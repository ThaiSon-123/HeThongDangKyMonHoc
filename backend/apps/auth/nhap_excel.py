"""Tạo tài khoản hàng loạt từ file Excel (ADM-02): file mẫu, đọc + kiểm tra từng dòng, tạo các dòng hợp lệ."""

from io import BytesIO
from zipfile import BadZipFile

from django.core.exceptions import ValidationError as DjangoValidationError
from openpyxl import load_workbook
from openpyxl.utils.exceptions import InvalidFileException
from rest_framework.exceptions import ValidationError

from apps.auth import services
from apps.auth.models import Role, User
from core.export import xlsx_nhieu_sheet

COT = ["Tên đăng nhập", "Họ tên", "Email", "Vai trò", "Mật khẩu"]
TOI_DA_DONG = 1000
TOI_DA_BYTE = 2 * 1024 * 1024
# Vai trò nhận cả nhãn tiếng Việt lẫn mã, không phân biệt hoa thường
VAI_TRO = {
    **{str(r.label).lower(): r.value for r in Role},
    **{r.value.lower(): r.value for r in Role},
}


def file_mau():
    vi_du = [
        ("2324801030999", "Nguyễn Văn An", "an.nv@student.tdmu.edu.vn", "Sinh viên", "MatKhau2026"),
        ("gv.tranthib", "Trần Thị B", "b.tt@tdmu.edu.vn", "Giảng viên", "MatKhau2026"),
    ]
    huong_dan = [
        ("Tên đăng nhập", "Bắt buộc, không trùng tài khoản đã có và không trùng trong file."),
        ("Họ tên", "Không bắt buộc."),
        ("Email", "Không bắt buộc; dùng để nhận mã xác thực khi quên mật khẩu."),
        ("Vai trò", "Bắt buộc, một trong: " + ", ".join(str(r.label) for r in Role) + "."),
        ("Mật khẩu", "Bắt buộc, ít nhất 8 ký tự, có cả chữ và số."),
        ("Lưu ý", "Giữ nguyên dòng tiêu đề và thứ tự cột; xóa 2 dòng ví dụ trước khi nhập."),
    ]
    return xlsx_nhieu_sheet(
        "mau_tao_tai_khoan.xlsx",
        [("Tài khoản", COT, vi_du), ("Hướng dẫn", ["Cột", "Quy định"], huong_dan)],
    )


def _o(v):
    return "" if v is None else str(v).strip()


def doc_file(f):
    """Đọc file đã tải lên → các dòng `{dong, username, full_name, email, role, password, loi[]}`.
    File không đọc được / sai mẫu / rỗng → `ValidationError` field `file` (không trả dòng nào)."""
    if f is None:
        raise ValidationError({"file": ["Chưa chọn file Excel."]})
    if f.size > TOI_DA_BYTE:
        raise ValidationError({"file": ["File quá lớn (tối đa 2 MB)."]})
    try:
        ws = load_workbook(BytesIO(f.read()), read_only=True, data_only=True).worksheets[0]
    except (BadZipFile, InvalidFileException, KeyError, OSError, ValueError):
        raise ValidationError(
            {"file": ["Không đọc được file. Hãy dùng file Excel (.xlsx) theo mẫu."]}
        ) from None
    dong = ws.iter_rows(values_only=True)
    tieu_de = [_o(v) for v in next(dong, ())]
    while tieu_de and not tieu_de[-1]:
        tieu_de.pop()
    if tieu_de != COT:
        thieu = [c for c in COT if c not in tieu_de]
        chi_tiet = f"thiếu cột {', '.join(thieu)}" if thieu else "sai thứ tự cột"
        raise ValidationError(
            {
                "file": [
                    f"File không đúng mẫu ({chi_tiet}). Dòng tiêu đề phải là: {' · '.join(COT)}."
                ]
            }
        )

    rows = []
    for so, r in enumerate(dong, start=2):
        gia_tri = [_o(v) for v in (*r, *[None] * len(COT))[: len(COT)]]
        if not any(gia_tri):
            continue  # bỏ dòng trống
        username, full_name, email, vai_tro, password = gia_tri
        rows.append(
            {
                "dong": so,
                "username": username,
                "full_name": full_name,
                "email": email,
                "role": VAI_TRO.get(vai_tro.lower(), vai_tro),
                "password": password,
            }
        )
        if len(rows) > TOI_DA_DONG:
            raise ValidationError({"file": [f"Mỗi lần nhập tối đa {TOI_DA_DONG} tài khoản."]})
    if not rows:
        raise ValidationError({"file": ["File không có dòng tài khoản nào."]})
    _kiem_tra(rows)
    return rows


def _kiem_tra(rows):
    da_co = set(
        User.objects.filter(username__in=[r["username"] for r in rows]).values_list(
            "username", flat=True
        )
    )
    dem = {}
    for r in rows:
        dem[r["username"]] = dem.get(r["username"], 0) + 1
    email_field = User._meta.get_field("email")
    for r in rows:
        loi = []
        u = r["username"]
        if not u:
            loi.append("Thiếu tên đăng nhập.")
        elif u in da_co:
            loi.append("Tên đăng nhập đã tồn tại.")
        elif dem[u] > 1:
            loi.append("Tên đăng nhập bị trùng trong file.")
        elif len(u) > 150 or not all(c.isalnum() or c in "@.+-_" for c in u):
            loi.append("Tên đăng nhập chỉ gồm chữ, số và @ . + - _ (tối đa 150 ký tự).")
        if r["role"] not in Role.values:
            loi.append("Vai trò không hợp lệ.")
        if r["email"]:
            try:
                email_field.run_validators(r["email"])
            except DjangoValidationError:
                loi.append("Email không hợp lệ.")
        if not r["password"]:
            loi.append("Thiếu mật khẩu.")
        else:
            try:
                services.check_password_policy(r["password"], User(username=u), "password")
            except ValidationError as e:
                loi.extend(e.detail["password"])
        r["loi"] = [str(x) for x in loi]


def tao_tai_khoan(rows):
    """Tạo các dòng không có lỗi. Trả danh sách `User` đã tạo."""
    return [
        User.objects.create_user(
            username=r["username"],
            password=r["password"],
            email=r["email"],
            first_name=r["full_name"],
            role=r["role"],
        )
        for r in rows
        if not r["loi"]
    ]


def xem_truoc(rows):
    """Bỏ mật khẩu khỏi dữ liệu trả về; kèm nhãn vai trò để hiển thị."""
    nhan = dict(Role.choices)
    return [
        {
            "dong": r["dong"],
            "username": r["username"],
            "full_name": r["full_name"],
            "email": r["email"],
            "role": r["role"],
            "role_label": str(nhan.get(r["role"], r["role"])),
            "loi": r["loi"],
        }
        for r in rows
    ]
