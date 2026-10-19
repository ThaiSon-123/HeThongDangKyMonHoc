"""API dữ liệu đào tạo — chỉ PĐT (PDT-02..09, ma trận quyền mục 9)."""

import django_filters
from django.db.models import Count, Q
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.audit.models import HanhDong
from apps.auth.models import Role
from apps.training import services
from apps.training.models import (
    ClassSection,
    Course,
    Curriculum,
    CurriculumCourse,
    Faculty,
    Major,
    Prerequisite,
    Schedule,
    Semester,
    TrangThaiDung,
    TrangThaiLop,
    TrangThaiMon,
)
from apps.training.serializers import (
    ClassSectionSerializer,
    CourseSerializer,
    CurriculumCourseSerializer,
    CurriculumSerializer,
    FacultySerializer,
    GradeDeadlineSerializer,
    MajorSerializer,
    PrerequisiteSerializer,
    ScheduleSerializer,
    SemesterSerializer,
    SemesterWindowSerializer,
)
from apps.training.teacher import MyClassSerializer, lop_cua_gv, lop_cua_toi
from core.exceptions import business_error
from core.mixins import AuditLogMixin
from core.pagination import StandardPagination
from core.permissions import HasRole, IsGiaoVien, IsPhongDaoTao, PdtWriteKtRead


class _PdtViewSet(AuditLogMixin):
    permission_classes = [IsPhongDaoTao]
    http_method_names = ["get", "post", "patch", "head", "options"]
    ordering = ["-id"]


class _CoXoaViewSet(_PdtViewSet):
    """Bản ghi nối / lịch: sai thì xóa được (khác nhóm danh mục chỉ ngừng)."""

    http_method_names = [*_PdtViewSet.http_method_names, "delete"]


class FacultyViewSet(_PdtViewSet):
    audit_model = "Faculty"
    queryset = Faculty.objects.annotate(
        so_nganh=Count("nganh", filter=Q(nganh__trang_thai=TrangThaiDung.HOAT_DONG), distinct=True),
        so_giao_vien=Count("giao_vien", filter=Q(giao_vien__user__is_locked=False), distinct=True),
        so_mon=Count(
            "mon_hoc", filter=Q(mon_hoc__trang_thai=TrangThaiMon.HOAT_DONG), distinct=True
        ),
    )
    serializer_class = FacultySerializer
    filterset_fields = ["trang_thai"]
    search_fields = ["ma_khoa", "ten_khoa"]
    ordering_fields = ["id", "ma_khoa", "ten_khoa"]


class MajorViewSet(_PdtViewSet):
    permission_classes = [PdtWriteKtRead]  # KT chỉ đọc
    audit_model = "Major"
    queryset = Major.objects.select_related("khoa").annotate(
        so_ctdt=Count("ctdts", filter=Q(ctdts__trang_thai=TrangThaiDung.HOAT_DONG))
    )
    serializer_class = MajorSerializer
    filterset_fields = ["khoa", "trang_thai"]
    search_fields = ["ma_nganh", "ten_nganh"]
    ordering_fields = ["id", "ma_nganh", "ten_nganh"]


class CurriculumViewSet(_PdtViewSet):
    audit_model = "Curriculum"
    queryset = Curriculum.objects.select_related("nganh")
    serializer_class = CurriculumSerializer
    filterset_fields = ["nganh", "khoa_tuyen_sinh", "trang_thai"]
    search_fields = ["ma_ctdt", "nganh__ten_nganh"]
    ordering_fields = ["id", "ma_ctdt", "khoa_tuyen_sinh"]


class CurriculumCourseViewSet(_CoXoaViewSet):
    audit_model = "CurriculumCourse"
    queryset = CurriculumCourse.objects.select_related("mon_hoc")
    serializer_class = CurriculumCourseSerializer
    filterset_fields = ["ctdt", "mon_hoc", "khoi_kien_thuc", "loai_mon", "hoc_ky_goi_y"]
    search_fields = ["mon_hoc__ma_mon", "mon_hoc__ten_mon"]
    ordering_fields = ["id", "hoc_ky_goi_y", "mon_hoc__ma_mon"]


class CourseFilter(django_filters.FilterSet):
    nganh = django_filters.NumberFilter(
        field_name="mon_ctdt__ctdt__nganh", distinct=True, help_text="Môn thuộc CTĐT của ngành"
    )

    class Meta:
        model = Course
        fields = ["khoa", "trang_thai", "loai_danh_gia"]


class CourseViewSet(_PdtViewSet):
    audit_model = "Course"
    queryset = Course.objects.select_related("khoa")
    serializer_class = CourseSerializer
    filterset_class = CourseFilter
    search_fields = ["ma_mon", "ten_mon"]
    ordering_fields = ["id", "ma_mon", "ten_mon"]


