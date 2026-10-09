# DESIGN SPEC — Hệ thống Đăng ký Môn học (Registration System)

> **Nguồn duy nhất:** `plan.md` v2.5 + `checklist.md` + `chuc_nang.md` + `app_router.dart` (route thực tế).
> **Mục đích:** mô tả đủ để sinh UI bằng Google Stitch / Figma Make **và** để FE build Flutter Web + App đúng 63 chức năng (PDT-16, SV-14, GV-12, KT-13, ADM-08) trên 5 vai trò.
> **Cách dùng với Stitch:** dán mục **1. Theme prompt** vào System/Theme, rồi dán từng **Prompt** ở mục 5–9 cho từng route.

---

## 1. Theme prompt (dùng chung cho mọi màn hình)

```
A modern, clean academic management web app for a Vietnamese university
course registration system, called "Đăng ký Môn học".
Style: Material 3, light mode, friendly and professional.
Primary: indigo #3F51B5, secondary: teal #009688,
background: #F5F6FA (soft gray), surface: white cards with subtle shadow,
success green #2E7D32, error red #C62828, warning amber #F9A825.
Typography: Inter / Roboto, headings bold, body regular 14-16px.
Layout: left sidebar navigation (collapsible, 240px) + top app bar with
search and user avatar. Rounded corners 12px, cards with 16px padding.
Tables use zebra rows and status badge chips. All UI text is in Vietnamese.
Dark mode: same seed #1A56DB via ColorScheme.fromSeed (AppTheme).
```

### 1.1. Design tokens (đồng bộ `lib/core/theme/app_theme.dart`)

| Token | Giá trị | Ghi chú |
| :--- | :--- | :--- |
| Primary (seed) | `#1A56DB` (light) / `#3F51B5` indigo accent | Nút chính, link, tab active — `ColorScheme.fromSeed(seed: 0xFF1A56DB)` |
| Secondary | `#009688` teal | Nhấn phụ, "đã duyệt", progress |
| Background | `#F5F6FA` | Nền trang |
| Surface | `#FFFFFF` | Card, bảng, sidebar |
| Success / Error / Warning | `#2E7D32` / `#C62828` / `#F9A825` | Badge trạng thái |
| Text chính / phụ | `#212121` / `#757575` | |
| Corner radius | 12px (card/nút), 8px (input), 16px (dialog) | |
| Spacing | Bội số 8px | |
| Icon | Material Symbols | |
| App seed | `0xFF1A56DB` | `AppTheme._seed` — Stitch có thể dùng indigo `#3F51B5` làm biến thể, code giữ seed này |

### 1.2. Typography & a11y
- Headings: bold 20–24px; body 14–16px; caption 12px.
- Touch target ≥ 48px (bắt buộc App SV/GV).
- Contrast AA; focus ring rõ; mọi bảng có `EmptyState` + `ErrorState` + skeleton.
- Envelope lỗi thống nhất `{"error":{"code","message","details"}}` → hiển thị `code` + `message` + `details` (vd `LOP_DAY` kèm `si_so_*`).

---

## 2. Nền tảng & Route map

### 2.1. Quy tắc nền tảng (plan.md mục 15, v2.5)

| Vai trò | Nền tảng | Ghi chú build |
| :--- | :--- | :--- |
| **Admin** | **Web only** | Route `/admin/*` chỉ render trên `kIsWeb`; trên App → `PlaceholderScreen("Chỉ khả dụng trên trình duyệt")` |
| **PĐT** | **Web only** | `/pdt/*` tương tự |
| **Kế toán** | **Web only** | `/accountant/*` tương tự |
| **Sinh viên** | **Web + App** | Full responsive; App layout mobile native |
| **Giáo viên** | **Web + App** | Full responsive; App layout mobile native |
| **Public** | Web + App | `/login`, `/forgot-password` khả dụng mọi nơi |

> `dang_ky_mon_hoc/` chỉ giữ `android/`, `ios/`, `web/` (đã xóa `linux/macos/windows`). Khi build App chỉ đóng gói `/login`, `/forgot-password`, `/student/*`, `/teacher/*`.

### 2.2. Route map thực tế (`lib/core/router/app_router.dart`)

| Vai trò | Route | Tên hiển thị | Nền tảng |
| :--- | :--- | :--- | :--- |
| **Public** | `/login` | Đăng nhập | Web + App |
| | `/forgot-password` | Quên mật khẩu | Web + App |
| **Admin** | `/admin` | Dashboard Admin | Web only |
| | `/admin/accounts` | Tài khoản | Web only |
| | `/admin/roles` | Phân quyền | Web only |
| | `/admin/config` | Cấu hình hệ thống | Web only |
| | `/admin/logs` | Audit log | Web only |
| | `/admin/backups` | Sao lưu / phục hồi | Web only |
| | `/admin/notifications` | Quản lý thông báo | Web only |
| **PĐT** | `/pdt` | Dashboard PĐT | Web only |
| | `/pdt/majors` | Ngành | Web only |
| | `/pdt/curriculums` | Chương trình đào tạo | Web only |
| | `/pdt/courses` | Học phần (+ tiên quyết) | Web only |
| | `/pdt/semesters` | Học kỳ + cửa sổ ĐK | Web only |
| | `/pdt/classes` | Lớp học phần + lịch | Web only |
| | `/pdt/registrations` | Theo dõi / hủy ĐK | Web only |
| | `/pdt/grade-sheets` | Duyệt điểm (KHOA) | Web only |
| | `/pdt/retakes` | Đơn học lại / cải thiện | Web only |
| | `/pdt/reports` | Báo cáo đào tạo | Web only |
| | `/pdt/notifications` | Quản lý thông báo | Web only |
| **Sinh viên** | `/student` | Dashboard SV | Web + App |
| | `/student/profile` | Hồ sơ sinh viên | Web + App |
| | `/student/register` | Đăng ký môn học | Web + App |
| | `/student/auto-schedule` | Tự động xếp TKB | Web + App |
| | `/student/schedule` | Thời khóa biểu | Web + App |
| | `/student/grades` | Bảng điểm | Web + App |
| | `/student/attendance` | Điểm danh | Web + App |
| | `/student/tuition` | Học phí | Web + App |
| | `/student/retakes` | Đơn học lại / cải thiện | Web + App |
| | `/student/notifications` | Thông báo | Web + App |
| **Giáo viên** | `/teacher` | Dashboard GV | Web + App |
| | `/teacher/profile` | Hồ sơ giáo viên | Web + App |
| | `/teacher/classes` | Lớp giảng dạy | Web + App |
| | `/teacher/attendance` | Điểm danh | Web + App |
| | `/teacher/grades` | Nhập điểm | Web + App |
| | `/teacher/notifications` | Thông báo | Web + App |
| **Kế toán** | `/accountant` | Dashboard KT | Web only |
| | `/accountant/config` | Cấu hình học phí | Web only |
| | `/accountant/tuition` | Học phí (danh sách + tính) | Web only |
| | `/accountant/debts` | Công nợ | Web only |
| | `/accountant/reports` | Báo cáo tài chính | Web only |
| | `/accountant/notifications` | Quản lý thông báo | Web only |

