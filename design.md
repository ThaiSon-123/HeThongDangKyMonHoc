# DESIGN SPEC — Hệ thống Đăng ký Môn học

**Phiên bản:** 3.8 — khớp `plan.md` v3.8 (5 vai trò · 59 CN · BR-01..26, BR-24 đã gỡ)
**Nền tảng:** SV + GV = **Flutter Web + Flutter App (Android/iOS)**; Admin + PĐT + KT = **chỉ Flutter Web**.

> **Nguyên tắc:** UI chỉ *hiển thị và gọi API*; mọi quy tắc nghiệp vụ do backend quyết (plan.md mục 4–6).
> File này **tham chiếu** BR/endpoint/mã lỗi của plan, không định nghĩa lại. Nghiệp vụ đổi ⇒ sửa `plan.md` trước, rồi đồng bộ lại đây.
> Ký hiệu **(bổ sung)** = route/endpoint/trường chưa có trong `plan.md` nhưng design này **chốt dùng**; danh sách cần đồng bộ ngược vào plan ở mục 13.
> **Đã gỡ so với design cũ (v2.5):** `cam_thi`, đơn học lại/cải thiện (`/student/retakes`, `/pdt/retakes`), restore backup, PDF, phân quyền sửa được, `LECH_LT/LECH_TH`, `GIAM_TRU`, hoàn tiền nhiều trạng thái, `IDEMPOTENCY_KEY_REUSED`, giỏ đăng ký.

---

## 1. Design system (dùng chung)

### 1.1. Theme prompt cho Stitch / Figma Make

```
A modern, clean academic management app for a Vietnamese university course
registration system called "Đăng ký Môn học". Material 3, light mode, friendly and professional.
Primary indigo #3F51B5, secondary teal #009688, background #F5F6FA, surface white with subtle shadow,
success #2E7D32, error #C62828, warning #F9A825. Font Inter/Roboto, headings bold, body 14-16px.
Web: fixed left sidebar 240px + top bar (title, semester picker, bell with red dot, avatar + role chip).
Mobile: bottom navigation + app bar. Corner radius 12px, card padding 16px.
Tables: zebra rows, status chips, pagination. All UI text in Vietnamese.
```

### 1.2. Token

| Token | Giá trị | Dùng cho |
| :--- | :--- | :--- |
| Primary | `#3F51B5` (indigo) | Nút chính, link, mục menu active |
| Secondary | `#009688` (teal) | Nhấn phụ, progress, "đã duyệt" |
| Background / Surface | `#F5F6FA` / `#FFFFFF` | Nền trang / card, bảng, sidebar |
| Success / Error / Warning / Info | `#2E7D32` / `#C62828` / `#F9A825` / `#1565C0` | Chip, banner, toast |
| Text chính / phụ | `#212121` / `#757575` | |
| Radius | 12 (card, nút) · 8 (input) · 16 (dialog) | |
| Spacing | bội số 8px | |
| Icon | Material Symbols | |
| Touch target | ≥ 48px (bắt buộc cho App SV/GV) | |

> `lib/core/theme/app_theme.dart` hiện dùng seed `0xFF1A56DB` — **cần đổi seed về `#3F51B5` + secondary teal** để khớp file này (một nguồn token). Dark mode có sẵn qua `ColorScheme.fromSeed`; thiết kế Stitch chỉ làm light.

### 1.3. Màu chip theo trạng thái (toàn bộ enum trong plan)

| Nhóm | Giá trị → màu |
| :--- | :--- |
| Học kỳ | `MO` xanh · `DONG` xám |
| Lớp HP | `KE_HOACH` xám · `MO` xanh · `DANG_HOC` indigo · `DA_DONG` xám đậm |
| Đăng ký | `DA_DANG_KY` xanh · `DA_HUY` xám |
| Điểm | `NHAP_TAM` vàng · `CHINH_THUC` indigo · `KHOA` xanh (kèm icon khóa) |
| Điểm chữ | A,B xanh · C,D vàng · F đỏ · P xanh |
| Điểm danh | `CO_MAT` xanh · `VANG_CO_PHEP` vàng · `VANG_KHONG_PHEP` đỏ · `di_tre` chip cam nhỏ "Trễ" |
| Buổi điểm danh | `MO` vàng · `DA_DIEM_DANH` xanh |
| Yêu cầu sửa điểm danh | `CHO_DUYET` vàng · `DUYET` xanh · `TU_CHOI` đỏ |
| Học phí (`hien_thi`) | `CHUA_TINH` xám · `CON_NO` đỏ · `CHO_HOAN_TIEN` vàng · `DA_DONG` xanh · cờ phụ "Quá hạn" đỏ đậm |
| Ngành/CTĐT/Môn | `HOAT_DONG` xanh · `NGUNG`/`NGUNG_SU_DUNG` xám |
| Thông báo | `DA_GUI` xanh · `THU_HOI` xám gạch |
| Tài khoản | Hoạt động xanh · `is_locked` đỏ |
| Cờ tỷ lệ vắng (BR-20) | "Nguy cơ cấm thi" đỏ — **chỉ là nhãn cảnh báo**, không chặn thao tác nào |

### 1.4. Component dùng lại

| Component | Quy định |
| :--- | :--- |
| `StatusChip` | Bảng 1.3. |
| `DataTable` (Web) | Header `#FAFAFA`, zebra, sort, filter chips, search, phân trang mặc định 25 / tối đa 50 (`page`, `page_size`); lọc bằng `?search=&ordering=&<fk>=`. **Đây là PDT-15 "tra cứu"** — không có ô tìm kiếm toàn cục. |
| `CardList` (App & Web <600px) | Mỗi hàng bảng → 1 card; hành động trong menu `⋮`. |
| `SemesterPicker` | Mặc định theo plan 8.2: học kỳ chứa ngày hôm nay → học kỳ `MO` gần nhất → nếu API trả `400` thì hiện EmptyState "Chưa có học kỳ phù hợp". |
| `ClassCard` | Mã lớp, tên môn, tín chỉ, GV, sĩ số `x/y` + thanh (<70% xanh · 70–90% vàng · >90% đỏ), lịch `Thứ X · Tiết a–b · Phòng`. |
| `ConfirmDialog` | Tiêu đề + mô tả hậu quả + [Hủy] [Xác nhận]; thao tác không hoàn tác dùng nút đỏ; có ô `ly_do` khi plan bắt buộc (BR-05). |
| `WarningsBanner` | Hiển thị `warnings[]: {code,message}` của response thành công (vàng, đóng được) — không chặn luồng. |
| `ErrorBanner/Toast` | Hiện `message` + `code` nhỏ. Bảng mã lỗi: mục 1.6. |
| `EmptyState` · `ErrorState` · `Skeleton` | Mọi danh sách có đủ 3 trạng thái; EmptyState có CTA nếu vai trò có quyền tạo. |
| `OfflineBanner` (App) | "Đang ngoại tuyến — chỉ xem dữ liệu đã tải". Mọi nút ghi disabled khi mất mạng. |
| `AccountMenu` | Avatar ở TopBar → Hồ sơ · Đổi mật khẩu · Đăng xuất. SV/GV có trang `/…/profile`; Admin/PĐT/KT dùng **dialog** (chỉ username, vai trò, email + đổi mật khẩu) — vì plan không có route hồ sơ cho 3 vai trò này. |

### 1.5. Quy tắc tương tác bắt buộc

- **Idempotency** (plan 8.3): chỉ 2 chỗ — `POST /api/registrations/` và `POST /api/tuition/payments/`. Client sinh UUID v4 **khi mở thao tác** (dialog/lần bấm đầu), giữ nguyên khi retry/lỗi mạng, sinh mới sau khi thành công hoặc khi người dùng đổi dữ liệu. Server replay trả lại cùng kết quả → UI coi như thành công, **không** báo lỗi trùng.
- **Nút ghi** disable + spinner trong lúc chờ (chống bấm đúp).
- **Rate limit** `429 QUA_NHIEU_YEU_CAU` → banner "Thao tác quá nhanh, thử lại sau ít giây".
- **401** → interceptor refresh một lần; refresh thất bại hoặc `TAI_KHOAN_BI_KHOA` → xóa token, về `/login` kèm thông báo.
- **Sau mọi thao tác ghi thành công** → refetch danh sách/số liệu liên quan (sĩ số, tín chỉ, học phí) thay vì tự cộng trừ ở client.
- **Số tiền** hiển thị `1.234.000 ₫`; **ngày** `dd/MM/yyyy`; **giờ** theo `Asia/Ho_Chi_Minh`.

### 1.6. Mã lỗi → thông điệp UI (plan 8.4)

| Mã | HTTP | Hiển thị |
| :--- | :---: | :--- |
| `NGOAI_CUA_SO_DANG_KY` | 400 | "Ngoài thời gian đăng ký" (kèm cửa sổ của học kỳ) |
| `LOP_CHUA_MO` | 400 | "Lớp chưa mở đăng ký" |
| `THIEU_TIEN_QUYET` | 400 | "Chưa đạt môn tiên quyết" |
| `DA_DAT_MON` | 400 | "Bạn đã đạt môn này" |
| `VUOT_TIN_TC_TOI_DA` / `VUOT_TIN_TC_CANH_BAO` | 400 | "Vượt số tín chỉ tối đa" / "Diện cảnh báo học vụ: tối đa N tín chỉ" |
| `CHUA_CAU_HINH_GIA` | 400 | Ở màn KT (`calculate`): lỗi + link tới cấu hình giá. Ở luồng đăng ký: **warning**, không phải lỗi |
| `SO_TIEN_KHONG_HOP_LE` | 400 | "Số tiền vượt công nợ/số cần hoàn" |
| `LOP_DAY` | 409 | "Lớp vừa hết chỗ" → refetch danh sách |
| `TRUNG_LICH` | 409 | "Trùng lịch với lớp đã đăng ký" |
| `DA_DANG_KY` | 409 | "Bạn đã đăng ký lớp này" |
| `DA_DANG_KY_MON` | 409 | "Bạn đã đăng ký một lớp khác của môn này — hủy lớp đó trước khi đổi lớp" |
| `QUA_HAN_NHAP_DIEM` | 409 | "Đã quá hạn nhập điểm — liên hệ PĐT gia hạn" |
| `TRANG_THAI_KHONG_HOP_LE` | 409 | Nêu rõ trạng thái hiện tại (vd "Còn lớp đang mở/đang học nên chưa đóng được học kỳ") |
| `KHONG_CO_QUYEN` | 403 | "Bạn không có quyền thực hiện" |
| `TAI_KHOAN_BI_KHOA` | 403 | "Tài khoản đã bị khóa — liên hệ quản trị" |
| `QUA_NHIEU_YEU_CAU` | 429 | Banner rate-limit |

Lỗi field DRF `{"field": ["…"]}` → hiện ngay dưới ô nhập tương ứng.

### 1.7. Chọn tuần tự (cascading) — bắt buộc cho mọi màn tác nghiệp

Dữ liệu con **chỉ xuất hiện sau khi đã chọn đủ cha**. Quy tắc chung:

1. Ô chọn phụ thuộc bị **disable** + placeholder "Chọn <cha> trước" cho tới khi cha có giá trị. Vùng nội dung hiện `EmptyState` hướng dẫn (vd "Chọn học kỳ và lớp để xem điểm danh") — **không** hiện bảng rỗng, **không** tải trước dữ liệu con.
2. Chỉ gọi API chi tiết **sau khi** đủ lựa chọn (không tải sẵn toàn bộ SV/buổi/điểm của mọi lớp).
3. Đổi lựa chọn cha ⇒ **xóa** lựa chọn con và nội dung con. Nếu đang có thay đổi chưa lưu (điểm danh, điểm) ⇒ `ConfirmDialog` "Bỏ các thay đổi chưa lưu?".
4. Ô con chỉ liệt kê **giá trị hợp lệ theo cha** (vd lớp của đúng học kỳ đã chọn, và chỉ lớp liên quan tới chính người dùng).
5. Chỉ `SemesterPicker` có giá trị mặc định (mục 1.4). **Lớp / buổi không tự chọn mặc định**, trừ khi chỉ có đúng một lựa chọn hợp lệ.
6. Lựa chọn nằm trên URL query (`?hoc_ky=&lop=&buoi=`) để tải lại trang / nút Back giữ nguyên trạng thái.
7. **Web:** các cấp nằm cùng một trang (master–detail, cấp sau hiện bên phải/bên dưới). **App:** mỗi cấp là một màn (push), nút Back về cấp trước.

| Màn | Chuỗi chọn → thứ hiện ra ở mỗi bước |
| :--- | :--- |
| SV `/student/attendance` | Học kỳ → **Lớp** (chỉ lớp mình đã đăng ký trong học kỳ đó) → *thống kê lớp* + *danh sách buổi* + *yêu cầu của tôi* → chọn một buổi → *chi tiết buổi / Xin sửa* |
| SV `/student/grades` | Học kỳ (mặc định "Tất cả") → bảng điểm + GPA của phạm vi đó |
| SV `/student/tuition`, `/student/schedule` | Học kỳ → tổng hợp học phí / lưới TKB |
| SV `/student/register` | Học kỳ (cố định: học kỳ `MO` hiện hành) → lớp đang mở |
| GV `/teacher/attendance` | **Lớp** → *danh sách buổi sinh sẵn theo lịch* → chọn một buổi đã đến ngày → *danh sách SV để điểm danh* |
| GV `/teacher/grades` | **Lớp** → lưới nhập điểm cả lớp |
| GV soạn thông báo | `audience = CLASS` → chọn lớp mình |
| PĐT `/pdt/grade-sheets` | Học kỳ → danh sách lớp → chọn lớp → bảng điểm + hành động (Duyệt / Gia hạn / Nhập hộ) |
| PĐT `/pdt/registrations` | Học kỳ → (ngành, lớp lọc theo học kỳ đó) → bảng đăng ký |
| PĐT `/pdt/curriculums` tab Môn | Chọn CTĐT → bảng môn của CTĐT |
| PĐT `/pdt/courses` tab Tiên quyết | Chọn môn → danh sách tiên quyết |
| PĐT `/pdt/profiles` (tạo SV) | Ngành + khóa nhập học → danh sách CTĐT khớp để chọn |
| KT `/accountant/config` | Học kỳ (tab Hạn đóng) · Phạm vi → ô Tham chiếu (ngành / khối) |
| KT `/accountant/tuition`, `/debts`, `/reports` | Học kỳ → bảng → chọn SV → drawer chi tiết / dialog thu–hoàn |
| Form soạn thông báo | `audience` → ô người nhận tương ứng (vai trò / lớp / người dùng) |

