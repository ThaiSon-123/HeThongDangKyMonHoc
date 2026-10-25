"""API điểm danh (GV-06..09, SV-10, PDT-10): buổi sinh sẵn, lưu cả lớp, tỷ lệ vắng, yêu cầu sửa."""

from django.http import FileResponse, Http404
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.attendance import services
from apps.attendance.models import Attendance, AttendanceRequest, AttendanceSession
from apps.attendance.serializers import (
    AttendanceRequestSerializer,
    MyAttendanceSerializer,
    RecordsPutSerializer,
    RecordsSerializer,
    RequestCreateSerializer,
    RequestDecisionSerializer,
    SessionListSerializer,
    SessionSerializer,
)
from apps.audit.models import HanhDong
from apps.auth.models import Role
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import ClassSection, Semester, TrangThaiDon, TrangThaiLop
from apps.training.services import chon_hoc_ky
from core.mixins import write_audit
from core.pagination import StandardPagination
from core.permissions import HasRole, IsGiaoVien, IsSinhVien


class IsGiaoVienOrPdt(HasRole):
    roles = (Role.GIAO_VIEN, Role.PHONG_DAO_TAO)


class IsGiaoVienOrSinhVien(HasRole):
    roles = (Role.GIAO_VIEN, Role.SINH_VIEN)


def _lop_xem_duoc(user, lop_id):
    """Lớp mà người dùng được xem điểm danh: PĐT mọi lớp, GV chỉ lớp mình (BR-23)."""
    qs = ClassSection.objects.select_related("giao_vien", "hoc_ky")
    lop = qs.filter(pk=lop_id).first() if str(lop_id).isdigit() else None
    if lop is None:
        raise ValidationError({"lop_hoc_phan": ["Lớp học phần không tồn tại."]})
    if user.role == Role.GIAO_VIEN:
        services.kiem_tra_gv_lop(user, lop)
    return lop


class SessionViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """`GET /attendance/sessions/?lop_hoc_phan=` — buổi sinh sẵn của lớp (không có API tạo buổi)."""

    serializer_class = SessionSerializer
    pagination_class = StandardPagination
    filter_backends: list = []

    def get_permissions(self):
        if self.action == "records" and self.request.method == "PUT":
            return [IsGiaoVien()]
        return [IsGiaoVienOrPdt()]

    def get_queryset(self):
        return AttendanceSession.objects.all()

    @extend_schema(
        parameters=[OpenApiParameter("lop_hoc_phan", int, required=True)],
        responses=SessionListSerializer,
    )
    def list(self, request):
        lop = _lop_xem_duoc(request.user, request.query_params.get("lop_hoc_phan"))
        qs = lop.buoi_diem_danh.all()
        page = self.paginate_queryset(qs)
        res = self.get_paginated_response(self.get_serializer(page, many=True).data)
        res.data["tong_so_buoi"] = qs.count()
        return res

    def _records_payload(self, session):
        lop = session.lop_hoc_phan
        tong, thong_ke = services.thong_ke_lop(lop)
        luu = {a.sinh_vien_id: a for a in Attendance.objects.filter(attendance_session=session)}
        pct = services.max_absent_pct()
        rows = []
        for r in services.sinh_vien_dang_ky(lop):
            a = luu.get(r.sinh_vien_id)
            tk = thong_ke.get(r.sinh_vien_id, {})
            vang = tk.get("so_vang_kp", 0)
            chi_so = services.chi_so_vang(tong, vang, pct)
            ho_so = r.sinh_vien.sinh_vien
            rows.append(
                {
                    "sinh_vien": r.sinh_vien_id,
                    "ma_sv": ho_so.ma_sv,
                    "ho_ten": ho_so.ho_ten,
                    "trang_thai": a.trang_thai if a else "CO_MAT",
                    "di_tre": a.di_tre if a else False,
                    "ghi_chu": a.ghi_chu if a else "",
                    "da_luu": a is not None,
                    "so_buoi_vang_kp": vang,
                    "ty_le_vang": chi_so["ty_le_vang"],
                    "canh_bao_vang": chi_so["canh_bao_vang"],
                }
            )
        return {
            "session": SessionSerializer(session).data,
            "lop_trang_thai": lop.trang_thai,
            "co_the_diem_danh": lop.trang_thai == TrangThaiLop.DANG_HOC
            and session.ngay_hoc <= timezone.localdate()
            and services.con_han_xin_sua(session.ngay_hoc),
            "con_han_sua": services.con_han_xin_sua(session.ngay_hoc),
            "so_ngay_xin_sua": services.so_ngay_xin_sua(),
            "tong_so_buoi": tong,
            "max_absent_pct": pct,
            "records": rows,
        }

    @extend_schema(methods=["GET"], responses=RecordsSerializer)
    @extend_schema(methods=["PUT"], request=RecordsPutSerializer, responses=RecordsSerializer)
    @action(detail=True, methods=["get", "put"])
    def records(self, request, pk=None):
        """GET: danh sách điểm danh cả lớp (GV lớp mình, PĐT). PUT: **lưu cả lớp** (chỉ GV lớp mình,
        lớp `DANG_HOC`, buổi đã tới ngày — BR-19/20)."""
        session = (
            AttendanceSession.objects.select_related("lop_hoc_phan__giao_vien")
            .filter(pk=pk)
            .first()
        )
        if session is None:
            raise Http404
        if request.user.role == Role.GIAO_VIEN:
            services.kiem_tra_gv_lop(request.user, session.lop_hoc_phan)
        if request.method == "PUT":
            s = RecordsPutSerializer(data=request.data)
            s.is_valid(raise_exception=True)
            session, so_dong = services.luu_diem_danh(
                session.id, request.user, s.validated_data["records"]
            )
            write_audit(
                request,
                HanhDong.UPDATE,
                "AttendanceSession",
                session.id,
                {"hanh_dong": "luu_diem_danh", "so_dong": so_dong},
            )
            session = AttendanceSession.objects.select_related("lop_hoc_phan").get(pk=session.id)
        return Response(self._records_payload(session))


