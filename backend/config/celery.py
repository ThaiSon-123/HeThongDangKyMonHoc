"""Celery app + 4 job nền (plan.md mục 7.8).

Job stub ở Pha 0: đăng ký task + beat schedule để cài đặt lịch không cần deploy lại.
Nội dung job ghi ở Pha 2/6/10.
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
    "tuition_overdue_notify": {
        "task": "jobs.tuition_overdue_notify",
        "schedule": crontab(hour=7, minute=0),
    },
    "backup_daily": {
        "task": "jobs.backup_daily",
        "schedule": crontab(hour=2, minute=0),
    },
    "flush_expired_tokens": {
        "task": "jobs.flush_expired_tokens",
        "schedule": crontab(hour=3, minute=0),
    },
}

# `jobs` không phải Django app nên autodiscover không thấy — import tường minh
# (đặt cuối file để `app` đã tạo xong, tránh vòng lặp với jobs.tasks).
from jobs import tasks  # noqa: E402,F401