### 1.8. Phong cách giao diện (Navy + cam) — áp dụng cho Web và App

Tham chiếu: ảnh màn Thời khóa biểu sinh viên (header navy bo góc, thẻ bo tròn, thanh dưới nổi). Quy tắc dưới đây **thay** các màu/layout tương ứng ở 1.1–1.2 khi khác nhau; logic và nội dung màn hình không đổi.

| Thành phần | Quy định |
| :--- | :--- |
| Màu | Navy header `#1F2A5C → #2C3A7A` (gradient 160°) · nền trang `#F4F5FA` · thẻ trắng · **nút chính vẫn indigo `#3F51B5`** · **điểm nhấn cam `#D9480F`** (nhãn "Hôm nay", ngày hôm nay, avatar, chấm thông báo); nền cam nhạt `#FFF1E6` + chữ `#9A3412` |
| Màu theo môn | Mỗi lớp một cặp pastel + vạch trái: indigo `#E8EAF6/#2C3A7A`, xanh `#E6F4EA/#1B6E3A`, tím `#F3E5F5/#6A1B9A`, cam `#FFF1E6/#9A3412`, xám `#ECEFF1/#37474F`. Tên lớp luôn kèm mã lớp để không chỉ dựa vào màu |
| Thẻ | Bo 16, không viền, bóng nhẹ `0 2px 10px rgba(31,42,92,.08)`; input vẫn viền 1px `#9AA1B2` bo 8–12 |
| **App — header** | Khối navy bo đáy 28: hàng trên gồm ô logo trắng "ĐK" + học kỳ, chuông (chấm cam khi có tin) và avatar cam (bấm vào Hồ sơ); dưới là tiêu đề 28px bold + dòng phụ (khoảng tuần, số lớp…); có thể thêm dải nút "pill". Màn cấp sâu dùng header gọn: nút Back + tiêu đề + dòng phụ |
| **App — thanh dưới** | Thanh trắng **nổi** (cách mép 16px, bo 34, bóng nhẹ) gồm 5 mục **đều nhau**, không có nút nổi. **Mục đang chọn** là một viên thuốc navy bo tròn chứa icon + nhãn **trắng** (nền gradient navy, bóng nhẹ); mục còn lại icon + nhãn xám `#6B7280`, không nền. Giáo viên: Tổng quan · Lớp · Điểm danh · TKB · Nhập điểm. Sinh viên: Trang chủ · Đăng ký · TKB · Học phí · Hồ sơ. Chỉ hiện ở các màn cấp 1, ẩn ở màn cấp sâu |
| **Web — khung** | **Sidebar navy rộng 260px, chia nhóm có tiêu đề in hoa** (Tổng quan / Giảng dạy / Học vụ / Khác; tiêu đề nhóm và dòng phụ của thương hiệu **không gắn học kỳ hay năm học** — học kỳ chỉ hiện ở `SemesterPicker` của từng màn): khối thương hiệu ở đầu (logo + tên + dòng phụ), mục đang chọn tô **đặc** indigo `#3F51B5` kèm bóng, huy hiệu số cam cho Thông báo chưa đọc, mục **Đăng xuất** trong nhóm Khác, và **khối người dùng ghim đáy** (avatar cam, họ tên, mã · vai trò, nút đăng xuất). Phần nội dung: tiêu đề trang 28px màu navy + dòng phụ, chuông thông báo nền trắng ở góc phải (không lặp lại avatar vì đã có ở sidebar); thẻ như trên. **Giữ sidebar**, không dùng thanh dưới trên Web |
| Bố cục nội dung Web | Nội dung trang **trải hết chiều ngang** vùng bên phải sidebar — không đặt `max-width` làm trống một nửa trang; danh sách/bảng dài full width, form dài chia 2 cột hoặc lưới tự co (`auto-fit`) |
| Chip trạng thái | Giữ bảng màu 1.3; nền nhạt + chữ đậm ≥ 11px (App) / 12px (Web) |
| Truy cập | Chữ trên nền cam/navy phải đạt 4.5:1; không dùng chữ trắng trên cam `#F57C00` hay sáng hơn; mục thanh dưới ≥ 48px |

**Màn Thời khóa biểu (GV-05, SV-08) — xem theo tuần có ngày thật.** Vì buổi học đã sinh sẵn theo ngày (plan BR-20), TKB hiện **ngày cụ thể**: nút *‹ Tuần trước · Tuần này · Cả học kỳ · Tuần sau ›*; mỗi ngày có tiết là một nhóm "Thứ 7 · 10/10" (nhãn **HÔM NAY** màu cam) gồm các thẻ có bong bóng ngày (T7 / 10), khối màu theo môn (tên, mã lớp · phòng · sĩ số, **Tiết 1–3 · Sáng**) và lối tắt **Điểm danh ›** nếu buổi đã đến ngày (buổi tương lai ghi "Chưa tới ngày điểm danh"). Chế độ *Cả học kỳ* hiện lịch lặp theo thứ ("Thứ 3 · mỗi tuần"). Giờ đồng hồ **không hiển thị** vì plan chưa có bảng đổi tiết sang giờ; muốn hiện giờ cần thêm bảng này vào cấu hình hệ thống. **Web:** lưới 7 cột (Thứ 2 → Chủ nhật) × 15 tiết. Cột trái là nhãn **"Tiết 1…15"** nền navy; **không có cột giờ, không có cột bên phải**. Tiêu đề cột ghi *Thứ + ngày* (vd "Thứ 5 (08/10)"); chuyển tuần bằng thanh bộ lọc phía trên; cột hôm nay tô cam nhạt. Mỗi khối môn trải đúng các tiết của buổi học và hiện: **Tên môn (LT+TH) (Mã môn)** · **Nhóm:** mã lớp học phần · **Phòng:** · **Sĩ số:** (bản giáo viên; **bản sinh viên thay dòng Sĩ số bằng `GV: <tên giáo viên>`** vì giáo viên luôn là chính người xem). Lưới chiếm toàn bộ chiều rộng, **không có panel chi tiết** — mọi thông tin cần xem đã nằm trong khối. **In được:** nút **"In thời khóa biểu"** ở thanh bộ lọc gọi `window.print()`; khi in chỉ còn tiêu đề (tên giáo viên, khoảng tuần/học kỳ), chú giải màu và lưới — ẩn sidebar, thanh bộ lọc và panel chi tiết; khổ A4 ngang, giữ màu nền. Không cần API. Bản App không có nút in. Học kỳ đã kết thúc chỉ xem được chế độ Cả học kỳ.

---

## 2. Điều hướng, nền tảng & responsive

### 2.1. Nền tảng & entrypoint

| Vai trò | Web (`lib/main.dart`) | App (`lib/main_app.dart`) |
| :--- | :---: | :---: |
| Admin · PĐT · KT | ✓ | ✗ — đăng nhập ở App → màn `/web-only` ("Vai trò này chỉ dùng trên trình duyệt") + nút Đăng xuất |
| SV · GV | ✓ | ✓ |
| Public (`/login`, `/forgot-password`) | ✓ | ✓ |

Bản App **không import** `routes_admin/pdt/accountant` (plan 10.2). Guard: chưa đăng nhập → `/login`; sai vai trò → `homePath` của vai trò.

### 2.2. Breakpoint

| Bề rộng | Web | App |
| :--- | :--- | :--- |
| < 600px | AppBar + Drawer trượt; bảng → `CardList`; form 1 cột | Luôn dạng này |
| 600–1024px | `NavigationRail` | (tablet: NavigationRail) |
| > 1024px | Sidebar cố định 240px + TopBar | — |

### 2.3. Menu theo vai trò (Web sidebar)

| Vai trò | Mục menu (theo thứ tự) |
| :--- | :--- |
| **SV** | Tổng quan · Đăng ký môn · TKB tự động · Thời khóa biểu · CTĐT *(bổ sung)* · Điểm · Điểm danh · Học phí · Thông báo · Hồ sơ |
| **GV** | Tổng quan · Lớp phụ trách · Điểm danh · Nhập điểm · Thông báo · Hồ sơ |
| **PĐT** | Tổng quan · Hồ sơ SV/GV *(bổ sung)* · Khoa / viện *(bổ sung)* · Ngành · CTĐT · Môn học · Học kỳ · Lớp học phần · Đăng ký · Duyệt điểm · Báo cáo · Thông báo · Nhật ký *(bổ sung)* |
| **KT** | Tổng quan · Cấu hình học phí · Học phí · Công nợ · Báo cáo · Thông báo · Nhật ký *(bổ sung)* |
| **Admin** | Tổng quan · Tài khoản · Ma trận quyền · Cấu hình · Audit log · Sao lưu · Thông báo |

### 2.4. Điều hướng App

| Vai trò | Bottom nav | Truy cập khác |
| :--- | :--- | :--- |
| **SV** (5 tab) | Trang chủ · Đăng ký · TKB · Học phí · Hồ sơ | Điểm, Điểm danh, CTĐT, TKB tự động và Thông báo mở từ **Trang chủ** (lối tắt) hoặc chuông ở header; Hồ sơ mở bằng avatar |
| **GV** (4 tab) | Tổng quan · Lớp · Điểm danh · Nhập điểm | Chuông 🔔 (Thông báo), avatar (Hồ sơ, Đăng xuất) |

### 2.5. Route map (khớp plan 10.3)

| Vai trò | Route | CN | Web | App |
| :--- | :--- | :--- | :---: | :---: |
| Public | `/login`, `/forgot-password` | SV/GV/PDT/KT/ADM-01 | ✓ | ✓ |
| Admin | `/admin` · `/admin/accounts` · `/admin/permissions` · `/admin/config` · `/admin/logs` · `/admin/backups` · `/admin/notifications` | ADM-02..08 | ✓ | — |
| PĐT | `/pdt` · `/pdt/majors` · `/pdt/curriculums` · `/pdt/courses` · `/pdt/semesters` · `/pdt/classes` · `/pdt/registrations` · `/pdt/grade-sheets` · `/pdt/reports` · `/pdt/notifications` | PDT-02..14 | ✓ | — |
| | **(bổ sung)** `/pdt/profiles` · `/pdt/faculties` · `/pdt/logs` | PDT-01 · PDT-02 · ADM-06 | ✓ | — |
| SV | `/student` · `/student/profile` · `/student/register` · `/student/auto-schedule` · `/student/schedule` · `/student/grades` · `/student/attendance` · `/student/tuition` · `/student/notifications` | SV-02..13 | ✓ | ✓ |
| | **(bổ sung)** `/student/curriculum` · `/student/tuition/pay` | SV-03 · SV-12 | ✓ | ✓ |
| GV | `/teacher` · `/teacher/profile` · `/teacher/classes` · `/teacher/attendance` · `/teacher/grades` · `/teacher/notifications` | GV-02..12 | ✓ | ✓ |
| | **(bổ sung)** `/teacher/schedule` | GV-05 | ✓ | ✓ |
| KT | `/accountant` · `/accountant/config` · `/accountant/tuition` · `/accountant/debts` · `/accountant/reports` · `/accountant/notifications` | KT-01..11 | ✓ | — |
| | **(bổ sung)** `/accountant/logs` | ADM-06 | ✓ | — |

Tổng: 40 route theo plan + 4 route bổ sung. Lý do: matrix mục 9 cho PĐT sửa hồ sơ (PDT-01), SV xem CTĐT (SV-03), PĐT/KT xem audit (ADM-06) nhưng plan 10.3 chưa có route. `/pdt/logs` và `/accountant/logs` dùng chung widget `AuditLogScreen` với `scope` cố định (`training` / `finance`) — server vẫn tự lọc theo vai trò.

---

## 3. Vòng đời học kỳ — màn nào hoạt động khi nào

UI phải khớp thứ tự này, tránh để người dùng thấy nút dùng được nhưng bị 409.

| Giai đoạn | Điều kiện hệ thống | Ai làm gì (màn) |
| :--- | :--- | :--- |
| **Chuẩn bị** | Học kỳ chưa mở; lớp `KE_HOACH` | PĐT: ngành → CTĐT → môn + tiên quyết → gán môn vào CTĐT → học kỳ + cửa sổ ĐK → lớp + lịch. PĐT tạo hồ sơ SV/GV (gán `ctdt`). KT: cấu hình giá + hạn đóng. Admin: tạo tài khoản trước hồ sơ |
| **Mở đăng ký** | PĐT bấm *Mở học kỳ* (cần cửa sổ ĐK) rồi *Mở lớp* (có GV, sĩ số, ≥1 lịch) | SV: đăng ký/hủy **chỉ khi** học kỳ `MO` + trong cửa sổ + lớp `MO` (BR-01, BR-05). PĐT: theo dõi, hủy hộ |
| **Đang học** | Job 00:05 chuyển lớp `MO` → `DANG_HOC` khi qua `ngay_bat_dau` | GV: điểm danh, nhập điểm. SV: xem điểm danh, xin sửa. PĐT: vẫn hủy hộ được. KT: thu tiền bất kỳ lúc nào |
| **Nhập & khóa điểm** | Lớp `DANG_HOC`, trong `han_nhap_diem` (BR-13) | GV nhập `NHAP_TAM` → khóa `CHINH_THUC` (mở khóa được nếu còn hạn). Quá hạn → PĐT gia hạn / nhập hộ |
| **Đóng lớp** | Qua `ngay_ket_thuc` **và** mọi SV `DA_DANG_KY` có điểm ≥ `CHINH_THUC` | Job tự đóng hoặc PĐT bấm *Đóng lớp* → `DA_DONG`. Điểm danh/nhập điểm bị khóa |
| **Duyệt điểm** | Lớp `DA_DONG` | PĐT duyệt cả lớp `CHINH_THUC` → `KHOA` → cập nhật GPA/tín chỉ tích lũy, thông báo SV. SV **chỉ thấy điểm `KHOA`** |
| **Đóng học kỳ** | Không còn lớp `MO`/`DANG_HOC` | PĐT bấm *Đóng học kỳ* |

