# CHECKLIST TRIỂN KHAI — HỆ THỐNG ĐĂNG KÝ MÔN HỌC

> **Nguồn:** `plan.md` v2.5 (nguồn duy nhất). File này để theo dõi tiến độ triển khai.
> **Cách dùng:** tick `[x]` khi hoàn thành; mỗi pha phải đạt **Milestone** + **DoD** (mục 18 của file này; gốc ở plan.md mục 22) mới sang pha sau.
> **Thời lượng:** ~14 tuần (7 người) / ~20 tuần (5 người).

> **Nền tảng theo vai trò (v2.5):**
> - **SV + GV** → Flutter **Web + App** (Android/iOS).
> - **Admin + PĐT + KT** → **chỉ Flutter Web** (nghiệp vụ nặng, bảng dữ liệu lớn, thao tác bàn phím).
> - Một codebase Flutter duy nhất; khi build App chỉ đóng gói route `/login`, `/forgot-password`, `/student/*`, `/teacher/*`.

---

## 0. TỔNG QUAN NHANH

| Hạng mục | Số lượng |
| :--- | :--- |
| Thực thể DB | 27 |
| Quy tắc nghiệp vụ (BR) | 25 (BR-01..25) |
| Chức năng | 63 (PDT-16, SV-14, GV-12, KT-13, ADM-08) |
| Vai trò | 5 (Admin, PĐT, SV, GV, KT) |
| API endpoint | ~70 |
| Celery job | 5 |
| Pha triển khai | 12 dòng theo dõi (Pha 0 → Pha 10, tách riêng 6b) |

**Kiến trúc:** Flutter Web + App (Material 3 · GoRouter · Riverpod · Dio — SV/GV cả 2 nền tảng; Admin/PĐT/KT Web only) → Django REST (JWT) → PostgreSQL 16. Backend là nguồn sự thật duy nhất.

**Bố cục repo (monorepo):**
```
HeThongDangKyMonHoc/            ← git root
├── backend/                    ← tạo mới (Django — cây ở plan.md mục 2)
├── dang_ky_mon_hoc/            ← Flutter project ĐÃ CÓ SẴN — giữ nguyên vị trí
├── design/                     # mockup HTML
├── plan.md · checklist.md · chuc_nang.md
└── .github/workflows/ci.yml    ← 2 job theo path: backend/** và dang_ky_mon_hoc/**
```

---

## 1. PHA 0 — NỀN TẢNG (1 tuần)

### 1.1. Repo & CI
- [x] **Chuẩn bị repo (Bước 0):**
  - [x] Commit hiện trạng — Flutter skeleton (`dang_ky_mon_hoc/`) + `checklist.md` + `plan.md` + `chuc_nang.md` + `design/` ← đã commit (`c0cee53`, kèm backend skeleton + CI)
  - [x] Xóa `linux/`, `macos/`, `windows/` khỏi `dang_ky_mon_hoc/` (chỉ giữ `android/`, `ios/`, `web/` — cần lại thì `flutter create --platforms=linux .`) ← đã stage, chờ commit
  - [x] `.gitignore` bổ sung: `.idea/`, `*.iml`, `.dart_tool/` (đã có sẵn từ trước)
- [x] Bố cục monorepo: `backend/` tạo mới cùng cấp với `dang_ky_mon_hoc/` (giữ nguyên tên thư mục Flutter — package name lấy từ `pubspec.yaml`); docker-compose đặt tại `backend/`; `plan.md`/`checklist.md`/`chuc_nang.md`/`design/` ở repo root
- [x] Repo backend (`backend/`) + Flutter dùng chung 1 repo
- [x] CI: job `backend` (ruff + mypy + pytest) — trigger theo path `backend/**` (`dorny/paths-filter`)
- [x] CI: job `flutter` (analyze + test) — trigger theo path `dang_ky_mon_hoc/**` (`dorny/paths-filter`)
- [x] Pre-commit: `black` + `ruff` + `dart format` (`.pre-commit-config.yaml`)
- [x] `.gitignore` loại `.env`, `__pycache__`, build artifacts

### 1.2. Docker & môi trường
- [x] `docker-compose.yml`: web (Django+Gunicorn) + db (PostgreSQL 16) + redis + celery worker + celery beat + nginx
- [x] `Dockerfile` backend (Python 3.12 + Gunicorn, `docker-entrypoint.sh` chờ DB → migrate → collectstatic)
- [x] `.env.example` commit kèm giá trị mẫu (plan.md mục 23)
- [x] `.env` thật **không commit** (`.gitignore` + `.dockerignore`)
- [x] `docker-compose up -d` chạy được toàn bộ service — 6/6 healthy, `curl /api/docs/` → 200
  - Lưu ý máy dev: host 8000 bị Docker Desktop chiếm → web map `${WEB_PORT:-8010}:8000`, vào qua nginx `:80`

### 1.3. Django skeleton
- [x] Project `config/` (settings dev/prod, urls, wsgi, asgi)
- [x] `DJANGO_SETTINGS_MODULE`, `SECRET_KEY`, `DEBUG`, `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS` từ env
- [x] `core/exceptions.py` — envelope lỗi `{error: {code, message, details}}` + mã lỗi nghiệp vụ (plan.md mục 13.8)
- [x] `core/` — permissions, pagination, mixins (`AuditLogMixin`, `ScopeFilter`)
- [x] `django-filter` + phân trang (mặc định 25, tối đa 50)
- [x] `Idempotency-Key` middleware (plan.md mục 13.7)
- [x] `drf-spectacular` → Swagger `/api/docs/` + schema `/api/schema/` — route đã trả 200, **nội dung rỗng tới Pha 1** (chưa có viewset)
- [x] `django-celery-beat` + 5 job `jobs.*` (plan.md mục 11.8) — worker đã đăng ký đủ 5

### 1.4. Flutter skeleton
- [x] Project Flutter (Web + Android) — Flutter 3.47, đã có sẵn, giữ `android/` + `web/` + `ios/`
- [x] `core/api/` — Dio client + interceptor refresh token (`QueuedInterceptor`, 401 → refresh 1 lần → retry; refesh fail → xoá token về login)
- [x] `core/auth/` — `AuthController` (Riverpod `Notifier`: login/logout/restore phiên) + `TokenStorage` (`flutter_secure_storage`)
- [x] `core/router/` — GoRouter + route map theo role (plan.md mục 15.3), redirect theo `AuthState` + `refreshListenable`
- [x] `core/theme/` — Material 3 (`ColorScheme.fromSeed`, light + dark)
- [x] `shared/` — `widgets/placeholder_screen.dart` (giữ chỗ cho 40 route); `models/`, `utils/` bổ sung theo pha
- [x] **Route map theo vai trò: Admin/PĐT/KT chỉ Web; SV/GV Web + App** — `_webOnlyRoles` chặn bằng `kIsWeb`; route web-only mở trên App hiển thị màn "chỉ khả dụng trên trình duyệt"
- [x] Build được cả Web + App, không lỗi console — `flutter analyze` 0 issue, widget test pass, `flutter build web` + `flutter build apk --debug` OK (commit `c164e57`)

