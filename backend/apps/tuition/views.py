"""API học phí (KT-01..11, SV-12): bảng giá, miễn giảm, tính, thu/hoàn, công nợ, biên lai, `tuition/my`."""

import uuid

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.http import HttpResponseRedirect
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.audit.models import HanhDong
from apps.profiles.models import StudentProfile
from apps.registration.models import TrangThaiDangKy
from apps.registration.services import ho_so_sinh_vien
from apps.training.models import Semester
from apps.training.services import chon_hoc_ky
from apps.tuition import services
from apps.tuition.models import (
    Discount,
    HinhThucDong,
    HocPhanGia,
    LoaiThanhToan,
    OnlineTransaction,
    Payment,
    TrangThaiGiaoDich,
    TrangThaiHocPhi,
    Tuition,
    TuitionConfig,
    TuitionInstallment,
)
from apps.tuition.serializers import (
    CalculateResultSerializer,
    DiscountSerializer,
    HocPhanGiaSerializer,
    InstallmentSerializer,
    InstallmentsPutSerializer,
    InstallmentsSerializer,
    MyPayResultSerializer,
    MyPaySerializer,
    MyPayStatusSerializer,
    MyPlanSerializer,
    MyTuitionSerializer,
    PaymentCreateSerializer,
    PaymentSerializer,
    SinhVienKtSerializer,
    TuitionConfigSerializer,
    TuitionDetailSerializer,
    TuitionRowSerializer,
)
from core.exceptions import Codes, business_error
from core.export import XLSX, xlsx_response
from core.mixins import AuditLogMixin, write_audit
from core.pagination import StandardPagination
from core.permissions import IsKeToan, IsSinhVien
from core.utils import client_ip, int_param

HOC_KY = OpenApiParameter("hoc_ky", int, description="Mặc định: học kỳ hiện tại / `MO` gần nhất")


class _KtViewSet(AuditLogMixin):
    permission_classes = [IsKeToan]
    http_method_names = ["get", "post", "patch", "head", "options"]
    ordering = ["-id"]


class TuitionConfigViewSet(_KtViewSet):
    """KT-01: hạn đóng học phí theo học kỳ."""

    audit_model = "TuitionConfig"
    queryset = TuitionConfig.objects.select_related("hoc_ky")
    serializer_class = TuitionConfigSerializer
    filterset_fields = ["hoc_ky"]
    search_fields = ["hoc_ky__ten_hk"]
    ordering_fields = ["id", "han_dong"]


class InstallmentsView(APIView):
    """KT-01: 3 đợt đóng học phí của học kỳ — `GET`/`PUT /api/tuition/installments/?hoc_ky=`."""

    permission_classes = [IsKeToan]

    @staticmethod
    def _tra(hoc_ky):
        dots = TuitionInstallment.objects.filter(hoc_ky=hoc_ky).order_by("thu_tu")
        return Response({"hoc_ky": hoc_ky.id, "dots": InstallmentSerializer(dots, many=True).data})

    @extend_schema(parameters=[HOC_KY], responses=InstallmentsSerializer)
    def get(self, request):
        return self._tra(chon_hoc_ky(request.query_params.get("hoc_ky")))

    @extend_schema(
        parameters=[HOC_KY], request=InstallmentsPutSerializer, responses=InstallmentsSerializer
    )
    def put(self, request):
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        s = InstallmentsPutSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        with transaction.atomic():
            TuitionInstallment.objects.filter(hoc_ky=hoc_ky).delete()
            TuitionInstallment.objects.bulk_create(
                TuitionInstallment(hoc_ky=hoc_ky, **d) for d in s.validated_data["dots"]
            )
        write_audit(
            request,
            HanhDong.UPDATE,
            "TuitionInstallment",
            f"hk{hoc_ky.id}",
            {"dots": InstallmentSerializer(s.validated_data["dots"], many=True).data},
        )
        return self._tra(hoc_ky)