Học phí **độc lập** với vòng đời lớp (không chặn đóng lớp, không phụ thuộc trạng thái lớp).

---

## 4. Màn hình chung (Web + App)

### 4.1. `/login` — Đăng nhập
**Prompt:**
```
Login screen. Web: two columns — left indigo gradient panel with logo, "Đăng ký Môn học" and a short tagline; right white card with fields "Tên đăng nhập", "Mật khẩu" (eye toggle), primary button "Đăng nhập", link "Quên mật khẩu?". Mobile: single column, logo on top, card full width. Vietnamese, Material 3.
```
- `POST /api/auth/login/`. Rate limit **10/phút/IP** (không khóa theo tài khoản) → `429` thì banner.
- Lỗi: sai thông tin → thông báo chung (không nói sai ô nào); `TAI_KHOAN_BI_KHOA` → banner đỏ "Tài khoản đã bị khóa".
- Thành công → lưu token bằng `flutter_secure_storage` (access 60 phút, refresh 7 ngày) → chuyển `homePath` theo vai trò. App + vai trò Admin/PĐT/KT → `/web-only`.

### 4.2. `/forgot-password` — Quên & đặt lại mật khẩu
- **Bước 1 — Nhập email:** `POST /api/auth/forgot-password/` (3 lần/15 phút/email). **Luôn hiện cùng một thông điệp** "Nếu email tồn tại, chúng tôi đã gửi hướng dẫn" — UI không được tiết lộ email có tồn tại hay không.
- **Bước 2 — Nhập token + mật khẩu mới + xác nhận:** `POST /api/auth/reset-password/`. Token sống 30 phút, dùng 1 lần; hết hạn/sai → lỗi field. Ở dev, response có token → tự điền sẵn (ẩn ở prod: `PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE=False`).
- Chính sách mật khẩu hiển thị dưới ô nhập: ≥ 8 ký tự, có chữ và số. Thành công → toast → `/login`.

### 4.3. Đổi mật khẩu (trong Hồ sơ / AccountMenu)
`POST /api/auth/change-password/` (mật khẩu cũ, mới, xác nhận). Server blacklist refresh cũ ⇒ sau khi thành công **đăng xuất và yêu cầu đăng nhập lại** (đơn giản, an toàn).

### 4.4. Thông báo (dùng chung cho 5 vai trò — nhận)
Route: `/student/notifications`, `/teacher/notifications`, `/pdt/notifications`, `/accountant/notifications`, `/admin/notifications`; mỗi vai trò thêm **form soạn** theo quyền (xem từng vai trò). Danh sách nhận giống nhau:

**Prompt:**
```
Notifications list: cards with unread blue dot, title, 2-line snippet, sender and time. Top: segmented filter Tất cả / Chưa đọc and button "Đánh dấu tất cả đã đọc". Tap card to expand full content. Mobile: full-screen list, pull to refresh.
```
- `GET /api/notifications/` · `PATCH /api/notifications/{id}/read/` · `POST /api/notifications/read-all/`. Thông báo `THU_HOI` biến khỏi danh sách người nhận.
- Chuông ở TopBar/AppBar: chấm đỏ khi có chưa đọc; refetch khi mở app và mỗi 60 giây khi tab đang mở (không dùng websocket).
- **Thông báo tự động** người dùng sẽ gặp (plan 7.6): đăng ký/hủy thành công (SV) · lớp đổi lịch/phòng/hủy (cả lớp) · điểm mới `KHOA` (SV) · học phí quá hạn (SV + KT).

**Form soạn (vai trò được phép gửi):**

| Vai trò | `audience` được chọn | Người nhận chọn |
| :--- | :--- | :--- |
| Admin | `ROLE` · `CLASS` · `USER` | Vai trò (đa chọn) / lớp / tìm theo mã |
| PĐT | `ROLE` · `CLASS` · `USER` | như trên |
| KT | `ROLE` · `CLASS` · `USER` | như trên |
| GV | **chỉ `CLASS`** (lớp mình phụ trách) | Chọn lớp của mình (đa chọn) |
| SV | — không có form | — |

Form: tiêu đề, nội dung, chọn `audience` → trường `target_refs` tương ứng, không có dòng đếm số người nhận (plan không có endpoint). `POST /api/notifications/`. Tab "Đã gửi" liệt kê thông báo mình gửi, nút **Thu hồi** (`DELETE`, chỉ Admin hoặc chính người gửi) có `ConfirmDialog`.

---

## 5. SINH VIÊN — Web + App (9 route + 1 bổ sung)

Quy ước SV: chỉ thấy dữ liệu của mình (BR-23). Mọi màn có `SemesterPicker` nếu dữ liệu theo học kỳ. App SV: 1 cột, bottom nav (mục 2.4), `Skeleton` khi tải.

### 5.0. `/student` — Tổng quan (SV-02 dữ liệu tóm tắt)

| | Web (>1024px) | App |
| :--- | :--- | :--- |
| Bố cục | Lời chào + 4 thẻ số liệu (hàng ngang) · cột trái: *Hôm nay học gì* (TKB hôm nay) · cột phải: thông báo mới nhất | 1 cột: lời chào → 4 thẻ cuộn ngang → "Hôm nay" → thông báo → 2 nút lớn "Đăng ký môn" |

Thẻ: **Tín chỉ đã đăng ký** (học kỳ này) · **GPA tích lũy / Tín chỉ tích lũy** (`profiles/me`; `gpa=NULL` → "Chưa có") · **Cảnh báo** (có môn nguy cơ cấm thi — BR-20) · **Còn nợ** (`con_no`, đỏ nếu quá hạn; vàng "Chờ hoàn tiền" nếu `can_hoan>0`).

Dữ liệu: `profiles/me`, `registrations/history`, `timetable/my`, `tuition/my`, `attendance/my`, `notifications`. Hôm nay = lịch có `thu` trùng thứ hôm nay (CN = 8).

**Prompt:**
```
Student dashboard. Greeting "Xin chào, <tên> — <mã SV>, <ngành>". Four stat cards: "Tín chỉ đã đăng ký", "GPA tích lũy", "Cảnh báo vắng", "Học phí còn nợ". Below: "Hôm nay" list of today's classes (time, mã lớp, môn, phòng) and a "Thông báo mới" list. Primary buttons "Đăng ký môn học". Indigo accents, Vietnamese. Mobile variant: single column, horizontally scrolling stat cards.
```

### 5.1. `/student/profile` — Hồ sơ (SV-02)
- Khối chỉ đọc: mã SV, họ tên, ngành, khóa nhập học, **CTĐT**, GPA, tín chỉ tích lũy, xếp loại học lực (BR-25f: Xuất sắc 3.60–4.00 · Giỏi 3.20–3.59 · Khá 2.50–3.19 · TB 2.00–2.49 · Yếu 1.00–1.99 · Kém <1.00).
- Khối sửa được: **chỉ `email`, `sdt`** (`PATCH /api/profiles/me/`). Trường học vụ bị khóa kèm tooltip "Liên hệ Phòng đào tạo".
- Khối đổi mật khẩu (mục 4.3).
- App: avatar tròn lớn trên cùng, các khối xếp dọc; nút Đăng xuất cuối trang.

### 5.2. `/student/curriculum` *(bổ sung)* — Chương trình đào tạo (SV-03)
- `GET /api/curriculums/my/`. Hiển thị **theo từng học kỳ gợi ý** (`hoc_ky_goi_y`): mỗi học kỳ một khối "Học kỳ n · Năm học YYYY–YYYY" (năm học tính từ khóa nhập học), dòng phụ "x môn · y tín chỉ · z bắt buộc · w tự chọn", học kỳ đang học có nhãn "Học kỳ hiện tại". Bảng: **Mã môn · Tên môn (kèm "Tiên quyết: …") · TC · Khối kiến thức (chip) · Loại (Bắt buộc/Tự chọn) · Điểm · Trạng thái**.
- Trạng thái cá nhân: **Đã đạt** / **Chưa đạt (F)** / **Đang học** / **Chưa học** (suy từ `grades/my` và đăng ký hiện tại). Cột Điểm hiện tổng kết (hoặc `P`), `—` nếu chưa có điểm chính thức. Bộ lọc theo trạng thái ẩn học kỳ không còn môn phù hợp.
- Đầu trang: thẻ tiến độ `tín chỉ đã đạt / tong_tin_chi_yeu_cau` (thanh progress), 4 thẻ số liệu (tổng số môn · tín chỉ đã đạt · môn đã đạt · đang học) và khối **"Phân bổ theo khối kiến thức"** (5 khối: Chung · Cơ sở ngành · Chuyên ngành · Tự chọn · Tốt nghiệp, mỗi khối `đã đạt / tổng` tín chỉ).
- App: cùng cấu trúc, mỗi môn là một thẻ (điểm + trạng thái bên phải, chip khối và loại bên dưới), phân bổ khối cuộn ngang.

### 5.3. `/student/register` — Đăng ký môn học (SV-04, 05, 07, 09)

**Ba tab:** *Lớp đang mở* · *Đã đăng ký* · *Lịch sử*.

**Thanh trạng thái trên cùng** (dính khi cuộn): học kỳ + cửa sổ đăng ký ("Còn 3 ngày" / "Đã đóng") · **Tín chỉ: `X` đã đăng ký** (kèm "/ tối đa" lấy từ `meta.tin_chi_toi_da` của `/api/courses/available/`, mục 13) · cảnh báo diện học vụ nếu `gpa < 2.0` (giới hạn thấp hơn, BR-07).

**Tab 1 — Lớp đang mở** (`GET /api/courses/available/`)
- Server **đã lọc**: đúng CTĐT, còn chỗ, không trùng lịch với lớp đã đăng ký ⇒ client **không** tự lọc lại. Vì vậy lỗi `LOP_DAY` / `TRUNG_LICH` chỉ xảy ra khi tranh chấp (người khác đăng ký trước) → toast lỗi + **refetch danh sách**.
- **Gom nhóm theo môn:** danh sách là các **dòng môn có thể mở rộng** (chevron `›`, mã học phần dạng mono, tên môn, chip TC · Bắt buộc/Tự chọn · khối kiến thức, và số lớp đang mở). Bấm vào môn để xổ ra **các lớp học phần** của môn đó — mỗi lớp là một dòng/thẻ gồm *mã lớp · giáo viên · lịch học · phòng · sĩ số (thanh) · nút Đăng ký*. Client gom từ danh sách lớp của `/api/courses/available/` theo `mon_hoc`. Mặc định mở sẵn môn đầu tiên. Tiêu đề phụ: "x môn · y lớp học phần đang mở".
- **Một môn một lớp:** sau khi đăng ký một lớp, cả môn đó rời khỏi tab *Lớp đang mở* (không hiện các lớp còn lại của môn); hủy lớp thì môn quay lại. Backend chặn thật bằng BR-04(d): lỗi `DA_DANG_KY_MON` (409) khi tranh chấp/đăng ký từ nơi khác → toast + refetch.
- Bộ lọc: tìm theo mã/tên, bắt buộc/tự chọn (Web có thêm khối kiến thức, ngày học) và **bộ lọc theo CTĐT** (client ghép `GET /api/curriculums/my/`, không thêm endpoint):
  - *Bộ lọc môn* (hai nút chọn một **Tất cả môn đang mở** / **Theo CTĐT**, cộng nút bật-tắt **Môn chưa học** — dùng **kết hợp** được, ví dụ "Theo CTĐT" + kỳ 8 + "Môn chưa học"; "chưa học" = chưa có điểm trong bảng điểm, môn **học lại** không tính). **Theo CTĐT** (sắp xếp tăng dần theo `hoc_ky_goi_y`, mỗi môn có chip "Kỳ n · HKx năm học"; môn học lại có chip "Học lại").
  - *Kỳ trong chương trình đào tạo* (dropdown): "Tất cả các kỳ" + 8 kỳ của CTĐT, ví dụ "Kỳ 1 · HK1 2023–2024" … "Kỳ 8 · HK2 2026–2027 · kỳ đang đăng ký", kèm số môn đang mở của kỳ đó. **Chỉ bật khi chọn "Theo CTĐT"** (chọn tuần tự, mục 1.7); chọn lại phạm vi thì kỳ về "Tất cả".
- Mỗi lớp trong môn đã mở rộng có nút **Đăng ký** → `POST /api/registrations/` (`Idempotency-Key`). **Bấm là đăng ký ngay** — *không có giỏ hàng*, vì chỗ chỉ được giữ khi POST thành công (BR-06); giỏ sẽ tạo cảm giác "đã giữ chỗ" sai. Gộp nhiều môn một lượt là việc của `/student/auto-schedule`.
- Sau 201: toast thành công; nếu `warnings[]` → `WarningsBanner` (vd dưới tín chỉ tối thiểu BR-07, hoặc `CHUA_CAU_HINH_GIA` "Học phí chưa được tính"); lớp chuyển sang tab "Đã đăng ký".
- Lỗi theo mục 1.6. `NGOAI_CUA_SO_DANG_KY`/`LOP_CHUA_MO` → khóa toàn bộ nút Đăng ký + banner giải thích.

**Tab 2 — Đã đăng ký** (`registrations/history`, lọc `DA_DANG_KY` của học kỳ chọn)
- Danh sách lớp + tổng tín chỉ. Nút **Hủy** (`DELETE /api/registrations/{id}/`) **chỉ khi** lớp `MO` **và** trong cửa sổ đăng ký (BR-05); ngược lại nút bị ẩn, thay bằng ghi chú "Liên hệ Phòng đào tạo để hủy".
- `ConfirmDialog`: "Hủy đăng ký <môn>? Học phí sẽ được tính lại." Sau hủy → refetch sĩ số/tín chỉ/học phí.

**Tab 3 — Lịch sử** (SV-09): bảng mọi bản ghi: môn, lớp, học kỳ, trạng thái `DA_DANG_KY`/`DA_HUY`, ngày đăng ký, ngày hủy, **lý do hủy** (nếu PĐT hủy hộ thì thấy lý do PĐT ghi).