class PrerequisiteViewSet(_CoXoaViewSet):
    audit_model = "Prerequisite"
    http_method_names = ["get", "post", "delete", "head", "options"]  # cặp cố định: thêm / xóa
    queryset = Prerequisite.objects.select_related("mon_hoc", "mon_tien_quyet")
    serializer_class = PrerequisiteSerializer
    filterset_fields = ["mon_hoc", "mon_tien_quyet"]
    search_fields = ["mon_hoc__ma_mon", "mon_tien_quyet__ma_mon"]
    ordering_fields = ["id"]


class SemesterViewSet(_PdtViewSet):
    permission_classes = [PdtWriteKtRead]  # KT chỉ đọc
    audit_model = "Semester"
    queryset = Semester.objects.all()
    serializer_class = SemesterSerializer
    filterset_fields = ["trang_thai", "nam_hoc"]
    search_fields = ["ten_hk", "nam_hoc"]
    ordering_fields = ["id", "ngay_bat_dau"]

    def _doi_trang_thai(self, ham):
        hoc_ky = ham(self.get_object())
        self._audit(HanhDong.UPDATE, hoc_ky, {"trang_thai": hoc_ky.trang_thai})
        return Response(self.get_serializer(hoc_ky).data)

    @extend_schema(request=None, responses=SemesterSerializer)
    @action(detail=True, methods=["post"])
    def open(self, request, pk=None):
        return self._doi_trang_thai(services.mo_hoc_ky)

    @extend_schema(request=None, responses=SemesterSerializer)
    @action(detail=True, methods=["post"])
    def close(self, request, pk=None):
        return self._doi_trang_thai(services.dong_hoc_ky)

    @extend_schema(request=SemesterWindowSerializer, responses=SemesterSerializer)
    @action(detail=True, methods=["patch"])
    def window(self, request, pk=None):
        hoc_ky = self.get_object()
        cua_so = SemesterWindowSerializer(data=request.data)
        cua_so.is_valid(raise_exception=True)
        s = SemesterSerializer(hoc_ky, data=cua_so.validated_data, partial=True)
        s.is_valid(raise_exception=True)
        hoc_ky = self.perform_update(s)
        return Response(SemesterSerializer(hoc_ky).data)


class ClassSectionFilter(django_filters.FilterSet):
    nganh = django_filters.NumberFilter(
        field_name="mon_hoc__mon_ctdt__ctdt__nganh",
        distinct=True,
        help_text="Môn thuộc CTĐT của ngành",
    )
    khoa = django_filters.NumberFilter(
        field_name="mon_hoc__khoa", help_text="Khoa/viện phụ trách môn"
    )

    class Meta:
        model = ClassSection
        fields = ["hoc_ky", "mon_hoc", "giao_vien", "trang_thai"]


class IsPdtKtOrGiaoVien(HasRole):
    roles = (Role.PHONG_DAO_TAO, Role.KE_TOAN, Role.GIAO_VIEN)


class ClassSectionViewSet(_PdtViewSet):
    permission_classes = [PdtWriteKtRead]  # KT chỉ đọc; GV chỉ xem chi tiết lớp mình (`retrieve`)
    audit_model = "ClassSection"
    queryset = (
        ClassSection.objects.select_related("mon_hoc", "hoc_ky", "giao_vien")
        .prefetch_related("lich_hoc")
        .annotate(so_buoi=Count("buoi_diem_danh", distinct=True))
    )
    serializer_class = ClassSectionSerializer
    filterset_class = ClassSectionFilter
    search_fields = ["ma_lop", "mon_hoc__ma_mon", "mon_hoc__ten_mon", "giao_vien__ho_ten"]
    ordering_fields = ["id", "ma_lop", "ngay_bat_dau"]

    def get_permissions(self):
        return [IsPdtKtOrGiaoVien()] if self.action == "retrieve" else super().get_permissions()

    def retrieve(self, request, *args, **kwargs):
        """GV-04: GV chỉ xem lớp mình phụ trách (BR-23); PĐT/KT xem mọi lớp."""
        lop = self.get_object()
        if request.user.role == Role.GIAO_VIEN:
            lop_cua_gv(request.user, lop.pk)
        return Response(self.get_serializer(lop).data)

    def perform_update(self, serializer):
        lop = super().perform_update(serializer)
        services.dong_bo_buoi_diem_danh(lop)  # ngày bắt đầu/kết thúc có thể đã đổi (BR-20)
        doi = {"ngay_bat_dau", "ngay_ket_thuc", "giao_vien"} & set(serializer.validated_data)
        if doi:
            services.bao_doi_lich(
                lop,
                self.request.user,
                "Phòng đào tạo đã cập nhật thời gian hoặc giáo viên của lớp.",
            )
        return lop

    def _doi_trang_thai(self, ham):
        lop = ham(self.get_object())
        self._audit(HanhDong.UPDATE, lop, {"trang_thai": lop.trang_thai})
        return Response(self.get_serializer(self.get_queryset().get(pk=lop.pk)).data)

    @extend_schema(request=None, responses=ClassSectionSerializer)
    @action(detail=True, methods=["post"])
    def open(self, request, pk=None):
        return self._doi_trang_thai(services.mo_lop)

    @extend_schema(request=None, responses=ClassSectionSerializer)
    @action(detail=True, methods=["post"])
    def close(self, request, pk=None):
        return self._doi_trang_thai(services.dong_lop)

    @extend_schema(request=GradeDeadlineSerializer, responses=ClassSectionSerializer)
    @action(detail=True, methods=["post"], url_path="grade-deadline")
    def grade_deadline(self, request, pk=None):
        """Gia hạn nhập điểm (BR-13): đặt `han_nhap_diem` mới, ghi audit log."""
        lop = self.get_object()
        services.kiem_tra_sua_lop(lop)
        s = GradeDeadlineSerializer(data=request.data, context={"lop": lop})
        s.is_valid(raise_exception=True)
        cu = lop.han_nhap_diem
        lop.han_nhap_diem = s.validated_data["han_nhap_diem"]
        lop.save(update_fields=["han_nhap_diem"])
        self._audit(
            HanhDong.UPDATE,
            lop,
            {
                "hanh_dong": "gia_han_nhap_diem",
                "tu": str(cu) if cu else None,
                "den": str(lop.han_nhap_diem),
            },
        )
        return Response(self.get_serializer(lop).data)