### 1.5. Seed data
- [x] Management command `seed_demo` (plan.md mục 24) — `apps/config/management/commands/seed_demo.py`, idempotent (`update_or_create`), mật khẩu qua env `SEED_DEMO_PASSWORD`
- [x] Tài khoản: 1 Admin, 2 PĐT, 2 KT, 3 GV, 10 SV — mật khẩu `Demo@12345` (log console khi chạy, không ghi repo)
- [x] 2 ngành × 1 CTĐT × 8 môn (6 bắt buộc + 2 tự chọn), đủ 5 khối kiến thức, 2 cặp tiên quyết (IT2010←IT1010, IT3010←IT2010)
- [x] 1 môn `loai_danh_gia = DAT_KHONG_DAT` (IT4020 Kỹ năng khởi nghiệp)
- [x] 2 học kỳ: 1 `DONG` (có điểm `KHOA`), 1 `MO` + cửa sổ đăng ký mở
- [x] 6 lớp HP: 4 `MO` (1 lớp `si_so_toi_da = 2` test BR-02/06), 1 `DANG_HOC`, 1 `DA_DONG` — `si_so_hien_tai` cập nhật theo đăng ký
- [x] Mỗi lớp 2 `Schedule`, có 1 cặp lịch trùng giờ (IT1010/IT2010 cùng thứ 2 tiết 1–3, test BR-03)
- [x] Bảng giá: `MAC_DINH` + 2 `NGANH` + 1 `KHOI_KIEN_THUC` + `LECH_LT` + `GIA_TH` + `TuitionConfig` (hạn đóng = cuối HK - 30 ngày)
- [x] `SystemConfig`: tín chỉ 12–24, `tin_chi_toi_da_canh_bao = 14`, `max_absent_pct = 20`, `so_ngay_cho_phep_nhap_diem = 14` (cả 5 tham số cũng đặt trên Semester `MO`)
- [x] 1 lớp có 10 buổi `DA_DIEM_DANH`, sv01 vắng 3/10 = 30% (test BR-20/BR-24); sv05 có 1 môn F → đơn học lại `DUYET` (BR-24); GPA cache sv01 = 3.99, sv02 = 2.10

**Milestone Pha 0:** Docker chạy, Swagger mở được, seed data nạp đầy đủ, Flutter build Web + App. ← **HOÀN THÀNH (2026-10-09):** 18 user / 2 ngành / 2 CTĐT / 8 môn / 6 lớp / 52 đăng ký / 20 điểm / 10 buổi điểm danh — `seed_demo` idempotent, chạy lại an toàn.

---

## 2. PHA 1 — AUTH & HỒ SƠ (1 tuần)

### 2.1. Backend — User & Auth
- [ ] Model `User`: `username`, `password_hash`, `role` (5 enum cứng), `is_locked`, `last_login`
- [ ] `LockedAwareJWTAuthentication` — chặn token khi `is_locked = true` (kể cả refresh)
- [ ] JWT login/refresh (SimpleJWT): access 60m, refresh 7d, rotate + blacklist
- [ ] `token_blacklist` app
- [ ] `POST /api/auth/login/` — rate limit 5/min/IP + 10/min/account
- [ ] `POST /api/auth/logout/` — blacklist refresh token
- [ ] `POST /api/auth/refresh/` — rotate + blacklist refresh cũ
- [ ] `POST /api/auth/forgot-password/` — rate limit 3/15p/email, token TTL 30 phút, dùng 1 lần
- [ ] `POST /api/auth/reset-password/` — invalidate toàn bộ refresh token cũ
- [ ] `POST /api/auth/change-password/` — blacklist refresh cũ khi đổi
- [ ] Password policy: tối thiểu 8 ký tự, có chữ + số (lỗi `400` field-level)
- [ ] `GET /api/health/`
- [ ] Dev: `PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE = True` (prod phải `False`)

### 2.2. Backend — Profiles
- [ ] Model `StudentProfile`: `ma_sv` (unique), `ho_ten`, `nganh` (FK), `khoa_nhap_hoc`, `ctdt` (FK), `gpa`, `tin_chi_tich_luy`, `email`, `sdt`
- [ ] Model `TeacherProfile`: `ma_gv` (unique), `ho_ten`, `khoa_bo_mon`, `hoc_vi`, `email`, `sdt`
- [ ] `GET/PATCH /api/profiles/me/` — xem/sửa email, sdt (không sửa trường học vụ)
- [ ] `GET/POST/PATCH /api/profiles/students/` — PĐT/Admin
- [ ] `GET/POST/PATCH /api/profiles/teachers/` — PĐT/Admin

### 2.3. Flutter — Auth & hồ sơ (Web cho mọi vai trò; App chỉ cho SV/GV)
- [ ] Màn hình login
- [ ] Màn hình forgot/reset password
- [ ] Màn hình đổi mật khẩu
- [ ] Màn hình xem hồ sơ cá nhân
- [ ] Interceptor tự refresh token khi hết hạn

**Milestone Pha 1:** Đăng nhập được cả 5 role; token bị khóa khi Admin khóa tài khoản.

---

## 3. PHA 2 — DỮ LIỆU ĐÀO TẠO (1.5 tuần)

### 3.1. Backend — Ngành & CTĐT
- [ ] Model `Major`: `ma_nganh` (unique), `ten_nganh`, `thoi_gian_dao_tao`, `trang_thai`
- [ ] Model `Curriculum`: `ma_ctdt`, `nganh` (FK), `khoa_tuyen_sinh`, `tong_tin_chi_yeu_cau` (>0), `trang_thai`
- [ ] Unique một phần `(nganh, khoa_tuyen_sinh) WHERE trang_thai = HOAT_DONG`
- [ ] Model `CurriculumCourse`: `ctdt`, `mon_hoc`, `khoi_kien_thuc` (5 loại), `loai_mon` (bat_buoc/tu_chon), `hoc_ky_goi_y`
- [ ] `UNIQUE(ctdt, mon_hoc)`
- [ ] API `GET/POST/PATCH /api/majors/`
- [ ] API `GET/POST/PATCH /api/curriculums/`
- [ ] API `GET/POST/PATCH /api/curriculum-courses/`

### 3.2. Backend — Môn học & tiên quyết
- [ ] Model `Course`: `ma_mon`, `ten_mon`, `tong_tin_chi`, `tin_chi_ly_thuyet`, `tin_chi_thuc_hanh`, `so_tiet_ly_thuyet`, `so_tiet_thuc_hanh`, `loai_danh_gia` (DIEM/DAT_KHONG_DAT), `trang_thai`
- [ ] `tong_tin_chi = tin_chi_ly_thuyet + tin_chi_thuc_hanh`
- [ ] `trang_thai = NGUNG_SU_DUNG` → chặn mở lớp mới + loại khỏi danh sách SV
- [ ] Model `Prerequisite`: `mon_hoc`, `mon_tien_quyet`
- [ ] `UNIQUE(mon_hoc, mon_tien_quyet)`; `mon_hoc ≠ mon_tien_quyet`
- [ ] Chốt chu trình: DFS từ `mon_hoc` theo cạnh `mon_tien_quyet`, gặp lại → `400`
- [ ] API `GET/POST/PATCH /api/courses/`
- [ ] API `GET/POST/PATCH /api/prerequisites/`

### 3.3. Backend — Học kỳ & lớp HP & lịch học
- [ ] Model `Semester`: `ten_hk`, `nam_hoc`, `ngay_bat_dau`, `ngay_ket_thuc`, `cua_so_dk_bat_dau`, `cua_so_dk_ket_thuc`, `tin_chi_toi_thieu` (nullable), `tin_chi_toi_da` (nullable), `tin_chi_toi_da_canh_bao` (nullable), `trang_thai` (MO/DONG)
- [ ] Model `ClassSection`: `ma_lop`, `mon_hoc`, `hoc_ky`, `giao_vien`, `si_so_toi_da`, `si_so_hien_tai`, `ngay_bat_dau` (nullable), `ngay_ket_thuc`, `han_nhap_diem` (nullable), `trang_thai` (KE_HOACH/MO/DANG_HOC/DA_DONG)
- [ ] `si_so_hien_tai ≤ si_so_toi_da`; `si_so_hien_tai ≥ 0`
- [ ] Model `Schedule`: `lop_hoc_phan`, `thu` (2–6), `buoi`, `tiet_bat_dau`, `so_tiet_moi_buoi`, `phong`, `ngay_hoc` (nullable)
- [ ] `tiet_ket_thuc = tiet_bat_dau + so_tiet_moi_buoi − 1` (dẫn xuất, không lưu cột)
- [ ] `buoi` dẫn xuất từ `tiet_bat_dau` (1–5 sáng, 6–10 chiều, 11–15 tối) — BR-08
- [ ] Bắt buộc nhập `so_tiet_moi_buoi` — BR-09
- [ ] Kiểm overlap phòng + GV cùng thời điểm/ngày hiệu lực (BR-03)
- [ ] API `GET/POST/PATCH /api/semesters/`
- [ ] `POST /api/semesters/{id}/open/` — mở học kỳ (cần cửa sổ + 3 trần tín chỉ)
- [ ] `POST /api/semesters/{id}/close/` — đóng học kỳ (hết lớp MO/DANG_HOC, còn → `409`)
- [ ] `PATCH /api/semesters/{id}/window/` — cửa sổ đăng ký
- [ ] API `GET/POST/PATCH /api/class-sections/`
- [ ] `POST /api/class-sections/{id}/open/` — KE_HOACH → MO (cần lịch + sĩ số)
- [ ] `POST /api/class-sections/{id}/close/` — → DA_DONG (mọi ĐK có Grade ≥ CHINH_THUC hoặc F tự sinh)
- [ ] `POST /api/class-sections/{id}/grade-deadline/` — gia hạn nhập điểm (audit log)
- [ ] API `GET/POST/PATCH /api/schedules/`

