"""Tự điểm danh khuôn mặt + GPS (KH §7, checklist Đợt 2). Engine khuôn mặt giả, không cần model."""

import secrets
from datetime import timedelta
from types import SimpleNamespace

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone

from apps.attendance import crypto
from apps.attendance import tu_diem_danh as tdd
from apps.attendance.models import (
    Attendance,
    AttendanceRequest,
    AttendanceSession,
    Challenge,
    CheckinAttempt,
    FaceTemplate,
    TrangThaiMau,
)
from apps.attendance.tests.face_fakes import E0, FakeEngine, fa, vec
from apps.audit.models import AuditLog
from apps.auth.models import Role
from apps.registration.models import Registration
from apps.training.models import TrangThaiLop
from core.factories import ClassSectionFactory, StudentProfileFactory, UserFactory

pytestmark = pytest.mark.django_db
M = 1 / 111_195  # ~1 m theo vĩ độ
TAM = (10.98, 106.67)
TURN_LEFT = [0.0, -0.1, -0.3, -0.3]


@pytest.fixture(autouse=True)
def moi_truong(tmp_path, settings, monkeypatch):
    settings.FACE_STORAGE_DIR = tmp_path
    # Chỉ thay `secrets` trong tu_diem_danh: Django cũng dùng secrets.choice để sinh salt mật khẩu.
    fake = SimpleNamespace(
        choice=lambda xs: "turn_left",
        token_urlsafe=secrets.token_urlsafe,
        token_bytes=secrets.token_bytes,
    )
    monkeypatch.setattr(tdd, "secrets", fake)
    eng = FakeEngine({})
    monkeypatch.setattr(tdd, "get_engine", lambda: eng)
    return eng


@pytest.fixture
def engine(moi_truong):
    return moi_truong


def khung(engine, *analyses, prefix="k"):
    files = []
    for i, a in enumerate(analyses):
        key = f"{prefix}{i}".encode()
        engine.results[key] = a
        files.append(SimpleUploadedFile(f"{prefix}{i}.jpg", key, content_type="image/jpeg"))
    return files


def khung_dat(engine, emb=E0, prefix="k", **kw):
    return khung(engine, *(fa(yaw_proxy=y, embedding=emb, **kw) for y in TURN_LEFT), prefix=prefix)


def gps(lat=TAM[0], lng=TAM[1], acc=5, n=5, mock=False, dlat=0.0):
    return [
        {"lat": lat + dlat, "lng": lng, "acc": acc, "ts": i * 1000, "mock": mock} for i in range(n)
    ]


def mau_duyet(sv_user, ten=None):
    return FaceTemplate.objects.create(
        sinh_vien=sv_user,
        ten_mo_hinh=ten or tdd._cfg().model_name,
        embedding=crypto.encrypt(crypto.embedding_to_bytes(E0)),
        trang_thai=TrangThaiMau.DUYET,
    )


@pytest.fixture
def lop():
    lop = ClassSectionFactory(trang_thai=TrangThaiLop.DANG_HOC)
    sv = [StudentProfileFactory() for _ in range(3)]
    for p in sv:
        Registration.objects.create(sinh_vien=p.user, lop_hoc_phan=lop)
    s = AttendanceSession.objects.create(
        lop_hoc_phan=lop, ngay_hoc=timezone.localdate(), buoi="SANG", tiet_bat_dau=1
    )
    return lop, s, [p.user for p in sv]


@pytest.fixture
def gv(login_as, lop):
    return login_as(lop[0].giao_vien.user)


def url(s, tail):
    return f"/api/attendance/sessions/{s.id}/{tail}/"


def mo(gv, s, **kw):
    return gv.post(url(s, "mo-phien"), {"mau_gps": gps(), **kw}, format="json")


def thu_thach(c, s):
    return c.post(url(s, "challenge"))


def gui(c, s, nonce, files, mau=None, **kw):
    data = {"nonce": nonce, "khung": files, "mau_gps": _json(mau or gps(n=3)), **kw}
    return c.post(url(s, "checkin"), data, format="multipart")


