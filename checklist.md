# CHECKLIST TRIỂN KHAI — HỆ THỐNG ĐĂNG KÝ MÔN HỌC

> **Nguồn:** `plan.md` v3.9 (nguồn duy nhất). File này chỉ để theo dõi tiến độ — **không định nghĩa quy tắc**;
> mỗi dòng trỏ về mục/BR trong plan. Có chỗ lệch giữa hai file ⇒ plan thắng, sửa checklist.
> **Cách dùng:** tick `[x]` khi xong; mỗi pha phải đạt **Milestone + DoD** (mục 10) mới sang pha sau.
> **Thời lượng:** ~10–11 tuần cho đội 4–5 người (plan mục 12).
> **Giao diện:** mọi màn Flutter bám mockup trong [`design_mockups/`](design_mockups/README.md) (bố cục, màu, câu chữ, hành vi); quy ước ở `design.md` mục 1.7–1.9.

---

## 0. TỔNG QUAN

| Hạng mục | Số lượng |
| :--- | :--- |
| Thực thể | 26 |
| Quy tắc nghiệp vụ | BR-01..26 (BR-24 đã gỡ → 25 quy tắc) |
| Chức năng | 59 (PDT 15 · SV 13 · GV 12 · KT 11 · ADM 8) |
| Vai trò | 5 — SV + GV: Web + App; Admin + PĐT + KT: chỉ Web |
| Celery job | 4 |
| Pha | 0 → 10 (Pha 8 tùy chọn) |

**Đã bỏ ở v3.0 (không làm):** cấm thi tự động (BR-24) · `GradeRetake`/học lại-cải thiện · lịch bù theo ngày ·
`RolePermission` (quyền cố định trong code) · restore DB qua API · trần tín chỉ theo học kỳ · `LECH_LT`/`LECH_TH` ·
hoàn tiền nhiều trạng thái · PDF · thông báo theo ngành/học kỳ.

---

## 1. PHA 0 — NỀN TẢNG ✅

- [x] Repo monorepo: `backend/`, `dang_ky_mon_hoc/`, `docs/`; Flutter chỉ giữ `android/ios/web`
- [x] CI 2 job theo path (backend: ruff + black + mypy + pytest · flutter: format + analyze + test)
- [x] Docker Compose (`backend/docker-compose.yml`): web · worker · beat · db (PostgreSQL 16) · redis · nginx
- [x] Skeleton Django: 10 app, settings base/dev/prod, `.env.example`
- [x] `core/`: envelope lỗi + mã lỗi (mục 8.4), phân trang, quyền theo role, `AuditLogMixin`, middleware `Idempotency-Key`
- [x] Models + migration cho 25 thực thể đầu
- [x] Thêm `Faculty` (khoa/viện) + FK `khoa` cho `Major`/`TeacherProfile`/`Course`; migrate `TeacherProfile.khoa_bo_mon` (chuỗi) → FK; `seed_demo` tạo khoa/viện (migration đã tạo lại từ đầu)
- [x] Swagger `/api/docs/`; Celery beat 4 job (stub trừ `flush_expired_tokens`)
- [x] `seed_demo` (idempotent): tài khoản, 2 ngành × 8 môn, 2 học kỳ, 6 lớp, bảng giá, điểm, điểm danh, lịch có thứ 7 + Chủ nhật
- [x] Flutter skeleton: Riverpod + GoRouter + Dio, theme Material 3, login/forgot-password, route theo vai trò
- [x] **Đồng bộ plan v3.0:** bỏ `cam_thi`/`GradeRetake`/`RolePermission`/`Schedule.ngay_hoc`/`Semester.tin_chi_*`;
      `Schedule.thu` 2..8; học phí dẫn xuất (`Payment.loai`); `AuditLog.doi_tuong_id` dạng chuỗi; CORS regex; `token_blacklist`