class PricingViewSet(_KtViewSet):
    """KT-02/03/04: bảng giá `HocPhanGia` (mặc định, khối kiến thức, ngành, giá TH). Sai thì xóa."""

    audit_model = "HocPhanGia"
    http_method_names = [*_KtViewSet.http_method_names, "delete"]
    queryset = HocPhanGia.objects.select_related("hoc_ky")
    serializer_class = HocPhanGiaSerializer
    filterset_fields = ["hoc_ky", "pham_vi"]
    search_fields = ["tham_chieu"]
    ordering_fields = ["id", "don_gia"]

    @extend_schema(
        parameters=[
            OpenApiParameter(
                "ap_dung_cho",
                int,
                description="Học kỳ: giá của kỳ đó + giá 'mọi học kỳ' đang áp dụng",
            )
        ]
    )
    def list(self, request, *args, **kwargs):
        return super().list(request, *args, **kwargs)

    def get_queryset(self):
        qs = super().get_queryset()
        if hoc_ky := int_param(self.request, "ap_dung_cho"):
            qs = qs.filter(Q(hoc_ky=hoc_ky) | Q(hoc_ky__isnull=True))
        return qs


class DiscountViewSet(_KtViewSet):
    """KT-05 / BR-18: miễn giảm, học bổng — mọi thay đổi ghi audit log."""

    audit_model = "Discount"
    http_method_names = [*_KtViewSet.http_method_names, "delete"]
    queryset = Discount.objects.select_related("sinh_vien__sinh_vien", "hoc_ky")
    serializer_class = DiscountSerializer
    filterset_fields = ["hoc_ky", "loai", "sinh_vien"]
    search_fields = ["sinh_vien__sinh_vien__ma_sv", "sinh_vien__sinh_vien__ho_ten"]
    ordering_fields = ["id"]


# ----------------------------------------------------------------- danh sách / chi tiết


def _hang(t, discounts, han, hom_nay, chi_tiet=None, payments=None, dots=()):
    ho_so = getattr(t.sinh_vien, "sinh_vien", None)
    dx = services.gia_tri_dan_xuat(t, discounts, t.payments.all())
    lich = services.lich_dot(dx["phai_nop"], dx["thuc_thu"], dots)
    han, qua_han = services.han_va_qua_han(t.hinh_thuc, dx, han, lich, hom_nay)
    out = {
        "id": t.id,
        "sinh_vien": t.sinh_vien_id,
        "ma_sv": ho_so.ma_sv if ho_so else "",
        "ho_ten": ho_so.ho_ten if ho_so else "",
        "nganh_ma": ho_so.nganh.ma_nganh if ho_so else "",
        "nganh_ten": ho_so.nganh.ten_nganh if ho_so else "",
        "hoc_ky": t.hoc_ky_id,
        "ten_hk": t.hoc_ky.ten_hk,
        "tong_tin_chi": t.tong_tin_chi,
        "tong_tien": t.tong_tien,
        "trang_thai": t.trang_thai,
        **dx,
        "hinh_thuc": t.hinh_thuc,
        "han_dong": han,
        "qua_han": qua_han,
    }
    if chi_tiet is not None:
        out["chi_tiet"] = chi_tiet
        out["payments"] = payments if payments is not None else list(t.payments.all())
    return out


def _tuition_qs(request, hoc_ky):
    qs = (
        Tuition.objects.filter(hoc_ky=hoc_ky)
        .select_related("sinh_vien__sinh_vien__nganh", "hoc_ky")
        .prefetch_related("payments")
    )
    p = request.query_params
    if nganh := int_param(request, "nganh"):
        qs = qs.filter(sinh_vien__sinh_vien__nganh=nganh)
    if sinh_vien := int_param(request, "sinh_vien"):
        qs = qs.filter(sinh_vien=sinh_vien)
    if lop := int_param(request, "lop_hoc_phan"):
        qs = qs.filter(
            sinh_vien__dang_ky__lop_hoc_phan=lop,
            sinh_vien__dang_ky__trang_thai=TrangThaiDangKy.DA_DANG_KY,
        )
    if p.get("search"):
        t = p["search"].strip()
        qs = qs.filter(
            Q(sinh_vien__sinh_vien__ma_sv__icontains=t)
            | Q(sinh_vien__sinh_vien__ho_ten__icontains=t)
        )
    return qs.order_by("sinh_vien__sinh_vien__ma_sv")


def _rows(qs, hoc_ky):
    """Dựng dòng cho cả `qs` (một truy vấn miễn giảm cho cả lô)."""
    ds = {}
    for d in Discount.objects.filter(hoc_ky=hoc_ky):
        ds.setdefault(d.sinh_vien_id, []).append(d)
    han, hom_nay = services.han_dong(hoc_ky.id), timezone.localdate()
    dots = services.dot_cua_hoc_ky(hoc_ky.id)
    return [_hang(t, ds.get(t.sinh_vien_id, []), han, hom_nay, dots=dots) for t in qs]


