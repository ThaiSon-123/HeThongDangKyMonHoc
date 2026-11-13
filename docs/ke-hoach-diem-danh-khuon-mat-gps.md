# Kế hoạch chi tiết: Điểm danh bằng nhận diện khuôn mặt và GPS

> Áp dụng đặc tả `D:\DiemDanhKhuonMat_GPS\docs\dac-ta-thiet-ke.md` (bản 3) vào **Hệ thống đăng ký môn học**.
> Trạng thái: **kế hoạch, chưa triển khai.**

## 1. Mục tiêu

Sinh viên **tự điểm danh bằng điện thoại** trong thời gian giảng viên mở phiên. Hệ thống kiểm tra đồng thời:

| Câu hỏi | Lớp xác thực | Cách làm |
|---|---|---|
| Đúng người? | Khuôn mặt | So khớp 1-1 với mẫu khuôn mặt đã được duyệt của chính tài khoản |
| Người thật? | Chống giả mạo | Mô hình anti-spoofing + thử thách quay đầu ngẫu nhiên |
| Đúng nơi? | GPS | Khoảng cách tới vị trí giảng viên lúc mở phiên, bán kính thích ứng theo sai số |
| Đúng phòng? (tùy chọn) | Mã QR | Mã đổi mỗi 30 giây chiếu trên máy chiếu, sinh viên quét |

Mục tiêu là chặn các cách gian lận phổ biến:
- điểm danh hộ;
- giơ ảnh hoặc video của người khác;
- điểm danh từ xa;
- giả vị trí;
- phát lại gói tin cũ.

## 2. Công nghệ sử dụng

### 2.1 Tổng quan

| Tầng | Công nghệ | Ghi chú |
|---|---|---|
| Backend | **Django 5.1 + Django REST Framework** (có sẵn) | Thêm module điểm danh khuôn mặt vào app `attendance` |
| Cơ sở dữ liệu | **PostgreSQL 16** (có sẵn) | Thêm 4 bảng, mở rộng 2 bảng |
| Suy luận AI | **ONNX Runtime** (CPU) | Chạy mô hình nhận diện, không cần GPU |
| Xử lý ảnh | **OpenCV** (`opencv-python-headless`) | Giải mã ảnh, phát hiện mặt (YuNet), căn chỉnh, đo độ sáng/nét |
| Tính toán | **NumPy** | Vector embedding, cosine similarity |
| Mã hóa | **cryptography** (AES-256-GCM) | Mã hóa embedding và ảnh khuôn mặt trước khi lưu |
| Tác vụ nền | **Celery + Redis** (có sẵn) | Dọn ảnh bằng chứng quá hạn hằng ngày |
| Triển khai | **Docker Compose** (có sẵn) | Model ONNX đóng gói vào image backend |
| App di động | **Flutter** (có sẵn), Android | Sinh viên điểm danh, giảng viên mở phiên |
| Web | **Flutter Web** (có sẵn) | Giảng viên chiếu QR; PĐT duyệt khuôn mặt |

### 2.2 Thư viện Flutter thêm mới

| Gói | Dùng để |
|---|---|
| `camera` | Mở camera trước, chụp **chuỗi 5–8 khung hình** khi sinh viên làm hành động |
| `geolocator` | Lấy nhiều mẫu GPS độ chính xác cao, đọc cờ **vị trí giả (`isMocked`)** trên Android |
| `mobile_scanner` | Quét mã QR phòng học |
| `qr_flutter` | Hiển thị mã QR trên web của giảng viên |
| `uuid` | Sinh `device_id` cố định cho mỗi máy (phát hiện một máy điểm danh cho nhiều người) |

Quyền Android: `CAMERA`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.

### 2.3 Thư viện Python thêm mới
`onnxruntime`, `opencv-python-headless`, `numpy`, `cryptography`.

## 3. Mô hình AI