### 3.4. Flutter — PĐT quản lý dữ liệu (**Web only**)
- [ ] Màn hình ngành (CRUD)
- [ ] Màn hình CTĐT + gán CurriculumCourse
- [ ] Màn hình môn học (CRUD)
- [ ] Màn hình tiên quyết
- [ ] Màn hình học kỳ + cửa sổ đăng ký
- [ ] Màn hình lớp HP + lịch học

**Milestone Pha 2:** PĐT tạo đủ dữ liệu cho 1 học kỳ.

---

## 4. PHA 3 — ĐĂNG KÝ (2 tuần) ⭐ CRITICAL

> Pair BE-1 + BE-2. Không cắt pha này nếu thiếu người.

### 4.1. Backend — Registration
- [ ] Model `Registration`: `sinh_vien`, `lop_hoc_phan`, `hoc_ky`, `trang_thai` (DA_DANG_KY/DA_HUY), `cam_thi` (bool), `notified_cam_thi_review` (bool), `loai_dang_ky` (BINH_THUONG/HOC_LAI/HOC_CAI_THIEN), `ngay_dang_ky`, `ngay_huy`, `ly_do_huy`, `request_id` (UUID, nullable)
- [ ] `UNIQUE(sinh_vien, lop_hoc_phan)`
- [ ] `request_id` UNIQUE khi khác NULL (idempotency bền)
- [ ] `POST /api/registrations/` — **bắt buộc** `Idempotency-Key`
- [ ] `DELETE /api/registrations/{id}/` — hủy (SV trong cửa sổ / PĐT ngoài cửa sổ)
- [ ] `GET /api/registrations/history/` — SV xem lịch sử
- [ ] `GET /api/registrations/` — PĐT theo dõi
- [ ] `PATCH /api/registrations/{id}/` — PĐT xóa cờ `cam_thi` (lý do bắt buộc, audit log)
- [ ] `GET /api/registrations/export/` — xuất Excel/PDF

### 4.2. Backend — Business Rules đăng ký
- [ ] **BR-01:** HK `MO` + trong cửa sổ + lớp `MO` (không KE_HOACH/DANG_HOC/DA_DONG)
- [ ] **BR-02:** Lớp chưa đạt sĩ số tối đa
- [ ] **BR-03:** Không trùng lịch (định nghĩa đầy đủ: định kỳ theo thứ × giao tiết; lịch bù so ngày thật)
- [ ] **BR-04:** Đạt tiên quyết (Grade `KHOA` + `diem_tong_ket ≥ 5.0` + `cam_thi = false`, không phân biệt CTĐT)
- [ ] **BR-04 (học lại):** Đã có Grade `KHOA` cho chính môn → bắt buộc `GradeRetake` `DUYET`
- [ ] **BR-04 (miễn):** Đăng ký lại theo đơn `DUYET` → miễn tiên quyết
- [ ] **BR-05:** Hủy trong cửa sổ → hoàn toàn bộ học phí; ngoài cửa sổ → điều chỉnh theo chính sách
- [ ] **BR-06:** Transaction `SELECT FOR UPDATE` trên ClassSection → đọc lại sĩ số → INSERT + sĩ số+1 → COMMIT
- [ ] **BR-06 (hủy):** `FOR UPDATE` + sĩ số−1 (không xuống dưới 0)
- [ ] **BR-07:** Giới hạn tín chỉ (tối thiểu cảnh báo, tối đa chặn cứng, diện cảnh báo học vụ)
- [ ] **BR-07 (fallback):** `Semester.tin_chi_*` ?? `SystemConfig`; `tin_chi_toi_da_canh_bao` fallback 14
- [ ] Trả `warnings[]` trong response thành công (thiếu tín chỉ tối thiểu)

### 4.3. Backend — Idempotency
- [ ] Middleware đọc header `Idempotency-Key` (UUID)
- [ ] Redis fast-path cache 24h
- [ ] DB UNIQUE backstop (`Registration.request_id`)
- [ ] Replay key → trả đúng response cũ (kể cả 201)
- [ ] Key hết hạn Redis + đụng UNIQUE DB → vẫn trả response gốc
- [ ] Re-activate sau hủy giữ nguyên `request_id` cũ → replay key cũ **vẫn trả response gốc**; key bị ghi đè bởi re-activate mới → replay `409 IDEMPOTENCY_KEY_REUSED`, không re-execute (plan.md mục 10)

### 4.4. Backend — Tính học phí đột biến khi đăng ký
- [ ] Tính học phí theo BR-15/16/17 ngay khi đăng ký (cập nhật Tuition trong cửa sổ)
- [ ] Tạo thông báo xác nhận đăng ký

### 4.5. Flutter — SV đăng ký (Web + App)
- [ ] Màn hình xem môn được đăng ký (`GET /api/courses/available/` — đã lọc CTĐT, còn chỗ, không trùng lịch)
- [ ] Màn hình đăng ký thủ công
- [ ] Màn hình hủy đăng ký
- [ ] Màn hình lịch sử đăng ký
- [ ] Gửi `Idempotency-Key` mỗi lần POST

**Milestone Pha 3:** SV đăng ký được; không overbook khi 2 SV cùng bấm.

---

## 5. PHA 4 — ĐIỂM DANH (1 tuần)

### 5.1. Backend — Attendance
- [ ] Model `AttendanceSession`: `lop_hoc_phan`, `ngay_hoc`, `buoi`, `tiet_bat_dau`, `trang_thai` (MO/DA_DIEM_DANH)
- [ ] `UNIQUE(lop_hoc_phan, ngay_hoc, buoi)`
- [ ] Model `Attendance`: `attendance_session`, `lop_hoc_phan`, `ngay_hoc`, `sinh_vien`, `trang_thai` (CO_MAT/VANG_CO_PHEP/VANG_KHONG_PHEP), `di_tre` (bool), `ghi_chu`, `cap_nhat_luc`
- [ ] `UNIQUE(attendance_session, sinh_vien)` — BR-20
- [ ] Model `AttendanceRequest`: `attendance`, `sinh_vien`, `ly_do`, `trang_thai_mong_muon`, `trang_thai` (CHO_DUYET/DUYET/TU_CHOI), `nguoi_duyet`, `ngay_duyet`
- [ ] `POST /api/attendance/sessions/` — GV tạo buổi (lớp `DANG_HOC`)
- [ ] `POST /api/attendance/{id}/records/` — GV điểm danh (BR-19)
- [ ] `PATCH /api/attendance/{id}/records/` — GV sửa (session `MO` hoặc `DA_DIEM_DANH` ≤ 24h; không sửa lớp `DA_DONG`) — BR-20
- [ ] `GET /api/attendance/history/` — GV xem lịch sử
- [ ] `GET /api/attendance/my/` — SV xem điểm danh của mình
- [ ] `POST /api/attendance/requests/` — SV xin sửa
- [ ] `GET /api/attendance/requests/` — SV (của mình) / GV (lớp phụ trách) / PĐT
- [ ] `PATCH /api/attendance/requests/{id}/` — PĐT/GV duyệt/từ chối
- [ ] `GET /api/attendance/` — PĐT xem

