"""Tự điểm danh khuôn mặt + GPS (docs/ke-hoach-diem-danh-khuon-mat-gps.md, port từ DiemDanhKhuonMat_GPS).

Luồng: SV đồng ý dữ liệu → đăng ký mặt → PĐT/GV duyệt. GV mở phiên (GPS chốt tâm) → SV xin thử thách →
gửi khung hình + GPS (+ mã phòng) → 6 bước kiểm tra → kết quả chỉ nâng hạng: vắng < đáng ngờ < có mặt.
"""

import json
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.db.models import Q
from django.http import Http404
from django.utils import timezone
from rest_framework.exceptions import ValidationError

from apps.attendance import crypto, geo, room_token
from apps.attendance.face import checks
from apps.attendance.face.runtime import get_engine, infer
from apps.attendance.face.types import FaceCfg
from apps.attendance.face.verify import build_template, verify_checkin
from apps.attendance.models import (
    Attendance,
    AttendanceSession,
    Challenge,
    CheckinAttempt,
    Consent,
    FaceTemplate,
    HanhDongThuThach,
    KetQuaLuot,
    TrangThaiDiemDanh,
    TrangThaiMau,
    TrangThaiSession,
)
from apps.attendance.services import kiem_tra_gv_lop, sinh_vien_dang_ky
from apps.config.models import SystemConfig
from apps.registration.models import Registration, TrangThaiDangKy
from apps.training.models import TrangThaiLop
from core.exceptions import Codes, business_error

# Mã lý do trả cho SV (app map sang câu tiếng Việt). Không trả điểm số thô để SV không dò được ngưỡng.
LY_DO = {
    "MA_PHONG_SAI": "Chưa xác nhận được bạn đang trong phòng học: hãy lại gần bàn giảng viên rồi đọc lại mã ESP32 (hoặc gõ mã giảng viên đọc).",
    "GPS_KEM": "GPS chưa đủ chính xác, hãy bật Wi-Fi và thử lại gần cửa sổ.",
    "QUA_XA": "Bạn đang ở ngoài khuôn viên trường.",
    "CHUA_CO_KHUON_VIEN": "Trường chưa cấu hình khuôn viên. Hãy báo giảng viên.",
    "KHONG_THAY_MAT": "Không thấy khuôn mặt trong khung hình.",
    "NHIEU_MAT": "Chỉ một người trong khung hình.",
    "THIEU_SANG": "Thiếu sáng.",
    "ANH_MO": "Ảnh bị mờ, hãy giữ máy chắc tay.",
    "SAI_HANH_DONG": "Chưa thấy bạn làm đúng hành động được yêu cầu.",
    "ANH_GIA": "Không xác nhận được người thật.",
    "KHONG_KHOP": "Khuôn mặt không khớp với tài khoản.",
    "KHONG_DONG_NHAT": "Các ảnh không phải cùng một người.",
    "CHUA_CO_MAT": "Bạn chưa có mẫu khuôn mặt được duyệt. Hãy báo giảng viên để điểm danh thủ công.",
    "MO_HINH_DOI": "Hệ thống đã đổi mô hình nhận diện, bạn cần đăng ký lại khuôn mặt.",
}
_MA_MAT = {  # mã của engine (port nguyên) → mã tiếng Việt
    "FACE_NOT_FOUND": "KHONG_THAY_MAT",
    "MULTIPLE_FACES": "NHIEU_MAT",
    "LOW_LIGHT": "THIEU_SANG",
    "BLURRY": "ANH_MO",
    "ACTION_NOT_DETECTED": "SAI_HANH_DONG",
    "SPOOF_DETECTED": "ANH_GIA",
    "FACE_MISMATCH": "KHONG_KHOP",
    "INCONSISTENT_FACE": "KHONG_DONG_NHAT",
}
MAX_ANH_BYTES = 2 * 1024 * 1024


def _cfg():
    return FaceCfg.from_settings()


def _tdd(khoa):
    return settings.TU_DIEM_DANH[khoa]


def _loi(code, message, ly_do=None):
    return business_error(code, message, {"ly_do": ly_do} if ly_do else None)


def _mau(samples):
    return [
        geo.Sample(s["lat"], s["lng"], s["acc"], s["ts"], s.get("mock", False)) for s in samples
    ]


# ============================================================== đồng ý + mẫu khuôn mặt


def da_dong_y(sv):
    return Consent.objects.filter(
        sinh_vien=sv, phien_ban=_tdd("consent_version"), rut_lai_luc__isnull=True
    ).exists()