> Tổng route: **42** (2 public + 7 Admin + 11 PĐT + 10 SV + 6 GV + 6 KT). Dashboard (`/admin`, `/pdt`, `/student`, `/teacher`, `/accountant`) là màn tổng quan riêng, không chỉ redirect.

---

## 3. Shell & Components dùng chung

### 3.1. App shell
- **Web >1024px:** `NavigationDrawer` cố định 240px + `TopBar` (tiêu đề, search, chuông 🔔 có dot đỏ, avatar + role chip).
- **Web 600–1024px:** `NavigationRail` trượt (overlay).
- **Web <600px & App:** `BottomNavigationBar` (SV 5 tab, GV 4 tab) + `Drawer` trượt; AppBar gọn.
- **Sidebar theo role:** chỉ hiện menu của role; active có nền indigo nhạt + indicator.
- **Auth guard:** `unknown` → splash; chưa đăng nhập → `/login`; sai role → `role.homePath`.

### 3.2. Components lặp lại
- **Status chip:** `Mở đăng ký` (xanh `#2E7D32`), `Đóng` (xám), `Sắp mở` (vàng `#F9A825`), `Chờ duyệt` (vàng), `Đã duyệt` (xanh), `Từ chối` (đỏ), `CAM_THI` (đỏ đậm), `DA_DANG_KY`/`DA_HUY`, `NHAP_TAM`/`CHINH_THUC`/`KHOA`, `CHUA_TINH`/`DA_TINH`/`CON_NO`/`GIAM_TRU`/`CHO_HOAN_TIEN`.
- **Card môn học:** mã môn, tên môn (vi), tín chỉ chip, khối kiến thức, GV, sĩ số `hiện tại/tối đa` + progress bar (<70% xanh, 70–90% vàng, >90% đỏ), lịch `Thứ X, Tiết a–b, Phòng`.
- **Bảng dữ liệu:** header `#FAFAFA`, zebra rows, sort icon, filter chips trên bảng, search, phân trang (mặc định 25, tối đa 50), chọn `page_size`.
- **Dialog xác nhận:** tiêu đề + mô tả + 2 nút (Hủy / Xác nhận); với `cam_thi` xóa cờ bắt buộc nhập `ly_do`.
- **Toast/Snackbar:** thành công xanh, lỗi đỏ kèm `code`.
- **EmptyState:** icon + "Chưa có dữ liệu" + CTA.
- **Badge tín chỉ:** `Tổng: 12/24 TC` + cảnh báo `VUOT_TIN_TC_TOI_DA` đỏ / `warnings[]` vàng cho thiếu tối thiểu.
- **Tiến độ học phí:** `tổng — đã thu — miễn giảm — còn nợ — hoàn tiền` + thanh progress.

### 3.3. Patterns toàn cục
- **Phân trang/dropdown/filter:** mọi list dùng `?search=&ordering=&{fk}=&trang_thai=` (django-filter), whitelist field.
- **Rate limit UI:** 429 `QUA_NHIEU_YEU_CAU` → banner "Thử lại sau X giây".
- **Idempotency:** `POST /api/registrations/` và `POST /api/tuition/payments/` bắt buộc `Idempotency-Key` (UUID) — client tự sinh `uuid v4` mỗi lần bấm, gửi header; khi retry/network lỗi giữ nguyên key; khi `409 IDEMPOTENCY_KEY_REUSED` → báo "Yêu cầu đã được thay thế, vui lòng thử lại".
- **Warnings:** BR-07 thiếu tối thiểu, BR-15 thiếu CTĐT → trả `warnings[]` trong response 201/200 → hiện banner vàng, không chặn.
- **Offline (App SV/GV):** cache-API minimal read-only (TKB/điểm đã tải), mọi thao tác ghi cần mạng — hiện banner "Cần kết nối mạng".

---

## 4. Màn hình Public (Web + App)

### 4.1. `/login` — Đăng nhập (UC-01, SV-01/GV-01/ADM-01)
**Prompt:**
```
A centered login screen on soft gray #F5F6FA. Left half: indigo gradient panel with university logo, title "Đăng ký Môn học" and tagline. Right half: white card 12px radius, fields "Tên đăng nhập" + "Mật khẩu" with eye toggle, primary button "Đăng nhập", link "Quên mật khẩu?", role hint text. Material 3, Vietnamese.
```
- **Web:** 2 cột (gradient + card). **App:** 1 cột, card full-width, logo trên.
- Fields: `username`, `password`; validation rỗng; lỗi `TAI_KHOAN_BI_KHOA` → banner đỏ.
- Nút "Đăng nhập" → `POST /api/auth/login/` (rate limit 5/min/IP + 10/min/account) → lưu access(60m)/refresh(7d) vào `flutter_secure_storage`; interceptor tự refresh.
- Link "Quên mật khẩu?" → `/forgot-password`.

### 4.2. `/forgot-password` — Quên / đặt lại mật khẩu (Pha 1)
**Prompt:**
```
Password recovery screen, white card centered, step indicator (1. Nhập email → 2. Nhập mã/token → 3. Mật khẩu mới). Fields with helper text, primary button "Gửi yêu cầu", back to login link. Light, Vietnamese.
```
- Flow 2 bước: `POST /api/auth/forgot-password/` (3/15p/email, token TTL 30p, dùng 1 lần; dev trả token trong response) → `POST /api/auth/reset-password/` (invalidate refresh cũ) → toast → `/login`.
- Đổi mật khẩu khi đã đăng nhập: màn riêng `Đổi mật khẩu` (trong Profile) → `POST /api/auth/change-password/` (blacklist refresh cũ, password policy ≥8 ký tự + chữ + số, lỗi 400 field-level).

