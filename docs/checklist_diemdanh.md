# Checklist triển khai: Điểm danh khuôn mặt + GPS

> Đi kèm kế hoạch `docs/ke-hoach-diem-danh-khuon-mat-gps.md` (gọi tắt **KH**, số mục ghi dạng KH §x).
> Code nguồn để chép: `D:\DiemDanhKhuonMat_GPS` (gọi tắt **NGUỒN**).
> Đánh dấu `[x]` khi xong. Mỗi đợt chỉ coi là xong khi phần **Kiểm tra** của đợt đó chạy xanh.

---

## Tiến độ (cập nhật 12/11/2026)

**Đã xong Đợt 0–2 (backend):** `pytest` toàn dự án xanh (1408 test).
- Lõi: `apps/attendance/face/` (YuNet + ArcFace R50 + MiniFASNetV2), `geo.py`, `room_token.py`, `crypto.py`. Model ONNX ở `backend/face_models/` (sha256 khớp README, không đưa lên git).
- Dữ liệu: migration **0005** (giữ 0004 vì đã push), bỏ `FaceProfile` và cột v0, thêm `FaceTemplate`, `Consent`, `Challenge`, `CheckinAttempt`, xóa cấu hình tọa độ trường v0.
- Nghiệp vụ: `apps/attendance/tu_diem_danh.py`. API: `apps/attendance/views_tu_diem_danh.py`, khai báo trong `config/api_urls.py` và bảng quyền `core/tests/test_phan_quyen.py`.
- Test: `apps/attendance/tests/test_tu_diem_danh.py` (28 test) + test lõi port từ NGUỒN.

**Khác so với checklist gốc:**
- Ngưỡng khuôn mặt / GPS đặt ở `settings.FACE`, `settings.GPS`, `settings.TU_DIEM_DANH` (sửa rồi khởi động lại server), không đưa lên trang cấu hình PĐT. Trang PĐT chỉ có r₀ mặc định và số phút mở phiên.
- Lỗi nghiệp vụ dùng mã có sẵn (`TRANG_THAI_KHONG_HOP_LE`, `QUA_NHIEU_YEU_CAU`, `KHONG_CO_QUYEN`) + `details.ly_do` (`CHUA_CO_MAT`, `MO_HINH_DOI`, `HET_LUOT`, `DA_CO_MAT`, `NONCE_SAI`, `GPS_KEM`, `PHIEN_DONG`), vì dự án không cho tự thêm mã lỗi.
- Chi tiết SV trong phiên: `GET /api/attendance/sessions/{id}/luot/?sinh_vien=`. Thêm `DELETE /api/attendance/consent/` (rút lại đồng ý = thu hồi mẫu mặt).
- Ảnh mã hóa nằm ở `MEDIA_ROOT/diem_danh/` (volume `media` có sẵn).

**Đã xong Đợt 3–4 (Flutter, 13/11/2026):** 299 test Flutter xanh.
- SV: `/student/face` (đồng ý, đăng ký 3 tư thế, trạng thái, xóa, rút lại), `/student/checkin` (phiên đang mở → thử thách → mã phòng gõ tay → GPS 6 giây → chụp chuỗi 6 khung → kết quả).
- GV: `/teacher/self-attendance` (mở phiên lấy GPS 10 giây, đếm ngược, làm mới 4 giây, lọc, chi tiết lượt + ảnh bằng chứng, duyệt đáng ngờ, điểm danh thủ công, hàng loạt, tính lại tâm, đóng / mở lại), `/teacher/faces`. PĐT: `/pdt/faces`.
- Chạy thật trên web với backend Docker: GV mở phiên, SV thấy phiên và nhận đúng thông báo "chưa có mẫu mặt". Chưa thử chụp ảnh thật (trình duyệt tự động không cấp quyền camera).

**Đã tích `[x]` (14/11/2026)** các mục Đợt 0–4 đã có trong code và đối chiếu được (`flutter test` 299 xanh, `flutter analyze` sạch, OpenAPI không warning). Các mục chưa tích là phần còn thiếu thật, gồm:
- 0.2 (các quyết định còn mở, trừ phiên bản văn bản đồng ý `v1`), 1.2 (file `.onnx` và sha256: không đưa lên git, phải kiểm trên máy có model), ngưỡng nằm ở `settings.FACE` nên 1.7 chỉ tích phần đã làm, 135 (data migration xóa khóa cũ).
- 2.1: migration 0005 xóa `mo_diem_danh_den` rồi thêm `het_han_luc` (không phải `RenameField`), đăng ký admin; 2.2: chưa kiểm tra "suy luận ngoài transaction"; 2.3: chưa đặt `DATA_UPLOAD_MAX_MEMORY_SIZE` (nginx đã `client_max_body_size 20m`).
- Kiểm tra Đợt 2: chưa tích GV lớp khác xem bằng chứng (403), audit; "toàn bộ test cũ xanh": khi chạy lại trong Docker có 1 test lỗi `test_prod_an_toan_mac_dinh` vì `.env` local đặt `NUM_PROXIES=0` (không phải lỗi code).
- Đợt 3: thiếu `mobile_scanner` và `uuid` trong `pubspec.yaml`, chưa có nút mở cài đặt khi bị từ chối quyền, chưa rõ trang PĐT có lọc theo khoa/lớp; Đợt 4: chưa có badge phiên mở ở trang chủ SV, chưa kiểm chứng "hết 60 s quay lại bước 1" và "mất mạng không tự gửi lại"; chạy tay trên web và Android: chưa làm.

**Đã gộp "Điểm danh" và "Tự điểm danh" (14/11/2026)** theo `docs/ke-hoach-gop-diem-danh.md`. `flutter test` 311 xanh, `flutter analyze` sạch, `pytest apps/attendance` xanh.
- GV: một màn `/teacher/attendance` (chọn lớp → buổi). Panel buổi có khối tự điểm danh (mở / theo dõi / đóng / mở lại / tính lại tâm), danh sách SV dùng chung (4 lựa chọn, cờ đáng ngờ, xem lượt + ảnh bằng chứng, chip "Có đơn chờ duyệt"). Phiên đang mở: bấm trạng thái lưu ngay từng SV (`PATCH tu-diem-danh/`, nhận thêm `di_tre`), không có nút lưu cả lớp; còn lại lưu cả lớp như cũ. Danh sách buổi có chip "Phiên đang mở" / "Đã tự điểm danh" / "n đáng ngờ" (`GET sessions/` thêm `da_mo_tu_diem_danh`, `dang_mo_tu_diem_danh`, `so_dang_ngo`). Nút "Duyệt khuôn mặt" hiện số mẫu chờ duyệt. Bỏ route và menu `/teacher/self-attendance`.
- SV: màn `/student/attendance` có thẻ phiên đang mở (bấm vào luồng camera + GPS) và nút "Khuôn mặt điểm danh" kèm trạng thái (chưa đăng ký / chờ duyệt / bị từ chối / đã duyệt / cần đăng ký lại); Tổng quan có huy hiệu nhắc khi có phiên chưa điểm danh. Bỏ mục menu "Tự điểm danh" (route `/student/checkin` còn).
- Backend: duyệt yêu cầu sửa đặt `nguoi_quyet` (phiên đang mở không ghi đè kết quả vừa duyệt).
- Chưa làm: chạy tay trên web và Android.

