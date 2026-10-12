"""Serializer dữ liệu đào tạo. Trạng thái học kỳ/lớp chỉ đổi qua action (mục 6), không PATCH trực tiếp."""

from datetime import date

from django.utils import timezone
from rest_framework import serializers

from apps.config.models import SystemConfig
from apps.training import services
from apps.training.models import (
    ClassSection,
    Course,
    Curriculum,
    CurriculumCourse,
    Faculty,
    Major,
    Prerequisite,
    Schedule,
    Semester,
    TrangThaiDung,
    TrangThaiMon,
)


def _gia_tri(serializer, attrs, ten):
    """Giá trị `ten` sau khi áp `attrs` lên bản ghi đang sửa (PATCH một phần vẫn kiểm tra đủ)."""
    if ten in attrs:
        return attrs[ten]
    if serializer.instance:
        return getattr(serializer.instance, ten, None)
    return serializer.Meta.model._meta.get_field(ten).get_default() or None


def _khoa_hoat_dong(serializer, khoa):
    """Chỉ chặn khi gán khoa/viện đã ngừng cho bản ghi mới / đổi khoa (không chặn dữ liệu cũ)."""
    if khoa.trang_thai != TrangThaiDung.HOAT_DONG and not (
        serializer.instance and serializer.instance.khoa_id == khoa.id
    ):
        raise serializers.ValidationError("Khoa/viện đã ngừng hoạt động.")
    return khoa


def _dem(obj, ten_annotate, related, **loc):
    """Số bản ghi liên quan: dùng giá trị annotate của list view, ngược lại đếm trực tiếp."""
    if hasattr(obj, ten_annotate):
        return getattr(obj, ten_annotate)
    return getattr(obj, related).filter(**loc).count()


class FacultySerializer(serializers.ModelSerializer):
    # Chỉ đếm bản ghi đang hoạt động — chính là điều kiện cho phép ngừng khoa/viện.
    so_nganh = serializers.SerializerMethodField()
    so_giao_vien = serializers.SerializerMethodField()
    so_mon = serializers.SerializerMethodField()

    class Meta:
        model = Faculty
        fields = ["id", "ma_khoa", "ten_khoa", "trang_thai", "so_nganh", "so_giao_vien", "so_mon"]

    def get_so_nganh(self, obj) -> int:
        return _dem(obj, "so_nganh", "nganh", trang_thai=TrangThaiDung.HOAT_DONG)

    def get_so_giao_vien(self, obj) -> int:
        return _dem(obj, "so_giao_vien", "giao_vien", user__is_locked=False)

    def get_so_mon(self, obj) -> int:
        return _dem(obj, "so_mon", "mon_hoc", trang_thai=TrangThaiMon.HOAT_DONG)

    def validate_trang_thai(self, value):
        if (
            self.instance
            and value == TrangThaiDung.NGUNG
            and self.instance.trang_thai != TrangThaiDung.NGUNG
        ):
            services.kiem_tra_ngung_khoa(self.instance)
        return value


class MajorSerializer(serializers.ModelSerializer):
    khoa_ten = serializers.CharField(source="khoa.ten_khoa", read_only=True)
    so_ctdt = serializers.SerializerMethodField()

    def get_so_ctdt(self, obj) -> int:
        return _dem(obj, "so_ctdt", "ctdts", trang_thai=TrangThaiDung.HOAT_DONG)

    class Meta:
        model = Major
        fields = [
            "id",
            "ma_nganh",
            "ten_nganh",
            "thoi_gian_dao_tao",
            "khoa",
            "khoa_ten",
            "so_ctdt",
            "trang_thai",
        ]

    def validate_khoa(self, khoa):
        return _khoa_hoat_dong(self, khoa)