---

## 5. Sinh viên — 10 màn (Web + App, 1 codebase)

### 5.0. `/student` — Dashboard SV (tổng quan, Pha 10)
**Prompt:**
```
Student dashboard with sidebar (SV menu) and top bar. Greeting "Xin chào, Nguyễn Văn A — SV20210001, CNTT K66". Row of 4 stat cards: Tín chỉ đã ĐK / Lớp đang học / GPA / Học phí còn nợ. Below: weekly timetable preview (color blocks) and notifications list (unread dot). CTA buttons: "Đăng ký môn học" and "TKB tự động". Light, indigo accents, Vietnamese.
```
- Dữ liệu: `GET /api/registrations/history/`, `GET /api/timetable/my/`, `GET /api/grades/my/`, `GET /api/tuition/my/`, `GET /api/notifications/` (unread count).
- Cards lấy từ `StudentProfile.gpa`, `tin_chi_tich_luy`, Tuition `con_no`.

### 5.1. `/student/profile` — Hồ sơ SV (SV-02, Pha 1)
**Prompt:**
```
Student profile screen, two cards: left avatar + mã SV + ngành + CTĐT + khóa + GPA/tín chỉ tích lũy (read-only chips); right editable contact form (email, sđt) with Save button. Below: "Đổi mật khẩu" form (mật khẩu cũ/mới/xác nhận). Material 3, Vietnamese.
```
- `GET/PATCH /api/profiles/me/` — chỉ sửa `email`, `sdt`; trường học vụ read-only.
- App: xếp dọc 1 cột, avatar tròn lớn.

### 5.2. `/student/register` — Đăng ký môn học thủ công (SV-04/05/07/09, Pha 3, BR-01..07)
**Prompt:**
```
Course registration screen — Web: two columns (65/35). Left: search bar + filters (học kỳ, ngành, khối kiến thức, còn chỗ), scrollable course cards each with mã môn, tên, tín chỉ chip, khối, GV, sĩ số progress, lịch, button "Đăng ký" (disabled gray when full/conflict). Right: sticky cart "Giỏ đăng ký" with selected courses, remove X, total credits "Tổng: 12/24 TC" + warning banner if under minimum, primary button "Xác nhận đăng ký" (disabled when over max). App: single column with bottom sheet cart + FAB "Giỏ (3)".
Light, Vietnamese.
```
- Nguồn: `GET /api/courses/available/` (đã lọc theo CTĐT, còn chỗ, không trùng lịch hiện tại) vs `GET /api/auto-schedule/available-courses/` (không lọc — chỉ dùng cho TKB tự động).
- Mỗi `Đăng ký` → `POST /api/registrations/` **bắt buộc** `Idempotency-Key` (UUID) + `hoc_ky`, `lop_hoc_phan`. Xử lý lỗi: `NGOAI_CUA_SO_DANG_KY`/`LOP_CHUA_MO` (400), `LOP_DAY`/`TRUNG_LICH` (409), `THIEU_TIEN_QUYET`/`DA_DAT_MON` (400), `VUOT_TIN_TC_TOI_DA`/`VUOT_TIN_TC_CANH_BAO` (400), `IDEMPOTENCY_KEY_REUSED` (409).
- `warnings[]` (thiếu tối thiểu) → banner vàng trong cart, vẫn cho xác nhận.
- Hủy: `DELETE /api/registrations/{id}/` (trong cửa sổ) → hoàn học phí BR-05 → cập nhật Tuition + toast. Ngoài cửa sổ SV không tự hủy (PĐT force-cancel).
- Lịch sử: tab trong màn hoặc link tới `/student/schedule` history → `GET /api/registrations/history/` (bảng: môn, lớp, trạng thái `DA_DANG_KY`/`DA_HUY`, `cam_thi` badge, ngày ĐK, lý do hủy).
- Trạng thái: nút disable + tooltip "Lớp đã đầy"/"Trùng lịch"/"Thiếu tiên quyết".

### 5.3. `/student/auto-schedule` — TKB tự động (SV-06, Pha 8)
**Prompt:**
```
Auto-schedule screen: top multi-select chips for subjects (from CTĐT), priority toggles (buổi sáng/chiều, GV yêu thích). Middle: 3 suggestion cards (Tổ hợp 1/2/3) each showing a mini weekly grid + score badge + "Chưa trùng lịch" check. Each course row has "Chọn lớp" dropdown. Bottom: button "Xác nhận từng môn" (posts one by one). Light, Vietnamese.
```
- `AutoScheduleService` pure Dart (greedy MVP: bắt buộc theo `hoc_ky_goi_y` trước, mỗi môn chọn lớp đầu không trùng, scoring: không trùng buổi + tiết gần nhau, tối đa 3 tổ hợp). Nguồn: `GET /api/auto-schedule/available-courses/` (toàn bộ lớp mở + lịch, **không lọc trùng**).
- Mỗi xác nhận → `POST /api/registrations/` như 5.2 (chạy lại BR-01..07 server-side).

### 5.4. `/student/schedule` — Thời khóa biểu (SV-08)
**Prompt:**
```
Weekly timetable screen with week selector arrows and semester dropdown "Học kỳ 1 - 2025-2026". Color-coded weekly grid Mon-Sat columns, periods 1-15 rows (sáng 1-5, chiều 6-10, tối 11-15). Each block is a rounded card: mã môn, phòng, GV. Legend below. Toggle Week/Semester view. Light, Vietnamese.
```
- `GET /api/timetable/my/` (chung path với GV, phân giải theo role). Dữ liệu từ `Schedule` (`thu`, `buoi` dẫn xuất, `tiet_bat_dau`/`tiet_ket_thuc`, `phong`, `ngay_hoc`).
- App: swipe tuần, bottom filter học kỳ.

