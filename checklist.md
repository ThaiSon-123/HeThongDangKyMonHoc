# CHECKLIST TRIỂN KHAI — HỆ THỐNG ĐĂNG KÝ MÔN HỌC

> **Nguồn:** `plan.md` v3.0 (nguồn duy nhất). File này chỉ để theo dõi tiến độ — **không định nghĩa quy tắc**;
> mỗi dòng trỏ về mục/BR trong plan. Có chỗ lệch giữa hai file ⇒ plan thắng, sửa checklist.
> **Cách dùng:** tick `[x]` khi xong; mỗi pha phải đạt **Milestone + DoD** (mục 10) mới sang pha sau.
> **Thời lượng:** ~10–11 tuần cho đội 4–5 người (plan mục 12).

---

## 0. TỔNG QUAN

| Hạng mục | Số lượng |
| :--- | :--- |
| Thực thể | 25 |
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
- [x] Models + migration cho cả 25 thực thể
- [x] Swagger `/api/docs/`; Celery beat 4 job (stub trừ `flush_expired_tokens`)
- [x] `seed_demo` (idempotent): tài khoản, 2 ngành × 8 môn, 2 học kỳ, 6 lớp, bảng giá, điểm, điểm danh, lịch có thứ 7 + Chủ nhật
- [x] Flutter skeleton: Riverpod + GoRouter + Dio, theme Material 3, login/forgot-password, route theo vai trò
- [x] **Đồng bộ plan v3.0:** bỏ `cam_thi`/`GradeRetake`/`RolePermission`/`Schedule.ngay_hoc`/`Semester.tin_chi_*`;
      `Schedule.thu` 2..8; học phí dẫn xuất (`Payment.loai`); `AuditLog.doi_tuong_id` dạng chuỗi; CORS regex; `token_blacklist`
- [x] **Flutter v3.0:** hai entrypoint (`main.dart` Web · `main_app.dart` App) + `routes_<role>.dart`
- [ ] Chạy thử trên máy có Docker/PostgreSQL: `docker compose up`, `migrate`, `seed_demo` *(đã chạy trên SQLite, chưa chạy trên PostgreSQL)*
- [ ] Tạo lại venv Python **3.12** (venv hiện tại là 3.14.7 — Django 5.1 chưa hỗ trợ)
- [ ] Thêm `services.py` cho từng app khi bắt đầu pha tương ứng (mục 1.2)

---

## 2. PHA 1 — AUTH & HỒ SƠ (1 tuần)

- [ ] `User` 5 role, `is_locked`; login / refresh (rotate + blacklist) / logout — BR-22
- [ ] `LockedAwareJWTAuthentication` chặn cả login lẫn refresh khi khóa
- [ ] `forgot-password` (phản hồi **giống nhau** dù email có/không tồn tại; token 30 phút, 1 lần) · `reset-password` · `change-password` (blacklist refresh cũ)
- [ ] Password policy ≥ 8 ký tự, có chữ + số
- [ ] Rate limit login 10/phút/IP (không khóa theo tài khoản) · quên mật khẩu 3/15 phút/email
- [ ] `GET/PATCH /api/profiles/me/` (chỉ sửa `email`, `sdt`)
- [ ] `/api/profiles/students/` · `/api/profiles/teachers/` (PĐT sửa, Admin đọc) — PDT-01, ADM-03
- [ ] `/api/users/` · `lock` · `reset-password` (Admin) — ADM-02
- [ ] Job `flush_expired_tokens`
- [ ] Flutter: login, forgot/reset, đổi mật khẩu, xem/sửa hồ sơ
- [ ] **Milestone:** đăng nhập cả 5 role; khóa tài khoản chặn cả token đang dùng

## 3. PHA 2 — DỮ LIỆU ĐÀO TẠO (1.5 tuần)

