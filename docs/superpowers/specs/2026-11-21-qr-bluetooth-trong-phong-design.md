# Thiết kế: xác nhận "trong phòng" bằng QR + Bluetooth (hai mã)

> 21/11/2026 · Liên quan: `docs/ke-hoach-gps-khuon-vien-va-esp32.md` §4.

## Vì sao
Hiện tại bước "trong phòng" chỉ kiểm **một mã** (đổi 30 giây). Mã đó vừa hiện trên màn GV vừa do ESP32 phát, nên SV ngoài phòng chỉ cần được nhắn mã là qua; ESP32 chỉ giúp đỡ phải gõ. Mục tiêu: quét QR là bước mở đầu, sau đó hệ thống bắt bật Bluetooth và kiểm tra máy SV có gần ESP32 không, theo cách server kiểm được. iPhone (không có Web Bluetooth) vẫn điểm danh được nhưng phải chờ GV duyệt.

## Cách làm đã chọn
Hai mã khác nhau, cùng sinh từ `ma_phong_bi_mat` của phiên, cùng cửa sổ 30 giây:

| Mã | Ở đâu | Chứng minh |
|---|---|---|
| **Mã QR** (mã hiện có, giữ nguyên cách sinh) | QR + chữ trên màn GV | SV nhìn thấy màn chiếu |
| **Mã Bluetooth** (mới, HMAC thêm nhãn `ble`) | Chỉ ESP32 phát, **không hiện trên màn** | Máy SV ở gần ESP32 |

Đã cân nhắc và bỏ: ESP32 quét điện thoại SV (web/iPhone không phát được, MAC ngẫu nhiên, khối lượng lớn); một mã như cũ (không vá được lỗ hổng nhắn mã).

## Luồng SV (phiên bật "Bắt mã phòng")
GPS (nếu bật) → **Mã QR** → **Bluetooth** → thử thách (tính lượt) → quét mặt. Danh sách bước hiện hai dòng riêng: "Mã QR trên màn chiếu" và "Bluetooth (gần máy giảng viên)".
1. **QR:** nút "Quét QR" mở camera (thư viện `mobile_scanner`, chạy cả app lẫn web); hoặc gõ mã hiện dưới QR.
2. **Bluetooth:** app Android nhắc bật Bluetooth rồi tự dò; web Chrome Android bấm "Kiểm tra Bluetooth" và chọn ESP32; máy không hỗ trợ (iPhone…) thì báo không kiểm tra được.
3. Bluetooth không đạt / không hỗ trợ: hiện nút **"Tiếp tục không có Bluetooth"** kèm cảnh báo "lượt sẽ chờ giảng viên duyệt".

## Server
- `room_token`: thêm tham số kênh (`qr` mặc định, giữ nguyên mã cũ; `ble` thêm nhãn vào HMAC).
- `GET sessions/{id}/room-token/` trả thêm `ma_ble`.
- `POST sessions/{id}/challenge/` nhận thêm `ma_bluetooth` (tùy chọn):
  - `ma_phong` (mã QR) thiếu/sai → `MA_PHONG_SAI` như cũ, không tính lượt.
  - `ma_bluetooth` **có gửi mà sai** → `MA_BLUETOOTH_SAI`, không tính lượt (để app dò lại).
  - `ma_bluetooth` **không gửi** → vẫn cấp thử thách, ghi `Challenge.co_bluetooth = False` (migration thêm cột).
- `checkin`: phiên bật phòng mà thử thách không có Bluetooth → thêm cờ `KHONG_BLUETOOTH` → lượt **đáng ngờ** (GV duyệt). Server tự biết, SV không khai gian được.

## GV
- Khối "Mã phòng": thêm **QR** (`qr_flutter`, đã có) chứa mã QR, chữ mã QR dưới để SV gõ; đẩy **`ma_ble`** xuống ESP32 thay cho mã QR.
- Nhãn cờ mới: "Không xác nhận Bluetooth".
- Firmware ESP32 **không sửa**.

## Không làm
Ngưỡng RSSI (chưa đo); app iPhone; deep link khi quét QR bằng camera ngoài app.

## Rủi ro / chưa kiểm chứng
- `mobile_scanner` trên web cần HTTPS khi mở từ điện thoại; chưa thử trong dự án.
- Vẫn có thể nhắn **cả hai** mã cho người ngoài trong 30–60 giây; khó hơn nhiều so với một mã, khuôn mặt + GPS vẫn chặn điểm danh hộ / ở nhà.