### 5.5. `/student/grades` — Bảng điểm (SV-11, Pha 5, BR-10/11/25)
**Prompt:**
```
Grades screen: semester dropdown filter, 3 summary cards (GPA học kỳ, GPA tích lũy, Tín chỉ tích lũy + xếp loại Xuất sắc/Giỏi/Khá…), below a table: Mã môn, Tên môn, TC, QT, GK, CK, Tổng kết, Chữ (A/B/C/D/F/P), GPA4. Pass green chip "Đạt"/"P", fail red "F". Note "* Chỉ điểm KHOA hiển thị chính thức". Light, Vietnamese.
```
- `GET /api/grades/my/` — chỉ `KHOA` là chính thức; `NHAP_TAM`/`CHINH_THUC` có thể mờ/ẩn.
- `P` (`DAT_KHONG_DAT` ≥5.0) → `gpa_thang_4 = null`, không vào GPA; `F` vẫn vào mẫu số.

### 5.6. `/student/attendance` — Điểm danh & xin sửa (SV-10, Pha 4)
**Prompt:**
```
Attendance screen: semester + class filter chips, list of sessions (Ngày, Buổi, Tiết, trạng thái CO_MAT/VANG_CO_PHEP/VANG_KHONG_PHEP + DI_TRE flag). Each row has "Xin sửa" button (if within policy). Bottom sheet form: lý do + trạng thái mong muốn (dropdown CO_MAT/VANG...). History tab shows requests CHO_DUYET/DUYET/TU_CHOI. Light, Vietnamese.
```
- `GET /api/attendance/my/` (bản ghi theo `attendance_session`), `POST /api/attendance/requests/` (kèm `trang_thai_mong_muon` + `ly_do`), `GET /api/attendance/requests/` (của mình).

### 5.7. `/student/tuition` — Học phí (SV-12, Pha 6, BR-15..17)
**Prompt:**
```
Tuition screen: summary card "Học kỳ 1 - 2025-2026" with total, paid, discount, refund, remaining + progress bar + status chip (DA_DONG/CON_NO/GIAM_TRU/CHO_HOAN_TIEN). Below: detail table (môn × tín chỉ × đơn giá) and payment history. Light, Vietnamese.
```
- `GET /api/tuition/my/` — `con_no = max(0, tong_tien - da_thu - mien_giam)`, thứ tự ưu tiên `CHO_HOAN_TIEN > CON_NO > GIAM_TRU > DA_DONG`.

### 5.8. `/student/retakes` — Đơn học lại / cải thiện (SV-14, Pha 6b, Luồng 8)
**Prompt:**
```
Retake request screen: form card (dropdown môn đã có Grade KHOA, học kỳ muốn học lại, loại HOC_LAI/HOC_CAI_THIEN, lý do textarea) + Submit. Below: table of my requests with status chips CHO_DUYET/DUYET/TU_CHOI, người duyệt, ngày duyệt. Info banner: "Cần đơn DUYET mới được đăng ký lại môn đã có điểm". Light, Vietnamese.
```
- `GET/POST /api/grade-retakes/` (SV). `DUYET` → mới được `POST /api/registrations/` với `loai_dang_ky = HOC_LAI/HOC_CAI_THIEN` (miễn BR-04 tiên quyết cho chính môn đó).

### 5.9. `/student/notifications` — Thông báo (SV-13, Pha 7)
**Prompt:**
```
Notifications screen: list of notification cards with unread blue dot, title, snippet, time, audience chip (ROLE/CLASS...). Top actions: "Đánh dấu tất cả đã đọc" + filter Chưa đọc/Đã đọc. Tap to expand full content. Light, Vietnamese.
```
- `GET /api/notifications/`, `PATCH /api/notifications/{id}/read/`, `POST /api/notifications/read-all/`.

---

## 6. Giảng viên — 6 màn (Web + App)

### 6.0. `/teacher` — Dashboard GV
**Prompt:**
```
Teacher dashboard: greeting + stats (số lớp phụ trách, số SV, buổi điểm danh tuần này, điểm chưa khóa). List of my classes as cards (mã lớp, môn, sĩ số, lịch). Shortcuts: "Điểm danh" / "Nhập điểm". Light, Vietnamese.
```
- `GET /api/class-sections/my/`, `GET /api/attendance/history/`, `GET /api/grades/` (lọc lớp mình).

### 6.1. `/teacher/profile` — Hồ sơ GV (GV-02)
- Tương tự SV profile: `ma_gv`, `khoa_bo_mon`, `hoc_vi` read-only; `email`/`sdt` editable; đổi mật khẩu.

### 6.2. `/teacher/classes` — Lớp phụ trách (GV-03/04/05, Pha 2–5)
**Prompt:**
```
My classes screen: grid/list toggle of class cards (mã lớp, môn, học kỳ, sĩ số, trạng thái KE_HOACH/MO/DANG_HOC/DA_DONG, lịch chips). Tap card → detail screen with tabs: Thông tin (môn, GV, sĩ số, ngày bắt đầu/kết thúc, han_nhap_diem) + Lịch học + Danh sách SV (mã SV, họ tên, cam_thi badge) + Xuất Excel/PDF button. Light, Vietnamese.
```
- `GET /api/class-sections/my/` + `GET /api/class-sections/{id}/` (BR-23). Nút `Xuất` → `GET /api/class-sections/{id}/export/`.
- TKB cá nhân: tab/filter trong màn hoặc route riêng dùng `GET /api/timetable/my/` (GV).

### 6.3. `/teacher/attendance` — Điểm danh (GV-06/07/08/09, Pha 4, BR-19/20/24)
**Prompt:**
```
Attendance management screen: top class + date + buổi + tiết pickers + button "Tạo buổi". Below: student table with columns Mã SV, Họ tên, Trạng thái (segmented: Có mặt / Vắng có phép / Vắng không phép) + Đi trễ switch + Ghi chú. Sticky bottom bar: "Lưu" + "Chốt buổi (DA_DIEM_DANH)". History tab: list of sessions with status MO/DA_DIEM_DANH and edit window badge "Sửa được 24h". Light, Vietnamese.
```
- `POST /api/attendance/sessions/` (chỉ khi lớp `DANG_HOC`; `UNIQUE(lop, ngay, buoi)`), `POST /api/attendance/{id}/records/`, `PATCH /api/attendance/{id}/records/` (chỉ khi session `MO` hoặc `DA_DIEM_DANH ≤24h`; không sửa khi lớp `DA_DONG`), `GET /api/attendance/history/`.
- Duyệt yêu cầu SV: `PATCH /api/attendance/requests/{id}/` (GV chỉ duyệt lớp mình).
- App: swipe giữa các SV, segmented control lớn.

