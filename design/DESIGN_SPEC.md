# DESIGN SPEC — Hệ thống Đăng ký Môn Học

**Nguồn:** `plan.md` v2.4.1 · **Nền tảng:** Flutter Material 3 (Web + App) · **Áp dụng cho:** mọi mockup trong `design/mockups/` và mọi màn Flutter sau này.

> File này là nguồn sự thật cho màu / chữ / spacing / component. Mọi mockup HTML dùng đúng token tại đây. Khi import vào Figma, tạo **Variables** theo đúng tên token.

---

## 0. BẢN SẮC HỆ THỐNG — "ACADEMIA ẤM"

Khác biệt có chủ đích so với dashboard AI xanh-indigo thông thường:

| Yếu tố | Quyết định | Vì sao riêng |
| :--- | :--- | :--- |
| Nền trang | **Kem ngà `#FAF7F2`** (không phải xám lạnh) | Ấm áp, kiểu giấy vở học đường |
| Primary | **Xanh rêu `#2D6A4F`** (emerald đậm) | Không phải indigo/xanh dương mặc định |
| Accent phụ | **Cam đất `#D97706`** (honey/terracotta) | Action phụ, hover, số nổi bật, vạch CreditProgress |
| Sidebar | **Than xanh `#1F2937`** đặc, chữ ngà, nav-active là pill rêu | Tương phản khối, nhìn xa vẫn ra app "trường mình" |
| Font chữ | **Be Vietnam Pro** (toàn bộ UI) | Font do người Việt thiết kế, dấu tiếng Việt chuẩn; Google Fonts có sẵn; Flutter dùng `google_fonts` — KHÔNG dùng Roboto |
| Bo góc | Card **16px**, nút/chip **pill 999px**, input 12px | Mềm, thân thiện sinh viên |
| Đổ bóng | `0 2px 8px rgba(31,41,55,.06), 0 1px 2px rgba(31,41,55,.04)` | Bóng ấm rất nhẹ — phẳng, không "floating" |
| Icon | **Material Symbols Rounded** | Khớp rounded family của `flutter/material`; không dùng emoji |
| TKB | **Mỗi môn 1 màu pastel riêng** (bảng 1.4) | Nhận biết môn bằng màu — đặc trưng nhất của màn SV/GV |

---

## 1. COLOR TOKENS

Quy ước tên: `--m3-<nhóm>-<tên>`. Dark mode khai báo đè trên `[data-theme="dark"]`.

### 1.1. Brand

| Token | Light | Dark | Dùng |
| :--- | :--- | :--- | :--- |
| `--bg-page` | `#FAF7F2` | `#141D18` | Nền trang (kem ngà / xanh than đậm) |
| `--m3-primary` | `#2D6A4F` | `#74C69D` | Nút chính, link, nav active, focus |
| `--m3-on-primary` | `#FFFFFF` | `#0E2A1D` | Chữ trên nền primary |
| `--m3-primary-container` | `#DCEDE3` | `#1F3D2E` | Nền nhánh active, chip "đã chọn" |
| `--accent` | `#D97706` | `#E8A33D` | Cam đất — action phụ, số nổi bật |
| `--m3-error` | `#B3402F` | `#E77A67` | Lỗi, CON_NO, CAM_THI (đỏ đất) |
| `--m3-surface` | `#FFFFFF` | `#1C2620` | Nền card, table |
| `--sidebar-bg` | `#1F2937` | `#0F171F` | Sidebar than (cả 2 theme tối màu) |
| `--sidebar-text` | `#E5E1D8` | `#E5E1D8` | Chữ sidebar |
| `--m3-surface-variant` | `#F3EEE5` | `#223028` | Stripe bảng, nền phụ |
| `--m3-outline` | `#EAE4D9` | `#33413A` | Border card/input/table (ấm) |
| `--m3-on-surface` | `#212B25` | `#EAE6DD` | Chữ chính |
| `--m3-on-surface-variant` | `#6B7268` | `#A8A296` | Chữ phụ, label, caption |

### 1.2. Semantic trạng thái nghiệp vụ (map trực tiếp enum `plan.md`)

Chấm tròn 6px màu fg luôn đi kèm chip. Dark mode = nền dịt + chữ sáng cùng tông.

**Lớp học phần (`ClassSection.trang_thai` — mục 10):**

| Enum | Chip bg | Chip fg | Ý nghĩa UI |
| :--- | :--- | :--- | :--- |
| `KE_HOACH` | `#EFEAE2` | `#8A7E6A` | Ấm xám — chưa mở |
| `MO` | `#E7F2EA` | `#2D6A4F` | Rêu — đang mở đăng ký |
| `DANG_HOC` | `#E8EEF7` | `#3B5B92` | Xanh dương trầm — đang diễn ra |
| `DA_DONG` | `#E5E0D8` | `#6B6252` | Nâu xám — kết thúc, chỉ đọc |

**Điểm (`Grade.trang_thai` — BR-14) & đơn học lại (`GradeRetake.trang_thai`):**