| | Web | App |
| :--- | :--- | :--- |
| Tab 1 | Lưới 2–3 cột `ClassCard`; bộ lọc ở thanh trên | 1 cột; bộ lọc trong bottom sheet; nút Đăng ký full-width 48px |
| Tab 2/3 | Bảng | `CardList` |

**Prompt (Web):**
```
Course registration screen with three tabs: "Lớp đang mở", "Đã đăng ký", "Lịch sử". Sticky status bar: semester name, registration window countdown chip, total registered credits. Tab 1: filter row (search, khối kiến thức, bắt buộc/tự chọn, thứ) and a grid of class cards: mã lớp, tên môn, tín chỉ chip, bắt buộc/tự chọn chip, GV, sĩ số progress bar (x/y), schedule "Thứ 3 · Tiết 1-3 · P.A101", primary button "Đăng ký". No shopping cart. Yellow dismissible warnings banner on top. Vietnamese, Material 3.
```
**Prompt (App):**
```
Mobile course registration, single column. Top app bar with semester and credit total chip. Bottom sheet filters. Class cards with full-width "Đăng ký" button (48px). Tabs as segmented control. Snackbar for success/error. Vietnamese.
```

### 5.4. `/student/auto-schedule` — TKB tự động (SV-06, **tùy chọn · Pha 8**)
- **Bước 1 gồm hai khối đánh số, trải hết chiều ngang trang:** *"1. Chọn môn muốn học"* — cùng bộ lọc với màn Đăng ký (*Tất cả môn đang mở / Theo CTĐT* + nút *Môn chưa học*, kết hợp được, + dropdown *Kỳ trong chương trình đào tạo*, mục 5.3); mỗi môn là một dòng có checkbox + chevron: bấm vào xổ ra **chọn Giáo viên mong muốn** (nút "Tự động chọn" + từng giáo viên của môn; chọn một giáo viên thì tự tick môn đó) và **bảng các lớp học phần** (mã lớp · giáo viên · lịch · phòng · sĩ số) như màn Đăng ký — lớp không thuộc giáo viên đã chọn bị làm mờ, lớp thuộc giáo viên đó có nhãn "Đã chọn". Môn bắt buộc theo `hoc_ky_goi_y` chọn sẵn và *"2. Ưu tiên cá nhân"* gồm: **Tránh ngày trong tuần** (T2…CN, nhiều lựa chọn, chú thích "Chọn các thứ bạn KHÔNG muốn xếp lịch học"), **Ngày muốn học** (T2…CN, chú thích về việc lớp có buổi vào ngày đó được điểm cao hơn; chọn ngày này thì tự bỏ khỏi "tránh" và ngược lại) và **Ca học ưu tiên** (Sáng tiết 1–5 · Chiều tiết 6–10 · Tối tiết 11–15, ba nút rộng). Mỗi nhóm nút chia đều bằng chiều ngang.
- Chọn môn + ưu tiên → **client** (`AutoScheduleService`, pure Dart) sinh tối đa **3 tổ hợp** từ `GET /api/auto-schedule/available-courses/` (toàn bộ lớp mở, **chưa lọc trùng lịch**).
- **Bước 2:** đầu trang có câu giải thích tổng quát ("Tổ hợp 1 được điểm cao nhất vì: …"). Mỗi tổ hợp là một thẻ có **điểm /100 + thanh điểm**, nhãn "Điểm cao nhất" cho tổ hợp đầu, khối **"Vì sao có điểm này"** liệt kê các lý do với dấu ✓ (đạt: không có buổi vào ngày tránh, đúng ca ưu tiên, học ≤ 4 ngày/tuần, không trùng tiết…) hoặc ! (chưa đạt hoặc bị vướng — ví dụ "Chiều thứ 5 bị vướng môn Trí tuệ nhân tạo (CNTT401-03, tiết 6–8) ngay sau buổi sáng An toàn thông tin"; "Đúng giáo viên mong muốn: Trí tuệ nhân tạo – Vũ Đức Anh" / "Chưa xếp được giáo viên mong muốn: … học với A thay vì B"), danh sách môn/lớp + tổng tín chỉ. Tổ hợp xếp theo điểm giảm dần; Web hiển thị các thẻ cạnh nhau, App xếp dọc. Cho phép đổi lớp từng môn (dropdown các lớp khác không gây trùng).
- **Gợi ý ≠ đăng ký.** Nút "Đăng ký tổ hợp này" → `ConfirmDialog` liệt kê môn → POST **tuần tự từng môn**, mỗi môn một `Idempotency-Key`, nghỉ giữa các request để không vượt 30 lần/phút. Hiển thị tiến trình từng dòng ✓/✗ + mã lỗi; môn lỗi không làm hủy môn đã thành công; cuối cùng nút "Xem lớp đã đăng ký".
- Không có endpoint suggest phía server; không lưu gợi ý.

**Prompt:**
```
Auto-schedule screen. Step 1: chips to pick subjects and two preference toggles. Step 2: three suggestion cards "Tổ hợp 1/2/3", each with a mini weekly grid (Mon–Sun columns, periods 1–15), list of classes, total credits and a green "Không trùng lịch" badge. Step 3: confirm dialog listing courses, then a progress list with check/cross per course. Vietnamese.
```

### 5.5. `/student/schedule` — Thời khóa biểu (SV-08)
- `GET /api/timetable/my/` + chọn học kỳ. Hiển thị **theo tuần có ngày thật** (nút Tuần trước / Tuần này / Cả học kỳ / Tuần sau, nhãn HÔM NAY) theo mục 1.8; chế độ *Cả học kỳ* hiện lịch lặp theo thứ × tiết. Mỗi tuần chỉ hiện lớp có ngày nằm trong `[ngay_bat_dau, ngay_ket_thuc]` của lớp.
- **Lưới Web:** cột Thứ 2 … Thứ 7, **Chủ nhật** (`thu=8`); hàng tiết 1–15 chia 3 nhóm *Sáng 1–5 · Chiều 6–10 · Tối 11–15* (dải nền phân biệt); khối môn trải đúng số tiết (`so_tiet_moi_buoi`), mỗi môn một màu cố định; trong khối: mã lớp, phòng. Click khối → popover: tên môn, GV, phòng, tiết `a–b`.
- Cột CN ẩn nếu không có lịch.
- **App:** *danh sách theo ngày* như mục 1.8 (header navy + nút pill chuyển tuần, nhóm theo ngày, nhãn HÔM NAY, thanh dưới nổi).
- Chưa có lớp → EmptyState + CTA "Đăng ký môn học".

**Prompt:**
```
Weekly timetable. Semester dropdown. Grid: columns Thứ 2–Thứ 7 and Chủ nhật, rows periods 1–15 grouped into Sáng (1–5), Chiều (6–10), Tối (11–15) with subtle background bands. Colored rounded blocks spanning the class's periods showing mã lớp and phòng; legend below. Week navigation with real dates (previous week, this week, whole term, next week) and an orange HÔM NAY badge on today. Mobile variant: navy hero header with pill controls, day groups of rounded cards, floating bottom bar.
```

### 5.6. `/student/grades` — Bảng điểm (SV-11)
- `GET /api/grades/my/`. **Chỉ điểm `KHOA` là chính thức** — lớp chưa duyệt hiện dòng mờ "Chưa có điểm chính thức" (không lộ điểm nháp).
- **Bộ lọc Học kỳ** (mục 1.7): mặc định **"Tất cả học kỳ"** → bảng nhóm theo từng học kỳ; chọn một học kỳ → chỉ hiện học kỳ đó.
- Thẻ trên: **GPA tích lũy** · **Tín chỉ tích lũy** · **Xếp loại** (BR-25f) luôn hiện; khi chọn **một học kỳ cụ thể** thêm 3 thẻ: **GPA học kỳ** (kèm xếp loại học kỳ) · **Điểm TB học kỳ (hệ 10)** · **Tín chỉ học kỳ** (đạt / đã học). `gpa=NULL` → "Chưa có".
- **Thống kê ở đầu mỗi khối học kỳ** (cả khi xem "Tất cả học kỳ"): *Số môn · Tín chỉ đã học · Tín chỉ đạt · Điểm TB (hệ 10) · GPA học kỳ (hệ 4) · Xếp loại học kỳ* — số liệu từ `thong_ke[]` của `/api/grades/my/` (BR-25g: môn `P` không tính vào điểm TB và GPA; `F` vẫn tính vào mẫu số). Học kỳ đang học chưa có điểm hiện "4 môn · 12 tín chỉ đang học".
- Bảng nhóm theo học kỳ: Mã môn · Tên · TC · QT · GK · CK · Tổng kết (2 chữ số) · Chữ · Hệ 4. Chip chữ theo 1.3.
- Quy tắc hiển thị: môn `DAT_KHONG_DAT` đạt → chữ **P**, hệ 4 = "—" (không vào GPA); **F** vẫn tính vào GPA; `diem_cuoi_ky` NULL (khi `KHOA`) hiện "—".
- Môn học lại: chú thích "Tính lần học mới nhất" (BR-25c) — dòng lần cũ mờ, nhãn "Đã thay thế".
- App: mỗi môn là 1 thẻ (tổng kết + chữ nổi bật; chạm để mở chi tiết QT/GK/CK).

### 5.7. `/student/attendance` — Điểm danh (SV-10)
**Luồng bắt buộc: Học kỳ → Lớp → thống kê & chi tiết (mục 1.7).**

| Bước | Trạng thái màn hình |
| :--- | :--- |
| 0. Mới vào | Chỉ có 2 ô chọn: **Học kỳ** (mặc định theo `SemesterPicker`) và **Lớp** (disable cho tới khi có học kỳ). Nội dung: `EmptyState` "Chọn lớp để xem thống kê điểm danh". **Chưa hiện số liệu nào.** |
| 1. Chọn học kỳ | Ô *Lớp* mở, liệt kê **chỉ các lớp mình đã đăng ký (`DA_DANG_KY`) trong học kỳ đó** kèm trạng thái lớp. Nếu học kỳ không có lớp nào → EmptyState "Bạn chưa đăng ký lớp nào trong học kỳ này". Đổi học kỳ ⇒ xóa lớp đã chọn. |
| 2. Chọn lớp | Gọi `GET /api/attendance/my/` cho lớp đó. Hiện 3 khối: **Thống kê lớp** · **Danh sách buổi** · **Yêu cầu của tôi** (tab). |
| 3. Chọn một buổi (hoặc bấm "Xin sửa") | Mở **chi tiết buổi** (Web: panel bên phải; App: màn con) và form xin sửa. |

- **Thống kê lớp** (thẻ): **tổng số buổi theo lịch** (cố định cả khóa, vd 42) · đã điểm danh · có mặt · vắng có phép · **vắng không phép** · số buổi đi trễ · **tỷ lệ vắng `= VANG_KHONG_PHEP / tổng số buổi theo lịch`** (vd 9/42 = 21%; vắng có phép không tính). Thanh tiến trình so số buổi vắng không phép với **ngưỡng `max_absent_pct × tổng số buổi`** (vd 20% × 42 = 8,4 ⇒ bị cờ từ 9 buổi); vượt ngưỡng → đỏ + nhãn "Nguy cơ cấm thi". Dòng phụ "Còn được vắng không phép thêm n buổi" (n ≥ 0). Server trả `tong_so_buoi`, `canh_bao_vang`, `so_buoi_vang_cho_phep` trong `/api/attendance/my/` — UI không tự suy ngưỡng. Chú thích: "Chỉ là cảnh báo, quyết định thuộc giáo viên/Phòng đào tạo".
- **Danh sách buổi theo lịch** (chỉ buổi của lớp đã chọn, mới nhất trước): Ngày · Buổi · Tiết · Trạng thái (chip) + "Trễ" nếu `di_tre` · ghi chú của GV. Buổi **sắp tới** hiện mờ, nhãn "Chưa tới ngày" (không xin sửa được). Buổi đã đến ngày nhưng GV chưa điểm danh (`MO`) hiện "Chưa điểm danh" — vẫn nằm trong tổng số buổi.
- **Chi tiết buổi:** ngày, buổi, tiết, trạng thái, `di_tre`, ghi chú; nếu từng có yêu cầu sửa → lịch sử yêu cầu của buổi đó.
- **Xin sửa:** chọn một buổi đã điểm danh → nút "Xin sửa điểm danh buổi này" mở **form ngay trong panel chi tiết buổi** (Web) / bottom sheet (App): trạng thái hiện tại (chỉ đọc) · **trạng thái mong muốn** chọn một trong *Có mặt*, *Có mặt – đi trễ*, *Vắng có phép* (bỏ giá trị trùng trạng thái hiện tại; mỗi lựa chọn có mô tả ngắn) · **lý do** (bắt buộc, báo lỗi dưới ô) · **minh chứng** ảnh hoặc PDF, không bắt buộc, tối đa 5 MB, hiện tên tệp đã chọn và nút bỏ tệp → `POST /api/attendance/requests/` (`multipart`). Buổi chưa diễn ra không có nút; buổi đã có yêu cầu `CHO_DUYET` → chip "Chờ duyệt" thay nút (không gửi trùng). **Lớp đã đóng (`DA_DONG`)** → ẩn nút, hiện dòng "Lớp đã đóng nên không thể gửi yêu cầu sửa điểm danh"; yêu cầu còn chờ lúc đóng lớp tự thành **"Từ chối"** kèm ghi chú đỏ "Quá hạn — lớp đã đóng".
- Tab **Yêu cầu của tôi** (`GET /api/attendance/requests/`, lọc theo lớp đã chọn): buổi, "hiện tại → mong muốn", lý do, **tệp minh chứng** (nếu có), thời điểm gửi, trạng thái (`Chờ duyệt`/`Đã duyệt`/`Từ chối`), người duyệt. App liệt kê các yêu cầu đã gửi ngay dưới danh sách buổi.

| | Web | App |
| :--- | :--- | :--- |
| Bố cục | Thanh chọn (Học kỳ · Lớp) cố định trên cùng; dưới: cột trái = thống kê + danh sách buổi, cột phải = chi tiết buổi/yêu cầu | Màn 1: chọn Học kỳ + Lớp (danh sách lớp dạng thẻ) → Màn 2: thống kê + danh sách buổi (tab Buổi / Yêu cầu) → Màn 3: chi tiết buổi + form xin sửa (bottom sheet) |

