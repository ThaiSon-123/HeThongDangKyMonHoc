# Kế hoạch gộp "Điểm danh" và "Tự điểm danh" thành một

> Trạng thái (14/11/2026): **đã gộp xong và hoàn thiện các phần phụ** (chip trên danh sách buổi, huy hiệu ở trang chủ SV, trạng thái khuôn mặt, số mẫu chờ duyệt). `flutter test` 311 xanh, `flutter analyze` sạch, `pytest apps/attendance` xanh.
> **Chưa làm:** chạy tay trên web và Android.
> Khác bản nháp: nút bulk có hai nhãn theo chế độ ("Tất cả có mặt" khi không có phiên, "Tất cả chưa điểm danh → Có mặt" khi phiên mở).
> Liên quan: `docs/ke-hoach-diem-danh-khuon-mat-gps.md` (KH), `docs/checklist_diemdanh.md`.

---

## 1. Vấn đề hiện tại

| Điểm | Thực trạng |
|---|---|
| Dữ liệu | **Đã dùng chung.** Cả hai ghi vào `Attendance` (mỗi SV mỗi buổi một dòng) và `AttendanceSession`. |
| Giao diện giảng viên | **Hai màn riêng:** `/teacher/attendance` (điểm danh tay + yêu cầu sửa) và `/teacher/self-attendance` (mở phiên, theo dõi, duyệt đáng ngờ). Cả hai đều bắt chọn lớp, rồi chọn buổi. |
| Giao diện sinh viên | **Hai màn riêng:** `/student/attendance` (lịch sử) và `/student/checkin` (luồng camera + GPS). |
| Cờ "đáng ngờ" | Chỉ hiện ở màn tự điểm danh. Màn điểm danh tay không biết đến `dang_ngo`. |
| Điện thoại | Không có menu bên, chỉ có thanh tab dưới. Mục "Tự điểm danh" không nằm trong tab nào. |
| Duyệt yêu cầu sửa | `xu_ly_yeu_cau` đổi trạng thái nhưng **không đặt `nguoi_quyet`**, nên phiên tự điểm danh đang mở vẫn có thể ghi đè kết quả giảng viên vừa duyệt. |

## 2. Mục tiêu và không phải mục tiêu

**Mục tiêu**
- Giảng viên chỉ có **một** chỗ để điểm danh một buổi: chọn lớp, chọn buổi, thấy tất cả (tự điểm danh, điểm danh tay, cờ đáng ngờ, yêu cầu sửa).
- Sinh viên có **một** mục "Điểm danh": xem lịch sử, và bấm điểm danh ngay khi có phiên đang mở.
- Trên điện thoại không còn chức năng "mồ côi" ngoài thanh điều hướng.

**Không làm (giữ nguyên)**
- Các endpoint backend và quy tắc nghiệp vụ. Tự điểm danh chỉ mở cho buổi hôm nay; điểm danh tay sửa được trong N ngày. Hai bộ quy tắc khác nhau, gộp lại dễ sinh lỗi.
- Luồng sinh viên điểm danh (thử thách, mã phòng, GPS, chụp ảnh): vẫn là một luồng nhiều bước riêng, chỉ đổi **lối vào**.
- Đăng ký / duyệt khuôn mặt: theo **sinh viên**, không theo **buổi**, nên không gộp vào màn điểm danh.

## 3. Thiết kế giao diện giảng viên

### 3.1 Cấu trúc màn "Điểm danh" (route `/teacher/attendance`)

Giữ khung của `TeacherAttendanceScreen` (chọn học kỳ → chọn lớp → hai tab **Các buổi** / **Yêu cầu sửa**). Khi bấm vào một buổi, panel mở ngay dưới buổi đó gồm 3 khối:

```
┌ Buổi: Thứ Sáu 14/11 · Sáng, tiết 1–3 ─────────────────────┐
│ [A] Khối Tự điểm danh                                       │
│     • Chưa mở:  [Mở tự điểm danh]  (form: thời hạn, r₀, QR) │
│     • Đang mở:  ● còn 07:32 · Có mặt 28 · Đáng ngờ 2 · Chưa 5│
│                 [Đóng phiên]   (banner "tâm lệch" nếu có)   │
│     • Đã đóng:  Đã đóng · [Mở lại]                          │
├────────────────────────────────────────────────────────────┤
│ [B] Danh sách sinh viên (dùng chung)                        │
│     Lọc: Tất cả | Có mặt | Đáng ngờ | Chưa điểm danh       │
│     Nguyễn A · SV001 · Vắng KP 1/15      [Có mặt]           │
│     Trần B   · SV002 · ĐÁNG NGỜ · Lệch vị trí   [Xem lượt]  │
│     Lê C     · SV003 · Chưa có mẫu mặt   [Có mặt|Vắng|Phép] │
│     [Tất cả chưa có mặt → Có mặt]                           │
├────────────────────────────────────────────────────────────┤
│ [C] Lưu điểm danh  (chỉ khi KHÔNG có phiên đang mở)         │
└────────────────────────────────────────────────────────────┘
```

- **Khối A** chỉ hiện khi buổi là **hôm nay** và lớp `DANG_HOC` (đúng điều kiện backend). Buổi khác: nếu buổi từng mở phiên thì hiện tóm tắt chỉ-đọc ("Đã tự điểm danh: 25 có mặt, 1 đáng ngờ"), nếu chưa thì ẩn hẳn khối A.
- **Khối B** là danh sách hiện có của điểm danh tay, **thêm**: chip "Đáng ngờ", cờ (`coText`), "Chưa có mẫu mặt", số lượt, nút "Xem lượt" mở `_ChiTietSv` (lượt, điểm, ảnh bằng chứng, duyệt / từ chối). Thay hai nút bulk hiện có ("Tất cả có mặt" và "Tất cả chưa điểm danh → Có mặt") bằng **một** nút.
- **Danh sách buổi**: thêm chip nhỏ trên mỗi buổi, ví dụ "Phiên đang mở" hoặc "2 đáng ngờ", để giảng viên không phải mở từng buổi mới biết.

### 3.2 Xung đột cần giải quyết: lưu cả lớp và cập nhật thời gian thực

Hai màn hiện có hai cách ghi khác nhau, và chúng **va chạm** khi gộp:

| | Điểm danh tay (`_Roster`) | Tự điểm danh (`_Phien`) |
|---|---|---|
| Đọc | `GET records/` một lần, giữ lựa chọn trong bộ nhớ | `GET tu-diem-danh/` làm mới mỗi 4 giây |
| Ghi | `PUT records/` **cả lớp**, đặt `nguoi_quyet` cho **mọi** SV | `PATCH tu-diem-danh/` từng SV hoặc nhóm |

Nếu giảng viên đang chọn dở rồi bấm "Lưu cả lớp" trong lúc sinh viên vẫn điểm danh, lần lưu sẽ **ghi đè kết quả mới của sinh viên** bằng dữ liệu cũ và khóa mọi SV bằng `nguoi_quyet`.

**Đề xuất (phương án A):**
- Khi **phiên đang mở**: mỗi lần giảng viên bấm một trạng thái là **lưu ngay cho riêng SV đó** (dùng `PATCH tu-diem-danh/`, đã có sẵn). Ẩn khối C (không có nút "Lưu cả lớp"). Danh sách làm mới mỗi 4 giây như hiện nay.
- Khi **không có phiên đang mở** (chưa mở, đã đóng, buổi cũ): giữ đúng hành vi cũ, chọn rồi **Lưu điểm danh** cả lớp (`PUT records/`).
- Ghi chú rõ trên giao diện: "Đang có phiên tự điểm danh, mỗi thay đổi được lưu ngay."
- **Đủ 4 lựa chọn như màn cũ** (Có mặt, Đi trễ, Vắng có phép, Vắng không phép): `PATCH tu-diem-danh/` được bổ sung tham số `di_tre` (xem mục 6). Giảng viên chỉnh lại một sinh viên bao nhiêu lần cũng được.
- **Đơn xin sửa:** tab "Yêu cầu sửa" giữ nguyên ở cấp lớp, vẫn duyệt / từ chối được khi phiên đang mở. Dòng sinh viên có đơn chờ duyệt hiện chip **"Có đơn chờ duyệt"**, bấm chuyển sang tab Yêu cầu sửa.