- [ ] CRUD Major · Curriculum (unique `HOAT_DONG` mỗi ngành × khóa) · CurriculumCourse · Course · Prerequisite (chống chu trình, DFS)
- [ ] Semester + cửa sổ đăng ký (`PATCH /window/`); `open`/`close` (đóng: hết lớp `MO`/`DANG_HOC` → `409`)
- [ ] ClassSection (`open`/`close`/`grade-deadline`; môn `NGUNG_SU_DUNG` không mở được)
- [ ] Schedule: BR-08 (`thu` 2..8, Chủ nhật = 8) · BR-09 · phòng/GV không giao tiết cùng `thu`
- [ ] Job `classes_transition_daily` (mục 6, 7.8)
- [ ] `AuditLogMixin` áp cho các ViewSet ghi của pha này
- [ ] Flutter (Web): PĐT quản lý ngành / CTĐT / môn / học kỳ / lớp / lịch
- [ ] **Milestone:** PĐT tạo đủ dữ liệu cho 1 học kỳ

## 4. PHA 3 — ĐĂNG KÝ (2 tuần) ⭐ critical — làm theo cặp

- [ ] `registration/services.py`: BR-01 · BR-02 · BR-03 · BR-04 · BR-07
- [ ] BR-06: `SELECT … FOR UPDATE` + đọc lại sĩ số trong lock; hủy giảm sĩ số, không xuống dưới 0
- [ ] BR-05: SV hủy (lớp `MO` + trong cửa sổ) · PĐT hủy hộ (lớp `MO`/`DANG_HOC`, bắt buộc `ly_do`, audit log)
- [ ] Idempotency (mục 8.3): `request_id` UNIQUE DB; gán một lần lúc tạo; replay trả bản ghi cũ; key khác khi đã `DA_DANG_KY` → `409 DA_DANG_KY`
- [ ] Tính lại học phí sau đăng ký/hủy — **ngoài transaction, không chặn**; lỗi → `warnings[]` (`CHUA_CAU_HINH_GIA`)
- [ ] `GET /api/courses/available/` · `/registrations/history/` · `/registrations/` (PĐT) · `/registrations/export/`
- [ ] Thông báo xác nhận đăng ký/hủy (trigger)
- [ ] Flutter: SV xem lớp, đăng ký, hủy, lịch sử, TKB (`/timetable/my/`)
- [ ] **Milestone:** 2 SV bấm chỗ cuối → chỉ 1 thành công (test trên PostgreSQL thật)

## 5. PHA 4 — ĐIỂM DANH (1 tuần)

- [ ] `POST /attendance/sessions/` (lớp `DANG_HOC`) · `GET/PUT …/sessions/{id}/records/` (lưu cả lớp) — BR-19/20
- [ ] Tỷ lệ vắng + cờ cảnh báo (`max_absent_pct`), mẫu số 0 an toàn; **không** chặn nhập điểm
- [ ] `AttendanceRequest`: SV gửi · GV (lớp mình)/PĐT duyệt → ghi lại `Attendance`
- [ ] `/attendance/my/` · `/attendance/sessions/?lop_hoc_phan=` (lịch sử)
- [ ] Flutter: GV điểm danh cả lớp; SV xem + xin sửa
- [ ] **Milestone:** GV điểm danh, SV xin sửa, GV/PĐT duyệt

## 6. PHA 5 — ĐIỂM (1.5 tuần)

- [ ] `GET/PUT /class-sections/{id}/grades/` (nhập cả lớp, `NHAP_TAM`, xem trước BR-10)
- [ ] `POST …/grades/lock/` `{lock|unlock}` cả lớp — BR-14 (unlock: lớp `DANG_HOC` + trong hạn, audit log)
- [ ] BR-10 (NULL ≠ 0) · BR-11 (band liên tục, `DAT_KHONG_DAT` → P) · BR-12
- [ ] BR-13: hạn mặc định có fallback `Semester.ngay_ket_thuc`; PĐT gia hạn / nhập hộ (audit log)
- [ ] `POST …/grades/approve/` (PĐT, lớp `DA_DONG`) → `KHOA` → BR-25 (GPA, tín chỉ tích lũy, "lần mới nhất" theo `hoc_ky.ngay_bat_dau`)
- [ ] Đóng lớp: mọi ĐK `DA_DANG_KY` có `Grade ≥ CHINH_THUC`
- [ ] `/grades/my/` (chỉ `KHOA`)
- [ ] Flutter: GV nhập điểm (lưới) + xem trước; PĐT duyệt; SV xem điểm
- [ ] **Milestone:** nhập → khóa → đóng lớp → duyệt → SV xem; GPA đúng

