"""Giáo viên xem lớp mình phụ trách: danh sách SV (GV-04) và xuất Excel (GV-12). BR-12/23."""

from datetime import date

from django.db.models import Exists, OuterRef
from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import extend_schema
from rest_framework import serializers
from rest_framework.exceptions import NotFound
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.attendance.models import Attendance, TrangThaiDiemDanh
from apps.attendance.services import chi_so_vang, thong_ke_lop
from apps.auth.models import Role
from apps.grades import services as grades
from apps.grades.models import Grade, TrangThaiDiem
from apps.registration.serializers import ClassBriefSerializer
from apps.training.models import ClassSection
from apps.training.serializers import han_nhap_diem_cua
from core.export import XLSX, xlsx_nhieu_sheet
from core.permissions import HasRole, IsGiaoVien


def _lop(pk):
    lop = (
        ClassSection.objects.select_related("giao_vien", "mon_hoc", "hoc_ky").filter(pk=pk).first()
    )
    if lop is None:
        raise NotFound("Không tìm thấy lớp học phần.")
    return lop


def lop_cua_gv(user, pk):
    """Lớp `pk` do `user` phụ trách; lớp của GV khác → `403 KHONG_CO_QUYEN` (BR-23)."""
    lop = _lop(pk)
    grades.kiem_tra_gv_lop(user, lop)
    return lop


class IsGiaoVienOrPdt(HasRole):
    roles = (Role.GIAO_VIEN, Role.PHONG_DAO_TAO)


def lop_cua_toi(user):
    """Lớp tôi phụ trách kèm `diem_da_duyet` (đã có điểm `KHOA`); dùng cho `class-sections/my/`."""
    return ClassSection.objects.filter(giao_vien__user=user).annotate(
        diem_da_duyet=Exists(
            Grade.objects.filter(lop_hoc_phan=OuterRef("pk"), trang_thai=TrangThaiDiem.KHOA)
        )
    )


class MyClassSerializer(ClassBriefSerializer):
    ten_hk = serializers.CharField(source="hoc_ky.ten_hk", read_only=True)
    han_nhap_diem_hieu_luc = serializers.SerializerMethodField()
    diem_da_duyet = serializers.BooleanField(read_only=True)

    class Meta(ClassBriefSerializer.Meta):
        fields = [
            *ClassBriefSerializer.Meta.fields,
            "ten_hk",
            "han_nhap_diem_hieu_luc",
            "diem_da_duyet",
        ]
        read_only_fields = fields

    def get_han_nhap_diem_hieu_luc(self, obj) -> date:
        return han_nhap_diem_cua(self, obj)


class ClassStudentSerializer(serializers.Serializer):
    sinh_vien = serializers.IntegerField()
    ma_sv = serializers.CharField()
    ho_ten = serializers.CharField()
    nganh_ten = serializers.CharField()


class ClassStudentsSerializer(serializers.Serializer):
    lop_hoc_phan = serializers.IntegerField()
    si_so = serializers.IntegerField()
    si_so_toi_da = serializers.IntegerField()
    records = ClassStudentSerializer(many=True)


def _sinh_vien(lop):
    return [
        {
            "sinh_vien": r.sinh_vien_id,
            "ma_sv": r.sinh_vien.sinh_vien.ma_sv,
            "ho_ten": r.sinh_vien.sinh_vien.ho_ten,
            "nganh_ten": r.sinh_vien.sinh_vien.nganh.ten_nganh,
        }
        for r in grades.sinh_vien_lop(lop)
    ]


class ClassStudentsView(APIView):
    """`GET /api/class-sections/{id}/students/` (GV-04): SV đang đăng ký lớp mình."""

    permission_classes = [IsGiaoVien]

    @extend_schema(responses=ClassStudentsSerializer)
    def get(self, request, pk):
        lop = lop_cua_gv(request.user, pk)
        records = _sinh_vien(lop)
        return Response(
            {
                "lop_hoc_phan": lop.id,
                "si_so": len(records),
                "si_so_toi_da": lop.si_so_toi_da,
                "records": records,
            }
        )


