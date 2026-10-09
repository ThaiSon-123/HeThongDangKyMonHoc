# DESIGN SPEC — Hệ thống Đăng ký Môn học (Registration System)

> File mô tả thiết kế UI để sinh màn hình bằng Google Stitch.
> Cách dùng: dán mục "1. Theme prompt" vào phần System/Theme của Stitch, rồi dán từng "Prompt" ở mục 3 để sinh từng màn hình.

---

## 1. Theme prompt (dùng chung cho mọi màn hình)

```
A modern, clean academic management web app for a Vietnamese university
course registration system, called "Đăng ký Môn học".
Style: Material 3, light mode, friendly and professional.
Primary color: indigo #3F51B5, secondary: teal #009688,
background: #F5F6FA (soft gray), surface: white cards with subtle shadow,
success green #2E7D32, error red #C62828, warning amber #F9A825.
Typography: Inter / Roboto, headings bold, body regular 14-16px.
Layout: left sidebar navigation (collapsible, 240px) + top app bar with
search and user avatar. Rounded corners 12px, cards with 16px padding.
Tables use zebra rows and status badge chips.
All UI text is in Vietnamese.
```

### Design tokens

| Token | Giá trị | Ghi chú |
| :--- | :--- | :--- |
| Primary | `#3F51B5` | Nút chính, link, tab active |
| Secondary | `#009688` | Nhấn phụ, trạng thái "đã duyệt" |
| Background | `#F5F6FA` | Nền trang |
| Surface | `#FFFFFF` | Card, bảng, sidebar |
| Success / Error / Warning | `#2E7D32` / `#C62828` / `#F9A825` | Badge trạng thái |
| Text chính / phụ | `#212121` / `#757575` | |
| Corner radius | 12px (card, nút), 8px (input) | |
| Spacing | Bội số của 8px | |
| Icon | Material Symbols | |

### Components dùng lặp lại

- **Sidebar**: logo trường, menu theo vai trò, mục active có nền indigo nhạt
- **Top bar**: tiêu đề trang, ô tìm kiếm, chuông thông báo (có dot đỏ), avatar + tên vai trò
- **Status chip**: `Mở đăng ký` (xanh lá), `Đóng` (xám), `Sắp mở` (vàng), `Chờ duyệt` (vàng), `Đã duyệt` (xanh), `Từ chối` (đỏ)
- **Card môn học**: mã môn, tên môn, số tín chỉ, giảng viên, sĩ số hiện tại/tối đa (thanh progress), nút hành động
- **Bảng dữ liệu**: header nền #FAFAFA, phân trang, tìm kiếm phía trên

---

## 2. Vai trò & menu

| Vai trò | Menu sidebar |
| :--- | :--- |
| Sinh viên (SV) | Trang chủ, Đăng ký môn học, Lịch học của tôi, Điểm của tôi, Học phí |
| Giảng viên (GV) | Trang chủ, Lớp học đang dạy, Nhập điểm, Lịch giảng dạy |
| Phụ trách (PĐ) | Duyệt đăng ký, Quản lý lớp học, Báo cáo khoa |
| Kế toán (KT) | Quản lý học phí, Lịch sử thanh toán |
| Admin | Người dùng, Môn học & Lớp, Đợt đăng ký, Cấu hình hệ thống |

---

## 3. Danh sách màn hình

### 3.1 Đăng nhập

**Prompt:**
```
A centered login screen on a soft gray background. Left half: indigo
gradient panel with university logo, app title "Đăng ký Môn học" and a
short tagline. Right half: white card with Vietnamese labels — email
field, password field with eye toggle, primary button "Đăng nhập",
link "Quên mật khẩu?", and a role hint text. Clean Material 3 style.
```

### 3.2 Trang chủ (Dashboard)

**Prompt:**
```
Dashboard home screen with left sidebar (menu: Trang chủ, Đăng ký môn học,
Lịch học của tôi, Điểm của tôi, Học phí) and top bar. Content: greeting
header "Xin chào, Nguyễn Văn A", then a row of 4 stat cards (Số tín chỉ
đã đăng ký, Lớp đang học, GPA hiện tại, Học phí còn nợ), below that a
weekly schedule preview card and a notifications list card. Light mode,
indigo accents, Vietnamese text.
```

### 3.3 Đăng ký môn học (màn chính của SV)

**Prompt:**
```
Course registration screen, two-column layout. Left column (65%): search
bar with filters (khoa, học kỳ), then a scrollable list of course cards —
each card shows course code (e.g. "IT4040"), course name in Vietnamese,
3 credits chip, lecturer name, current/max seats "35/50" with a progress
bar, schedule "Thứ 2, Tiết 1-3", and a primary button "Đăng ký" (disabled
gray when full). Right column (35%): sticky cart panel "Giỏ đăng ký" —
list of selected courses with remove icons, total credits counter
"Tổng: 12/24 tín chỉ", and a big indigo button "Xác nhận đăng ký".
Light background, Material 3, Vietnamese text.
```