### 6.4. `/teacher/grades` — Nhập điểm (GV-10, Pha 5, BR-10..14)
**Prompt:**
```
Grade entry screen: header class dropdown + search Mã SV. Table: Mã SV, Họ tên, QT (0-10 input), GK (0-10), CK (0-10), Tổng kết (auto-calculated read-only, 2 decimals), Chữ (A/B/C/D/F/P auto). Top banner warns if any SV cam_thi (CK locked, 409). Bottom sticky bar: "Lưu nháp (NHAP_TAM)" outline + "Khóa điểm (CHINH_THUC)" filled with confirm dialog. After lock, show "Mở khóa" (unlock) if within han_nhap_diem and class DANG_HOC. Light, Vietnamese.
```
- `POST /api/grades/` (GV chỉ lớp mình; `409 CAM_THI` nếu `Registration.cam_thi=true`; `409 QUA_HAN_NHAP_DIEM` nếu quá `han_nhap_diem`; `409 TRANG_THAI_KHONG_HOP_LE` nếu lớp `DA_DONG`), `PATCH /api/grades/{id}/lock/` `{action:"lock"|"unlock"}` (`unlock` chỉ `CHINH_THUC→NHAP_TAM`, trong hạn, audit log; `KHOA` bất biến).
- Preview tổng kết áp BR-10 ngay khi nhập (QT*0.1+GK*0.4+CK*0.5, fallback thiếu GK 20/80, thiếu CK NULL→0, cam_thi không fallback, làm tròn 2cs; `DAT_KHONG_DAT` → P/F).
- PĐT gia hạn: không có UI GV, nhưng hiển thị `han_nhap_diem` countdown.

### 6.5. `/teacher/notifications` — Thông báo GV (GV-11, Pha 7)
- List như SV + composer hạn chế: chỉ gửi tới `CLASS` (lớp mình) qua `POST /api/notifications/` (`audience=CLASS`, `target_refs=[classId]`). PĐT/Admin gửi rộng hơn.

---

## 7. Phòng đào tạo — 11 màn (Web only)

### 7.0. `/pdt` — Dashboard PĐT
**Prompt:**
```
PDT dashboard: stats row (số ngành, CTĐT, môn, lớp MO/DANG_HOC/DA_DONG, đăng ký kỳ này). Charts: registrations per major, class occupancy bar. Alerts: "3 lớp chưa đủ sĩ số", "2 lớp sắp hết hạn nhập điểm". Shortcuts to Majors/Semesters/Classes/Grade Sheets. Light, Vietnamese.
```

### 7.1. `/pdt/majors` — Ngành (PDT-02, Pha 2)
**Prompt:**
```
Majors management: search bar + button "+ Thêm ngành". Table: Mã ngành, Tên ngành, Thời gian đào tạo, Trạng thái chip, actions Edit/Delete. Dialog form: mã, tên, thời gian, trạng thái. Light, Vietnamese.
```
- `GET/POST/PATCH /api/majors/`.

### 7.2. `/pdt/curriculums` — CTĐT + gán môn (PDT-03, Pha 2)
**Prompt:**
```
Curriculums screen with two tabs: "CTĐT" table (Mã CTĐT, Ngành, Khóa tuyển sinh, Tổng TC yêu cầu, Trạng thái) and "Gán môn (CurriculumCourse)" table (CTĐT, Môn, Khối kiến thức dropdown (chung/cơ sở ngành/chuyên ngành/tự chọn/tốt nghiệp), Loại môn (bắt buộc/tự chọn), Học kỳ gợi ý). Add/edit dialogs, UNIQUE(ctdt, mon_hoc) validation. Light, Vietnamese.
```
- `GET/POST/PATCH /api/curriculums/` + `/api/curriculum-courses/` (khối kiến thức gán tại đây — KT-03 đọc từ đây).
- Lưu ý: `UNIQUE(nganh, khoa_tuyen_sinh) WHERE trang_thai=HOAT_DONG` (1 CTĐT hoạt động mỗi khóa).

### 7.3. `/pdt/courses` — Môn học & tiên quyết (PDT-04/05, Pha 2)
**Prompt:**
```
Courses screen: tab "Môn học" table (Mã môn, Tên, TC (tổng/LT/TH), Tiết LT/TH, Loại đánh giá DIEM/DAT_KHONG_DAT, Trạng thái) with "+ Thêm môn". Tab "Tiên quyết" graph/table (Môn → Môn tiên quyết) with "+ Thêm" and cycle validation banner. Light, Vietnamese.
```
- `GET/POST/PATCH /api/courses/` (`tong_tin_chi = LT+TH`, `NGUNG_SU_DUNG` chặn mở lớp mới), `/api/prerequisites/` (`UNIQUE(mon, tien_quyet)`, `mon≠tien_quyet`, DFS chống chu trình → 400).

### 7.4. `/pdt/semesters` — Học kỳ + cửa sổ ĐK (PDT-06/07, Pha 2, BR-01/07)
**Prompt:**
```
Semesters screen: table (Tên HK, Năm học, Ngày bắt đầu/kết thúc, Cửa sổ ĐK, 3 trần tín chỉ, Trạng thái MO/DONG chip) with actions Open/Close/Edit. Form dialog: date pickers for semester + window (window ⊂ semester), 3 number fields tin_chi_toi_thieu/toi_da/toi_da_canh_bao (nullable = fallback SystemConfig/14). Buttons "Mở HK" / "Đóng HK" / "Sửa cửa sổ". Light, Vietnamese.
```
- `GET/POST/PATCH /api/semesters/`, `POST /{id}/open/` (cần cửa sổ + 3 trần), `POST /{id}/close/` (còn lớp MO/DANG_HOC → 409), `PATCH /{id}/window/`.

