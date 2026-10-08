# Design — Hệ thống Đăng ký Môn học

Phác thảo UI cho `plan.md` (Flutter Material 3 + GoRouter + Riverpod). 5 màn chính đã có
mockup full-color; ~27 màn phụ có wireframe mức thấp.

```
design/
├── DESIGN_SPEC.md               # Design system: màu/chữ/spacing/component (nguồn sự thật)
├── wireframes.svg               # 27 wireframe màn phụ (import thẳng Figma)
├── mockups/
│   ├── 01_login.html            # Đăng nhập (5 role · rate-limit error · dark)
│   ├── 02_student_register.html # SV đăng ký môn học (BR-01..07 · TKB · học phí BR-15)
│   ├── 03_teacher_attendance.html # GV điểm danh (BR-19 3 trạng thái + DI_TRE + CẤM THI BR-24)
│   ├── 04_pdt_class_sections.html # PĐT lớp HP (4 trạng thái · dialog đặt lịch BR-08/09)
│   ├── 05_accountant_tuition.html # KT học phí (7 trạng thái · dialog thu · BR-05/15)
│   └── mobile/
│       └── 00_student_app.html  # App mobile SV 5 frame 390×844 — style "Campus Navy"
│                                 # (tham chiếu UI/UX Figma node 373-534: header navy
│                                 #  #1F2A44, accent cam #F97316, thẻ bo 20px, nav pill nổi)
└── README.md
```

## Cách đưa vào Figma

### A. Mockup HTML → Figma (plugin **html.to.design** — khuyến nghị)

1. Mở file `mockups/*.html` trong Chrome/Edge để xem trước (`file:///D:/HeThongDangKyMonHoc/design/mockups/02_student_register.html`).
2. Trong **Figma Desktop App**: Menu → Plugins → tìm **html.to.design** → cài (miễn phí).
3. Chạy plugin → chọn tab **Import** → dán URL `file:///...` hoặc kéo thả file HTML vào.
4. Chọn **Import as: Responsive** → tick breakpoint **1440px** (desktop) rồi import lần nữa với **390px** (mobile) nếu muốn frame mobile.
5. Layer vào Figma đầy đủ (màu, text, spacing tách layer) — chỉnh sửa được như layer thường.

**App mobile (`mockups/mobile/00_student_app.html`):** 1 file chứa 5 frame 390×844 đặt cạnh nhau
(01 Trang chủ · 02 Đăng ký môn học · 03 Thời khóa biểu · 04 Học phí · 05 Hồ sơ) — import **một lần**
là ra đủ 5 frame trong Figma, mỗi frame đúng kích thước iPhone, nội dung đã được nén vừa khít
(không bị cắt). Font **Be Vietnam Pro** + icon **Material Symbols Rounded** khớp luôn bộ Flutter.

**Dark mode:** trước khi import, bấm nút 🌙/☀ trên trang (hoặc chạy
`document.body.setAttribute('data-theme','dark')` trong DevTools) rồi import — mỗi theme 1 lần,
đặt 2 frame cạnh nhau trong Figma.

**Lưu ý:** bản free của html.to.design giới hạn số import/tháng — xem trước bằng browser trước,
chỉ import đúng file cần. Dialog (xác nhận đăng ký / tạo buổi / thu tiền) ẩn mặc định; muốn
import cả trạng thái dialog thì bật nút tương ứng trên trang trước khi import.

### B. Wireframe SVG → Figma (không cần plugin)

- Kéo thả `wireframes.svg` vào canvas Figma, hoặc File → Place image/`Ctrl+Shift+K`.
- File gộp 27 khung 480×300 (≈ desktop 1440×900 thu nhỏ). Muốn tách từng màn: trong Figma
  chọn group → `Ctrl+Alt+K` (crop) hoặc ungroup và copy khung cần dùng.
- SVG vào là vector, chỉnh được từng rect/text.

### C. Dựng design system trong Figma (từ DESIGN_SPEC.md)

1. Tạo file Figma mới → mở panel **Variables** (Local variables).
2. Tạo collection `tokens` với đúng tên token mục 1 của DESIGN_SPEC.md
   (`--m3-primary`, `--c-mo-bg`, …) — mỗi token 1 cột Light/Dark.
3. Tạo **Styles**: màu (theo mục 1), text (**Be Vietnam Pro** — mục 2, khớp Flutter qua `google_fonts`),
   effect (shadow ấm `0 2px 8px rgba(31,41,55,.06)`).
4. Dựng component theo mục 4: `StatusChip` (variant theo enum mục 1.2), `Button`
   (filled/tonal/text/error), `FormField`, `DataTable`, `AppShell` (sidebar 280 + topbar 64),
   `ScheduleGrid`, `AttendanceRow`, `CreditProgress`, `Banner`.
5. Icons: plugin **Material Symbols Rounded** — đúng bộ Flutter rounded family dùng.

## Checklist đối chiếu nghiệp vụ khi dựng/duyệt màn

- [ ] Mọi enum trạng thái dùng đúng màu bảng 1.2 DESIGN_SPEC.md (4 state lớp HP, 7 state học phí…)
- [ ] Chip **CẤM THI** (BR-24) tách riêng khỏi 3 trạng thái điểm danh (BR-19); **DI_TRE** là control riêng
- [ ] Warning (không chặn) = amber; Error (chặn) = đỏ — không đảo
- [ ] TKB: 6 cột × 15 tiết, 3 nhóm buổi (sáng 1–5 / chiều 6–10 / tối 11–15) — BR-08
- [ ] Số tiền `1.234.567 ₫`, tabular-nums, căn phải
- [ ] SV/GV chỉ thấy dữ liệu phạm vi mình (BR-23)
- [ ] CreditProgress: mốc tối thiểu 12 / tối đa 24, cảnh báo thiếu = amber (BR-07)

## Màn chưa vẽ

Wireframe mức thấp đã phủ ~27 màn phụ. Đợt sau có thể dựng mockup full-color cho nhóm nào
được ưu tiên (gợi ý: SV-12 TKB, GV-07 nhập điểm, KT-12 công nợ) — nói tên màn là tôi làm tiếp.
