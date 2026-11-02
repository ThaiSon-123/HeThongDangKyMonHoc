"""Admin tạo tài khoản hàng loạt từ file Excel: file mẫu, xem trước (sai mẫu / lỗi từng dòng), tạo dòng hợp lệ."""

from io import BytesIO

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from openpyxl import Workbook, load_workbook

from apps.audit.models import AuditLog
from apps.auth.models import Role, User
from apps.auth.nhap_excel import COT
from core.factories import UserFactory

pytestmark = pytest.mark.django_db
URL = "/api/users/import/"


@pytest.fixture
def admin(login_as):
    return login_as(UserFactory(role=Role.ADMIN))


def excel(rows, cot=COT):
    wb = Workbook()
    ws = wb.active
    ws.append(cot)
    for r in rows:
        ws.append(list(r))
    buf = BytesIO()
    wb.save(buf)
    return SimpleUploadedFile("tk.xlsx", buf.getvalue())


def gui(api, f, xac_nhan=False):
    return api.post(URL, {"file": f, "xac_nhan": "1" if xac_nhan else "0"}, format="multipart")


def test_file_mau_dung_cot_va_doc_lai_duoc(admin):
    res = admin.get("/api/users/import-template/")
    assert res.status_code == 200 and "spreadsheetml" in res["Content-Type"]
    ws = load_workbook(BytesIO(res.content)).worksheets[0]
    assert [c.value for c in ws[1]] == COT


def test_xem_truoc_khong_tao_va_danh_dau_loi_tung_dong(admin):
    UserFactory(username="da_co")
    f = excel(
        [
            ("sv001", "Nguyễn Văn A", "a@example.com", "Sinh viên", "MatKhau2026"),
            ("gv001", "Trần B", "", "GIAO_VIEN", "MatKhau2026"),
            ("da_co", "", "", "Kế toán", "MatKhau2026"),
            ("sv002", "", "khong-phai-email", "Hiệu trưởng", "yeu"),
            ("sv001", "", "", "Sinh viên", "MatKhau2026"),
            (None, None, None, None, None),  # dòng trống bị bỏ qua
        ]
    )

    res = gui(admin, f)

    assert res.status_code == 200
    assert (res.data["hop_le"], res.data["loi"]) == (1, 4)
    theo_dong = {r["dong"]: r for r in res.data["rows"]}
    assert theo_dong[3]["loi"] == [] and theo_dong[3]["role"] == "GIAO_VIEN"
    assert theo_dong[3]["role_label"] == "Giảng viên"
    assert "Tên đăng nhập bị trùng trong file." in theo_dong[2]["loi"]
    assert theo_dong[4]["loi"] == ["Tên đăng nhập đã tồn tại."]
    assert {"Vai trò không hợp lệ.", "Email không hợp lệ."} <= set(theo_dong[5]["loi"])
    assert all("password" not in r for r in res.data["rows"])  # không trả mật khẩu
    assert not User.objects.filter(username__in=["sv001", "gv001"]).exists()


def test_xac_nhan_tao_dong_hop_le_bo_qua_dong_loi_va_ghi_audit(admin, client):
    f = excel(
        [
            ("sv001", "Nguyễn Văn A", "a@example.com", "Sinh viên", "MatKhau2026"),
            ("sv002", "", "", "Sinh viên", "yeu"),
        ]
    )

    res = gui(admin, f, xac_nhan=True)

    assert res.status_code == 200 and res.data["da_tao"] == 1
    u = User.objects.get(username="sv001")
    assert (u.role, u.email, u.first_name) == (Role.SINH_VIEN, "a@example.com", "Nguyễn Văn A")
    assert not User.objects.filter(username="sv002").exists()
    assert AuditLog.objects.filter(doi_tuong="User", doi_tuong_id=str(u.id)).exists()
    login = client.post("/api/auth/login/", {"username": "sv001", "password": "MatKhau2026"})
    assert login.status_code == 200


@pytest.mark.parametrize(
    "f,thong_diep",
    [
        (
            excel([("a", "", "", "Sinh viên", "MatKhau2026")], cot=["Tên", "Vai trò"]),
            "không đúng mẫu",
        ),
        (excel([], cot=COT), "không có dòng tài khoản nào"),
        (SimpleUploadedFile("tk.xlsx", b"day khong phai excel"), "Không đọc được file"),
    ],
)
def test_sai_mau_bao_loi_file(admin, f, thong_diep):
    res = gui(admin, f)
    assert res.status_code == 400 and thong_diep in res.data["file"][0]


def test_xac_nhan_khi_khong_dong_nao_hop_le_bi_tu_choi(admin):
    res = gui(admin, excel([("", "", "", "Sinh viên", "MatKhau2026")]), xac_nhan=True)
    assert res.status_code == 400 and User.objects.filter(role=Role.SINH_VIEN).count() == 0


def test_chi_admin(login_as):
    api = login_as(UserFactory(role=Role.PHONG_DAO_TAO))
    assert gui(api, excel([("a", "", "", "Sinh viên", "MatKhau2026")])).status_code == 403
