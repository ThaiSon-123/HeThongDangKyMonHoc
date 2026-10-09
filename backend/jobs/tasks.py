"""5 job nền — lịch ở config/celery.py (plan.md mục 11.8). Pha 0: stub, nội dung ghi ở Pha 7-8."""

from config.celery import app


@app.task(name="jobs.classes_transition_daily")
def classes_transition_daily():
    # TODO(Pha 8): mục 10 — MO→DANG_HOC→DA_DONG
    pass


@app.task(name="jobs.scan_cam_thi")
def scan_cam_thi():
    # TODO(Pha 5): BR-24
    pass


@app.task(name="jobs.tuition_overdue_notify")
def tuition_overdue_notify():
    # TODO(Pha 7): mục 11.6
    pass


@app.task(name="jobs.recalc_gpa")
def recalc_gpa():
    # TODO(Pha 6): BR-25
    pass


@app.task(name="jobs.backup_daily")
def backup_daily():
    # TODO(Pha 12): ADM-08 pg_dump → BACKUP_DIR
    pass