## 7. PHA 6 — HỌC PHÍ (1.5 tuần)

- [ ] `pricing.py` (BR-16/17) — self-check đã có; nối vào service tính học phí
- [ ] `HocPhanGia` (UNIQUE functional index) · `TuitionConfig` · `Discount` (`MIEN_GIAM`/`HOC_BONG`)
- [ ] `POST /tuition/calculate/?hoc_ky=` (hàng loạt, lỗi giá → `400 CHUA_CAU_HINH_GIA`)
- [ ] Giá trị dẫn xuất của `Tuition` (`mien_giam`, `phai_nop`, `thuc_thu`, `con_no`, `can_hoan`, trạng thái hiển thị)
- [ ] `POST /tuition/payments/` — BR-26: `THU`/`HOAN`, `FOR UPDATE` trên `Tuition`, `request_id`, `SO_TIEN_KHONG_HOP_LE`
- [ ] `GET /tuition/` · `/tuition/debts/` · `/tuition/my/` · biên lai
- [ ] Job `tuition_overdue_notify`
- [ ] Flutter: KT cấu hình + thu/hoàn; SV xem học phí
- [ ] **Milestone:** tính đúng, thu/hoàn đúng; hủy môn đã thu dư → `can_hoan > 0`

## 8. PHA 7 — THÔNG BÁO & AUDIT (1 tuần)

- [ ] Notification (`ROLE`/`CLASS`/`USER`) + NotificationRead; `read`, `read-all`; thu hồi
- [ ] Trigger: đăng ký/hủy · lớp đổi lịch/phòng · điểm `KHOA` · học phí quá hạn
- [ ] `AuditLogMixin` đủ cho mọi ViewSet ghi; `GET /admin/audit-logs/` lọc scope theo role
- [ ] Flutter: thông báo cho 5 role; Web: màn audit log
- [ ] **Milestone:** gửi đúng đích, log đầy đủ

## 9. PHA 8–10

**Pha 8 — TKB tự động (tùy chọn, 1 tuần)**
- [ ] `GET /auto-schedule/available-courses/` (không lọc trùng lịch)
- [ ] `AutoScheduleService` (pure Dart, greedy, tối đa 3 tổ hợp, test độc lập) + màn hình gợi ý → xác nhận → đăng ký
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

## 11. THỰC THỂ (25) — model + migration ✅ ở Pha 0; cột Pha = pha làm API/nghiệp vụ

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

## 12. QUY TẮC NGHIỆP VỤ — tick khi có code + test

