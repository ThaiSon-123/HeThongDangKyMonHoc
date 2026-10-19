"""Báo cáo tài chính (KT-11): `GET /api/reports/finance/` và `/export/` (Excel).

Cùng bộ lọc với `GET /api/tuition/` (`hoc_ky`, `nganh`, `lop_hoc_phan`, `sinh_vien`); bảng chi tiết
từng SV lấy từ chính endpoint đó, báo cáo chỉ tổng hợp + xuất file."""

from decimal import Decimal

from drf_spectacular.types import OpenApiTypes
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.training.services import chon_hoc_ky
from apps.tuition.serializers import TIEN
from apps.tuition.views import HOC_KY, _rows, _tuition_qs
from core.export import XLSX, xlsx_nhieu_sheet
from core.permissions import IsKeToan

PARAMS = [
    HOC_KY,
    OpenApiParameter("nganh", int),
    OpenApiParameter("lop_hoc_phan", int),
    OpenApiParameter("sinh_vien", int),
]
TRANG_THAI = {
    "CHUA_TINH": "Chưa tính",
    "CON_NO": "Còn nợ",
    "CHO_HOAN_TIEN": "Chờ hoàn tiền",
    "DA_DONG": "Đã đóng đủ",
}


class FinanceTongSerializer(serializers.Serializer):
    phai_thu = serializers.DecimalField(**TIEN)
    da_thu = serializers.DecimalField(**TIEN)
    con_no = serializers.DecimalField(**TIEN)
    cho_hoan = serializers.DecimalField(**TIEN)
    so_sinh_vien = serializers.IntegerField()
    so_chua_tinh = serializers.IntegerField()
    so_con_no = serializers.IntegerField()
    so_qua_han = serializers.IntegerField()
    so_cho_hoan = serializers.IntegerField()


class FinanceNganhSerializer(serializers.Serializer):
    nganh_ma = serializers.CharField()
    nganh_ten = serializers.CharField()
    phai_thu = serializers.DecimalField(**TIEN)
    da_thu = serializers.DecimalField(**TIEN)


class FinanceReportSerializer(serializers.Serializer):
    hoc_ky = serializers.IntegerField()
    ten_hk = serializers.CharField()
    tong = FinanceTongSerializer()
    theo_nganh = FinanceNganhSerializer(many=True)


def tong_hop(rows):
    """Phải thu = Σ phải nộp · Đã thu = Σ thực thu (THU − HOÀN) · Còn nợ = Σ `con_no` ·
    Chờ hoàn = Σ `can_hoan`. Chỉ cộng theo từng SV nên khớp với bảng chi tiết."""
    tong = {
        "phai_thu": Decimal(0),
        "da_thu": Decimal(0),
        "con_no": Decimal(0),
        "cho_hoan": Decimal(0),
        "so_sinh_vien": len(rows),
        "so_chua_tinh": 0,
        "so_con_no": 0,
        "so_qua_han": 0,
        "so_cho_hoan": 0,
    }
    nganh = {}
    for r in rows:
        tong["phai_thu"] += r["phai_nop"]
        tong["da_thu"] += r["thuc_thu"]
        tong["con_no"] += r["con_no"]
        tong["cho_hoan"] += r["can_hoan"]
        tong["so_chua_tinh"] += r["hien_thi"] == "CHUA_TINH"
        tong["so_con_no"] += r["con_no"] > 0
        tong["so_qua_han"] += r["qua_han"]
        tong["so_cho_hoan"] += r["can_hoan"] > 0
        n = nganh.setdefault(
            r["nganh_ma"],
            {
                "nganh_ma": r["nganh_ma"],
                "nganh_ten": r["nganh_ten"],
                "phai_thu": Decimal(0),
                "da_thu": Decimal(0),
            },
        )
        n["phai_thu"] += r["phai_nop"]
        n["da_thu"] += r["thuc_thu"]
    return tong, sorted(nganh.values(), key=lambda n: (-n["phai_thu"], n["nganh_ma"]))


def _du_lieu(request):
    hoc_ky = chon_hoc_ky(request.query_params.get("hoc_ky"))
    rows = _rows(_tuition_qs(request, hoc_ky), hoc_ky)
    tong, theo_nganh = tong_hop(rows)
    return hoc_ky, rows, tong, theo_nganh


class FinanceReportView(APIView):
    permission_classes = [IsKeToan]

    @extend_schema(parameters=PARAMS, responses=FinanceReportSerializer)
    def get(self, request):
        hoc_ky, _, tong, theo_nganh = _du_lieu(request)
        data = {
            "hoc_ky": hoc_ky.id,
            "ten_hk": hoc_ky.ten_hk,
            "tong": tong,
            "theo_nganh": theo_nganh,
        }
        return Response(FinanceReportSerializer(data).data)  # tiền dạng chuỗi như mọi API học phí


class FinanceReportExportView(APIView):
    permission_classes = [IsKeToan]

    @extend_schema(parameters=PARAMS, responses={(200, XLSX): OpenApiTypes.BINARY})
    def get(self, request):
        hoc_ky, rows, tong, theo_nganh = _du_lieu(request)
        return xlsx_nhieu_sheet(
            "bao_cao_tai_chinh.xlsx",
            [
                (
                    "Tổng hợp",
                    ["Chỉ tiêu", "Giá trị"],
                    [
                        ("Học kỳ", hoc_ky.ten_hk),
                        ("Phải thu", float(tong["phai_thu"])),
                        ("Đã thu", float(tong["da_thu"])),
                        ("Còn nợ", float(tong["con_no"])),
                        ("Chờ hoàn tiền", float(tong["cho_hoan"])),
                        ("Số sinh viên", tong["so_sinh_vien"]),
                        ("SV chưa tính học phí", tong["so_chua_tinh"]),
                        ("SV còn nợ", tong["so_con_no"]),
                        ("SV quá hạn", tong["so_qua_han"]),
                        ("SV chờ hoàn tiền", tong["so_cho_hoan"]),
                    ],
                ),
                (
                    "Theo ngành",
                    ["Mã ngành", "Ngành", "Phải thu", "Đã thu"],
                    [
                        (n["nganh_ma"], n["nganh_ten"], float(n["phai_thu"]), float(n["da_thu"]))
                        for n in theo_nganh
                    ],
                ),
                (
                    "Chi tiết theo sinh viên",
                    [
                        "Mã SV",
                        "Họ tên",
                        "Ngành",
                        "Tổng tiền",
                        "Miễn giảm",
                        "Phải nộp",
                        "Đã thu",
                        "Còn nợ",
                        "Cần hoàn",
                        "Trạng thái",
                        "Hạn đóng",
                    ],
                    [
                        (
                            r["ma_sv"],
                            r["ho_ten"],
                            r["nganh_ten"],
                            float(r["tong_tien"]),
                            float(r["mien_giam"]),
                            float(r["phai_nop"]),
                            float(r["thuc_thu"]),
                            float(r["con_no"]),
                            float(r["can_hoan"]),
                            TRANG_THAI[r["hien_thi"]] + (" (quá hạn)" if r["qua_han"] else ""),
                            r["han_dong"].strftime("%d/%m/%Y") if r["han_dong"] else "",
                        )
                        for r in rows
                    ],
                ),
            ],
        )