### 7.5. `/pdt/classes` — Lớp HP + lịch (PDT-08/09, Pha 2, BR-08/09)
**Prompt:**
```
Class sections screen: filters by semester/course/status, table/cards (Mã lớp, Môn, HK, GV, Sĩ số hiện tại/tối đa, Ngày bắt đầu/kết thúc, han_nhap_diem, Trạng thái KE_HOACH/MO/DANG_HOC/DA_DONG, actions Open/Close/GradeDeadline). Detail drawer: class info + schedule table (Thứ, Buổi auto, Tiết bắt đầu, Số tiết/buổi, Tiết kết thúc auto, Phòng, Ngày học) with overlap validation. Buttons "Mở lớp (KE_HOACH→MO)" / "Đóng lớp (→DA_DONG)" / "Gia hạn nhập điểm". Light, Vietnamese.
```
- `GET/POST/PATCH /api/class-sections/`, `/open/` (cần lịch+sĩ số), `/close/` (mọi ĐK có Grade≥CHINH_THUC hoặc F BR-24), `/grade-deadline/` (audit log), `GET/POST/PATCH /api/schedules/` (BR-08 15 tiết/ngày, `tiet_ket_thuc` dẫn xuất, `buoi` dẫn xuất, overlap phòng+GV theo BR-03).

### 7.6. `/pdt/registrations` — Theo dõi & hủy ĐK (PDT-10/11, Pha 3, BR-05)
**Prompt:**
```
Registrations tracking: filters (HK, ngành, lớp, môn, trạng thái DA_DANG_KY/DA_HUY, cam_thi). Table: Mã SV, Họ tên, Ngành, Môn, Lớp, Ngày ĐK, cam_thi badge, actions: "Hủy (force)" with reason dialog + "Xóa cờ cấm thi" (cam_thi=false + lý do, audit log, disabled if class DA_DONG → 409). Export button "Xuất Excel/PDF". Light, Vietnamese.
```
- `GET /api/registrations/`, `DELETE /api/registrations/{id}/` (PĐT force-cancel ngoài cửa sổ → điều chỉnh học phí BR-05), `PATCH /api/registrations/{id}/` (xóa `cam_thi`).

### 7.7. `/pdt/grade-sheets` — Duyệt điểm (PDT-12, Pha 5, BR-14)
**Prompt:**
```
Grade sheets approval: class filter (chỉ lớp DA_DONG), table per class (Mã SV, Họ tên, QT/GK/CK, Tổng kết, Chữ, Trạng thái NHAP_TAM/CHINH_THUC/KHOA). Bulk action bar: "Duyệt cả lớp (CHINH_THUC→KHOA)" with confirm, shows count. After approve, trigger GPA recalc + notifications. Light, Vietnamese.
```
- `GET /api/grades/?lop_hoc_phan=`, `POST /api/grade-sheets/{lop}/approve/` (theo lớp, không duyệt lẻ).

### 7.8. `/pdt/retakes` — Duyệt đơn học lại (PDT-16, Pha 6b)
**Prompt:**
```
Retakes review: table (Mã SV, Họ tên, Môn, HK muốn học lại, Loại HOC_LAI/HOC_CAI_THIEN, Lý do, Trạng thái CHO_DUYET/DUYET/TU_CHOI, Ngày nộp). Actions: Duyệt/Từ chối with audit. Filter by status/semester. Light, Vietnamese.
```
- `GET/PATCH /api/grade-retakes/` (PĐT).

### 7.9. `/pdt/reports` — Báo cáo đào tạo (PDT-14, Pha 9)
**Prompt:**
```
Training reports: filters (HK, ngành, lớp), KPI cards (tổng SV, tổng ĐK, tỷ lệ lấp đầy), charts (bar: registrations per course, occupancy). Table drill-down. Buttons "Xuất Excel" / "Xuất PDF" (openpyxl/reportlab). Light, Vietnamese.
```
- `GET /api/reports/training/` + `/export/` (+ `GET /api/registrations/export/`).

### 7.10. `/pdt/notifications` — Gửi thông báo (PDT-13, Pha 7)
- Composer: tiêu đề, nội dung, `audience` (ROLE/MAJOR/CLASS/SEMESTER/USER) + `target_refs` multi-select, preview tệp người nhận. `POST /api/notifications/`, `DELETE /{id}/` (thu hồi).

---

## 8. Kế toán — 6 màn (Web only)

### 8.0. `/accountant` — Dashboard KT
**Prompt:**
```
Accountant dashboard: KPI cards (tổng phải thu, đã thu, còn nợ, chờ hoàn tiền), overdue alert banner, chart per semester/major. Shortcuts to Config/Tuition/Debts/Reports. Light, Vietnamese.
```

### 8.1. `/accountant/config` — Cấu hình học phí (KT-01..05, Pha 6, BR-16/17)
**Prompt:**
```
Tuition config screen: top form TuitionConfig (Học kỳ, Hạn đóng, Chính sách hoàn giảm textarea). Below: pricing table (HocPhanGia) with columns Học kỳ (nullable=Mặc định), Phạm vi (MAC_DINH/KHOI_KIEN_THUC/NGANH/LECH_LT/LECH_TH/GIA_TH), Tham chiếu (mã ngành / tên khối), Đơn giá, Hiệu lực từ, actions Edit/Delete. "+ Thêm bảng giá" dialog with validation UNIQUE(hoc_ky, pham_vi, tham_chieu) via COALESCE. Info box explains BR-16 priority (HK→NULL, khối→ngành→mặc định) and BR-17 LT/TH formulas. Light, Vietnamese.
```
- `GET/POST/PATCH /api/tuition/config/`, `/api/tuition/pricing/` (UNIQUE functional index, `don_gia≥0`, `LECH_*` là hệ số).

### 8.2. `/accountant/tuition` — Danh sách & tính học phí (KT-07/08/09, Pha 6)
**Prompt:**
```
Tuition list: filters (HK, ngành, trạng thái CHUA_TINH/DA_TINH/CON_NO/GIAM_TRU/CHO_HOAN_TIEN/DA_DONG...), search Mã SV. Table: Mã SV, Họ tên, HK, Tổng TC, Tổng tiền, Đã thu, Miễn giảm, Hoàn tiền, Còn nợ, Trạng thái chip. Row actions: "Xem chi tiết" (môn×đơn giá breakdown), "Tính lại (rebase)" (POST /calculate/), "Xác nhận thanh toán" dialog (số tiền, phương thức TIEN_MAT/CHUYEN_KHOAN/KHAC, Idempotency-Key). Top button "Tính học phí hàng loạt". Light, Vietnamese.
```
- `GET /api/tuition/`, `POST /api/tuition/calculate/` (rebase theo đơn giá hiện hành), `POST /api/tuition/payments/` (bắt buộc `Idempotency-Key`, `request_id` UNIQUE, `da_thu=Σ Payment`), `GET /api/tuition/receipts/{id}/`.

