# Kế hoạch: GPS theo khuôn viên trường và xác nhận "trong phòng" bằng ESP32 (BLE)

> Trạng thái: **bản nháp ý tưởng, chưa làm.** Ghi lại các trao đổi ngày 14–15/11/2026.
> Liên quan: `docs/ke-hoach-diem-danh-khuon-mat-gps.md` (KH), `docs/checklist_diemdanh.md`, `docs/ke-hoach-gop-diem-danh.md`.
> Những chỗ ghi "chưa kiểm chứng" là điều chưa thử trong dự án, cần thử trước khi dựa vào.

---

## 1. Vấn đề

Cách xác nhận vị trí hiện tại: tâm = GPS của giảng viên lúc mở phiên, bán kính `r = r₀ + σ_gv + min(σ_sv, 30)`.

- GPS trong phòng kín rất kém (đã nằm trong KH §15). Laptop không có chip GPS, định vị bằng Wi-Fi hoặc IP, sai số 30–1000 m, nên test trên laptop không đại diện cho điện thoại thật.
- Ngưỡng hiện tại: giảng viên cần ≥ 5 mẫu sai số ≤ 20 m, sinh viên ≥ 3 mẫu sai số ≤ 30 m. Laptop không đạt nên báo "Chưa đủ 5 mẫu GPS có sai số ≤ 20 m".
- Tạm thời để test: `backend/config/settings/dev.py` đọc `GPS_MAX_ACC_GV_M` và `GPS_MAX_ACC_SV_M` từ `.env` (đang đặt 500 m trên máy dev). Mặc định vẫn là 20 và 30 m, prod không dùng file này. Tác dụng phụ: bán kính chấp nhận phình ra rất lớn nên không thử được "quá xa".

## 2. Hướng giải quyết: hai lớp xác nhận tách nhau

| Lớp | Xác nhận | Công cụ |
|---|---|---|
| Ở **trường** | Sinh viên đang trong khuôn viên | GPS + đa giác khuôn viên (mục 3) |
| Trong **phòng** | Sinh viên đang gần giảng viên | Bluetooth ESP32 (mục 4) |

Hai lớp độc lập, chọn theo từng phiên. Khuôn mặt và chống giả mạo vẫn chạy ở mọi chế độ.

## 3. GPS: 3 chế độ cho mỗi phiên và đa giác khuôn viên

### 3.1 Chọn chế độ khi giảng viên mở phiên
1. **Quanh vị trí giảng viên:** như hiện tại (mặc định, không ảnh hưởng phần đang chạy).
2. **Trong khuôn viên trường:** dùng đa giác do quản trị vẽ.
3. **Không kiểm tra GPS.**

Với chế độ 2 và 3: giảng viên không cần đứng lấy GPS 10 giây; khối "tâm" và nút "Tính lại tâm" ẩn đi; màn sinh viên bỏ qua bước lấy GPS nếu phiên không kiểm tra.

### 3.2 Vẽ khuôn viên (cấu hình toàn hệ thống)
- Màn bản đồ: chạm để thêm điểm, kéo để chỉnh, hoàn tác, xóa.
- Ô **"Sai lệch cho phép (m)"** do người quản trị đặt, mặc định đề xuất 30 m.
- Lưu vào cấu hình hệ thống (`SystemConfig`), không cần sửa code mỗi lần đổi.

### 3.3 Cách kiểm tra phía server
- Tính khoảng cách `d` từ vị trí sinh viên đến đa giác (0 nếu nằm trong).
- Dùng lại `geo.classify(d, sai_lech)` và bảng quyết định sẵn có: `d ≤ sai_lech` → đạt; `≤ 2×sai_lech` → lệch nhẹ (đáng ngờ); lớn hơn → không đạt.
- Cổng chất lượng mẫu (`aggregate`, `max_acc_sv_m`) giữ nguyên. Cờ vị trí giả và bước nhảy vẫn áp dụng.

### 3.4 Dữ liệu
- Thêm cột "chế độ GPS" cho `AttendanceSession` (migration nhỏ).
- Cấu hình mới: đa giác (danh sách tọa độ) và sai lệch cho phép.

### 3.5 Các quyết định còn mở (mặc định đề xuất)
| # | Câu hỏi | Mặc định |
|---|---|---|
| 1 | Thư viện bản đồ | `flutter_map` + OpenStreetMap (cần internet, web và Android). Phương án khác: nhập tay danh sách tọa độ |
| 2 | Ai được vẽ | Admin và Phòng đào tạo |
| 3 | Số vùng | Một đa giác, thêm nhiều vùng khi trường có nhiều cơ sở |
| 4 | Chọn "Trong khuôn viên" mà chưa vẽ | Chặn mở phiên và báo giảng viên |

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
- Dòng `GPS_MAX_ACC_*` trong `.env` chỉ dùng cho dev. Prod để ngưỡng thật (20 và 30 m) hoặc dùng GPS đa giác ở mục 3.

Hạn chế của bản web so với app Android:
- Không phát hiện được vị trí giả (`is_mocked` luôn `false`).
- `device_id` nằm trong bộ nhớ trình duyệt, xóa dữ liệu trang là mất nên cờ "cùng máy" kém tin cậy.
- Bluetooth ESP32 chỉ dùng được trên Chrome/Edge Android (mục 4.4); iPhone phải gõ tay mã phòng.
- Chính sách "điểm danh trên web" vẫn **chưa chốt** (checklist, điểm 6). Server đã lưu `nen_tang` cho từng lượt nên đổi sau chỉ sửa một chỗ trong bảng quyết định.

## 6. Thứ tự làm đề xuất

1. **GPS 3 chế độ và đa giác khuôn viên** (mục 3): không cần phần cứng, test được ngay. Thứ tự: backend và test, màn chọn chế độ khi mở phiên, màn vẽ bản đồ.
2. **BLE với ESP32** (mục 4): làm sau khi board về. Việc: firmware, Web Serial ở trang giảng viên, đọc BLE phía sinh viên.
3. **Chính sách web và triển khai VPS** (mục 5): chốt trước khi cho sinh viên dùng thật.

## 7. Câu hỏi còn mở

- Mục 3.5: bốn quyết định về bản đồ, người vẽ, số vùng, và trường hợp chưa vẽ.
- Trong lớp có iPhone không? Nếu có, nhóm này dùng gõ tay mã phòng (hoặc cách khác, chưa thiết kế).
- Chấp nhận một lần bấm chọn thiết bị trên web, hay yêu cầu hoàn toàn tự động (phải dùng app Android thay cho web)?
- Chính sách điểm danh trên web (checklist, điểm 6).