def dong_y(sv):
    if not da_dong_y(sv):
        Consent.objects.create(sinh_vien=sv, phien_ban=_tdd("consent_version"))


def thu_hoi_mat(sv):
    """Thu hồi mọi mẫu còn hiệu lực: xóa embedding và ảnh đăng ký ngay. Trả số mẫu bị thu hồi."""
    mau = list(
        FaceTemplate.objects.filter(
            sinh_vien=sv, trang_thai__in=[TrangThaiMau.CHO_DUYET, TrangThaiMau.DUYET]
        )
    )
    for m in mau:
        if m.thu_muc_anh:
            crypto.delete_tree(m.thu_muc_anh)
        m.trang_thai, m.embedding, m.thu_muc_anh = TrangThaiMau.THU_HOI, None, ""
        m.save(update_fields=["trang_thai", "embedding", "thu_muc_anh"])
    return len(mau)


@transaction.atomic
def rut_lai_dong_y(sv):
    Consent.objects.filter(sinh_vien=sv, rut_lai_luc__isnull=True).update(
        rut_lai_luc=timezone.now()
    )
    return thu_hoi_mat(sv)


def mau_duyet(sv):
    """Embedding đã duyệt của đúng mô hình đang chạy, hoặc None (đổi mô hình = đăng ký lại)."""
    m = FaceTemplate.objects.filter(
        sinh_vien=sv, trang_thai=TrangThaiMau.DUYET, ten_mo_hinh=_cfg().model_name
    ).first()
    if m is None or m.embedding is None:
        return None
    return crypto.embedding_from_bytes(crypto.decrypt(bytes(m.embedding)))


def trang_thai_mat(sv):
    theo = {}
    for m in FaceTemplate.objects.filter(sinh_vien=sv).exclude(trang_thai=TrangThaiMau.THU_HOI):
        theo.setdefault(m.trang_thai, m)  # mới nhất mỗi trạng thái (ordering -id)
    kq = {
        "da_dong_y": da_dong_y(sv),
        "trang_thai": "CHUA_CO",
        "ly_do": "",
        "can_dang_ky_lai": False,
        "dang_cho_cap_nhat": TrangThaiMau.CHO_DUYET in theo,
    }
    if TrangThaiMau.DUYET in theo:
        kq["trang_thai"] = "DUYET"
        kq["can_dang_ky_lai"] = theo[TrangThaiMau.DUYET].ten_mo_hinh != _cfg().model_name
    elif TrangThaiMau.CHO_DUYET in theo:
        kq["trang_thai"], kq["dang_cho_cap_nhat"] = "CHO_DUYET", False
    elif TrangThaiMau.TU_CHOI in theo:
        kq["trang_thai"], kq["ly_do"] = "TU_CHOI", theo[TrangThaiMau.TU_CHOI].ly_do
    if kq["trang_thai"] in ("CHUA_CO", "TU_CHOI"):
        # PĐT thu hồi mẫu (có lý do) mới nhất → báo SV như bị từ chối để đăng ký lại.
        moi = FaceTemplate.objects.filter(sinh_vien=sv).first()
        if moi and moi.trang_thai == TrangThaiMau.THU_HOI and moi.ly_do:
            kq["trang_thai"], kq["ly_do"] = "TU_CHOI", f"Phòng đào tạo thu hồi mẫu: {moi.ly_do}"
    return kq


def dang_ky_mat(sv, anh):
    """3–5 ảnh → kiểm tra chất lượng + người thật + cùng một người → mẫu chờ duyệt (thay mẫu chờ cũ)."""
    if not da_dong_y(sv):
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, "Bạn cần đồng ý xử lý dữ liệu sinh trắc trước.")
    cfg = _cfg()
    mau, loi = infer(build_template, anh, get_engine(), cfg)
    if mau is None:
        raise ValidationError(
            {"anh": [" ".join(f"Ảnh {x['index'] + 1}: {LY_DO[_MA_MAT[x['reason']]]}" for x in loi)]}
        )
    with transaction.atomic():
        for cu in FaceTemplate.objects.filter(sinh_vien=sv, trang_thai=TrangThaiMau.CHO_DUYET):
            if cu.thu_muc_anh:
                crypto.delete_tree(cu.thu_muc_anh)
            cu.trang_thai, cu.embedding, cu.thu_muc_anh = TrangThaiMau.THU_HOI, None, ""
            cu.save(update_fields=["trang_thai", "embedding", "thu_muc_anh"])
        m = FaceTemplate.objects.create(
            sinh_vien=sv,
            ten_mo_hinh=cfg.model_name,
            embedding=crypto.encrypt(crypto.embedding_to_bytes(mau)),
            so_anh=len(anh),
        )
        m.thu_muc_anh = f"dang_ky/{m.id}"
        for i, a in enumerate(anh):
            crypto.save_blob(f"{m.thu_muc_anh}/{i}.jpg", a)
        m.save(update_fields=["thu_muc_anh"])
    return m