Phương án thay thế (B): luôn lưu ngay từng SV, bỏ hẳn nút lưu cả lớp. Gọn hơn nhưng **thay đổi hành vi điểm danh tay quen thuộc** và backend `quyet_tay` hiện **không kiểm tra hạn sửa** (`kiem_tra_con_han`) hay trạng thái lớp như `luu_diem_danh`, nên phải bổ sung kiểm tra ở backend. Không chọn B trừ khi bạn muốn.

### 3.3 Nguồn dữ liệu

Gộp **phía client**, không đổi API: khi mở một buổi, lấy `GET records/` (có `ty_le_vang`, `canh_bao_vang`, `co_the_diem_danh`) và, nếu buổi có phiên, `GET tu-diem-danh/` (có `dang_ngo`, `luot`, `co_mau_mat`, `gv_da_quyet`). Ghép theo `sinh_vien`. Chỉ làm mới `tu-diem-danh/` mỗi 4 giây khi phiên đang mở.

Cần kiểm tra trước khi code: `GET tu-diem-danh/` có trả đúng cho buổi **quá khứ** từng mở phiên không (để hiện tóm tắt chỉ-đọc).

### 3.4 Tổ chức code

- `teacher_attendance_screen.dart` (784 dòng) giữ vai trò khung và tab Yêu cầu sửa.
- Tách phần tự điểm danh của `gv_tu_diem_danh_screen.dart` (703 dòng) thành widget dùng lại được, ví dụ `tu_diem_danh/gv_phien_panel.dart`: khối A, `_MoPhien`, `_ChiTietSv`, `_AnhBangChung`, `_chonPhut`. `_Roster` nhúng widget này.
- Xóa `GvTuDiemDanhScreen` sau khi chuyển hết sang panel.
- Dùng chung nút "đánh có mặt cho tất cả chưa có mặt" thay vì hai nút.

## 4. Thiết kế giao diện sinh viên

- **"Điểm danh"** (`/student/attendance`): đầu trang thêm thẻ **"Đang có phiên tự điểm danh"** cho mỗi phiên đang mở của các lớp đã đăng ký (dùng `GET open-sessions/`, đã có). Bấm thẻ vào luồng điểm danh. Không có phiên thì ẩn thẻ.
- Dòng liên kết **"Khuôn mặt điểm danh: chưa đăng ký / chờ duyệt / đã duyệt"** dẫn tới `/student/face`.
- **Luồng điểm danh** (`SvTuDiemDanhScreen`) giữ nguyên, đổi cách vào: từ thẻ ở trên. Giữ route `/student/checkin` để các liên kết cũ và test không vỡ, nhưng **bỏ khỏi menu**.
- Trang chủ sinh viên: hiện nút tắt "Điểm danh" như cũ; có thể thêm huy hiệu khi có phiên đang mở (làm sau).

## 5. Điều hướng

| Việc | Thay đổi |
|---|---|
| Menu bên SV | Bỏ mục "Tự điểm danh" (giữ route, không hiện) |
| Menu bên GV | Bỏ mục "Tự điểm danh"; mục "Duyệt khuôn mặt" giữ |
| Route `/teacher/self-attendance` | Chuyển hướng sang `/teacher/attendance` |
| Nút tắt thêm hôm qua trên trang chủ SV và thẻ lớp GV | **Gỡ** (không còn cần vì đã gộp) |
| "Duyệt khuôn mặt" của GV trên điện thoại | Thêm nút trong màn Điểm danh, hiện số mẫu chờ duyệt |
| PĐT (`/pdt/faces`) | Không đổi |

## 6. Thay đổi backend (nhỏ)

1. **`xu_ly_yeu_cau`** (`services.py`): khi duyệt, đặt `nguoi_quyet = gv` và `dang_ngo = False`. Đóng lỗ hổng "phiên mở có thể ghi đè kết quả vừa duyệt". Kèm test.
2. **`PATCH tu-diem-danh/`** (`views_tu_diem_danh.py`, `quyet_tay`): nhận thêm `di_tre` (bool, mặc định `false`), chỉ có nghĩa khi `trang_thai = CO_MAT`. Hiện `quyet_tay` không đặt `di_tre` cho trạng thái có mặt nên giảng viên không đánh được "Đi trễ" khi phiên đang mở. Kèm test.
3. **Chip "Có đơn chờ duyệt" trên dòng sinh viên:** dữ liệu đơn đã được tải sẵn ở tab Yêu cầu sửa (`_LopData.requests`), ghép theo sinh viên và buổi ở client, không cần API mới.
4. *(Tùy chọn)* Thêm vào danh sách buổi (`/attendance/sessions/`) các trường `dang_mo` và `so_dang_ngo` để vẽ chip trên mỗi buổi mà không phải gọi từng buổi. Nếu bỏ, danh sách buổi chỉ có chip sau khi mở buổi.

