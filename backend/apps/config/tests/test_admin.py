"""Pha 10: ma trận quyền (ADM-04), cấu hình hệ thống (ADM-05), sao lưu (ADM-08), health đầy đủ."""

import os
import subprocess
import time
from unittest import mock

import pytest

from apps.audit.models import AuditLog
from apps.auth.models import Role
from apps.config import services
from apps.config.matrix import CAC_VAI_TRO, MA_TRAN, NHOM, ma_tran
from apps.config.models import SystemConfig
from core.factories import UserFactory

pytestmark = pytest.mark.django_db
KHAC_ADMIN = [Role.PHONG_DAO_TAO, Role.SINH_VIEN, Role.GIAO_VIEN, Role.KE_TOAN]


@pytest.fixture
def admin(login_as):
    return login_as(UserFactory(role=Role.ADMIN))


@pytest.fixture
def thu_muc(settings, tmp_path):
    settings.BACKUP_DIR = tmp_path
    return tmp_path


# ------------------------------------------------------------------ ma trận quyền


def test_ma_tran_du_5_vai_tro_moi_dong_va_chi_doc(admin):
    res = admin.get("/api/admin/permissions/")
    assert res.status_code == 200
    assert res.data["vai_tro"] == [v.value for v in CAC_VAI_TRO]
    assert len(res.data["results"]) == len(MA_TRAN) == 22
    for dong in res.data["results"]:
        assert all(set(dong[v.value]) == {"co", "gioi_han"} for v in CAC_VAI_TRO)
    nhom = [d["nhom"] for d in res.data["results"]]
    assert nhom == sorted(nhom, key=NHOM.index)  # cùng nhóm đứng liền nhau để giao diện chia khối
    dong = next(d for d in ma_tran() if d["quyen"] == "Audit log")
    assert dong["PHONG_DAO_TAO"] == {"co": True, "gioi_han": "đào tạo"}
    assert dong["SINH_VIEN"] == {"co": False, "gioi_han": None}
    for phuong_thuc in (admin.post, admin.put, admin.patch, admin.delete):
        assert phuong_thuc("/api/admin/permissions/", {}).status_code == 405


def test_ma_tran_khop_hanh_vi_that(login_as):
    """Vài quyền chính của bảng phải đúng với view thật (hai nơi không được lệch)."""
    co = {d["quyen"]: d for d in ma_tran()}

    def cho_phep(quyen, vai_tro):
        return co[quyen][vai_tro.value]["co"]

    for vt in (Role.ADMIN, *KHAC_ADMIN):
        c = login_as(UserFactory(role=vt))
        assert (c.get("/api/users/").status_code == 200) == cho_phep(
            "Tạo/khóa tài khoản, reset mật khẩu", vt
        )
        assert (c.get("/api/reports/training/").status_code != 403) == cho_phep(
            "Báo cáo đào tạo / xuất đăng ký", vt
        )
        assert (c.get("/api/reports/finance/").status_code != 403) == cho_phep(
            "Báo cáo tài chính / xuất", vt
        )
        assert (c.get("/api/admin/config/").status_code == 200) == cho_phep(
            "Xem ma trận quyền, cấu hình hệ thống, backup", vt
        )


# ------------------------------------------------------------------ cấu hình


def test_doc_cau_hinh_du_6_khoa_voi_mac_dinh(admin):
    res = admin.get("/api/admin/config/")
    assert res.status_code == 200
    items = {i["khoa"]: i for i in res.data["items"]}
    assert list(items) == [
        "max_absent_pct",
        "so_ngay_cho_phep_nhap_diem",
        "backup_retention_days",
        "ck_ngan_hang",
        "ck_so_tai_khoan",
        "ck_chu_tai_khoan",
    ]
    assert items["max_absent_pct"]["gia_tri"] == "20" and items["ck_ngan_hang"]["gia_tri"] == ""
    assert items["max_absent_pct"]["cap_nhat_luc"] is None
    assert items["so_ngay_cho_phep_nhap_diem"]["nhom"] == "Nhập điểm"
    assert res.data["sua_lan_cuoi"] is None


def test_patch_cau_hinh_luu_dung_va_ghi_audit(admin):
    res = admin.patch(
        "/api/admin/config/",
        {
            "max_absent_pct": 25,
            "ck_chu_tai_khoan": "TRUONG  DAI HOC",
            "so_ngay_cho_phep_nhap_diem": "14",
        },
        format="json",
    )
    assert res.status_code == 200
    items = {i["khoa"]: i for i in res.data["items"]}
    assert items["max_absent_pct"]["gia_tri"] == "25"
    assert items["ck_chu_tai_khoan"]["gia_tri"] == "TRUONG DAI HOC"  # gộp khoảng trắng
    assert items["max_absent_pct"]["cap_nhat_luc"] is not None
    assert res.data["sua_lan_cuoi"]["boi"] == AuditLog.objects.first().user.username
    assert SystemConfig.get_int("max_absent_pct", 0) == 25  # nơi khác đọc được ngay (BR-20)
    # Chỉ khóa thật sự đổi mới ghi log (so_ngay… giữ nguyên 14).
    logs = AuditLog.objects.filter(doi_tuong="SystemConfig")
    assert {log.doi_tuong_id for log in logs} == {"max_absent_pct", "ck_chu_tai_khoan"}
    log = logs.get(doi_tuong_id="max_absent_pct")
    assert log.chi_tiet == {"tu": "20", "den": "25"} and log.hanh_dong == "UPDATE"
    assert log.scope == "other"


