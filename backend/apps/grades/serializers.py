from rest_framework import serializers

from apps.grades.models import TrangThaiDiem

_DIEM = {"max_digits": 4, "decimal_places": 2, "min_value": 0, "max_value": 10}


class GradeInSerializer(serializers.Serializer):
    sinh_vien = serializers.IntegerField()
    diem_qua_trinh = serializers.DecimalField(
        required=False, allow_null=True, default=None, **_DIEM
    )
    diem_giua_ky = serializers.DecimalField(required=False, allow_null=True, default=None, **_DIEM)
    diem_cuoi_ky = serializers.DecimalField(required=False, allow_null=True, default=None, **_DIEM)


class GradesPutSerializer(serializers.Serializer):
    records = GradeInSerializer(many=True, allow_empty=False)


class GradeRowSerializer(serializers.Serializer):
    sinh_vien = serializers.IntegerField()
    ma_sv = serializers.CharField()
    ho_ten = serializers.CharField()
    diem_qua_trinh = serializers.DecimalField(allow_null=True, **_DIEM)
    diem_giua_ky = serializers.DecimalField(allow_null=True, **_DIEM)
    diem_cuoi_ky = serializers.DecimalField(allow_null=True, **_DIEM)
    diem_tong_ket = serializers.DecimalField(allow_null=True, **_DIEM)
    diem_chu = serializers.CharField(allow_blank=True)
    gpa_thang_4 = serializers.DecimalField(max_digits=3, decimal_places=2, allow_null=True)
    trang_thai = serializers.ChoiceField(choices=TrangThaiDiem.choices, allow_null=True)


class GradeSheetSerializer(serializers.Serializer):
    lop_hoc_phan = serializers.IntegerField()
    ma_lop = serializers.CharField()
    ten_mon = serializers.CharField()
    loai_danh_gia = serializers.CharField()
    lop_trang_thai = serializers.CharField()
    han_nhap_diem = serializers.DateField()
    qua_han = serializers.BooleanField()
    co_the_nhap = serializers.BooleanField()
    co_the_khoa = serializers.BooleanField()
    co_the_mo_khoa = serializers.BooleanField()
    co_the_duyet = serializers.BooleanField()
    records = GradeRowSerializer(many=True)


class LockSerializer(serializers.Serializer):
    action = serializers.ChoiceField(choices=["lock", "unlock"])


class ApproveResultSerializer(serializers.Serializer):
    so_sinh_vien = serializers.IntegerField()


class MyGradeRowSerializer(serializers.Serializer):
    hoc_ky = serializers.IntegerField()
    ten_hk = serializers.CharField()
    ma_lop = serializers.CharField()
    ma_mon = serializers.CharField()
    ten_mon = serializers.CharField()
    tin_chi = serializers.IntegerField()
    diem_qua_trinh = serializers.DecimalField(allow_null=True, **_DIEM)
    diem_giua_ky = serializers.DecimalField(allow_null=True, **_DIEM)
    diem_cuoi_ky = serializers.DecimalField(allow_null=True, **_DIEM)
    diem_tong_ket = serializers.DecimalField(allow_null=True, **_DIEM)
    diem_chu = serializers.CharField()
    gpa_thang_4 = serializers.DecimalField(max_digits=3, decimal_places=2, allow_null=True)


class MyGradeStatSerializer(serializers.Serializer):
    hoc_ky = serializers.IntegerField()
    ten_hk = serializers.CharField()
    so_mon = serializers.IntegerField()
    tin_chi_hoc = serializers.IntegerField()
    tin_chi_dat = serializers.IntegerField()
    diem_tb = serializers.DecimalField(max_digits=4, decimal_places=2, allow_null=True)
    gpa = serializers.DecimalField(max_digits=3, decimal_places=2, allow_null=True)
    xep_loai = serializers.CharField(allow_null=True)


class MyGradesSerializer(serializers.Serializer):
    gpa = serializers.DecimalField(max_digits=3, decimal_places=2, allow_null=True)
    tin_chi_tich_luy = serializers.IntegerField()
    xep_loai = serializers.CharField(allow_null=True)
    thong_ke = MyGradeStatSerializer(many=True)
    diem = MyGradeRowSerializer(many=True)


class GradeSheetListRowSerializer(serializers.Serializer):
    id = serializers.IntegerField()
    ma_lop = serializers.CharField()
    ten_mon = serializers.CharField()
    ten_hk = serializers.CharField()
    giao_vien_ten = serializers.CharField()
    trang_thai = serializers.CharField()
    so_sv = serializers.IntegerField()
    nhap_tam = serializers.IntegerField()
    chinh_thuc = serializers.IntegerField()
    khoa = serializers.IntegerField()
