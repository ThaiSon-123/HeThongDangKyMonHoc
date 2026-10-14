"""Báo cáo đào tạo (PDT-14): `GET /api/reports/training/` và `/export/` (Excel)."""

from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import ClassSection, TrangThaiLop
from apps.training.services import chon_hoc_ky
from core.export import XLSX, xlsx_nhieu_sheet
from core.permissions import IsPhongDaoTao
from core.utils import int_param

PARAMS = [
    OpenApiParameter("hoc_ky", int, description="Mặc định: học kỳ hiện tại / `MO` gần nhất"),
    OpenApiParameter("nganh", int, description="Môn thuộc CTĐT của ngành"),
    OpenApiParameter("mon_hoc", int),
]


class TongSerializer(serializers.Serializer):
    so_sinh_vien = serializers.IntegerField()
    so_lop = serializers.IntegerField()
    tong_luot_dang_ky = serializers.IntegerField()
    lop_day = serializers.IntegerField()
    lop_con_cho = serializers.IntegerField()


class TheoMonSerializer(serializers.Serializer):
    mon_hoc = serializers.IntegerField()
    ma_mon = serializers.CharField()
    ten_mon = serializers.CharField()
    luot_dang_ky = serializers.IntegerField()


class TheoLopSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    ma_lop = serializers.CharField()
    ten_mon = serializers.CharField()
    giao_vien_ten = serializers.CharField()
    si_so_hien_tai = serializers.IntegerField()
    si_so_toi_da = serializers.IntegerField()
    ty_le_lap_day = serializers.FloatField()
    trang_thai = serializers.CharField()


class TrainingReportSerializer(serializers.Serializer):
    hoc_ky = serializers.IntegerField()
    ten_hk = serializers.CharField()
    tong = TongSerializer()
    theo_mon = TheoMonSerializer(many=True)
    theo_lop = TheoLopSerializer(many=True)


def bao_cao_dao_tao(hoc_ky, nganh=None, mon_hoc=None):
    """Lớp của học kỳ (trừ `KE_HOACH`, chưa mở), lọc theo ngành (qua CTĐT) / môn.
    `lop_day` + `lop_con_cho` = số lớp đang `MO` (còn nhận đăng ký): hết chỗ / còn chỗ."""
    lops = ClassSection.objects.filter(hoc_ky=hoc_ky).exclude(trang_thai=TrangThaiLop.KE_HOACH)
    if nganh:
        lops = lops.filter(mon_hoc__mon_ctdt__ctdt__nganh=nganh).distinct()
    if mon_hoc:
        lops = lops.filter(mon_hoc=mon_hoc)
    lops = list(lops.select_related("mon_hoc", "giao_vien").order_by("ma_lop"))

    theo_lop = [
        {
            "id": lop.id,
            "ma_lop": lop.ma_lop,
            "ten_mon": lop.mon_hoc.ten_mon,
            "giao_vien_ten": lop.giao_vien.ho_ten,
            "si_so_hien_tai": lop.si_so_hien_tai,
            "si_so_toi_da": lop.si_so_toi_da,
            "ty_le_lap_day": (
                round(100 * lop.si_so_hien_tai / lop.si_so_toi_da, 1) if lop.si_so_toi_da else 0.0
            ),
            "trang_thai": lop.trang_thai,
        }
        for lop in lops
    ]
    theo_mon = {}
    for lop in lops:
        m = theo_mon.setdefault(
            lop.mon_hoc_id,
            {
                "mon_hoc": lop.mon_hoc_id,
                "ma_mon": lop.mon_hoc.ma_mon,
                "ten_mon": lop.mon_hoc.ten_mon,
                "luot_dang_ky": 0,
            },
        )
        m["luot_dang_ky"] += lop.si_so_hien_tai
    dang_mo = [lop for lop in lops if lop.trang_thai == TrangThaiLop.MO]
    so_day = sum(1 for lop in dang_mo if lop.si_so_hien_tai >= lop.si_so_toi_da)
    so_sinh_vien = (
        Registration.objects.filter(
            lop_hoc_phan__in=[lop.id for lop in lops], trang_thai=TrangThaiDangKy.DA_DANG_KY
        )
        .values("sinh_vien")
        .distinct()
        .count()
    )
    return {
        "hoc_ky": hoc_ky.id,
        "ten_hk": hoc_ky.ten_hk,
        "tong": {
            "so_sinh_vien": so_sinh_vien,
            "so_lop": len(lops),
            "tong_luot_dang_ky": sum(lop.si_so_hien_tai for lop in lops),
            "lop_day": so_day,
            "lop_con_cho": len(dang_mo) - so_day,
        },
        "theo_mon": sorted(theo_mon.values(), key=lambda m: (-m["luot_dang_ky"], m["ma_mon"])),
        "theo_lop": sorted(theo_lop, key=lambda r: (-r["ty_le_lap_day"], r["ma_lop"])),
    }


def _bao_cao(request):
    return bao_cao_dao_tao(
        chon_hoc_ky(request.query_params.get("hoc_ky")),
        int_param(request, "nganh"),
        int_param(request, "mon_hoc"),
    )


class TrainingReportView(APIView):
    permission_classes = [IsPhongDaoTao]

    @extend_schema(parameters=PARAMS, responses=TrainingReportSerializer)
    def get(self, request):
        return Response(_bao_cao(request))


class TrainingReportExportView(APIView):
    permission_classes = [IsPhongDaoTao]

    @extend_schema(parameters=PARAMS, responses={(200, XLSX): OpenApiTypes.BINARY})
    def get(self, request):
        r = _bao_cao(request)
        t = r["tong"]
        return xlsx_nhieu_sheet(
            "bao_cao_dao_tao.xlsx",
            [
                (
                    "Tổng quan",
                    ["Chỉ tiêu", "Giá trị"],
                    [
                        ("Học kỳ", r["ten_hk"]),
                        ("Số sinh viên", t["so_sinh_vien"]),
                        ("Số lớp", t["so_lop"]),
                        ("Tổng lượt đăng ký", t["tong_luot_dang_ky"]),
                        ("Lớp đầy", t["lop_day"]),
                        ("Lớp còn chỗ", t["lop_con_cho"]),
                    ],
                ),
                (
                    "Theo môn",
                    ["Mã môn", "Tên môn", "Lượt đăng ký"],
                    [(m["ma_mon"], m["ten_mon"], m["luot_dang_ky"]) for m in r["theo_mon"]],
                ),
                (
                    "Theo lớp",
                    [
                        "Mã lớp",
                        "Môn học",
                        "Giáo viên",
                        "Sĩ số",
                        "Sĩ số tối đa",
                        "Lấp đầy (%)",
                        "Trạng thái",
                    ],
                    [
                        (
                            c["ma_lop"],
                            c["ten_mon"],
                            c["giao_vien_ten"],
                            c["si_so_hien_tai"],
                            c["si_so_toi_da"],
                            c["ty_le_lap_day"],
                            TrangThaiLop(c["trang_thai"]).label,
                        )
                        for c in r["theo_lop"]
                    ],
                ),
            ],
        )
