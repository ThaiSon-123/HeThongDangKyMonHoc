# Mockup giao diện (tham chiếu)

Bản thiết kế **toàn bộ giao diện** của hệ thống — 5 vai trò, 70 màn — dùng làm chuẩn để dựng Flutter "làm giống".
Đây là mockup tĩnh/tương tác mô phỏng, **không phải mã sản phẩm**: bám theo bố cục, màu, hành vi, câu chữ; không sao chép HTML vào Flutter.

> Nguồn quy tắc nghiệp vụ vẫn là [`plan.md`](../plan.md); quy ước giao diện nằm ở [`design.md`](../design.md) (mục 1.7 chọn tuần tự, 1.8 phong cách, 1.9 tương tác & chuyển động). Có lệch giữa mockup và hai file này thì **hai file này thắng**, rồi sửa mockup.

## Cách xem

```bash
cd design_mockups
python -m http.server 8000
```

Mở `http://localhost:8000/index.html` (danh sách màn hình) hoặc mở thẳng một tệp `*.dc.html`. Cần mạng để tải font Be Vietnam Pro. Tệp `support.js` là runtime của Claude Design (gồm React) để các `.dc.html` chạy được khi mở cục bộ.

`canvas.json` là bố cục tấm canvas (vị trí, kích thước từng màn: Web 1440 px, App 390 px) nếu cần nhập lại vào Claude Design.

## Quy ước đặt tên

| Tiền tố | Vai trò | Nền tảng |
| :--- | :--- | :--- |
| `SV-Web-*`, `SV-App-*` | Sinh viên | Web / App |
| `Main`, `Web-*`, `App-*` | Giáo viên | Web / App |
| `PDT-Web-*` | Phòng đào tạo | chỉ Web |
| `KT-Web-*` | Kế toán | chỉ Web |
| `AD-Web-*` | Quản trị (Admin) | chỉ Web |

## Những điều cần biết khi làm theo

- **Dữ liệu mẫu** thống nhất giữa các vai trò: sinh viên Trần Hoàng Nam (SV2023014, CNTT K2023), giáo viên Trần Minh Quân (GV001) dạy CNTT101-01, CNTT203-02, CNTT305-01, CNTT320-01; "hôm nay" là **12/01/2027** (đăng ký học kỳ 2 còn 7 ngày).
- Màn có **tweak** (`mode`, `startStep`, `uiState`…) để xem các trạng thái: đang mở/đóng đăng ký, đang tải, lỗi tải. Mở trong Claude Design để chỉnh; mở cục bộ thì sửa giá trị `default` trong `data-props` của tệp.
- **Luồng chọn tuần tự** (chọn lớp trước thì mới hiện buổi/danh sách) và **ô gõ để tìm có lọc liên động** (ngành → môn → giáo viên cùng khoa/viện) là bắt buộc — xem `design.md` mục 1.7 và 1.9.
- Giao diện **không hiển thị mã kỹ thuật** (tên enum, mã lỗi, tên API); nhãn tiếng Việt lấy theo mockup.
- Phần hành vi bổ sung (phím tắt, bảng trượt chọn trên App, chuyển động) nằm trong khối `ui-polish` ở đầu mỗi tệp — chỉ là mô phỏng, bản Flutter dùng thành phần Material 3 tương ứng (xem bảng ở `design.md` mục 1.9).
- Mockup **chưa có**: sắp xếp theo cột ở mọi bảng, kéo-xuống-để-làm-mới / vuốt-ngang-dòng ở App, chế độ tối, thông báo lỗi ngay dưới từng ô nhập.

## Danh sách màn hình

### Sinh viên — Web (Web + App)

| Màn hình | Route | Tệp |
| :--- | :--- | :--- |
| Tổng quan | `/student` | `SV-Web-TongQuan.dc.html` |
| Đăng ký môn học | `/student/register` | `SV-Web-DangKy.dc.html` |
| Tạo TKB tự động | `/student/auto-schedule` | `SV-Web-TKBTuDong.dc.html` |
| Thời khóa biểu | `/student/schedule` | `SV-Web-TKB.dc.html` |
| Chương trình đào tạo | `/student/curriculum` | `SV-Web-CTDT.dc.html` |
| Điểm | `/student/grades` | `SV-Web-Diem.dc.html` |
| Điểm danh | `/student/attendance` | `SV-Web-DiemDanh.dc.html` |
| Học phí | `/student/tuition` | `SV-Web-HocPhi.dc.html` |
| Thanh toán học phí (mã QR) | `/student/tuition/pay` | `SV-Web-ThanhToan.dc.html` |
| Thông báo | `/student/notifications` | `SV-Web-ThongBao.dc.html` |
| Hồ sơ | `/student/profile` | `SV-Web-HoSo.dc.html` |

### Sinh viên — App

| Màn hình | Route | Tệp |
| :--- | :--- | :--- |
| Tổng quan | `/student` | `SV-App-TongQuan.dc.html` |
| Đăng ký môn học | `/student/register` | `SV-App-DangKy.dc.html` |
| Tạo TKB tự động | `/student/auto-schedule` | `SV-App-TKBTuDong.dc.html` |
| Thời khóa biểu | `/student/schedule` | `SV-App-TKB.dc.html` |
| Chương trình đào tạo | `/student/curriculum` | `SV-App-CTDT.dc.html` |
| Điểm | `/student/grades` | `SV-App-Diem.dc.html` |
| Điểm danh | `/student/attendance` | `SV-App-DiemDanh.dc.html` |
| Học phí | `/student/tuition` | `SV-App-HocPhi.dc.html` |
| Thanh toán học phí (mã QR) | `/student/tuition/pay` | `SV-App-ThanhToan.dc.html` |
| Thông báo | `/student/notifications` | `SV-App-ThongBao.dc.html` |
| Hồ sơ | `/student/profile` | `SV-App-HoSo.dc.html` |