@pytest.mark.parametrize(
    "khoa,gia_tri",
    [
        ("max_absent_pct", 101),
        ("max_absent_pct", -1),
        ("max_absent_pct", "abc"),
        ("so_ngay_cho_phep_nhap_diem", -5),
        ("backup_retention_days", 0),
        ("ck_ngan_hang", "   "),
        ("ck_so_tai_khoan", "12a45"),
        ("ck_chu_tai_khoan", "Nguyễn Văn A"),
        ("ck_chu_tai_khoan", "nguyen van a"),
        ("khong_co_khoa_nay", 1),
    ],
)
def test_patch_cau_hinh_gia_tri_sai_bi_tu_choi(admin, khoa, gia_tri):
    res = admin.patch("/api/admin/config/", {khoa: gia_tri}, format="json")
    assert res.status_code == 400
    assert khoa in res.data


def test_patch_co_mot_khoa_sai_thi_khong_luu_khoa_nao(admin):
    res = admin.patch(
        "/api/admin/config/", {"max_absent_pct": 30, "backup_retention_days": 0}, format="json"
    )
    assert res.status_code == 400
    assert not SystemConfig.objects.filter(khoa="max_absent_pct").exists()
    assert not AuditLog.objects.filter(doi_tuong="SystemConfig").exists()
    assert admin.patch("/api/admin/config/", {}, format="json").status_code == 400


def test_cau_hinh_chi_admin(login_as):
    for vt in KHAC_ADMIN:
        c = login_as(UserFactory(role=vt))
        assert c.get("/api/admin/config/").status_code == 403
        assert (
            c.patch("/api/admin/config/", {"max_absent_pct": 1}, format="json").status_code == 403
        )
        assert c.get("/api/admin/permissions/").status_code == 403
        assert c.get("/api/admin/backups/").status_code == 403
        assert c.post("/api/admin/backups/").status_code == 403
    from rest_framework.test import APIClient

    assert APIClient().get("/api/admin/config/").status_code == 401


# ------------------------------------------------------------------ sao lưu


def pg_dump_gia(noi_dung=b"PGDMP"):
    """`subprocess.run` giả: ghi nội dung vào file `-f`, như pg_dump thật."""

    def chay(lenh, **kw):
        with open(lenh[lenh.index("-f") + 1], "wb") as f:
            f.write(noi_dung)
        return subprocess.CompletedProcess(lenh, 0, "", "")

    return chay


@pytest.fixture(autouse=False)
def postgres():
    """Giả lập cấu hình PostgreSQL để `tao_backup` không từ chối khi test chạy trên SQLite."""
    cfg = {
        "ENGINE": "django.db.backends.postgresql",
        "HOST": "db",
        "PORT": "5432",
        "USER": "u",
        "NAME": "hethongdangkymonhoc",
        "PASSWORD": "mat-khau-bi-mat",
    }
    with mock.patch.object(services, "cau_hinh_db", return_value=cfg):
        yield


def test_tao_backup_ghi_partial_roi_doi_ten(thu_muc, postgres):
    with mock.patch.object(subprocess, "run", side_effect=pg_dump_gia()) as run:
        ten = services.tao_backup()
    lenh = run.call_args.args[0]
    assert (
        lenh[:2] == ["pg_dump", "-Fc"]
        and ["-h", "db", "-p", "5432", "-U", "u", "-d", "hethongdangkymonhoc"] == lenh[2:10]
    )
    assert (
        run.call_args.kwargs["env"]["PGPASSWORD"] == "mat-khau-bi-mat"
    )  # mật khẩu không nằm trong argv
    assert "mat-khau-bi-mat" not in " ".join(lenh)
    assert ten.startswith("hethongdangkymonhoc_") and ten.endswith(".dump")
    assert (thu_muc / ten).read_bytes() == b"PGDMP"
    assert list(thu_muc.glob("*.partial")) == []  # không còn file dở


def test_tao_backup_loi_pg_dump_khong_de_lai_file(thu_muc, postgres):
    def hong(lenh, **kw):
        open(lenh[lenh.index("-f") + 1], "wb").close()
        return subprocess.CompletedProcess(lenh, 1, "", "pg_dump: lỗi kết nối")

    with mock.patch.object(subprocess, "run", side_effect=hong):
        with pytest.raises(services.BackupError, match="lỗi kết nối"):
            services.tao_backup()
    assert list(thu_muc.iterdir()) == []


