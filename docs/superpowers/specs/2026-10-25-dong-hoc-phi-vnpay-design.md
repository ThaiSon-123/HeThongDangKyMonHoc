# Đóng học phí một lần / chia 3 đợt + quét QR VNPay sandbox

Ngày: 2026-10-25 · Trạng thái: chờ duyệt

## 1. Mục tiêu

Sinh viên (SV) đóng học phí học kỳ theo một trong hai hình thức, **đổi được bất cứ lúc nào**:

- `MOT_LAN`: đóng một lần toàn bộ.
- `CHIA_DOT`: chia 3 đợt theo cấu hình của kế toán (KT) cho từng học kỳ (tỷ lệ % + hạn).

Thanh toán qua **mã QR → cổng VNPay sandbox** (tiền giả). Thanh toán thành công thì học phí tự cập nhật,
KT không phải bấm xác nhận. KT vẫn thu tiền mặt / hoàn tiền như hiện tại.

Không làm: tiền thật, hoàn tiền qua VNPay, đối soát hàng ngày (QueryDR/Refund), chia số đợt khác 3.

## 2. Giả định

- Chưa có key VNPay: code + test dùng key giả; key thật nạp bằng biến môi trường (không commit).
- Đảo quyết định "không cổng thanh toán" ở `plan.md` mục 1; sẽ cập nhật `plan.md` và `chuc_nang.md`.
- Giao thức VNPay 2.1.0 đã đối chiếu ngày 2026-10-25 với
  https://sandbox.vnpayment.vn/apis/docs/thanh-toan-pay/pay.html và
  https://sandbox.vnpayment.vn/apis/vnpay-demo/. Phần chưa kiểm chứng còn lại ở mục 9.

## 3. Dữ liệu (`apps/tuition/models.py`)

Giữ nguyên tắc dự án: **không lưu** `con_no`; lịch đợt là giá trị dẫn xuất.

| Model / trường | Mô tả |
|---|---|
| `TuitionInstallment` | `hoc_ky` FK, `thu_tu` (1..3), `ty_le` Decimal(5,2) > 0, `han_dong` Date. `UNIQUE(hoc_ky, thu_tu)`. Một học kỳ chỉ hợp lệ khi có đủ 3 đợt, Σ`ty_le` = 100, `han_dong` tăng dần (kiểm ở serializer, vì ràng buộc cấp DB không biểu diễn được). |
| `Tuition.hinh_thuc` | `MOT_LAN` (mặc định) / `CHIA_DOT`. |
| `OnlineTransaction` | `txn_ref` UUID unique (gửi VNPay dạng `uuid.hex`, 32 ký tự chữ số, đúng kiểu Alphanumeric[1,100] của `vnp_TxnRef`), `tuition` FK, `so_tien`, `trang_thai` ∈ {`CHO`, `THANH_CONG`, `THAT_BAI`, `LOI`}, `vnp_transaction_no`, `tao_luc`, `ket_thuc_luc`. Dùng để đối chiếu số tiền khi VNPay gọi lại. |
| `PhuongThuc.VNPAY` | Thêm lựa chọn; cần migration cho `Payment.phuong_thuc`. |

`Payment.nguoi_thu` là bắt buộc → với giao dịch VNPay lấy chính SV làm người thu. `Payment.request_id` = `txn_ref`,
nên `ghi_thanh_toan` vốn idempotent theo `request_id` cho ta chống ghi trùng miễn phí.

### Lịch đợt (dẫn xuất, `services.lich_dot(tuition, ...)`)

Chỉ có nghĩa khi `hinh_thuc = CHIA_DOT` và học kỳ có cấu hình đủ 3 đợt:

- `luy_ke_n = round(phai_nop × Σ ty_le[1..n] / 100)`; đợt 3 luôn = `phai_nop` (tránh lệch làm tròn).
- Số phải nộp của đợt n = `luy_ke_n − luy_ke_(n-1)`.
- Đợt n **đã đóng** khi `thuc_thu ≥ luy_ke_n` ("tiền chảy từ đợt 1 xuống").
- `dot_tiep_theo` = đợt đầu tiên chưa đóng; số cần đóng cho nó = `luy_ke_n − thuc_thu`.
- Quá hạn: có đợt `n` với `han_dong < hôm nay` và `thuc_thu < luy_ke_n`.
  Với `MOT_LAN` giữ nguyên hạn `TuitionConfig.han_dong`.

Vì không gắn `Payment` vào đợt cụ thể, đổi hình thức giữa chừng không sinh dữ liệu mồ côi: chỉ đổi cách đọc.

## 4. API