- [x] **Flutter v3.0:** hai entrypoint (`main.dart` Web · `main_app.dart` App) + `routes_<role>.dart`
- [x] Chạy thử trên PostgreSQL 16 qua Docker: `migrate` + `seed_demo` (2 lần, idempotent) + Swagger 200
- [x] venv Python **3.12** (`backend/.venv312`); CI/Docker cũng 3.12
- [x] **Bổ sung sau rà soát Pha 0:** `/api/health/` · `DEFAULT_FILTER_BACKENDS` (filter/search/ordering) ·
      `CACHES` Redis dùng chung · lỗi throttle → envelope `429 QUA_NHIEU_YEU_CAU` · hạ tầng test
      (`config/settings/test.py`, `conftest.py`, `core/factories.py`) · CI có PostgreSQL service ·
      worker/beat đợi web healthy · sửa `authentication.py` (gọi `business_error` sai tham số) ·
      Flutter `ApiClient` (đường dẫn `/api`, gắn Bearer, refresh lưu token xoay vòng, không deadlock) ·
      Swagger hợp lệ 0 cảnh báo (nút Authorize + request/response mọi view; có test) ·
      test hạ tầng `core/` (envelope, phân trang, middleware idempotency, IP client) ·
      `NUM_PROXIES` (rate limit không bị lách bằng `X-Forwarded-For`) · `createsuperuser` tạo `ADMIN`
      (migration `user.0002`) · `pytest-cov` (coverage `auth/services` 96%, tổng 85%)
- [ ] Thêm `services.py` cho từng app khi bắt đầu pha tương ứng (mục 1.2) — đã có: `auth`, `profiles`, `training`

---

## 2. PHA 1 — AUTH & HỒ SƠ (1 tuần)

**Backend (đã xong, 91 test qua trên PostgreSQL và SQLite):**
- [x] `User` 5 role, `is_locked`; login / refresh (rotate + blacklist) / logout — BR-22
- [x] `LockedAwareJWTAuthentication` chặn cả login lẫn refresh khi khóa
- [x] `forgot-password` (phản hồi **giống nhau** dù email có/không tồn tại; token 30 phút, 1 lần) · `reset-password` · `change-password` (blacklist refresh cũ)
- [x] Password policy ≥ 8 ký tự, có chữ + số
- [x] Rate limit login 10/phút/IP (không khóa theo tài khoản) · quên mật khẩu 3/15 phút/email
- [x] `GET/PATCH /api/profiles/me/` (chỉ sửa `email`, `sdt`; xếp loại học lực BR-25f)
- [x] `/api/profiles/students/` · `/api/profiles/teachers/` (PĐT sửa, Admin đọc) — PDT-01, ADM-03
- [x] `/api/users/` · `lock` · `reset-password` (Admin) — ADM-02; ghi audit LOGIN / PHAN_QUYEN
- [x] Job `flush_expired_tokens`

**Flutter:**
- [x] Ống dẫn API + phiên đăng nhập (không có giao diện): `ApiClient`, `AuthController`, map `role` backend → `UserRole`; 8 test
- [x] Build được cả hai entrypoint (`web -t lib/main.dart`, `web -t lib/main_app.dart`); đã kiểm tra bản App **không chứa** route `/admin`, `/pdt`, `/accountant`
- [x] Màn hình theo `design_mockups/`: đăng nhập (Web 2 cột / App), quên + đặt lại mật khẩu 3 bước, đổi mật khẩu, hồ sơ SV/GV (Web + App), `/web-only`, hộp thoại tài khoản (Admin/PĐT/KT)
- [x] Khung điều hướng: sidebar navy 260 · thanh icon 600–1024 · header navy + thanh dưới nổi (App) · AppBar + Drawer (3 vai trò Web-only) — đã xem trên trình duyệt với backend thật
- [x] Màn Admin quản lý tài khoản (`/admin/accounts`, ADM-02): lọc/tìm/phân trang, khóa-mở khóa (xác nhận), tạo, sửa (đổi vai trò có xác nhận), đặt lại mật khẩu, ngăn chi tiết hồ sơ học vụ
- [x] Màn PĐT quản lý hồ sơ SV/GV (`/pdt/profiles`, PDT-01): chip tài khoản chưa có hồ sơ (`GET /profiles/pending-accounts/`), tab Sinh viên / Giáo viên, tạo + sửa hồ sơ
- [x] **Milestone:** đăng nhập cả 5 role; khóa tài khoản chặn cả token đang dùng *(API và màn hình đã đạt)*

## 3. PHA 2 — DỮ LIỆU ĐÀO TẠO (1.5 tuần) ✅

