"""API tự điểm danh khuôn mặt + GPS (KH §10). Nghiệp vụ nằm ở `tu_diem_danh.py`."""

from django.http import Http404, HttpResponse
from django.utils import timezone
from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import serializers
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework.throttling import UserRateThrottle
from rest_framework.views import APIView

from apps.attendance import tu_diem_danh as tdd
from apps.attendance.face import checks
from apps.attendance.models import TrangThaiDiemDanh, TrangThaiMau
from apps.audit.models import HanhDong
from apps.auth.services import full_name
from core.mixins import write_audit
from core.permissions import IsGiaoVien, IsPhongDaoTao, IsSinhVien
from core.utils import client_ip, int_param


class DiemDanhThrottle(UserRateThrottle):
    """Xin thử thách / gửi lượt: chặn spam suy luận (mỗi lượt ~0,7 s CPU)."""

    rate = "20/min"


# ------------------------------------------------------------------ serializers vào


class MauGpsSerializer(serializers.Serializer):
    lat = serializers.FloatField(min_value=-90, max_value=90)
    lng = serializers.FloatField(min_value=-180, max_value=180)
    acc = serializers.FloatField(min_value=0.01)
    ts = serializers.IntegerField()
    mock = serializers.BooleanField(default=False)


def _anh(min_n, max_n):
    return serializers.ListField(child=serializers.FileField(), min_length=min_n, max_length=max_n)


def _doc_anh(files):
    out = []
    for f in files:
        if f.size > tdd.MAX_ANH_BYTES:
            raise serializers.ValidationError("Mỗi ảnh tối đa 2 MB.")
        out.append(f.read())
    return out


class DangKyMatSerializer(serializers.Serializer):
    anh = _anh(3, 5)


class MoPhienSerializer(serializers.Serializer):
    thoi_han = serializers.IntegerField(min_value=1, max_value=240, required=False)
    kiem_tra_phong = serializers.BooleanField(default=False)
    kiem_tra_gps = serializers.BooleanField(default=True)


class MoLaiSerializer(serializers.Serializer):
    thoi_han = serializers.IntegerField(min_value=1, max_value=240, required=False)


class ThuThachSerializer(serializers.Serializer):
    ma_phong = serializers.CharField(max_length=20, required=False, allow_blank=True)  # mã QR
    ma_bluetooth = serializers.CharField(max_length=20, required=False, allow_blank=True)


class KiemTraViTriSerializer(serializers.Serializer):
    mau_gps = serializers.ListField(child=MauGpsSerializer(), max_length=100, allow_empty=True)


class CheckinSerializer(serializers.Serializer):
    nonce = serializers.CharField(max_length=40)
    khung = _anh(3, 10)
    mau_gps = serializers.JSONField(required=False, default=list)  # rỗng khi phiên tắt GPS
    device_id = serializers.CharField(max_length=64, required=False, allow_blank=True)
    nen_tang = serializers.ChoiceField(choices=["android", "web"], default="android")

    def validate_mau_gps(self, v):
        s = MauGpsSerializer(data=v, many=True, allow_empty=True, max_length=100)
        s.is_valid(raise_exception=True)
        return s.validated_data


class DatTrangThaiSerializer(serializers.Serializer):
    sinh_vien = serializers.ListField(child=serializers.IntegerField(), min_length=1)
    trang_thai = serializers.ChoiceField(choices=TrangThaiDiemDanh.choices)
    di_tre = serializers.BooleanField(required=False, default=False)  # chỉ có nghĩa khi CO_MAT


class QuyetLuotSerializer(serializers.Serializer):
    co_mat = serializers.BooleanField()


class DuyetMatSerializer(serializers.Serializer):
    duyet = serializers.BooleanField()
    ly_do = serializers.CharField(max_length=255, required=False, allow_blank=True, default="")


# ------------------------------------------------------------------ SV


class ConsentView(APIView):
    permission_classes = [IsSinhVien]

    @extend_schema(request=None, responses=None)
    def post(self, request):
        tdd.dong_y(request.user)
        write_audit(request, HanhDong.CREATE, "Consent", request.user.id, {"dong_y": True})
        return Response(tdd.trang_thai_mat(request.user))

    @extend_schema(request=None, responses=None)
    def delete(self, request):
        n = tdd.rut_lai_dong_y(request.user)
        write_audit(request, HanhDong.DELETE, "Consent", request.user.id, {"thu_hoi_mau": n})
        return Response(tdd.trang_thai_mat(request.user))