def _phan_trang(request, rows, view):
    pg = StandardPagination()
    page = pg.paginate_queryset(rows, request, view=view)
    return pg.get_paginated_response(TuitionRowSerializer(page, many=True).data)


LIST_PARAMS = [
    HOC_KY,
    OpenApiParameter("nganh", int),
    OpenApiParameter("lop_hoc_phan", int),
    OpenApiParameter("sinh_vien", int),
    OpenApiParameter("search", str),
    OpenApiParameter("hien_thi", str, description="CHUA_TINH | CON_NO | CHO_HOAN_TIEN | DA_DONG"),
    OpenApiParameter("page", int),
    OpenApiParameter("page_size", int),
]


class TuitionListView(APIView):
    """`GET /api/tuition/` (KT-07): học phí theo học kỳ/ngành/lớp/trạng thái, kèm giá trị dẫn xuất."""

    permission_classes = [IsKeToan]

    @extend_schema(parameters=LIST_PARAMS, responses=TuitionRowSerializer(many=True))
    def get(self, request):
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        rows = _rows(_tuition_qs(request, hoc_ky), hoc_ky)
        # ponytail: trạng thái hiển thị là dẫn xuất nên lọc ở Python trên cả học kỳ; ~10^4 dòng/học kỳ
        # còn ổn, chuyển sang annotate SQL nếu cần hơn.
        if request.query_params.get("hien_thi"):
            rows = [r for r in rows if r["hien_thi"] == request.query_params["hien_thi"]]
        return _phan_trang(request, rows, self)


class TuitionDebtsView(APIView):
    """`GET /api/tuition/debts/` (KT-09): còn nợ, quá hạn, chờ hoàn tiền (`can_hoan`)."""

    permission_classes = [IsKeToan]

    @extend_schema(
        parameters=[*LIST_PARAMS, OpenApiParameter("qua_han", bool)],
        responses=TuitionRowSerializer(many=True),
    )
    def get(self, request):
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        rows = [
            r
            for r in _rows(_tuition_qs(request, hoc_ky), hoc_ky)
            if r["con_no"] > 0 or r["can_hoan"] > 0
        ]
        if request.query_params.get("qua_han") in ("1", "true", "True"):
            rows = [r for r in rows if r["qua_han"]]
        if request.query_params.get("hien_thi"):
            rows = [r for r in rows if r["hien_thi"] == request.query_params["hien_thi"]]
        return _phan_trang(request, rows, self)


class TuitionDetailView(APIView):
    """`GET /api/tuition/{id}/` (KT): chi tiết từng môn + các lần thu/hoàn."""

    permission_classes = [IsKeToan]

    @extend_schema(responses=TuitionDetailSerializer)
    def get(self, request, pk):
        t = (
            Tuition.objects.select_related("sinh_vien__sinh_vien__nganh", "hoc_ky")
            .prefetch_related("payments__nguoi_thu")
            .filter(pk=pk)
            .first()
        )
        if t is None:
            raise NotFound("Không tìm thấy học phí.")
        ds = list(Discount.objects.filter(sinh_vien=t.sinh_vien, hoc_ky=t.hoc_ky))
        try:
            chi_tiet = services.chi_tiet_hoc_phi(t.sinh_vien, t.hoc_ky)[0]
        except Exception:  # thiếu giá: vẫn xem được các khoản đã thu
            chi_tiet = []
        return Response(
            TuitionDetailSerializer(
                _hang(
                    t,
                    ds,
                    services.han_dong(t.hoc_ky_id),
                    timezone.localdate(),
                    chi_tiet,
                    list(t.payments.all()),
                    services.dot_cua_hoc_ky(t.hoc_ky_id),
                )
            ).data
        )


class TuitionCalculateView(APIView):
    """`POST /api/tuition/calculate/?hoc_ky=` (KT-06): tính lại hàng loạt. Thiếu giá → `400`."""

    permission_classes = [IsKeToan]

    @extend_schema(parameters=[HOC_KY], request=None, responses=CalculateResultSerializer)
    def post(self, request):
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        n = services.tinh_hang_loat(hoc_ky)
        write_audit(
            request,
            HanhDong.UPDATE,
            "Tuition",
            f"hk{hoc_ky.id}",
            {"hanh_dong": "tinh_hang_loat", "so_sv": n},
        )
        return Response({"so_sinh_vien": n})