**Prompt:**
```
Student attendance, step-by-step. Top bar with two dependent dropdowns: "Học kỳ" then "Lớp" (disabled until semester chosen). Initial state: empty state "Chọn lớp để xem thống kê điểm danh" and no numbers. After a class is chosen: left column = summary card (sessions held, present, excused, unexcused, late, absence-rate progress bar turning red with chip "Nguy cơ cấm thi", helper text that it is only a warning) + tabs "Các buổi học" (table: ngày, buổi, tiết, status chip, "Trễ" tag) and "Yêu cầu của tôi"; right column = selected session detail with button "Xin sửa" (dialog: current status read-only, desired status, reason). Mobile: three-level navigation (pick → stats + sessions → session detail with bottom sheet). Vietnamese.
```

### 5.8. `/student/tuition` — Học phí (SV-12)
- `GET /api/tuition/my/` (kèm giá trị dẫn xuất, plan mục 5). Chọn học kỳ.
- **Thẻ tổng hợp:** `tong_tien` · `mien_giam` · `phai_nop` · `thuc_thu` · **`con_no`** · `can_hoan`, kèm `hien_thi` làm chip chính: `CHUA_TINH` (hiện "Học phí chưa được tính" — không hiện số 0) · `CON_NO` · `CHO_HOAN_TIEN` ("Bạn được hoàn <can_hoan>") · `DA_DONG`. Thanh tiến độ `thực thu / phải nộp`.
- **Hạn đóng** (`TuitionConfig.han_dong`): còn `con_no>0` và quá hạn → chip "Quá hạn" đỏ.
- Bảng chi tiết: môn · TC lý thuyết · TC thực hành · thành tiền (từ `chi_tiet[]` của `/api/tuition/my/`); lịch sử giao dịch (`THU`/`HOAN`, ngày, số tiền, phương thức, mã biên lai — từ `payments[]`). Khi `con_no > 0` (học kỳ chưa đóng đủ) hiện nút cam **"Thanh toán học phí"** trong thẻ trạng thái → mở trang `/student/tuition/pay` (mục 5.8a). Học kỳ đã đóng đủ không có nút.
- App: thẻ tóm tắt lớn + accordion "Chi tiết môn" / "Giao dịch".

### 5.8a. `/student/tuition/pay` *(bổ sung)* — Thanh toán học phí bằng mã QR
- Không tích hợp cổng thanh toán: SV **chuyển khoản** vào tài khoản của trường, **Phòng Kế toán đối soát và ghi `Payment` THU** (KT-08). Học phí chỉ cập nhật sau khi kế toán xác nhận.
- Thông tin nhận tiền lấy từ `tuition/my` → `thanh_toan{ngan_hang, so_tai_khoan, chu_tai_khoan, noi_dung_ck}` (cấu hình ở `SystemConfig`). Mã QR (VietQR) **sinh ở client** từ các thông tin này + số tiền; bản thiết kế dùng mã minh họa.
- Bố cục Web: hai cột — trái: thẻ **công nợ hiện tại**, chọn **Thanh toán toàn bộ** hoặc **một phần** (ô nhập số tiền, kiểm tra > 0 và ≤ `con_no` theo BR-26), danh sách **các bước thanh toán** + hộp lưu ý chờ kế toán xác nhận; phải — **mã QR**, các dòng *Ngân hàng · Số tài khoản · Chủ tài khoản · Số tiền · Nội dung chuyển khoản* mỗi dòng có nút **Sao chép**, nút **Tải mã QR**. Nhập số tiền sai → ẩn QR, báo lỗi dưới ô. Nội dung chuyển khoản cố định `HOCPHI <mã SV> <học kỳ>` để kế toán đối soát.
- App: một cột — công nợ + chọn hình thức → QR → thông tin tài khoản (nút Sao chép ≥ 48px) → các bước. Nút "Lưu mã QR vào máy".

### 5.9. `/student/notifications`
Mục 4.4 (chỉ nhận, không soạn).

---

## 6. GIÁO VIÊN — Web + App (6 route)

Quy ước GV: chỉ thấy **lớp mình phụ trách** (BR-12/23). Mọi màn tác nghiệp (`/teacher/attendance`, `/teacher/grades`) **bắt đầu bằng `ClassPicker`** (danh sách `GET /api/class-sections/my/`) và **không tự chọn lớp** (mục 1.7): chưa chọn lớp ⇒ chỉ có ô chọn lớp + `EmptyState` "Chọn lớp để bắt đầu", chưa hiện buổi, danh sách SV hay điểm. Ô chọn lớp hiển thị kèm học kỳ + trạng thái lớp (ưu tiên `DANG_HOC` ở đầu danh sách). Lớp không ở `DANG_HOC` → màn chuyển **chế độ chỉ xem** + banner giải thích.

### 6.0. `/teacher` — Tổng quan
- Thẻ: số lớp đang dạy (`DANG_HOC`) · tổng SV · **lớp cần xử lý** (lớp `DANG_HOC` sắp/đã quá `han_nhap_diem`) · buổi điểm danh tuần này.
- "Lịch dạy hôm nay" (từ `timetable/my`, `thu` = hôm nay) · danh sách lớp dạng thẻ với 2 lối tắt **Điểm danh** / **Nhập điểm** — lối tắt mở màn tương ứng với lớp đã chọn sẵn qua URL (`?lop=<id>`), nên bỏ qua bước chọn lớp.
- Cảnh báo: lớp có `han_nhap_diem` còn ≤ 3 ngày (vàng) / đã quá hạn (đỏ).
- App: 1 cột; "Hôm nay" nổi bật nhất.

### 6.1. `/teacher/profile` — Hồ sơ (GV-02)
Như 5.1: chỉ đọc `ma_gv`, họ tên, khoa/viện, học vị; sửa `email`, `sdt`; đổi mật khẩu.

### 6.2. `/teacher/classes` — Lớp phụ trách (GV-03, 04, 05, 12)
- **Danh sách:** thẻ/bảng lớp: mã lớp, môn, học kỳ, sĩ số, trạng thái, lịch (chip `Thứ·Tiết`). Lọc theo học kỳ + trạng thái.
- **Chi tiết lớp** (trang con hoặc drawer, 4 tab):
  1. *Thông tin:* môn, tín chỉ, học kỳ, ngày bắt đầu/kết thúc, **hạn nhập điểm** (kèm đếm ngược), trạng thái.
  2. *Lịch học:* bảng lịch (Thứ · Tiết `a–b` · Buổi · Phòng).
  3. *Danh sách SV* (`GET /class-sections/{id}/students/`): mã SV, họ tên, ngành; nút **Xuất Excel** (`/class-sections/{id}/export/` — SV, bảng điểm, bảng điểm danh).
  4. *Lịch dạy cá nhân* (GV-05): lưới tuần như 5.5 nhưng cho **tất cả lớp mình dạy** (`timetable/my`), tô màu theo lớp. (Plan không có route riêng ⇒ đặt làm tab ở màn này.)
- App: chi tiết lớp là màn con; tab thành segmented control; nút Xuất Excel → chia sẻ file.

**Prompt:**
```
Teacher "My classes". Filter row (semester, status). Class cards: mã lớp, môn, status chip, sĩ số, schedule chips, grade-deadline countdown. Class detail with four tabs: Thông tin, Lịch học, Danh sách SV (with "Xuất Excel" button), Lịch dạy của tôi (weekly grid across all my classes). Vietnamese.
```

### 6.3. `/teacher/attendance` — Điểm danh (GV-06, 07, 08, 09)

**Buổi điểm danh do hệ thống sinh sẵn** (plan BR-20): với mỗi lớp, mọi ngày trong `[ngày bắt đầu, ngày kết thúc]` có thứ trùng với lịch học đều đã có sẵn một buổi. Ví dụ lớp học từ 01/10 đến 05/11, chỉ học thứ 5 ⇒ 01, 08, 15, 22, 29/10 và 05/11 = **6 buổi**. GV **không tạo buổi** — chỉ chọn buổi và điểm danh. Tổng số buổi này (vd 6) là **mẫu số cố định** của tỷ lệ vắng cho cả khóa.

**Luồng bắt buộc: Lớp → Buổi → Danh sách SV (mục 1.7).** Buổi chỉ hiện sau khi chọn lớp; danh sách SV chỉ hiện sau khi chọn một buổi.

| Bước | Trạng thái màn hình |
| :--- | :--- |
| 0. Mới vào | Chỉ có ô **Chọn lớp** (lớp mình phụ trách, kèm học kỳ + trạng thái). `EmptyState` "Chọn lớp để xem các buổi điểm danh". **Không hiện buổi, không hiện danh sách SV.** |
| 1. Chọn lớp | Gọi `GET /api/attendance/sessions/?lop_hoc_phan=`. Hiện: **thẻ tóm tắt** chỉ gồm số liệu ("42 buổi theo lịch · đã đến hạn 16 · đã điểm danh 15 · sắp tới 26"; **không** ghi chú giải thích quy tắc nghiệp vụ trên giao diện — cờ "Nguy cơ cấm thi" ở từng sinh viên đã đủ), **danh sách buổi** (ngày · buổi · tiết · chip · số vắng) và tab **Yêu cầu sửa của SV**. Buổi **sắp tới** hiện mờ, không chọn được ("Chưa tới ngày"). Panel điểm danh còn trống: "Chọn một buổi để điểm danh". |
| 2. Chọn một buổi đã đến ngày | Mở **panel điểm danh** của buổi đó với danh sách SV `DA_DANG_KY` (`GET …/records/`). |
| 3. Lưu | `PUT …/records/` cả lớp một lần → refetch danh sách buổi (chip chuyển `DA_DIEM_DANH`, số vắng và tỷ lệ vắng cập nhật). |
| Đổi lớp | Xóa buổi đang chọn và panel; có thay đổi chưa lưu → `ConfirmDialog` "Bỏ các thay đổi chưa lưu?". |

**Danh sách buổi (GV-06, GV-09):** mới nhất trước; chip `MO` ("Chưa điểm danh") / `DA_DIEM_DANH` ("Đã điểm danh"); buổi hôm nay có nhãn "Hôm nay". Buổi đã qua nhưng chưa điểm danh được nhắc màu vàng — vẫn nằm trong mẫu số. Lớp chưa `DANG_HOC` hoặc `DA_DONG` → chỉ xem.

**Panel điểm danh (GV-07, 08)** — danh sách SV `DA_DANG_KY` của lớp:
- Mỗi dòng: mã SV · họ tên · *segmented* **Có mặt / Vắng có phép / Vắng không phép** · công tắc **Đi trễ** · ghi chú. Buổi chưa điểm danh: mặc định tất cả **Có mặt** + lối tắt "Tất cả có mặt"; buổi đã điểm danh: hiển thị giá trị đã lưu.
- Cạnh mỗi SV: **"Vắng KP n/tổng (x%)"** (vd 9/42 = 21%) và nhãn "Nguy cơ cấm thi" khi n vượt ngưỡng (chỉ thông tin, không chặn). Số này cộng cả lựa chọn đang sửa trong buổi hiện tại khi chưa lưu.
- Thanh đếm "Có mặt a · Vắng có phép b · Vắng không phép c · Trễ d". Nút **Lưu** → `PUT /api/attendance/sessions/{id}/records/` (cả lớp; buổi chuyển `MO` → `DA_DIEM_DANH` ở lần lưu thành công đầu tiên).
- **Sửa điểm danh (GV-08):** mở lại buổi cũ → cùng panel; sửa được **bất kỳ lúc nào khi lớp còn `DANG_HOC`** (không có cửa sổ 24h); lớp `DA_DONG` → chỉ xem.
- Buổi **tương lai** không mở được panel (server từ chối `TRANG_THAI_KHONG_HOP_LE`).

**Tab Yêu cầu sửa của SV (GV-08)** — chỉ của lớp đã chọn (`GET /api/attendance/requests/`): mỗi yêu cầu là một thẻ gồm SV (tên · mã) · buổi · thời điểm gửi · **"hiện tại → mong muốn"** (kể cả *Có mặt – đi trễ*) · **lý do** · **minh chứng** (chip tên tệp + liên kết "Xem minh chứng", hoặc "Không đính kèm minh chứng") · chip trạng thái. Nút **Duyệt / Từ chối** (`PATCH /api/attendance/requests/{id}/`); sau khi xử lý thẻ hiện ghi chú kết quả và nhãn trên tab đếm lại số yêu cầu còn chờ. Với **lớp đã đóng**, các yêu cầu hiện chip "Từ chối" + ghi chú "Tự động từ chối — quá hạn, lớp đã đóng" và không còn nút Duyệt/Từ chối. `DUYET` ⇒ server ghi trạng thái mong muốn và cờ đi trễ; UI refetch buổi và tỷ lệ vắng. Bản App: cùng nội dung (kể cả chip minh chứng) trong tab "Yêu cầu sửa" của danh sách buổi.

| | Web | App |
| :--- | :--- | :--- |
| Bố cục | Thanh chọn lớp cố định trên cùng. Hai cột: **trái** = thẻ tóm tắt + danh sách buổi + tab Yêu cầu; **phải** = panel điểm danh (bảng SV rộng, thanh Lưu dính dưới) | **Màn 1:** chọn lớp (danh sách thẻ lớp). **Màn 2:** thẻ tóm tắt + danh sách buổi (có buổi sắp tới mờ) + tab Yêu cầu, **không có nút Tạo buổi**. **Màn 3:** điểm danh — thẻ SV, segmented 3 nút lớn (≥48px), thanh Lưu dính đáy. Back về cấp trước |