class MyFaceView(APIView):
    permission_classes = [IsSinhVien]

    @extend_schema(responses=None)
    def get(self, request):
        return Response(tdd.trang_thai_mat(request.user))

    @extend_schema(responses=None)
    def delete(self, request):
        n = tdd.thu_hoi_mat(request.user)
        write_audit(request, HanhDong.DELETE, "FaceTemplate", request.user.id, {"thu_hoi": n})
        return Response(tdd.trang_thai_mat(request.user))


class KhungThrottle(UserRateThrottle):
    """Quét real time: ~1 khung / 0,8 giây khi đăng ký hoặc điểm danh; chỉ dò mặt nên rẻ."""

    scope = "khung_mat"
    rate = "150/min"


class KiemTraKhungSerializer(serializers.Serializer):
    anh = serializers.FileField()
    tu_the = serializers.ChoiceField(choices=list(checks.POSES))


class KiemTraKhungView(APIView):
    permission_classes = [IsSinhVien]
    parser_classes = [MultiPartParser, FormParser]
    throttle_classes = [KhungThrottle]

    @extend_schema(request=KiemTraKhungSerializer, responses=None)
    def post(self, request):
        s = KiemTraKhungSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        return Response(tdd.kiem_tra_khung(_doc_anh([d["anh"]])[0], d["tu_the"]))


class EnrollView(APIView):
    permission_classes = [IsSinhVien]
    parser_classes = [MultiPartParser, FormParser]
    throttle_classes = [DiemDanhThrottle]

    @extend_schema(request=DangKyMatSerializer, responses=None)
    def post(self, request):
        s = DangKyMatSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        m = tdd.dang_ky_mat(request.user, _doc_anh(s.validated_data["anh"]))
        write_audit(request, HanhDong.CREATE, "FaceTemplate", m.id, {"so_anh": m.so_anh})
        return Response(tdd.trang_thai_mat(request.user), status=201)


class OpenSessionsView(APIView):
    permission_classes = [IsSinhVien]

    @extend_schema(responses=None)
    def get(self, request):
        toi_da = tdd._tdd("so_luot_toi_da")
        return Response(
            [
                {
                    "id": s.id,
                    "lop_hoc_phan": s.lop_hoc_phan_id,
                    "ma_lop": s.lop_hoc_phan.ma_lop,
                    "ten_mon": s.lop_hoc_phan.mon_hoc.ten_mon,
                    "ngay_hoc": s.ngay_hoc,
                    "buoi": s.buoi,
                    "het_han_luc": s.het_han_luc,
                    "kiem_tra_phong": s.kiem_tra_phong,
                    "kiem_tra_gps": s.kiem_tra_gps,
                    "trang_thai": a.trang_thai if a else TrangThaiDiemDanh.VANG_KHONG_PHEP,
                    "dang_ngo": bool(a and a.dang_ngo),
                    "luot_con_lai": max(toi_da - da_dung, 0),
                }
                for s, a, da_dung in tdd.phien_dang_mo_cua_sv(request.user)
            ]
        )


class ChallengeView(APIView):
    permission_classes = [IsSinhVien]
    throttle_classes = [DiemDanhThrottle]

    @extend_schema(request=ThuThachSerializer, responses=None)
    def post(self, request, pk):
        s = ThuThachSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        return Response(
            tdd.xin_thu_thach(
                request.user,
                pk,
                d.get("ma_phong", ""),
                ma_bluetooth=d.get("ma_bluetooth", ""),
            ),
            status=201,
        )


class KiemTraViTriView(APIView):
    """GPS trước khi quét mặt (chỉ báo, không tính lượt)."""

    permission_classes = [IsSinhVien]
    throttle_classes = [DiemDanhThrottle]

    @extend_schema(request=KiemTraViTriSerializer, responses=None)
    def post(self, request, pk):
        s = KiemTraViTriSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        return Response(
            tdd.kiem_tra_vi_tri(request.user, pk, [dict(x) for x in s.validated_data["mau_gps"]])
        )


class CheckinView(APIView):
    permission_classes = [IsSinhVien]
    parser_classes = [MultiPartParser, FormParser]
    throttle_classes = [DiemDanhThrottle]

    @extend_schema(request=CheckinSerializer, responses=None)
    def post(self, request, pk):
        s = CheckinSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        return Response(
            tdd.diem_danh(
                request.user,
                pk,
                _doc_anh(d["khung"]),
                d["nonce"],
                [dict(x) for x in d["mau_gps"]],
                d.get("device_id", ""),
                d["nen_tang"],
                client_ip(request),
            )
        )


# ------------------------------------------------------------------ GV


