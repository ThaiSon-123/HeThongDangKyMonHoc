"""Phân quyền (BR-21/23, plan mục 9): **mỗi endpoint một dòng** trong bảng `QUYEN`.

- `test_bang_quyen_du_moi_endpoint`: endpoint mới thêm vào API mà chưa khai báo vai trò ở đây → fail.
- `test_vai_tro_sai_bi_chan`: mọi vai trò KHÔNG được liệt kê (và người chưa đăng nhập) bị 403/401.
- `test_vai_tro_dung_khong_bi_chan_o_tang_quyen`: với GET, vai trò được liệt kê không bị 401/403.
  (Chỉ GET vì các method ghi có thể gây tác dụng phụ khi gọi thật.)
Vai trò: A=Admin · P=Phòng đào tạo · S=Sinh viên · G=Giáo viên · K=Kế toán.
"""

import pytest
from drf_spectacular.generators import SchemaGenerator
from rest_framework.test import APIClient

from apps.auth.models import Role
from core.factories import StudentProfileFactory, TeacherProfileFactory, UserFactory

pytestmark = pytest.mark.django_db

VAI_TRO = {
    "A": Role.ADMIN,
    "P": Role.PHONG_DAO_TAO,
    "S": Role.SINH_VIEN,
    "G": Role.GIAO_VIEN,
    "K": Role.KE_TOAN,
}
TAT_CA = "APSGK"

# Không cần đăng nhập (hoặc chỉ cần token của chính mình trong body) — không thuộc ma trận quyền.
CONG_KHAI = {
    ("POST", "/api/auth/login/"),
    ("POST", "/api/auth/refresh/"),
    ("POST", "/api/auth/forgot-password/"),
    ("POST", "/api/auth/reset-password/"),
    ("GET", "/api/health/"),
    # VNPay gọi về: không có token, chỉ chữ ký HMAC làm căn cứ
    ("GET", "/api/tuition/vnpay/ipn/"),
    ("GET", "/api/tuition/vnpay/return/"),
}