**Backend (156 test qua; coverage `training` 99%; đã chạy thử trên PostgreSQL qua Docker):**
- [x] CRUD Faculty (PĐT; ngừng chỉ khi không còn ngành/GV hoạt động) · Major · Curriculum (unique `HOAT_DONG` mỗi ngành × khóa) · CurriculumCourse · Course (`tong_tin_chi` server tính) · Prerequisite (chống chu trình, DFS) — `GET` kèm số ngành/GV/môn (khoa), số CTĐT (ngành)
- [x] Semester + cửa sổ đăng ký (`PATCH /window/`); `open`/`close` (đóng: còn lớp `MO`/`DANG_HOC` → `409`)
- [x] ClassSection (`open`/`close`/`grade-deadline`; môn `NGUNG_SU_DUNG` không mở được; lớp `DA_DONG` không sửa; ngày lớp nằm trong học kỳ)
- [x] Schedule: BR-08 (`thu` 2..8, Chủ nhật = 8) · BR-09 · phòng/GV không giao tiết cùng `thu` (cùng học kỳ)
- [x] Job `classes_transition_daily` (mục 6, 7.8) — idempotent
- [x] `AuditLogMixin` áp cho các ViewSet ghi của pha này (kèm audit cho `open`/`close`/`grade-deadline`)
- [x] `Semester` `tin_chi_toi_thieu`/`tin_chi_toi_da`/`tin_chi_toi_da_canh_bao` (mặc định 12/24/14, PĐT sửa, có validate); lọc `?khoa=` `?nganh=`

**Flutter (Web, 79 test qua; bản App đã kiểm tra không chứa màn PĐT/Admin):**
- [x] PĐT: Khoa/viện · Ngành · CTĐT & gán môn · Môn học & tiên quyết · Học kỳ (cửa sổ + giới hạn tín chỉ + mở/đóng) · Lớp học phần & lịch (mở/đóng, gia hạn nhập điểm); ô chọn có gợi ý và lọc liên động (ngành → môn → giáo viên cùng khoa)
- [x] Lưới tuần của lịch lớp và hạn nhập điểm mặc định (`han_nhap_diem_hieu_luc`, BR-13) trong ngăn chi tiết lớp
- [x] **Milestone:** PĐT tạo đủ dữ liệu cho 1 học kỳ *(đã chạy luồng học kỳ → lớp → lịch → mở lớp trên API thật)*

## 4. PHA 3 — ĐĂNG KÝ (2 tuần) ⭐ critical — làm theo cặp ✅

- [x] `registration/services.py`: BR-01 · BR-02 · BR-03 · BR-04 · BR-07
- [x] BR-06: `SELECT … FOR UPDATE` + đọc lại sĩ số trong lock; hủy giảm sĩ số, không xuống dưới 0
- [x] BR-05: SV hủy (lớp `MO` + trong cửa sổ) · PĐT hủy hộ (lớp `MO`/`DANG_HOC`, bắt buộc `ly_do`, audit log)
- [x] Idempotency (mục 8.3): `request_id` UNIQUE DB; gán một lần lúc tạo; replay trả bản ghi cũ; key khác khi đã `DA_DANG_KY` → `409 DA_DANG_KY`
- [x] Tính lại học phí sau đăng ký/hủy — **ngoài transaction, không chặn**; lỗi → `warnings[]` (`CHUA_CAU_HINH_GIA`)
- [x] `GET /api/courses/available/` · `/registrations/history/` · `/registrations/` (PĐT) · `/registrations/export/`
- [x] Thông báo xác nhận đăng ký/hủy (trigger)
- [x] Flutter (PĐT): tab *Sinh viên đăng ký* trong ngăn chi tiết lớp (mockup `PDT-Web-LopHP`)
- [x] Flutter: SV xem lớp (**gom theo môn, bấm môn để xem các lớp học phần**), đăng ký, hủy, lịch sử (`/student/register`); lọc *Theo CTĐT + kỳ* và *Môn chưa học* (kết hợp được); TKB theo tuần có ngày thật (`/student/schedule`, `/timetable/my/`)
- [x] Bản Web: nút **In** thời khóa biểu — sinh tài liệu HTML A4 ngang riêng (iframe ẩn + `print()`), không in canvas; bản App không có nút
- [x] _Bổ sung:_ PĐT theo dõi đăng ký + hủy hộ + xuất Excel (`/pdt/registrations`); `GET /api/curriculums/my/`; `GET /api/timetable/my/` dùng chung SV/GV; `tuition/services.tinh_hoc_phi` (BR-15..17)
- [x] **Milestone:** 2 SV bấm chỗ cuối → chỉ 1 thành công (test trên PostgreSQL thật)

## 5. PHA 4 — ĐIỂM DANH (1 tuần) ✅