def mau_xem_duoc(nguoi):
    """Chỉ PĐT duyệt khuôn mặt (quyền chặn ở view), thấy mọi mẫu."""
    return FaceTemplate.objects.select_related("sinh_vien__sinh_vien")


GOI_Y_KHUNG = {
    None: "Tốt lắm, giữ yên…",
    "KHONG_THAY_MAT": "Chưa thấy khuôn mặt, hãy đưa mặt vào giữa khung.",
    "NHIEU_MAT": "Chỉ để một người trong khung.",
    "LAI_GAN": "Lại gần camera hơn một chút.",
    "THIEU_SANG": "Thiếu sáng, hãy ra chỗ sáng hơn.",
    "ANH_MO": "Ảnh bị mờ, giữ máy yên.",
    "NHIN_THANG": "Nhìn thẳng vào camera.",
    "QUAY_TRAI": "Quay đầu sang trái thêm.",
    "QUAY_PHAI": "Quay đầu sang phải thêm.",
}


def kiem_tra_khung(anh, tu_the):
    """Quét real time: chỉ dò mặt + chất lượng + tư thế (không nhận diện, không chống giả), không lưu ảnh."""
    a = infer(get_engine().analyze, anh, embed=False, spoof=False)
    ma = checks.live_hint(a, _cfg(), tu_the)
    return {"ok": ma is None, "ma": ma, "thong_bao": GOI_Y_KHUNG[ma]}


def danh_sach_mau(trang_thai, q=""):
    """PĐT: mẫu theo trạng thái (chờ duyệt: cũ nhất trước; còn lại: mới nhất trước), tìm theo MSSV / họ tên.
    Trả `[(mẫu, [mọi mẫu của SV đó, cũ → mới])]`."""
    qs = FaceTemplate.objects.filter(trang_thai=trang_thai).select_related(
        "sinh_vien__sinh_vien__nganh", "nguoi_duyet"
    )
    if q:
        qs = qs.filter(
            Q(sinh_vien__sinh_vien__ma_sv__icontains=q)
            | Q(sinh_vien__sinh_vien__ho_ten__icontains=q)
        )
    # ponytail: tối đa 200 dòng, đủ cho một đợt duyệt; cần phân trang khi lịch sử lớn hơn.
    ds = list(qs.order_by("id" if trang_thai == TrangThaiMau.CHO_DUYET else "-id")[:200])
    lich = {}
    for m in FaceTemplate.objects.filter(sinh_vien_id__in={m.sinh_vien_id for m in ds}).order_by(
        "id"
    ):
        lich.setdefault(m.sinh_vien_id, []).append(m)
    return [(m, lich[m.sinh_vien_id]) for m in ds]


@transaction.atomic
def pdt_thu_hoi_mat(nguoi, mau_id, ly_do):
    """PĐT thu hồi mẫu đã duyệt (vd ảnh không đúng người): SV phải đăng ký lại mới tự điểm danh được."""
    m = FaceTemplate.objects.select_for_update().filter(pk=mau_id).first()
    if m is None:
        raise Http404
    if m.trang_thai != TrangThaiMau.DUYET:
        raise _loi(
            Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ thu hồi được mẫu đang ở trạng thái đã duyệt."
        )
    if not ly_do:
        raise ValidationError({"ly_do": ["Thu hồi phải ghi lý do."]})
    m.trang_thai, m.embedding, m.ly_do = TrangThaiMau.THU_HOI, None, ly_do
    m.nguoi_duyet, m.ngay_duyet = nguoi, timezone.now()
    m.save(update_fields=["trang_thai", "embedding", "ly_do", "nguoi_duyet", "ngay_duyet"])
    return m


def anh_dang_ky(nguoi, mau_id, i):
    m = mau_xem_duoc(nguoi).filter(pk=mau_id).first()
    if m is None or not m.thu_muc_anh or not 0 <= i < m.so_anh:
        return None
    return crypto.load_blob(f"{m.thu_muc_anh}/{i}.jpg")


