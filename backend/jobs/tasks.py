"""4 job nền — lịch ở config/celery.py (plan.md mục 7.8). Pha 0: stub, trừ flush_expired_tokens."""

from django.core.management import call_command

from config.celery import app


@app.task(name="jobs.classes_transition_daily")
def classes_transition_daily():
    # TODO(Pha 2): mục 6 — MO→DANG_HOC→DA_DONG
    pass


@app.task(name="jobs.tuition_overdue_notify")
def tuition_overdue_notify():
    # TODO(Pha 6): mục 7.6
    pass


@app.task(name="jobs.backup_daily")
def backup_daily():
    # TODO(Pha 10): ADM-08 pg_dump → BACKUP_DIR, xóa file quá backup_retention_days
    pass


@app.task(name="jobs.flush_expired_tokens")
def flush_expired_tokens():
    """Dọn bảng token_blacklist (SimpleJWT) — không có thì bảng phình mãi."""
    call_command("flushexpiredtokens")
