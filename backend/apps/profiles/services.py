"""Hồ sơ cá nhân (SV-02, GV-02) và quy tắc xếp loại học lực (BR-25f)."""

from decimal import Decimal

from django.db import transaction
from rest_framework.exceptions import ValidationError

from apps.auth.models import Role
from apps.auth.services import user_payload
from apps.profiles.models import StudentProfile, TeacherProfile

# (ngưỡng GPA thang 4 tối thiểu, xếp loại) — BR-25f, từ cao xuống thấp
_XEP_LOAI = [
    (Decimal("3.60"), "Xuất sắc"),
    (Decimal("3.20"), "Giỏi"),
    (Decimal("2.50"), "Khá"),
    (Decimal("2.00"), "Trung bình"),
    (Decimal("1.00"), "Yếu"),
]

CONTACT_FIELDS = {"email", "sdt"}


def xep_loai(gpa):
    """Xếp loại học lực theo GPA thang 4; chưa có GPA → None."""
    if gpa is None:
        return None
    return next((ten for nguong, ten in _XEP_LOAI if gpa >= nguong), "Kém")


def get_profile(user):
    if user.role == Role.SINH_VIEN:
        return StudentProfile.objects.select_related("nganh", "ctdt").filter(user=user).first()
    if user.role == Role.GIAO_VIEN:
        return TeacherProfile.objects.filter(user=user).first()
    return None


def profile_payload(user):
    data = user_payload(user)
    profile = get_profile(user)
    if isinstance(profile, StudentProfile):
        data.update(
            ma_sv=profile.ma_sv,
            ho_ten=profile.ho_ten,
            nganh={
                "id": profile.nganh_id,
                "ma_nganh": profile.nganh.ma_nganh,
                "ten_nganh": profile.nganh.ten_nganh,
            },
            khoa_nhap_hoc=profile.khoa_nhap_hoc,
            ctdt=(
                {
                    "id": profile.ctdt_id,
                    "ma_ctdt": profile.ctdt.ma_ctdt,
                    "tong_tin_chi_yeu_cau": profile.ctdt.tong_tin_chi_yeu_cau,
                }
                if profile.ctdt
                else None
            ),
            gpa=None if profile.gpa is None else str(profile.gpa),
            tin_chi_tich_luy=profile.tin_chi_tich_luy,
            xep_loai=xep_loai(profile.gpa),
            sdt=profile.sdt,
        )
    elif isinstance(profile, TeacherProfile):
        data.update(
            ma_gv=profile.ma_gv,
            ho_ten=profile.ho_ten,
            khoa_bo_mon=profile.khoa_bo_mon,
            hoc_vi=profile.hoc_vi,
            sdt=profile.sdt,
        )
    return data


@transaction.atomic
def update_contact(user, data):
    """Chỉ cho sửa email, sdt. Email ghi cả vào User (dùng cho quên mật khẩu) lẫn hồ sơ."""
    profile = get_profile(user)
    if "sdt" in data and profile is None:
        raise ValidationError({"sdt": ["Vai trò này không có số điện thoại."]})
    if "email" in data:
        user.email = data["email"]
        user.save(update_fields=["email"])
    if profile is not None:
        for field in CONTACT_FIELDS & set(data):
            setattr(profile, field, data[field])
        profile.save()
    return profile_payload(user)


def sync_user_email(profile):
    """PĐT sửa email trên hồ sơ → đồng bộ sang tài khoản đăng nhập."""
    if profile.email and profile.user.email != profile.email:
        profile.user.email = profile.email
        profile.user.save(update_fields=["email"])