- [x] **Sinh sẵn `AttendanceSession`** khi lớp `MO` / khi PĐT sửa lịch-ngày lớp (chỉ sinh/xóa buổi tương lai chưa điểm danh) — BR-20; **không có** `POST /attendance/sessions/`
- [x] `GET …/sessions/?lop_hoc_phan=` (kèm `tong_so_buoi`) · `GET/PUT …/sessions/{id}/records/` (lưu cả lớp; chỉ buổi `ngay_hoc` ≤ hôm nay; lần lưu đầu → `DA_DIEM_DANH`) — BR-19/20
- [x] Tỷ lệ vắng = `VANG_KHONG_PHEP` / **tổng số buổi theo lịch** (cố định cả khóa; vắng có phép không tính) + cờ cảnh báo (`max_absent_pct`); `/attendance/my/` trả `tong_so_buoi`, `canh_bao_vang`, `so_buoi_vang_cho_phep`; **không** chặn nhập điểm
- [x] _(model + ràng buộc 1 yêu cầu chờ duyệt/buổi đã xong; còn API)_ `AttendanceRequest`: SV gửi (trạng thái mong muốn + `di_tre_mong_muon`, lý do bắt buộc, `minh_chung` tùy chọn ≤ 5 MB, `multipart`) · **chỉ GV (lớp mình)** xem minh chứng và duyệt → ghi lại `Attendance` (PĐT không duyệt); chỉ gửi/duyệt khi lớp `DANG_HOC`; đóng lớp ⇒ yêu cầu chờ tự `TU_CHOI` (`ghi_chu` quá hạn)
- [x] `/attendance/my/` · `/attendance/sessions/?lop_hoc_phan=` (danh sách buổi sinh sẵn)
- [x] Flutter (PĐT): tab *Điểm danh* (chỉ xem) trong ngăn chi tiết lớp
- [x] Flutter: GV điểm danh cả lớp; SV xem + xin sửa (chọn trạng thái mong muốn, lý do bắt buộc, minh chứng tùy chọn); **chỉ GV (lớp mình)** xem minh chứng và duyệt
- [x] Flutter: GV xem thời khóa biểu theo tuần (`/teacher/schedule`, dùng `/timetable/my/`); bản Web có nút **In** (`window.print()`, A4 ngang)
- [x] **Milestone:** GV điểm danh, SV xin sửa, GV duyệt *(đã chạy trọn luồng trên API thật với dữ liệu seed)*
- [x] _Bổ sung:_ `GET /api/class-sections/my/` (GV-03) để GV chọn lớp. _Hạn chế:_ bản App chưa mở được minh chứng (cần plugin mở tệp) — GV xem minh chứng trên Web

## 6. PHA 5 — ĐIỂM (1.5 tuần) ✅

- [x] `GET/PUT /class-sections/{id}/grades/` (nhập cả lớp, `NHAP_TAM`, xem trước BR-10)
- [x] `POST …/grades/lock/` `{lock|unlock}` cả lớp — BR-14 (unlock: lớp `DANG_HOC` + trong hạn, audit log)
- [x] BR-10 (NULL ≠ 0) · BR-11 (band liên tục, `DAT_KHONG_DAT` → P) · BR-12
- [x] BR-13: hạn mặc định có fallback `Semester.ngay_ket_thuc`; PĐT gia hạn / nhập hộ (audit log)
- [x] `POST …/grades/approve/` (PĐT, lớp `DA_DONG`) → `KHOA` → BR-25 (GPA, tín chỉ tích lũy, "lần mới nhất" theo `hoc_ky.ngay_bat_dau`)
- [x] Đóng lớp: mọi ĐK `DA_DANG_KY` có `Grade ≥ CHINH_THUC`
- [x] `/grades/my/` (chỉ `KHOA`)
- [x] Flutter: GV nhập điểm (lưới) + xem trước; PĐT duyệt; SV xem điểm **kèm thống kê từng học kỳ** (tín chỉ học/đạt, điểm TB, GPA, xếp loại; `grades/my.thong_ke[]`, BR-25g)
- [x] **Milestone:** nhập → khóa → đóng lớp → duyệt → SV xem; GPA đúng
- [x] _Bổ sung:_ `GET /api/grade-sheets/` (danh sách lớp + số dòng điểm theo trạng thái cho PĐT duyệt); `failureText` hiện nguyên thông điệp lỗi nghiệp vụ của server

## 7. PHA 6 — HỌC PHÍ (1.5 tuần) ✅