class TuitionStudentsView(APIView):
    """`GET /api/tuition/students/?search=` (KT): tra SV để lập miễn giảm — chỉ mã SV, họ tên, ngành."""

    permission_classes = [IsKeToan]

    @extend_schema(
        parameters=[OpenApiParameter("search", str), OpenApiParameter("page", int)],
        responses=SinhVienKtSerializer(many=True),
    )
    def get(self, request):
        qs = StudentProfile.objects.select_related("nganh").order_by("ma_sv")
        t = request.query_params.get("search", "").strip()
        if t:
            qs = qs.filter(Q(ma_sv__icontains=t) | Q(ho_ten__icontains=t))
        pg = StandardPagination()
        page = pg.paginate_queryset(qs, request, view=self)
        return pg.get_paginated_response(SinhVienKtSerializer(page, many=True).data)


# ----------------------------------------------------------------- thu / hoàn


class PaymentViewSet(mixins.ListModelMixin, mixins.CreateModelMixin, viewsets.GenericViewSet):
    """`POST /api/tuition/payments/` (KT-08, BR-26) + danh sách + biên lai (KT-10)."""

    permission_classes = [IsKeToan]
    serializer_class = PaymentSerializer
    queryset = Payment.objects.select_related("nguoi_thu")
    filterset_fields = ["tuition", "loai"]
    ordering = ["-ngay"]
    ordering_fields = ["id", "ngay"]
    search_fields = ["bien_lai_ma"]

    @staticmethod
    def _key(request):
        raw = getattr(request, "idempotency_key", None)
        if not raw:
            return None
        try:
            return uuid.UUID(raw)
        except ValueError:
            raise ValidationError({"Idempotency-Key": ["Phải là UUID."]}) from None

    @extend_schema(
        request=PaymentCreateSerializer,
        responses={201: PaymentSerializer},
        parameters=[OpenApiParameter("Idempotency-Key", str, OpenApiParameter.HEADER)],
    )
    def create(self, request):
        """Ghi `THU`/`HOAN`. Hỗ trợ `Idempotency-Key`: trùng key trả lại bản ghi cũ."""
        s = PaymentCreateSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        p, moi = services.ghi_thanh_toan(
            request.user,
            d["tuition"],
            d["loai"],
            d["so_tien"],
            d["phuong_thuc"],
            self._key(request),
        )
        if moi:
            write_audit(
                request,
                HanhDong.CREATE,
                "Payment",
                p.id,
                {"tuition": p.tuition_id, "loai": p.loai, "so_tien": str(p.so_tien)},
            )
        return Response(PaymentSerializer(p).data, status=201)

    @extend_schema(responses={(200, XLSX): OpenApiTypes.BINARY})
    @action(detail=True, methods=["get"])
    def receipt(self, request, pk=None):
        """Biên lai Excel của một lần thu/hoàn (KT-10)."""
        p = self.get_object()
        t = p.tuition
        ho_so = t.sinh_vien.sinh_vien
        rows = [
            ("Mã biên lai", p.bien_lai_ma),
            ("Loại", "Thu" if p.loai == LoaiThanhToan.THU else "Hoàn tiền"),
            ("Ngày", timezone.localtime(p.ngay).strftime("%d/%m/%Y %H:%M")),
            ("Sinh viên", f"{ho_so.ho_ten} ({ho_so.ma_sv})"),
            ("Ngành", ho_so.nganh.ten_nganh),
            ("Học kỳ", t.hoc_ky.ten_hk),
            ("Số tiền", float(p.so_tien)),
            ("Phương thức", p.get_phuong_thuc_display()),
            ("Người thu", p.nguoi_thu.username),
        ]
        return xlsx_response(f"{p.bien_lai_ma}.xlsx", ["Mục", "Giá trị"], rows, sheet="Biên lai")


# ----------------------------------------------------------------- SV xem học phí