def _json(v):
    import json

    return json.dumps(v)


@pytest.fixture
def phien_mo(gv, lop):
    _, s, svs = lop
    assert mo(gv, s).status_code == 200
    for u in svs:
        mau_duyet(u)
    return s, svs


def diem_danh(login_as, engine, s, u, files=None, **kw):
    c = login_as(u)
    r = thu_thach(c, s)
    assert r.status_code == 201, r.data
    return gui(c, s, r.data["nonce"], files or khung_dat(engine, prefix=f"u{u.id}-"), **kw)


# ------------------------------------------------------------------ mở phiên


def test_mo_phien_tao_vang_ca_lop_va_khong_de_co_phep(gv, lop):
    _, s, svs = lop
    Attendance.objects.create(
        attendance_session=s,
        lop_hoc_phan=s.lop_hoc_phan,
        ngay_hoc=s.ngay_hoc,
        sinh_vien=svs[0],
        trang_thai="VANG_CO_PHEP",
    )
    r = mo(gv, s, r0=30, kiem_tra_phong=True)
    assert r.status_code == 200 and r.data["dang_mo"] and r.data["ban_kinh_m"] == 30
    tt = dict(
        Attendance.objects.filter(attendance_session=s).values_list("sinh_vien", "trang_thai")
    )
    assert tt == {
        svs[0].id: "VANG_CO_PHEP",
        svs[1].id: "VANG_KHONG_PHEP",
        svs[2].id: "VANG_KHONG_PHEP",
    }
    s.refresh_from_db()
    assert s.trang_thai == "DA_DIEM_DANH" and s.tam_lat == pytest.approx(TAM[0])


def test_mo_phien_gv_khac_lop_va_gps_kem(login_as, gv, lop):
    _, s, _ = lop
    khac = login_as(UserFactory(role=Role.GIAO_VIEN))
    assert mo(khac, s).status_code == 403
    r = gv.post(url(s, "mo-phien"), {"mau_gps": gps(n=4)}, format="json")
    assert r.status_code == 409 and r.data["error"]["details"]["ly_do"] == "GPS_KEM"
    assert mo(gv, s).status_code == 200
    assert mo(gv, s).status_code == 409  # không mở chồng


def test_chi_mo_buoi_hom_nay(gv, lop):
    _, s, _ = lop
    s.ngay_hoc = timezone.localdate() - timedelta(days=1)
    s.save()
    assert mo(gv, s).status_code == 409


def test_dong_va_mo_lai_giu_ket_qua_va_so_luot(login_as, engine, gv, phien_mo):
    s, svs = phien_mo
    assert diem_danh(login_as, engine, s, svs[0]).data["ket_qua"] == "CO_MAT"
    assert gv.post(url(s, "dong-phien")).status_code == 200
    assert thu_thach(login_as(svs[1]), s).status_code == 409  # phiên đóng
    r = gv.post(url(s, "mo-lai"), {"thoi_han": 5}, format="json")
    assert r.status_code == 200 and r.data["dang_mo"]
    assert gv.post(url(s, "mo-lai")).status_code == 409  # đang mở
    s.refresh_from_db()
    assert s.tam_lat == pytest.approx(TAM[0])
    assert Attendance.objects.get(attendance_session=s, sinh_vien=svs[0]).trang_thai == "CO_MAT"
    assert Challenge.objects.filter(session=s, sinh_vien=svs[0]).count() == 1


# ------------------------------------------------------------------ thử thách


def test_thu_thach_can_mau_duyet_dung_mo_hinh(login_as, gv, lop):
    _, s, svs = lop
    mo(gv, s)
    c = login_as(svs[0])
    r = thu_thach(c, s)
    assert r.status_code == 409 and r.data["error"]["details"]["ly_do"] == "CHUA_CO_MAT"
    mau_duyet(svs[0], ten="mo_hinh_cu")
    r = thu_thach(c, s)
    assert r.status_code == 409 and r.data["error"]["details"]["ly_do"] == "MO_HINH_DOI"
    assert Challenge.objects.count() == 0  # không tính lượt
    assert login_as(svs[0]).get("/api/attendance/face/me/").data["can_dang_ky_lai"] is True