**Prompt (Web):**
```
Teacher attendance, step-by-step master–detail. Top: a single "Chọn lớp" dropdown (class code, course, semester, status chip). Initial state: empty state "Chọn lớp để xem các buổi điểm danh", nothing else. After choosing a class: left column shows a summary card with numbers only ("42 buổi theo lịch · đã đến hạn 16 · đã điểm danh 15 · sắp tới 26", no explanatory rule text), then a list of pre-generated sessions (date, buổi, periods, status chip MO/DA_DIEM_DANH, absence count) with upcoming sessions faded and not selectable, and a second tab "Yêu cầu sửa của SV" with a pending badge. There is NO "create session" button. Right column shows placeholder "Chọn một buổi để điểm danh". After selecting a session: roster table — mã SV, họ tên, segmented control (Có mặt / Vắng có phép / Vắng không phép), "Đi trễ" switch, ghi chú, "Vắng KP 9/42 (21%)" with red "Nguy cơ cấm thi" tag when over threshold; sticky bottom bar with counts and "Lưu". Vietnamese.
```
**Prompt (App):**
```
Mobile teacher attendance in three levels: (1) list of my classes as cards to pick from, (2) summary card plus pre-generated sessions of the chosen class (no create button), segmented tab "Buổi / Yêu cầu", (3) roster of the chosen session with a card per student, three large segmented buttons, "Đi trễ" switch, "Vắng KP n/tổng" and a sticky bottom "Lưu" bar with counts. Back arrow returns one level. Vietnamese.
```

### 6.4. `/teacher/grades` — Nhập điểm (GV-10)
**Điều kiện thao tác** (UI phản ánh, server là chốt): lớp `DANG_HOC` **và** trong `han_nhap_diem` (BR-13). Ngược lại toàn bộ ô nhập disabled + banner.

- **Luồng: Lớp → lưới điểm (mục 1.7).** Mới vào chỉ có ô **Chọn lớp** + `EmptyState` "Chọn lớp để nhập điểm"; chọn lớp xong mới tải lưới cả lớp (`GET …/grades/`).
- **Thanh đầu (sau khi chọn lớp):** chip trạng thái điểm của lớp · **đếm ngược hạn nhập điểm** (đỏ khi quá hạn: "Đã quá hạn — liên hệ Phòng đào tạo để gia hạn hoặc nhập hộ"). Đổi lớp khi có ô chưa lưu → `ConfirmDialog`.
- **Lưới nhập cả lớp:** Mã SV · Họ tên · **QT** · **GK** · **CK** · *Tổng kết (xem trước)* · *Chữ* · Trạng thái dòng.
  - Ô trống = **NULL (chưa nhập)** ≠ `0` (GV nhập 0). Giá trị ∈ [0,10], tối đa 2 chữ số thập phân; ngoài khoảng → viền đỏ.
  - **Xem trước BR-10** tính ngay phía client: `QT×0.1 + GK×0.4 + CK×0.5`; GK trống → 20/80 (QT/CK); CK trống → coi CK = 0 (dòng hiển thị nhãn "CK = 0 (chưa nhập)"). Làm tròn 2 chữ số. Chữ theo BR-11 (≥8.50 A · ≥7.00 B · ≥5.50 C · ≥4.00 D · <4.00 F); môn `DAT_KHONG_DAT`: ≥5.0 → **P**, ngược lại F.
  - Phím Tab/Enter chuyển ô theo hàng; dán nhiều ô từ Excel (Web).
- **Hành động (thanh dính đáy):**
  - **Lưu nháp** → `PUT /api/class-sections/{id}/grades/` (upsert cả lớp, `NHAP_TAM`).
  - **Khóa điểm cả lớp** → `ConfirmDialog` (nêu: "n SV chưa có CK sẽ tính CK = 0", "sau khi khóa chỉ mở khóa được khi còn hạn") → `POST …/grades/lock/ {action:"lock"}` ⇒ `CHINH_THUC`.
  - **Mở khóa** (hiện khi đang `CHINH_THUC`, lớp `DANG_HOC`, trong hạn) → `{action:"unlock"}` ⇒ `NHAP_TAM`; có audit log.
  - Khi `KHOA` (đã duyệt) → toàn bộ chỉ xem, ổ khóa xám "Đã được Phòng đào tạo duyệt".
- **Xuất Excel** (bảng điểm).
- Điểm đã khóa không ảnh hưởng SV cho tới khi PĐT duyệt `KHOA` (SV chưa thấy) — ghi chú nhỏ trên đầu trang.

| | Web | App |
| :--- | :--- | :--- |
| Bố cục | Lưới bảng đầy đủ, thao tác bàn phím | Danh sách thẻ SV, mỗi thẻ 3 ô số lớn + kết quả xem trước; thanh hành động dính đáy; bàn phím số |

**Prompt:**
```
Teacher grade entry grid. Initial state: only a "Chọn lớp" dropdown and an empty state; the grid appears after a class is chosen. Header: class picker, grade-status chip, deadline countdown. Table: Mã SV, Họ tên, QT, GK, CK (number inputs 0–10, empty = not entered), read-only "Tổng kết" (2 decimals) and "Chữ" chip auto-calculated, row validation red. Banner when past deadline with disabled inputs. Sticky bar: outlined "Lưu nháp", filled "Khóa điểm cả lớp" with confirm dialog, and "Mở khóa" when allowed. Mobile: card per student with three large numeric inputs.
```

### 6.5. `/teacher/notifications`
Mục 4.4: nhận + **chỉ gửi `CLASS` cho lớp mình** (GV-11).

---

## 7. PHÒNG ĐÀO TẠO — Web only (10 route + 3 bổ sung)

Quy ước PĐT: toàn bộ màn dùng `DataTable` + drawer chi tiết bên phải (≥1024px) hoặc trang con (<1024px). Nút tạo/sửa mở dialog (≤6 trường) hoặc drawer (nhiều trường). Xóa cứng không tồn tại — chỉ **ngừng** (`NGUNG`/`NGUNG_SU_DUNG`) vì đối tượng đã có dữ liệu liên quan.

> **Ô chọn có gợi ý (combobox):** mọi danh sách dài (môn học, lớp, giáo viên, người nhận) là ô gõ để tìm — bấm vào là hiện đủ danh sách, gõ từng chữ (không cần dấu) thì lọc theo khớp. **Lọc liên động:** chọn *ngành* thì danh sách môn chỉ còn môn của ngành đó; chọn *môn* thì danh sách giáo viên chỉ còn giáo viên cùng khoa phụ trách môn (khi tạo lớp) hoặc giáo viên đang dạy môn (khi lọc). Thông báo gửi một người: chọn *vai trò* → *khoa* → gõ *tên*.
>
> **Mockup Claude Design:** đã dựng đủ 13 màn Web PĐT (`PDT-Web-*.dc.html`: Tổng quan, Hồ sơ SV/GV, Khoa / viện, Ngành, CTĐT, Môn học, Học kỳ, Lớp học phần, Đăng ký, Duyệt điểm, Báo cáo, Thông báo, Nhật ký). Ngày "hôm nay" trong dữ liệu mẫu là 12/01/2027 (cửa sổ đăng ký HK2 còn 7 ngày). Nhật ký PĐT dùng `AuditLogScreen` với `scope=training` cố định (mục 9.5).

### 7.0. `/pdt` — Tổng quan
- Thẻ (học kỳ chọn): lớp theo trạng thái (`KE_HOACH`/`MO`/`DANG_HOC`/`DA_DONG`) · tổng lượt đăng ký `DA_DANG_KY` · lớp đầy · lớp còn chỗ.
- **Danh sách việc cần làm** (mỗi dòng là link lọc sẵn):
  - Lớp `KE_HOACH` thiếu GV/lịch → "n lớp chưa đủ điều kiện mở".
  - Lớp `DANG_HOC` quá `han_nhap_diem` → "n lớp quá hạn nhập điểm" → `/pdt/grade-sheets`.
  - Lớp `DA_DONG` chưa duyệt `KHOA` → "n lớp chờ duyệt điểm".
  - Học kỳ có cửa sổ đăng ký sắp đóng (còn ≤ 10 ngày) → link `/pdt/semesters`.
- Lối tắt: Học kỳ · Lớp HP · Đăng ký · Duyệt điểm. Dữ liệu từ các list đã có (dùng `count` của list phân trang).

### 7.1. `/pdt/profiles` *(bổ sung)* — Hồ sơ SV/GV (PDT-01)
- Hai tab *Sinh viên* · *Giáo viên*; bảng + tìm theo mã/tên, lọc ngành/khoa.
- **Tạo hồ sơ** chọn một `User` đã được Admin tạo (vai trò SV/GV) và **chưa có hồ sơ**; danh sách tài khoản chưa có hồ sơ hiện thành badge "Chưa có hồ sơ" để PĐT biết cần làm.
  - SV: `ma_sv` (duy nhất), họ tên, ngành, khóa nhập học, **CTĐT** (chỉ liệt kê CTĐT `HOAT_DONG` khớp *ngành + khóa*; sau khi gán **cố định**, không sửa — ô khóa kèm tooltip), email, sđt. `gpa` / `tin_chi_tich_luy` hiển thị chỉ đọc (cache BR-25).
  - GV: `ma_gv` (duy nhất), họ tên, khoa/viện (chọn từ danh mục `/pdt/faculties`), học vị, email, sđt.
- API: `/api/profiles/students/`, `/api/profiles/teachers/` (GET/POST/PATCH).

### 7.1a. `/pdt/faculties` *(bổ sung)* — Khoa / viện (PDT-02)
**Do PĐT quản lý** (Admin chỉ cấp tài khoản, không đụng danh mục này). Bảng: mã · tên · số ngành · số giáo viên · số môn · trạng thái. Dialog thêm/sửa (mã không đổi sau khi tạo). **Ngừng** (không xóa): nếu còn ngành hoặc giáo viên đang thuộc khoa/viện thì nút xác nhận bị khóa kèm thông báo "Hãy chuyển họ sang nơi khác trước khi ngừng". Danh mục này là nguồn cho ô chọn khoa/viện ở hồ sơ giáo viên, ngành, môn học và cho bộ lọc liên động (môn → giáo viên cùng khoa/viện).

### 7.2. `/pdt/majors` — Ngành (PDT-02)
Bảng: mã ngành · tên · **khoa / viện quản lý** · thời gian đào tạo · số CTĐT · trạng thái. Dialog thêm/sửa; "Ngừng ngành" (không xóa). `ma_nganh` duy nhất.

### 7.3. `/pdt/curriculums` — CTĐT & gán môn (PDT-03)
- **Tab CTĐT:** mã CTĐT · ngành · khóa tuyển sinh · tổng tín chỉ yêu cầu (>0) · trạng thái. Chỉ **một** CTĐT `HOAT_DONG` cho mỗi (ngành, khóa) — vi phạm → lỗi field.
- **Tab Môn trong CTĐT** (`CurriculumCourse`): chọn một CTĐT → bảng môn: môn · **khối kiến thức** (`chung`/`co_so_nganh`/`chuyen_nganh`/`tu_chon`/`tot_nghiep`) · **loại môn** (bắt buộc/tự chọn) · học kỳ gợi ý. Thêm môn: chọn môn `HOAT_DONG`; `(ctdt, môn)` duy nhất. Dòng cuối: tổng tín chỉ đã gán vs `tong_tin_chi_yeu_cau`.
- Ghi chú trên màn: *khối kiến thức* là căn cứ tính giá của Kế toán (BR-16) ⇒ đổi khối có thể làm đổi học phí.

### 7.4. `/pdt/courses` — Môn học & tiên quyết (PDT-04, 05)
- **Tab Môn học:** mã · tên · tín chỉ (tổng = LT + TH, **tự tính, không nhập tổng**) · số tiết LT/TH (chỉ để giảng dạy, không tính phí) · loại đánh giá `DIEM`/`DAT_KHONG_DAT` · trạng thái. "Ngừng sử dụng" ⇒ chặn mở lớp mới, môn đã có lớp/CTĐT vẫn giữ.
- **Tab Tiên quyết:** chọn một môn → danh sách môn tiên quyết của nó + thêm/bỏ. Chặn tự tiên quyết và **chu trình** (server 400 → hiện đường vòng "A → B → A").

### 7.5. `/pdt/semesters` — Học kỳ & cửa sổ đăng ký (PDT-06, 07)
- Bảng: tên · năm học · thời gian · **cửa sổ đăng ký** · trạng thái `MO`/`DONG`.
- Form: ngày bắt đầu/kết thúc; **cửa sổ ĐK phải nằm trong thời gian học kỳ** (kiểm tra ngay trên date picker). Khối **Giới hạn tín chỉ đăng ký** của từng học kỳ: *tối thiểu* (12) · *tối đa* (24) · *tối đa khi bị cảnh báo học vụ* (14); kiểm tra tối thiểu ≤ tối đa và mức cảnh báo ≤ tối đa. Học kỳ phụ gọi là "Học kỳ 3".
- Nút **Mở học kỳ** (chỉ khi đã đặt cửa sổ) · **Đóng học kỳ** (còn lớp `MO`/`DANG_HOC` ⇒ `409 TRANG_THAI_KHONG_HOP_LE`: nút bị vô hiệu kèm tooltip "Còn n lớp chưa đóng" + link lọc sang `/pdt/classes`). Sửa cửa sổ: `PATCH …/window/`.

### 7.6. `/pdt/classes` — Lớp học phần & lịch (PDT-08, 09, + xem điểm danh PDT-10)
- **Danh sách:** lọc học kỳ · môn · GV · trạng thái. Cột: mã lớp · môn · GV · sĩ số `x/y` · ngày BĐ/KT (NULL hiện "theo học kỳ") · hạn nhập điểm · trạng thái.
- **Tạo/sửa lớp:** môn (`HOAT_DONG` mới chọn được), học kỳ, GV, sĩ số tối đa (không nhỏ hơn sĩ số hiện tại), ngày BĐ/KT (tùy chọn).
- **Drawer chi tiết — 4 tab:**
  1. *Lịch học* (PDT-09): bảng lịch + form: **Thứ** (2–7, **8 = Chủ nhật**), **tiết bắt đầu** (1–15), **số tiết/buổi**, phòng. Tự hiển thị *tiết kết thúc* và *buổi* (Sáng 1–5/Chiều 6–10/Tối 11–15). Chặn khi **vượt hết nhóm tiết** của buổi (BR-09) — báo trước khi gửi. Server từ chối khi **phòng hoặc GV bị giao tiết** cùng thứ → hiển thị lớp đang chiếm. Mini-lưới 7×15 tô màu lịch lớp này để PĐT thấy trực quan.
  2. *Sinh viên:* danh sách đăng ký của lớp (liên kết sang `/pdt/registrations`).
  3. *Điểm danh:* danh sách buổi + tỷ lệ vắng từng SV (chỉ xem). Việc xem và duyệt yêu cầu sửa điểm danh của SV là của **giáo viên lớp đó**, PĐT không tham gia.
  4. *Điểm & hạn:* hạn nhập điểm hiện tại + nút **Gia hạn nhập điểm** (chọn ngày mới, bắt buộc > hạn hiện tại; có audit log).
