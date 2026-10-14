"""4 job nền — lịch ở config/celery.py (plan.md mục 7.8). cả 4 job đã làm."""

import logging

from django.core.management import call_command

from config.celery import app

logger = logging.getLogger(__name__)


@app.task(name="jobs.classes_transition_daily")
def classes_transition_daily():
    """Mục 6/7.8: `MO` qua ngày bắt đầu → `DANG_HOC`; `DANG_HOC` đủ điều kiện → `DA_DONG`."""
    from apps.training.services import chuyen_trang_thai_lop_hang_ngay

    return chuyen_trang_thai_lop_hang_ngay()


@app.task(name="jobs.tuition_overdue_notify")
def tuition_overdue_notify():
    """Mục 7.8: học phí còn nợ quá hạn → thông báo SV (một lần) + tổng hợp cho Kế toán."""
    from apps.tuition.services import thong_bao_qua_han

    return thong_bao_qua_han()


@app.task(name="jobs.backup_daily")
def backup_daily():
    """Mục 7.8 / ADM-08: `pg_dump` → `BACKUP_DIR`, rồi xóa file quá `backup_retention_days`.
    Cũng được `POST /api/admin/backups/` gọi (chạy nền). Lỗi → log + task FAILURE, không nuốt."""
    from apps.config import services

    try:
        ten = services.tao_backup()
    except services.BackupError:
        logger.exception("Sao lưu thất bại")
        raise
    return {"file": ten, "da_xoa": services.don_backup_cu()}


@app.task(name="jobs.flush_expired_tokens")
def flush_expired_tokens():
    """Dọn bảng token_blacklist (SimpleJWT) — không có thì bảng phình mãi."""
    call_command("flushexpiredtokens")