def test_toi_da_5_luot(login_as, phien_mo):
    s, svs = phien_mo
    c = login_as(svs[0])
    con = [thu_thach(c, s).data["luot_con_lai"] for _ in range(5)]
    assert con == [4, 3, 2, 1, 0]
    r = thu_thach(c, s)
    assert r.status_code == 429 and r.data["error"]["details"]["ly_do"] == "HET_LUOT"


def test_sv_ngoai_lop_khong_xin_duoc(login_as, phien_mo):
    s, _ = phien_mo
    assert thu_thach(login_as(StudentProfileFactory().user), s).status_code == 403


# ------------------------------------------------------------------ 6 bước


def test_co_mat_va_khong_lo_diem_so(login_as, engine, phien_mo):
    s, svs = phien_mo
    r = diem_danh(login_as, engine, s, svs[0])
    assert r.status_code == 200
    assert (r.data["ket_qua"], r.data["trang_thai"], r.data["ly_do"]) == ("CO_MAT", "CO_MAT", None)
    assert not {"diem_mat", "diem_that", "d_m", "r_m"} & set(r.data)
    assert r.data["luot_con_lai"] == 4
    assert thu_thach(login_as(svs[0]), s).data["error"]["details"]["ly_do"] == "DA_CO_MAT"


def test_nonce_dung_lai_bi_chan(login_as, engine, phien_mo):
    s, svs = phien_mo
    c = login_as(svs[0])
    nonce = thu_thach(c, s).data["nonce"]
    assert gui(c, s, nonce, khung_dat(engine)).status_code == 200
    r = gui(c, s, nonce, khung_dat(engine))
    assert r.status_code == 409 and r.data["error"]["details"]["ly_do"] == "NONCE_SAI"
    # nonce của SV khác
    n2 = thu_thach(login_as(svs[1]), s).data["nonce"]
    assert gui(c, s, n2, khung_dat(engine)).status_code == 409
    assert CheckinAttempt.objects.count() == 1  # bước 1–2 không ghi lượt


def test_nonce_het_han(login_as, engine, phien_mo):
    s, svs = phien_mo
    c = login_as(svs[0])
    nonce = thu_thach(c, s).data["nonce"]
    Challenge.objects.update(het_han_luc=timezone.now() - timedelta(seconds=1))
    assert gui(c, s, nonce, khung_dat(engine)).status_code == 409


def _ly_do(r):
    return r.data["ket_qua"], r.data["ly_do"]["ma"], CheckinAttempt.objects.first().buoc_dung


def test_ma_phong(login_as, engine, gv, lop):
    _, s, svs = lop
    mo(gv, s, kiem_tra_phong=True)
    mau_duyet(svs[0])
    mau_duyet(svs[1])
    r = diem_danh(login_as, engine, s, svs[0], ma_phong="AAAAAAAA")
    assert _ly_do(r) == ("KHONG_DAT", "MA_PHONG_SAI", 3)
    ma = gv.get(url(s, "room-token")).data["ma"]
    assert diem_danh(login_as, engine, s, svs[1], ma_phong=ma.lower()).data["ket_qua"] == "CO_MAT"


def test_gps_kem_va_qua_xa(login_as, engine, phien_mo):
    s, svs = phien_mo
    r = diem_danh(login_as, engine, s, svs[0], mau=gps(n=3, acc=50))
    assert _ly_do(r) == ("KHONG_DAT", "GPS_KEM", 4)
    # r = 20 + 5 + 5 = 30 m; cách 100 m > 2r
    r = diem_danh(login_as, engine, s, svs[1], mau=gps(n=3, dlat=100 * M))
    assert _ly_do(r) == ("KHONG_DAT", "QUA_XA", 4)
    assert engine.results.keys().isdisjoint(k for k, *_ in engine.calls)  # không chạy mô hình