Không đổi mô hình dữ liệu, không cần migration.

## 7. Kiểm thử

- `test/attendance_test.dart` (599 dòng) và `test/tu_diem_danh_test.dart` (nhóm "GV — tự điểm danh", 5 test) sẽ phải chỉnh lại theo màn mới. Giữ **mọi hành vi đang được kiểm**: mở phiên gửi đủ tham số, đếm và cờ, duyệt lượt đáng ngờ → `POST quyet`, điểm danh tay sinh viên chưa có mẫu mặt, mở lại phiên, lưu cả lớp, duyệt / từ chối yêu cầu sửa.
- Test mới: khi phiên đang mở không có nút "Lưu cả lớp" và mỗi lần bấm gửi `PATCH`; khi không có phiên thì "Lưu cả lớp" còn như cũ; buổi không phải hôm nay không có khối A; thẻ "đang có phiên" của sinh viên hiện / ẩn đúng.
- Backend: test `xu_ly_yeu_cau` đặt `nguoi_quyet` và lượt tự điểm danh sau đó **không ghi đè**.
- Backend: test `PATCH` với `di_tre = true` lưu "Đi trễ"; `di_tre` bị bỏ qua khi trạng thái không phải có mặt.
- Flutter: dòng sinh viên có đơn chờ duyệt hiện chip; bấm chip chuyển sang tab Yêu cầu sửa.
- `flutter analyze` sạch, toàn bộ `flutter test` xanh; chạy tay bản web với backend Docker.

## 8. Các bước thực hiện đề xuất

| # | Bước | Kiểm tra |
|---|---|---|
| 1 | Backend: `xu_ly_yeu_cau` đặt `nguoi_quyet`; `PATCH tu-diem-danh/` nhận `di_tre` + test | `pytest apps/attendance` xanh |
| 2 | Tách widget phiên từ `gv_tu_diem_danh_screen.dart` sang `gv_phien_panel.dart`, màn cũ vẫn chạy | Test tự điểm danh GV hiện có vẫn xanh |
| 3 | Nhúng panel vào `_Roster` của `TeacherAttendanceScreen`; danh sách dùng chung; phương án A | Test mới ở mục 7 |
| 4 | Chip trạng thái trên danh sách buổi; nút Duyệt khuôn mặt cho GV | Test + xem tay |
| 5 | Phía sinh viên: thẻ phiên đang mở + liên kết khuôn mặt (sau khi đọc `student_attendance_screen.dart`) | Test mới |
| 6 | Điều hướng: bỏ mục menu, chuyển hướng route, gỡ nút tắt đã thêm | `flutter analyze`, `flutter test` |
| 7 | Xóa `GvTuDiemDanhScreen` và test cũ, cập nhật `checklist_diemdanh.md` | Toàn bộ test xanh |

Công sức: vừa phải (khoảng 1.500 dòng giao diện được sắp xếp lại, phần lớn là di chuyển). Rủi ro chính ở bước 3 (xung đột lưu), nên làm và kiểm kỹ riêng.

## 9. Câu hỏi cần bạn quyết định

1. ~~Cách lưu khi phiên đang mở~~ → **đã chọn phương án A** (lưu ngay từng SV, ẩn nút lưu cả lớp), kèm `di_tre` ở `PATCH` và chip "Có đơn chờ duyệt".
2. **Buổi quá khứ từng tự điểm danh:** có hiện tóm tắt chỉ-đọc và xem lại lượt / ảnh bằng chứng không, hay ẩn hẳn? Đề xuất hiện chỉ-đọc.
3. **Chip trên danh sách buổi:** có làm thay đổi backend (mục 6.2) để có chip ngay, hay để sau?
4. **Gỡ hai nút tắt "Tự điểm danh"** mình đã thêm vào trang chủ SV và thẻ lớp GV khi gộp xong: đồng ý không?
5. **Phạm vi lần này:** làm cả giảng viên và sinh viên, hay giảng viên trước?