- [x] `pricing.py` (BR-16/17) — self-check đã có; nối vào service tính học phí
- [x] `HocPhanGia` (UNIQUE functional index) · `TuitionConfig` · `Discount` (`MIEN_GIAM`/`HOC_BONG`)
- [x] `POST /tuition/calculate/?hoc_ky=` (hàng loạt, lỗi giá → `400 CHUA_CAU_HINH_GIA`)
- [x] Giá trị dẫn xuất của `Tuition` (`mien_giam`, `phai_nop`, `thuc_thu`, `con_no`, `can_hoan`, trạng thái hiển thị)
- [x] `POST /tuition/payments/` — BR-26: `THU`/`HOAN`, `FOR UPDATE` trên `Tuition`, `request_id`, `SO_TIEN_KHONG_HOP_LE`
- [x] `GET /tuition/` · `/tuition/debts/` · `/tuition/my/` · biên lai
- [x] Job `tuition_overdue_notify`
- [x] Flutter: KT cấu hình + thu/hoàn; SV xem học phí và **thanh toán bằng chuyển khoản QR** (`/student/tuition/pay`: chọn toàn bộ/một phần ≤ `con_no`, QR sinh ở client từ `tuition/my.thanh_toan`, sao chép thông tin); KT đối soát theo nội dung `HOCPHI <ma_sv> <hoc_ky>`
- [x] _(khóa đã có trong `seed_demo`; còn `tuition/my`)_ `SystemConfig` thêm `ck_ngan_hang`, `ck_so_tai_khoan`, `ck_chu_tai_khoan` + `tuition/my` trả `thanh_toan{…}`
- [x] **Milestone:** tính đúng, thu/hoàn đúng; hủy môn đã thu dư → `can_hoan > 0`
- [x] _Bổ sung:_ `GET /api/tuition/{id}/` (chi tiết + giao dịch) và `GET /api/tuition/students/` (KT tra SV, chỉ mã SV/họ tên/ngành); KT được **đọc** học kỳ/ngành/lớp học phần (`PdtWriteKtRead`). _Hạn chế:_ mã QR là QR văn bản thông tin chuyển khoản (chưa phải VietQR chuẩn ngân hàng); chưa có nút "Tải mã QR về máy" và "Xuất danh sách" công nợ

## 8. PHA 7 — THÔNG BÁO & AUDIT (1 tuần)

- [x] Notification (`ROLE`/`CLASS`/`USER`) + NotificationRead; `read`, `read-all`; thu hồi
- [x] Trigger: đăng ký/hủy · lớp đổi lịch/phòng · điểm `KHOA` · học phí quá hạn
- [x] `AuditLogMixin` đủ cho mọi ViewSet ghi; `GET /admin/audit-logs/` lọc scope theo role
- [x] Flutter: thông báo cho 5 role (hộp thư, chuông + số chưa đọc, gửi theo vai trò/lớp/người, thu hồi); Web: màn nhật ký (lọc hành động/phạm vi/ngày, xem chi tiết)
- [x] **Milestone:** gửi đúng đích, log đầy đủ
- [x] _Ghi chú:_ phạm vi hiển thị thông báo lọc ở tầng Python (đủ cho quy mô đồ án; chuyển sang SQL nếu hộp thư lớn). GV chỉ gửi cho lớp mình; Admin không gửi cho lớp

## 9. PHA 8–10

**Pha 8 — TKB tự động (tùy chọn, 1 tuần)**
- [ ] `GET /auto-schedule/available-courses/` (không lọc trùng lịch)
- [ ] `AutoScheduleService` (pure Dart, greedy, tối đa 3 tổ hợp, test độc lập) + màn hình gợi ý → xác nhận → đăng ký
- [ ] Bước chọn môn: bộ lọc *Theo CTĐT + kỳ* và *Môn chưa học* (kết hợp được) (ghép `curriculums/my`) + chọn *giáo viên mong muốn* từng môn (điểm +8 / −10)
- [ ] **Milestone:** gợi ý được ≤ 3 tổ hợp hợp lệ

**Pha 9 — Báo cáo & Excel (0.5–1 tuần)**
- [ ] `core/export.py` (`openpyxl`, `?format=xlsx`) · báo cáo đào tạo + tài chính · xuất đăng ký / lớp / biên lai
- [ ] Flutter: PĐT/KT xem báo cáo, xuất file
- [ ] **Milestone:** báo cáo đúng, tải được file