def test_anh_gia_va_khong_khop(login_as, engine, phien_mo):
    s, svs = phien_mo
    r = diem_danh(login_as, engine, s, svs[0], files=khung_dat(engine, spoof_score=0.3))
    assert _ly_do(r) == ("KHONG_DAT", "ANH_GIA", 5)
    r = diem_danh(login_as, engine, s, svs[1], files=khung_dat(engine, emb=vec(0.1), prefix="x"))
    assert _ly_do(r) == ("KHONG_DAT", "KHONG_KHOP", 6)
    r = diem_danh(
        login_as,
        engine,
        s,
        svs[2],
        files=khung(engine, *(fa(yaw_proxy=y) for y in [0.0, 0.1, 0.3, 0.3]), prefix="y"),
    )
    assert _ly_do(r) == ("KHONG_DAT", "SAI_HANH_DONG", 5)


# ------------------------------------------------------------------ bảng quyết định + cờ


def test_lech_nhe_la_dang_ngo_co_anh_bang_chung(login_as, engine, gv, phien_mo):
    s, svs = phien_mo
    r = diem_danh(login_as, engine, s, svs[0], mau=gps(n=3, dlat=45 * M))  # r=30 < 45 ≤ 60
    assert r.data["ket_qua"] == "DANG_NGO" and r.data["dang_ngo"]
    luot = CheckinAttempt.objects.get()
    assert luot.co == ["LECH_NHE"] and luot.anh_bang_chung
    a = Attendance.objects.get(attendance_session=s, sinh_vien=svs[0])
    assert (a.trang_thai, a.dang_ngo, a.luot_tot_nhat_id) == ("VANG_KHONG_PHEP", True, luot.id)
    res = gv.get(f"/api/attendance/attempts/{luot.id}/evidence/")
    assert res.status_code == 200 and res["Content-Type"] == "image/jpeg"
    assert AuditLog.objects.filter(doi_tuong="CheckinAttempt").exists()


def test_sat_nguong_la_dang_ngo(login_as, engine, phien_mo):
    s, svs = phien_mo
    r = diem_danh(login_as, engine, s, svs[0], files=khung_dat(engine, emb=vec(0.45)))
    assert r.data["ket_qua"] == "DANG_NGO"
    assert CheckinAttempt.objects.get().co == ["SAT_NGUONG"]


def test_vi_tri_gia_va_cung_may(login_as, engine, phien_mo):
    s, svs = phien_mo
    r = diem_danh(login_as, engine, s, svs[0], mau=gps(n=3, mock=True), device_id="may-1")
    assert r.data["ket_qua"] == "DANG_NGO"
    assert CheckinAttempt.objects.get(sinh_vien=svs[0]).co == ["VI_TRI_GIA"]
    r = diem_danh(login_as, engine, s, svs[1], device_id="may-1", nen_tang="web")
    assert r.data["ket_qua"] == "DANG_NGO"
    luot = CheckinAttempt.objects.get(sinh_vien=svs[1])
    assert luot.co == ["CUNG_MAY"] and luot.nen_tang == "web"


def test_buoc_nhay_giua_cac_mau(login_as, engine, phien_mo):
    s, svs = phien_mo
    mau = gps(n=3)
    mau[2]["lat"] += 25 * M  # 25 m trong 1 s → 25 m/s; thêm 10 m nữa
    mau[2]["lat"] += 10 * M
    r = diem_danh(login_as, engine, s, svs[0], mau=mau)
    assert "BUOC_NHAY" in CheckinAttempt.objects.get().co and r.data["ket_qua"] == "DANG_NGO"


def test_chi_nang_hang(lop, phien_mo):
    s, svs = phien_mo
    a = tdd._nang_hang(s, svs[0].id, "CO_MAT", None)
    assert a.trang_thai == "CO_MAT"
    a = tdd._nang_hang(s, svs[0].id, "DANG_NGO", None)
    assert (a.trang_thai, a.dang_ngo) == ("CO_MAT", False)