### 5.2. Flutter — Điểm danh (Web + App)
- [ ] GV: tạo buổi điểm danh
- [ ] GV: điểm danh từng SV (CO_MAT / VANG_CO_PHEP / VANG_KHONG_PHEP + DI_TRE)
- [ ] GV: sửa điểm danh
- [ ] GV: xem lịch sử điểm danh
- [ ] SV: xem điểm danh + xin sửa

**Milestone Pha 4:** GV điểm danh được; SV xin sửa được.

---

## 6. PHA 5 — ĐIỂM (1.5 tuần)

### 6.1. Backend — Grade
- [ ] Model `Grade`: `lop_hoc_phan`, `sinh_vien`, `diem_qua_trinh`, `diem_giua_ky`, `diem_cuoi_ky`, `diem_tong_ket`, `diem_chu`, `gpa_thang_4`, `trang_thai` (NHAP_TAM/CHINH_THUC/KHOA), `ngay_nhap`
- [ ] `UNIQUE(lop_hoc_phan, sinh_vien)`
- [ ] Điểm số ∈ [0, 10]
- [ ] `diem_cuoi_ky` giữ `NULL` trong DB kể cả khi `KHOA` (fallback chỉ áp lúc tính)
- [ ] `POST /api/grades/` — GV nhập (lớp mình) / PĐT nhập hộ (quá hạn)
- [ ] `PATCH /api/grades/{id}/lock/` — body `{action: "lock" | "unlock"}`
- [ ] `lock` → `CHINH_THUC` (lớp `DANG_HOC`, trong hạn BR-13)
- [ ] `unlock` → `NHAP_TAM` (lớp `DANG_HOC`, trong hạn, audit log); `KHOA` không unlock
- [ ] `GET /api/grades/` — PĐT xem/lọc
- [ ] `GET /api/grades/my/` — SV xem
- [ ] `POST /api/grade-sheets/{lop_hoc_phan}/approve/` — PĐT duyệt cả bảng điểm lớp (`CHINH_THUC` → `KHOA`)

### 6.2. Backend — Business Rules điểm
- [ ] **BR-10:** Tổng kết = `QT*0.1 + GK*0.4 + CK*0.5`; fallback thiếu GK → 20/80; thiếu CK (`NULL`) → CK=0
- [ ] **BR-10:** `diem_cuoi_ky = 0` (GV nhập 0) → công thức thường, không fallback
- [ ] **BR-10:** SV `cam_thi = true` → không áp fallback thiếu CK, chốt F
- [ ] **BR-10:** Làm tròn 2 chữ số
- [ ] **BR-11:** Band liên tục: ≥8.50→A(4.0), ≥7.00→B(3.0), ≥5.50→C(2.0), ≥4.00→D(1.0), <4.00→F(0.0)
- [ ] **BR-11:** `DAT_KHONG_DAT` → `P` (≥5.00, `gpa_thang_4 = null`) / `F` (<5.00)
- [ ] **BR-12:** GV chỉ nhập điểm lớp mình phụ trách
- [ ] **BR-13:** GV cập nhật trong 2 tuần từ `ngay_ket_thuc`; quá hạn → `409 QUA_HAN_NHAP_DIEM`
- [ ] **BR-13:** PĐT gia hạn qua `POST /api/class-sections/{id}/grade-deadline/`
- [ ] **BR-14:** State machine `NHAP_TAM → CHINH_THUC → KHOA`; `CHINH_THUC → NHAP_TAM` (GV unlock); `KHOA` bất biến
- [ ] **BR-24:** SV `cam_thi = true` → `POST/PATCH /api/grades/` trả `409 CAM_THI`
- [ ] **BR-25:** GPA học kỳ/tích lũy; P loại khỏi tử số & mẫu số; F vào mẫu số; học lại lấy mới nhất
- [ ] **BR-25:** Tie-break cùng `ngay_nhap` → `id` lớn hơn
- [ ] **BR-25:** Cập nhật `StudentProfile.gpa` + `tin_chi_tich_luy` khi Grade → `KHOA`
- [ ] **BR-25:** Xếp loại: Xuất sắc 3.60–4.00, Giỏi 3.20–3.59, Khá 2.50–3.19, TB 2.00–2.49, Yếu 1.00–1.99, Kém <1.00

### 6.3. Backend — Celery job điểm
- [ ] `scan_cam_thi` — 00:30 hằng ngày trên lớp `DANG_HOC` + bắn lại khi lớp `DA_DONG`
- [ ] **BR-24:** Mẫu số = số `AttendanceSession` `DA_DIEM_DANH`; mẫu số = 0 → skip
- [ ] **BR-24:** `so_vang_khong_phep / so_buoi_da_diem_danh > MAX_ABSENT_PCT` → `cam_thi = true`
- [ ] **BR-24:** Lớp `DA_DONG` → sinh mới hoặc UPDATE `Grade` thành F/KHOA (tôn trọng UNIQUE)
- [ ] **BR-24:** Job chỉ set, không unset; notification PĐT 1 lần (`notified_cam_thi_review`)
- [ ] `recalc_gpa` — bắn khi Grade → `KHOA` + 01:00 hằng ngày

### 6.4. Flutter — Điểm (GV + SV: Web + App; PĐT duyệt/gia hạn: Web only)
- [ ] GV: nhập điểm QT/GK/CK + xem trước tổng kết
- [ ] GV: khóa/mở khóa điểm
- [ ] PĐT: duyệt điểm theo lớp
- [ ] PĐT: gia hạn nhập điểm
- [ ] SV: xem điểm (chỉ `KHOA` hiển thị chính thức)

**Milestone Pha 5:** Nhập điểm → khóa → PĐT duyệt → SV xem được.

---

## 7. PHA 6 — HỌC PHÍ (1.5 tuần)

### 7.1. Backend — Tuition
- [ ] Model `HocPhanGia`: `hoc_ky` (nullable), `pham_vi` (MAC_DINH/KHOI_KIEN_THUC/NGANH/LECH_LT/LECH_TH/GIA_TH), `tham_chieu` (chuỗi), `don_gia`, `hieu_luc_tu` (nullable)
- [ ] Functional unique index `COALESCE(tham_chieu, '')` hoặc partial index (NULL ≠ NULL)
- [ ] `don_gia` ≥ 0; `LECH_LT`/`LECH_TH` là hệ số (âm hoặc dương)
- [ ] Model `TuitionConfig`: `hoc_ky`, `han_dong`, `chinh_sach_hoan_giam`
- [ ] Model `Discount`: `sinh_vien`, `hoc_ky`, `loai` (MIEN_GIAM/HOAN_TIEN/GIAM_TRU/HOC_BONG), `so_tien`/`ty_le`, `ly_do`, `trang_thai` (AP_DUNG/DA_CHI)
- [ ] Model `Payment`: `tuition`, `so_tien`, `phuong_thuc` (TIEN_MAT/CHUYEN_KHOAN/KHAC), `ngay_thu`, `nguoi_thu`, `bien_lai_ma`, `request_id` (UUID, nullable)
- [ ] `Payment.request_id` UNIQUE khi khác NULL
- [ ] Model `Tuition`: `sinh_vien`, `hoc_ky`, `tong_tin_chi`, `tong_tien`, `da_thu`, `mien_giam`, `hoan_tien`, `con_no`, `trang_thai`
- [ ] `UNIQUE(sinh_vien, hoc_ky)`
- [ ] `da_thu` = Σ Payment
- [ ] `mien_giam` = Σ Discount `loai ∈ {MIEN_GIAM, GIAM_TRU, HOC_BONG}` + `trang_thai = AP_DUNG` (loại HOAN_TIEN)
- [ ] `hoan_tien` = Σ Discount `loai = HOAN_TIEN` + `trang_thai = AP_DUNG` (DA_CHI là lịch sử)
- [ ] `con_no = max(0, tong_tien − da_thu − mien_giam)`
- [ ] Thứ tự ưu tiên trạng thái: `CHO_HOAN_TIEN` > `CON_NO` > `GIAM_TRU` > `DA_DONG`

