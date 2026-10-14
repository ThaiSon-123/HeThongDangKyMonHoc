"""Cấu hình hệ thống (ADM-05) và sao lưu (ADM-08)."""

import os
import re
import subprocess
from datetime import datetime, timedelta
from pathlib import Path

from django.conf import settings
from django.utils import timezone

from apps.config.models import SystemConfig

# ----------------------------------------------------------------- cấu hình (ADM-05)


def _so_nguyen(thap, cao=None):
    def kiem_tra(v):
        s = str(v).strip()
        if not re.fullmatch(r"\d+", s) or int(s) < thap or (cao is not None and int(s) > cao):
            gioi_han = f"từ {thap} đến {cao}" if cao is not None else f"từ {thap} trở lên"
            raise ValueError(f"Phải là số nguyên {gioi_han}.")
        return str(int(s))

    return kiem_tra


def _chuoi(v):
    s = " ".join(str(v).split())
    if not s:
        raise ValueError("Không được để trống.")
    return s


def _chu_so(v):
    s = str(v).strip()
    if not re.fullmatch(r"\d+", s):
        raise ValueError("Chỉ gồm chữ số.")
    return s


def _chu_hoa_khong_dau(v):
    s = " ".join(str(v).split())
    if not re.fullmatch(r"[A-Z]+( [A-Z]+)*", s):
        raise ValueError("Chữ in hoa không dấu, ví dụ NGUYEN VAN A.")
    return s


# (khóa, nhóm, mô tả, mặc định, hàm kiểm tra) — đúng 6 khóa (design.md 9.3)
CAU_HINH = [
    (
        "max_absent_pct",
        "Điểm danh",
        "% buổi vắng không phép tối đa; vượt thì hiện cờ cảnh báo (BR-20)",
        "20",
        _so_nguyen(0, 100),
    ),
    (
        "so_ngay_cho_phep_nhap_diem",
        "Nhập điểm",
        "Số ngày được nhập điểm sau khi lớp kết thúc (BR-13)",
        "14",
        _so_nguyen(0),
    ),
    (
        "backup_retention_days",
        "Sao lưu",
        "Số ngày giữ file sao lưu",
        "30",
        _so_nguyen(1),
    ),
    (
        "ck_ngan_hang",
        "Nhận chuyển khoản học phí",
        "Ngân hàng nhận chuyển khoản học phí",
        "",
        _chuoi,
    ),
    (
        "ck_so_tai_khoan",
        "Nhận chuyển khoản học phí",
        "Số tài khoản nhận học phí",
        "",
        _chu_so,
    ),
    (
        "ck_chu_tai_khoan",
        "Nhận chuyển khoản học phí",
        "Chủ tài khoản (chữ in hoa không dấu)",
        "",
        _chu_hoa_khong_dau,
    ),
]
_THEO_KHOA = {c[0]: c for c in CAU_HINH}


def doc_cau_hinh():
    """6 khóa cấu hình kèm giá trị hiện tại (chưa đặt thì là mặc định) và lần sửa gần nhất."""
    luu = {c.khoa: c for c in SystemConfig.objects.filter(khoa__in=_THEO_KHOA)}
    return [
        {
            "khoa": khoa,
            "nhom": nhom,
            "mo_ta": mo_ta,
            "mac_dinh": mac_dinh,
            "gia_tri": luu[khoa].gia_tri if khoa in luu else mac_dinh,
            "cap_nhat_luc": luu[khoa].cap_nhat_luc if khoa in luu else None,
        }
        for khoa, nhom, mo_ta, mac_dinh, _ in CAU_HINH
    ]


def sua_lan_cuoi():
    """`{boi, luc}` của lần sửa cấu hình gần nhất (lấy từ audit log), chưa sửa lần nào → None."""
    from apps.audit.models import AuditLog

    log = (
        AuditLog.objects.filter(doi_tuong="SystemConfig")
        .select_related("user")
        .order_by("-thoi_gian")
        .first()
    )
    if log is None:
        return None
    return {"boi": log.user.username if log.user else "", "luc": log.thoi_gian}


