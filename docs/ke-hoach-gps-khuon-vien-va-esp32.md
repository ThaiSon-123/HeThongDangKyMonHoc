# Kế hoạch: GPS theo khuôn viên trường và xác nhận "trong phòng" bằng ESP32 (BLE)

> Trạng thái: **đã làm** (19/11/2026): GPS khuôn viên (mục 3) và ESP32 (mục 4). Ghi lại các trao đổi ngày 14–19/11/2026.
> Liên quan: `docs/ke-hoach-diem-danh-khuon-mat-gps.md` (KH), `docs/checklist_diemdanh.md`, `docs/ke-hoach-gop-diem-danh.md`.
> Những chỗ ghi "chưa kiểm chứng" là điều chưa thử trong dự án, cần thử trước khi dựa vào.

---

## 1. Vấn đề (cách cũ, đã bỏ)

Cách cũ: tâm = GPS của giảng viên lúc mở phiên, bán kính `r = r₀ + σ_gv + min(σ_sv, 30)`.

- GPS trong phòng kín rất kém (KH §15). Laptop không có chip GPS, định vị bằng Wi-Fi hoặc IP, sai số 30–1000 m.
- Giảng viên phải đứng lấy ≥ 5 mẫu GPS sai số ≤ 20 m mới mở được phiên; trên laptop gần như không đạt.

## 2. Hướng đã chọn: hai lớp xác nhận tách nhau

| Lớp | Xác nhận | Công cụ |
|---|---|---|
| Ở **trường** | Sinh viên đang trong khuôn viên | GPS + đa giác khuôn viên (mục 3), **mọi phiên** |
| Trong **phòng** | Sinh viên đang gần giảng viên | Bluetooth ESP32 (mục 4), giảng viên **bật/tắt khi mở phiên** ("Bắt mã phòng") |

Khuôn mặt và chống giả mạo vẫn chạy ở mọi phiên. **Đã bỏ hẳn** kiểu "quanh vị trí giảng viên": không còn lấy GPS giảng viên, bán kính r₀, "Tính lại tâm" (quyết định 19/11).

## 3. GPS theo khuôn viên trường

### 3.1 Mở phiên
Giảng viên chỉ chọn thời hạn và "Bắt mã phòng"; không cần đứng lấy GPS. Chưa vẽ khuôn viên thì server chặn mở phiên (`CHUA_CO_KHUON_VIEN`).

### 3.2 Vẽ khuôn viên (Phòng đào tạo, màn Quy chế, nhóm Điểm danh)
- Bản đồ `flutter_map` + OpenStreetMap (cần internet): chạm để thêm góc, chạm vào góc để xóa, Hoàn tác, Xóa hết. Chưa có kéo để chỉnh góc.
- Lưu trong `SystemConfig`: `khuon_vien` = JSON `[[vĩ độ, kinh độ], ...]` (3–100 góc, rỗng = chưa vẽ) và `sai_lech_khuon_vien_m` (mặc định 30, 0–500).

### 3.3 Kiểm tra phía server
- `geo.distance_to_polygon_m`: khoảng cách `d` từ vị trí sinh viên đến đa giác (0 nếu nằm trong, đa giác lõm vẫn đúng).
- `geo.classify(d, sai_lech)`: `d ≤ sai_lech` → đạt; `≤ 2×sai_lech` → đáng ngờ (cờ "Sát mép khuôn viên"); lớn hơn → `QUA_XA` ("Ngoài khuôn viên").
- Cổng chất lượng mẫu (`aggregate`, `max_acc_sv_m`), cờ vị trí giả và bước nhảy giữ nguyên.

### 3.4 Dữ liệu
- Migration `attendance 0006`: bỏ `tam_lat`, `tam_lng`, `tam_sai_so_m`, `tam_goc_lat`, `tam_goc_lng`, `ban_kinh_m` của `AttendanceSession`.
- Migration `config 0002`: `SystemConfig.gia_tri` dài tối đa 4000 ký tự (đủ cho đa giác).
- Bỏ endpoint `POST sessions/{id}/tinh-lai-tam/` và khóa cấu hình `ban_kinh_diem_danh_m`.

### 3.5 Còn mở
- Một đa giác cho cả trường; thêm nhiều vùng khi trường có nhiều cơ sở.

## 4. ESP32 và Bluetooth: xác nhận sinh viên đang trong phòng

### 4.1 Hướng đã bỏ
ESP32 **quét** điện thoại đang bật Bluetooth để biết ai ở gần: khó chạy ổn định. Điện thoại không có app phát tín hiệu thì gần như không phát gì, và Android lẫn iOS đổi địa chỉ MAC ngẫu nhiên, nên không biết điện thoại nào của sinh viên nào.