| Mã | Tóm tắt | Pha | ✓ |
| :--- | :--- | :---: | :---: |
| BR-01 | Học kỳ `MO` + trong cửa sổ + lớp `MO` | 3 | [ ] |
| BR-02 | Không vượt sĩ số | 3 | [ ] |
| BR-03 | Trùng lịch: cùng `thu` + giao tiết (chỉ lịch định kỳ) | 3 | [ ] |
| BR-04 | Tiên quyết; đã đạt (`diem_chu ≠ F`) → `DA_DAT_MON`; F học lại được | 3 | [ ] |
| BR-05 | Hủy: SV (lớp `MO` + cửa sổ) · PĐT (lớp `MO`/`DANG_HOC`) | 3 | [ ] |
| BR-06 | Transaction + `FOR UPDATE` chống overbook | 3 | [ ] |
| BR-07 | Tín chỉ 12–24 · cảnh báo GPA < 2.0 → 14 · `SystemConfig` | 3 | [ ] |
| BR-08 | 15 tiết/ngày; `thu` 2..8 (8 = Chủ nhật) | 2 | [ ] |
| BR-09 | Bắt buộc `so_tiet_moi_buoi`, không vượt nhóm tiết | 2 | [ ] |
| BR-10 | Tổng kết 10/40/50 + fallback (NULL ≠ 0) | 5 | [ ] |
| BR-11 | Thang chữ band liên tục; P/F; đạt = ≠ F | 5 | [ ] |
| BR-12 | GV chỉ nhập lớp mình | 5 | [ ] |
| BR-13 | Hạn nhập điểm + gia hạn / nhập hộ | 5 | [ ] |
| BR-14 | `NHAP_TAM` → `CHINH_THUC` → `KHOA`; unlock có điều kiện | 5 | [ ] |
| BR-15 | Học phí = Σ môn; tính lại bất cứ lúc nào | 6 | [ ] |
| BR-16 | Tra giá 2 trục `hoc_ky` × khối → ngành → mặc định | 6 | [ ] |
| BR-17 | LT = giá gốc; TH = `GIA_TH` nếu có | 6 | [ ] |
| BR-18 | Miễn giảm do KT, có audit log | 6 | [ ] |
| BR-19 | 3 trạng thái điểm danh + cờ `di_tre` | 4 | [ ] |
| BR-20 | Điểm danh theo buổi; tỷ lệ vắng + cờ cảnh báo | 4 | [ ] |
| BR-21 | Phân quyền 5 vai trò | 1–10 | [ ] |
| BR-22 | JWT; khóa tài khoản chặn login + refresh | 1 | [ ] |
| BR-23 | SV chỉ dữ liệu mình; GV chỉ lớp mình | 1–10 | [ ] |
| BR-24 | *(đã gỡ v3.0)* | — | — |
| BR-25 | GPA, tín chỉ tích lũy, xếp loại | 5 | [ ] |
| BR-26 | Thu / hoàn tiền: `FOR UPDATE`, không vượt `con_no` / `can_hoan` | 6 | [ ] |

## 13. ENDPOINT — tick khi có code + test + Swagger

**Auth & chung:** [ ] login · [ ] logout · [ ] refresh · [ ] forgot-password · [ ] reset-password · [ ] change-password ·
[ ] profiles/me · [ ] health · [ ] notifications (list / read / read-all / gửi / thu hồi)

**Admin:** [ ] users · [ ] users/{id}/lock · [ ] users/{id}/reset-password · [ ] admin/permissions (GET) ·
[ ] admin/config · [ ] admin/audit-logs · [ ] admin/backups (GET/POST)

**PĐT:** [ ] profiles/students · [ ] profiles/teachers · [ ] majors · [ ] curriculums · [ ] curriculum-courses ·
[ ] courses · [ ] prerequisites · [ ] semesters (+ open/close/window) · [ ] class-sections (+ open/close/grade-deadline) ·
[ ] schedules · [ ] registrations (GET/DELETE/export) · [ ] attendance/sessions (xem) ·
[ ] attendance/requests (PATCH) · [ ] class-sections/{id}/grades/approve · [ ] reports/training (+ export)

**SV:** [ ] curriculums/my · [ ] courses/available · [ ] auto-schedule/available-courses · [ ] registrations (POST/DELETE) ·
[ ] registrations/history · [ ] timetable/my · [ ] attendance/my · [ ] attendance/requests (GET/POST) · [ ] grades/my · [ ] tuition/my

**GV:** [ ] class-sections/my · [ ] class-sections/{id} · [ ] class-sections/{id}/students ·
[ ] attendance/sessions (POST) · [ ] attendance/sessions/{id}/records (GET/PUT) ·
[ ] class-sections/{id}/grades (GET/PUT) · [ ] class-sections/{id}/grades/lock · [ ] class-sections/{id}/export

**KT:** [ ] tuition/config · [ ] tuition/pricing · [ ] tuition/discounts · [ ] tuition (GET) · [ ] tuition/calculate ·
[ ] tuition/payments · [ ] tuition/debts · [ ] tuition/payments/{id}/receipt · [ ] reports/finance (+ export)

## 14. TEST BẮT BUỘC (plan mục 13)