def _mo_ta(lich):
    thu = "Chủ nhật" if lich.thu == 8 else f"Thứ {lich.thu}"
    return f"{thu}, tiết {lich.tiet_bat_dau}–{lich.tiet_ket_thuc}, phòng {lich.phong}"


class ScheduleViewSet(_CoXoaViewSet):
    audit_model = "Schedule"
    queryset = Schedule.objects.select_related("lop_hoc_phan")
    serializer_class = ScheduleSerializer
    filterset_fields = ["lop_hoc_phan", "thu"]
    search_fields = ["phong", "lop_hoc_phan__ma_lop"]
    ordering_fields = ["id", "thu", "tiet_bat_dau"]

    def perform_create(self, serializer):
        lich = super().perform_create(serializer)
        services.dong_bo_buoi_diem_danh(lich.lop_hoc_phan)  # BR-20
        services.bao_doi_lich(
            lich.lop_hoc_phan, self.request.user, f"Thêm buổi học {_mo_ta(lich)}."
        )
        return lich

    def perform_update(self, serializer):
        lich = super().perform_update(serializer)
        services.dong_bo_buoi_diem_danh(lich.lop_hoc_phan)
        services.bao_doi_lich(
            lich.lop_hoc_phan, self.request.user, f"Buổi học đổi thành {_mo_ta(lich)}."
        )
        return lich

    def perform_destroy(self, instance):
        lop = instance.lop_hoc_phan
        services.kiem_tra_sua_lop(lop)
        if lop.trang_thai != TrangThaiLop.KE_HOACH and lop.lich_hoc.count() == 1:
            raise business_error(
                "TRANG_THAI_KHONG_HOP_LE", "Lớp đã mở phải còn ít nhất một lịch học."
            )
        mo_ta = _mo_ta(instance)
        super().perform_destroy(instance)
        services.dong_bo_buoi_diem_danh(lop)
        services.bao_doi_lich(lop, self.request.user, f"Bỏ buổi học {mo_ta}.")


class MyClassSectionsView(APIView):
    """`GET /api/class-sections/my/` (GV-03): lớp tôi phụ trách, mới nhất trước. Lọc `?hoc_ky=`,
    `?trang_thai=`."""

    permission_classes = [IsGiaoVien]

    @extend_schema(
        parameters=[
            OpenApiParameter("hoc_ky", int),
            OpenApiParameter("trang_thai", str),
            OpenApiParameter("page", int),
            OpenApiParameter("page_size", int),
        ],
        responses=MyClassSerializer(many=True),
    )
    def get(self, request):
        qs = (
            lop_cua_toi(request.user)
            .select_related("mon_hoc", "giao_vien", "hoc_ky")
            .prefetch_related("lich_hoc")
            .order_by("-hoc_ky__ngay_bat_dau", "ma_lop")
        )
        hoc_ky_id = request.query_params.get("hoc_ky")
        if hoc_ky_id:
            qs = qs.filter(hoc_ky=services.chon_hoc_ky(hoc_ky_id))
        if request.query_params.get("trang_thai"):
            qs = qs.filter(trang_thai=request.query_params["trang_thai"])
        paginator = StandardPagination()
        page = paginator.paginate_queryset(qs, request, view=self)
        return paginator.get_paginated_response(MyClassSerializer(page, many=True).data)