Cả 3 mô hình đều chạy trên **CPU** ở dạng **ONNX**, lấy từ project `D:\DiemDanhKhuonMat_GPS\backend\models\`, nơi đã đo thử.

| # | Mô hình | Vai trò | Đầu vào → đầu ra | Dung lượng | Nguồn / giấy phép |
|---|---|---|---|---|---|
| 1 | **YuNet** (`face_detection_yunet_2023mar.onnx`) | Phát hiện khuôn mặt + 5 điểm mốc (2 mắt, mũi, 2 mép miệng) | Ảnh → khung mặt + 5 điểm + độ tin cậy | 0,23 MB | OpenCV Zoo, MIT |
| 2 | **ArcFace ResNet-50** (`w600k_r50.onnx`) | Trích **embedding 512 chiều** đặc trưng khuôn mặt | Mặt căn chỉnh 112×112 RGB → vector 512 số (chuẩn hóa L2) | 175 MB | InsightFace `buffalo_l` v0.7, **chỉ dùng phi thương mại** (đồ án được phép) |
| 3 | **MiniFASNetV2** (`MiniFASNetV2.onnx`) | **Chống giả mạo**: phân biệt người thật / ảnh in / màn hình | Vùng cắt 2,7× khung mặt, 80×80 BGR → xác suất "người thật" | 1,7 MB | Silent-Face-Anti-Spoofing (Minivision), Apache-2.0 |

**Bản nhẹ để dự phòng:** MobileFaceNet `w600k_mbf.onnx` (13 MB). Nếu đổi sang bản này phải đo lại ngưỡng, và sinh viên phải đăng ký lại khuôn mặt. Mỗi mẫu lưu tên mô hình; mẫu của mô hình cũ bị từ chối ở bước thử thách với lý do "cần đăng ký lại khuôn mặt" (không tính lượt), và app hiện trạng thái này ở màn Khuôn mặt của tôi.

### 3.1 Số liệu đo thử
Lấy từ `D:\DiemDanhKhuonMat_GPS\experiments\spike.md`.

| Chỉ số | Kết quả |
|---|---|
| Thời gian mỗi khung (CPU) | Phát hiện 5 ms · embedding R50 95 ms · anti-spoofing 1,3 ms |
| Một lượt điểm danh (6–8 khung) | ≈ **0,7 giây** |
| Anti-spoofing, mặt thật | thấp nhất **0,95** |
| Anti-spoofing, ảnh in / màn hình | ≈ **0,00** |
| Anti-spoofing, video trên điện thoại | cao nhất **0,68** (dưới ngưỡng 0,8; thử thách quay đầu chặn thêm) |
| Cosine cùng người, nhìn thẳng | 0,91–0,93 |
| Cosine khác người | ≈ 0,03 |

### 3.2 Ngưỡng
Đặt trong cấu hình server, chỉnh được không cần build lại app.

| Tham số | Giá trị tạm | Ý nghĩa |
|---|---|---|
| `accept_threshold` | 0,50 | Cosine ≥ mức này: khuôn mặt **đạt** |
| `suspect_threshold` | 0,40 | Từ 0,40 đến dưới 0,50 là **sát ngưỡng** (đáng ngờ); dưới 0,40 là **không khớp** |
| `antispoof_threshold` | 0,80 | Điểm "người thật" thấp hơn: chặn |
| `yaw_threshold` | 0,25 | Mức quay đầu (≈ 20°) để tính là đã làm hành động |
| `min_face_px` / `min_brightness` / `min_sharpness` | 100 px / 60 / 50 | Chất lượng khung hình tối thiểu |

## 4. Đường xử lý khuôn mặt trên server

```
Khung hình JPEG (5–8 ảnh, cạnh dài ≤ 1280 px)
  │
  ├─ Lượt 1 (nhẹ, mọi khung): YuNet phát hiện mặt → căn chỉnh 112×112 theo 5 điểm mốc
  │     → đo: số mặt, độ rộng mặt, độ sáng, độ nét (phương sai Laplacian), góc quay (yaw)
  │     → cần ≥ 3 khung đạt chất lượng, nếu không: "Thiếu sáng" / "Ảnh bị mờ" / "Không thấy mặt"
  │
  ├─ Kiểm tra hành động: phải có 1 khung nhìn thẳng RỒI 1 khung quay đúng hướng được yêu cầu
  │     (trái/phải, chọn ngẫu nhiên) → chặn video quay sẵn
  │
  ├─ Lượt 2 (nặng): MiniFASNetV2 trên 3 khung nét nhất, lấy điểm THẤP nhất → < 0,8 thì chặn
  │     ArcFace trích embedding cho MỌI khung đạt
  │
  └─ Đối sánh 1-1: cosine từng khung với mẫu đã duyệt
        → điểm = trung vị; khung thấp nhất cũng phải ≥ ngưỡng nghi ngờ
        (so mọi khung để chặn ghép khung người khác với 1 khung của chính chủ)
