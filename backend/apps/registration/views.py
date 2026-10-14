"""API đăng ký môn (SV-03..09, PDT-10/11): đăng ký, hủy, lịch sử, theo dõi, xuất Excel, lớp có thể
đăng ký, CTĐT của tôi, thời khóa biểu."""

import uuid

import django_filters
from django.utils import timezone
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import mixins, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import NotFound, ValidationError
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.audit.models import HanhDong
from apps.auth.models import Role
from apps.registration import services
from apps.registration.models import Registration, TrangThaiDangKy
from apps.registration.serializers import (
    AvailableCoursesSerializer,
    CancelSerializer,
    ClassBriefSerializer,
    MyCurriculumSerializer,
    RegistrationCreateSerializer,
    RegistrationResultSerializer,
    RegistrationSerializer,
    TimetableSerializer,
)
from apps.training.models import ClassSection, CurriculumCourse, TrangThaiHocKy
from apps.training.services import chon_hoc_ky
from core.export import XLSX, xlsx_response
from core.mixins import write_audit
from core.pagination import StandardPagination
from core.permissions import HasRole, IsPhongDaoTao, IsSinhVien

HOC_KY_PARAM = OpenApiParameter(
    "hoc_ky", int, description="Mặc định: học kỳ hiện tại / `MO` gần nhất"
)


class IsSinhVienOrPdt(HasRole):
    roles = (Role.SINH_VIEN, Role.PHONG_DAO_TAO)


class IsSinhVienOrGiaoVien(HasRole):
    roles = (Role.SINH_VIEN, Role.GIAO_VIEN)


class RegistrationFilter(django_filters.FilterSet):
    hoc_ky = django_filters.NumberFilter(field_name="lop_hoc_phan__hoc_ky")
    mon_hoc = django_filters.NumberFilter(field_name="lop_hoc_phan__mon_hoc")
    nganh = django_filters.NumberFilter(field_name="sinh_vien__sinh_vien__nganh")

    class Meta:
        model = Registration
        fields = ["lop_hoc_phan", "trang_thai"]


class RegistrationViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """`POST` (SV) · `DELETE` (SV hủy / PĐT hủy hộ) · `GET` (PĐT theo dõi) · `history` · `export`."""

    serializer_class = RegistrationSerializer
    filterset_class = RegistrationFilter
    search_fields = [
        "sinh_vien__sinh_vien__ma_sv",
        "sinh_vien__sinh_vien__ho_ten",
        "lop_hoc_phan__ma_lop",
        "lop_hoc_phan__mon_hoc__ten_mon",
    ]
    ordering_fields = ["id", "ngay_dang_ky"]
    ordering = ["-ngay_dang_ky"]
    throttle_scope = "registration"  # 30/phút/người dùng, chỉ áp cho thao tác ghi

    def get_throttles(self):
        return super().get_throttles() if self.request.method in ("POST", "DELETE") else []

    def get_permissions(self):
        if self.action in ("list", "export"):
            return [IsPhongDaoTao()]
        if self.action == "destroy":
            return [IsSinhVienOrPdt()]
        return [IsSinhVien()]  # create, history

    def get_queryset(self):
        if getattr(self, "swagger_fake_view", False):
            return Registration.objects.none()
        qs = Registration.objects.select_related(
            "sinh_vien__sinh_vien__nganh",
            "lop_hoc_phan__mon_hoc",
            "lop_hoc_phan__hoc_ky",
            "lop_hoc_phan__giao_vien",
        ).prefetch_related("lop_hoc_phan__lich_hoc")
        user = self.request.user
        return qs.filter(sinh_vien=user) if user.role == Role.SINH_VIEN else qs

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
        request=RegistrationCreateSerializer,
        responses={201: RegistrationResultSerializer},
        parameters=[
            OpenApiParameter("Idempotency-Key", str, OpenApiParameter.HEADER, required=True)
        ],
    )
    def create(self, request):
        """Đăng ký môn (BR-01..07). Bắt buộc `Idempotency-Key`; trùng key trả lại bản ghi cũ."""
        s = RegistrationCreateSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        reg, warnings, moi = services.dang_ky(
            request.user, s.validated_data["lop_hoc_phan"], self._key(request)
        )
        if moi:
            write_audit(
                request,
                HanhDong.CREATE,
                "Registration",
                reg.id,
                {"lop_hoc_phan": reg.lop_hoc_phan_id, "sinh_vien": reg.sinh_vien_id},
            )
        return Response(self._payload(reg.id, warnings), status=201)

    @extend_schema(request=CancelSerializer, responses=RegistrationResultSerializer)
    def destroy(self, request, pk=None):
        """Hủy đăng ký (BR-05). SV: lớp `MO` + trong cửa sổ. PĐT hủy hộ: lớp `MO`/`DANG_HOC`,
        bắt buộc `ly_do`."""
        reg = self.get_object()
        s = CancelSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        ly_do = s.validated_data.get("ly_do", "")
        reg, warnings = services.huy_dang_ky(reg.id, request.user, ly_do)
        write_audit(
            request,
            HanhDong.UPDATE,
            "Registration",
            reg.id,
            {
                "hanh_dong": "huy_dang_ky",
                "boi": request.user.role,
                "sinh_vien": reg.sinh_vien_id,
                "ly_do": reg.ly_do_huy,
            },
        )
        return Response(self._payload(reg.id, warnings))

    def _payload(self, reg_id, warnings):
        reg = self.get_queryset().get(pk=reg_id)
        reg.warnings = warnings
        return RegistrationResultSerializer(reg).data

    @extend_schema(responses=RegistrationSerializer(many=True))
    @action(detail=False, methods=["get"])
    def history(self, request):
        """Lịch sử đăng ký của tôi — đã đăng ký / đã hủy, kèm lý do hủy (SV-09)."""
        qs = self.filter_queryset(self.get_queryset())
        page = self.paginate_queryset(qs)
        return self.get_paginated_response(self.get_serializer(page, many=True).data)

    @extend_schema(responses={(200, XLSX): OpenApiTypes.BINARY})
    @action(detail=False, methods=["get"])
    def export(self, request):
        """Xuất Excel danh sách đăng ký theo bộ lọc hiện tại (PDT-10)."""
        rows = []
        for r in self.filter_queryset(self.get_queryset()):
            ho_so = getattr(r.sinh_vien, "sinh_vien", None)
            lop = r.lop_hoc_phan
            rows.append(
                (
                    ho_so.ma_sv if ho_so else "",
                    ho_so.ho_ten if ho_so else "",
                    ho_so.nganh.ten_nganh if ho_so else "",
                    lop.ma_lop,
                    lop.mon_hoc.ten_mon,
                    lop.hoc_ky.ten_hk,
                    timezone.localtime(r.ngay_dang_ky).strftime("%d/%m/%Y %H:%M"),
                    "Đã đăng ký" if r.trang_thai == TrangThaiDangKy.DA_DANG_KY else "Đã hủy",
                    r.ly_do_huy,
                )
            )
        return xlsx_response(
            "dang_ky_mon_hoc.xlsx",
            [
                "Mã SV",
                "Họ tên",
                "Ngành",
                "Mã lớp",
                "Môn học",
                "Học kỳ",
                "Ngày đăng ký",
                "Trạng thái",
                "Lý do hủy",
            ],
            rows,
            sheet="Đăng ký",
        )


class AvailableCoursesView(APIView):
    """`GET /api/courses/available/` (SV-04): đã lọc cả trùng lịch."""

    permission_classes = [IsSinhVien]
    loc_trung_lich = True

    @extend_schema(
        parameters=[
            HOC_KY_PARAM,
            OpenApiParameter("search", str, description="Mã lớp / mã môn / tên môn"),
            OpenApiParameter("page", int),
            OpenApiParameter("page_size", int),
        ],
        responses=AvailableCoursesSerializer,
    )
    def get(self, request):
        user = request.user
        ho_so = services.ho_so_sinh_vien(user)
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        lop = services.lop_co_the_dang_ky(
            user, ho_so, hoc_ky, request.query_params.get("search", ""), self.loc_trung_lich
        )
        paginator = StandardPagination()
        page = paginator.paginate_queryset(lop, request, view=self)
        ctx = {
            "cau_hinh_mon": {
                c.mon_hoc_id: c
                for c in CurriculumCourse.objects.filter(
                    ctdt_id=ho_so.ctdt_id, mon_hoc__in=[x.mon_hoc_id for x in page]
                )
            }
        }
        res = paginator.get_paginated_response(
            ClassBriefSerializer(page, many=True, context=ctx).data
        )
        now = timezone.now()
        res.data["meta"] = {
            "hoc_ky": hoc_ky.id,
            "ten_hk": hoc_ky.ten_hk,
            "trong_cua_so": hoc_ky.trang_thai == TrangThaiHocKy.MO
            and hoc_ky.cua_so_dk_bat_dau <= now <= hoc_ky.cua_so_dk_ket_thuc,
            "tin_chi_toi_thieu": hoc_ky.tin_chi_toi_thieu,
            "tin_chi_toi_da": hoc_ky.tin_chi_toi_da,
            "tin_chi_toi_da_canh_bao": hoc_ky.tin_chi_toi_da_canh_bao,
            "tin_chi_da_dang_ky": services.tong_tin_chi_dang_ky(user, hoc_ky),
            "bi_canh_bao_hoc_vu": services.tran_tin_chi(ho_so, hoc_ky) < hoc_ky.tin_chi_toi_da,
        }
        return res