def _phien_payload(s):
    return {
        "id": s.id,
        "mo_luc": s.mo_luc,
        "het_han_luc": s.het_han_luc,
        "dong_luc": s.dong_luc,
        "dang_mo": s.dang_mo_tu_diem_danh(),
        "kiem_tra_phong": s.kiem_tra_phong,
        "kiem_tra_gps": s.kiem_tra_gps,
    }


class MoPhienView(APIView):
    permission_classes = [IsGiaoVien]

    @extend_schema(request=MoPhienSerializer, responses=None)
    def post(self, request, pk):
        s = MoPhienSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        phien = tdd.mo_phien(
            request.user,
            pk,
            d.get("thoi_han") or tdd.thoi_han_mac_dinh(),
            d["kiem_tra_phong"],
            kiem_tra_gps=d["kiem_tra_gps"],
        )
        write_audit(request, HanhDong.UPDATE, "AttendanceSession", pk, {"hanh_dong": "mo_phien"})
        return Response(_phien_payload(phien))


class MoLaiView(APIView):
    permission_classes = [IsGiaoVien]

    @extend_schema(request=MoLaiSerializer, responses=None)
    def post(self, request, pk):
        s = MoLaiSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        thoi_han = s.validated_data.get("thoi_han") or tdd.thoi_han_mac_dinh()
        phien = tdd.mo_lai_phien(request.user, pk, thoi_han)
        write_audit(request, HanhDong.UPDATE, "AttendanceSession", pk, {"hanh_dong": "mo_lai"})
        return Response(_phien_payload(phien))


class DongPhienView(APIView):
    permission_classes = [IsGiaoVien]

    @extend_schema(request=None, responses=None)
    def post(self, request, pk):
        phien = tdd.dong_phien(request.user, pk)
        write_audit(request, HanhDong.UPDATE, "AttendanceSession", pk, {"hanh_dong": "dong_phien"})
        return Response(_phien_payload(phien))


class RoomTokenView(APIView):
    permission_classes = [IsGiaoVien]

    @extend_schema(responses=None)
    def get(self, request, pk):
        return Response(tdd.ma_phong(request.user, pk))


class TuDiemDanhView(APIView):
    """GET: danh sách thời gian thực. PATCH: đặt trạng thái (1 SV = thủ công, nhiều SV = hàng loạt)."""

    permission_classes = [IsGiaoVien]
    parser_classes = [JSONParser]

    @extend_schema(responses=None)
    def get(self, request, pk):
        kq = tdd.danh_sach_phien(request.user, pk)
        return Response({**kq, "session": _phien_payload(kq["session"])})

    @extend_schema(request=DatTrangThaiSerializer, responses=None)
    def patch(self, request, pk):
        s = DatTrangThaiSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        d = s.validated_data
        n = tdd.quyet_tay(request.user, pk, d["sinh_vien"], d["trang_thai"], d["di_tre"])
        write_audit(
            request,
            HanhDong.UPDATE,
            "AttendanceSession",
            pk,
            {
                "hanh_dong": "dat_trang_thai",
                "sinh_vien": d["sinh_vien"],
                "trang_thai": d["trang_thai"],
                "di_tre": d["di_tre"],
            },
        )
        kq = tdd.danh_sach_phien(request.user, pk)
        return Response({**kq, "session": _phien_payload(kq["session"]), "so_dong": n})


class LuotCuaSvView(APIView):
    """`?sinh_vien=` — mọi lượt của một SV trong phiên (màn chi tiết SV)."""

    permission_classes = [IsGiaoVien]

    @extend_schema(parameters=[OpenApiParameter("sinh_vien", int, required=True)], responses=None)
    def get(self, request, pk):
        sv_id = int_param(request, "sinh_vien")
        if sv_id is None:
            raise serializers.ValidationError({"sinh_vien": ["Bắt buộc."]})
        return Response(tdd.luot_cua_sv_trong_phien(request.user, pk, sv_id))


class QuyetLuotView(APIView):
    permission_classes = [IsGiaoVien]

    @extend_schema(request=QuyetLuotSerializer, responses=None)
    def post(self, request, pk):
        s = QuyetLuotSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        luot = tdd.quyet_luot(request.user, pk, s.validated_data["co_mat"])
        write_audit(
            request,
            HanhDong.UPDATE,
            "CheckinAttempt",
            pk,
            {"co_mat": s.validated_data["co_mat"], "sinh_vien": luot.sinh_vien_id},
        )
        return Response({"id": luot.id, "co_mat": s.validated_data["co_mat"]})


def _jpeg(data):
    if data is None:
        raise Http404
    res = HttpResponse(data, content_type="image/jpeg")
    res["Cache-Control"] = "no-store"
    return res