| Enum | Chip bg | Chip fg |
| :--- | :--- | :--- |
| `NHAP_TAM` | `#FDF0DC` | `#B45309` |
| `CHINH_THUC` | `#E8EEF7` | `#3B5B92` |
| `KHOA` | `#E7F2EA` | `#2D6A4F` |
| `CHO_DUYET` | `#FDF0DC` | `#B45309` |
| `DUYET` | `#E7F2EA` | `#2D6A4F` |
| `TU_CHOI` | `#FBEAE6` | `#B3402F` |

**Đăng ký (`Registration.trang_thai`):** `DA_DANG_KY` = `#E8EEF7`/`#3B5B92`, `DA_HUY` = `#E5E0D8`/`#6B6252` (tên lớp gạch mờ).

**Học phí (`Tuition.trang_thai` — mục 10):**

| Enum | Chip bg | Chip fg |
| :--- | :--- | :--- |
| `CHUA_TINH` | `#EFEAE2` | `#8A7E6A` |
| `DA_TINH` | `#E8EEF7` | `#3B5B92` |
| `DA_DONG` | `#E7F2EA` | `#2D6A4F` |
| `CON_NO` | `#FBEAE6` | `#B3402F` |
| `GIAM_TRU` | `#E0F2EF` | `#0F766E` |
| `CHO_HOAN_TIEN` | `#FDF0DC` | `#B45309` |
| `DA_HOAN_TIEN` | `#EDE7F6` | `#6D4FA1` |

**Điểm danh (BR-19):**

| Giá trị | Màu | Dùng |
| :--- | :--- | :--- |
| `CO_MAT` | rêu `#2D6A4F` | Nút radio/badge |
| `VANG_CO_PHEP` | xanh dương trầm `#3B5B92` | |
| `VANG_KHONG_PHEP` | đỏ đất `#B3402F` | |
| `DI_TRE` (cờ riêng) | cam đất `#B45309` | Checkbox/toggle **riêng**, không thay 3 trạng thái trên |
| `CAM_THI` (cờ BR-24) | `#B3402F` nền `#FBEAE6` | Chip "CẤM THI" đậm 700, tooltip ngưỡng 20% |

### 1.3. Màu cảnh báo & khối kiến thức

- **Banner cảnh báo (không chặn):** nền `#FDF0DC`, viền trái 4px `#D97706`, icon cam đất.
- **Banner lỗi (chặn):** nền `#FBEAE6`, viền trái 4px `#B3402F`.
- **Banner thông tin:** nền `#DCEDE3`, viền trái 4px `#2D6A4F`.
- **Khối kiến thức (5 khối):** `chung` = `#8A7E6A`, `co_so_nganh` = `#3B5B92`, `chuyen_nganh` = `#2D6A4F`, `tu_chon` = `#0F766E`, `tot_nghiep` = `#B45309`.

### 1.4. Màu pastel TKB theo môn (đặc trưng màn SV/GV)

Mỗi `ClassSection` lấy màu theo chỉ số trong danh sách học kỳ (round-robin) — SV nhận biết môn qua màu:

| # | Tên | bg | fg |
| :--- | :--- | :--- | :--- |
| 1 | Rêu | `#CDE7D8` | `#2D6A4F` |
| 2 | Cát | `#F6E3C5` | `#92600A` |
| 3 | Hồng đất | `#F4D8DA` | `#A3454F` |
| 4 | Oải hương | `#E3DCEE` | `#5B4B8A` |
| 5 | Xanh biển nhạt | `#D3E4EF` | `#2F6288` |
| 6 | Ô liu | `#E8EBD3` | `#5F6B1F` |

(Block TKB: nền bg, viền trái 3px fg, chữ fg đậm 600.)

---

## 2. TYPOGRAPHY — Be Vietnam Pro (không Roboto)

Import Flutter: package `google_fonts` với `BeVietnamPro`. Web mockup: Google Fonts `<link>`.

| Style | Size/Line | Weight | Dùng |
| :--- | :--- | :--- | :--- |
| `display-small` | 36/44 | **700** | Số lớn dashboard (tổng SV, tổng thu) |
| `headline-small` | 24/32 | **700** | Tiêu đề trang |
| `title-large` | 20/28 | **600** | Tên màn trong topbar |
| `title-medium` | 16/24 | **600** | Tiêu đề card, tên môn |
| `title-small` | 14/20 | **600** | Label section (HOA, letter-spacing 1px) |
| `body-medium` | 14/20 | 400 | Chữ thân bảng, form |
| `body-small` | 12.5/18 | 400 | Caption, meta (mã SV, ngày) |
| `label-large` | 14/20 | **600** | Text nút |
| `label-medium` | 12/16 | **600** | Text chip |

- Section label: 11px, 600, HOA, letter-spacing 1px, màu `on-surface-variant`.
- Số bảng: `font-variant-numeric: tabular-nums`; số tiền/KPI weight 700.
- Số KPI lớn dùng màu nhấn rêu hoặc cam đất.