# ------------------------------------------------------------------ GV quyết tay


def test_gv_quyet_tay_khong_bi_ghi_de(login_as, engine, gv, phien_mo):
    s, svs = phien_mo
    r = gv.patch(
        url(s, "tu-diem-danh"),
        {"sinh_vien": [svs[0].id], "trang_thai": "VANG_KHONG_PHEP"},
        format="json",
    )
    assert r.status_code == 200
    assert diem_danh(login_as, engine, s, svs[0]).data["trang_thai"] == "VANG_KHONG_PHEP"


def test_diem_danh_thu_cong_cho_sv_chua_co_mat(login_as, gv, lop):
    _, s, svs = lop
    mo(gv, s)
    r = gv.patch(
        url(s, "tu-diem-danh"), {"sinh_vien": [svs[0].id], "trang_thai": "CO_MAT"}, format="json"
    )
    row = next(x for x in r.data["rows"] if x["sinh_vien"] == svs[0].id)
    assert (row["trang_thai"], row["gv_da_quyet"], row["co_mau_mat"]) == ("CO_MAT", True, False)
    assert r.data["dem"] == {"co_mat": 1, "dang_ngo": 0, "chua": 2}
    bad = gv.patch(
        url(s, "tu-diem-danh"),
        {"sinh_vien": [StudentProfileFactory().user_id], "trang_thai": "CO_MAT"},
        format="json",
    )
    assert bad.status_code == 400


def test_gv_dat_di_tre_khi_phien_mo(gv, phien_mo):
    s, svs = phien_mo

    def dat(tt, **kw):
        r = gv.patch(
            url(s, "tu-diem-danh"),
            {"sinh_vien": [svs[0].id], "trang_thai": tt, **kw},
            format="json",
        )
        assert r.status_code == 200
        return next(x for x in r.data["rows"] if x["sinh_vien"] == svs[0].id)

    row = dat("CO_MAT", di_tre=True)
    assert (row["trang_thai"], row["di_tre"]) == ("CO_MAT", True)
    assert dat("CO_MAT")["di_tre"] is False  # không gửi di_tre = có mặt đúng giờ
    assert dat("VANG_CO_PHEP", di_tre=True)["di_tre"] is False  # chỉ có nghĩa khi có mặt


def test_duyet_yeu_cau_khoa_ket_qua_khoi_ghi_de_cua_phien_mo(login_as, engine, gv, lop, phien_mo):
    s, svs = phien_mo
    assert diem_danh(login_as, engine, s, svs[0]).data["trang_thai"] == "CO_MAT"
    att = Attendance.objects.get(attendance_session=s, sinh_vien=svs[0])
    yc = AttendanceRequest.objects.create(
        attendance=att,
        sinh_vien=svs[0],
        ly_do="Có giấy phép",
        trang_thai_mong_muon="VANG_CO_PHEP",
    )
    ok = gv.patch(f"/api/attendance/requests/{yc.id}/", {"trang_thai": "DUYET"}, format="json")
    assert ok.status_code == 200
    att.refresh_from_db()
    assert (att.trang_thai, att.nguoi_quyet_id) == ("VANG_CO_PHEP", lop[0].giao_vien.user_id)
    # Phiên vẫn mở, SV điểm danh lại: kết quả GV vừa duyệt không bị ghi đè.
    assert diem_danh(login_as, engine, s, svs[0], files=None).data["trang_thai"] == "VANG_CO_PHEP"