class MyAttendanceView(APIView):
    """`GET /api/attendance/my/` (SV-10): từng buổi + tỷ lệ vắng của tôi theo lớp đã đăng ký."""

    permission_classes = [IsSinhVien]

    @extend_schema(parameters=[OpenApiParameter("hoc_ky", int)], responses=MyAttendanceSerializer)
    def get(self, request):
        user = request.user
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        pct = services.max_absent_pct()
        so_ngay = services.so_ngay_xin_sua()
        regs = Registration.objects.filter(
            sinh_vien=user,
            trang_thai=TrangThaiDangKy.DA_DANG_KY,
            lop_hoc_phan__hoc_ky=hoc_ky,
        ).select_related("lop_hoc_phan__mon_hoc")
        lop_data = []
        for reg in regs:
            lop = reg.lop_hoc_phan
            diem = {
                a.attendance_session_id: a
                for a in Attendance.objects.filter(
                    lop_hoc_phan=lop, sinh_vien=user
                ).prefetch_related("yeu_cau")
            }
            buoi = []
            for s in lop.buoi_diem_danh.all():
                a = diem.get(s.id)
                yc = None
                if a is not None:
                    gan_nhat = max(a.yeu_cau.all(), key=lambda y: y.id, default=None)
                    yc = (
                        {"id": gan_nhat.id, "trang_thai": gan_nhat.trang_thai} if gan_nhat else None
                    )
                buoi.append(
                    {
                        "session": s.id,
                        "attendance": a.id if a else None,
                        "ngay_hoc": s.ngay_hoc,
                        "buoi": s.buoi,
                        "tiet_bat_dau": s.tiet_bat_dau,
                        "trang_thai": a.trang_thai if a else None,
                        "di_tre": a.di_tre if a else False,
                        "ghi_chu": a.ghi_chu if a else "",
                        "yeu_cau": yc,
                        "con_han_xin_sua": services.con_han_xin_sua(s.ngay_hoc, so_ngay),
                    }
                )
            tong, thong_ke = services.thong_ke_lop(lop)
            tk = thong_ke.get(user.id, {})
            vang = tk.get("so_vang_kp", 0)
            lop_data.append(
                {
                    "lop_hoc_phan": lop.id,
                    "ma_lop": lop.ma_lop,
                    "ma_mon": lop.mon_hoc.ma_mon,
                    "ten_mon": lop.mon_hoc.ten_mon,
                    "lop_trang_thai": lop.trang_thai,
                    "tong_so_buoi": tong,
                    "so_co_mat": tk.get("so_co_mat", 0),
                    "so_di_tre": tk.get("so_di_tre", 0),
                    "so_vang_co_phep": tk.get("so_vang_co_phep", 0),
                    "so_vang_kp": vang,
                    **services.chi_so_vang(tong, vang, pct),
                    "buoi": buoi,
                }
            )
        cac_hoc_ky = (
            Semester.objects.filter(
                id__in=Registration.objects.filter(
                    sinh_vien=user, trang_thai=TrangThaiDangKy.DA_DANG_KY
                ).values("lop_hoc_phan__hoc_ky_id")
            )
            .order_by("-ngay_bat_dau")
            .values("id", "ten_hk")
        )
        return Response(
            MyAttendanceSerializer(
                {
                    "hoc_ky": hoc_ky.id,
                    "ten_hk": hoc_ky.ten_hk,
                    "cac_hoc_ky": cac_hoc_ky,
                    "max_absent_pct": pct,
                    "so_ngay_xin_sua": so_ngay,
                    "lop_hoc_phan": lop_data,
                }
            ).data
        )