### 3.4 Lịch học của tôi

**Prompt:**
```
Weekly timetable screen. Top bar with week selector arrows and semester
dropdown "Học kỳ 1 - 2025-2026". Content: a color-coded weekly grid,
days Monday-Saturday as columns, time periods as rows. Each class block
is a rounded colored card showing course code, room, and group. Legend
below. Sidebar navigation, light theme, Vietnamese text.
```

### 3.5 Điểm của tôi

**Prompt:**
```
Grades screen. Top: semester dropdown filter. A data table with columns:
Mã môn, Tên môn, Số tín chỉ, Điểm quá trình, Điểm thi, Điểm chữ cái,
Ghi chú. Pass rows show a green "Đạt" chip, failed rows a red chip.
Above the table, 3 summary stat cards: GPA học kỳ, GPA tích lũy,
Tín chỉ tích lũy. Clean zebra table, Material 3, Vietnamese text.
```

### 3.6 Học phí

**Prompt:**
```
Tuition payment screen. Top: summary card "Học phí học kỳ 1 - 2025-2026"
showing total amount "12.000.000 VNĐ", paid "8.000.000 VNĐ", remaining
"4.000.000 VNĐ" with a progress bar. Below: transaction history table
with columns Mã giao dịch, Ngày, Số tiền, Phương thức, Trạng thái chip
("Thành công" green / "Chờ xử lý" amber). Primary button "Thanh toán
học phí". Light theme, Vietnamese text.
```

### 3.7 Nhập điểm (GV)

**Prompt:**
```
Grade entry screen for a lecturer. Top: class dropdown "Lớp: IT4040-N1",
search field for student ID. Data table with columns: Mã SV, Họ tên,
Điểm quá trình (number input), Điểm thi (number input), Điểm tổng
(auto-calculated, read-only). Sticky bottom action bar with buttons
"Lưu nháp" (outlined) and "Chốt điểm" (filled, with confirmation state).
Light theme, Vietnamese text.
```

### 3.8 Duyệt đăng ký (PĐ)

**Prompt:**
```
Registration approval screen. Top: filters by class and status chips
(Chờ duyệt, Đã duyệt, Từ chối). Data table of registration requests with
columns: Mã SV, Họ tên, Môn học, Thời gian đăng ký, Trạng thái chip,
and two icon buttons per row: approve (green check) and reject (red X).
A banner at top shows "24 yêu cầu đang chờ duyệt". Sidebar for faculty
admin role, light theme, Vietnamese text.
```

### 3.9 Quản lý người dùng (Admin)

**Prompt:**
```
User management screen. Top: search bar, role filter dropdown, and a
primary button "+ Thêm người dùng". Data table: Mã người dùng, Họ tên,
Email, Vai trò chip (SV, GV, Phụ trách, Kế toán, Admin), Khoa, Trạng thái
(Active/Inactive switch), action icons edit and delete. Pagination below.
Sidebar navigation, light theme, Vietnamese text.
```

### 3.10 Quản lý Môn học & Lớp (Admin)

**Prompt:**
```
Course and class management screen with tabs "Môn học" and "Lớp học".
Tab 1: course table (Mã môn, Tên môn, Tín chỉ, Khoa, Số lớp) with
"+ Thêm môn học" button. Tab 2: class cards grid, each card shows class
code "IT4040-N1", lecturer, schedule, seats "35/50" progress bar, and
status chip "Mở đăng ký". Light theme, Material 3, Vietnamese text.
```

### 3.11 Quản lý Đợt đăng ký (Admin)

**Prompt:**
```
Registration period management screen. A timeline list of periods, each
card shows period name "Đợt 1 - Học kỳ 1", start/end date pickers,
status chip (Sắp mở amber / Đang mở green / Đã đóng gray), and allowed
year cohorts ("Dành cho SV năm 2"). Primary button "+ Tạo đợt mới".
Light theme, Vietnamese text.
```

---

## 4. Trạng thái & ràng buộc cần thể hiện

- Nút "Đăng ký" **disable + xám** khi lớp đã đủ sĩ số hoặc trùng lịch → tooltip "Lớp đã đầy" / "Trùng lịch học"
- Sĩ số progress bar: <70% xanh, 70–90% vàng, >90% đỏ (gần đầy)
- Giỏ đăng ký vượt 24 tín chỉ → nút Xác nhận disable + cảnh báo đỏ
- Xác nhận đăng ký → dialog xác nhận → toast "Đăng ký thành công" + cập nhật chip trạng thái
- Bảng trống (empty state): icon + dòng "Chưa có dữ liệu"
