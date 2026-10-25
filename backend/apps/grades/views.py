"""API điểm: nhập cả lớp / khóa / duyệt (GV-10, PDT-12), `grades/my` (SV-11), danh sách duyệt (PĐT)."""

from django.db.models import Count, Q
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.audit.models import HanhDong
from apps.auth.models import Role
from apps.grades import services
from apps.grades.models import Grade, TrangThaiDiem
from apps.grades.serializers import (
    ApproveResultSerializer,
    GradeSheetListRowSerializer,
    GradeSheetSerializer,
    GradesPutSerializer,
    LockSerializer,
    MyGradesSerializer,
)
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import ClassSection, TrangThaiLop
from core.mixins import write_audit
from core.pagination import StandardPagination
from core.permissions import HasRole, IsGiaoVien, IsPhongDaoTao, IsSinhVien


class IsGiaoVienOrPdt(HasRole):
    roles = (Role.GIAO_VIEN, Role.PHONG_DAO_TAO)


def _lop(pk):
    lop = (
        ClassSection.objects.select_related("giao_vien", "mon_hoc", "hoc_ky").filter(pk=pk).first()
    )
    if lop is None:
        raise NotFound("Không tìm thấy lớp học phần.")
    return lop


def _xem(request, pk):
    lop = _lop(pk)
    if request.user.role == Role.GIAO_VIEN:
        services.kiem_tra_gv_lop(request.user, lop)  # BR-12/23
    return lop


class ClassGradesView(APIView):
    """`GET/PUT /api/class-sections/{id}/grades/`."""

    permission_classes = [IsGiaoVienOrPdt]

    @extend_schema(responses=GradeSheetSerializer)
    def get(self, request, pk):
        lop = _xem(request, pk)
        return Response(GradeSheetSerializer(services.bang_diem_lop(lop, request.user)).data)

    @extend_schema(request=GradesPutSerializer, responses=GradeSheetSerializer)
    def put(self, request, pk):
        """Nhập/sửa điểm. GV: lưu `NHAP_TAM` (lớp mình, đang học, trong hạn). PĐT: **nhập hộ**, lưu
        thẳng `CHINH_THUC` (BR-13/14); tự ghi audit log."""
        lop = _xem(request, pk)
        s = GradesPutSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        lop, so_dong = services.luu_diem(lop.id, request.user, s.validated_data["records"])
        write_audit(
            request,
            HanhDong.UPDATE,
            "Grade",
            lop.id,
            {
                "hanh_dong": "nhap_ho" if request.user.role == Role.PHONG_DAO_TAO else "nhap_diem",
                "lop_hoc_phan": lop.id,
                "so_dong": so_dong,
            },
        )
        lop = _lop(lop.id)
        return Response(GradeSheetSerializer(services.bang_diem_lop(lop, request.user)).data)


class ClassGradesLockView(APIView):
    """`POST /api/class-sections/{id}/grades/lock/` `{action: lock|unlock}` — GV, cả lớp (BR-14)."""

    permission_classes = [IsGiaoVien]

    @extend_schema(request=LockSerializer, responses=GradeSheetSerializer)
    def post(self, request, pk):
        lop = _xem(request, pk)
        s = LockSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        khoa = s.validated_data["action"] == "lock"
        n = services.doi_khoa_lop(lop.id, request.user, khoa)
        write_audit(
            request,
            HanhDong.UPDATE,
            "Grade",
            lop.id,
            {"hanh_dong": "khoa_diem" if khoa else "mo_khoa_diem", "so_dong": n},
        )
        return Response(
            GradeSheetSerializer(services.bang_diem_lop(_lop(lop.id), request.user)).data
        )


class ClassGradesApproveView(APIView):
    """`POST /api/class-sections/{id}/grades/approve/` — PĐT duyệt cả lớp `DA_DONG` → `KHOA` (PDT-12)."""

    permission_classes = [IsPhongDaoTao]

    @extend_schema(request=None, responses=ApproveResultSerializer)
    def post(self, request, pk):
        lop = _lop(pk)
        n = services.duyet_lop(lop.id)
        write_audit(
            request,
            HanhDong.UPDATE,
            "Grade",
            lop.id,
            {"hanh_dong": "duyet_diem", "so_sinh_vien": n},
        )
        return Response({"so_sinh_vien": n})