### 8.3. `/accountant/debts` — Công nợ & điều chỉnh (KT-10/11, Pha 6)
**Prompt:**
```
Debts screen: filters (quá hạn, còn nợ), table of overdue tuitions (Mã SV, HK, Còn nợ, Hạn đóng, Trạng thái). Actions: "Điều chỉnh" (tạo Discount MIEN_GIAM/GIAM_TRU/HOC_BONG/HOAN_TIEN), "Xem lịch sử Discount". Light, Vietnamese.
```
- `GET /api/tuition/debts/`, `GET/POST/PATCH /api/tuition/discounts/` (KT quyết định, audit log), `POST /api/tuition/adjustments/`.

### 8.4. `/accountant/reports` — Báo cáo tài chính (KT-13, Pha 9)
**Prompt:**
```
Finance reports: filters (HK, ngành), KPI (phải thu/đã thu/còn nợ), table per class/student, chart. Export Excel/PDF buttons. Light, Vietnamese.
```
- `GET /api/reports/finance/`.

### 8.5. `/accountant/notifications` — Thông báo KT
- Composer như PĐT, `audience` thường `USER`/`MAJOR`.

---

## 9. Admin — 7 màn (Web only)

### 9.0. `/admin` — Dashboard Admin
**Prompt:**
```
Admin dashboard: system health card (API, DB, Redis, Celery worker/beat), stats (tổng user per role, locked accounts, backup status), recent audit log snippet, quick actions to Accounts/Roles/Backups. Light, Vietnamese.
```
- `GET /api/health/`, `GET /api/admin/audit-logs/?scope=all` (recent), `GET /api/admin/backups/`.

### 9.1. `/admin/accounts` — Tài khoản (ADM-02, Pha 1)
**Prompt:**
```
User management: search + role filter + "+ Thêm người dùng" button. Table: Username, Họ tên (từ profile), Email, Vai trò chip (ADMIN/PDT/SV/GV/KT), Khoa/Ngành, Trạng thái (Active/Locked switch), actions Edit/Delete/Lock/Reset password. Dialogs: create (username, password, role), lock toggle (is_locked), reset password. Light, Vietnamese.
```
- `GET/POST/PATCH /api/users/`, `PATCH /{id}/lock/` (chặn cả token hiện có), `POST /{id}/reset-password/`. `is_locked` → `LockedAwareJWTAuthentication` chặn mọi request kể cả refresh.

### 9.2. `/admin/roles` — Phân quyền (ADM-04, Pha 1)
**Prompt:**
```
Roles & permissions: read-only list of 5 roles (ADMIN, PHONG_DAO_TAO, SINH_VIEN, GIAO_VIEN, KE_TOAN) with permission matrix table (rows=permissions, cols=roles, checkboxes). Save button "Lưu phân quyền" (PUT). Info: "Role là enum cứng, không tạo/xóa". Light, Vietnamese.
```
- `GET /api/admin/roles/` (read-only), `GET/PUT /api/admin/permissions/`.

### 9.3. `/admin/config` — Cấu hình hệ thống (ADM-05, Pha 0/1)
**Prompt:**
```
System config screen: form table (Khóa, Kiểu INT/DECIMAL/STRING/BOOL/JSON, Giá trị, Mô tả). Editable rows for tin_chi_toi_thieu/toi_da/tin_chi_toi_da_canh_bao, MAX_ABSENT_PCT, so_ngay_cho_phep_nhap_diem, pagination limits, rate limits, backup_retention_days. Save per row with validation. Light, Vietnamese.
```
- `GET/PATCH /api/admin/config/` (`SystemConfig` với `kieu`, `gia_tri` string parse theo kiểu).

### 9.4. `/admin/logs` — Audit log (ADM-06, Pha 7)
**Prompt:**
```
Audit log screen: filters (user, hành động CREATE/UPDATE/DELETE/LOGIN/PHAN_QUYEN, đối tượng, thời gian range, scope all/training/finance). Table: Thời gian, User, Hành động chip, Đối tượng, ID, Chi tiết JSON expandable, IP. Pagination. Light, Vietnamese.
```
- `GET /api/admin/audit-logs/?scope=all` (Admin) / `training` (PĐT) / `finance` (KT) — server filter theo role. `AuditLogMixin` ghi mọi ViewSet.

### 9.5. `/admin/backups` — Sao lưu / phục hồi (ADM-08, Pha 10)
**Prompt:**
```
Backups screen: top card "Tạo backup ngay" button + status. Below: history table (Thời gian, Loại create/restore, Dung lượng, Trạng thái, actions Tải/Phục hồi). Info: "pg_dump daily 02:00, giữ theo backup_retention_days". Light, Vietnamese.
```
- `GET /api/admin/backups/`, `POST /api/admin/backups/` `{action:"create"|"restore", backup_id?}`. Job `backup_daily` 02:00.

### 9.6. `/admin/notifications` — Thông báo hệ thống (ADM-07)
- Composer như PĐT nhưng `audience` có thể `ROLE` toàn hệ thống; `DELETE /api/notifications/{id}/` thu hồi (`THU_HOI`).

---

## 10. Responsive & trạng thái

### 10.1. Breakpoints (plan.md 15.4)
| Rộng | Web | App (SV/GV) |
| :--- | :--- | :--- |
| `<600px` | Drawer trượt, bảng → cards, form 1 cột | Native mobile, bottom nav |
| `600–1024px` | NavigationRail trượt | — |
| `>1024px` | Drawer cố định 240px + TopBar | — |