- **Nút vòng đời** (hiện/ẩn theo trạng thái, đúng mục 3):
  - `KE_HOACH` → **Mở lớp**. Nút disable + checklist điều kiện: ☐ có GV ☐ có sĩ số ☐ ≥ 1 lịch ☐ môn chưa `NGUNG_SU_DUNG`.
  - `MO`/`DANG_HOC` → **Đóng lớp** (chỉ bật khi đã qua `ngay_ket_thuc` và đủ điều kiện điểm; lỗi → tooltip `TRANG_THAI_KHONG_HOP_LE`).
  - Chuyển `MO` → `DANG_HOC` **chỉ do job hằng ngày** (qua `ngay_bat_dau`) — UI không có nút thủ công; muốn học sớm thì PĐT sửa `ngay_bat_dau` của lớp.
- Đổi lịch/phòng/hủy lớp đã `MO` ⇒ cảnh báo "Sẽ gửi thông báo tới cả lớp" (trigger plan 7.6).

### 7.7. `/pdt/registrations` — Theo dõi & hủy hộ (PDT-10, 11)
- Lọc theo thứ tự: học kỳ (mặc định) → ngành / môn / **lớp (chỉ liệt kê lớp của học kỳ đã chọn)** → trạng thái (`DA_DANG_KY`/`DA_HUY`). Cột: mã SV · họ tên · ngành · môn · lớp · ngày ĐK · trạng thái · lý do hủy.
- **Hủy hộ** (`DELETE /api/registrations/{id}/`, body `ly_do`): chỉ hiện khi bản ghi `DA_DANG_KY` và lớp `MO` **hoặc `DANG_HOC`**. Dialog **bắt buộc** `ly_do`; cảnh báo hậu quả: sĩ số −1, học phí tính lại, nếu SV đã đóng dư sẽ phát sinh *cần hoàn tiền* cho KT. Ghi audit log.
- **Xuất Excel** (`/registrations/export/`) theo bộ lọc hiện tại.

### 7.8. `/pdt/grade-sheets` — Duyệt điểm (PDT-12)
- **Luồng: Học kỳ → danh sách lớp → chọn lớp (mục 1.7).** Chưa chọn lớp thì chỉ có danh sách lớp (chưa hiện bảng điểm của lớp nào); chọn lớp mới mở panel bảng điểm cả lớp + các nút hành động.
- Danh sách lớp theo học kỳ với cột: lớp · môn · GV · số SV · **trạng thái điểm** (đếm `NHAP_TAM`/`CHINH_THUC`/`KHOA`) · hạn nhập điểm · trạng thái lớp. Chia 3 nhóm lọc nhanh:
  | Nhóm | Điều kiện | Hành động |
  | :--- | :--- | :--- |
  | **Chờ duyệt** | Lớp `DA_DONG`, điểm `CHINH_THUC` | **Duyệt cả lớp** |
  | **Quá hạn** | Lớp `DANG_HOC`, quá `han_nhap_diem` | **Gia hạn** · **Nhập hộ** |
  | **Đã duyệt** | Điểm `KHOA` | Chỉ xem |
- **Duyệt cả lớp** (`POST …/grades/approve/`): mở bảng điểm cả lớp để xem trước → `ConfirmDialog` "Duyệt <n> SV? Sau khi duyệt điểm bất biến, GPA/tín chỉ tích lũy sẽ cập nhật và SV được thông báo." Không duyệt lẻ từng SV. Lớp chưa `DA_DONG` → nút bị khóa kèm lý do.
- **Nhập hộ:** mở lưới nhập như `/teacher/grades` (cùng widget, quyền PĐT) → `PUT …/grades/`; ghi audit log. Điểm nhập hộ được lưu thẳng ở `CHINH_THUC` (PĐT không có quyền khóa, mà lớp chỉ đóng được khi mọi SV ≥ `CHINH_THUC`).
- **Gia hạn:** `POST …/grade-deadline/`.

### 7.9. `/pdt/reports` — Báo cáo đào tạo (PDT-14)
- Bộ lọc: học kỳ · ngành · môn.
- Thẻ: số SV · số lớp · tổng lượt đăng ký · lớp đầy · lớp còn chỗ. Biểu đồ cột: đăng ký theo môn; tỷ lệ lấp đầy theo lớp. Bảng chi tiết có thể sắp xếp.
- Nút **Xuất Excel** (`/reports/training/export/`). Không xuất PDF.

### 7.10. `/pdt/notifications`
Mục 4.4: nhận + soạn (`ROLE`/`CLASS`/`USER`).

### 7.11. `/pdt/logs` *(bổ sung)* — Nhật ký (scope `training`)
Widget `AuditLogScreen` (mục 9.5) với `scope=training` cố định, không có bộ chọn scope.

---

## 8. KẾ TOÁN — Web only (6 route + 1 bổ sung)

Quy ước KT: số tiền căn phải, định dạng `₫`; KT chỉ thấy tối thiểu `ma_sv`, `ho_ten`, `nganh` của SV (không sdt/email/GPA).

> **Mockup Claude Design:** đã dựng đủ 7 màn Web Kế toán (`KT-Web-*.dc.html`: Tổng quan, Cấu hình học phí, Học phí, Công nợ, Báo cáo tài chính, Thông báo, Nhật ký). Cùng quy ước với PĐT: ô gõ để tìm cho danh sách dài, lọc liên động (ngành → lớp → sinh viên), bảng số tiền căn phải, không hiện mã trạng thái kỹ thuật. Ngày "hôm nay" trong dữ liệu mẫu là 12/01/2027 (học kỳ 1 đã quá hạn đóng học phí 31/10/2026). Nhật ký KT dùng `AuditLogScreen` với `scope=finance` cố định.

### 8.0. `/accountant` — Tổng quan
- Thẻ (học kỳ chọn): **Phải thu** (Σ phải nộp) · **Đã thu** · **Còn nợ** · **Chờ hoàn** (Σ `can_hoan`). Dữ liệu `reports/finance`.
- Banner: "n SV quá hạn đóng học phí" → `/accountant/debts`; "n SV chờ hoàn tiền"; **"n SV chưa được tính học phí"** → nút tới `/accountant/tuition`.
- Biểu đồ: phải thu vs đã thu theo ngành.

### 8.1. `/accountant/config` — Cấu hình học phí (KT-01…05)
Ba tab:

**Tab 1 — Hạn đóng (KT-01):** chọn học kỳ → `han_dong` + ghi chú (`TuitionConfig`, 1 bản ghi/học kỳ).

**Tab 2 — Bảng giá (KT-02, 03, 04)** (`HocPhanGia`): bảng gồm *Học kỳ* (trống = **Mặc định mọi học kỳ**) · *Phạm vi* · *Tham chiếu* · *Đơn giá/tín chỉ*. Dialog thêm/sửa:
| Phạm vi | Ô "Tham chiếu" | Ý nghĩa |
| :--- | :--- | :--- |
| `MAC_DINH` | (khóa, trống) | Giá chung |
| `NGANH` | Chọn ngành (`ma_nganh`) | Giá theo ngành (KT-02) |
| `KHOI_KIEN_THUC` | Chọn 1 trong 5 khối | Giá theo khối (KT-03) |
| `GIA_TH` | (khóa, trống) | Đơn giá **tín chỉ thực hành** (KT-04); nếu không có thì TH tính bằng giá gốc (BR-17) |

  Ràng buộc: `don_gia ≥ 0`; **trùng (học kỳ, phạm vi, tham chiếu)** bị chặn (kể cả khi học kỳ trống). Khung thông tin cố định cạnh bảng giải thích thứ tự tra giá **BR-16**: (1) bản ghi của chính học kỳ → (2) bản ghi chung (học kỳ trống); trong mỗi trục: Khối kiến thức → Ngành → Mặc định.
  Đổi giá **không** tự cập nhật học phí đã tính — hiện lời nhắc "Bấm *Tính lại* ở Học phí để áp dụng".

**Tab 3 — Miễn giảm / học bổng (KT-05)** (`Discount`): bảng theo học kỳ: SV · loại `MIEN_GIAM`/`HOC_BONG` · **số tiền hoặc tỷ lệ %** (đúng một trong hai — UI là nút chọn Số tiền | Tỷ lệ) · lý do. Tạo/sửa đều ghi audit log (BR-18). Tổng miễn giảm của một SV không vượt tổng tiền (server cắt về `tong_tien`).

### 8.2. `/accountant/tuition` — Học phí (KT-06, 07, 08, 10)
- Chọn học kỳ → thanh hành động đầu trang: **Tính học phí hàng loạt** (`POST /tuition/calculate/?hoc_ky=`; kết quả: số SV đã tính, danh sách SV lỗi `CHUA_CAU_HINH_GIA` kèm link tới cấu hình giá). Học phí cũng **tự tính khi SV đăng ký/hủy**.
- Bảng: mã SV · họ tên · ngành · tổng TC · tổng tiền · miễn giảm · phải nộp · đã thu · **còn nợ** · **cần hoàn** · trạng thái (`hien_thi`). Lọc: ngành · lớp · trạng thái. Sắp xếp theo còn nợ.
- **Drawer SV:** tóm tắt các con số; bảng *Giao dịch* (`THU`/`HOAN`, ngày, số tiền, phương thức, người thu, mã biên lai, nút **Biên lai Excel** — KT-10); mục *Miễn giảm* (xem + "Thêm miễn giảm" mở dialog tab 3).
- **Ghi thu / Ghi hoàn (KT-08):** nút trên dòng/drawer → dialog:
  - Loại `THU` | `HOAN` (nút chọn); số tiền (>0; **gợi ý tối đa**: `THU` ≤ `con_no`, `HOAN` ≤ `can_hoan`; nút "Điền đủ số"); phương thức (`TIEN_MAT`/`CHUYEN_KHOAN`/`KHAC`); mã biên lai (tùy chọn); ghi chú.
  - Chỉ cho phép khi `Tuition` đã `DA_TINH`; còn `CHUA_TINH` → nút disable "Cần tính học phí trước".
  - `Idempotency-Key` sinh khi mở dialog (mục 1.5). Hai kế toán thu cùng lúc: server khóa dòng, người sau nhận `SO_TIEN_KHONG_HOP_LE` ⇒ dialog báo "Công nợ đã thay đổi" + tự tải lại số.
  - `Payment` **không sửa/xóa**: nhập sai ⇒ ghi một khoản `HOAN` bù (dòng thông tin trong dialog).

### 8.3. `/accountant/debts` — Công nợ (KT-09)
Hai tab: **Còn nợ** (`con_no > 0`, có bộ lọc *Chỉ quá hạn* so với `han_dong`) · **Chờ hoàn tiền** (`can_hoan > 0`). Cột: SV · học kỳ · số tiền · hạn đóng · số ngày trễ. Nút nhanh **Ghi thu** / **Ghi hoàn** mở lại dialog 8.2. Chip "Quá hạn" đỏ. Xuất danh sách → dùng `/reports/finance/export/`.

### 8.4. `/accountant/reports` — Báo cáo tài chính (KT-11)
Lọc học kỳ · ngành · lớp · SV. Thẻ Phải thu / Đã thu / Còn nợ / Chờ hoàn; biểu đồ theo ngành; bảng chi tiết; **Xuất Excel**.

### 8.5. `/accountant/notifications`
Mục 4.4 (nhận + soạn `ROLE`/`CLASS`/`USER`). Thông báo tự động "học phí quá hạn" cũng gửi cho KT.

### 8.6. `/accountant/logs` *(bổ sung)*
`AuditLogScreen` với `scope=finance` cố định.

**Prompt (tuition list):**
```
Accountant tuition screen. Top bar: semester picker and button "Tính học phí hàng loạt". Filter chips (ngành, lớp, trạng thái). Dense table with right-aligned currency columns: Tổng tiền, Miễn giảm, Phải nộp, Đã thu, Còn nợ, Cần hoàn, and status chip (CHUA_TINH, CON_NO, CHO_HOAN_TIEN, DA_DONG) with a red "Quá hạn" tag. Right drawer with transaction history and receipt download. Dialog "Ghi thu / Ghi hoàn": segmented THU/HOAN, amount with max helper, payment method, receipt code. Vietnamese.
```

---

## 9. ADMIN — Web only (7 route)

Admin xử lý *tài khoản & hệ thống*, **không** có quyền nghiệp vụ đào tạo/tài chính (menu không hiện).

> **Mockup Claude Design:** đã dựng đủ 7 màn Web Quản trị (`AD-Web-*.dc.html`: Tổng quan, Tài khoản, Ma trận quyền, Cấu hình hệ thống, Sao lưu, Thông báo, Nhật ký). Giao diện dùng tên gọi thường ("Máy chủ ứng dụng", "Cơ sở dữ liệu", "Bộ nhớ đệm", "Tác vụ chạy nền") thay cho tên kỹ thuật; nhật ký Admin có bộ chọn phạm vi Tất cả / Đào tạo / Tài chính / Hệ thống.

### 9.0. `/admin` — Tổng quan
- Thẻ **Sức khỏe hệ thống** (`/api/health/`): API · DB · Redis · Celery · job gần nhất lỗi (nếu có).
- Thẻ số tài khoản theo vai trò + số tài khoản đang khóa (dùng `count` của `/api/users/?role=&is_locked=`).
- Backup gần nhất (tên, thời gian, dung lượng) với cảnh báo vàng nếu > 48 giờ chưa có backup mới.
- 10 dòng audit log mới nhất; lối tắt Tài khoản · Cấu hình · Sao lưu.

