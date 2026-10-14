"""4 job nền — lịch ở config/celery.py (plan.md mục 7.8). đã làm: classes_transition_daily, tuition_overdue_notify, flush_expired_tokens; còn lại stub."""

from django.core.management import call_command

from config.celery import app


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
    # TODO(Pha 10): ADM-08 pg_dump → BACKUP_DIR, xóa file quá backup_retention_days
    pass


@app.task(name="jobs.flush_expired_tokens")
def flush_expired_tokens():
    """Dọn bảng token_blacklist (SimpleJWT) — không có thì bảng phình mãi."""
    call_command("flushexpiredtokens")
