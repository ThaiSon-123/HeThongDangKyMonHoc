"""factory-boy dùng chung cho test (không import ở code chạy thật)."""

from datetime import UTC, date, datetime

import factory

from apps.auth.models import Role, User
from apps.profiles.models import StudentProfile, TeacherProfile
from apps.training.models import (
    ClassSection,
    Course,
    Curriculum,
    Faculty,
    Major,
    Schedule,
    Semester,
)

MAT_KHAU = "Matkhau123"


class UserFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = User
        skip_postgeneration_save = True

    username = factory.Sequence(lambda n: f"user{n}")
    email = factory.LazyAttribute(lambda o: f"{o.username}@example.com")
    first_name = factory.Sequence(lambda n: f"Người dùng {n}")
    role = Role.SINH_VIEN

    @factory.post_generation
    def password(self, create, extracted, **kwargs):
        self.set_password(extracted or MAT_KHAU)
        if create:
            self.save(update_fields=["password"])


class FacultyFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Faculty

    ma_khoa = factory.Sequence(lambda n: f"KH{n}")
    ten_khoa = factory.Sequence(lambda n: f"Khoa {n}")


class MajorFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Major

    khoa = factory.SubFactory(FacultyFactory)

    ma_nganh = factory.Sequence(lambda n: f"NG{n}")
    ten_nganh = factory.Sequence(lambda n: f"Ngành {n}")


class CurriculumFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Curriculum

    ma_ctdt = factory.Sequence(lambda n: f"CT{n}")
    nganh = factory.SubFactory(MajorFactory)
    khoa_tuyen_sinh = "K22"
    tong_tin_chi_yeu_cau = 140


class StudentProfileFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = StudentProfile

    user = factory.SubFactory(UserFactory, role=Role.SINH_VIEN)
    ma_sv = factory.Sequence(lambda n: f"SV{n:05d}")
    ho_ten = factory.Sequence(lambda n: f"Sinh viên {n}")
    nganh = factory.SubFactory(MajorFactory)
    khoa_nhap_hoc = "K22"
    email = factory.LazyAttribute(lambda o: o.user.email)


class TeacherProfileFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = TeacherProfile

    user = factory.SubFactory(UserFactory, role=Role.GIAO_VIEN)
    ma_gv = factory.Sequence(lambda n: f"GV{n:05d}")
    ho_ten = factory.Sequence(lambda n: f"Giảng viên {n}")
    khoa = factory.SubFactory(FacultyFactory)
    email = factory.LazyAttribute(lambda o: o.user.email)


class CourseFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Course

    ma_mon = factory.Sequence(lambda n: f"MH{n:03d}")
    ten_mon = factory.Sequence(lambda n: f"Môn {n}")
    tong_tin_chi = 3
    tin_chi_ly_thuyet = 3
    tin_chi_thuc_hanh = 0
    khoa = factory.SubFactory(FacultyFactory)


class SemesterFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Semester

    ten_hk = factory.Sequence(lambda n: f"HK{n}")
    nam_hoc = "2025-2026"
    ngay_bat_dau = date(2026, 2, 1)
    ngay_ket_thuc = date(2026, 6, 30)
    cua_so_dk_bat_dau = datetime(2026, 2, 1, 1, 0, tzinfo=UTC)
    cua_so_dk_ket_thuc = datetime(2026, 2, 14, 1, 0, tzinfo=UTC)


class ClassSectionFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = ClassSection

    ma_lop = factory.Sequence(lambda n: f"LOP{n:03d}")
    mon_hoc = factory.SubFactory(CourseFactory)
    hoc_ky = factory.SubFactory(SemesterFactory)
    giao_vien = factory.SubFactory(TeacherProfileFactory)
    si_so_toi_da = 60


class ScheduleFactory(factory.django.DjangoModelFactory):
    class Meta:
        model = Schedule

    lop_hoc_phan = factory.SubFactory(ClassSectionFactory)
    thu = 2
    tiet_bat_dau = 1
    so_tiet_moi_buoi = 3
    phong = "A101"