def test_danh_sach_buoi_co_co_phien_va_so_dang_ngo(login_as, engine, gv, lop):
    _, s, svs = lop

    def buoi_cua_lop():
        r = gv.get("/api/attendance/sessions/", {"lop_hoc_phan": s.lop_hoc_phan_id})
        assert r.status_code == 200
        return next(x for x in r.data["results"] if x["id"] == s.id)

    b = buoi_cua_lop()
    assert (b["da_mo_tu_diem_danh"], b["dang_mo_tu_diem_danh"], b["so_dang_ngo"]) == (
        False,
        False,
        0,
    )
    assert mo(gv, s).status_code == 200
    b = buoi_cua_lop()
    assert (b["da_mo_tu_diem_danh"], b["dang_mo_tu_diem_danh"], b["so_dang_ngo"]) == (
        True,
        True,
        0,
    )
    Attendance.objects.filter(attendance_session=s, sinh_vien=svs[0]).update(dang_ngo=True)
    assert buoi_cua_lop()["so_dang_ngo"] == 1
    gv.post(url(s, "dong-phien"))
    b = buoi_cua_lop()
    assert (b["da_mo_tu_diem_danh"], b["dang_mo_tu_diem_danh"]) == (True, False)


def test_gv_duyet_luot_dang_ngo(login_as, engine, gv, phien_mo):
    s, svs = phien_mo
    diem_danh(login_as, engine, s, svs[0], mau=gps(n=3, dlat=45 * M))
    luot = CheckinAttempt.objects.get()
    assert (
        gv.post(f"/api/attendance/attempts/{luot.id}/quyet/", {"co_mat": True}).status_code == 200
    )
    a = Attendance.objects.get(attendance_session=s, sinh_vien=svs[0])
    assert (a.trang_thai, a.dang_ngo, a.nguoi_quyet_id) == (
        "CO_MAT",
        False,
        s.lop_hoc_phan.giao_vien.user_id,
    )
    chi_tiet = gv.get(url(s, "luot"), {"sinh_vien": svs[0].id})
    assert chi_tiet.data[0]["co"] == ["LECH_NHE"]


def test_luu_ca_lop_danh_dau_gv_da_quyet(gv, phien_mo):
    s, svs = phien_mo
    body = {"records": [{"sinh_vien": u.id, "trang_thai": "CO_MAT"} for u in svs]}
    assert (
        gv.put(f"/api/attendance/sessions/{s.id}/records/", body, format="json").status_code == 200
    )
    assert not Attendance.objects.filter(attendance_session=s, nguoi_quyet__isnull=True).exists()


def test_sv_khong_goi_duoc_api_gv(login_as, phien_mo):
    s, svs = phien_mo
    c = login_as(svs[0])
    assert c.get(url(s, "tu-diem-danh")).status_code == 403
    assert c.post(url(s, "dong-phien")).status_code == 403


# ------------------------------------------------------------------ tính lại tâm


def test_tinh_lai_tam_chi_nang_hang(login_as, engine, gv, lop):
    lop_, s, _ = lop
    svs = [StudentProfileFactory().user for _ in range(5)]
    for u in svs:
        Registration.objects.create(sinh_vien=u, lop_hoc_phan=lop_)
        mau_duyet(u)
    mo(gv, s)
    assert gv.post(url(s, "tinh-lai-tam")).status_code == 409  # chưa lệch
    for u in svs:  # cả lớp lệch ~45 m về phía bắc: đều "lệch nhẹ"
        assert (
            diem_danh(login_as, engine, s, u, mau=gps(n=3, dlat=45 * M)).data["ket_qua"]
            == "DANG_NGO"
        )
    assert gv.get(url(s, "tu-diem-danh")).data["goi_y_tinh_lai_tam"] is True
    r = gv.post(url(s, "tinh-lai-tam"))
    assert r.status_code == 200 and r.data["so_luot_nang_hang"] == 5
    assert Attendance.objects.filter(attendance_session=s, trang_thai="CO_MAT").count() == 5
    s.refresh_from_db()
    assert s.tam_goc_lat == pytest.approx(TAM[0]) and s.tam_lat == pytest.approx(TAM[0] + 45 * M)


# ------------------------------------------------------------------ đồng ý + đăng ký + duyệt mặt