### 7.2. Backend — API Tuition
- [ ] `GET/POST/PATCH /api/tuition/config/` — KT cấu hình chính sách
- [ ] `GET/POST/PATCH /api/tuition/pricing/` — KT bảng giá
- [ ] `GET/POST/PATCH /api/tuition/discounts/` — KT miễn giảm
- [ ] `GET /api/tuition/` — KT danh sách
- [ ] `POST /api/tuition/calculate/` — KT tính học phí (rebase)
- [ ] `POST /api/tuition/payments/` — KT xác nhận thanh toán (Idempotency-Key)
- [ ] `GET /api/tuition/debts/` — KT công nợ
- [ ] `POST /api/tuition/adjustments/` — KT điều chỉnh
- [ ] `GET /api/tuition/receipts/{id}/` — KT biên lai
- [ ] `GET /api/tuition/my/` — SV xem học phí
- [ ] `GET /api/reports/finance/` — KT báo cáo tài chính

### 7.3. Backend — Business Rules học phí
- [ ] **BR-15:** Học phí = Σ (tín chỉ × đơn giá) theo bảng giá đang áp dụng
- [ ] **BR-16:** Tra bảng giá 2 trục: (1) `hoc_ky` = học kỳ đang tính, (2) `hoc_ky IS NULL`; trong mỗi trục: `KHOI_KIEN_THUC` → `NGANH` → `MAC_DINH`
- [ ] **BR-16:** Không tìm được → `400 CHUA_CAU_HINH_GIA`
- [ ] **BR-17:** Đơn giá LT = `đơn giá gốc × (1 + LECH_LT)` nếu có bản ghi `LECH_LT` khớp khối
- [ ] **BR-17:** Đơn giá TH = `GIA_TH` nếu có, ngược lại `đơn giá gốc × (1 + LECH_TH)`, ngược lại `đơn giá gốc`
- [ ] **BR-17:** Adjustment records tra cùng 2 trục `hoc_ky` như BR-16
- [ ] **BR-17:** Môn có `tin_chi_thuc_hanh > 0` → `tin_chi_ly_thuyet × đơn giá LT + tin_chi_thuc_hanh × đơn giá TH`
- [ ] **BR-18:** KT quyết định miễn giảm; mọi thay đổi ghi audit log
- [ ] **BR-05 (học phí):** Hủy trong cửa sổ → hoàn toàn bộ; ngoài cửa sổ → điều chỉnh theo chính sách
- [ ] **BR-05 (học phí):** `HOAN_TIEN` tách khỏi `mien_giam`; `hoan_tien > 0` → `CHO_HOAN_TIEN`
- [ ] **BR-05 (học phí):** Rebase giữ `Discount` đã `DA_CHI` (không thu hồi tiền đã chi)
- [ ] **BR-05 (học phí):** Rebase sau khi đăng ký mới → reset về `DA_TINH`, giữ `Discount` `DA_CHI`

### 7.4. Backend — Celery job học phí
- [ ] `tuition_overdue_notify` — 07:00 hằng ngày; chỉ xét `Tuition` đã `DA_TINH`; `con_no > 0` + quá `han_dong` → thông báo SV + báo cáo KT
- [ ] Job 00:05 quét học kỳ `DONG` còn `Tuition` `CHUA_TINH` → nhắc KT tính (audit log)

### 7.5. Flutter — Học phí (KT: Web only; SV xem học phí: Web + App)
- [ ] KT: cấu hình chính sách + bảng giá
- [ ] KT: tính học phí + xác nhận thanh toán
- [ ] KT: xem công nợ + điều chỉnh
- [ ] KT: xuất biên lai + báo cáo tài chính
- [ ] SV: xem học phí theo học kỳ

**Milestone Pha 6:** Tính học phí đúng; thu được; công nợ chính xác.

---

## 8. PHA 6b — HỌC LẠI / CẢI THIỆN ĐIỂM (0.5 tuần)

### 8.1. Backend — GradeRetake
- [ ] Model `GradeRetake`: `sinh_vien`, `mon_hoc`, `hoc_ky`, `loai` (HOC_LAI/HOC_CAI_THIEN), `ly_do`, `trang_thai` (CHO_DUYET/DUYET/TU_CHOI), `nguoi_duyet`, `ngay_duyet`
- [ ] `UNIQUE(sinh_vien, mon_hoc, hoc_ky)`
- [ ] `GET/POST /api/grade-retakes/` — SV nộp đơn + xem đơn của mình
- [ ] `PATCH /api/grade-retakes/{id}/` — PĐT duyệt/từ chối
- [ ] `GET/PATCH /api/grade-retakes/` — PĐT xem/duyệt
- [ ] **Không** sửa/xoá `Grade` cũ — lịch sử điểm bất biến
- [ ] `DUYET` → SV đăng ký lớp mới, `Registration.loai_dang_ky` đặt theo loai đơn
- [ ] **BR-04 (miễn):** Đăng ký lại theo đơn `DUYET` → miễn tiên quyết

### 8.2. Flutter — Học lại (SV: Web + App; PĐT: Web only)
- [ ] SV: form nộp đơn (chọn môn + học kỳ + lý do)
- [ ] SV: theo dõi trạng thái đơn
- [ ] PĐT: màn hình xử lý đơn (duyệt/từ chối)

**Milestone Pha 6b:** Đơn cải thiện điểm chạy được; `Grade` cũ không bị sửa.

---

## 9. PHA 7 — THÔNG BÁO & AUDIT (1 tuần)

### 9.1. Backend — Notification
- [ ] Model `Notification`: `tieu_de`, `noi_dung`, `audience` (ROLE/MAJOR/CLASS/SEMESTER/USER), `target_refs` (JSON array), `nguoi_gui`, `ngay_gui`, `trang_thai` (DA_GUI/THU_HOI)
- [ ] Model `NotificationRead`: `notification`, `user`, `da_doc`, `ngay_doc`
- [ ] `UNIQUE(notification, user)`
- [ ] `POST /api/notifications/` — PĐT/GV/KT/Admin gửi
- [ ] `GET /api/notifications/` — mọi vai trò xem thông báo của mình
- [ ] `PATCH /api/notifications/{id}/read/` — đánh dấu đã đọc
- [ ] `POST /api/notifications/read-all/` — bulk đánh dấu
- [ ] `DELETE /api/notifications/{id}/` — Admin/người gửi thu hồi → `THU_HOI`
- [ ] Phân giải người nhận từ `audience × target_refs` tại backend

### 9.2. Backend — Trigger tự động thông báo
- [ ] Đăng ký/hủy đăng ký thành công → `USER` (SV)
- [ ] Lớp bị hủy/đổi phòng/đổi lịch → `CLASS`
- [ ] Mở cửa sổ đăng ký → `MAJOR` / `SEMESTER`
- [ ] Điểm mới `KHOA` → `USER` (SV)
- [ ] Học phí quá hạn → `USER` (SV) + KT
- [ ] Cảnh báo học vụ (GPA < 2.0) → `USER` (SV) + PĐT

### 9.3. Backend — AuditLog
- [ ] Model `AuditLog`: `user`, `hanh_dong` (CREATE/UPDATE/DELETE/LOGIN/PHAN_QUYEN), `doi_tuong`, `doi_tuong_id` (UUID polymorphic, không FK), `chi_tiet` (JSON), `thoi_gian`, `ip`
- [ ] `AuditLogMixin` áp cho mọi ViewSet ghi
- [ ] Bảng mapping scope: `training.*` (User/Profile, Major, Curriculum, ..., Grade, Notification), `finance.*` (HocPhanGia, TuitionConfig, Discount, Payment, Tuition), khác (SystemConfig, RolePermission, Backup)
- [ ] `GET /api/admin/audit-logs/` — Admin (scope=all) / PĐT (training) / KT (finance); server filter theo role