@transaction.atomic
def duyet_mat(nguoi, mau_id, dong_y_duyet, ly_do=""):
    m = mau_xem_duoc(nguoi).select_for_update(of=("self",)).filter(pk=mau_id).first()
    if m is None:
        raise _loi(Codes.KHONG_CO_QUYEN, "Không tìm thấy mẫu khuôn mặt bạn được duyệt.")
    if m.trang_thai != TrangThaiMau.CHO_DUYET:
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, "Mẫu này đã được xử lý.")
    if dong_y_duyet:
        FaceTemplate.objects.filter(sinh_vien=m.sinh_vien, trang_thai=TrangThaiMau.DUYET).update(
            trang_thai=TrangThaiMau.THU_HOI, embedding=None
        )
        m.trang_thai = TrangThaiMau.DUYET
    else:
        if not ly_do:
            raise ValidationError({"ly_do": ["Từ chối phải ghi lý do."]})
        m.trang_thai, m.embedding = TrangThaiMau.TU_CHOI, None
    # Duyệt hay từ chối đều xóa ảnh, chỉ giữ embedding đã mã hóa (KH §7.1).
    if m.thu_muc_anh:
        crypto.delete_tree(m.thu_muc_anh)
    m.thu_muc_anh, m.nguoi_duyet, m.ngay_duyet, m.ly_do = "", nguoi, timezone.now(), ly_do
    m.save()
    return m


# ============================================================== phiên (GV)


def _phien_gv(gv, session_id, khoa=False):
    qs = AttendanceSession.objects.select_related("lop_hoc_phan__giao_vien")
    if khoa:
        qs = qs.select_for_update(of=("self",))
    s = qs.filter(pk=session_id).first()
    if s is None:
        raise Http404
    kiem_tra_gv_lop(gv, s.lop_hoc_phan)
    return s


def _kiem_tra_hom_nay(s, now):
    if s.lop_hoc_phan.trang_thai != TrangThaiLop.DANG_HOC:
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ điểm danh được khi lớp đang học.")
    if s.ngay_hoc != timezone.localdate(now):
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, "Chỉ mở tự điểm danh cho buổi học hôm nay.")


def khuon_vien():
    """Đa giác khuôn viên do PĐT vẽ: `[(lat, lng), ...]`; chưa vẽ → None."""
    raw = SystemConfig.objects.filter(khoa="khuon_vien").values_list("gia_tri", flat=True).first()
    return [tuple(p) for p in json.loads(raw)] if raw else None


def sai_lech_khuon_vien_m():
    return SystemConfig.get_int("sai_lech_khuon_vien_m", 30)


def thoi_han_mac_dinh():
    return SystemConfig.get_int("so_phut_mo_diem_danh", 10)


@transaction.atomic
def mo_phien(gv, session_id, thoi_han, kiem_tra_phong, now=None):
    now = now or timezone.now()
    s = _phien_gv(gv, session_id, khoa=True)
    _kiem_tra_hom_nay(s, now)
    if s.mo_luc is not None:
        raise _loi(
            Codes.TRANG_THAI_KHONG_HOP_LE,
            "Buổi này đã mở tự điểm danh; dùng Mở lại nếu phiên đã đóng.",
        )
    if khuon_vien() is None:
        raise _loi(
            Codes.TRANG_THAI_KHONG_HOP_LE,
            "Phòng đào tạo chưa vẽ khuôn viên trường nên chưa mở được tự điểm danh.",
            "CHUA_CO_KHUON_VIEN",
        )
    s.mo_luc, s.het_han_luc, s.dong_luc, s.nguoi_mo = (
        now,
        now + timedelta(minutes=thoi_han),
        None,
        gv,
    )
    s.kiem_tra_phong = kiem_tra_phong
    s.ma_phong_bi_mat = secrets.token_bytes(32)
    s.trang_thai = TrangThaiSession.DA_DIEM_DANH
    s.save()
    # Sinh sẵn "vắng không phép" cho cả lớp → danh sách thời gian thực đủ người; không đè dòng đã có.
    co = set(Attendance.objects.filter(attendance_session=s).values_list("sinh_vien_id", flat=True))
    Attendance.objects.bulk_create(
        [
            Attendance(
                attendance_session=s,
                lop_hoc_phan=s.lop_hoc_phan,
                ngay_hoc=s.ngay_hoc,
                sinh_vien_id=r.sinh_vien_id,
                trang_thai=TrangThaiDiemDanh.VANG_KHONG_PHEP,
            )
            for r in sinh_vien_dang_ky(s.lop_hoc_phan)
            if r.sinh_vien_id not in co
        ]
    )
    return s


