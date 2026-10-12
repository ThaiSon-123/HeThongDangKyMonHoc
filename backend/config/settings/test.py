"""Môi trường test. Mặc định SQLite in-memory cho nhanh; `TEST_DB=postgres` dùng PostgreSQL thật
(biến DB_* như dev) — bắt buộc cho test khóa dòng/đồng thời (plan.md mục 13)."""

import os

from .dev import *  # noqa: F401,F403

if os.environ.get("TEST_DB") != "postgres":
    DATABASES = {"default": {"ENGINE": "django.db.backends.sqlite3", "NAME": ":memory:"}}

CACHES = {"default": {"BACKEND": "django.core.cache.backends.locmem.LocMemCache"}}
PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]  # test nhanh
EMAIL_BACKEND = "django.core.mail.backends.locmem.EmailBackend"
PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = False  # test nào cần thì bật riêng