QUYEN = {
    # --- chung
    ("POST", "/api/auth/change-password/"): TAT_CA,
    ("POST", "/api/auth/logout/"): TAT_CA,
    ("GET", "/api/profiles/me/"): TAT_CA,
    ("PATCH", "/api/profiles/me/"): TAT_CA,
    ("GET", "/api/notifications/"): TAT_CA,
    ("POST", "/api/notifications/"): "APGK",
    ("POST", "/api/notifications/read-all/"): TAT_CA,
    ("GET", "/api/notifications/recipients/"): "APK",
    ("DELETE", "/api/notifications/{id}/"): "APGK",
    ("PATCH", "/api/notifications/{id}/read/"): TAT_CA,
    # --- Admin
    ("GET", "/api/users/"): "A",
    ("POST", "/api/users/"): "A",
    ("GET", "/api/users/{id}/"): "A",
    ("PATCH", "/api/users/{id}/"): "A",
    ("PATCH", "/api/users/{id}/lock/"): "A",
    ("POST", "/api/users/{id}/reset-password/"): "A",
    ("GET", "/api/admin/permissions/"): "A",
    ("GET", "/api/admin/config/"): "A",
    ("PATCH", "/api/admin/config/"): "A",
    ("GET", "/api/admin/backups/"): "A",
    ("POST", "/api/admin/backups/"): "A",
    ("GET", "/api/admin/audit-logs/"): "APK",
    # --- hồ sơ
    ("GET", "/api/profiles/pending-accounts/"): "AP",
    ("GET", "/api/profiles/students/"): "AP",
    ("POST", "/api/profiles/students/"): "P",
    ("GET", "/api/profiles/students/{id}/"): "AP",
    ("PATCH", "/api/profiles/students/{id}/"): "P",
    ("GET", "/api/profiles/teachers/"): "AP",
    ("POST", "/api/profiles/teachers/"): "P",
    ("GET", "/api/profiles/teachers/{id}/"): "AP",
    ("PATCH", "/api/profiles/teachers/{id}/"): "P",
    # --- dữ liệu đào tạo (PĐT ghi; KT đọc ngành/học kỳ/lớp để chọn khi lập giá)
    ("GET", "/api/faculties/"): "P",
    ("POST", "/api/faculties/"): "P",
    ("GET", "/api/faculties/{id}/"): "P",
    ("PATCH", "/api/faculties/{id}/"): "P",
    ("GET", "/api/majors/"): "PK",
    ("POST", "/api/majors/"): "P",
    ("GET", "/api/majors/{id}/"): "PK",
    ("PATCH", "/api/majors/{id}/"): "P",
    ("GET", "/api/curriculums/"): "P",
    ("POST", "/api/curriculums/"): "P",
    ("GET", "/api/curriculums/{id}/"): "P",
    ("PATCH", "/api/curriculums/{id}/"): "P",
    ("GET", "/api/curriculums/my/"): "S",
    ("GET", "/api/curriculum-courses/"): "P",
    ("POST", "/api/curriculum-courses/"): "P",
    ("GET", "/api/curriculum-courses/{id}/"): "P",
    ("PATCH", "/api/curriculum-courses/{id}/"): "P",
    ("DELETE", "/api/curriculum-courses/{id}/"): "P",
    ("GET", "/api/courses/"): "P",
    ("POST", "/api/courses/"): "P",
    ("GET", "/api/courses/{id}/"): "P",
    ("PATCH", "/api/courses/{id}/"): "P",
    ("GET", "/api/prerequisites/"): "P",
    ("POST", "/api/prerequisites/"): "P",
    ("GET", "/api/prerequisites/{id}/"): "P",
    ("DELETE", "/api/prerequisites/{id}/"): "P",
    ("GET", "/api/semesters/"): "PK",
    ("POST", "/api/semesters/"): "P",
    ("GET", "/api/semesters/{id}/"): "PK",
    ("PATCH", "/api/semesters/{id}/"): "P",
    ("PATCH", "/api/semesters/{id}/window/"): "P",
    ("POST", "/api/semesters/{id}/open/"): "P",
    ("POST", "/api/semesters/{id}/close/"): "P",
    ("GET", "/api/class-sections/"): "PK",
    ("POST", "/api/class-sections/"): "P",
    ("GET", "/api/class-sections/{id}/"): "PKG",
    ("PATCH", "/api/class-sections/{id}/"): "P",
    ("POST", "/api/class-sections/{id}/open/"): "P",
    ("POST", "/api/class-sections/{id}/close/"): "P",
    ("POST", "/api/class-sections/{id}/grade-deadline/"): "P",
    ("GET", "/api/schedules/"): "P",
    ("POST", "/api/schedules/"): "P",
    ("GET", "/api/schedules/{id}/"): "P",
    ("PATCH", "/api/schedules/{id}/"): "P",
    ("DELETE", "/api/schedules/{id}/"): "P",
    # --- sinh viên
    ("GET", "/api/courses/available/"): "S",
    ("GET", "/api/auto-schedule/available-courses/"): "S",
    ("POST", "/api/registrations/"): "S",
    ("GET", "/api/registrations/history/"): "S",
    ("GET", "/api/timetable/my/"): "SG",
    ("GET", "/api/attendance/my/"): "S",
    ("GET", "/api/grades/my/"): "S",
    ("GET", "/api/tuition/my/"): "S",
    ("PATCH", "/api/tuition/my/plan/"): "S",
    ("POST", "/api/tuition/my/pay/"): "S",
    ("GET", "/api/tuition/my/pay/{txn_ref}/"): "S",
    # --- PĐT theo dõi / hủy hộ
    ("GET", "/api/registrations/"): "P",
    ("GET", "/api/registrations/export/"): "P",
    ("DELETE", "/api/registrations/{id}/"): "SP",
    ("GET", "/api/grade-sheets/"): "P",
    ("POST", "/api/class-sections/{id}/grades/approve/"): "P",
    ("GET", "/api/reports/training/"): "P",
    ("GET", "/api/reports/training/export/"): "P",
    # --- giáo viên
    ("GET", "/api/class-sections/my/"): "G",
    ("GET", "/api/class-sections/{id}/students/"): "G",
    ("GET", "/api/class-sections/{id}/export/"): "PG",
    ("GET", "/api/class-sections/{id}/grades/"): "PG",
    ("PUT", "/api/class-sections/{id}/grades/"): "PG",
    ("POST", "/api/class-sections/{id}/grades/lock/"): "G",
    # --- điểm danh
    ("GET", "/api/attendance/sessions/"): "PG",
    ("GET", "/api/attendance/sessions/{id}/records/"): "PG",
    ("PUT", "/api/attendance/sessions/{id}/records/"): "G",
    ("GET", "/api/attendance/requests/"): "SG",
    ("POST", "/api/attendance/requests/"): "S",
    ("PATCH", "/api/attendance/requests/{id}/"): "G",
    ("GET", "/api/attendance/requests/{id}/minh-chung/"): "SG",
    # --- kế toán
    ("GET", "/api/tuition/config/"): "K",
    ("POST", "/api/tuition/config/"): "K",
    ("GET", "/api/tuition/config/{id}/"): "K",
    ("PATCH", "/api/tuition/config/{id}/"): "K",
    ("GET", "/api/tuition/pricing/"): "K",
    ("POST", "/api/tuition/pricing/"): "K",
    ("GET", "/api/tuition/pricing/{id}/"): "K",
    ("PATCH", "/api/tuition/pricing/{id}/"): "K",
    ("DELETE", "/api/tuition/pricing/{id}/"): "K",
    ("GET", "/api/tuition/discounts/"): "K",
    ("POST", "/api/tuition/discounts/"): "K",
    ("GET", "/api/tuition/discounts/{id}/"): "K",
    ("PATCH", "/api/tuition/discounts/{id}/"): "K",
    ("DELETE", "/api/tuition/discounts/{id}/"): "K",
    ("GET", "/api/tuition/"): "K",
    ("GET", "/api/tuition/{id}/"): "K",
    ("GET", "/api/tuition/debts/"): "K",
    ("GET", "/api/tuition/students/"): "K",
    ("POST", "/api/tuition/calculate/"): "K",
    ("GET", "/api/tuition/installments/"): "K",
    ("PUT", "/api/tuition/installments/"): "K",
    ("GET", "/api/tuition/payments/"): "K",
    ("POST", "/api/tuition/payments/"): "K",
    ("GET", "/api/tuition/payments/{id}/receipt/"): "K",
    ("GET", "/api/reports/finance/"): "K",
    ("GET", "/api/reports/finance/export/"): "K",
}