```

**Mẫu khuôn mặt khi đăng ký:**
- Sinh viên chụp 3–5 ảnh (thẳng, hơi trái, hơi phải).
- Mỗi ảnh phải đạt chất lượng và anti-spoofing, và các ảnh phải là cùng một người.
- Mẫu = trung bình các embedding, chuẩn hóa thành 1 vector, rồi mã hóa AES-GCM trước khi lưu.

## 5. Định vị GPS

| Bước | Nội dung |
|---|---|
| Giảng viên mở phiên | App lấy mẫu GPS ≤ 20 giây, giữ mẫu có sai số ≤ 20 m, cần ≥ 5 mẫu. Server lấy **trung vị** làm **tâm phiên** và sai số tâm σ_gv |
| Sinh viên điểm danh | App lấy mẫu 5–10 giây, gửi **toàn bộ mẫu thô**. Server bỏ mẫu sai số > 30 m, cần ≥ 3 mẫu, lấy trung vị → vị trí và σ_sv |
| Khoảng cách | Công thức **Haversine** giữa vị trí sinh viên và tâm phiên → d |
| Bán kính thích ứng | **r = r₀ + σ_gv + σ_sv** (r₀ mặc định 20 m, chọn được 10–50 m; σ_sv có trần 30 m để không bị cố tình làm GPS kém cho bán kính phình to) |
| Quyết định | d ≤ r: **đạt** · r < d ≤ 2r: **lệch nhẹ** (tối đa "đáng ngờ") · d > 2r: **không đạt** |
| Chống giả | Cờ `isMocked` (Android), phát hiện **bước nhảy** > 30 m/s giữa các mẫu hoặc giữa các lượt |
| Tâm lệch | Khi > 70 % sinh viên đã qua khuôn mặt lệch cùng một phía, app báo giảng viên. Giảng viên bấm **tính lại tâm**: tâm mới = trung vị vị trí sinh viên, và hệ thống chỉ nâng hạng kết quả, không hạ |

## 6. Mã QR phòng học (bật/tắt theo phiên)

```
window = floor(thời_gian_unix / 30)
mã     = HMAC-SHA256(khóa_bí_mật_của_phiên, id_phiên || window) → 8 ký tự base32
Server chấp nhận window hiện tại và window ngay trước.
```

- Không lưu từng mã: server tự tính lại để so.
- Giảng viên mở web, chiếu QR toàn màn hình, mã tự đổi mỗi 30 giây; sinh viên quét bằng app trước khi chụp mặt.
- Không gắn cờ theo IP: cả lớp dùng wifi trường thì chung một IP, còn người nhận mã chuyển tiếp ở ngoài thường dùng 4G (IP khác). Chuyển tiếp mã do GPS và khuôn mặt chặn.

## 7. Luồng nghiệp vụ

### 7.1 Đăng ký khuôn mặt (một lần)
1. Sinh viên đọc và **đồng ý xử lý dữ liệu sinh trắc** (lưu phiên bản văn bản).
2. Chụp 3–5 ảnh. Server kiểm tra rồi tạo mẫu ở trạng thái **chờ duyệt**; ảnh lưu tạm đã mã hóa.
3. **PĐT** (web) hoặc **giảng viên lớp** đối chiếu với ảnh thẻ sinh viên, rồi **duyệt** hoặc **từ chối** (kèm lý do).
4. Duyệt xong thì **xóa ảnh**, chỉ giữ embedding đã mã hóa.

### 7.2 Mở phiên (giảng viên, app)
1. Giảng viên chọn **buổi học hôm nay** của lớp đang học, thời hạn (mặc định 10 phút), r₀, và bật/tắt mã QR.
2. App lấy mẫu GPS cho đủ, rồi server chốt tâm.
3. Server tạo sẵn kết quả **"Vắng không phép"** cho cả lớp. Vì vậy danh sách thời gian thực hiện đủ người.

### 7.3 Sinh viên điểm danh: 6 bước kiểm tra, từ rẻ đến đắt

| Bước | Kiểm tra | Không đạt khi |
|---|---|---|
| 0 | Xin **thử thách**: nonce dùng 1 lần, hạn 60 giây, hành động ngẫu nhiên (quay trái/phải). Mỗi lần xin tính 1 lượt, **tối đa 5 lượt/phiên** | Phiên đóng, chưa có mẫu mặt được duyệt, hết lượt, đã có mặt |
| 1 | Phiên còn mở, sinh viên thuộc lớp | Phiên đã đóng / hết hạn |
| 2 | Nonce đúng sinh viên + phiên, chưa dùng, chưa hết hạn | Phát lại gói tin cũ |
| 3 | Mã phòng (nếu bật) | Mã sai / hết hạn |
| 4 | Vị trí GPS | Sai số quá lớn, hoặc d > 2r |
| 5 | Chất lượng + hành động + anti-spoofing | Thiếu sáng, mờ, sai hành động, ảnh giả |
| 6 | Đối sánh khuôn mặt | Không khớp |

**Bảng quyết định** (áp dụng khi qua cả 6 bước):

| Khuôn mặt \ Vị trí | d ≤ r | r < d ≤ 2r |
|---|---|---|
| Đạt | **Có mặt** | Đáng ngờ |
| Sát ngưỡng | Đáng ngờ | Đáng ngờ |

**Biến "có mặt" thành "đáng ngờ"** khi có một trong các dấu hiệu:
- vị trí giả;
- bước nhảy vị trí;
- **cùng máy đã điểm danh cho sinh viên khác** trong phiên.

**Quy tắc ghi kết quả:**
- Kết quả chỉ **nâng hạng**: vắng < đáng ngờ < có mặt.
- Khi giảng viên đã quyết định tay, hệ thống **không ghi đè**.
- Sinh viên chỉ nhận thông điệp lý do, **không thấy điểm số thô**, để không dò được ngưỡng.

### 7.4 Giảng viên theo dõi và đóng phiên
- Danh sách tự làm mới mỗi 4 giây: có mặt, đáng ngờ, chưa điểm danh, kèm cờ.
- **Điểm danh thủ công**: sinh viên chưa đăng ký khuôn mặt, quên mang điện thoại, máy hỏng hoặc hết lượt thì báo giảng viên; giảng viên đánh có mặt ngay trong phiên. Danh sách đánh dấu sẵn ai chưa có mẫu khuôn mặt được duyệt.
- Lượt đáng ngờ có **ảnh bằng chứng** (1 khung, mã hóa, giữ 30 ngày), điểm mặt, d, r. Giảng viên **duyệt có mặt** hoặc **từ chối**.
- Đặt trạng thái hàng loạt cho trường hợp mất mạng hoặc GPS phòng hỏng.
- Đóng phiên bằng tay, hoặc phiên tự hết hạn. Sau khi đóng vẫn chỉnh tay được như hiện nay.
- **Mở lại phiên** (bấm nhầm đóng, hoặc còn sinh viên chưa kịp): chỉ trong ngày của buổi. Mở lại giữ nguyên tâm, bán kính, kết quả và số lượt đã dùng; chỉ đặt thời hạn mới.

## 8. Ánh xạ vào hệ thống hiện có

| Đặc tả | Hệ thống đăng ký môn học |
|---|---|
| Lớp, danh sách lớp | `ClassSection` + `Registration` (đã đăng ký) |
| Phiên điểm danh | **Dùng lại** `AttendanceSession` (buổi sinh sẵn theo lịch học), thêm cột phiên |
| Kết quả điểm danh | **Dùng lại** `Attendance`: có mặt → `CO_MAT`; có phép → `VANG_CO_PHEP`; vắng/từ chối → `VANG_KHONG_PHEP`; **đáng ngờ** = vắng + cờ `dang_ngo` |
| Đơn xin nghỉ / khiếu nại | Đã có (`AttendanceRequest`) → không làm lại |
| Cảnh báo vắng, cấm thi, lịch, thông báo, báo cáo Excel, nhật ký | Đã có → không làm lại |
| Quản trị viên duyệt mặt | **PĐT** duyệt; **giảng viên** duyệt sinh viên lớp mình |

## 9. Thiết kế dữ liệu

**Mở rộng bảng cũ**
- `attendance_attendancesession`:
  - tâm phiên: `tam_lat`, `tam_lng`, `tam_sai_so_m`, `tam_goc_lat`, `tam_goc_lng`;
  - `ban_kinh_m`, `kiem_tra_phong`, `ma_phong_bi_mat`;
  - `mo_luc`, `het_han_luc`, `dong_luc`, `nguoi_mo`.
- `attendance_attendance`: `dang_ngo`, `luot_tot_nhat`, `nguoi_quyet`.

**Bảng mới**

| Bảng | Nội dung chính |
|---|---|
| `attendance_facetemplate` | Sinh viên, tên mô hình, embedding (mã hóa), trạng thái chờ duyệt/đã duyệt/từ chối/thu hồi, người duyệt, lý do. Mỗi sinh viên tối đa 1 mẫu đã duyệt + 1 mẫu chờ duyệt |
| `attendance_consent` | Sinh viên, phiên bản văn bản đồng ý, lúc đồng ý / rút lại |
| `attendance_challenge` | Buổi, sinh viên, nonce, hành động, hạn, đã dùng |
| `attendance_checkinattempt` | Mọi lượt gửi lên: mẫu GPS thô, d, r, điểm mặt, điểm liveness, kết quả, bước dừng, cờ, ảnh bằng chứng |

## 10. API mới

| Vai trò | Đường dẫn | Chức năng |
|---|---|---|
| SV | `POST /api/attendance/consent/` | Đồng ý dữ liệu |
| SV | `GET`, `DELETE /api/attendance/face/me/` | Trạng thái / xóa khuôn mặt |
| SV | `POST /api/attendance/faces/enroll/` | Gửi 3–5 ảnh đăng ký |
| SV | `GET /api/attendance/open-sessions/` | Các phiên đang mở của lớp mình |
| SV | `POST /api/attendance/sessions/{id}/challenge/` | Xin thử thách |
| SV | `POST /api/attendance/sessions/{id}/checkin/` | Gửi khung hình + mẫu GPS + mã phòng |
| GV | `POST /api/attendance/sessions/{id}/mo-phien/` | Mở phiên (kèm mẫu GPS) |
| GV | `POST /api/attendance/sessions/{id}/dong-phien/` | Đóng phiên |
| GV | `POST /api/attendance/sessions/{id}/mo-lai/` | Mở lại phiên đã đóng / hết hạn (trong ngày) |
| GV | `POST /api/attendance/sessions/{id}/tinh-lai-tam/` | Tính lại tâm |
| GV | `GET /api/attendance/sessions/{id}/room-token/` | Mã QR hiện tại |
| GV | `GET`, `PATCH /api/attendance/sessions/{id}/tu-diem-danh/` | Danh sách thời gian thực / đặt trạng thái hàng loạt |
| GV | `POST /api/attendance/attempts/{id}/quyet/` | Duyệt có mặt / từ chối lượt đáng ngờ (ghi nhật ký) |
| GV | `GET /api/attendance/attempts/{id}/evidence/` | Ảnh bằng chứng lượt đáng ngờ |
| PĐT, GV | `GET /api/attendance/faces/pending/` | Danh sách chờ duyệt |
| PĐT, GV | `GET /api/attendance/faces/{id}/photos/` | Xem ảnh đăng ký (ghi nhật ký) |
| PĐT, GV | `POST /api/attendance/faces/{id}/review/` | Duyệt / từ chối |

## 11. Màn hình

| Vai trò | Màn hình |
|---|---|
| Sinh viên (app) | Đồng ý dữ liệu · Đăng ký khuôn mặt (khung oval, 3 tư thế) · Khuôn mặt của tôi · **Điểm danh** từng bước: thử thách → quét QR → GPS (hiện độ chính xác) → camera "Quay đầu sang trái" + đếm 60 giây → kết quả, lý do, số lượt còn lại |
| Giảng viên (app) | **Mở phiên** (thanh trạng thái GPS) · **Phiên đang chạy** (bộ đếm, lọc, duyệt đáng ngờ, hàng loạt, tính lại tâm, đóng) · Chi tiết sinh viên trong phiên · Duyệt khuôn mặt lớp mình |
| Giảng viên (web) | Chiếu mã QR toàn màn hình |
| PĐT (web) | Duyệt khuôn mặt toàn trường |

Phần lớn màn hình được chuyển từ app của project `DiemDanhKhuonMat_GPS` sang giao diện của hệ thống này.

## 12. Bảo mật và quyền riêng tư

| Dữ liệu | Xử lý | Thời hạn |
|---|---|---|
| Embedding khuôn mặt | Mã hóa AES-256-GCM, khóa `DATA_KEY` trong `.env` (không nằm trong DB) | Đến khi xóa / đăng ký lại / thôi học |
| Ảnh đăng ký | Lưu tạm, mã hóa | Xóa ngay khi duyệt hoặc từ chối |
| Khung hình điểm danh | Chỉ xử lý trong bộ nhớ | Không lưu |
| Ảnh bằng chứng (đáng ngờ) | 1 khung, mã hóa | 30 ngày, tác vụ Celery xóa hằng ngày |
| Mẫu GPS | Chỉ lúc điểm danh, không theo dõi liên tục | Hết học kỳ |

Các biện pháp khác:
- HTTPS khi lên VPS.
- Phân quyền: sinh viên chỉ thấy dữ liệu của mình, giảng viên chỉ thấy lớp mình.
- Ghi **nhật ký** mỗi lần xem ảnh, duyệt mặt, chỉnh kết quả.
- Sinh viên **tự xóa** được dữ liệu khuôn mặt.
- Cần xin phép nhà trường theo **Nghị định 13/2023/NĐ-CP** về bảo vệ dữ liệu cá nhân.

## 13. Hạ tầng và tài nguyên

- Model ONNX: khoảng **177 MB**, nằm ở `backend/face_models/`, không đưa lên git (ghi nguồn tải và sha256 trong README).
- RAM: mỗi worker Gunicorn nạp model riêng, khoảng 0,5 GB. Với 3 worker, VPS nên có **≥ 4 GB RAM** (đặc tả gợi ý 4 vCPU / 8 GB).
- CPU: một lượt điểm danh khoảng 0,7 giây. Server giới hạn số lượt suy luận chạy cùng lúc bằng số core, nên 60 sinh viên trong vài phút vẫn ổn.
- Volume `media` cho ảnh (đã thêm vào `docker-compose.yml`).

## 14. Thứ tự triển khai

| Đợt | Nội dung | Kiểm tra |
|---|---|---|
| 1 | Chép lõi thuần (khuôn mặt, GPS, mã phòng, mã hóa) + test thuần | `pytest` |
| 2 | Bảng dữ liệu, nghiệp vụ, API (engine giả để test) | `pytest`: từng bước dừng 1–6, bảng quyết định, 5 lượt, nonce dùng lại |
| 3 | App: đồng ý, đăng ký, duyệt khuôn mặt | `flutter test` |
| 4 | App: mở phiên, điểm danh, theo dõi, duyệt | `flutter test` |
| 5 | Mã QR, tính lại tâm, dọn dữ liệu | `pytest`, `flutter test` |
| 6 | Build Docker, chạy thật trên Android | Kịch bản: mặt thật (đạt), ảnh trên màn hình (chặn), ở xa (chặn), 2 người 1 máy (đáng ngờ) |

## 15. Giới hạn cần nói rõ

- Máy đã **root** có công cụ chuyên dụng vẫn giả được GPS; iOS không có cờ vị trí giả.
- Sinh viên có cả **web**: trên web không phát hiện được vị trí giả (Chrome DevTools đổi tọa độ trong vài giây) và `device_id` xóa được. Mã phòng chặn người ở nhà tự làm một mình, nhưng không chặn được khi có bạn trong lớp nhắn mã ra ngay lúc đó. Chính sách cho lượt điểm danh từ web **chưa chốt**; giai đoạn đầu dùng bản web để test.
- GPS trong nhà lệch 5–20 m, **không phân biệt được phòng hay tầng**: cần mã QR nếu muốn chắc đúng phòng.
- Chuyển tiếp mã QR cho bạn ở ngoài trong vòng 30 giây chỉ **giảm** được rủi ro; người đó vẫn phải qua khuôn mặt và GPS.
- Ngưỡng hiện là **giá trị tạm** từ thí nghiệm nhỏ; cần đo thêm FAR/FRR trên dữ liệu thật trước khi dùng chính thức.
- Mô hình ArcFace của InsightFace **chỉ được dùng phi thương mại**.