@transaction.atomic
def mo_lai_phien(gv, session_id, thoi_han, now=None):
    """Mở lại phiên đã đóng / hết hạn trong ngày: giữ mã phòng, kết quả và số lượt."""
    now = now or timezone.now()
    s = _phien_gv(gv, session_id, khoa=True)
    _kiem_tra_hom_nay(s, now)
    if s.mo_luc is None:
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, "Buổi này chưa mở tự điểm danh.")
    if s.dang_mo_tu_diem_danh(now):
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, "Phiên đang mở.")
    s.dong_luc, s.het_han_luc = None, now + timedelta(minutes=thoi_han)
    s.save(update_fields=["dong_luc", "het_han_luc"])
    return s


@transaction.atomic
def dong_phien(gv, session_id, now=None):
    now = now or timezone.now()
    s = _phien_gv(gv, session_id, khoa=True)
    if not s.dang_mo_tu_diem_danh(now):
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, "Phiên không mở.")
    s.dong_luc = now
    s.save(update_fields=["dong_luc"])
    return s


def ma_phong(gv, session_id, now=None):
    s = _phien_gv(gv, session_id)
    t = (now or timezone.now()).timestamp()
    if not s.kiem_tra_phong or not s.dang_mo_tu_diem_danh():
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, "Phiên không mở hoặc không bật mã phòng.")
    w = _tdd("room_token_window_s")
    return {
        "ma": room_token.room_code(bytes(s.ma_phong_bi_mat), s.id, t, w),
        "het_han_sau_giay": round(room_token.window_end(t, w) - t, 1),
    }


# ============================================================== ghi kết quả (chỉ nâng hạng)


def _hang(a):
    if a.trang_thai == TrangThaiDiemDanh.CO_MAT:
        return 2
    return 1 if a.dang_ngo else 0


def _nang_hang(s, sv_id, ket_qua, luot):
    """Có mặt / đáng ngờ chỉ nâng hạng; GV đã quyết tay thì không ghi đè."""
    a = (
        Attendance.objects.select_for_update()
        .filter(attendance_session=s, sinh_vien_id=sv_id)
        .first()
    )
    if a is None:
        a = Attendance(
            attendance_session=s,
            lop_hoc_phan_id=s.lop_hoc_phan_id,
            ngay_hoc=s.ngay_hoc,
            sinh_vien_id=sv_id,
            trang_thai=TrangThaiDiemDanh.VANG_KHONG_PHEP,
        )
    moi = 2 if ket_qua == KetQuaLuot.CO_MAT else 1
    if a.nguoi_quyet_id is not None or moi <= _hang(a):
        return a
    if moi == 2:
        a.trang_thai, a.dang_ngo, a.di_tre = TrangThaiDiemDanh.CO_MAT, False, False
    else:
        a.dang_ngo = True  # giữ trạng thái vắng (có phép / không phép), chờ GV duyệt
    a.luot_tot_nhat = luot
    a.save()
    return a


def quyet_tay(gv, session_id, sv_ids, trang_thai, di_tre=False):
    """GV đặt trạng thái (1 SV = điểm danh thủ công, nhiều SV = hàng loạt). Dùng được cả khi phiên mở."""
    with transaction.atomic():
        s = _phien_gv(gv, session_id, khoa=True)
        dang_ky = {r.sinh_vien_id for r in sinh_vien_dang_ky(s.lop_hoc_phan)}
        if not set(sv_ids) <= dang_ky:
            raise ValidationError({"sinh_vien": ["Có sinh viên không thuộc lớp."]})
        co = {
            a.sinh_vien_id: a
            for a in Attendance.objects.filter(attendance_session=s, sinh_vien_id__in=sv_ids)
        }
        for sv_id in sv_ids:
            a = co.get(sv_id) or Attendance(
                attendance_session=s,
                lop_hoc_phan_id=s.lop_hoc_phan_id,
                ngay_hoc=s.ngay_hoc,
                sinh_vien_id=sv_id,
            )
            a.trang_thai, a.dang_ngo, a.nguoi_quyet = trang_thai, False, gv
            # "Đi trễ" = có mặt + di_tre; trạng thái khác thì không có cờ trễ.
            a.di_tre = bool(di_tre) and trang_thai == TrangThaiDiemDanh.CO_MAT
            a.save()
        if s.trang_thai != TrangThaiSession.DA_DIEM_DANH:
            s.trang_thai = TrangThaiSession.DA_DIEM_DANH
            s.save(update_fields=["trang_thai"])
    return len(sv_ids)


def luot_cua_gv(gv, luot_id):
    luot = (
        CheckinAttempt.objects.select_related("session__lop_hoc_phan__giao_vien")
        .filter(pk=luot_id)
        .first()
    )
    if luot is None:
        raise Http404
    kiem_tra_gv_lop(gv, luot.session.lop_hoc_phan)
    return luot