| Method | Đường dẫn | Quyền | Ghi chú |
|---|---|---|---|
| GET / PUT | `/api/tuition/installments/?hoc_ky=` | KT | PUT thay cả 3 đợt trong một transaction; ghi audit. |
| PATCH | `/api/tuition/my/plan/` | SV | Body `{hinh_thuc}`. `CHIA_DOT` bị từ chối nếu học kỳ chưa cấu hình đợt. |
| POST | `/api/tuition/my/pay/` | SV | Body `{muc: "DOT_TIEP" \| "TOAN_BO" \| "TUY_Y", so_tien?}`. Số tiền phải `0 < x ≤ con_no`. Tạo `OnlineTransaction` `CHO`, trả `{payment_url, txn_ref, so_tien}`. |
| GET | `/api/tuition/my/pay/{txn_ref}/` | SV | Trạng thái giao dịch (client poll để tự cập nhật sau khi quét). |
| GET | `/api/tuition/vnpay/return/` | công khai | Trình duyệt được VNPay redirect về. Xác thực + ghi `Payment`, rồi redirect tới trang kết quả của app. |
| GET | `/api/tuition/vnpay/ipn/` | công khai | VNPay gọi server-to-server; trả JSON `{RspCode, Message}`. |

`GET /api/tuition/my/` bổ sung: `hinh_thuc`, `cac_dot` (mỗi đợt: `thu_tu`, `han_dong`, `phai_nop`, `luy_ke`, `da_dong`),
`dot_tiep_theo`. Dòng KT (`TuitionRowSerializer`) bổ sung `hinh_thuc`; `qua_han` tính theo mục 3.

### Xử lý callback (dùng chung cho return + IPN: `services.xac_nhan_vnpay(params)`)

1. Kiểm `vnp_SecureHash` (HMAC-SHA512, so sánh hằng thời gian). Sai → từ chối, không ghi gì (IPN: `97`).
2. Tìm `OnlineTransaction` theo `vnp_TxnRef`. Không có → IPN `01`.
3. `vnp_Amount / 100` ≠ `so_tien` → IPN `04`, giữ nguyên trạng thái.
4. Đã `THANH_CONG` → trả kết quả cũ, không ghi lại (IPN `02`).
5. `vnp_ResponseCode == "00"` **và** `vnp_TransactionStatus == "00"` (chặt hơn mẫu của VNPay, vốn dùng `||`) → `ghi_thanh_toan(sv, tuition, THU, so_tien, VNPAY, request_id=txn_ref)`,
   đặt `THANH_CONG`, ghi audit. Ngược lại → `THAT_BAI`.
6. Nếu `ghi_thanh_toan` từ chối vì `con_no` đã giảm trong lúc chờ (ví dụ KT thu tiền mặt song song) → đặt `LOI`,
   ghi audit để KT xử lý hoàn tiền thủ công. Không tự hoàn.

**Lệch có chủ đích so với khuyến nghị của VNPay.** Tài liệu VNPay chỉ cho phép IPN cập nhật kết quả, còn return URL
chỉ kiểm checksum và hiển thị. Nhưng IPN URL phải được đăng ký riêng với VNPay và **bắt buộc SSL**, nên trên máy
dev/demo gần như không nhận được IPN. Vì vậy return URL cũng gọi `xac_nhan_vnpay`. Rủi ro đã chặn bằng chữ ký,
đối chiếu số tiền với `OnlineTransaction` và idempotent theo `txn_ref`, nên chạy cả hai đường vẫn chỉ ghi một `Payment`.
Khi triển khai thật có SSL và đã đăng ký IPN, nên bỏ nhánh ghi ở return URL.

Mã trả IPN: `00` cập nhật xong, `02` đã xác nhận trước đó (VNPay dừng); `01`, `04`, `97`, `99` thì VNPay retry
tối đa 10 lần, cách nhau 5 phút.

## 5. Tích hợp VNPay (`apps/tuition/vnpay.py`, một file nhỏ)

Cấu hình qua env (`config/settings/base.py`): `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`,
`VNPAY_URL` (mặc định `https://sandbox.vnpayment.vn/paymentv2/vpcpay.html`),
`VNPAY_RETURN_URL` (địa chỉ backend mà **điện thoại** truy cập được), `APP_RESULT_URL` (trang kết quả của app).
Thêm các khóa vào `backend/.env.example`. Thiếu `TMN_CODE`/`HASH_SECRET` → `POST /my/pay/` trả `400` rõ ràng,
màn SV hiện cảnh báo "chưa cấu hình".

Tham số tạo yêu cầu: `vnp_Version=2.1.0`, `vnp_Command=pay`, `vnp_TmnCode`, `vnp_Amount=so_tien×100`,
`vnp_CreateDate` (yyyyMMddHHmmss, giờ VN), `vnp_CurrCode=VND`, `vnp_IpAddr`, `vnp_Locale=vn`,
`vnp_OrderInfo="HOCPHI <ma_sv> HK<id>"` (không dấu), `vnp_OrderType=other`, `vnp_ReturnUrl`, `vnp_TxnRef=<uuid.hex>`,
`vnp_ExpireDate` (bắt buộc, +15 phút). Không gửi `vnp_BankCode` để người dùng tự chọn phương thức trên trang VNPay
(gửi `VNPAYQR` sẽ ép vào thẳng mã QR, xem mục 9).
Chữ ký: sắp tăng dần theo tên tham số, nối `key=urllib.parse.quote_plus(value)` bằng `&` (tương đương `urlencode` của PHP trong tài liệu),
HMAC-SHA512 với `HASH_SECRET`, hex thường. Khi xác thực loại `vnp_SecureHash` ra khỏi dữ liệu ký.
Tài liệu yêu cầu `vnp_IpAddr` là IP khách; lấy từ `REMOTE_ADDR`/`X-Forwarded-For`.

