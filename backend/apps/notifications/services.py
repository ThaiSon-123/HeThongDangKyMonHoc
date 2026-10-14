"""Thông báo (plan.md mục 7.6, ADM-07): gửi tự động, tập người nhận, đã đọc, thu hồi."""

from datetime import timedelta

from django.utils import timezone

from apps.auth.models import Role
from apps.notifications.models import (
    Audience,
    Notification,
    NotificationRead,
    TrangThaiThongBao,
)

# ponytail: tập người nhận suy ra từ `audience × target_refs` (JSON) nên lọc ở Python trên các thông báo
# gần đây; đủ cho quy mô trường (vài nghìn thông báo/kỳ). Cần hơn thì tách bảng người nhận.
CUA_SO_NGAY = 180


def gui_cho_nguoi_dung(user, tieu_de, noi_dung):
    return Notification.objects.create(
        tieu_de=tieu_de,
        noi_dung=noi_dung,
        audience=Audience.USER,
        target_refs=[user.id],
        nguoi_gui=None,
    )


def gui_cho_lop(lop, tieu_de, noi_dung, nguoi_gui=None):
    """Báo cho mọi SV đang đăng ký và GV phụ trách lớp (vd lớp đổi lịch / phòng)."""
    return Notification.objects.create(
        tieu_de=tieu_de,
        noi_dung=noi_dung,
        audience=Audience.CLASS,
        target_refs=[lop.id],
        nguoi_gui=nguoi_gui,
    )


def lop_cua_toi(user):
    """Các lớp mà `user` thuộc về: SV = đang đăng ký; GV = phụ trách."""
    from apps.registration.models import Registration, TrangThaiDangKy
    from apps.training.models import ClassSection

    if user.role == Role.SINH_VIEN:
        return set(
            Registration.objects.filter(
                sinh_vien=user, trang_thai=TrangThaiDangKy.DA_DANG_KY
            ).values_list("lop_hoc_phan_id", flat=True)
        )
    if user.role == Role.GIAO_VIEN:
        return set(ClassSection.objects.filter(giao_vien__user=user).values_list("id", flat=True))
    return set()


def nguoi_nhan_thay(n, user, lop_ids):
    refs = n.target_refs or []
    if n.audience == Audience.USER:
        return user.id in refs
    if n.audience == Audience.ROLE:
        return user.role in refs
    return any(r in lop_ids for r in refs)


def hop_thu(user):
    """Thông báo `DA_GUI` mà `user` nhận được, mới nhất trước, kèm `da_doc`."""
    tu = timezone.now() - timedelta(days=CUA_SO_NGAY)
    lop_ids = lop_cua_toi(user)
    ds = [
        n
        for n in Notification.objects.filter(trang_thai=TrangThaiThongBao.DA_GUI, ngay_gui__gte=tu)
        .select_related("nguoi_gui")
        .order_by("-ngay_gui", "-id")
        if nguoi_nhan_thay(n, user, lop_ids)
    ]
    da_doc = set(
        NotificationRead.objects.filter(user=user, notification__in=ds).values_list(
            "notification_id", flat=True
        )
    )
    for n in ds:
        n.da_doc = n.id in da_doc
    return ds


def danh_dau_da_doc(user, notification):
    NotificationRead.objects.get_or_create(user=user, notification=notification)


def danh_dau_tat_ca(user):
    chua = [n for n in hop_thu(user) if not n.da_doc]
    NotificationRead.objects.bulk_create(
        [NotificationRead(user=user, notification=n) for n in chua], ignore_conflicts=True
    )
    return len(chua)


def so_chua_doc(user):
    return sum(1 for n in hop_thu(user) if not n.da_doc)