class AutoScheduleCoursesView(AvailableCoursesView):
    """`GET /api/auto-schedule/available-courses/` (SV-06): toàn bộ lớp mở của CTĐT, còn chỗ, chưa đăng ký
    — **không lọc trùng lịch** (client tự ghép TKB; đăng ký thật vẫn kiểm BR-01..07 ở server)."""

    loc_trung_lich = False


class MyCurriculumView(APIView):
    """`GET /api/curriculums/my/` (SV-03): CTĐT của tôi kèm môn đã đạt chưa."""

    permission_classes = [IsSinhVien]

    @extend_schema(responses=MyCurriculumSerializer)
    def get(self, request):
        ho_so = services.ho_so_sinh_vien(request.user)
        ctdt = ho_so.ctdt
        if ctdt is None:
            raise NotFound("Chưa được gán chương trình đào tạo.")
        da_dat = services.mon_da_dat_ids(request.user)
        mon = [
            {
                "mon_hoc": c.mon_hoc_id,
                "ma_mon": c.mon_hoc.ma_mon,
                "ten_mon": c.mon_hoc.ten_mon,
                "tong_tin_chi": c.mon_hoc.tong_tin_chi,
                "khoi_kien_thuc": c.khoi_kien_thuc,
                "loai_mon": c.loai_mon,
                "hoc_ky_goi_y": c.hoc_ky_goi_y,
                "da_dat": c.mon_hoc_id in da_dat,
            }
            for c in CurriculumCourse.objects.filter(ctdt=ctdt).select_related("mon_hoc")
        ]
        return Response(
            MyCurriculumSerializer(
                {
                    "id": ctdt.id,
                    "ma_ctdt": ctdt.ma_ctdt,
                    "nganh_ten": ho_so.nganh.ten_nganh,
                    "khoa_tuyen_sinh": ctdt.khoa_tuyen_sinh,
                    "tong_tin_chi_yeu_cau": ctdt.tong_tin_chi_yeu_cau,
                    "mon": mon,
                }
            ).data
        )


class MyTimetableView(APIView):
    """`GET /api/timetable/my/` (SV-08, GV-05): lịch học (SV: lớp đã đăng ký; GV: lớp phụ trách)."""

    permission_classes = [IsSinhVienOrGiaoVien]

    @extend_schema(parameters=[HOC_KY_PARAM], responses=TimetableSerializer)
    def get(self, request):
        hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
        qs = ClassSection.objects.filter(hoc_ky=hoc_ky)
        if request.user.role == Role.SINH_VIEN:
            qs = qs.filter(
                dang_ky__sinh_vien=request.user, dang_ky__trang_thai=TrangThaiDangKy.DA_DANG_KY
            )
        else:
            qs = qs.filter(giao_vien__user=request.user)
        qs = (
            qs.select_related("mon_hoc", "giao_vien")
            .prefetch_related("lich_hoc")
            .order_by("ma_lop")
        )
        return Response(
            TimetableSerializer(
                {
                    "hoc_ky": hoc_ky.id,
                    "ten_hk": hoc_ky.ten_hk,
                    "ngay_bat_dau": hoc_ky.ngay_bat_dau,
                    "ngay_ket_thuc": hoc_ky.ngay_ket_thuc,
                    "lop_hoc_phan": qs,
                }
            ).data
        )
