"""E2E (plan mục 13): một học kỳ đi hết vòng **đăng ký → điểm danh → điểm → học phí** qua API thật,
mỗi vai trò chỉ gọi đúng endpoint của mình. Dữ liệu nền dựng bằng factory; hành động bằng API."""

import uuid
from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from apps.auth.models import Role
from apps.notifications.models import Notification
from apps.training import services as training
from apps.training.models import TrangThaiLop
from apps.tuition.models import HocPhanGia, TuitionConfig
from core.factories import (
    ClassSectionFactory,
    CourseFactory,
    CurriculumFactory,
    ScheduleFactory,
    SemesterFactory,
    StudentProfileFactory,
    UserFactory,
)

pytestmark = pytest.mark.django_db


def khoa_idem(key=None):
    return {"HTTP_IDEMPOTENCY_KEY": str(key or uuid.uuid4())}


def test_dang_ky_diem_danh_diem_hoc_phi(login_as):
    hom_nay = timezone.localdate()
    now = timezone.now()
    hk = SemesterFactory(
        ngay_bat_dau=hom_nay - timedelta(days=40),
        ngay_ket_thuc=hom_nay + timedelta(days=20),
        cua_so_dk_bat_dau=now - timedelta(days=1),
        cua_so_dk_ket_thuc=now + timedelta(days=7),
        trang_thai="MO",
    )
    TuitionConfig.objects.create(hoc_ky=hk, han_dong=hom_nay + timedelta(days=30))
    HocPhanGia.objects.create(pham_vi="MAC_DINH", don_gia=Decimal("100000"))
    mon = CourseFactory(tong_tin_chi=3, tin_chi_ly_thuyet=3, tin_chi_thuc_hanh=0)
    lop = ClassSectionFactory(
        hoc_ky=hk,
        mon_hoc=mon,
        trang_thai=TrangThaiLop.MO,
        si_so_toi_da=30,
        ngay_bat_dau=hom_nay - timedelta(days=30),
        ngay_ket_thuc=hom_nay - timedelta(days=1),
    )
    ScheduleFactory(lop_hoc_phan=lop, thu=hom_nay.isoweekday() + 1, phong="B201")
    ctdt = CurriculumFactory()
    sv = StudentProfileFactory(nganh=ctdt.nganh, ctdt=ctdt)

    sv_api, gv_api = login_as(sv.user), login_as(lop.giao_vien.user)
    pdt_api = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    kt_api = login_as(UserFactory(role=Role.KE_TOAN))

    # 1. SV đăng ký (BR-01..07) → học phí tự tính, có thông báo xác nhận
    res = sv_api.post("/api/registrations/", {"lop_hoc_phan": lop.id}, **khoa_idem())
    assert res.status_code == 201 and res.data["trang_thai"] == "DA_DANG_KY"
    assert Notification.objects.filter(target_refs=[sv.user.id]).exists()
    hoc_phi = kt_api.get("/api/tuition/", {"hoc_ky": hk.id}).data["results"][0]
    assert (hoc_phi["ma_sv"], hoc_phi["phai_nop"], hoc_phi["hien_thi"]) == (
        sv.ma_sv,
        "300000.00",
        "CON_NO",
    )

    # 2. Hệ thống: lớp tới ngày học → DANG_HOC; buổi điểm danh sinh theo lịch (BR-20)
    assert training.chuyen_trang_thai_lop_hang_ngay(hom_nay) == (1, 0)
    training.dong_bo_buoi_diem_danh(lop)
    buoi = gv_api.get("/api/attendance/sessions/", {"lop_hoc_phan": lop.id}).data
    assert buoi["tong_so_buoi"] >= 4
    dau = buoi["results"][-1]  # buổi gần nhất (còn trong hạn sửa điểm danh, BR-20e)

    # 3. GV điểm danh cả lớp; SV thấy bản ghi của mình
    ds = gv_api.get(f"/api/attendance/sessions/{dau['id']}/records/").data
    assert [r["ma_sv"] for r in ds["records"]] == [sv.ma_sv]
    res = gv_api.put(
        f"/api/attendance/sessions/{dau['id']}/records/",
        {"records": [{"sinh_vien": sv.user_id, "trang_thai": "VANG_KHONG_PHEP"}]},
        format="json",
    )
    assert res.status_code == 200
    mine = sv_api.get("/api/attendance/my/").data["lop_hoc_phan"][0]
    assert mine["tong_so_buoi"] == buoi["tong_so_buoi"]

    # 4. GV nhập điểm cả lớp rồi khóa → CHINH_THUC; SV chưa thấy (chỉ thấy điểm KHOA)
    res = gv_api.put(
        f"/api/class-sections/{lop.id}/grades/",
        {
            "records": [
                {
                    "sinh_vien": sv.user_id,
                    "diem_qua_trinh": 8,
                    "diem_giua_ky": 7,
                    "diem_cuoi_ky": 9,
                }
            ]
        },
        format="json",
    )
    assert res.status_code == 200
    assert (
        gv_api.post(
            f"/api/class-sections/{lop.id}/grades/lock/", {"action": "lock"}, format="json"
        ).status_code
        == 200
    )
    assert sv_api.get("/api/grades/my/").data["diem"] == []

    # 5. Hết ngày học, đủ điểm → lớp DA_DONG; PĐT duyệt → KHOA; SV thấy điểm + GPA (BR-25)
    assert training.chuyen_trang_thai_lop_hang_ngay(hom_nay) == (0, 1)
    res = pdt_api.post(f"/api/class-sections/{lop.id}/grades/approve/")
    assert res.status_code == 200
    diem = sv_api.get("/api/grades/my/").data
    assert diem["diem"][0]["diem_chu"] == "B" and diem["tin_chi_tich_luy"] == 3
    assert Decimal(diem["gpa"]) == Decimal("3.24")  # tổng kết 8.10 × 0.4 (hệ 4 tuyến tính, BR-11)

    # 6. KT thu đủ học phí (replay cùng Idempotency-Key không thu thêm) → hết nợ
    key = uuid.uuid4()
    body = {"tuition": hoc_phi["id"], "loai": "THU", "so_tien": "300000", "phuong_thuc": "TIEN_MAT"}
    lan1 = kt_api.post("/api/tuition/payments/", body, **khoa_idem(key))
    lan2 = kt_api.post("/api/tuition/payments/", body, **khoa_idem(key))
    assert lan1.status_code == 201 and lan2.data["id"] == lan1.data["id"]
    mine = sv_api.get("/api/tuition/my/").data
    assert (mine["thuc_thu"], mine["con_no"], mine["hien_thi"]) == (
        "300000.00",
        "0.00",
        "DA_DONG",
    )
    assert kt_api.get("/api/tuition/debts/", {"hoc_ky": hk.id}).data["count"] == 0
    bao_cao = kt_api.get("/api/reports/finance/", {"hoc_ky": hk.id}).data["tong"]
    assert (bao_cao["phai_thu"], bao_cao["da_thu"], bao_cao["con_no"]) == (
        "300000.00",
        "300000.00",
        "0.00",
    )

    # 7. PĐT thấy lớp trong báo cáo đào tạo
    tong = pdt_api.get("/api/reports/training/", {"hoc_ky": hk.id}).data["tong"]
    assert (tong["so_sinh_vien"], tong["so_lop"], tong["tong_luot_dang_ky"]) == (1, 1, 1)