KY_HIEU = {
    TrangThaiDiemDanh.VANG_CO_PHEP: "P",
    TrangThaiDiemDanh.VANG_KHONG_PHEP: "V",
}


def _so(diem):
    return None if diem is None else float(diem)


def _o_diem_danh(trang_thai, di_tre):
    if trang_thai == TrangThaiDiemDanh.CO_MAT:
        return "T" if di_tre else "x"
    return KY_HIEU[trang_thai]


class ClassExportView(APIView):
    """`GET /api/class-sections/{id}/export/` (GV-12): Excel gồm danh sách SV, bảng điểm, điểm danh.
    GV chỉ lớp mình; PĐT mọi lớp (ma trận quyền mục 9)."""

    permission_classes = [IsGiaoVienOrPdt]

    @extend_schema(responses={(200, XLSX): OpenApiTypes.BINARY})
    def get(self, request, pk):
        lop = lop_cua_gv(request.user, pk) if request.user.role == Role.GIAO_VIEN else _lop(pk)
        sv = _sinh_vien(lop)
        danh_sach = [(i, s["ma_sv"], s["ho_ten"], s["nganh_ten"]) for i, s in enumerate(sv, 1)]

        nhan = {t.value: t.label for t in TrangThaiDiem}
        bang_diem = [
            (
                r["ma_sv"],
                r["ho_ten"],
                *(_so(r[k]) for k in ("diem_qua_trinh", "diem_giua_ky", "diem_cuoi_ky")),
                _so(r["diem_tong_ket"]),
                r["diem_chu"],
                nhan.get(r["trang_thai"], "Chưa nhập"),
            )
            for r in grades.bang_diem_lop(lop, request.user)["records"]
        ]

        buoi = list(lop.buoi_diem_danh.order_by("ngay_hoc", "tiet_bat_dau", "id"))
        o = {
            (a["sinh_vien_id"], a["attendance_session_id"]): _o_diem_danh(
                a["trang_thai"], a["di_tre"]
            )
            for a in Attendance.objects.filter(lop_hoc_phan=lop).values(
                "sinh_vien_id", "attendance_session_id", "trang_thai", "di_tre"
            )
        }
        tong, thong_ke = thong_ke_lop(lop)
        diem_danh = []
        for s in sv:
            tk = thong_ke.get(s["sinh_vien"], {})
            vang_kp = tk.get("so_vang_kp", 0)
            diem_danh.append(
                (
                    s["ma_sv"],
                    s["ho_ten"],
                    *(o.get((s["sinh_vien"], b.id), "") for b in buoi),
                    vang_kp,
                    tk.get("so_vang_co_phep", 0),
                    chi_so_vang(tong, vang_kp)["ty_le_vang"],
                )
            )
        diem_danh += [(), ("Ký hiệu: x có mặt · T đi trễ · P vắng có phép · V vắng không phép",)]

        return xlsx_nhieu_sheet(
            f"{lop.ma_lop}.xlsx",
            [
                ("Danh sách SV", ["STT", "Mã SV", "Họ tên", "Ngành"], danh_sach),
                (
                    "Bảng điểm",
                    [
                        "Mã SV",
                        "Họ tên",
                        "Quá trình",
                        "Giữa kỳ",
                        "Cuối kỳ",
                        "Tổng kết",
                        "Điểm chữ",
                        "Trạng thái",
                    ],
                    bang_diem,
                ),
                (
                    "Điểm danh",
                    [
                        "Mã SV",
                        "Họ tên",
                        *(f"{b.ngay_hoc:%d/%m} T{b.tiet_bat_dau}" for b in buoi),
                        "Vắng KP",
                        "Vắng có phép",
                        "Tỷ lệ vắng (%)",
                    ],
                    diem_danh,
                ),
            ],
        )