def quyet_luot(gv, luot_id, dong_y_co_mat):
    luot = luot_cua_gv(gv, luot_id)
    tt = TrangThaiDiemDanh.CO_MAT if dong_y_co_mat else TrangThaiDiemDanh.VANG_KHONG_PHEP
    quyet_tay(gv, luot.session_id, [luot.sinh_vien_id], tt)
    return luot


def anh_bang_chung(gv, luot_id):
    luot = luot_cua_gv(gv, luot_id)
    return crypto.load_blob(luot.anh_bang_chung) if luot.anh_bang_chung else None


# ============================================================== SV: thử thách + điểm danh


def _phien_sv(sv, session_id, now):
    s = AttendanceSession.objects.filter(pk=session_id).first()
    if (
        s is None
        or not Registration.objects.filter(
            sinh_vien=sv, lop_hoc_phan_id=s.lop_hoc_phan_id, trang_thai=TrangThaiDangKy.DA_DANG_KY
        ).exists()
    ):
        raise _loi(Codes.KHONG_CO_QUYEN, "Bạn không thuộc lớp của buổi này.")
    if not s.dang_mo_tu_diem_danh(now):
        raise _loi(
            Codes.TRANG_THAI_KHONG_HOP_LE, "Phiên điểm danh đã đóng hoặc hết hạn.", "PHIEN_DONG"
        )
    return s


def _so_luot_da_dung(s, sv):
    return Challenge.objects.filter(session=s, sinh_vien=sv).count()


def phien_dang_mo_cua_sv(sv, now=None):
    now = now or timezone.now()
    lop_ids = Registration.objects.filter(
        sinh_vien=sv, trang_thai=TrangThaiDangKy.DA_DANG_KY
    ).values("lop_hoc_phan_id")
    qs = AttendanceSession.objects.select_related("lop_hoc_phan__mon_hoc").filter(
        lop_hoc_phan_id__in=lop_ids,
        mo_luc__isnull=False,
        dong_luc__isnull=True,
        het_han_luc__gt=now,
    )
    toi = {
        a.attendance_session_id: a
        for a in Attendance.objects.filter(sinh_vien=sv, attendance_session__in=qs)
    }
    return [(s, toi.get(s.id), _so_luot_da_dung(s, sv)) for s in qs]


@transaction.atomic
def xin_thu_thach(sv, session_id, ma_phong="", now=None):
    """Mỗi lần xin = 1 lượt, kể cả khi không gửi lên (chống xin liên tục để chọn hành động dễ).
    Phiên bắt mã phòng: kiểm tra "trong phòng" (mã ESP32) **trước**; sai mã thì không cấp, không tính lượt."""
    now = now or timezone.now()
    s = _phien_sv(sv, session_id, now)
    AttendanceSession.objects.select_for_update().filter(pk=s.pk).first()  # xếp hàng theo phiên
    duyet = FaceTemplate.objects.filter(sinh_vien=sv, trang_thai=TrangThaiMau.DUYET).first()
    if duyet is None:
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, LY_DO["CHUA_CO_MAT"], "CHUA_CO_MAT")
    if duyet.ten_mo_hinh != _cfg().model_name:  # chặn sớm, không tính lượt
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, LY_DO["MO_HINH_DOI"], "MO_HINH_DOI")
    a = Attendance.objects.filter(attendance_session=s, sinh_vien=sv).first()
    if a is not None and a.trang_thai == TrangThaiDiemDanh.CO_MAT:
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, "Bạn đã được ghi nhận có mặt.", "DA_CO_MAT")
    da_dung, toi_da = _so_luot_da_dung(s, sv), _tdd("so_luot_toi_da")
    if da_dung >= toi_da:
        raise _loi(
            Codes.QUA_NHIEU_YEU_CAU,
            "Bạn đã dùng hết lượt điểm danh của phiên này. Hãy báo giảng viên để điểm danh thủ công.",
            "HET_LUOT",
        )
    if s.kiem_tra_phong and not room_token.verify_room_code(
        ma_phong,
        bytes(s.ma_phong_bi_mat),
        s.id,
        now.timestamp(),
        _tdd("room_token_window_s"),
    ):
        raise _loi(Codes.TRANG_THAI_KHONG_HOP_LE, LY_DO["MA_PHONG_SAI"], "MA_PHONG_SAI")
    c = Challenge.objects.create(
        session=s,
        sinh_vien=sv,
        nonce=secrets.token_urlsafe(24),
        hanh_dong=secrets.choice(HanhDongThuThach.values),
        het_han_luc=now + timedelta(seconds=_tdd("challenge_ttl_s")),
    )
    return {
        "nonce": c.nonce,
        "hanh_dong": c.hanh_dong,
        "het_han_luc": c.het_han_luc,
        "luot_con_lai": toi_da - da_dung - 1,
        "kiem_tra_phong": s.kiem_tra_phong,
    }