class MyTuitionView(APIView):
    """`GET /api/tuition/my/` (SV-12): học phí của tôi kèm chi tiết môn, giao dịch, thông tin chuyển khoản."""

    permission_classes = [IsSinhVien]

    @extend_schema(parameters=[HOC_KY], responses=MyTuitionSerializer)
    def get(self, request):
        user = request.user
        ho_so = ho_so_sinh_vien(user)
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        t = (
            Tuition.objects.filter(sinh_vien=user, hoc_ky=hoc_ky)
            .select_related("sinh_vien__sinh_vien__nganh", "hoc_ky")
            .prefetch_related("payments__nguoi_thu")
            .first()
        )
        if t is None:  # chưa có đăng ký nào: học phí 0, chưa tính
            t = Tuition(sinh_vien=user, hoc_ky=hoc_ky)
            payments = []
        else:
            payments = list(t.payments.all())
        try:
            chi_tiet = services.chi_tiet_hoc_phi(user, hoc_ky)[0]
        except Exception:  # chưa cấu hình giá: SV thấy CHUA_TINH
            chi_tiet = []
        ds = list(Discount.objects.filter(sinh_vien=user, hoc_ky=hoc_ky))
        dots = services.dot_cua_hoc_ky(hoc_ky.id)
        if t.pk is None:
            row = _hang_chua_co(t, ds, hoc_ky, ho_so)
        else:
            row = _hang(t, ds, services.han_dong(hoc_ky.id), timezone.localdate(), dots=dots)
        lich = services.lich_dot(row["phai_nop"], row["thuc_thu"], dots)
        row["cac_dot"] = lich
        row["dot_tiep_theo"] = (
            services.dot_tiep_theo(lich, row["thuc_thu"])
            if row["hinh_thuc"] == HinhThucDong.CHIA_DOT
            else None
        )
        row["chi_tiet"] = chi_tiet
        row["payments"] = payments
        row["thanh_toan"] = services.thong_tin_chuyen_khoan(ho_so, hoc_ky)
        row["cac_hoc_ky"] = (
            Semester.objects.filter(
                Q(id=hoc_ky.id)
                | Q(id__in=Tuition.objects.filter(sinh_vien=user).values("hoc_ky_id"))
            )
            .order_by("-ngay_bat_dau")
            .values("id", "ten_hk")
        )
        return Response(MyTuitionSerializer(row).data)


class MyPlanView(APIView):
    """`PATCH /api/tuition/my/plan/?hoc_ky=`: SV đổi giữa đóng một lần / chia 3 đợt (đổi lúc nào cũng
    được: lịch đợt là dẫn xuất nên `con_no` không đổi)."""

    permission_classes = [IsSinhVien]

    @extend_schema(parameters=[HOC_KY], request=MyPlanSerializer, responses=MyPlanSerializer)
    def patch(self, request):
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        s = MyPlanSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        hinh_thuc = s.validated_data["hinh_thuc"]
        t = Tuition.objects.filter(sinh_vien=request.user, hoc_ky=hoc_ky).first()
        if t is None or t.trang_thai != TrangThaiHocPhi.DA_TINH:
            raise business_error(Codes.TRANG_THAI_KHONG_HOP_LE, "Học phí chưa được tính.")
        if hinh_thuc == HinhThucDong.CHIA_DOT and not services.dot_cua_hoc_ky(hoc_ky.id):
            raise business_error(
                Codes.TRANG_THAI_KHONG_HOP_LE, "Học kỳ này chưa cấu hình chia đợt."
            )
        t.hinh_thuc = hinh_thuc
        t.save(update_fields=["hinh_thuc"])
        write_audit(
            request,
            HanhDong.UPDATE,
            "Tuition",
            t.id,
            {"hanh_dong": "doi_hinh_thuc", "hinh_thuc": hinh_thuc},
        )
        return Response({"hinh_thuc": hinh_thuc})


class MyPayView(APIView):
    """`POST /api/tuition/my/pay/?hoc_ky=`: tạo giao dịch VNPay, trả `payment_url` để mở/quét QR."""

    permission_classes = [IsSinhVien]

    @extend_schema(
        parameters=[HOC_KY], request=MyPaySerializer, responses={201: MyPayResultSerializer}
    )
    def post(self, request):
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        s = MyPaySerializer(data=request.data)
        s.is_valid(raise_exception=True)
        giao_dich, url = services.tao_giao_dich_vnpay(
            request.user,
            hoc_ky,
            s.validated_data["muc"],
            s.validated_data.get("so_tien"),
            client_ip(request),
        )
        write_audit(
            request,
            HanhDong.CREATE,
            "OnlineTransaction",
            giao_dich.id,
            {"tuition": giao_dich.tuition_id, "so_tien": str(giao_dich.so_tien)},
        )
        data = {"payment_url": url, "txn_ref": giao_dich.txn_ref.hex, "so_tien": giao_dich.so_tien}
        return Response(MyPayResultSerializer(data).data, status=201)