class CurriculumSerializer(serializers.ModelSerializer):
    nganh_ten = serializers.CharField(source="nganh.ten_nganh", read_only=True)

    class Meta:
        model = Curriculum
        fields = [
            "id",
            "ma_ctdt",
            "nganh",
            "nganh_ten",
            "khoa_tuyen_sinh",
            "tong_tin_chi_yeu_cau",
            "trang_thai",
        ]

    def validate(self, attrs):
        # DRF không tự kiểm unique có điều kiện khi PATCH một phần → tự kiểm, báo lỗi field.
        if _gia_tri(self, attrs, "trang_thai") == TrangThaiDung.HOAT_DONG:
            trung = Curriculum.objects.filter(
                nganh=_gia_tri(self, attrs, "nganh"),
                khoa_tuyen_sinh=_gia_tri(self, attrs, "khoa_tuyen_sinh"),
                trang_thai=TrangThaiDung.HOAT_DONG,
            )
            if self.instance:
                trung = trung.exclude(pk=self.instance.pk)
            if trung.exists():
                raise serializers.ValidationError(
                    {
                        "khoa_tuyen_sinh": [
                            "Ngành này đã có CTĐT đang hoạt động cho khóa tuyển sinh."
                        ]
                    }
                )
        return attrs


class CourseSerializer(serializers.ModelSerializer):
    """`tong_tin_chi` = LT + TH, server tự tính."""

    khoa_ten = serializers.CharField(source="khoa.ten_khoa", read_only=True)

    class Meta:
        model = Course
        fields = [
            "id",
            "ma_mon",
            "ten_mon",
            "tong_tin_chi",
            "tin_chi_ly_thuyet",
            "tin_chi_thuc_hanh",
            "so_tiet_ly_thuyet",
            "so_tiet_thuc_hanh",
            "loai_danh_gia",
            "khoa",
            "khoa_ten",
            "trang_thai",
        ]
        read_only_fields = ["tong_tin_chi"]

    def validate_khoa(self, khoa):
        return _khoa_hoat_dong(self, khoa)

    def validate(self, attrs):
        tong = _gia_tri(self, attrs, "tin_chi_ly_thuyet") or 0
        tong += _gia_tri(self, attrs, "tin_chi_thuc_hanh") or 0
        if tong < 1:
            raise serializers.ValidationError(
                {"tin_chi_ly_thuyet": ["Môn phải có ít nhất 1 tín chỉ."]}
            )
        attrs["tong_tin_chi"] = tong
        return attrs


class CurriculumCourseSerializer(serializers.ModelSerializer):
    ma_mon = serializers.CharField(source="mon_hoc.ma_mon", read_only=True)
    ten_mon = serializers.CharField(source="mon_hoc.ten_mon", read_only=True)
    tong_tin_chi = serializers.IntegerField(source="mon_hoc.tong_tin_chi", read_only=True)

    class Meta:
        model = CurriculumCourse
        fields = [
            "id",
            "ctdt",
            "mon_hoc",
            "ma_mon",
            "ten_mon",
            "tong_tin_chi",
            "khoi_kien_thuc",
            "loai_mon",
            "hoc_ky_goi_y",
        ]

    def update(self, instance, validated_data):
        # CTĐT và môn chỉ đặt lúc gán; muốn đổi thì xóa rồi gán lại.
        validated_data.pop("ctdt", None)
        validated_data.pop("mon_hoc", None)
        return super().update(instance, validated_data)


class PrerequisiteSerializer(serializers.ModelSerializer):
    ma_mon = serializers.CharField(source="mon_hoc.ma_mon", read_only=True)
    ma_mon_tien_quyet = serializers.CharField(source="mon_tien_quyet.ma_mon", read_only=True)

    class Meta:
        model = Prerequisite
        fields = ["id", "mon_hoc", "ma_mon", "mon_tien_quyet", "ma_mon_tien_quyet"]

    def validate(self, attrs):
        if attrs["mon_hoc"] == attrs["mon_tien_quyet"]:
            raise serializers.ValidationError(
                {"mon_tien_quyet": ["Môn không thể tự là tiên quyết."]}
            )
        if services.tao_chu_trinh(attrs["mon_hoc"].id, attrs["mon_tien_quyet"].id):
            raise serializers.ValidationError(
                {"mon_tien_quyet": ["Tạo vòng lặp tiên quyết (chu trình)."]}
            )
        return attrs