def _co(face_status, vi_tri, mau, nhay_luot_truoc, cung_may):
    """Cờ của lượt đã qua đủ 6 bước; "có mặt" khi và chỉ khi không có cờ nào."""
    co = []
    if vi_tri == "drift":
        co.append("LECH_NHE")
    if face_status == "borderline":
        co.append("SAT_NGUONG")
    if any(m.mock for m in mau):
        co.append("VI_TRI_GIA")
    if nhay_luot_truoc or geo.has_jump(mau, settings.GPS["max_speed_mps"]):
        co.append("BUOC_NHAY")
    if cung_may:
        co.append("CUNG_MAY")
    return co


def diem_danh(sv, session_id, khung, nonce, mau_gps, device_id, nen_tang, ip, now=None):
    now = now or timezone.now()
    # Bước 1–2 không đạt thì không ghi lượt (giống bản gốc).
    s = _phien_sv(sv, session_id, now)
    with transaction.atomic():
        ch = Challenge.objects.filter(
            nonce=nonce, sinh_vien=sv, session=s, da_dung=False, het_han_luc__gt=now
        ).first()
        # UPDATE có điều kiện: hai request cùng nonce chạy song song thì chỉ một cái được 1 dòng.
        if ch is None or not Challenge.objects.filter(pk=ch.pk, da_dung=False).update(da_dung=True):
            raise _loi(
                Codes.TRANG_THAI_KHONG_HOP_LE,
                "Thử thách không hợp lệ hoặc đã hết hạn, hãy bắt đầu lại.",
                "NONCE_SAI",
            )

    mau = _mau(mau_gps)
    luot = CheckinAttempt(
        session=s,
        sinh_vien=sv,
        challenge=ch,
        nen_tang=nen_tang,
        device_id=device_id,
        ip=ip,
        mau_gps=mau_gps,
        ket_qua=KetQuaLuot.KHONG_DAT,
    )
    best = None

    def xong(buoc=None, ly_do=""):
        luot.buoc_dung, luot.ly_do = buoc, ly_do
        with transaction.atomic():
            luot.save()
            if luot.ket_qua != KetQuaLuot.KHONG_DAT:
                if luot.ket_qua == KetQuaLuot.DANG_NGO and best is not None:
                    luot.anh_bang_chung = crypto.save_blob(f"bang_chung/{luot.id}.jpg", khung[best])
                    luot.save(update_fields=["anh_bang_chung"])
                a = _nang_hang(s, sv.id, luot.ket_qua, luot)
            else:
                a = Attendance.objects.filter(attendance_session=s, sinh_vien=sv).first()
        return {
            "ket_qua": luot.ket_qua,
            "trang_thai": a.trang_thai if a else TrangThaiDiemDanh.VANG_KHONG_PHEP,
            "dang_ngo": bool(a and a.dang_ngo),
            "ly_do": {"ma": ly_do, "thong_bao": LY_DO[ly_do]} if ly_do else None,
            "luot_con_lai": max(_tdd("so_luot_toi_da") - _so_luot_da_dung(s, sv), 0),
        }

    # Bước 3 (mã phòng) đã kiểm tra lúc cấp thử thách: có nonce hợp lệ nghĩa là đã ở trong phòng.

    # Bước 4: vị trí so với khuôn viên; xa quá 2 lần sai lệch cho phép thì dừng, không chạy mô hình.
    g = settings.GPS
    fix = geo.aggregate(mau, g["max_acc_sv_m"], g["min_mau_sv"], g["max_span_s"])
    if fix is None:
        return xong(4, "GPS_KEM")
    vien = khuon_vien()
    if vien is None:  # PĐT xóa khuôn viên giữa phiên
        return xong(4, "CHUA_CO_KHUON_VIEN")
    r = sai_lech_khuon_vien_m()
    d = geo.distance_to_polygon_m(fix.lat, fix.lng, vien)
    luot.lat, luot.lng, luot.sai_so_m, luot.d_m, luot.r_m = fix.lat, fix.lng, fix.acc, d, r
    vi_tri = geo.classify(d, r)
    if vi_tri == "far":
        return xong(4, "QUA_XA")

    # Bước 5–6: chất lượng + hành động + chống giả, rồi so khớp.
    mau_mat = mau_duyet(sv)
    if mau_mat is None:
        return xong(6, "CHUA_CO_MAT")
    face = infer(verify_checkin, khung, ch.hanh_dong, mau_mat, get_engine(), _cfg())
    best = face.best_frame
    luot.diem_mat, luot.diem_that = face.face_score, face.liveness_score
    if face.status == "fail":
        return xong(6 if face.reason == "FACE_MISMATCH" else 5, _MA_MAT[face.reason])

    truoc = (
        CheckinAttempt.objects.filter(session=s, sinh_vien=sv, lat__isnull=False)
        .order_by("-id")
        .first()
    )
    nhay = truoc is not None and geo.jump_from_previous(
        geo.Fix(truoc.lat, truoc.lng, truoc.sai_so_m),
        truoc.tao_luc.timestamp(),
        fix,
        now.timestamp(),
        g["max_speed_mps"],
    )
    cung_may = bool(device_id) and (
        CheckinAttempt.objects.filter(session=s, device_id=device_id).exclude(sinh_vien=sv).exists()
    )
    luot.co = _co(face.status, vi_tri, mau, nhay, cung_may)
    luot.ket_qua = KetQuaLuot.DANG_NGO if luot.co else KetQuaLuot.CO_MAT
    return xong()