def test_tao_backup_chi_postgresql(thu_muc):  # test chạy SQLite
    with pytest.raises(services.BackupError, match="PostgreSQL"):
        services.tao_backup()


def tao_file(thu_muc, ten, tuoi_ngay):
    p = thu_muc / ten
    p.write_bytes(b"x" * 10)
    t = time.time() - tuoi_ngay * 86400
    os.utime(p, (t, t))
    return p


def test_don_backup_cu_theo_retention_chi_xoa_file_backup(thu_muc):
    SystemConfig.objects.create(khoa="backup_retention_days", gia_tri="7")
    cu = tao_file(thu_muc, "hethongdangkymonhoc_20200101_000000.dump", 30)
    moi = tao_file(thu_muc, "hethongdangkymonhoc_20990101_000000.dump", 2)
    la = tao_file(thu_muc, "ghi_chu_cua_admin.txt", 365)  # không đúng mẫu → không đụng tới
    assert services.don_backup_cu() == [cu.name]
    assert not cu.exists() and moi.exists() and la.exists()


def test_job_backup_daily_tao_roi_don(thu_muc, postgres):
    from jobs.tasks import backup_daily

    cu = tao_file(thu_muc, "hethongdangkymonhoc_20200101_000000.dump", 100)
    with mock.patch.object(subprocess, "run", side_effect=pg_dump_gia()):
        kq = backup_daily()
    assert kq["da_xoa"] == [cu.name]
    assert (thu_muc / kq["file"]).exists()
    with mock.patch.object(subprocess, "run", side_effect=OSError("không có pg_dump")):
        with pytest.raises(services.BackupError):
            backup_daily()


def test_danh_sach_backup_moi_nhat_truoc_va_trang_thai_dang_chay(admin, thu_muc):
    tao_file(thu_muc, "hethongdangkymonhoc_20990101_000000.dump", 5)
    moi = tao_file(thu_muc, "hethongdangkymonhoc_20990102_000000.dump", 1)
    res = admin.get("/api/admin/backups/")
    assert res.status_code == 200
    assert [r["ten"] for r in res.data["results"]][0] == moi.name
    assert res.data["results"][0]["dung_luong"] == 10
    assert res.data["dang_chay"] is False and res.data["so_ngay_giu"] == 30

    tao_file(thu_muc, "hethongdangkymonhoc_20990103_000000.dump.partial", 0)
    res = admin.get("/api/admin/backups/")
    assert res.data["dang_chay"] is True
    assert len(res.data["results"]) == 2  # file dở không hiện trong danh sách


def test_file_partial_treo_qua_lau_khong_con_la_dang_chay(thu_muc):
    p = tao_file(thu_muc, "hethongdangkymonhoc_20200101_000000.dump.partial", 0)
    t = time.time() - services.HET_GIO_PG_DUMP - 60
    os.utime(p, (t, t))
    assert services.dang_chay() is False


def test_post_backup_chay_nen_ghi_audit_va_chan_chay_trung(admin, thu_muc):
    with mock.patch("jobs.tasks.backup_daily.delay") as delay:
        res = admin.post("/api/admin/backups/")
        assert res.status_code == 202 and res.data == {"trang_thai": "DANG_CHAY"}
        delay.assert_called_once_with()
    log = AuditLog.objects.get(doi_tuong="Backup")
    assert log.hanh_dong == "CREATE" and log.scope == "other"

    tao_file(thu_muc, "hethongdangkymonhoc_20990103_000000.dump.partial", 0)
    with mock.patch("jobs.tasks.backup_daily.delay") as delay:
        res = admin.post("/api/admin/backups/")
        assert res.status_code == 409 and res.data["error"]["code"] == "TRANG_THAI_KHONG_HOP_LE"
        delay.assert_not_called()


def test_khong_co_api_restore_hay_tai_xuong(admin, thu_muc):
    tao_file(thu_muc, "hethongdangkymonhoc_20990101_000000.dump", 1)
    for url in ("/api/admin/backups/hethongdangkymonhoc_20990101_000000.dump/", "/api/admin/backups/restore/"):
        assert admin.get(url).status_code == 404
    assert admin.delete("/api/admin/backups/").status_code == 405


# ------------------------------------------------------------------ health


def test_health_full_bao_redis_va_worker(client):
    assert client.get("/api/health/").json() == {"status": "ok", "db": True}  # không đổi
    with mock.patch("core.views._worker_ok", return_value=True):
        body = client.get("/api/health/?full=1").json()
    assert body == {"status": "ok", "db": True, "redis": True, "worker": True}
    with mock.patch("core.views._worker_ok", return_value=False):
        res = client.get("/api/health/?full=1")
    assert res.status_code == 200 and res.json()["status"] == "degraded"
    assert res.json()["worker"] is False


def test_worker_ok_khong_co_broker_tra_false():
    from core.views import _worker_ok

    with mock.patch("config.celery.app.control.ping", side_effect=OSError("mất broker")):
        assert _worker_ok() is False