# Quyền theo đối tượng: vai trò không phải người gửi thì thấy 404 thay vì 403 (không lộ thông báo của người khác).
CHAN_BANG_404 = {("DELETE", "/api/notifications/{id}/")}


def cac_endpoint():
    """Mọi `(METHOD, đường dẫn)` có trong OpenAPI — nguồn sự thật về API đang chạy."""
    schema = SchemaGenerator().get_schema(request=None, public=True)
    return {
        (m.upper(), p)
        for p, item in schema["paths"].items()
        for m in item
        if m in ("get", "post", "put", "patch", "delete")
    }


def test_bang_quyen_du_moi_endpoint():
    thuc_te = cac_endpoint() - CONG_KHAI
    assert thuc_te - set(QUYEN) == set(), "Endpoint chưa khai báo vai trò trong QUYEN"
    assert set(QUYEN) - thuc_te == set(), "QUYEN còn dòng của endpoint không còn tồn tại"


def _url(path):
    return path.replace("{id}", "1")


# Middleware kiểm `Idempotency-Key` (đăng ký, thu tiền) chạy trước view → luôn gửi một key hợp lệ,
# nếu không POST sẽ trả 400 trước khi tới bước kiểm quyền.
KHOA_IDEM = {"HTTP_IDEMPOTENCY_KEY": "7b0c1d5e-2f3a-4b6c-8d9e-0a1b2c3d4e5f"}


def _nguoi_dung(ma_vai_tro):
    """SV/GV có hồ sơ (thiếu hồ sơ thì các API của riêng họ trả 403 vì lý do khác với vai trò)."""
    if ma_vai_tro == "S":
        return StudentProfileFactory().user
    if ma_vai_tro == "G":
        return TeacherProfileFactory().user
    return UserFactory(role=VAI_TRO[ma_vai_tro])


def _client(ma_vai_tro):
    from rest_framework_simplejwt.tokens import RefreshToken

    c = APIClient()
    token = RefreshToken.for_user(_nguoi_dung(ma_vai_tro)).access_token
    c.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
    return c


CA = [
    pytest.param(method, path, vt, id=f"{method} {path} cấm {vt}")
    for (method, path), duoc in QUYEN.items()
    for vt in VAI_TRO
    if vt not in duoc
]


@pytest.mark.parametrize("method,path,vt", CA)
def test_vai_tro_sai_bi_chan(method, path, vt):
    res = getattr(_client(vt), method.lower())(_url(path), {}, format="json", **KHOA_IDEM)
    if (method, path) in CHAN_BANG_404 and res.status_code == 404:
        return  # đối tượng không thuộc người gọi → ẩn (404), vẫn không thực hiện được
    assert res.status_code == 403, f"{vt} gọi {method} {path} → {res.status_code}"
    assert res.data["error"]["code"] == "KHONG_CO_QUYEN"


@pytest.mark.parametrize(
    "method,path", [pytest.param(m, p, id=f"{m} {p}") for (m, p) in QUYEN], ids=None
)
def test_chua_dang_nhap_bi_401(method, path):
    res = getattr(APIClient(), method.lower())(_url(path), {}, format="json", **KHOA_IDEM)
    assert res.status_code == 401


DUNG = [
    pytest.param(path, vt, id=f"GET {path} cho {vt}")
    for (method, path), duoc in QUYEN.items()
    if method == "GET"
    for vt in duoc
]


@pytest.mark.parametrize("path,vt", DUNG)
def test_vai_tro_dung_khong_bi_chan_o_tang_quyen(path, vt):
    res = _client(vt).get(_url(path))
    assert res.status_code not in (401, 403), f"{vt} bị chặn ở GET {path}: {res.status_code}"