**Pha 10 — Hoàn thiện (1 tuần)**
- [ ] Backup: `POST/GET /admin/backups/` (tạo + liệt kê file ở `BACKUP_DIR`, không restore) · job `backup_daily`
- [ ] `GET /admin/permissions/` (ma trận chỉ đọc) · `GET/PATCH /admin/config/`
- [ ] Rà rate limit / phân trang / mã lỗi · responsive Web + App · E2E · load test đăng ký (locust)
- [ ] Build: `flutter build web -t lib/main.dart` và `flutter build apk -t lib/main_app.dart`; xác nhận bản App không chứa màn Admin/PĐT/KT
- [ ] **Milestone:** production-ready

---

## 10. DEFINITION OF DONE (mỗi pha)

- [ ] Test pass; coverage `services.py` của pha ≥ 80%
- [ ] API đúng trên Swagger, đúng role, đúng mã lỗi mục 8.4 (không tự chế mã mới)
- [ ] Flutter build được Web và App (SV/GV), không lỗi console
- [ ] `ruff` + `black --check` + `mypy` sạch; `flutter analyze` sạch
- [ ] Review + merge PR
- [ ] Thay đổi nghiệp vụ cập nhật **trong plan.md** (đúng chỗ định nghĩa), rồi mới sửa checklist

---

## 11. THỰC THỂ (26) — model + migration ✅ ở Pha 0; cột Pha = pha làm API/nghiệp vụ

| # | Thực thể | App | Pha | Model |
| :---: | :--- | :--- | :---: | :---: |
| 1 | `User` | auth | 1 | [x] |
| 2 | `StudentProfile` | profiles | 1 | [x] |
| 3 | `TeacherProfile` | profiles | 1 | [x] |
| 4 | `Major` | training | 2 | [x] |
| 5 | `Curriculum` | training | 2 | [x] |
| 6 | `CurriculumCourse` | training | 2 | [x] |
| 7 | `Course` | training | 2 | [x] |
| 8 | `Prerequisite` | training | 2 | [x] |
| 9 | `Semester` | training | 2 | [x] |
| 10 | `ClassSection` | training | 2 | [x] |
| 11 | `Schedule` | training | 2 | [x] |
| 12 | `Registration` | registration | 3 | [x] |
| 13 | `AttendanceSession` | attendance | 4 | [x] |
| 14 | `Attendance` | attendance | 4 | [x] |
| 15 | `AttendanceRequest` | attendance | 4 | [x] |
| 16 | `Grade` | grades | 5 | [x] |
| 17 | `HocPhanGia` | tuition | 6 | [x] |
| 18 | `TuitionConfig` | tuition | 6 | [x] |
| 19 | `Discount` | tuition | 6 | [x] |
| 20 | `Payment` | tuition | 6 | [x] |
| 21 | `Tuition` | tuition | 6 | [x] |
| 22 | `Notification` | notifications | 7 | [x] |
| 23 | `NotificationRead` | notifications | 7 | [x] |
| 24 | `AuditLog` | audit | 7 | [x] |
| 25 | `SystemConfig` | config | 10 | [x] |
| 26 | `Faculty` | training | 2 | [x] |

## 12. QUY TẮC NGHIỆP VỤ — tick khi có code + test