def cap_nhat_cau_hinh(du_lieu):
    """Kiểm tra rồi lưu các khóa trong `du_lieu`. Trả `(lỗi, thay_đổi)`: nếu có lỗi thì **không lưu gì**.
    `thay_đổi` = `[(khóa, giá_trị_cũ, giá_trị_mới)]` chỉ gồm khóa thật sự đổi (để ghi audit log)."""
    loi, moi = {}, {}
    for khoa, v in du_lieu.items():
        if khoa not in _THEO_KHOA:
            loi[khoa] = ["Không có khóa cấu hình này."]
            continue
        try:
            moi[khoa] = _THEO_KHOA[khoa][4](v)
        except ValueError as e:
            loi[khoa] = [str(e)]
    if loi:
        return loi, []
    hien_tai = {c["khoa"]: c["gia_tri"] for c in doc_cau_hinh()}
    thay_doi = [(k, hien_tai[k], v) for k, v in moi.items() if hien_tai[k] != v]
    for khoa, _, gia_tri in thay_doi:
        SystemConfig.objects.update_or_create(
            khoa=khoa, defaults={"gia_tri": gia_tri, "mo_ta": _THEO_KHOA[khoa][2]}
        )
    return {}, thay_doi


# ----------------------------------------------------------------- sao lưu (ADM-08)

MAU_FILE = "hpsv_*.dump"
HET_GIO_PG_DUMP = 600  # giây; cũng là thời gian tối đa một file `.partial` còn coi là "đang chạy"


class BackupError(Exception):
    pass


def thu_muc_backup() -> Path:
    thu_muc = Path(settings.BACKUP_DIR)
    thu_muc.mkdir(parents=True, exist_ok=True)
    return thu_muc


def dang_chay(now: datetime | None = None) -> bool:
    """Có file `.partial` mới (chưa quá thời gian chờ) = một lần sao lưu đang chạy."""
    gio = (now or timezone.now()).timestamp()
    return any(
        gio - p.stat().st_mtime < HET_GIO_PG_DUMP
        for p in thu_muc_backup().glob(MAU_FILE + ".partial")
    )


def liet_ke():
    """Các file sao lưu hoàn chỉnh, mới nhất trước."""
    files = sorted(thu_muc_backup().glob(MAU_FILE), key=lambda p: p.stat().st_mtime, reverse=True)
    return [
        {
            "ten": p.name,
            "dung_luong": p.stat().st_size,
            "tao_luc": datetime.fromtimestamp(
                p.stat().st_mtime, tz=timezone.get_current_timezone()
            ),
        }
        for p in files
    ]


def cau_hinh_db():
    return settings.DATABASES["default"]


def tao_backup(now: datetime | None = None) -> str:
    """`pg_dump -Fc` vào `BACKUP_DIR`. Ghi ra `.partial` rồi đổi tên khi xong nên danh sách không
    bao giờ thấy file dở. Trả tên file; lỗi → `BackupError`."""
    db = cau_hinh_db()
    if "postgresql" not in db["ENGINE"]:
        raise BackupError("Chỉ sao lưu được khi dùng PostgreSQL.")
    ten = f"hpsv_{timezone.localtime(now):%Y%m%d_%H%M%S}.dump"
    dich = thu_muc_backup() / ten
    tam = dich.with_name(ten + ".partial")
    lenh = [
        "pg_dump",
        "-Fc",
        "-h",
        str(db["HOST"]),
        "-p",
        str(db["PORT"] or 5432),
        "-U",
        str(db["USER"]),
        "-d",
        str(db["NAME"]),
        "-f",
        str(tam),
    ]
    try:
        kq = subprocess.run(  # noqa: S603 — lệnh cố định, tham số lấy từ settings, không từ người dùng
            lenh,
            env={**os.environ, "PGPASSWORD": str(db["PASSWORD"])},
            capture_output=True,
            text=True,
            timeout=HET_GIO_PG_DUMP,
        )
    except (OSError, subprocess.TimeoutExpired) as e:
        tam.unlink(missing_ok=True)
        raise BackupError(f"Không chạy được pg_dump: {e}") from e
    if kq.returncode != 0:
        tam.unlink(missing_ok=True)
        raise BackupError(kq.stderr.strip()[:500] or "pg_dump thất bại.")
    tam.replace(dich)
    return ten


def don_backup_cu(now: datetime | None = None) -> list[str]:
    """Xóa file sao lưu quá `backup_retention_days` ngày (theo thời gian sửa file). Trả tên file đã xóa."""
    so_ngay = SystemConfig.get_int("backup_retention_days", 30)
    han = (now or timezone.now()) - timedelta(days=so_ngay)
    da_xoa = []
    for p in thu_muc_backup().glob(MAU_FILE):
        if p.stat().st_mtime < han.timestamp():
            p.unlink()
            da_xoa.append(p.name)
    return da_xoa