### 9.4. Flutter — Thông báo (Web cho mọi vai trò; App chỉ cho SV/GV)
- [ ] Màn hình thông báo cả 5 role
- [ ] Đánh dấu đã đọc + bulk đọc
- [ ] Soạn/gửi thông báo (PĐT/GV/KT/Admin)

**Milestone Pha 7:** Thông báo gửi đúng đích; log đầy đủ.

---

## 10. PHA 8 — TKB TỰ ĐỘNG (1 tuần)

### 10.1. Backend
- [ ] `GET /api/auto-schedule/available-courses/` — trả **toàn bộ** lớp mở + lịch (không lọc trùng lịch)
- [ ] Khác biệt rõ với `/api/courses/available/` (đã lọc trùng lịch theo SV)

### 10.2. Flutter — AutoScheduleService
- [ ] `AutoScheduleService` — pure Dart, không phụ thuộc Flutter
- [ ] Greedy MVP: sắp môn bắt buộc trước theo `hoc_ky_goi_y`, mỗi môn chọn lớp đầu không trùng lịch
- [ ] Scoring đơn giản: +điểm nếu không trùng buổi, +điểm nếu tiết gần nhau
- [ ] Trả về tối đa 3 tổ hợp
- [ ] Test độc lập cho service
- [ ] Màn hình SV: chọn môn + ưu tiên → xem gợi ý → xác nhận từng môn → POST `/api/registrations/`

**Milestone Pha 8:** Gợi ý được tối đa 3 tổ hợp hợp lệ.

---

## 11. PHA 9 — BÁO CÁO & XUẤT (1 tuần)

### 11.1. Backend — Export
- [ ] `openpyxl` (Excel) + `reportlab` (PDF)
- [ ] `core/export.py` — registry `(dataset, format) → file`, dùng chung mọi endpoint
- [ ] `GET /api/reports/training/` — PĐT báo cáo đào tạo
- [ ] `GET /api/reports/training/export/` — xuất Excel/PDF
- [ ] `GET /api/registrations/export/` — xuất danh sách đăng ký
- [ ] `GET /api/class-sections/{id}/export/` — GV xuất danh sách lớp/điểm/điểm danh
- [ ] `GET /api/reports/finance/` — KT báo cáo tài chính
- [ ] `GET /api/tuition/receipts/{id}/` — biên lai

### 11.2. Flutter — Báo cáo (PĐT + KT: Web only; GV: Web + App)
- [ ] PĐT: xem báo cáo đào tạo + xuất file
- [ ] KT: xem báo cáo tài chính + xuất file
- [ ] GV: xuất danh sách lớp/điểm/điểm danh

**Milestone Pha 9:** Báo cáo chạy đúng; xuất được file.

---

## 12. PHA 10 — HOÀN THIỆN & RELEASE (1 tuần)

### 12.1. Tối ưu & bảo mật
- [ ] Rate limit đầy đủ: login 5/min/IP + 10/min/account; forgot 3/15p/email; đăng ký 30/min/user; ghi chung 120/min/user
- [ ] Phân trang nhất quán (25/50)
- [ ] Xử lý lỗi thống nhất (envelope plan.md mục 13.8)
- [ ] `DEBUG=False`, secret từ env
- [ ] HTTPS (nginx + certbot)
- [ ] CORS chỉ cho origin được phép

### 12.2. Backup & monitoring
- [ ] `backup_daily` — 02:00 hằng ngày `pg_dump` → `BACKUP_DIR`, xoá file quá `backup_retention_days`
- [ ] `GET /api/admin/backups/` — xem lịch sử backup
- [ ] `POST /api/admin/backups/` — khởi tạo backup/restore
- [ ] `pg_dump` trước mỗi lần migrate prod
- [ ] Health check `/api/health/` + monitoring
- [ ] Log tập trung (gunicorn + celery)

### 12.3. Responsive & E2E
- [ ] Responsive Web: breakpoint 600/1024 (plan.md mục 15.4) — mọi vai trò
- [ ] App (SV/GV): layout mobile native, touch target ≥ 48px
- [ ] **App chỉ build cho SV + GV** — Admin/PĐT/KT không có app; route `/admin/*`, `/pdt/*`, `/accountant/*` chỉ chạy trên Web
- [ ] NavigationRail ẩn < 600px; trượt 600–1024px; NavigationDrawer cố định > 1024px
- [ ] E2E test chính: đăng ký → điểm → học phí
- [ ] Load test đăng ký (locust)

### 12.4. Hoàn thiện nghiệp vụ
- [ ] Luồng học lại/cải thiện điểm (nếu chưa làm ở Pha 6b)
- [ ] Audit log đầy đủ (mọi ViewSet ghi)
- [ ] Đồng bộ plan.md nếu có thay đổi nghiệp vụ

**Milestone Pha 10:** Production-ready.

---

## 13. CHECKLIST THỰC THỂ (27 entities)

| # | Thực thể | App | Pha | ✓ |
| :---: | :--- | :--- | :--- | :--- |
| 1 | `User` | auth | 1 | [ ] |
| 2 | `StudentProfile` | profiles | 1 | [ ] |
| 3 | `TeacherProfile` | profiles | 1 | [ ] |
| 4 | `Major` | training | 2 | [ ] |
| 5 | `Curriculum` | training | 2 | [ ] |
| 6 | `CurriculumCourse` | training | 2 | [ ] |
| 7 | `Course` | training | 2 | [ ] |
| 8 | `Prerequisite` | training | 2 | [ ] |
| 9 | `Semester` | training | 2 | [ ] |
| 10 | `ClassSection` | training | 2 | [ ] |
| 11 | `Schedule` | training | 2 | [ ] |
| 12 | `Registration` | registration | 3 | [ ] |
| 13 | `AttendanceSession` | attendance | 4 | [ ] |
| 14 | `Attendance` | attendance | 4 | [ ] |
| 15 | `AttendanceRequest` | attendance | 4 | [ ] |
| 16 | `Grade` | grades | 5 | [ ] |
| 17 | `HocPhanGia` | tuition | 6 | [ ] |
| 18 | `TuitionConfig` | tuition | 6 | [ ] |
| 19 | `Discount` | tuition | 6 | [ ] |
| 20 | `Payment` | tuition | 6 | [ ] |
| 21 | `Tuition` | tuition | 6 | [ ] |
| 22 | `Notification` | notifications | 7 | [ ] |
| 23 | `NotificationRead` | notifications | 7 | [ ] |
| 24 | `AuditLog` | audit | 7 | [ ] |
| 25 | `SystemConfig` | config | 0 | [ ] |
| 26 | `RolePermission` | config | 1 | [ ] |
| 27 | `GradeRetake` | registration | 6b | [ ] |

---

## 14. CHECKLIST BUSINESS RULES (BR-01..25)