class EvidenceView(APIView):
    permission_classes = [IsGiaoVien]

    @extend_schema(responses=None)
    def get(self, request, pk):
        data = tdd.anh_bang_chung(request.user, pk)
        write_audit(request, HanhDong.UPDATE, "CheckinAttempt", pk, {"xem_anh_bang_chung": True})
        return _jpeg(data)


# ------------------------------------------------------------------ duyệt khuôn mặt (PĐT)


def _mau_ngan(m):
    return {
        "id": m.id,
        "trang_thai": m.trang_thai,
        "ly_do": m.ly_do,
        "tao_luc": m.tao_luc,
        "ngay_duyet": m.ngay_duyet,
        "nguoi_duyet": full_name(m.nguoi_duyet) if m.nguoi_duyet else "",
    }


class FacesView(APIView):
    """PĐT: danh sách mẫu theo trạng thái (`trang_thai`, mặc định chờ duyệt), tìm `q` theo MSSV / họ tên;
    mỗi mẫu kèm ngành, khóa và các lần đăng ký trước của SV."""

    permission_classes = [IsPhongDaoTao]  # chỉ PĐT duyệt khuôn mặt

    @extend_schema(
        parameters=[
            OpenApiParameter("trang_thai", str, enum=TrangThaiMau.values),
            OpenApiParameter("q", str),
        ],
        responses=None,
    )
    def get(self, request):
        tt = request.query_params.get("trang_thai", TrangThaiMau.CHO_DUYET)
        if tt not in TrangThaiMau.values:
            raise serializers.ValidationError({"trang_thai": ["Trạng thái không hợp lệ."]})
        out = []
        for m, lich in tdd.danh_sach_mau(tt, request.query_params.get("q", "").strip()):
            hs = m.sinh_vien.sinh_vien
            out.append(
                {
                    **_mau_ngan(m),
                    "sinh_vien": m.sinh_vien_id,
                    "ma_sv": hs.ma_sv,
                    "ho_ten": hs.ho_ten,
                    "nganh": hs.nganh.ten_nganh,
                    "khoa_nhap_hoc": hs.khoa_nhap_hoc,
                    "so_anh": m.so_anh,
                    "lan_thu": next(i for i, x in enumerate(lich, 1) if x.id == m.id),
                    "co_mau_khac_da_duyet": any(
                        x.trang_thai == TrangThaiMau.DUYET and x.id != m.id for x in lich
                    ),
                    "lich_su": [_mau_ngan(x) for x in reversed(lich) if x.id != m.id],
                }
            )
        return Response(out)


class FacePhotoView(APIView):
    permission_classes = [IsPhongDaoTao]  # chỉ PĐT duyệt khuôn mặt

    @extend_schema(responses=None)
    def get(self, request, pk):
        i = request.query_params.get("i", "0")
        data = tdd.anh_dang_ky(request.user, pk, int(i)) if i.isdigit() else None
        write_audit(request, HanhDong.UPDATE, "FaceTemplate", pk, {"xem_anh": i})
        return _jpeg(data)


class ThuHoiMatSerializer(serializers.Serializer):
    ly_do = serializers.CharField(max_length=255, allow_blank=True, default="")


class FaceRevokeView(APIView):
    permission_classes = [IsPhongDaoTao]

    @extend_schema(request=ThuHoiMatSerializer, responses=None)
    def post(self, request, pk):
        s = ThuHoiMatSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        m = tdd.pdt_thu_hoi_mat(request.user, pk, s.validated_data["ly_do"].strip())
        write_audit(
            request,
            HanhDong.UPDATE,
            "FaceTemplate",
            m.id,
            {"trang_thai": m.trang_thai, "ly_do": m.ly_do},
        )
        return Response({"id": m.id, "trang_thai": m.trang_thai})


class FaceReviewView(APIView):
    permission_classes = [IsPhongDaoTao]  # chỉ PĐT duyệt khuôn mặt

    @extend_schema(request=DuyetMatSerializer, responses=None)
    def post(self, request, pk):
        s = DuyetMatSerializer(data=request.data)
        s.is_valid(raise_exception=True)
        m = tdd.duyet_mat(request.user, pk, s.validated_data["duyet"], s.validated_data["ly_do"])
        write_audit(
            request,
            HanhDong.UPDATE,
            "FaceTemplate",
            m.id,
            {"trang_thai": m.trang_thai, "ly_do": m.ly_do},
        )
        return Response(
            {"id": m.id, "trang_thai": m.trang_thai, "ngay_duyet": timezone.localtime(m.ngay_duyet)}
        )