### 10.2. Trạng thái & ràng buộc cần thể hiện trong UI
- Nút "Đăng ký" disable xám khi `LOP_DAY`/`TRUNG_LICH`/`THIEU_TIEN_QUYET`/`DA_DAT_MON` → tooltip mã lỗi.
- Progress sĩ số: <70% xanh, 70–90% vàng, >90% đỏ.
- Vượt `tin_chi_toi_da` → nút Xác nhận disable + banner đỏ `VUOT_TIN_TC_TOI_DA`; thiếu tối thiểu → banner vàng `warnings[]`.
- `cam_thi=true` → badge đỏ, chặn nhập CK (`409 CAM_THI`) ngay từ giữa kỳ (`DANG_HOC`).
- `han_nhap_diem` countdown; quá hạn → banner `QUA_HAN_NHAP_DIEM`, nút nhập disable, hiện "Liên hệ PĐT gia hạn".
- Lớp `DA_DONG` → mọi thao tác GV điểm/điểm danh disable; PĐT xóa `cam_thi` → 409.
- Học kỳ `DONG` còn lớp `MO`/`DANG_HOC` → nút Đóng HK disable + tooltip `TRANG_THAI_KHONG_HOP_LE`.
- Rỗng: icon + "Chưa có dữ liệu" + CTA tạo mới (nếu có quyền).
- Lỗi 429 → banner "Quá nhiều yêu cầu, thử lại sau".
- `401` hết hạn → interceptor refresh; nếu refresh fail → về `/login`.

### 10.3. Xuất file
- Backend sinh file (`openpyxl`/`reportlab`), Flutter chỉ tải: `GET .../export/?format=xlsx|pdf` → download. Registry `core/export.py` `(dataset, format)→file`.

---

## 11. Checklist màn hình (đối chiếu 63 CN)

| Role | Route | CN | Pha | Web | App |
| :--- | :--- | :--- | :---: | :---: | :---: |
| SV | `/student/register` | SV-04/05/07 | 3 | ✓ | ✓ |
| SV | `/student/auto-schedule` | SV-06 | 8 | ✓ | ✓ |
| SV | `/student/schedule` | SV-08 | 3 | ✓ | ✓ |
| SV | `/student/grades` | SV-11 | 5 | ✓ | ✓ |
| SV | `/student/attendance` | SV-10 | 4 | ✓ | ✓ |
| SV | `/student/tuition` | SV-12 | 6 | ✓ | ✓ |
| SV | `/student/retakes` | SV-14 | 6b | ✓ | ✓ |
| SV | `/student/notifications` | SV-13 | 7 | ✓ | ✓ |
| SV | `/student/profile` | SV-02 | 1 | ✓ | ✓ |
| SV | `/student` | — | 10 | ✓ | ✓ |
| GV | `/teacher/classes` | GV-03/04/05 | 2 | ✓ | ✓ |
| GV | `/teacher/attendance` | GV-06/07/08/09 | 4 | ✓ | ✓ |
| GV | `/teacher/grades` | GV-10 | 5 | ✓ | ✓ |
| GV | `/teacher/notifications` | GV-11 | 7 | ✓ | ✓ |
| GV | `/teacher/profile` | GV-02 | 1 | ✓ | ✓ |
| GV | `/teacher` | — | 10 | ✓ | ✓ |
| PĐT | `/pdt/majors` | PDT-02 | 2 | ✓ | — |
| PĐT | `/pdt/curriculums` | PDT-03 | 2 | ✓ | — |
| PĐT | `/pdt/courses` | PDT-04/05 | 2 | ✓ | — |
| PĐT | `/pdt/semesters` | PDT-06/07 | 2 | ✓ | — |
| PĐT | `/pdt/classes` | PDT-08/09 | 2 | ✓ | — |
| PĐT | `/pdt/registrations` | PDT-10/11 | 3 | ✓ | — |
| PĐT | `/pdt/grade-sheets` | PDT-12 | 5 | ✓ | — |
| PĐT | `/pdt/retakes` | PDT-16 | 6b | ✓ | — |
| PĐT | `/pdt/reports` | PDT-14/15 | 9 | ✓ | — |
| PĐT | `/pdt/notifications` | PDT-13 | 7 | ✓ | — |
| PĐT | `/pdt` | — | 10 | ✓ | — |
| KT | `/accountant/config` | KT-01..05 | 6 | ✓ | — |
| KT | `/accountant/tuition` | KT-07/08/09/12 | 6 | ✓ | — |
| KT | `/accountant/debts` | KT-10/11 | 6 | ✓ | — |
| KT | `/accountant/reports` | KT-13 | 9 | ✓ | — |
| KT | `/accountant/notifications` | KT-06/14 | 7 | ✓ | — |
| KT | `/accountant` | — | 10 | ✓ | — |
| Admin | `/admin/accounts` | ADM-02/03 | 1 | ✓ | — |
| Admin | `/admin/roles` | ADM-04 | 1 | ✓ | — |
| Admin | `/admin/config` | ADM-05 | 0 | ✓ | — |
| Admin | `/admin/logs` | ADM-06 | 7 | ✓ | — |
| Admin | `/admin/backups` | ADM-08 | 10 | ✓ | — |
| Admin | `/admin/notifications` | ADM-07 | 7 | ✓ | — |
| Admin | `/admin` | ADM-01 | 10 | ✓ | — |
| Public | `/login`, `/forgot-password` | ADM-01/PDT-01/SV-01/GV-01 | 1 | ✓ | ✓ |

> **Đủ 42 route + trạng thái**, phủ 63 CN và BR-01..25. Màn nào thiếu là thiếu CN — không tự bỏ.

---

## 12. Ghi chú triển khai

- **Một codebase Flutter duy nhất** (`dang_ky_mon_hoc/`): `kIsWeb` gate cho `webOnlyRoles`; `go_router` redirect theo `UserRole`.
- **Export:** không tự vẽ PDF ở client — gọi API export, nhận file.
- **TKB tự động:** không có `/suggest` server-side; client chạy `AutoScheduleService` pure Dart sau khi `GET /auto-schedule/available-courses/`.
- **Seed data** phải nạp trước khi demo màn hình (2 ngành×8 môn×6 lớp×bảng giá×SystemConfig).
- File này là spec UI — thay đổi nghiệp vụ vẫn cập nhật `plan.md` trước, rồi đồng bộ lại đây.