| Mã | Tóm tắt | Pha | ✓ |
| :--- | :--- | :---: | :---: |
| BR-01 | Học kỳ `MO` + trong cửa sổ + lớp `MO` | 3 | [x] |
| BR-02 | Không vượt sĩ số | 3 | [x] |
| BR-03 | Trùng lịch: cùng `thu` + giao tiết (chỉ lịch định kỳ) | 3 | [x] |
| BR-04 | Tiên quyết; đã đạt (`diem_chu ≠ F`) → `DA_DAT_MON`; F học lại được; **một môn một lớp/học kỳ** → `DA_DANG_KY_MON` (d) | 3 | [x] |
| BR-05 | Hủy: SV (lớp `MO` + cửa sổ) · PĐT (lớp `MO`/`DANG_HOC`) | 3 | [x] |
| BR-06 | Transaction + `FOR UPDATE` chống overbook | 3 | [x] |
| BR-07 | Tín chỉ 12–24 · cảnh báo GPA < 2.0 → 14 · đọc từ `Semester` (PĐT đặt theo học kỳ) | 3 | [x] |
| BR-08 | 15 tiết/ngày; `thu` 2..8 (8 = Chủ nhật) | 2 | [x] |
| BR-09 | Bắt buộc `so_tiet_moi_buoi`, không vượt nhóm tiết | 2 | [x] |
| BR-10 | Tổng kết 10/40/50 + fallback (NULL ≠ 0) | 5 | [x] |
| BR-11 | Thang chữ band liên tục; P/F; đạt = ≠ F | 5 | [x] |
| BR-12 | GV chỉ nhập lớp mình | 5 | [x] |
| BR-13 | Hạn nhập điểm + gia hạn / nhập hộ | 5 | [x] |
| BR-14 | `NHAP_TAM` → `CHINH_THUC` → `KHOA`; unlock có điều kiện | 5 | [x] |
| BR-15 | Học phí = Σ môn; tính lại bất cứ lúc nào | 6 | [x] |
| BR-16 | Tra giá 2 trục `hoc_ky` × khối → ngành → mặc định | 6 | [x] |
| BR-17 | LT = giá gốc; TH = `GIA_TH` nếu có | 6 | [x] |
| BR-18 | Miễn giảm do KT, có audit log | 6 | [x] |
| BR-19 | 3 trạng thái điểm danh + cờ `di_tre` (chỉ khi `CO_MAT`; UI 4 nút) | 4 | [x] |
| BR-20 | Buổi điểm danh sinh sẵn theo lịch; tỷ lệ vắng = vắng KP / tổng số buổi theo lịch + cờ cảnh báo | 4 | [x] |
| BR-21 | Phân quyền 5 vai trò | 1–10 | [ ] |
| BR-22 | JWT; khóa tài khoản chặn login + refresh | 1 | [ ] |
| BR-23 | SV chỉ dữ liệu mình; GV chỉ lớp mình | 1–10 | [ ] |
| BR-24 | *(đã gỡ v3.0)* | — | — |
| BR-25 | GPA, tín chỉ tích lũy, xếp loại | 5 | [x] |
| BR-26 | Thu / hoàn tiền: `FOR UPDATE`, không vượt `con_no` / `can_hoan` | 6 | [x] |

## 13. ENDPOINT — tick khi có code + test + Swagger

**Auth & chung:** [ ] login · [ ] logout · [ ] refresh · [ ] forgot-password · [ ] reset-password · [ ] change-password ·
[ ] profiles/me · [ ] health · [x] notifications (list / read / read-all / gửi / thu hồi)

**Admin:** [ ] users · [ ] users/{id}/lock · [ ] users/{id}/reset-password · [ ] admin/permissions (GET) ·
[ ] admin/config · [x] admin/audit-logs · [ ] admin/backups (GET/POST)

**PĐT:** [ ] profiles/students · [ ] profiles/teachers · [x] faculties · [x] majors · [x] curriculums · [x] curriculum-courses ·
[x] courses · [x] prerequisites · [x] semesters (+ open/close/window) · [x] class-sections (+ open/close/grade-deadline) ·
[x] schedules · [x] registrations (GET/DELETE/export) · [x] attendance/sessions (xem) ·
[x] class-sections/{id}/grades/approve · [ ] reports/training (+ export)

**SV:** [x] curriculums/my · [x] courses/available · [ ] auto-schedule/available-courses · [x] registrations (POST/DELETE) ·
[x] registrations/history · [x] timetable/my · [x] attendance/my · [x] attendance/requests (GET/POST) · [x] grades/my · [x] tuition/my

**GV:** [x] class-sections/my · [ ] class-sections/{id} · [ ] class-sections/{id}/students ·
[x] attendance/sessions (GET, sinh sẵn) · [x] attendance/sessions/{id}/records (GET/PUT) · [x] attendance/requests (GET/PATCH, chỉ lớp mình) ·
[x] class-sections/{id}/grades (GET/PUT) · [x] class-sections/{id}/grades/lock · [ ] class-sections/{id}/export

**KT:** [x] tuition/config · [x] tuition/pricing · [x] tuition/discounts · [x] tuition (GET) · [x] tuition/calculate ·
[x] tuition/payments · [x] tuition/debts · [x] tuition/payments/{id}/receipt · [ ] reports/finance (+ export)

## 14. TEST BẮT BUỘC (plan mục 13)