| Mã | Tóm tắt | Pha | ✓ |
| :--- | :--- | :--- | :--- |
| BR-01 | HK mở + trong cửa sổ + lớp `MO` | 3 | [ ] |
| BR-02 | Lớp chưa đạt sĩ số tối đa | 3 | [ ] |
| BR-03 | Không trùng lịch (định nghĩa đầy đủ) | 3 | [ ] |
| BR-04 | Đạt tiên quyết + học lại cần đơn `DUYET` | 3 | [ ] |
| BR-05 | Hủy trong/ngoài cửa sổ → hoàn học phí | 3, 6 | [ ] |
| BR-06 | Transaction `FOR UPDATE` chống overbook | 3 | [ ] |
| BR-07 | Giới hạn tín chỉ (tối thiểu/tối đa/cảnh báo) | 3 | [ ] |
| BR-08 | 15 tiết/ngày (1–5 sáng, 6–10 chiều, 11–15 tối) | 2 | [ ] |
| BR-09 | Bắt buộc nhập `so_tiet_moi_buoi` | 2 | [ ] |
| BR-10 | Tổng kết = QT*0.1+GK*0.4+CK*0.5 + fallback | 5 | [ ] |
| BR-11 | Band liên tục A/B/C/D/F + `DAT_KHONG_DAT`→P | 5 | [ ] |
| BR-12 | GV chỉ nhập điểm lớp mình | 5 | [ ] |
| BR-13 | GV nhập trong 2 tuần; quá hạn → PĐT gia hạn/nhập hộ | 5 | [ ] |
| BR-14 | State machine điểm + GV tự mở khóa | 5 | [ ] |
| BR-15 | Học phí = Σ (tín chỉ × đơn giá) | 6 | [ ] |
| BR-16 | Tra bảng giá 2 trục + 3 phạm vi | 6 | [ ] |
| BR-17 | Công thức LT/TH + `LECH_LT`/`LECH_TH`/`GIA_TH` | 6 | [ ] |
| BR-18 | KT quyết định miễn giảm + ghi log | 6 | [ ] |
| BR-19 | Trạng thái điểm danh + `DI_TRE` riêng | 4 | [ ] |
| BR-20 | Lưu theo từng buổi + sửa trong 24h | 4 | [ ] |
| BR-21 | Phân quyền 5 vai trò | 1 | [ ] |
| BR-22 | JWT + chặn token khi khóa | 1 | [ ] |
| BR-23 | SV xem dữ liệu của mình; GV lớp phụ trách | 1 | [ ] |
| BR-24 | Cấm thi theo điểm danh + sinh Grade F/KHOA | 5 | [ ] |
| BR-25 | GPA học kỳ/tích lũy + học lại lấy mới nhất | 5 | [ ] |

---

## 15. CHECKLIST API ENDPOINTS

### 15.1. Auth & hệ thống
- [ ] `POST /api/auth/login/`
- [ ] `POST /api/auth/logout/`
- [ ] `POST /api/auth/refresh/`
- [ ] `POST /api/auth/forgot-password/`
- [ ] `POST /api/auth/reset-password/`
- [ ] `POST /api/auth/change-password/`
- [ ] `GET /api/health/`
- [ ] `GET /api/profiles/me/`
- [ ] `PATCH /api/profiles/me/`
- [ ] `GET /api/schema/`
- [ ] `GET /api/docs/`

### 15.2. Admin
- [ ] `GET/POST/PATCH /api/users/`
- [ ] `PATCH /api/users/{id}/lock/`
- [ ] `POST /api/users/{id}/reset-password/`
- [ ] `GET /api/admin/roles/`
- [ ] `GET/PUT /api/admin/permissions/`
- [ ] `GET /api/admin/audit-logs/`
- [ ] `POST /api/admin/backups/`
- [ ] `GET /api/admin/backups/`
- [ ] `GET/PATCH /api/admin/config/`

### 15.3. Phòng đào tạo
- [ ] `GET/POST/PATCH /api/profiles/students/`
- [ ] `GET/POST/PATCH /api/profiles/teachers/`
- [ ] `GET/POST/PATCH /api/majors/`
- [ ] `GET/POST/PATCH /api/curriculums/`
- [ ] `GET/POST/PATCH /api/curriculum-courses/`
- [ ] `GET/POST/PATCH /api/courses/`
- [ ] `GET/POST/PATCH /api/prerequisites/`
- [ ] `GET/POST/PATCH /api/semesters/`
- [ ] `POST /api/semesters/{id}/open/`
- [ ] `POST /api/semesters/{id}/close/`
- [ ] `PATCH /api/semesters/{id}/window/`
- [ ] `GET/POST/PATCH /api/class-sections/`
- [ ] `POST /api/class-sections/{id}/open/`
- [ ] `POST /api/class-sections/{id}/close/`
- [ ] `POST /api/class-sections/{id}/grade-deadline/`
- [ ] `GET/POST/PATCH /api/schedules/`
- [ ] `GET /api/registrations/`
- [ ] `GET /api/attendance/`
- [ ] `GET /api/grades/`
- [ ] `PATCH /api/attendance/requests/{id}/`
- [ ] `PATCH /api/registrations/{id}/`
- [ ] `DELETE /api/registrations/{id}/`
- [ ] `POST /api/grade-sheets/{lop_hoc_phan}/approve/`
- [ ] `POST /api/notifications/`
- [ ] `DELETE /api/notifications/{id}/`
- [ ] `GET/PATCH /api/grade-retakes/`
- [ ] `GET /api/reports/training/`
- [ ] `GET /api/reports/training/export/`
- [ ] `GET /api/registrations/export/`

### 15.4. Sinh viên
- [ ] `GET /api/curriculums/my/`
- [ ] `GET /api/courses/available/`
- [ ] `POST /api/registrations/`
- [ ] `DELETE /api/registrations/{id}/`
- [ ] `GET /api/registrations/history/`
- [ ] `GET /api/auto-schedule/available-courses/`
- [ ] `GET /api/timetable/my/`
- [ ] `GET /api/attendance/my/`
- [ ] `POST /api/attendance/requests/`
- [ ] `GET /api/attendance/requests/`
- [ ] `GET /api/grades/my/`
- [ ] `GET /api/tuition/my/`
- [ ] `GET/POST /api/grade-retakes/`
- [ ] `GET /api/notifications/`
- [ ] `PATCH /api/notifications/{id}/read/`
- [ ] `POST /api/notifications/read-all/`

### 15.5. Giáo viên
- [ ] `GET /api/class-sections/my/`
- [ ] `GET /api/class-sections/{id}/`
- [ ] `GET /api/timetable/my/`
- [ ] `POST /api/attendance/sessions/`
- [ ] `POST /api/attendance/{id}/records/`
- [ ] `PATCH /api/attendance/{id}/records/`
- [ ] `GET /api/attendance/history/`
- [ ] `POST /api/grades/`
- [ ] `PATCH /api/grades/{id}/lock/`
- [ ] `POST /api/notifications/`
- [ ] `GET /api/class-sections/{id}/export/`

### 15.6. Kế toán
- [ ] `GET/POST/PATCH /api/tuition/config/`
- [ ] `GET/POST/PATCH /api/tuition/pricing/`
- [ ] `GET/POST/PATCH /api/tuition/discounts/`
- [ ] `GET /api/tuition/`
- [ ] `POST /api/tuition/calculate/`
- [ ] `POST /api/tuition/payments/`
- [ ] `GET /api/tuition/debts/`
- [ ] `POST /api/tuition/adjustments/`
- [ ] `GET /api/tuition/receipts/{id}/`
- [ ] `GET /api/reports/finance/`

---

## 16. TEST BẮT BUỘC (mục 19 plan.md)

### 16.1. Đăng ký & overbook
- [ ] 2 SV cùng bấm chỗ cuối → chỉ 1 SV thành công (BR-06) — **PostgreSQL thật, không mock**
- [ ] Replay `Idempotency-Key`: POST 2 lần cùng key (kể cả hết hạn Redis) → cùng response, không tạo 2 Registration
- [ ] `POST /api/tuition/payments/` không thu 2 lần tiền khi replay
- [ ] Đăng ký vào lớp `KE_HOACH`/`DA_DONG` → `LOP_CHUA_MO` (BR-01)
- [ ] SV đăng ký lại môn đã đạt với `BINH_THUONG` → `DA_DAT_MON` (BR-04)
- [ ] Có đơn `GradeRetake` `DUYET` → đăng ký được
- [ ] Vượt trần tín chỉ → `VUOT_TIN_TC_TOI_DA`; thiếu tối thiểu → `201` + `warnings` (BR-07)
- [ ] SV diện cảnh báo vượt `tin_chi_toi_da_canh_bao` → `VUOT_TIN_TC_CANH_BAO`
- [ ] Lịch bù `ngay_hoc` trùng tiết với lịch định kỳ → `TRUNG_LICH` (BR-03)
- [ ] Re-activate Registration giữ `request_id` cũ → replay key cũ trả response gốc
- [ ] Key bị ghi đè bởi re-activate mới → replay `409 IDEMPOTENCY_KEY_REUSED`