### 4.2 Hướng chọn: ESP32 làm beacon, cắm vào máy giảng viên
1. ESP32 cắm USB vào **máy tính của giảng viên**.
2. Trên web, giảng viên bấm "Kết nối ESP32" và chọn cổng (Web Serial, Chrome hoặc Edge máy tính).
3. Trang web lấy **mã phòng** từ server (`GET sessions/{id}/room-token/`, đổi mỗi 30 giây, sinh bằng `room_token.py`) và gửi qua USB cho ESP32.
4. ESP32 phát mã qua Bluetooth BLE ở công suất thấp.
5. Điện thoại sinh viên đọc mã, gửi lên server như `ma_phong`. Server **không phải sửa**, vì mã đã được kiểm bằng HMAC hiện có.

Tâm lúc này là chiếc ESP32 trên bàn giảng viên: không cần GPS giảng viên.

Ưu điểm: ESP32 không cần Wi-Fi, không giữ bí mật, không cần đồng bộ giờ; cắm máy nào cũng dùng được.

### 4.3 Vì sao phải dùng mã đổi liên tục
"Có trong phạm vi" do máy sinh viên tự báo nên có thể bị giả. Server chỉ tin mã đổi mỗi 30 giây mà ESP32 phát. Việc chỉ thấy ESP32 là chưa đủ.

### 4.4 Luồng trên từng nền tảng
| Nền tảng | Cách hoạt động |
|---|---|
| **App Android** | Quét ngầm hoàn toàn tự động, không hiện hộp chọn. Bấm Bắt đầu, thấy ESP32 thì sang bước quét mặt |
| **Web, Chrome/Edge Android** | Web Bluetooth, **không tự quét**. Sinh viên bấm "Kiểm tra có trong phòng", chọn ESP32 trong hộp chọn của trình duyệt, trang đọc mã rồi tự điền vào `ma_phong` và chuyển sang quét mặt |
| **Safari iPhone, Firefox** | **Không hỗ trợ Web Bluetooth.** Gõ tay mã phòng như hiện nay |

Trình duyệt cấm trang web tự quét Bluetooth khi vừa vào trang; luôn cần một thao tác của người dùng. Không đọc được mã thì sinh viên không qua bước này.

### 4.5 Yêu cầu và giới hạn
- ESP32 phải là **máy chủ GATT** (cho thiết bị khác kết nối đọc mã) để dùng được với Web Bluetooth.
- **Số kết nối cùng lúc của ESP32 có hạn.** Mỗi lần đọc 1–2 giây, nhưng cả lớp bấm đồng loạt có thể phải thử lại. **Chưa đo giới hạn cụ thể.**
- Cách quét quảng bá (`watchAdvertisements`) tránh được việc kết nối, nhưng **chưa kiểm chứng** nó có bật sẵn trên Chrome Android hay chưa.
- Cần gói Flutter cho Web Bluetooth; **chưa chọn và chưa thử** với Flutter web của dự án.
- Trang web giảng viên **phải mở suốt phiên** để đẩy mã mới cho ESP32.
- Web Serial chỉ chạy trên Chrome/Edge máy tính, lần đầu phải chọn cổng tay.
- Phạm vi chỉnh bằng công suất phát ESP32 và ngưỡng tín hiệu (RSSI) ở app. Ngưỡng ở app chỉ là kiểm tra phía máy sinh viên nên có thể bị giả.
- Mã vẫn có thể bị chuyển tiếp (người trong phòng đọc rồi nhắn cho bạn ngoài phòng). Khuôn mặt vẫn chặn việc điểm danh hộ.

### 4.5.0 Đã thử trên phần cứng (18/11/2026)
Firmware: `firmware/esp32_beacon/esp32_beacon.ino` (ESP32-S3, cổng UART/CH343, Arduino IDE 2.3.6, gói esp32 của Espressif).
- Gửi mã qua serial → ESP32 trả `OK <mã>`: **đạt**.
- Quảng bá tên `DD-<mã>`, nRF Connect (Android) thấy ngay, khoảng -47 dBm khi đặt sát: **đạt**.
- Kết nối GATT, đọc đặc tính ra đúng mã: **đạt**.
- Đổi mã → tên và giá trị đổi theo; nhiều máy kết nối: **đạt** (chưa đo số máy tối đa).
- **Chưa đo** bảng RSSI theo khoảng cách (cuối phòng, hành lang) → chưa chọn ngưỡng và công suất phát.
- Web Bluetooth trên **Chrome Windows** (`localhost`), trang thử `firmware/esp32_beacon/thu_web_bluetooth.html`: hộp chọn lọc theo UUID chỉ hiện ESP32, bấm Pair rồi đọc ra đúng mã, kết nối + đọc mất khoảng 1,8 giây: **đạt**.
- Web Serial (19/11): trang giảng viên (khối "Mã phòng", `lib/core/serial/`) bấm "Kết nối ESP32", chọn cổng COM của CH343 (Chrome ghi là "USB Single Serial"), ESP32 phát `DD-<mã đang hiện>`, đổi theo mỗi khi mã đổi (30 giây): **đạt**.
- **Chưa thử** Web Bluetooth trên **Chrome Android** (cần HTTPS hoặc cờ `unsafely-treat-insecure-origin-as-secure`).