class SemesterSerializer(serializers.ModelSerializer):
    class Meta:
        model = Semester
        fields = [
            "id",
            "ten_hk",
            "nam_hoc",
            "ngay_bat_dau",
            "ngay_ket_thuc",
            "cua_so_dk_bat_dau",
            "cua_so_dk_ket_thuc",
            "tin_chi_toi_thieu",
            "tin_chi_toi_da",
            "tin_chi_toi_da_canh_bao",
            "trang_thai",
        ]
        read_only_fields = ["trang_thai"]  # đổi qua open/close

    def validate(self, attrs):
        def g(ten):
            return _gia_tri(self, attrs, ten)

        loi = {}
        if g("ngay_bat_dau") >= g("ngay_ket_thuc"):
            loi["ngay_ket_thuc"] = ["Ngày kết thúc phải sau ngày bắt đầu."]
        mo, dong = g("cua_so_dk_bat_dau"), g("cua_so_dk_ket_thuc")
        if mo >= dong:
            loi["cua_so_dk_ket_thuc"] = ["Cửa sổ đăng ký phải kết thúc sau khi bắt đầu."]
        elif timezone.localtime(mo).date() < g("ngay_bat_dau") or timezone.localtime(
            dong
        ).date() > g("ngay_ket_thuc"):
            loi["cua_so_dk_bat_dau"] = ["Cửa sổ đăng ký phải nằm trong thời gian học kỳ."]
        if not 1 <= g("tin_chi_toi_thieu") <= g("tin_chi_toi_da"):
            loi["tin_chi_toi_thieu"] = ["Tối thiểu phải từ 1 và không vượt tối đa."]
        if g("tin_chi_toi_da_canh_bao") > g("tin_chi_toi_da"):
            loi["tin_chi_toi_da_canh_bao"] = ["Không được vượt tín chỉ tối đa."]
        if loi:
            raise serializers.ValidationError(loi)
        return attrs


class SemesterWindowSerializer(serializers.Serializer):
    """`PATCH /semesters/{id}/window/` — chỉ cửa sổ đăng ký."""

    cua_so_dk_bat_dau = serializers.DateTimeField()
    cua_so_dk_ket_thuc = serializers.DateTimeField()


class ScheduleSerializer(serializers.ModelSerializer):
    tiet_ket_thuc = serializers.IntegerField(read_only=True)
    buoi = serializers.CharField(read_only=True)

    class Meta:
        model = Schedule
        fields = [
            "id",
            "lop_hoc_phan",
            "thu",
            "tiet_bat_dau",
            "so_tiet_moi_buoi",
            "tiet_ket_thuc",
            "buoi",
            "phong",
        ]

    def validate_phong(self, value):
        return value.strip()

    def validate(self, attrs):
        lop = _gia_tri(self, attrs, "lop_hoc_phan")
        if self.instance and lop != self.instance.lop_hoc_phan:
            raise serializers.ValidationError({"lop_hoc_phan": ["Không đổi lớp của lịch học."]})
        services.kiem_tra_sua_lop(lop)
        bat_dau = _gia_tri(self, attrs, "tiet_bat_dau")
        so_tiet = _gia_tri(self, attrs, "so_tiet_moi_buoi")
        ket_thuc = bat_dau + so_tiet - 1
        if ket_thuc > services.tiet_cuoi_nhom(bat_dau):
            raise serializers.ValidationError(
                {
                    "so_tiet_moi_buoi": [
                        "Số tiết vượt quá nhóm tiết (sáng 1–5, chiều 6–10, tối 11–15)."
                    ]
                }
            )
        loi = services.xung_dot_lich(
            lop.hoc_ky_id,
            lop.giao_vien_id,
            _gia_tri(self, attrs, "thu"),
            bat_dau,
            ket_thuc,
            _gia_tri(self, attrs, "phong"),
            bo_qua=Schedule.objects.filter(pk=self.instance.pk) if self.instance else None,
        )
        if loi:
            raise serializers.ValidationError({k: [v] for k, v in loi.items()})
        return attrs