### 16.2. Điểm
- [ ] Điểm thiếu GK → fallback 20/80 (BR-10)
- [ ] `diem_cuoi_ky = NULL` → fallback thiếu CK; `diem_cuoi_ky = 0` → công thức thường
- [ ] Điểm 8.45/6.95/5.45 → B/C/D; biên 8.50/7.00/5.50/4.00 → A/B/C/D (BR-11)
- [ ] Môn `DAT_KHONG_DAT` điểm 6.0 → `P`, `gpa_thang_4 = null`, không vào GPA (BR-11/25)
- [ ] Môn `F` vẫn trong mẫu số GPA (BR-25)
- [ ] Học lại cùng môn → chỉ tính `Grade` `KHOA` lần cuối (BR-25c)
- [ ] Học cải thiện điểm mới thấp hơn → GPA dùng điểm mới (BR-25c)
- [ ] Quá `han_nhap_diem` → `QUA_HAN_NHAP_DIEM`; PĐT gia hạn xong nhập được (BR-13)
- [ ] GV tự mở khóa `CHINH_THUC → NHAP_TAM` trong hạn; lớp `DA_DONG` không sửa được
- [ ] Tạo tiên quyết chu trình (A→B→A) → `400`; `mon_hoc = mon_tien_quyet` → `400`

### 16.3. Điểm danh & cấm thi
- [ ] SV vắng quá 20% → `CAM_THI = true` giữa kỳ (lớp `DANG_HOC`) → GV nhập CK nhận `409` (BR-24)
- [ ] Lớp đóng được khi SV bị cấm thi; SV `CAM_THI` đã có `Grade` → job UPDATE thành F/KHOA (không duplicate)
- [ ] Lớp **không** đóng được khi còn ĐK chưa có `Grade` hoặc `Grade` còn `NHAP_TAM`
- [ ] Học phí chưa thu **không** chặn đóng lớp
- [ ] Lớp `DA_DONG`: `PATCH /api/registrations/{id}/` xóa cờ `cam_thi` → `409`

### 16.4. Học phí
- [ ] Học phí đúng thứ tự ưu tiên giá: học kỳ → NULL; khối → ngành → mặc định (BR-16)
- [ ] Đơn giá LT/TH đúng công thức (BR-17)
- [ ] Hủy hết môn đã thu → `con_no = 0`, `hoan_tien > 0`, `CHO_HOAN_TIEN` (BR-05)
- [ ] Không tìm được bảng giá → `CHUA_CAU_HINH_GIA` (BR-16)
- [ ] SV đã `DA_DONG` học phí, hủy hết môn trong cửa sổ → `CHO_HOAN_TIEN`
- [ ] Rebase sau khi KT chi hoàn tiền → không về `CHO_HOAN_TIEN` lần 2
- [ ] `Tuition` `mien_giam > 0` và `con_no > 0` → `CON_NO` (ưu tiên đúng)
- [ ] 2 bản ghi `MAC_DINH` cùng `hoc_ky` → violate UNIQUE (COALESCE/partial index)

### 16.5. Auth & bảo mật
- [ ] Token bị khóa → mọi request bị chặn; refresh token cũng bị chặn (BR-22)
- [ ] Logout → refresh token cũ không dùng lại được
- [ ] Đổi/reset mật khẩu → refresh token cũ bị blacklist
- [ ] Token reset hết hạn 30 phút / chỉ dùng 1 lần

### 16.6. Học kỳ
- [ ] Đóng học kỳ khi còn lớp `MO`/`DANG_HOC` → `409 TRANG_THAI_KHONG_HOP_LE`

---

## 17. DEPLOYMENT CHECKLIST (plan.md mục 20)

- [ ] `DEBUG=False`, secret từ env
- [ ] HTTPS (nginx + certbot)
- [ ] `pg_dump` trước mỗi lần migrate prod
- [ ] Backup DB tự động (daily)
- [ ] Log tập trung (gunicorn + celery)
- [ ] Health check (`/api/health/`) + monitoring
- [ ] `docker-compose up -d` chạy đủ: web, db, redis, celery, nginx
- [ ] `BACKUP_DIR` volume mount đúng

---

## 18. DEFINITION OF DONE (plan.md mục 22)

Mỗi pha khi:
1. [ ] Test pass (unit + integration) ≥ 80% coverage phần đó
2. [ ] API chạy đúng trên Swagger, phân quyền đúng role, trả **đúng mã lỗi** plan.md mục 13.8
3. [ ] Flutter build được cả Web + App (App chỉ cho SV/GV), không lỗi console
4. [ ] Review code + merge PR (kèm `🤖 Generated with [Claude Code](https://claude.com/claude-code)`)
5. [ ] Mọi thay đổi nghiệp vụ cập nhật **ngay trong plan.md**

---

## 19. TOOLING & PHONG CÁCH CODE (plan.md mục 27)

- [ ] `black` (line-length 100) — format Python
- [ ] `ruff` (`E,F,I,B,UP`; bỏ `E501`) — lint Python
- [ ] `mypy` (không `--strict`) — type check `apps/` + `core/`
- [ ] `dart format` — format Dart
- [ ] `flutter analyze` với `flutter_lints`
- [ ] `pre-commit` — chạy black + ruff + dart format trước commit
- [ ] Naming backend: field tiếng Việt không dấu (`hoc_ky`, `si_so_toi_da`), class `PascalCase`
- [ ] Naming Dart: `lowerCamelCase` field, class `PascalCase`; map snake_case → camelCase trong `fromJson`

---

## 20. THEO DÕI TIẾN ĐỘ

| Pha | Tên | Tuần | Trạng thái | ✓ |
| :---: | :--- | :---: | :--- | :---: |
| 0 | Nền tảng | 1 | [ ] | [ ] |
| 1 | Auth & hồ sơ | 1 | [ ] | [ ] |
| 2 | Dữ liệu đào tạo | 1.5 | [ ] | [ ] |
| 3 | Đăng ký ⭐ | 2 | [ ] | [ ] |
| 4 | Điểm danh | 1 | [ ] | [ ] |
| 5 | Điểm | 1.5 | [ ] | [ ] |
| 6 | Học phí | 1.5 | [ ] | [ ] |
| 6b | Học lại/cải thiện | 0.5 | [ ] | [ ] |
| 7 | Thông báo & audit | 1 | [ ] | [ ] |
| 8 | TKB tự động | 1 | [ ] | [ ] |
| 9 | Báo cáo & xuất | 1 | [ ] | [ ] |
| 10 | Hoàn thiện & release | 1 | [ ] | [ ] |
| | **TỔNG** | **~14** | | |

---

## 21. GHI CHÚ QUAN TRỌNG

1. **Backend là nguồn sự thật duy nhất** — mọi BR kiểm tra tại API, không tin frontend.
2. **Transaction mọi thao tác ghi đè lẫn nhau** — đăng ký, điểm danh, học phí.
3. **Idempotent** — retry API không tạo bản ghi trùng (UNIQUE + `request_id`).
4. **Phân quyền tại API** — mọi endpoint kiểm tra role + phạm vi.
5. **Không tự chế lỗi mới** — chỉ dùng mã lỗi trong mục 13.8.
6. **plan.md là nguồn duy nhất** — mọi thay đổi nghiệp vụ cập nhật ngay trong đó.
7. **Test overbook chạy PostgreSQL thật, không mock DB.**
8. **Pha 3 (đăng ký) là critical** — không cắt nếu thiếu người; pair BE-1 + BE-2.
9. **Cắt theo thứ tự nếu thiếu người:** Pha 8 (TKB) → Pha 6b (học lại) → Pha 9 (báo cáo). **Không cắt** Pha 3/5/6.
10. **Nền tảng (v2.5):** SV + GV chạy cả Web và App; Admin + PĐT + KT **chỉ Web**. Khi build App chỉ đóng gói route SV/GV — giảm dung lượng app và tránh phải làm UI mobile cho các màn hình bảng dữ liệu lớn.

---

*File này được tạo từ `plan.md` v2.5. Cập nhật khi có thay đổi nghiệp vụ.*