## 6. Flutter

- `student_tuition_screen.dart` (`StudentPayScreen`): thay khối QR chuyển khoản giả bằng:
  chọn hình thức (một lần / 3 đợt, đổi được), bảng 3 đợt (số tiền, hạn, trạng thái), chọn mức thanh toán
  (đợt tới / toàn bộ nợ / số tiền tùy ý ≤ nợ), nút **Thanh toán VNPay** (mở `payment_url` ở tab mới)
  và **QR của `payment_url`** (`qr_flutter` đã có) để quét bằng điện thoại.
- Sau khi tạo giao dịch, màn poll `GET /my/pay/{txn_ref}/` mỗi 3 giây tới khi hết `CHO` rồi tải lại `tuition/my`
  và báo kết quả. Cần thêm `url_launcher` (Web mở tab mới); chưa có trong `pubspec.yaml`.
- `tuition_config_screen.dart`: thêm form 3 đợt cho học kỳ đang chọn (tỷ lệ, hạn), kiểm tổng = 100% phía client trước khi PUT.
- Trang kết quả `/student/tuition/pay-result?status=&txn=` cho redirect từ return URL.
- Giữ giao diện theo `design.md` (Material 3) và các widget dùng chung hiện có (`_Card`, `AlertBanner`, `LabeledField`).

## 7. Kiểm thử

Backend (`apps/tuition/tests/`):
- `lich_dot`: chia 40/30/30, làm tròn đợt 3, `đã đóng` theo `thuc_thu`, đổi hình thức giữa chừng, quá hạn theo đợt.
- Cấu hình đợt: Σ ≠ 100, thiếu đợt, hạn không tăng dần → `400`.
- Callback: chữ ký sai bị từ chối; số tiền lệch bị từ chối; gọi return + IPN hai lần chỉ ra một `Payment`;
  `ResponseCode ≠ 00` → `THAT_BAI` không ghi `Payment`; `con_no` giảm giữa chừng → `LOI`.
- Phân quyền: SV chỉ tạo/đọc giao dịch của mình; KT không gọi `/my/pay/`.
- Chữ ký: một test vector cố định với key giả để khóa thuật toán ký.

Flutter: một widget test cho `StudentPayScreen` (hiện 3 đợt, đổi hình thức, QR xuất hiện khi chọn mức hợp lệ).

## 8. Tài liệu cần cập nhật

`plan.md` (mục 1 bảng quyết định, BR-26, model Payment/Tuition, API), `chuc_nang.md` (SV-12, API), `backend/.env.example`.

## 9. Rủi ro và việc cần kiểm chứng khi có key

- **Quét VNPAY-QR trên sandbox: đã kiểm tra một phần (2026-10-25).** Gửi thử đơn 10.000đ trên form demo công khai với
  `vnp_BankCode=VNPAYQR` thì sandbox hiện trang "Quét mã qua App Ngân hàng/Ví điện tử" có mã QR thật và đếm ngược 15 phút.
  Trang này liệt kê các app hỗ trợ quét: **Gateway Demo App, PGB Bank App, Vikki Bank App, Ví Appota**. Chưa xác nhận được
  bằng điện thoại thật là app nào cài được và quét xong có thanh toán được không. Nên có hai đường demo:
  1. **QR của ta** (chứa `payment_url`, không gửi `vnp_BankCode`) → điện thoại mở trang VNPay → trả bằng thẻ test NCB
     `9704198526191432198`, tên `NGUYEN VAN A`, phát hành `07/15`, OTP `123456`. Đường này không cần app đặc biệt.
  2. **`vnp_BankCode=VNPAYQR`** → trang VNPay hiện QR riêng, quét bằng một trong các app trên. Thêm làm nút phụ
     ("Thanh toán bằng VNPAY-QR") nếu thử được bằng điện thoại; không đổi thiết kế.
- Điện thoại phải gọi được `VNPAY_RETURN_URL` (cùng WiFi hoặc ngrok); nếu không, thanh toán xong nhưng bước redirect về backend lỗi
  trên điện thoại, và vì IPN cần SSL + đăng ký nên học phí sẽ không cập nhật. Mặc định mình cấu hình `VNPAY_RETURN_URL` bằng IP LAN của máy chạy backend.
- Chưa đăng ký sandbox (`http://sandbox.vnpayment.vn/devreg/`), nên chưa chạy thử đầu cuối với VNPay thật. Chữ ký được khóa bằng
  test vector tự tính; cần một lần chạy thật để chắc khớp.