- [ ] 2 SV cùng bấm chỗ cuối → 1 thành công; sĩ số không lệch sau hủy / đăng ký lại *(PostgreSQL thật)*
- [ ] Replay `Idempotency-Key` (đăng ký, thanh toán); re-activate không đổi `request_id`; key khác khi đã đăng ký → `409 DA_DANG_KY`
- [ ] Thanh toán đồng thời không vượt `phai_nop`; `SO_TIEN_KHONG_HOP_LE` (vượt `con_no` / `can_hoan` / ≤ 0)
- [ ] `LOP_CHUA_MO` (lớp `KE_HOACH`/`DANG_HOC`/`DA_DONG`) · `NGOAI_CUA_SO_DANG_KY`
- [ ] Trùng lịch (cùng `thu` giao tiết); không giao tiết → hợp lệ; thứ 7 + Chủ nhật hợp lệ; `thu = 1`/`9` → 400
- [ ] BR-04: `THIEU_TIEN_QUYET`; `DA_DAT_MON` (kể cả điểm D); F đăng ký lại được; chu trình tiên quyết → 400
- [ ] BR-07: vượt tối đa · dưới tối thiểu → 201 + warning · GPA < 2.0 vượt 14 · GPA NULL không bị giới hạn
- [ ] Hủy: SV khi lớp `DANG_HOC` → `409`; PĐT hủy hộ lớp `DANG_HOC` OK (lý do bắt buộc, sĩ số giảm, học phí tính lại)
- [ ] BR-10: thiếu GK → 20/80; CK NULL vs 0
- [ ] BR-11: 8.45/6.95/5.45 → B/C/D · biên 8.50/7.00/5.50/4.00 → A/B/C/D · 3.99 → F · `DAT_KHONG_DAT` → P (ngoài GPA) · F trong mẫu GPA
- [ ] BR-25: học lại môn F chỉ tính lần mới nhất (theo `hoc_ky.ngay_bat_dau`); điểm D cộng tín chỉ tích lũy
- [ ] BR-13: fallback `ngay_ket_thuc` NULL; `QUA_HAN_NHAP_DIEM`; gia hạn / nhập hộ có audit log
- [ ] BR-14: unlock chỉ khi `DANG_HOC` + trong hạn; `KHOA` bất biến
- [ ] Đóng lớp chỉ khi đủ `Grade ≥ CHINH_THUC`; học phí không chặn; đóng học kỳ còn lớp → `409`
- [ ] Tỷ lệ vắng > ngưỡng chỉ hiện cờ, không chặn nhập CK; mẫu số 0 không lỗi
- [ ] Học phí: ưu tiên `hoc_ky` → NULL; khối → ngành → mặc định; `GIA_TH`; thiếu giá → `calculate` 400 nhưng đăng ký vẫn 201 + warning; hủy hết môn đã thu → `can_hoan > 0`; UNIQUE `MAC_DINH` cùng `hoc_ky`
- [ ] Token: khóa chặn request + refresh; logout / đổi / reset blacklist refresh cũ; reset token 30 phút 1 lần; forgot-password không lộ email
- [ ] Phân quyền: mỗi endpoint một test sai role; SV không xem SV khác; GV không xem lớp khác
- [ ] Flutter: widget test Web + App; mọi route nằm dưới prefix vai trò (đã có); E2E đăng ký → điểm → học phí

## 15. TRIỂN KHAI

- [ ] `DEBUG=False`, `SECRET_KEY` từ env, `PASSWORD_RESET_RETURN_TOKEN_IN_RESPONSE=False`
- [ ] CORS prod = danh sách origin tường minh (không dùng regex localhost)
- [ ] HTTPS (nginx + certbot)
- [ ] `pg_dump` trước mỗi lần migrate prod
- [ ] Backup daily chạy được; thử restore tay một lần bằng `pg_restore`
- [ ] Log tập trung; `/api/health/` + monitoring (kể cả trạng thái worker)

---

*Tạo từ `plan.md` v3.0 (2026-10-10). Cập nhật khi plan đổi.*