class MyGradesView(APIView):
    """`GET /api/grades/my/` (SV-11): chỉ điểm `KHOA` + GPA + thống kê từng học kỳ (BR-25g)."""

    permission_classes = [IsSinhVien]

    @extend_schema(responses=MyGradesSerializer)
    def get(self, request):
        tong = services.tong_hop_diem(request.user)
        diem = [
            {
                "hoc_ky": g.lop_hoc_phan.hoc_ky_id,
                "ten_hk": g.lop_hoc_phan.hoc_ky.ten_hk,
                "ma_lop": g.lop_hoc_phan.ma_lop,
                "ma_mon": g.lop_hoc_phan.mon_hoc.ma_mon,
                "ten_mon": g.lop_hoc_phan.mon_hoc.ten_mon,
                "tin_chi": g.lop_hoc_phan.mon_hoc.tong_tin_chi,
                "diem_qua_trinh": g.diem_qua_trinh,
                "diem_giua_ky": g.diem_giua_ky,
                "diem_cuoi_ky": g.diem_cuoi_ky,
                "diem_tong_ket": g.diem_tong_ket,
                "diem_chu": g.diem_chu,
                "gpa_thang_4": g.gpa_thang_4,
            }
            for g in Grade.objects.filter(sinh_vien=request.user, trang_thai=TrangThaiDiem.KHOA)
            .select_related("lop_hoc_phan__mon_hoc", "lop_hoc_phan__hoc_ky")
            .order_by("-lop_hoc_phan__hoc_ky__ngay_bat_dau", "lop_hoc_phan__mon_hoc__ma_mon")
        ]
        return Response(MyGradesSerializer({**tong, "diem": diem}).data)


class GradeSheetListView(APIView):
    """`GET /api/grade-sheets/` (PĐT): lớp `DANG_HOC`/`DA_DONG` kèm số dòng điểm theo trạng thái,
    để duyệt điểm."""

    permission_classes = [IsPhongDaoTao]

    @extend_schema(
        parameters=[
            OpenApiParameter("hoc_ky", int),
            OpenApiParameter("nganh", int),
            OpenApiParameter("trang_thai", str),
            OpenApiParameter("search", str),
            OpenApiParameter("page", int),
            OpenApiParameter("page_size", int),
        ],
        responses=GradeSheetListRowSerializer(many=True),
    )
    def get(self, request):
        qs = (
            ClassSection.objects.filter(
                trang_thai__in=[TrangThaiLop.DANG_HOC, TrangThaiLop.DA_DONG]
            )
            .select_related("mon_hoc", "hoc_ky", "giao_vien")
            .annotate(
                nhap_tam=Count("diem", filter=Q(diem__trang_thai=TrangThaiDiem.NHAP_TAM)),
                chinh_thuc=Count("diem", filter=Q(diem__trang_thai=TrangThaiDiem.CHINH_THUC)),
                khoa=Count("diem", filter=Q(diem__trang_thai=TrangThaiDiem.KHOA)),
            )
            .order_by("-hoc_ky__ngay_bat_dau", "ma_lop")
        )
        p = request.query_params
        if p.get("hoc_ky"):
            qs = qs.filter(hoc_ky=p["hoc_ky"])
        if p.get("nganh"):
            qs = qs.filter(mon_hoc__mon_ctdt__ctdt__nganh=p["nganh"]).distinct()
        if p.get("trang_thai"):
            qs = qs.filter(trang_thai=p["trang_thai"])
        if p.get("search"):
            t = p["search"].strip()
            qs = qs.filter(
                Q(ma_lop__icontains=t)
                | Q(mon_hoc__ten_mon__icontains=t)
                | Q(mon_hoc__ma_mon__icontains=t)
            )
        so_sv = dict(
            Registration.objects.filter(trang_thai=TrangThaiDangKy.DA_DANG_KY)
            .values_list("lop_hoc_phan")
            .annotate(n=Count("id"))
        )
        pg = StandardPagination()
        page = pg.paginate_queryset(qs, request, view=self)
        rows = [
            {
                "id": c.id,
                "ma_lop": c.ma_lop,
                "ten_mon": c.mon_hoc.ten_mon,
                "ten_hk": c.hoc_ky.ten_hk,
                "giao_vien_ten": c.giao_vien.ho_ten,
                "trang_thai": c.trang_thai,
                "so_sv": so_sv.get(c.id, 0),
                "nhap_tam": c.nhap_tam,
                "chinh_thuc": c.chinh_thuc,
                "khoa": c.khoa,
            }
            for c in page
        ]
        return pg.get_paginated_response(GradeSheetListRowSerializer(rows, many=True).data)