### 4.5.1 Phần cần viết khi làm
- Firmware ESP32 (Arduino): máy chủ GATT, nhận mã qua serial, phát mã, chỉnh công suất.
- Web (giảng viên): kết nối Web Serial và đẩy `room-token` mỗi lần mã đổi.
- Web / app (sinh viên): đọc mã qua BLE và điền vào bước mã phòng.
- Hiện server chỉ có một bí mật cho mỗi **phiên** (`ma_phong_bi_mat`). Cách làm trên dùng được ngay vì mã vẫn thuộc phiên.

### 4.6 Chọn phần cứng
Cần ESP32 có BLE và cổng USB để cắm vào máy.

| Loại | Ghi chú |
|---|---|
| **ESP32-S3 DevKitC-1** (bạn chọn) | Có USB gốc, hầu như không cần driver. Loại **hàn sẵn chân** tiện hơn. N16R8 (flash 16 MB, PSRAM 8 MB) dư so với nhu cầu nhưng dùng được; N8 hay N8R2 rẻ hơn cũng đủ |
| ESP32-C3 DevKit, Super Mini | Nhỏ, rẻ, BLE 5, USB-C |
| ESP32-WROOM-32 DevKit | Rẻ, phổ biến, dùng chip chuyển USB nên Windows có thể phải cài driver |
| **ESP32-S2** | **Không có Bluetooth, không dùng** |

Lưu ý với DevKitC-1:
- Board có **2 cổng USB-C**: cổng ghi UART (qua chip chuyển đổi, có thể cần driver) và cổng ghi USB (cổng gốc của chip S3, không cần driver). Với Web Serial nên cắm **cổng USB gốc**; nếu máy không nhận thì thử cổng UART.
- Nhiều shop bán bản nhái; vẫn chạy nhưng chip chuyển đổi có thể là CH343 hoặc CH340 và phải cài driver.
- Cáp USB-C phải **có truyền dữ liệu** (cáp chỉ sạc sẽ không hiện cổng).
- Nên mua 2 board dự phòng.

## 5. Triển khai bản web lên VPS

Sinh viên dùng bản web điểm danh được, với điều kiện:

1. **HTTPS.** Camera và định vị trên trình duyệt chỉ chạy trên HTTPS hoặc `localhost`. Cần tên miền trỏ về VPS và chứng chỉ SSL (ví dụ Let's Encrypt). Checklist ghi mục này là "phải bật trước khi cho SV dùng".
2. **Sinh viên bấm Cho phép** camera và vị trí. Chrome Android và Safari iPhone đều hoạt động.
3. **Host giao diện web.** nginx trong Docker hiện chỉ phục vụ backend. Cần `flutter build web --dart-define=API_BASE_URL=https://tên-miền/api` rồi đặt bản build trên cùng tên miền.

Cấu hình VPS:
- Dùng cấu hình **prod**. Prod bắt buộc có `DATA_KEY`, liệt kê rõ `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS`, `CSRF_TRUSTED_ORIGINS`. `DATA_KEY` cần sao lưu riêng, mất là sinh viên phải đăng ký lại khuôn mặt.
- Model `.onnx` **không nằm trong git** (`face_detection_yunet_2023mar.onnx`, `w600k_r50.onnx`, `MiniFASNetV2.onnx`): copy 3 file vào `backend/face_models/` trước khi build image.
- RAM: checklist khuyến nghị VPS từ 4 GB (mỗi worker gunicorn nạp model khoảng 0,5 GB). **Chưa đo thực tế.**
- Dòng `GPS_MAX_ACC_SV_M` trong `.env` chỉ dùng cho dev (laptop). Prod để ngưỡng thật 30 m. Nhớ vẽ khuôn viên trước khi giảng viên mở phiên.

Hạn chế của bản web so với app Android:
- Không phát hiện được vị trí giả (`is_mocked` luôn `false`).
- `device_id` nằm trong bộ nhớ trình duyệt, xóa dữ liệu trang là mất nên cờ "cùng máy" kém tin cậy.
- Bluetooth ESP32 chỉ dùng được trên Chrome/Edge Android (mục 4.4); iPhone phải gõ tay mã phòng.
- Chính sách "điểm danh trên web" vẫn **chưa chốt** (checklist, điểm 6). Server đã lưu `nen_tang` cho từng lượt nên đổi sau chỉ sửa một chỗ trong bảng quyết định.

## 6. Thứ tự làm đề xuất

1. ~~GPS khuôn viên~~ (mục 3): **đã làm** 19/11.
2. ~~BLE với ESP32 trên web~~ (mục 4): **đã làm** firmware, Web Serial ở trang giảng viên, nút "Đọc mã từ ESP32" phía sinh viên (web). Còn: quét ngầm trong app Android.
3. **Chính sách web và triển khai VPS** (mục 5): chốt trước khi cho sinh viên dùng thật.

## 7. Câu hỏi còn mở

- Trong lớp có iPhone không? Nếu có, nhóm này dùng gõ tay mã phòng (hoặc cách khác, chưa thiết kế).
- Chấp nhận một lần bấm chọn thiết bị trên web, hay yêu cầu hoàn toàn tự động (phải dùng app Android thay cho web)?
- Chính sách điểm danh trên web (checklist, điểm 6).
