"""factory-boy dùng chung cho test (không import ở code chạy thật)."""

import factory

from apps.auth.models import Role, User
from apps.profiles.models import StudentProfile, TeacherProfile
from apps.training.models import Curriculum, Faculty, Major

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