class MyPayStatusView(APIView):
    """`GET /api/tuition/my/pay/<txn_ref>/`: trạng thái giao dịch của tôi (người khác → `404`)."""

    permission_classes = [IsSinhVien]

    @extend_schema(responses=MyPayStatusSerializer)
    def get(self, request, txn_ref):
        try:
            ref = uuid.UUID(txn_ref)
        except ValueError:
            raise NotFound("Không tìm thấy giao dịch.") from None
        gd = OnlineTransaction.objects.filter(txn_ref=ref, tuition__sinh_vien=request.user).first()
        if gd is None:
            raise NotFound("Không tìm thấy giao dịch.")
        data = {"txn_ref": gd.txn_ref.hex, "trang_thai": gd.trang_thai, "so_tien": gd.so_tien}
        return Response(MyPayStatusSerializer(data).data)


def _hang_chua_co(t, ds, hoc_ky, ho_so):
    dx = services.gia_tri_dan_xuat(t, ds, [])
    return {
        "id": None,
        "sinh_vien": t.sinh_vien_id,
        "ma_sv": ho_so.ma_sv,
        "ho_ten": ho_so.ho_ten,
        "nganh_ma": ho_so.nganh.ma_nganh,
        "nganh_ten": ho_so.nganh.ten_nganh,
        "hoc_ky": hoc_ky.id,
        "ten_hk": hoc_ky.ten_hk,
        "tong_tin_chi": 0,
        "tong_tien": t.tong_tien,
        "trang_thai": t.trang_thai,
        **dx,
        "hinh_thuc": t.hinh_thuc,
        "han_dong": services.han_dong(hoc_ky.id),
        "qua_han": False,
    }


# ----------------------------------------------------------------- VNPay gọi về


IPN_THONG_DIEP = {
    "00": "Confirm Success",
    "01": "Order not found",
    "02": "Order already confirmed",
    "04": "Invalid amount",
    "97": "Invalid signature",
    "99": "Unknown error",
}


def _tham_so_vnp(request):
    return {k: v for k, v in request.query_params.items() if k.startswith("vnp_")}


class _VnpayCallback(APIView):
    authentication_classes: list = []  # VNPay / trình duyệt đã rời app: chỉ chữ ký làm căn cứ
    permission_classes = [AllowAny]


class VnpayIpnView(_VnpayCallback):
    """`GET /api/tuition/vnpay/ipn/`: VNPay gọi server-to-server; trả `{RspCode, Message}`."""

    @extend_schema(responses=OpenApiTypes.OBJECT)
    def get(self, request):
        rsp, _ = services.xac_nhan_vnpay(_tham_so_vnp(request))
        return Response({"RspCode": rsp, "Message": IPN_THONG_DIEP[rsp]})


class VnpayReturnView(_VnpayCallback):
    """`GET /api/tuition/vnpay/return/`: trình duyệt SV được VNPay chuyển về; ghi kết quả (cùng hàm với
    IPN, idempotent) rồi chuyển tiếp tới trang kết quả của app."""

    @extend_schema(responses={302: None})
    def get(self, request):
        rsp, gd = services.xac_nhan_vnpay(_tham_so_vnp(request))
        if rsp == "97":
            status = "sai_chu_ky"
        elif gd is not None and rsp in ("00", "02"):
            status = {
                TrangThaiGiaoDich.THANH_CONG: "thanh_cong",
                TrangThaiGiaoDich.THAT_BAI: "that_bai",
                TrangThaiGiaoDich.LOI: "loi",
            }.get(gd.trang_thai, "khong_hop_le")
        else:
            status = "khong_hop_le"
        txn = gd.txn_ref.hex if gd is not None else ""
        return HttpResponseRedirect(f"{settings.APP_RESULT_URL}?status={status}&txn={txn}")