def test_dang_ky_va_duyet_mat(login_as, engine, gv, lop, tmp_path):
    lop_, s, svs = lop
    c = login_as(svs[0])
    anh = khung(engine, fa(embedding=vec(0.95, 1)), fa(embedding=vec(0.95, 2)), fa(embedding=E0))
    assert c.post("/api/attendance/faces/enroll/", {"anh": anh}).status_code == 409  # chưa đồng ý
    assert c.post("/api/attendance/consent/").data["da_dong_y"] is True
    anh = khung(engine, fa(embedding=vec(0.95, 1)), fa(embedding=vec(0.95, 2)), fa(embedding=E0))
    r = c.post("/api/attendance/faces/enroll/", {"anh": anh})
    assert r.status_code == 201 and r.data["trang_thai"] == "CHO_DUYET"
    m = FaceTemplate.objects.get()
    raw = (tmp_path / m.thu_muc_anh / "0.jpg").read_bytes()
    assert b"k0" not in raw  # ảnh trên đĩa đã mã hóa

    khac = login_as(UserFactory(role=Role.GIAO_VIEN))
    assert khac.get("/api/attendance/faces/pending/").data == []
    assert khac.post(f"/api/attendance/faces/{m.id}/review/", {"duyet": True}).status_code == 403
    assert gv.get("/api/attendance/faces/pending/").data[0]["id"] == m.id
    photo = gv.get(f"/api/attendance/faces/{m.id}/photos/?i=0")
    assert photo.status_code == 200 and photo.content == b"k0"
    assert gv.post(f"/api/attendance/faces/{m.id}/review/", {"duyet": False}).status_code == 400
    assert gv.post(f"/api/attendance/faces/{m.id}/review/", {"duyet": True}).status_code == 200
    m.refresh_from_db()
    assert m.trang_thai == "DUYET" and m.thu_muc_anh == "" and m.embedding is not None
    assert not (tmp_path / "dang_ky" / str(m.id)).exists()  # duyệt xong xóa ảnh
    assert c.get("/api/attendance/face/me/").data["trang_thai"] == "DUYET"
    assert AuditLog.objects.filter(doi_tuong="FaceTemplate").count() >= 3


def test_dang_ky_anh_loi_tra_ly_do_tung_anh(login_as, engine, lop):
    _, _, svs = lop
    c = login_as(svs[0])
    c.post("/api/attendance/consent/")
    anh = khung(engine, fa(), fa(sharpness=5), fa(spoof_score=0.2))
    r = c.post("/api/attendance/faces/enroll/", {"anh": anh})
    assert r.status_code == 400
    assert r.data["anh"] == [
        "Ảnh 2: Ảnh bị mờ, hãy giữ máy chắc tay. Ảnh 3: Không xác nhận được người thật."
    ]


def test_pdt_tu_choi_va_sv_xoa_mat(login_as, lop):
    _, _, svs = lop
    pdt = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    m = FaceTemplate.objects.create(sinh_vien=svs[0], ten_mo_hinh="x", embedding=b"1")
    r = pdt.post(f"/api/attendance/faces/{m.id}/review/", {"duyet": False, "ly_do": "Ảnh tối"})
    assert r.data["trang_thai"] == "TU_CHOI"
    c = login_as(svs[0])
    assert c.get("/api/attendance/face/me/").data["ly_do"] == "Ảnh tối"
    mau_duyet(svs[0])
    assert c.delete("/api/attendance/face/me/").data["trang_thai"] == "TU_CHOI"
    assert not FaceTemplate.objects.filter(trang_thai="DUYET").exists()
    c.post("/api/attendance/consent/")
    assert c.delete("/api/attendance/consent/").data["da_dong_y"] is False


def test_open_sessions_cua_sv(login_as, phien_mo):
    s, svs = phien_mo
    data = login_as(svs[0]).get("/api/attendance/open-sessions/").data
    assert [x["id"] for x in data] == [s.id] and data[0]["luot_con_lai"] == 5
    assert login_as(StudentProfileFactory().user).get("/api/attendance/open-sessions/").data == []