### Giáo viên — Web (Web + App)

| Màn hình | Route | Tệp |
| :--- | :--- | :--- |
| Tổng quan | `/teacher` | `Main.dc.html` |
| Lớp phụ trách | `/teacher/classes` | `Web-Lop.dc.html` |
| Điểm danh | `/teacher/attendance` | `Web-DiemDanh.dc.html` |
| Nhập điểm | `/teacher/grades` | `Web-NhapDiem.dc.html` |
| Thời khóa biểu | `/teacher/schedule` | `Web-TKB.dc.html` |
| Thông báo | `/teacher/notifications` | `Web-ThongBao.dc.html` |
| Hồ sơ | `/teacher/profile` | `Web-HoSo.dc.html` |
| Đăng nhập | `/login` | `Web-DangNhap.dc.html` |
| Quên mật khẩu | `/forgot-password` | `Web-QuenMatKhau.dc.html` |

### Giáo viên — App

| Màn hình | Route | Tệp |
| :--- | :--- | :--- |
| Tổng quan | `/teacher` | `App-TongQuan.dc.html` |
| Lớp phụ trách | `/teacher/classes` | `App-Lop.dc.html` |
| Chi tiết lớp | `/teacher/classes/:id` | `App-ChiTietLop.dc.html` |
| Điểm danh 1/3 — chọn lớp | `/teacher/attendance` | `App-ChonLop.dc.html` |
| Điểm danh 2/3 — các buổi | `/teacher/attendance` | `App-DanhSachBuoi.dc.html` |
| Điểm danh 3/3 — danh sách sinh viên | `/teacher/attendance` | `App-DiemDanh.dc.html` |
| Nhập điểm | `/teacher/grades` | `App-NhapDiem.dc.html` |
| Thời khóa biểu | `/teacher/schedule` | `App-TKB.dc.html` |
| Thông báo | `/teacher/notifications` | `App-ThongBao.dc.html` |
| Hồ sơ | `/teacher/profile` | `App-HoSo.dc.html` |
| Đăng nhập | `/login` | `App-DangNhap.dc.html` |
| Quên mật khẩu | `/forgot-password` | `App-QuenMatKhau.dc.html` |

### Phòng đào tạo — Web (chỉ Web)

| Màn hình | Route | Tệp |
| :--- | :--- | :--- |
| Tổng quan | `/pdt` | `PDT-Web-TongQuan.dc.html` |
| Hồ sơ SV / GV | `/pdt/profiles` | `PDT-Web-HoSo.dc.html` |
| Khoa / viện | `/pdt/faculties` | `PDT-Web-KhoaVien.dc.html` |
| Ngành | `/pdt/majors` | `PDT-Web-Nganh.dc.html` |
| CTĐT & gán môn | `/pdt/curriculums` | `PDT-Web-CTDT.dc.html` |
| Môn học & tiên quyết | `/pdt/courses` | `PDT-Web-MonHoc.dc.html` |
| Học kỳ & cửa sổ đăng ký | `/pdt/semesters` | `PDT-Web-HocKy.dc.html` |
| Lớp học phần & lịch | `/pdt/classes` | `PDT-Web-LopHP.dc.html` |
| Theo dõi đăng ký & hủy hộ | `/pdt/registrations` | `PDT-Web-DangKy.dc.html` |
| Duyệt điểm | `/pdt/grade-sheets` | `PDT-Web-DuyetDiem.dc.html` |
| Báo cáo đào tạo | `/pdt/reports` | `PDT-Web-BaoCao.dc.html` |
| Thông báo | `/pdt/notifications` | `PDT-Web-ThongBao.dc.html` |
| Nhật ký thao tác | `/pdt/logs` | `PDT-Web-NhatKy.dc.html` |

### Kế toán — Web (chỉ Web)

| Màn hình | Route | Tệp |
| :--- | :--- | :--- |
| Tổng quan | `/accountant` | `KT-Web-TongQuan.dc.html` |
| Cấu hình học phí | `/accountant/config` | `KT-Web-CauHinh.dc.html` |
| Học phí | `/accountant/tuition` | `KT-Web-HocPhi.dc.html` |
| Công nợ | `/accountant/debts` | `KT-Web-CongNo.dc.html` |
| Báo cáo tài chính | `/accountant/reports` | `KT-Web-BaoCao.dc.html` |
| Thông báo | `/accountant/notifications` | `KT-Web-ThongBao.dc.html` |
| Nhật ký thao tác | `/accountant/logs` | `KT-Web-NhatKy.dc.html` |

### Quản trị — Web (chỉ Web)

| Màn hình | Route | Tệp |
| :--- | :--- | :--- |
| Tổng quan | `/admin` | `AD-Web-TongQuan.dc.html` |
| Tài khoản | `/admin/accounts` | `AD-Web-TaiKhoan.dc.html` |
| Ma trận quyền | `/admin/permissions` | `AD-Web-MaTranQuyen.dc.html` |
| Cấu hình hệ thống | `/admin/config` | `AD-Web-CauHinh.dc.html` |
| Sao lưu | `/admin/backups` | `AD-Web-SaoLuu.dc.html` |
| Thông báo | `/admin/notifications` | `AD-Web-ThongBao.dc.html` |
| Nhật ký | `/admin/logs` | `AD-Web-NhatKy.dc.html` |

