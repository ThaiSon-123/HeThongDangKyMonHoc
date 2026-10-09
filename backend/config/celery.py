"""Celery app + 5 job nền rỗng (plan.md mục 11.8).

Job rỗng ở Pha 0: đăng ký task + beat schedule để cài đặt lịch không cần deploy lại.
Nội dung job ghi ở Pha 7-8.
"""

import os

from celery import Celery
from celery.schedules import crontab

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.dev")

app = Celery("hpsv")
app.config_from_object("django.conf:settings", namespace="CELERY")
app.autodiscover_tasks()

app.conf.beat_schedule = {
    "classes_transition_daily": {
        "task": "jobs.classes_transition_daily",
        "schedule": crontab(hour=0, minute=5),
    },
    "scan_cam_thi": {
        "task": "jobs.scan_cam_thi",
        "schedule": crontab(hour=0, minute=30),
    },
    "tuition_overdue_notify": {
        "task": "jobs.tuition_overdue_notify",
        "schedule": crontab(hour=7, minute=0),
    },
    "recalc_gpa": {
        "task": "jobs.recalc_gpa",
        "schedule": crontab(hour=1, minute=0),
    },
    "backup_daily": {
        "task": "jobs.backup_daily",
        "schedule": crontab(hour=2, minute=0),
    },
}

# `jobs` không phải Django app nên autodiscover không thấy — import tường minh
# (đặt cuối file để `app` đã tạo xong, tránh vòng lặp với jobs.tasks).
from jobs import tasks  # noqa: E402,F401