- [x] 2 SV cùng bấm chỗ cuối → 1 thành công; sĩ số không lệch sau hủy / đăng ký lại *(PostgreSQL thật)*
- [ ] Replay `Idempotency-Key` (đăng ký, thanh toán); re-activate không đổi `request_id`; key khác khi đã đăng ký → `409 DA_DANG_KY`
- [x] Thanh toán đồng thời không vượt `phai_nop`; `SO_TIEN_KHONG_HOP_LE` (vượt `con_no` / `can_hoan` / ≤ 0)
- [x] `LOP_CHUA_MO` (lớp `KE_HOACH`/`DANG_HOC`/`DA_DONG`) · `NGOAI_CUA_SO_DANG_KY`
- [x] Trùng lịch (cùng `thu` giao tiết); không giao tiết → hợp lệ; thứ 7 + Chủ nhật hợp lệ; `thu = 1`/`9` → 400
- [x] BR-04(d): đã đăng ký lớp A của môn X, đăng ký lớp B của X cùng học kỳ → `409 DA_DANG_KY_MON`; hủy A rồi đăng ký B được
- [x] BR-04: `THIEU_TIEN_QUYET`; `DA_DAT_MON` (kể cả điểm D); F đăng ký lại được; chu trình tiên quyết → 400
- [x] BR-07: vượt tối đa · dưới tối thiểu → 201 + warning · GPA < 2.0 vượt 14 · GPA NULL không bị giới hạn
- [x] Hủy: SV khi lớp `DANG_HOC` → `409`; PĐT hủy hộ lớp `DANG_HOC` OK (lý do bắt buộc, sĩ số giảm, học phí tính lại)
- [x] BR-10: thiếu GK → 20/80; CK NULL vs 0
- [x] BR-11: 8.45/6.95/5.45 → B/C/D · biên 8.50/7.00/5.50/4.00 → A/B/C/D · 3.99 → F · `DAT_KHONG_DAT` → P (ngoài GPA) · F trong mẫu GPA
- [x] BR-25: học lại môn F chỉ tính lần mới nhất (theo `hoc_ky.ngay_bat_dau`); điểm D cộng tín chỉ tích lũy
- [x] BR-13: fallback `ngay_ket_thuc` NULL; `QUA_HAN_NHAP_DIEM`; gia hạn / nhập hộ có audit log
- [x] BR-14: unlock chỉ khi `DANG_HOC` + trong hạn; `KHOA` bất biến
- [x] Đóng lớp chỉ khi đủ `Grade ≥ CHINH_THUC`; học phí không chặn; đóng học kỳ còn lớp → `409`
- [x] Buổi sinh sẵn: lớp 01/10–05/11 chỉ thứ 5 → 6 buổi; sửa lịch chỉ đổi buổi tương lai chưa điểm danh; điểm danh buổi tương lai → `TRANG_THAI_KHONG_HOP_LE`
- [x] Yêu cầu sửa điểm danh: lớp `DA_DONG` không gửi được; đóng lớp → yêu cầu chờ tự từ chối; chỉ GV lớp đó duyệt được
- [x] Tỷ lệ vắng: mẫu số = tổng buổi theo lịch (1/6 không cờ, 2/6 có cờ); vắng có phép không tính; cờ không chặn nhập CK
- [x] Học phí: ưu tiên `hoc_ky` → NULL; khối → ngành → mặc định; `GIA_TH`; thiếu giá → `calculate` 400 nhưng đăng ký vẫn 201 + warning; hủy hết môn đã thu → `can_hoan > 0`; UNIQUE `MAC_DINH` cùng `hoc_ky`
- [ ] Token: khóa chặn request + refresh; logout / đổi / reset blacklist refresh cũ; reset token 30 phút 1 lần; forgot-password không lộ email
- [ ] Phân quyền: mỗi endpoint một test sai role; SV không xem SV khác; GV không xem lớp khác
- [ ] Flutter: widget test Web + App; mọi route nằm dưới prefix vai trò (đã có); E2E đăng ký → điểm → học phí

## 15. TRIỂN KHAI

- [ ] `DEBUG=False`, `SECRET_KEY` từ env, `PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE=False`
- [ ] CORS prod = danh sách origin tường minh (không dùng regex localhost)
- [ ] `NUM_PROXIES=1` (mặc định ở `prod.py`) và **không publish cổng `web`** ra ngoài, chỉ nginx
- [ ] Tạo Admin đầu tiên: `python manage.py createsuperuser` (vai trò tự là `ADMIN`)
- [ ] HTTPS (nginx + certbot)
- [ ] `pg_dump` trước mỗi lần migrate prod
- [ ] Backup daily chạy được; thử restore tay một lần bằng `pg_restore`
- [ ] Log tập trung; `/api/health/` + monitoring (kể cả trạng thái worker)

---

*Tạo từ `plan.md` v3.9 (cập nhật 2026-10-11). Cập nhật khi plan đổi.*