**Còn lại:** Đợt 5 (trang chiếu QR + quét QR bằng `mobile_scanner`, task Celery dọn ảnh bằng chứng / `mau_gps`), Đợt 6 (nginx `client_max_body_size`, build lại `worker`/`beat`, chạy thật trên điện thoại).

---

## Đợt 0. Dọn bản v0 đang có và chốt quyết định

Commit `52a5ac5` đã đưa vào một bản v0 **khác hướng KH**:

| Có sẵn (v0) | KH yêu cầu | Xử lý |
|---|---|---|
| `backend/apps/attendance/khuon_mat.py`: YuNet + **SFace 128 chiều**, ngưỡng 0,363, không chống giả | YuNet + **ArcFace R50 512 chiều** + MiniFASNetV2 | Thay hẳn bằng package `face/` (Đợt 1) rồi xóa file này |
| Model `FaceProfile` (1 ảnh, `dac_trung` JSON **không mã hóa**, ảnh giữ vĩnh viễn) | `FaceTemplate` (embedding mã hóa AES-GCM, ảnh xóa khi duyệt) | Thay bằng `FaceTemplate` |
| `AttendanceSession.mo_diem_danh_den` | `mo_luc`, `het_han_luc`, `dong_luc`, `nguoi_mo` | Đổi tên thành `het_han_luc`, thêm các cột còn lại |
| `Attendance.tu_diem_danh_luc`, `do_giong`, `khoang_cach_m` | `dang_ngo`, `luot_tot_nhat` (FK tới lượt), `nguoi_quyet` | Số liệu nằm ở `CheckinAttempt` → bỏ 3 cột này |
| Cấu hình `vi_do_truong`, `kinh_do_truong`, `ban_kinh_diem_danh_m` (tâm cố định ở trường) | Tâm = GPS giảng viên lúc mở phiên, `r = r₀ + σ_gv + σ_sv` | Bỏ 2 khóa tọa độ; đổi `ban_kinh_diem_danh_m` thành **r₀ mặc định** (10–50, mặc định 20) |
| Cấu hình `so_phut_mo_diem_danh` (15) | Thời hạn mặc định 10 phút | Giữ khóa, đổi mặc định thành 10 |
| `docker-compose.yml` volume `media` | Cần | Giữ |
| `settings.FACE_MODEL_DIR` được tham chiếu nhưng **chưa khai báo**; Dockerfile chưa tải model; `requirements.txt` chưa có opencv | Cần | Làm ở Đợt 1 / Đợt 6 |

- [x] **0.1** Kiểm tra migration `0004_tu_diem_danh` đã chạy trên DB nào chưa (máy dev, VPS, file `.dump` đã chia sẻ):
  ```bash
  docker compose exec web python manage.py showmigrations attendance
  ```
  - Chưa ai chạy ngoài máy mình → **sửa thẳng 0004** (xóa file, `makemigrations` lại ở Đợt 2).
  - Đã chạy ở nơi khác → giữ 0004, viết **0005** để xóa/đổi tên cột.
- [ ] **0.2** Chốt các quyết định còn mở (ghi kết quả ngay dưới dòng này):
  - [ ] Ai duyệt khuôn mặt: PĐT toàn trường + GV lớp mình (KH §8) → **đồng ý / sửa**
  - [ ] Có làm iOS không (KH §15: iOS không có cờ vị trí giả) → mặc định **chỉ Android**
  - [ ] Mã QR bật mặc định hay tắt → mặc định **tắt**, GV bật khi mở phiên
  - [ ] Có ảnh thẻ sinh viên trong `StudentProfile` để đối chiếu khi duyệt không? Không có → người duyệt chỉ xem ảnh đăng ký
  - [x] Phiên bản văn bản đồng ý dữ liệu sinh trắc: `v1` (nội dung đặt ở `backend/apps/attendance/consent_text.py` hoặc cấu hình)
- [x] **0.3** Tạo nhánh làm việc từ `update_diemdanh`; mỗi đợt một hoặc vài commit.

---

## Đợt 1. Lõi thuần (không Django) + test thuần

Mục tiêu: chép các hàm thuần từ NGUỒN, không đụng DB, test chạy bằng `pytest` không cần Postgres.

### 1.1 Phụ thuộc và cấu hình
- [x] Thêm vào `backend/requirements.txt`:
  ```
  onnxruntime>=1.18
  opencv-python-headless>=4.10
  numpy>=1.26
  cryptography>=42
  ```
- [x] `pip install -r requirements.txt` trong venv, `python -c "import cv2, onnxruntime"` chạy được.
- [x] `backend/config/settings/base.py`:
  - [x] `FACE_MODEL_DIR = env("FACE_MODEL_DIR", default=BASE_DIR / "face_models")`
  - [x] `DATA_KEY = env("DATA_KEY", default="")` (32 byte, base64). Prod: thiếu → báo lỗi khi khởi động (không âm thầm chạy không mã hóa).
  - [x] Dict `FACE_CONFIG` hoặc đọc qua `apps.config.services.doc_cau_hinh` cho các ngưỡng ở KH §3.2 (xem 1.6).
- [x] `.env.example`: thêm `DATA_KEY=` kèm lệnh sinh khóa:
  ```bash
  python -c "import os,base64;print(base64.b64encode(os.urandom(32)).decode())"
  ```
- [x] `.gitignore`: `backend/face_models/*.onnx`, `backend/apps/attendance/tests/fixtures/faces/*.jpg`.