### 9.1. `/admin/accounts` — Tài khoản (ADM-02, ADM-03)
- Bảng: username · họ tên (từ hồ sơ, nếu có) · email · vai trò (chip) · hồ sơ (✓ / "Chưa có hồ sơ" cho SV/GV) · trạng thái (Hoạt động/Khóa) · đăng nhập gần nhất. Lọc vai trò, trạng thái khóa; tìm username/email.
- **Tạo tài khoản:** username, email, mật khẩu ban đầu, **vai trò** (5 giá trị). Với SV/GV, thêm dòng gợi ý: "Phòng đào tạo sẽ tạo hồ sơ học vụ". Không tạo hồ sơ ở đây (đó là của PĐT).
- **Sửa:** email, vai trò (đổi vai trò = `PHAN_QUYEN` trong audit log; có `ConfirmDialog`).
- **Khóa / mở khóa** (công tắc, `PATCH …/lock/`): `ConfirmDialog` nêu rõ "Khóa sẽ chặn cả phiên đang đăng nhập". Admin **không tự khóa chính mình** (nút disable).
- **Reset mật khẩu** (`POST …/reset-password/`): đặt mật khẩu mới; dialog nhắc chuyển cho người dùng.
- **Tra cứu hồ sơ (ADM-03):** drawer chi tiết hiển thị hồ sơ học vụ **chỉ đọc** + nhãn "Chỉnh sửa tại Phòng đào tạo".
- *Không có Xóa tài khoản* (plan chỉ có khóa).

### 9.2. `/admin/permissions` — Ma trận quyền (ADM-04)
**Chỉ đọc.** Bảng hàng = quyền, cột = Admin/PĐT/SV/GV/KT, ô = ✓ · ✗ · *(giới hạn: của mình / lớp mình / scope)* — nội dung lấy từ `GET /api/admin/permissions/` (nguồn: plan mục 9, cố định trong code). Banner: "Ma trận được định nghĩa trong mã nguồn; chỉ thay đổi vai trò khi tạo/sửa tài khoản." **Không có nút Lưu, không có checkbox sửa được.**

### 9.3. `/admin/config` — Cấu hình hệ thống (ADM-05)
Đúng **6 khóa** (form theo nhóm, mỗi ô có mô tả + giá trị mặc định + nút "Đặt lại mặc định"):

| Nhóm | Khóa | Mặc định | Kiểm tra |
| :--- | :--- | :---: | :--- |
| Điểm danh (BR-20) | `max_absent_pct` | 20 | 0–100 |
| Điểm (BR-13) | `so_ngay_cho_phep_nhap_diem` | 14 | nguyên ≥ 0 |
| Sao lưu | `backup_retention_days` | 30 | nguyên ≥ 1 |
| Nhận chuyển khoản học phí | `ck_ngan_hang` | — | chuỗi, bắt buộc |
| | `ck_so_tai_khoan` | — | chỉ chữ số, bắt buộc |
| | `ck_chu_tai_khoan` | — | chữ in hoa không dấu, bắt buộc |

`PATCH /api/admin/config/`; lưu theo từng nhóm; thay đổi áp dụng cho thao tác *sau đó* (không tính lại dữ liệu cũ) — ghi chú nhỏ. Hiện người sửa + thời gian gần nhất nếu API trả.

### 9.4. `/admin/notifications`
Mục 4.4: soạn mọi `audience` (toàn hệ thống qua `ROLE`), thu hồi thông báo của bất kỳ ai (ADM-07).

### 9.5. `/admin/logs` — Audit log (ADM-06)
- Widget **`AuditLogScreen`** dùng chung 3 route (Admin / PĐT / KT):
  | Route | `scope` | Phạm vi đối tượng |
  | :--- | :--- | :--- |
  | `/admin/logs` | `all` (Admin chọn được tất cả/training/finance/hệ thống) | tất cả, gồm SystemConfig & backup |
  | `/pdt/logs` | `training` (cố định) | User/Profile, Major, Curriculum, Course, Semester, ClassSection, Schedule, Registration, Attendance, Grade, Notification… |
  | `/accountant/logs` | `finance` (cố định) | HocPhanGia, TuitionConfig, Discount, Payment, Tuition |
- Lọc: người thực hiện · hành động (`CREATE`/`UPDATE`/`DELETE`/`LOGIN`/`PHAN_QUYEN`) · đối tượng · khoảng thời gian. Cột: thời gian · người dùng · hành động (chip) · đối tượng + id · IP · nút mở **chi tiết JSON** (diff trước/sau dạng cây có thể thu gọn). Chỉ đọc; phân trang.
- Server tự lọc theo vai trò: UI **không** tin tham số `scope` từ client để mở rộng quyền (route PĐT/KT không có bộ chọn scope).

### 9.6. `/admin/backups` — Sao lưu (ADM-08)
- Nút **Tạo backup ngay** (`POST /api/admin/backups/`, chạy nền → thẻ trạng thái "Đang chạy…", tự làm mới danh sách).
- Bảng: tên file · thời gian · dung lượng (`GET /api/admin/backups/`). Ghi chú: "Tự động lúc 02:00 hằng ngày, giữ `backup_retention_days` ngày."
- **Không có Phục hồi/Tải xuống** trong UI. Khung hướng dẫn: "Khôi phục thực hiện thủ công bằng `pg_restore` trên máy chủ."

**Prompt (Admin accounts):**
```
Admin accounts screen. Toolbar: search, role filter chips (Admin, PĐT, SV, GV, KT), lock-status filter, button "+ Tạo tài khoản". Table: username, họ tên, email, role chip, "Chưa có hồ sơ" amber badge for SV/GV, status switch (Hoạt động / Khóa), row menu (Sửa, Đặt lại mật khẩu). Right drawer shows read-only academic profile with a note "Chỉnh sửa tại Phòng đào tạo". No delete action. Vietnamese.
```

---

## 10. Luồng chéo vai trò (kiểm tra tính nhất quán)

| # | Luồng | Chuỗi màn hình |
| :--- | :--- | :--- |
| 1 | Người dùng mới | Admin `/admin/accounts` tạo user → PĐT `/pdt/profiles` tạo hồ sơ (gán `ctdt`) → người dùng đăng nhập |
| 2 | Chuẩn bị học kỳ | PĐT: ngành → CTĐT → môn/tiên quyết → gán môn → học kỳ + cửa sổ → lớp + lịch → Mở học kỳ → Mở lớp. KT: giá + hạn đóng (làm *trước* khi SV đăng ký để học phí không rơi vào `CHUA_CAU_HINH_GIA`) |
| 3 | Đăng ký | SV `/student/register` → thông báo xác nhận → học phí tự tính → SV xem `/student/tuition` |
| 4 | Thu tiền | KT `/accountant/tuition` ghi `THU` → `con_no` giảm; quá hạn → job thông báo SV + KT → `/accountant/debts` |
| 5 | Hủy hộ có hoàn tiền | PĐT hủy hộ (lý do) → học phí tính lại → `can_hoan > 0` → KT thấy ở *Công nợ → Chờ hoàn* → ghi `HOAN` |
| 6 | Điểm danh sai | SV xin sửa → GV (lớp mình) hoặc PĐT duyệt → bản điểm danh cập nhật → tỷ lệ vắng đổi |
| 7 | Điểm | GV nhập → khóa `CHINH_THUC` → lớp `DA_DONG` → PĐT duyệt `KHOA` → SV thấy điểm + GPA, nhận thông báo. Quá hạn: PĐT gia hạn / nhập hộ |
| 8 | Khóa tài khoản | Admin khóa → mọi request kể cả refresh bị `403 TAI_KHOAN_BI_KHOA` → client về `/login` |

---

## 11. Bảng đối chiếu chức năng (59 CN)

| Vai trò | CN → Màn hình |
| :--- | :--- |
| **SV (13)** | 01 `/login` · 02 `/student/profile` · 03 `/student/curriculum`* · 04–05 `/student/register` tab 1 · 06 `/student/auto-schedule` · 07 `/student/register` tab 2 · 08 `/student/schedule` · 09 `/student/register` tab 3 · 10 `/student/attendance` · 11 `/student/grades` · 12 `/student/tuition` · 13 `/student/notifications` |
| **GV (12)** | 01 `/login` · 02 `/teacher/profile` · 03–04 `/teacher/classes` · 05 `/teacher/classes` tab Lịch dạy · 06–09 `/teacher/attendance` · 10 `/teacher/grades` · 11 `/teacher/notifications` · 12 `/teacher/classes` (Xuất Excel) |
| **PĐT (15)** | 01 `/pdt/profiles`* · 02 `/pdt/faculties`* + `/pdt/majors` · 03 `/pdt/curriculums` · 04–05 `/pdt/courses` · 06–07 `/pdt/semesters` · 08–09 `/pdt/classes` · 10–11 `/pdt/registrations` (+ điểm danh trong `/pdt/classes`) · 12 `/pdt/grade-sheets` · 13 `/pdt/notifications` · 14 `/pdt/reports` · 15 bộ lọc/tìm kiếm ở mọi bảng |
| **KT (11)** | 01–05 `/accountant/config` · 06–08, 10 `/accountant/tuition` · 09 `/accountant/debts` · 11 `/accountant/reports` |
| **Admin (8)** | 01 `/login` · 02–03 `/admin/accounts` · 04 `/admin/permissions` · 05 `/admin/config` · 06 `/admin/logs` (+ PĐT/KT logs*) · 07 `/admin/notifications` · 08 `/admin/backups` |

\* route bổ sung, chưa có trong plan 10.3.

---

## 12. Ghi chú triển khai Flutter

- Cấu trúc `lib/` theo plan 10.2: `routes_<role>.dart` mỗi vai trò một file; `router_web.dart` ghép 5 vai trò; `router_app.dart` chỉ ghép `routes_student` + `routes_teacher` (build App không kéo màn Admin/PĐT/KT).
- Widget dùng chung đặt `shared/widgets`: `StatusChip`, `DataTable`/`CardList` (tự đổi theo breakpoint), `SemesterPicker`, `ClassPicker`, `WarningsBanner`, `ConfirmDialog`, `AuditLogScreen`, `GradeGrid` (dùng cho GV nhập điểm **và** PĐT nhập hộ), `WeeklyGrid` (TKB SV/GV, preview lịch PĐT).
- Preview tổng kết điểm & thang chữ: một hàm thuần Dart duy nhất, test đơn vị bằng các ca của plan mục 13 (8.45/6.95/5.45, biên 8.50/7.00/5.50/4.00, 3.99, thiếu GK, CK NULL vs 0, `DAT_KHONG_DAT`). Server vẫn là kết quả cuối cùng.
- Offline: chỉ cache-API read-only cho TKB/điểm đã tải (SV/GV); không viết service worker riêng.
- Export (Excel) do backend sinh qua `?format=xlsx`; client chỉ tải/chia sẻ file.
- Seed demo (`seed_demo`) phải đủ để dựng các trạng thái UI: lớp `MO`/`DANG_HOC`/`DA_DONG`, lớp `si_so_toi_da=2`, SV điểm D và F, SV vắng 3/10, lịch thứ 7 + Chủ nhật, cặp trùng giờ.

---

## 13. Quyết định thiết kế (đã đồng bộ vào `plan.md`)

Các điểm sau đã được ghi vào `plan.md` (trừ mục 10 là việc của mã Flutter):

| # | Nội dung chốt | Sửa trong plan |
| :--- | :--- | :--- |
| 1 | Thêm 4 route: `/pdt/profiles` (PDT-01), `/student/curriculum` (SV-03), `/pdt/logs` và `/accountant/logs` (ADM-06 cho PĐT/KT, dùng chung `AuditLogScreen`) | Mục 10.3 + `routes_<role>.dart` |
| 2 | Trần tín chỉ nằm trên `Semester` (PĐT đặt) ⇒ `GET /api/courses/available/` trả thêm `meta{tin_chi_toi_da, tin_chi_toi_da_canh_bao}`; `GET /api/attendance/my/` trả cờ `canh_bao_vang` mỗi lớp | Mục 8.1 (Sinh viên) |
| 3 | `GET /api/tuition/my/` trả thêm `chi_tiet[]` (môn, TC LT/TH, thành tiền) và `payments[]` | Mục 8.1 + mục 5 (Tuition) |
| 4 | PĐT "nhập hộ" điểm lưu thẳng `CHINH_THUC` | BR-13 |
| 5 | Không có nút/endpoint chuyển lớp `MO` → `DANG_HOC` thủ công; chỉ job `classes_transition_daily` | Mục 6 (bỏ chữ "hoặc PĐT bấm" ở `DANG_HOC`) |
| 6 | Buổi điểm danh chuyển `MO` → `DA_DIEM_DANH` ở lần `PUT records` thành công đầu tiên | Mục 5 (AttendanceSession) |
| 7 | Dashboard chỉ ghép từ endpoint sẵn có (dùng `count` của list phân trang); không thêm endpoint tổng hợp | — |
| 8 | Bỏ tiện ích "đếm người nhận thông báo" và "thử tra giá" (không có endpoint) | — |
| 9 | Đổi mật khẩu ⇒ client đăng xuất, yêu cầu đăng nhập lại (vì refresh cũ bị blacklist) | — |
| 10 | `app_theme.dart`: đổi seed `0xFF1A56DB` → `#3F51B5`, thêm secondary teal `#009688` | Mã Flutter (checklist 1.4) |
| 11 | Mỗi môn chỉ đăng ký một lớp trong một học kỳ — UI ẩn các lớp còn lại của môn đã đăng ký; backend chặn bằng BR-04(d), `DA_DANG_KY_MON` (409) | Đã chốt (plan v3.6) |
| 12 | Trần tín chỉ (tối thiểu / tối đa / tối đa khi cảnh báo học vụ) do **PĐT** đặt theo từng học kỳ, không còn ở cấu hình hệ thống của Admin | Đã chốt (plan v3.7) |
| 13 | Thêm danh mục **Khoa / viện** do PĐT quản lý (`/pdt/faculties`); ngành, môn học, giáo viên trỏ tới khoa/viện; ngừng chỉ khi không còn ngành/giáo viên hoạt động | Đã chốt (plan v3.8) |
| 14 | Danh sách dài là ô gõ để tìm (bấm là hiện đủ, gõ không dấu vẫn khớp); bộ lọc liên động ngành → môn → giáo viên cùng khoa/viện; UI không hiện mã trạng thái kỹ thuật | Chỉ là quy ước giao diện (mục 7) |