# ============================================================== GV theo dõi


def danh_sach_phien(gv, session_id, now=None):
    now = now or timezone.now()
    s = _phien_gv(gv, session_id)
    dk = sinh_vien_dang_ky(s.lop_hoc_phan)
    ids = [r.sinh_vien_id for r in dk]
    att = {a.sinh_vien_id: a for a in Attendance.objects.filter(attendance_session=s)}
    luot = {}
    for x in CheckinAttempt.objects.filter(session=s).order_by("id"):
        luot.setdefault(x.sinh_vien_id, []).append(x)
    so_thu_thach = {}
    for sv_id in Challenge.objects.filter(session=s).values_list("sinh_vien_id", flat=True):
        so_thu_thach[sv_id] = so_thu_thach.get(sv_id, 0) + 1
    co_mau = set(
        FaceTemplate.objects.filter(
            sinh_vien_id__in=ids, trang_thai=TrangThaiMau.DUYET, ten_mo_hinh=_cfg().model_name
        ).values_list("sinh_vien_id", flat=True)
    )
    rows, dem = [], {"co_mat": 0, "dang_ngo": 0, "chua": 0}
    for r in dk:
        a = att.get(r.sinh_vien_id)
        ds = luot.get(r.sinh_vien_id, [])
        tot = a.luot_tot_nhat if a and a.luot_tot_nhat_id else (ds[-1] if ds else None)
        if a and a.trang_thai == TrangThaiDiemDanh.CO_MAT:
            dem["co_mat"] += 1
        elif a and a.dang_ngo:
            dem["dang_ngo"] += 1
        else:
            dem["chua"] += 1
        hs = r.sinh_vien.sinh_vien
        rows.append(
            {
                "sinh_vien": r.sinh_vien_id,
                "ma_sv": hs.ma_sv,
                "ho_ten": hs.ho_ten,
                "trang_thai": a.trang_thai if a else TrangThaiDiemDanh.VANG_KHONG_PHEP,
                "di_tre": bool(a and a.di_tre),
                "dang_ngo": bool(a and a.dang_ngo),
                "gv_da_quyet": bool(a and a.nguoi_quyet_id),
                "co_mau_mat": r.sinh_vien_id in co_mau,
                "so_luot": so_thu_thach.get(r.sinh_vien_id, 0),
                "luot_cuoi_luc": ds[-1].tao_luc if ds else None,
                "luot": _luot_payload(tot) if tot else None,
            }
        )
    return {
        "session": s,
        "dang_mo": s.dang_mo_tu_diem_danh(now),
        "dem": dem,
        "rows": rows,
    }


def _luot_payload(x):
    return {
        "id": x.id,
        "ket_qua": x.ket_qua,
        "buoc_dung": x.buoc_dung,
        "ly_do": x.ly_do,
        "co": x.co,
        "diem_mat": x.diem_mat,
        "diem_that": x.diem_that,
        "d_m": x.d_m,
        "r_m": x.r_m,
        "nen_tang": x.nen_tang,
        "co_anh_bang_chung": bool(x.anh_bang_chung),
        "tao_luc": x.tao_luc,
    }


def luot_cua_sv_trong_phien(gv, session_id, sv_id):
    s = _phien_gv(gv, session_id)
    return [
        _luot_payload(x)
        for x in CheckinAttempt.objects.filter(session=s, sinh_vien_id=sv_id).order_by("-id")
    ]