---

## 3. SPACING & LAYOUT

- **Grid 4dp**: mọi khoảng = bội 4 (4/8/12/16/24/32/48).
- **Breakpoint** (mục 15.4): `< 600` mobile (bottom-nav + drawer) · `600–1024` tablet (NavigationRail 80px) · `> 1024` desktop (drawer **280px** + topbar).
- **AppShell desktop:** sidebar than 280px + vùng nội dung max-width 1200px, padding 24px.
- **Topbar cao 64px**, nền `bg-page`, phân tách border `outline`: breadcrumb · search pill · chip đếm ngược cửa sổ ĐK (nếu có) · NotificationBell · avatar ring rêu.
- **Touch target ≥ 48px** (mục 15.4).
- **DataTable:** header 48px nền `surface-variant` (title-small HOA 11px), row 56px, stripe `surface-variant`, border dưới 1px `outline`.
- **ScheduleGrid (TKB — BR-08):** 6 cột Thứ 2 → CN; 15 tiết chia 3 nhóm Sáng 1–5 / Chiều 6–10 / Tối 11–15; ô 28px; block = màu 1.4 + viền trái 3px; separator nhóm 2px.

---

## 4. COMPONENTS

### 4.1. StatusChip
Pill 20px, `label-medium`, nền/fg bảng 1.2, **kèm chấm tròn 6px màu fg**. Đỏ chỉ cho lỗi/nợ/cấm thi.

### 4.2. CreditProgress (BR-07)
Thanh 10px bo tròn trên `surface-variant`: fill rêu; vạch tối thiểu 12 (2px `on-surface-variant`); vạch tối đa 24 (2px cam đất); vùng cảnh báo học vụ = vạch cam + chữ "Trần 14 TC". Số bên phải `18/24` weight 700 màu rêu.

### 4.3. FilterBar
Card bo 16: select/input pill + nút. Nút chính rêu, phụ viền outline chữ rêu.

### 4.4. FormField
Label title-small trên, input 48px bo 12px, border 1px `outline`, focus 2px rêu. Error: border đỏ đất + helper đỏ.

### 4.5. Dialog xác nhận
Bo 20px, header 700, footer: TextButton hủy (rêu) + FilledButton rêu; nguy hiểm → nút đỏ đất.

### 4.6. Banner
48–56px, bo 12px, viền trái 4px + icon, nền mục 1.3, action link cam đất.

### 4.7. NotificationBell
Icon Material Symbols Rounded + badge đỏ đất 18px. Panel bo 16px, chấm rêu chưa đọc.

### 4.8. AttendanceRow (GV)
Row 56px: [avatar monogram 32px nền pastel 1.4 + tên + mã SV] · 3 nút radio pill (chọn = nền màu 1.2) · checkbox DI_TRE riêng · chip CẤM THI nếu có. Footer sticky bo 16 shadow-up: tổng hợp + nút Lưu buổi.

### 4.9. DataCard
Bo 16px, nền surface, border `outline`, padding 20px: label section-style + giá trị display + trend. **Điểm nhấn:** viền trên 3px màu nhóm (rêu = học vụ, cam = tài chính, xanh dương trầm = lớp học).

### 4.10. Empty state
Icon 48px màu `outline`, title-medium, body + TextButton cam đất.

---

## 5. ICON

**Material Symbols Rounded** (không emoji): `login`, `school`, `co_present`, `domain`, `payments`, `admin_panel_settings`, `notifications`, `calendar_month`, `playlist_add_check`, `grade`, `account_balance_wallet`, `history`, `cloud_download`, `schedule`, `check_circle`, `warning`, `error`, `search`, `menu_book`, `repeat`, `campaign`, `auto_awesome`, `logout`.

---

## 6. QUY TẮC ĐỐI CHIẾU NGHIỆP VỤ (checklist khi vẽ bất kỳ màn nào)

1. Mọi trạng thái enum dùng StatusChip đúng màu bảng 1.2 — không tự chế màu mới.
2. Cờ `cam_thi` LUÔN là chip đỏ đất "CẤM THI" cạnh tên SV — không lẫn trạng thái điểm danh (BR-19 vs BR-24).
3. `DI_TRE` là control riêng, không thay 3 trạng thái điểm danh.
4. Warning (không chặn) = cam đất; Error (chặn) = đỏ đất. Không đảo.
5. TKB luôn 15 tiết × 3 nhóm buổi (BR-08); block môn = màu 1.4 + đủ `so_tiet_moi_buoi`.
6. Số tiền: `1.234.567 ₫`, tabular-nums, căn phải.
7. Font **Be Vietnam Pro** mọi nơi; kiểm tra dấu tiếng Việt render chuẩn.
8. Màn SV chỉ hiện dữ liệu "của mình" (BR-23); GV chỉ lớp phụ trách.
9. Không dùng emoji làm icon trong UI thật.
