"""Ma trận phân quyền (ADM-04) — bản **chỉ đọc** của plan.md mục 9, cố định trong code.

Mỗi dòng: `(nhóm hiển thị, quyền, Admin, PĐT, SV, GV, KT)`; thứ tự cột như vậy.
Mỗi ô: `Y` có · `N` không · `Y:ghi chú` có giới hạn phạm vi.
Quyền thật được kiểm tra ở từng view (`core/permissions.py`); bảng này chỉ để Admin xem — test
`test_ma_tran_khop_hanh_vi_that` đối chiếu một số quyền chính với hành vi thật để hai nơi không lệch nhau.
"""

from apps.auth.models import Role

CAC_VAI_TRO = [Role.ADMIN, Role.PHONG_DAO_TAO, Role.SINH_VIEN, Role.GIAO_VIEN, Role.KE_TOAN]

NHOM = ["Tài khoản và hệ thống", "Đào tạo", "Tài chính"]  # thứ tự hiển thị các nhóm

MA_TRAN = [
    (
        "Tài khoản và hệ thống",
        "Đăng nhập, đổi/quên mật khẩu, xem hồ sơ mình",
        "Y",
        "Y",
        "Y",
        "Y",
        "Y",
    ),
    ("Tài khoản và hệ thống", "Tạo/khóa tài khoản, reset mật khẩu", "Y", "N", "N", "N", "N"),
    (
        "Tài khoản và hệ thống",
        "Xem ma trận quyền, cấu hình hệ thống, backup",
        "Y",
        "N",
        "N",
        "N",
        "N",
    ),
    ("Tài khoản và hệ thống", "Audit log", "Y:tất cả", "Y:đào tạo", "N", "N", "Y:tài chính"),
    ("Tài khoản và hệ thống", "Hồ sơ SV/GV", "Y:đọc", "Y:đọc + sửa", "N", "N", "N"),
    (
        "Đào tạo",
        "Ngành / CTĐT / Môn / Tiên quyết / Học kỳ / Lớp HP / Lịch",
        "N",
        "Y",
        "N",
        "N",
        "N",
    ),
    ("Đào tạo", "Theo dõi đăng ký", "N", "Y", "Y:của mình", "N", "N"),
    ("Đào tạo", "Đăng ký / hủy đăng ký", "N", "Y:chỉ hủy hộ", "Y", "N", "N"),
    ("Đào tạo", "Điểm danh + sửa điểm danh (buổi sinh sẵn)", "N", "N", "N", "Y:lớp mình", "N"),
    ("Đào tạo", "Xem điểm danh", "N", "Y", "Y:của mình", "Y:lớp mình", "N"),
    ("Đào tạo", "Xin sửa điểm danh", "N", "N", "Y", "N", "N"),
    ("Đào tạo", "Duyệt yêu cầu sửa điểm danh", "N", "N", "N", "Y:lớp mình", "N"),
    ("Đào tạo", "Nhập / khóa / mở khóa điểm", "N", "N", "N", "Y:lớp mình", "N"),
    ("Đào tạo", "Duyệt điểm, gia hạn, nhập hộ", "N", "Y", "N", "N", "N"),
    ("Đào tạo", "Xem điểm", "N", "Y", "Y:của mình", "Y:lớp mình", "N"),
    (
        "Tài chính",
        "Bảng giá / miễn giảm / tính / thu / hoàn / công nợ / biên lai",
        "N",
        "N",
        "N",
        "N",
        "Y",
    ),
    ("Tài chính", "Xem học phí", "N", "N", "Y:của mình", "N", "Y"),
    ("Tài khoản và hệ thống", "Gửi thông báo", "Y", "Y", "N", "Y:lớp mình", "Y"),
    ("Tài khoản và hệ thống", "Nhận thông báo", "Y", "Y", "Y", "Y", "Y"),
    ("Đào tạo", "Báo cáo đào tạo / xuất đăng ký", "N", "Y", "N", "N", "N"),
    ("Tài chính", "Báo cáo tài chính / xuất", "N", "N", "N", "N", "Y"),
    ("Đào tạo", "Xuất danh sách lớp", "N", "Y", "N", "Y:lớp mình", "N"),
]


def _o(ma):
    co, _, ghi_chu = ma.partition(":")
    return {"co": co == "Y", "gioi_han": ghi_chu or None}


def ma_tran():
    """`[{nhom, quyen, ADMIN: {co, gioi_han}, PHONG_DAO_TAO: {...}, ...}]` theo thứ tự plan mục 9."""
    return [
        {
            "nhom": dong[0],
            "quyen": dong[1],
            **{vt.value: _o(o) for vt, o in zip(CAC_VAI_TRO, dong[2:], strict=True)},
        }
        for dong in sorted(
            MA_TRAN, key=lambda d: NHOM.index(d[0])
        )  # sắp ổn định: giữ thứ tự plan trong nhóm
    ]