### 1.2 Model ONNX
- [ ] Chép từ `D:\DiemDanhKhuonMat_GPS\backend\models\` sang `backend/face_models/`:
  `face_detection_yunet_2023mar.onnx`, `w600k_r50.onnx`, `MiniFASNetV2.onnx` (và `w600k_mbf.onnx` nếu muốn dự phòng).
- [x] Chép `README.md` của thư mục model (nguồn tải, giấy phép, **sha256**) sang `backend/face_models/README.md`.
- [ ] Kiểm tra sha256 khớp README:
  ```powershell
  Get-FileHash backend\face_models\*.onnx -Algorithm SHA256
  ```

### 1.3 Package `backend/apps/attendance/face/`
Chép từ `NGUỒN/backend/app/services/face/`, đổi import cho khớp Django, **không** đổi thuật toán.
- [x] `types.py` – dataclass khung hình, kết quả kiểm tra, lý do dừng.
- [x] `checks.py` – lượt 1: số mặt, độ rộng mặt (`min_face_px`), độ sáng (`min_brightness`), độ nét Laplacian (`min_sharpness`), yaw; kiểm tra hành động "thẳng **rồi** quay đúng hướng" (KH §4).
- [x] `onnx_engine.py` – YuNet, căn chỉnh 112×112 theo 5 điểm, ArcFace (RGB, `(x−127,5)/127,5`, L2), MiniFASNetV2 (crop 2,7×, 80×80, BGR float, softmax, lớp 1 = thật).
- [x] `runtime.py` – nạp model **một lần mỗi process** (thay `@cache` của v0), semaphore giới hạn số lượt suy luận đồng thời = số core (KH §13).
- [x] `verify.py` – đối sánh 1-1: cosine từng khung, điểm = **trung vị**, khung thấp nhất ≥ `suspect_threshold`; anti-spoof lấy điểm **thấp nhất** của 3 khung nét nhất.
- [x] Engine giả (`face_fakes.py` của NGUỒN) để test nghiệp vụ không cần model → đặt ở `backend/apps/attendance/tests/face_fakes.py`.
- [x] Hàm tạo **mẫu đăng ký**: 3–5 ảnh → mỗi ảnh qua chất lượng + anti-spoof → các embedding phải cùng người (cosine đôi một ≥ `accept_threshold`) → trung bình → chuẩn hóa L2.
- [x] Xóa `backend/apps/attendance/khuon_mat.py` và mọi import của nó (`grep -rn khuon_mat backend/apps`).

### 1.4 `backend/apps/attendance/geo.py` (từ `NGUỒN/services/geo.py`)
- [x] `haversine(lat1, lng1, lat2, lng2) -> mét`
- [x] `tinh_tam(mau)` cho GV: lọc sai số ≤ 20 m, cần ≥ 5 mẫu, trả trung vị lat/lng + σ_gv
- [x] `vi_tri_sv(mau)`: lọc sai số ≤ 30 m, cần ≥ 3 mẫu, trả trung vị + σ_sv (σ_sv **trần 30 m**)
- [x] `ban_kinh(r0, σ_gv, σ_sv) = r0 + σ_gv + min(σ_sv, 30)`
- [x] `phan_loai(d, r)`: `DAT` (d ≤ r) / `LECH_NHE` (r < d ≤ 2r) / `KHONG_DAT` (d > 2r)
- [x] `co_buoc_nhay(mau)`: tốc độ giữa hai mẫu liên tiếp > 30 m/s
- [x] `co_vi_tri_gia(mau)`: bất kỳ mẫu nào `is_mocked = true`
- [x] `tam_lech(vi_tri_cac_sv, tam)`: > 70 % SV đã qua khuôn mặt cùng phía → trả `True` + tâm mới = trung vị vị trí SV

### 1.5 `backend/apps/attendance/room_token.py` (từ `NGUỒN/services/room_token.py`)
- [x] `ma_phong(bi_mat, session_id, window)` = HMAC-SHA256 → 8 ký tự base32
- [x] `ma_hien_tai(bi_mat, session_id, now)` với `window = floor(unix / 30)`
- [x] `kiem_tra_ma(...)` chấp nhận window hiện tại **và** window trước, so bằng `hmac.compare_digest`

### 1.6 `backend/apps/attendance/crypto.py` (từ `NGUỒN/app/crypto.py`)
- [x] `ma_hoa(bytes) -> bytes` / `giai_ma(bytes) -> bytes`: AES-256-GCM, nonce 12 byte ngẫu nhiên ghép đầu chuỗi, khóa từ `settings.DATA_KEY`
- [x] Hàm tiện ích `embedding_to_bytes` / `bytes_to_embedding` (`float32`, 512 số)

### 1.7 Ngưỡng cấu hình (KH §3.2)
Thêm vào `CAU_HINH` trong `backend/apps/config/services.py`, nhóm "Điểm danh", dùng `_so_thuc` / `_so_nguyen` có sẵn:
- [x] `accept_threshold` 0.50 (0–1)
- [x] `suspect_threshold` 0.40 (0–1, phải < accept → kiểm tra chéo khi lưu)
- [x] `antispoof_threshold` 0.80 (0–1)
- [x] `yaw_threshold` 0.25 (0–1)
- [x] `min_face_px` 100, `min_brightness` 60, `min_sharpness` 50
- [x] `so_luot_toi_da` 5 (1–20)
- [x] `so_ngay_giu_bang_chung` 30
- [x] Bỏ `vi_do_truong`, `kinh_do_truong`; đổi `ban_kinh_diem_danh_m` → r₀ mặc định 20, khoảng 10–50; `so_phut_mo_diem_danh` mặc định 10
- [ ] Nếu bảng `SystemConfig` đã có dòng cho khóa cũ → data migration xóa

### Kiểm tra Đợt 1
Chép test tương ứng từ NGUỒN vào `backend/apps/attendance/tests/`:
- [x] `test_geo.py`: haversine với cặp điểm đã biết; lọc mẫu; thiếu mẫu báo lỗi; trần σ_sv; 3 vùng d ≤ r / ≤ 2r / > 2r; bước nhảy; tâm lệch 70 %
- [x] `test_room_token.py`: cùng window khớp; window trước khớp; window cách 2 bị từ chối; khóa khác bị từ chối
- [x] `test_crypto.py`: mã hóa → giải mã ra đúng; sửa 1 byte → lỗi; hai lần mã hóa cùng dữ liệu ra khác nhau
- [x] `test_face_checks.py`: ảnh tối / mờ / không mặt / 2 mặt; hành động đúng thứ tự, sai hướng, thiếu khung thẳng
- [x] `test_face_verify.py` (engine giả): trung vị; 1 khung lạ → không đạt; anti-spoof lấy min
- [x] `test_onnx_engine.py` đánh dấu `@pytest.mark.models`, **tự bỏ qua** khi thiếu file model / ảnh mẫu (tạo ảnh mẫu theo lệnh trong `face_models/README.md`)
- [x] Đăng ký marker `models` trong `pyproject.toml`
```bash
cd backend && pytest apps/attendance/tests -k "geo or room_token or crypto or face" -q
```

---

## Đợt 2. Dữ liệu, nghiệp vụ, API

### 2.1 Model (`backend/apps/attendance/models.py`)
**`AttendanceSession` thêm** (KH §9):
- [x] `tam_lat`, `tam_lng` (`FloatField`, null), `tam_sai_so_m` (`FloatField`, null)
- [x] `tam_goc_lat`, `tam_goc_lng` (giữ tâm ban đầu khi tính lại tâm)
- [x] `ban_kinh_m` (`PositiveSmallIntegerField`, = r₀)
- [x] `kiem_tra_phong` (`BooleanField`, default False), `ma_phong_bi_mat` (`BinaryField`/`CharField`, sinh bằng `secrets.token_bytes(32)` lúc mở)
- [x] `mo_luc`, `het_han_luc` (đổi tên từ `mo_diem_danh_den`), `dong_luc` (`DateTimeField`, null)
- [x] `nguoi_mo` (FK User, null, `SET_NULL`)
- [x] Property `dang_mo_tu_diem_danh`: `mo_luc` có, `dong_luc` null, `now < het_han_luc`

**`Attendance` thêm / bỏ:**
- [x] `dang_ngo` (`BooleanField`, default False)
- [x] `luot_tot_nhat` (FK `CheckinAttempt`, null, `SET_NULL`)
- [x] `nguoi_quyet` (FK User, null) — khác null nghĩa là GV đã quyết tay → hệ thống **không ghi đè**
- [x] Bỏ `tu_diem_danh_luc`, `do_giong`, `khoang_cach_m`

**Bảng mới:**
- [x] `FaceTemplate` (thay `FaceProfile`):
  `sinh_vien` (FK), `ten_mo_hinh` (vd `w600k_r50`), `embedding` (`BinaryField`, mã hóa), `anh_dang_ky` (JSON danh sách đường dẫn file đã mã hóa, xóa sau duyệt), `trang_thai` (CHO_DUYET / DUYET / TU_CHOI / THU_HOI), `nguoi_duyet`, `ngay_duyet`, `ly_do`, `tao_luc`.
  Ràng buộc: `UniqueConstraint(sinh_vien, condition=trang_thai='DUYET')` và tương tự cho `CHO_DUYET`.
- [x] `Consent`: `sinh_vien`, `phien_ban`, `dong_y_luc`, `rut_lai_luc` (null)
- [x] `Challenge`: `session` (FK), `sinh_vien`, `nonce` (unique, `secrets.token_urlsafe(16)`), `hanh_dong` (`TRAI`/`PHAI`), `het_han_luc` (+60 s), `da_dung` (bool), `tao_luc`
- [x] `CheckinAttempt`: `session`, `sinh_vien`, `challenge` (FK, null), `mau_gps` (JSON thô), `d_m`, `r_m`, `diem_mat`, `diem_that` (liveness), `ket_qua` (CO_MAT / DANG_NGO / KHONG_DAT), `buoc_dung` (0–6, null nếu qua hết), `ly_do` (mã lý do), `co` (JSON list: `VI_TRI_GIA`, `BUOC_NHAY`, `CUNG_MAY`, `LECH_NHE`, `SAT_NGUONG`), `device_id`, `nen_tang` (`android` / `web`), `ip` (chỉ để tra cứu, không dùng chấm điểm), `anh_bang_chung` (đường dẫn file mã hóa, null), `tao_luc`.
  Index: `(session, sinh_vien)`, `(session, device_id)`.
- [x] Xóa model `FaceProfile` + file ảnh `media/khuon_mat/` cũ (data migration hoặc ghi chú dọn tay)
- [ ] `makemigrations attendance` → đọc lại migration sinh ra, đảm bảo đổi tên `mo_diem_danh_den → het_han_luc` là `RenameField` chứ không phải xóa + thêm
- [ ] Đăng ký admin (nếu dự án dùng Django admin cho attendance)

### 2.2 Nghiệp vụ (`backend/apps/attendance/tu_diem_danh.py` hoặc thêm vào `services.py`)
Chép luồng từ `NGUỒN/services/checkin.py` và `NGUỒN/services/sessions.py`.

**Đồng ý + đăng ký mặt**
- [x] `dong_y(sv, phien_ban)`; `rut_lai(sv)` → rút lại = thu hồi mẫu + xóa dữ liệu mặt
- [x] `dang_ky_mat(sv, anh_list)`: cần consent còn hiệu lực; 3–5 ảnh; mỗi ảnh ≤ 1280 px cạnh dài, ≤ 2 MB; tạo mẫu → `CHO_DUYET`; mẫu chờ cũ (nếu có) bị thay
- [x] `duyet_mat(nguoi, template, dong_y, ly_do)`: quyền PĐT hoặc GV có dạy SV đó; duyệt → mẫu DUYET cũ chuyển THU_HOI; **xóa file ảnh** dù duyệt hay từ chối; ghi `write_audit`
- [x] `xoa_mat(sv)`: thu hồi + xóa embedding

**Mở / đóng phiên**
- [x] `mo_phien(gv, session, mau_gps, thoi_han, r0, kiem_tra_phong)`:
  - GV phải dạy `ClassSection` của buổi; buổi phải là **hôm nay**; phiên đang mở thì không mở chồng
  - `tinh_tam` → lưu tâm + tâm gốc
  - Sinh sẵn `Attendance` = `VANG_KHONG_PHEP` cho mọi SV `Registration` đã đăng ký mà **chưa có** bản ghi (không đè đơn có phép đã duyệt)
  - Ghi `write_audit`
- [x] `dong_phien(gv, session)` → set `dong_luc`; phiên tự hết hạn khi `now ≥ het_han_luc` (kiểm tra lúc đọc, không cần job)
- [x] `mo_lai_phien(gv, session, thoi_han)`: cho **mở lại** phiên đã đóng hoặc đã hết hạn (GV bấm nhầm đóng, hoặc còn SV chưa kịp điểm danh):
  - chỉ trong **ngày của buổi**; GV phải dạy lớp
  - **giữ nguyên** tâm, bán kính, `ma_phong_bi_mat`: không cần lấy lại GPS
  - `dong_luc = null`, `het_han_luc = now + thoi_han`
  - giữ mọi kết quả và lượt đã có; số lượt đã dùng của SV **vẫn tính** (không reset về 5)
  - ghi `write_audit` (hành động "mở lại phiên")
- [x] `tinh_lai_tam(gv, session)`: chỉ khi `tam_lech` đúng; tâm mới = trung vị vị trí SV đã qua khuôn mặt; **chấm lại** các lượt cũ, chỉ **nâng hạng** kết quả

**Thử thách (bước 0)**
- [x] `xin_thu_thach(sv, session)`: từ chối khi phiên đóng / SV không có mẫu DUYET / đã đếm ≥ `so_luot_toi_da` thử thách / đã `CO_MAT`. Mỗi lần xin = 1 lượt. Trả `nonce`, `hanh_dong`, `het_han_luc`, `luot_con_lai`.
- [x] Mẫu DUYET có `ten_mo_hinh` khác mô hình đang chạy → từ chối ngay ở bước 0 với mã `MO_HINH_DOI`, **không tính lượt**
- [x] Dùng `select_for_update` hoặc đếm trong transaction để 2 request song song không vượt 5 lượt.

**Điểm danh (bước 1–6, dừng ở bước đầu tiên không đạt, luôn ghi `CheckinAttempt`)**
- [x] B1 phiên còn mở + SV thuộc lớp
- [x] B2 nonce đúng SV + phiên, `da_dung = False`, chưa hết hạn → đánh dấu `da_dung` **ngay** (trong transaction, `select_for_update`)
- [x] B3 nếu `kiem_tra_phong`: `kiem_tra_ma` (không kiểm tra IP: cả lớp chung wifi trường là chung IP)
- [x] B4 GPS: `vi_tri_sv` → d, r, phân loại; `KHONG_DAT` dừng; cờ `VI_TRI_GIA`, `BUOC_NHAY` (cả giữa các mẫu và so với lượt trước của SV)
- [x] B5 khuôn mặt: chất lượng (≥ 3 khung đạt) + hành động đúng `challenge.hanh_dong` + anti-spoof
- [x] B6 đối sánh với mẫu DUYET (đã chặn mẫu khác `ten_mo_hinh` từ bước 0, ở đây chỉ kiểm tra lại cho chắc)
- [x] Bảng quyết định KH §7.3 → `CO_MAT` / `DANG_NGO`
- [x] Hạ `CO_MAT` → `DANG_NGO` khi có cờ `VI_TRI_GIA`, `BUOC_NHAY`, `CUNG_MAY` (cùng `device_id` đã điểm danh SV khác trong phiên)
- [x] Lượt `DANG_NGO` → lưu **1 khung** bằng chứng, mã hóa
- [x] Ghi `Attendance`: chỉ nâng hạng (vắng < đáng ngờ < có mặt); bỏ qua nếu `nguoi_quyet` khác null. Có mặt → `CO_MAT`, `dang_ngo=False`; đáng ngờ → giữ `VANG_KHONG_PHEP` + `dang_ngo=True`; cập nhật `luot_tot_nhat`
- [x] Phản hồi SV: `ket_qua`, mã lý do + thông điệp tiếng Việt, `luot_con_lai`. **Không trả** `diem_mat`, `diem_that`, `d`, `r`
- [ ] Toàn bộ suy luận chạy **ngoài** transaction DB (0,7 s), chỉ phần ghi nằm trong transaction

**GV theo dõi / quyết tay**
- [x] `danh_sach_thoi_gian_thuc(session)`: mỗi SV: trạng thái, `dang_ngo`, cờ, số lượt, giờ lượt cuối, **chưa có mẫu mặt được duyệt** (để GV biết ai phải điểm danh tay); đếm có mặt / đáng ngờ / chưa điểm danh; cờ `tam_lech`
- [x] `quyet_tay(gv, attendance, trang_thai)`: set `nguoi_quyet`, ghi audit. Dùng được **cả khi phiên đang mở**: SV chưa đăng ký mặt, quên mang điện thoại, máy hỏng camera/GPS, hết lượt → báo GV, GV bấm có mặt. Không cần mẫu mặt hay lượt điểm danh nào.
- [x] `dat_hang_loat(gv, session, ds_sv, trang_thai)`: ghi audit
- [x] Sau khi đóng phiên, luồng chỉnh tay hiện có (`records` PUT) vẫn chạy → nhớ set `nguoi_quyet` ở đó luôn

**Mã lý do cho SV** (map sang tiếng Việt ở app, chép `NGUỒN/mobile/.../face_reasons.dart`):
- [x] `PHIEN_DONG`, `KHONG_THUOC_LOP`, `CHUA_CO_MAT`, `HET_LUOT`, `DA_CO_MAT`, `NONCE_SAI`, `MA_PHONG_SAI`, `GPS_KEM`, `QUA_XA`, `THIEU_SANG`, `ANH_MO`, `KHONG_THAY_MAT`, `NHIEU_MAT`, `SAI_HANH_DONG`, `ANH_GIA`, `KHONG_KHOP`, `MO_HINH_DOI`

### 2.3 API (`views.py`, `serializers.py`, `urls.py`)
Theo đúng bảng KH §10. Dùng lại `HasRole`, `IsSinhVien`, `IsGiaoVien`, `IsGiaoVienOrPdt`, `WriteThrottle`, `client_ip`, `write_audit`, `business_error` trong `core/`.
- [x] `POST /api/attendance/consent/` (SV)
- [x] `GET` / `DELETE /api/attendance/face/me/` (SV): `GET` trả thêm `can_dang_ky_lai = true` khi mẫu DUYET khác `ten_mo_hinh` đang chạy
- [x] `POST /api/attendance/faces/enroll/` (SV, multipart 3–5 file)
- [x] `GET /api/attendance/open-sessions/` (SV): phiên đang mở của các lớp SV đã đăng ký, kèm `kiem_tra_phong`, `het_han_luc`, trạng thái hiện tại của SV
- [x] `POST /api/attendance/sessions/{id}/challenge/` (SV)
- [x] `POST /api/attendance/sessions/{id}/checkin/` (SV, multipart: `nonce`, `frames[]` 5–8 JPEG, `gps` JSON, `ma_phong`, `device_id`, `nen_tang`)
- [x] `POST /api/attendance/sessions/{id}/mo-phien/` (GV)
- [x] `POST /api/attendance/sessions/{id}/dong-phien/` (GV)
- [x] `POST /api/attendance/sessions/{id}/mo-lai/` (GV, body: `thoi_han`)
- [x] `POST /api/attendance/sessions/{id}/tinh-lai-tam/` (GV)
- [x] `GET /api/attendance/sessions/{id}/room-token/` (GV): `{ma, het_han_sau_giay}`
- [x] `GET` / `PATCH /api/attendance/sessions/{id}/tu-diem-danh/` (GV)
- [x] `POST /api/attendance/attempts/{id}/quyet/` (GV, duyệt có mặt / từ chối lượt đáng ngờ)
- [x] `GET /api/attendance/attempts/{id}/evidence/` (GV, giải mã, trả `image/jpeg`, ghi audit)
- [x] `GET /api/attendance/faces/pending/` (PĐT: tất cả; GV: SV lớp mình)
- [x] `GET /api/attendance/faces/{id}/photos/?i=0` (PĐT/GV, giải mã, ghi audit)
- [x] `POST /api/attendance/faces/{id}/review/` (PĐT/GV)
- [x] Throttle riêng cho `challenge` và `checkin` (vd 10/phút/người)
- [ ] Giới hạn kích thước request upload (`DATA_UPLOAD_MAX_MEMORY_SIZE`, nginx `client_max_body_size` ≥ 12 MB)
- [x] Xác nhận schema OpenAPI (`drf-spectacular`) sinh đúng, không warning mới

### Kiểm tra Đợt 2
`backend/apps/attendance/tests/test_tu_diem_danh.py`, dùng engine giả + `UserFactory`:
- [x] Mở lại: phiên đã đóng → mở được, giữ tâm và kết quả cũ, SV đã có mặt vẫn có mặt; số lượt không reset; buổi của ngày khác → lỗi; phiên đang mở → lỗi
- [x] Mở phiên: GV không dạy lớp → 403; buổi không phải hôm nay → lỗi; < 5 mẫu GPS tốt → lỗi; tạo đủ bản ghi vắng; không đè `VANG_CO_PHEP`
- [x] Thử thách: chưa có mẫu DUYET; hết 5 lượt (lượt thứ 6 bị từ chối); đã có mặt; phiên đóng
- [x] Dừng **từng bước 1–6** đúng `buoc_dung` + mã lý do
- [x] Nonce dùng lại → B2; nonce hết hạn → B2; nonce của SV khác → B2
- [x] Bảng quyết định: 4 ô (đạt/sát ngưỡng × d≤r / r<d≤2r)
- [x] Hạ hạng vì `VI_TRI_GIA`, `BUOC_NHAY`, `CUNG_MAY`; nhiều SV cùng IP gửi liền nhau vẫn **có mặt** bình thường
- [x] Chỉ nâng hạng: có mặt rồi gửi lượt đáng ngờ → vẫn có mặt
- [x] GV đã quyết tay → lượt mới không ghi đè
- [x] Mẫu DUYET của mô hình cũ → thử thách trả `MO_HINH_DOI`, không tính lượt; `face/me` trả `can_dang_ky_lai`
- [x] GV quyết tay khi phiên đang mở cho SV không có mẫu mặt → có mặt, `nguoi_quyet` = GV
- [x] Phản hồi SV không chứa điểm số thô
- [x] Tính lại tâm: chỉ nâng hạng
- [x] Duyệt mặt: xóa file ảnh; GV lớp khác → 403; PĐT duyệt được
- [ ] Phân quyền: SV gọi API GV → 403; GV xem bằng chứng lớp khác → 403
- [ ] Audit có dòng cho: xem ảnh, duyệt mặt, quyết tay, xem bằng chứng
- [ ] Toàn bộ test cũ của dự án vẫn xanh
```bash
cd backend && pytest -q
```

---

## Đợt 3. App Flutter: đồng ý, đăng ký, duyệt khuôn mặt

Thư mục app: `dang_ky_mon_hoc/`. Màn hình chép từ `NGUỒN/mobile/lib/features/`, **đổi sang giao diện của dự án** (design.md: Material 3, indigo/teal), dùng api client + router sẵn có, không mang `neo.dart` của NGUỒN sang.

### 3.1 Phụ thuộc
- [ ] `pubspec.yaml`: `camera`, `geolocator`, `mobile_scanner`, `uuid` (`qr_flutter` đã có)
- [x] `android/app/src/main/AndroidManifest.xml`: `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`
- [x] `minSdkVersion` đủ cho `camera` / `mobile_scanner` (thường ≥ 21)
- [x] `flutter pub get` sạch

### 3.2 Lõi dùng chung (`lib/core/...` theo cấu trúc dự án)
- [x] `device_id.dart`: sinh UUID một lần, lưu `shared_preferences`/secure storage
- [x] `capture.dart`: mở camera trước, chụp chuỗi 5–8 khung khi SV làm hành động, nén JPEG, cạnh dài ≤ 1280
- [x] `gps_sampler.dart`: lấy mẫu độ chính xác cao trong N giây, mỗi mẫu `{lat, lng, accuracy, ts, is_mocked}`
- [x] `face_reasons.dart`: map mã lý do → câu tiếng Việt + gợi ý sửa
- [x] Chạy được trên **web** (Chrome, Safari iPhone): `camera`, `geolocator`, `mobile_scanner` đều có bản web nhưng chỉ chạy trên HTTPS hoặc `localhost`; trên web `is_mocked` luôn `false`, `device_id` lưu trong bộ nhớ trình duyệt (xóa dữ liệu trang là mất); gửi kèm `nen_tang` = `web` / `android` (`kIsWeb`)
- [x] Service gọi API mới trong `lib/features/attendance/` (cùng kiểu với `student_attendance_screen.dart` đang có)

### 3.3 Màn hình SV
- [ ] **Quyền truy cập** (camera, vị trí): giải thích trước khi hệ thống hỏi; bị từ chối vĩnh viễn → nút mở cài đặt
- [x] **Đồng ý dữ liệu sinh trắc**: hiện văn bản, nút đồng ý; lưu phiên bản
- [x] **Đăng ký khuôn mặt**: khung oval, 3 tư thế (thẳng / hơi trái / hơi phải), xem lại trước khi gửi, hiện lỗi từng ảnh
- [x] **Khuôn mặt của tôi**: trạng thái (chưa có / chờ duyệt / đã duyệt / bị từ chối + lý do / **cần đăng ký lại** do đổi mô hình), nút đăng ký lại, nút xóa (xác nhận 2 bước)
- [x] Thêm lối vào từ màn điểm danh SV / hồ sơ; thêm route trong `routes_student.dart`

### 3.4 Màn hình duyệt
- [x] **GV (app)**: danh sách chờ duyệt của SV lớp mình, xem ảnh, duyệt / từ chối kèm lý do
- [ ] **PĐT (web)**: trang duyệt toàn trường trong khu admin, lọc theo khoa/lớp

### Kiểm tra Đợt 3
- [x] `flutter analyze` không lỗi mới
- [x] `flutter test`: widget test màn đồng ý, khuôn mặt của tôi (4 trạng thái), map lý do
- [ ] Chạy tay bằng **bản web** (Chrome laptop hoặc Safari iPhone, xem mục "Test bằng bản web"): đồng ý → đăng ký → PĐT duyệt → hiện "đã duyệt"

---

## Đợt 4. App: mở phiên, điểm danh, theo dõi, duyệt đáng ngờ

### 4.1 GV
- [x] **Mở phiên** (từ `teacher_attendance_screen.dart`): chỉ buổi hôm nay; chọn thời hạn (mặc định 10), r₀ (10–50), bật/tắt QR; thanh trạng thái GPS (số mẫu tốt / 5, sai số hiện tại); nút mở chỉ bật khi đủ mẫu
- [x] **Phiên đang chạy**: đếm ngược, bộ đếm có mặt / đáng ngờ / chưa, lọc, tự làm mới **4 giây** (dừng khi rời màn hoặc phiên đóng), banner "tâm có thể lệch" + nút tính lại tâm, đặt hàng loạt, đóng phiên (xác nhận); phiên đã đóng trong ngày → nút **Mở lại** (chọn thời hạn)
- [x] **Chi tiết SV trong phiên**: các lượt, cờ, điểm mặt, d, r, ảnh bằng chứng; nút duyệt có mặt / từ chối
- [ ] Hiện mã QR toàn màn hình (web, Đợt 5)

### 4.2 SV
- [x] Danh sách phiên đang mở (`open-sessions`), có badge trên trang chủ SV (nay là thẻ trong màn Điểm danh + huy hiệu nhắc ở Tổng quan)
- [x] SV chưa có mẫu mặt được duyệt (`CHUA_CO_MAT`) hoặc hết lượt (`HET_LUOT`): hiện "Hãy báo giảng viên để điểm danh thủ công", kèm nút đăng ký khuôn mặt cho lần sau
- [x] **Luồng điểm danh** (chép `checkin_controller.dart` + `checkin_page.dart`):
  1. Xin thử thách → hiện hành động + đếm ngược 60 s + số lượt còn
  2. Mã phòng (nếu phiên bật): quét QR bằng camera sau, **hoặc gõ tay 8 ký tự** (laptop không quét được máy chiếu)
  3. Lấy GPS 5–10 s, hiện độ chính xác; cảnh báo nếu kém
  4. Camera: "Nhìn thẳng" → "Quay đầu sang trái/phải", chụp khung
  5. Gửi → màn kết quả: có mặt / đáng ngờ (GV sẽ xem) / không đạt + lý do + nút thử lại (nếu còn lượt)
- [ ] Hết 60 s trước khi gửi → quay lại bước 1 (tốn 1 lượt, báo rõ cho SV)
- [ ] Mất mạng lúc gửi → báo lỗi, **không** tự gửi lại (nonce đã dùng)

### Kiểm tra Đợt 4
- [x] `flutter test`: controller điểm danh (giả API) đi đúng thứ tự bước, xử lý hết hạn, hết lượt
- [ ] Chạy tay bằng bản web: GV mở phiên trên laptop (giả vị trí bằng DevTools), SV điểm danh trên iPhone hoặc tab Chrome thứ 2, danh sách GV cập nhật trong ≤ 4 s

---

## Đợt 5. Mã QR, tính lại tâm, dọn dữ liệu

- [ ] **Web GV chiếu QR**: trang toàn màn hình, gọi `room-token` mỗi lần mã hết hạn, `qr_flutter` vẽ mã, **hiện mã 8 ký tự chữ to** dưới QR để gõ tay, đếm ngược + tên lớp
- [ ] SV quét QR bằng `mobile_scanner` (app và web điện thoại) hoặc gõ tay mã (ô nhập tự viết hoa, bỏ khoảng trắng)
- [ ] Hoàn thiện tính lại tâm phía app (banner + xác nhận)
- [ ] **Celery beat** (`backend/config/celery.py` → `beat_schedule`, task trong `backend/jobs/tasks.py`):
  - [ ] Xóa `anh_bang_chung` của `CheckinAttempt` cũ hơn `so_ngay_giu_bang_chung` (file + set null)
  - [ ] Xóa ảnh đăng ký mồ côi (template TU_CHOI / THU_HOI còn file)
  - [ ] Hết học kỳ: xóa `mau_gps` của lượt thuộc học kỳ đã kết thúc (KH §12) — chạy hằng ngày, kiểm tra theo ngày kết thúc học kỳ
- [ ] SV thôi học / tài khoản bị xóa → xóa template (signal hoặc trong luồng khóa tài khoản hiện có)

### Kiểm tra Đợt 5
- [ ] `pytest`: task dọn xóa đúng bản ghi quá hạn, giữ bản ghi còn hạn; QR window ±1
- [ ] `flutter test`: trang QR đổi mã khi hết hạn (giả đồng hồ)

---

## Test bằng bản web (khi chưa có máy Android)

Dùng từ Đợt 3 trở đi. Server làm hết phần khuôn mặt / GPS, nên web test được gần như toàn bộ luồng.

### Trên laptop (Chrome)
- [ ] Chạy backend như thường (`docker compose up`)
- [ ] Chạy app bản web trỏ vào API:
  ```bash
  cd dang_ky_mon_hoc && flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8010/api
  ```
  (`localhost` được coi là an toàn nên camera và vị trí chạy được không cần HTTPS)
- [ ] Giả vị trí: DevTools (F12) → `⋮` → More tools → **Sensors** → Location → nhập tọa độ. GV và SV mở **2 cửa sổ Chrome** (một cửa sổ ẩn danh) để đăng nhập 2 tài khoản, đặt 2 tọa độ khác nhau để thử d ≤ r, r < d ≤ 2r, d > 2r
- [ ] Camera: dùng webcam; thử giơ ảnh trên điện thoại / ảnh in trước webcam để thử chống giả
- [ ] Mã phòng: mở trang chiếu QR ở cửa sổ GV, gõ tay mã 8 ký tự ở cửa sổ SV

### Trên iPhone (Safari) — để có camera và GPS thật
Safari chỉ mở camera / vị trí khi trang chạy **HTTPS**, nên phải mở đường hầm từ laptop:
- [ ] Build bản web và cho backend phục vụ cùng một địa chỉ (đỡ phải mở 2 đường hầm và sửa CORS), hoặc mở 2 đường hầm (1 cho web, 1 cho API) rồi build web với `API_BASE_URL` là địa chỉ đường hầm API
- [ ] Mở đường hầm bằng `cloudflared` (miễn phí, không cần tài khoản):
  ```bash
  cloudflared tunnel --url http://localhost:8010
  ```
- [ ] Thêm tên miền đường hầm (`*.trycloudflare.com`) vào `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS` trong `.env` dev
- [ ] Mở link trên Safari iPhone → cho phép camera và vị trí
- [ ] Đo thật: sai số GPS **trong phòng học**, ánh sáng phòng thật, đứng ngoài lớp xa dần để xem khi nào bị "quá xa"
- [ ] Kịch bản 2 thiết bị: laptop làm GV (mở phiên, chiếu QR), iPhone làm SV (quét QR thật bằng camera sau)
- [ ] **Tắt đường hầm khi test xong** (nó mở server máy bạn ra internet)

### Web không test được
- Cờ vị trí giả `is_mocked` (web không có) → test bằng `pytest` gửi `is_mocked = true`; trên máy thật để Đợt 6 (mượn máy Android ~15 phút)
- Hộp thoại xin quyền và giao diện riêng của Android → Android Emulator (camera trước = `Webcam0`, vị trí đặt trong Extended controls → Location)

---

## Đợt 6. Docker + chạy thật

### 6.1 Build
- [ ] `backend/Dockerfile`: model **không** nằm trong git → chọn một:
  - (a) `COPY face_models/ /app/face_models/` (build trên máy đã có model), hoặc
  - (b) bước `RUN curl ... && sha256sum -c` tải từ nguồn trong README.
  Ghi rõ lựa chọn vào `backend/face_models/README.md`.
- [ ] `ENV FACE_MODEL_DIR=/app/face_models`
- [ ] `opencv-python-headless` trên `python:3.12-slim` cần `libgl1`? (headless thường không cần; nếu lỗi import thì thêm `libglib2.0-0`)
- [ ] `.env` VPS có `DATA_KEY`; **sao lưu khóa riêng** — mất khóa = mất toàn bộ embedding (SV phải đăng ký lại)
- [ ] Gunicorn: số worker × ~0,5 GB RAM; VPS ≥ 4 GB; cân nhắc `--preload` để chia sẻ model giữa worker
- [ ] nginx: `client_max_body_size 12m;`
- [ ] HTTPS bật trước khi cho SV dùng (camera/GPS trên web cũng đòi HTTPS)
- [ ] Image build được, `docker compose up`, `/health` xanh, `python -c "from apps.attendance.face.runtime import ..."` nạp model OK trong container

### 6.2 Kịch bản chạy thật trên Android (KH §14)
| # | Kịch bản | Kỳ vọng | Kết quả |
|---|---|---|---|
| 1 | SV thật, trong lớp, ánh sáng tốt | Có mặt | [ ] |
| 2 | Giơ ảnh SV trên màn hình điện thoại khác | Chặn (ảnh giả) | [ ] |
| 3 | Ảnh in | Chặn (ảnh giả) | [ ] |
| 4 | Video quay sẵn | Chặn (sai hành động / ảnh giả) | [ ] |
| 5 | SV ở cách lớp > 2r | Không đạt (quá xa) | [ ] |
| 6 | SV ở r < d ≤ 2r | Đáng ngờ | [ ] |
| 7 | 2 SV dùng 1 máy | Người thứ 2 đáng ngờ (cùng máy) | [ ] |
| 8 | App giả vị trí (mock location bật) | Đáng ngờ (vị trí giả) | [ ] |
| 9 | Gửi lại request cũ (replay bằng Postman) | Chặn (nonce) | [ ] |
| 10 | Phòng tối / camera mờ | Thông báo thiếu sáng / mờ | [ ] |
| 11 | Người khác dùng tài khoản SV | Không khớp | [ ] |
| 12 | Bật QR, quét mã cũ > 60 s | Mã sai | [ ] |
| 13 | 60 SV trong 3 phút (dùng `locustfile.py` + engine thật) | Không timeout, p95 < 5 s | [ ] |

- [ ] Ghi lại cosine / liveness đo được vào một bảng, chỉnh ngưỡng nếu cần (cấu hình, không build lại)

---

## Phần không thuộc code nhưng phải làm
- [ ] Xin phép nhà trường theo **Nghị định 13/2023/NĐ-CP** (KH §12); lưu văn bản đồng ý `v1`
- [ ] Ghi rõ giới hạn KH §15 vào báo cáo đồ án (root giả GPS, iOS, GPS trong nhà, chuyển tiếp QR, ngưỡng tạm, giấy phép phi thương mại ArcFace)
- [ ] Cập nhật tài liệu hướng dẫn sử dụng cho GV / SV / PĐT
- [ ] Đổi trạng thái KH thành "đang triển khai" / "đã triển khai"

## Điểm KH còn thiếu / cần chốt (phát hiện khi viết checklist)
1. **Đã thêm** vào KH §10: API GV duyệt / từ chối lượt đáng ngờ `POST /attempts/{id}/quyet/` (xem 2.3).
2. **Đã chốt:** phiên đã đóng hoặc hết hạn **được mở lại** trong ngày của buổi, giữ tâm và kết quả cũ (xem 2.2 `mo_lai_phien`).
3. **Đã chốt:** SV chưa đăng ký khuôn mặt, quên mang điện thoại, máy hỏng hoặc hết lượt → báo GV, **GV điểm danh thủ công** ngay trong phiên (`quyet_tay`). Ghi vào hướng dẫn sử dụng.
4. **Đã bỏ** cờ "nhiều lượt cùng IP" (KH §6, §7.3): cả lớp dùng wifi trường nên chung một IP công cộng, trong khi người nhận mã chuyển tiếp ở ngoài thường dùng 4G (IP khác), nên cờ này báo nhầm người ở trong phòng mà không bắt được người ở ngoài. Chuyển tiếp mã vẫn bị GPS + khuôn mặt chặn (KH §15).
5. **Đã chốt:** đổi mô hình (vd R50 → MBF) làm mọi mẫu cũ vô hiệu → bước 0 trả `MO_HINH_DOI` (không tính lượt), app hiện "cần đăng ký lại"; trong lúc chờ đăng ký và duyệt lại, GV điểm danh thủ công.
6. **Chưa chốt: chính sách điểm danh trên web.** Web không phát hiện được vị trí giả (Chrome DevTools đổi tọa độ vài giây), `device_id` xóa được. Các hướng: (a) web bắt buộc mã phòng; (b) web không có mã → tối đa đáng ngờ; (c) web như app, ghi vào giới hạn; (d) chặn điểm danh trên web. Hiện tại: **dùng bản web để test trước**, server đã lưu `nen_tang` nên chốt sau chỉ phải sửa một chỗ trong bảng quyết định.