class AttendanceRequestViewSet(
    mixins.ListModelMixin, mixins.CreateModelMixin, viewsets.GenericViewSet
):
    """`GET/POST /attendance/requests/` (SV gửi/xem của mình; GV xem lớp mình) và `PATCH` (GV duyệt)."""

    serializer_class = AttendanceRequestSerializer
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    filterset_fields = ["trang_thai", "attendance__lop_hoc_phan"]
    ordering = ["-id"]
    ordering_fields = ["id", "ngay_gui"]
    search_fields: list = []

    def get_permissions(self):
        if self.action == "create":
            return [IsSinhVien()]
        if self.action == "partial_update":
            return [IsGiaoVien()]
        return [IsGiaoVienOrSinhVien()]

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return AttendanceRequest.objects.none()
        qs = AttendanceRequest.objects.select_related(
            "attendance__attendance_session",
            "attendance__lop_hoc_phan__mon_hoc",
            "sinh_vien__sinh_vien",
        )
        user = self.request.user
        if user.role == Role.SINH_VIEN:
            return qs.filter(sinh_vien=user)
        return qs.filter(attendance__lop_hoc_phan__giao_vien__user=user)

    @extend_schema(request=RequestCreateSerializer, responses={201: AttendanceRequestSerializer})
    def create(self, request):
        s = RequestCreateSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        yc = services.tao_yeu_cau(
            request.user,
            d["attendance"],
            d["trang_thai_mong_muon"],
            d["di_tre_mong_muon"],
            d["ly_do"],
            d.get("minh_chung"),
        )
        write_audit(
            request,
            HanhDong.CREATE,
            "AttendanceRequest",
            yc.id,
            {"attendance": yc.attendance_id, "mong_muon": yc.trang_thai_mong_muon},
        )
        return Response(
            AttendanceRequestSerializer(self.get_queryset().get(pk=yc.id)).data, status=201
        )

    @extend_schema(request=RequestDecisionSerializer, responses=AttendanceRequestSerializer)
    def partial_update(self, request, pk=None):
        """GV (lớp mình) duyệt / từ chối; duyệt → ghi lại điểm danh (BR-19). PĐT không tham gia."""
        yc = self.get_object()
        s = RequestDecisionSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        duyet = s.validated_data["trang_thai"] == TrangThaiDon.DUYET
        yc = services.xu_ly_yeu_cau(yc.id, request.user, duyet, s.validated_data["ghi_chu"])
        write_audit(
            request,
            HanhDong.UPDATE,
            "AttendanceRequest",
            yc.id,
            {"quyet_dinh": yc.trang_thai, "attendance": yc.attendance_id},
        )
        return Response(AttendanceRequestSerializer(self.get_queryset().get(pk=yc.id)).data)

    @extend_schema(responses={(200, "application/octet-stream"): OpenApiTypes.BINARY})
    @action(detail=True, methods=["get"], url_path="minh-chung")
    def minh_chung(self, request, pk=None):
        """Tải minh chứng — chỉ GV phụ trách lớp (BR-23); SV tải lại bản của mình."""
        yc = self.get_object()
        if not yc.minh_chung:
            raise Http404
        return FileResponse(yc.minh_chung.open("rb"), as_attachment=False)
