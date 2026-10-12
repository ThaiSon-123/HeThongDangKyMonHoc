"""Gửi thông báo tự động (plan.md mục 7.6). Pha 7 bổ sung CLASS/ROLE và API đọc."""

from apps.notifications.models import Audience, Notification


def gui_cho_nguoi_dung(user, tieu_de, noi_dung):
    return Notification.objects.create(
        tieu_de=tieu_de,
        noi_dung=noi_dung,
        audience=Audience.USER,
        target_refs=[user.id],
        nguoi_gui=None,
    )