class ClassSectionSerializer(serializers.ModelSerializer):
    ma_mon = serializers.CharField(source="mon_hoc.ma_mon", read_only=True)
    ten_mon = serializers.CharField(source="mon_hoc.ten_mon", read_only=True)
    ten_hk = serializers.CharField(source="hoc_ky.ten_hk", read_only=True)
    giao_vien_ten = serializers.CharField(source="giao_vien.ho_ten", read_only=True)
    lich_hoc = ScheduleSerializer(many=True, read_only=True)
    han_nhap_diem_hieu_luc = serializers.SerializerMethodField()

    def get_han_nhap_diem_hieu_luc(self, obj) -> date:
        # Đọc cấu hình một lần cho cả trang kết quả.
        so_ngay = self.root.context.setdefault(
            "so_ngay_nhap_diem", SystemConfig.get_int("so_ngay_cho_phep_nhap_diem", 14)
        )
        return services.han_nhap_diem_hieu_luc(obj, so_ngay)

    class Meta:
        model = ClassSection
        fields = [
            "id",
            "ma_lop",
            "mon_hoc",
            "ma_mon",
            "ten_mon",
            "hoc_ky",
            "ten_hk",
            "giao_vien",
            "giao_vien_ten",
            "si_so_toi_da",
            "si_so_hien_tai",
            "ngay_bat_dau",
            "ngay_ket_thuc",
            "han_nhap_diem",
            "han_nhap_diem_hieu_luc",
            "trang_thai",
            "lich_hoc",
        ]
        # Trạng thái đổi qua open/close/job; sĩ số hiện tại do đăng ký (Pha 3); hạn điểm qua grade-deadline.
        read_only_fields = ["si_so_hien_tai", "han_nhap_diem", "trang_thai"]

    def validate_mon_hoc(self, mon):
        if mon.trang_thai == TrangThaiMon.NGUNG_SU_DUNG and not (
            self.instance and self.instance.mon_hoc_id == mon.id
        ):
            raise serializers.ValidationError("Môn học đã ngừng sử dụng, không mở lớp được.")
        return mon

    def validate(self, attrs):
        inst = self.instance
        loi = {}
        if inst:
            services.kiem_tra_sua_lop(inst)
            # Đã có đăng ký thì không đổi môn / học kỳ của lớp.
            for ten in ("mon_hoc", "hoc_ky"):
                if ten in attrs and attrs[ten] != getattr(inst, ten) and inst.dang_ky.exists():
                    loi[ten] = ["Lớp đã có đăng ký, không đổi được."]
            if "si_so_toi_da" in attrs and attrs["si_so_toi_da"] < inst.si_so_hien_tai:
                loi["si_so_toi_da"] = ["Sĩ số tối đa không được nhỏ hơn sĩ số hiện tại."]
        hoc_ky = _gia_tri(self, attrs, "hoc_ky")
        bat_dau, ket_thuc = _gia_tri(self, attrs, "ngay_bat_dau"), _gia_tri(
            self, attrs, "ngay_ket_thuc"
        )
        if bat_dau and ket_thuc and bat_dau > ket_thuc:
            loi["ngay_ket_thuc"] = ["Ngày kết thúc phải từ ngày bắt đầu trở đi."]
        for ten, ngay in (("ngay_bat_dau", bat_dau), ("ngay_ket_thuc", ket_thuc)):
            if ngay and not hoc_ky.ngay_bat_dau <= ngay <= hoc_ky.ngay_ket_thuc:
                loi[ten] = ["Phải nằm trong thời gian học kỳ."]
        if inst and "giao_vien" in attrs and attrs["giao_vien"] != inst.giao_vien:
            for lich in inst.lich_hoc.all():
                xung_dot = services.xung_dot_lich(
                    inst.hoc_ky_id,
                    attrs["giao_vien"].id,
                    lich.thu,
                    lich.tiet_bat_dau,
                    lich.tiet_ket_thuc,
                    "",
                    bo_qua=inst.lich_hoc.all(),
                )
                if xung_dot:
                    loi["giao_vien"] = [xung_dot["giao_vien"]]
                    break
        if loi:
            raise serializers.ValidationError(loi)
        return attrs


class GradeDeadlineSerializer(serializers.Serializer):
    han_nhap_diem = serializers.DateField()

    def validate_han_nhap_diem(self, value):
        # Gia hạn = dời hạn ra xa hơn hạn đang đặt (nếu có).
        hien_tai = self.context["lop"].han_nhap_diem
        if hien_tai and value <= hien_tai:
            raise serializers.ValidationError("Hạn mới phải sau hạn hiện tại.")
        return value
