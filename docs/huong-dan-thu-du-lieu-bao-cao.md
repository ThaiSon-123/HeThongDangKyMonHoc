# Hướng dẫn chi tiết: thu dữ liệu, train, đánh giá và viết báo cáo Học máy

**Đề tài:** Xây dựng hệ thống điểm danh sinh viên bằng nhận diện khuôn mặt và định vị GPS trong khuôn viên trường.

**Phần học máy của báo cáo:** train và đánh giá **mô hình nhận diện khuôn mặt** trên dữ liệu của 5 người, có lớp "người lạ".

---

## Mục lục

0. [Tổng quan](#0-tổng-quan)
1. [Chuẩn bị](#1-chuẩn-bị)
2. [Quay video khuôn mặt](#2-quay-video-khuôn-mặt)
3. [Quay video giả mạo (nên có)](#3-quay-video-giả-mạo-nên-có)
4. [Chép video vào đúng thư mục](#4-chép-video-vào-đúng-thư-mục)
5. [Tải LFW làm lớp "người lạ"](#5-tải-lfw-làm-lớp-người-lạ)
6. [Cài môi trường và chạy notebook](#6-cài-môi-trường-và-chạy-notebook)
7. [Các file kết quả notebook xuất ra](#7-các-file-kết-quả-notebook-xuất-ra)
8. [Viết báo cáo cho đủ yêu cầu của mẫu](#8-viết-báo-cáo-cho-đủ-yêu-cầu-của-mẫu)
9. [Tài liệu tham khảo](#9-tài-liệu-tham-khảo)
10. [Lịch làm việc và bảng đánh dấu](#10-lịch-làm-việc-và-bảng-đánh-dấu)
11. [Quyền riêng tư và dọn dẹp](#11-quyền-riêng-tư-và-dọn-dẹp)

---

## 0. Tổng quan

### 0.1 Mô hình gồm 2 tầng

```
Video → cắt khung hình (2 khung/giây)
      → [Tầng 1 — có sẵn, KHÔNG train]  YuNet (tìm mặt) → căn chỉnh 112×112 → ArcFace → vector 512 chiều
      → [Tầng 2 — TRAIN]                SVM (so sánh với cosine, k-NN, MLP) → P1…P5 hoặc NGUOI_LA
```

Vì sao không train mạng CNN từ đầu: chỉ có 5 người, mạng sâu sẽ học thuộc ảnh. Dùng lại ArcFace đã học sẵn (học chuyển giao) và chỉ train bộ phân loại là cách đúng với lượng dữ liệu này.

### 0.2 Ba nguồn dữ liệu

| Nguồn | Vai trò | Ước lượng số ảnh |
|---|---|---|
| Video 5 người (P1–P5), 3 buổi | Các lớp cần nhận diện. Buổi 1–2 để train, buổi 3 để test | Khoảng 60–80 ảnh mỗi người mỗi buổi, tổng khoảng 1.000 ảnh |
| LFW (bộ công khai) | Lớp `NGUOI_LA`, dạy mô hình từ chối người ngoài lớp | Khoảng 400 ảnh của khoảng 150 người |
| Video giả mạo (tuỳ chọn) | Đánh giá MiniFASNetV2 chống ảnh và màn hình | Khoảng 30 ảnh mỗi kiểu mỗi người |

### 0.3 Ai làm gì

| Việc | Ai | Mục |
|---|---|---|
| Chuẩn bị, quay video, tải LFW, chép file | Bạn | 1–5 |
| Viết notebook, chạy thử bằng dữ liệu giả lập | Claude | — |
| Cài môi trường, chạy notebook với dữ liệu thật | Bạn | 6 |
| Viết báo cáo Word | Bạn | 8–9 |

---

## 1. Chuẩn bị

### 1.1 Người tham gia
- [ ] Chọn **5 người**, đặt mã **P1, P2, P3, P4, P5**.
- [ ] Ghi bảng **tên thật ↔ mã** vào một file riêng **ngoài repo** (ví dụ trong máy hoặc giấy). Báo cáo và notebook chỉ dùng mã.
- [ ] Cố gắng có cả nam và nữ, có người đeo kính. Mô hình được thử với nhiều kiểu mặt hơn, phần nhận xét Chương 4 có nhiều ý hơn.

### 1.2 Xin đồng ý
Gửi cho từng người (tin nhắn hoặc giấy ký) và lưu lại:

> Tôi, ____________, đồng ý cho bạn ____________ quay video khuôn mặt của tôi để train và đánh giá mô hình nhận diện khuôn mặt trong đồ án môn học tại Trường Đại học Thủ Dầu Một. Dữ liệu không công khai, không dùng vào mục đích khác, và được xoá sau khi đồ án được chấm. Tôi đồng ý / không đồng ý cho dùng ảnh khuôn mặt của mình làm hình minh hoạ trong báo cáo.

Người **không đồng ý dùng làm hình minh hoạ** thì vẫn dùng để train và test, chỉ không dán ảnh của họ vào báo cáo.

### 1.3 Thiết bị
| Thiết bị | Dùng để | Bắt buộc? |
|---|---|---|
| Điện thoại A | Quay buổi 1, 2 | Có |
| Điện thoại B (khác hãng) | Quay buổi 3 | Nên có. Không có thì dùng lại điện thoại A |
| Laptop hoặc điện thoại thứ ba | Hiển thị ảnh và video khi quay giả mạo | Nếu làm mục 3 |
| Ảnh in màu khổ A5 của từng người | Quay giả mạo | Nếu làm mục 3 |
| Đèn bàn hoặc đèn phòng điều chỉnh được | Tạo điều kiện tối, ngược sáng | Nên có |

### 1.4 Cài đặt camera trước khi quay
- [ ] Dùng **camera trước** (selfie).
- [ ] **Tắt chế độ làm đẹp, làm mịn da, bộ lọc** (beauty, AI beauty). Những chế độ này làm mặt khác thật.
- [ ] Độ phân giải **720p hoặc 1080p**, 30 khung/giây. Không cần 4K.
- [ ] Quay **dọc** (như lúc dùng app điểm danh).
- [ ] Để mặc định "lật ảnh gương" như máy đang có. Chỉ cần thống nhất giữa các buổi.

### 1.5 Sổ thu dữ liệu
Tạo file Excel `so_thu_du_lieu.xlsx` (lưu cạnh bảng tên thật, ngoài repo). Mỗi clip một dòng:

| Cột | Ví dụ |
|---|---|
| `nguoi` | P1 |
| `buoi` | buoi1 |
| `clip` | clip1 |
| `ngay` | 2026-11-25 |
| `gio` | 09:30 |
| `noi_quay` | Phòng học A1.203 |
| `anh_sang` | Đèn trần, đủ sáng |
| `phu_kien` | Không / kính / khẩu trang / mũ |
| `dien_thoai` | Samsung A54 |
| `ghi_chu` | Clip hơi rung đoạn cuối |

Sổ này là nguồn để viết phần **"phương pháp thu thập dữ liệu"** của báo cáo (thời gian, địa điểm, thiết bị, điều kiện).

---

## 2. Quay video khuôn mặt

### 2.1 Kịch bản cho mỗi clip (khoảng 25 giây)

Cầm điện thoại cách mặt **30–50 cm**, ngang tầm mắt, mặt chiếm khoảng 1/3 đến 1/2 khung hình.

| Giây | Động tác |
|---|---|
| 0–5 | Nhìn thẳng vào camera, giữ yên |
| 5–9 | Quay đầu **sang trái** từ từ (khoảng 30–45°), giữ 1 giây |
| 9–12 | Quay về giữa |
| 12–16 | Quay đầu **sang phải** từ từ, giữ 1 giây |
| 16–18 | Về giữa |
| 18–21 | **Ngước lên** nhẹ, rồi về giữa |
| 21–25 | **Cúi xuống** nhẹ, rồi về giữa. Có thể nói chuyện hoặc cười nhẹ (thay đổi nét mặt) |

Động tác **chậm và đều**. Quay nhanh thì khung hình bị nhoè và bị notebook loại bỏ.

### 2.2 Điều kiện của từng buổi

Mỗi người, mỗi buổi quay **2 clip**:

| Buổi | Vai trò | Clip 1 | Clip 2 | Điện thoại |
|---|---|---|---|---|
| **buoi1** | Train | Trong nhà, đủ sáng, không phụ kiện | Ngoài trời (bóng râm, không nắng gắt chiếu thẳng) | A |
| **buoi2** | Train | Trong nhà, **đèn tối hơn** (tắt bớt đèn) | **Ngược sáng** (lưng quay ra cửa sổ) **hoặc đeo kính** | A |
| **buoi3** | **Test** | Nơi khác hai buổi trước, đủ sáng | **Đeo khẩu trang hoặc mũ**, hoặc ánh sáng vàng | **B** (không có thì dùng A) |

Quy tắc:
- 3 buổi **khác ngày**. Không được thì ít nhất cách nhau vài giờ và đổi quần áo, đổi chỗ.
- **Buổi 3 quay sau cùng** và không cho mô hình "thấy" trước. Đây là dữ liệu kiểm thử độc lập.
- Mỗi khung hình chỉ có **1 khuôn mặt**. Không để người khác hay ảnh có mặt người (poster, màn hình) lọt vào phía sau.

### 2.3 Kiểm tra ngay sau khi quay
- [ ] Xem lại clip: mặt rõ, không bị che khuất cả clip, không bị nhoè quá nhiều.
- [ ] Độ dài từ 20 giây trở lên.
- [ ] Ghi dòng vào sổ thu dữ liệu.
- [ ] Clip hỏng thì **quay lại ngay**, đỡ phải hẹn lại người đó.

### 2.4 Lỗi thường gặp

| Lỗi | Hậu quả | Cách tránh |
|---|---|---|
| Đứng quá xa | Mặt nhỏ, YuNet không tìm thấy | Mặt chiếm từ 1/3 khung hình trở lên |
| Quay đầu nhanh | Khung nhoè bị loại, còn ít ảnh | Đếm chậm 1–2–3 khi quay |
| Nắng chiếu thẳng | Mặt cháy sáng | Đứng trong bóng râm |
| Bật làm đẹp | Mặt bị làm mịn, khác thật | Tắt trước khi quay |
| Có người phía sau | Lẫn mặt người khác | Quay ở chỗ vắng, phông nền trơn |
| Quay 3 buổi cùng lúc, cùng chỗ | Buổi 3 giống buổi 1, test ảo | Khác ngày, khác chỗ |

---

## 3. Quay video giả mạo (nên có)

Dùng để đánh giá mô hình chống giả mạo MiniFASNetV2 mà hệ thống đang dùng. Mỗi người quay **3 clip, mỗi clip khoảng 10 giây** bằng camera trước điện thoại A:

| File | Cách làm |
|---|---|
| `anh_in.mp4` | Cầm ảnh in màu của người đó trước camera, nghiêng nhẹ, đưa gần xa |
| `man_hinh.mp4` | Mở ảnh chân dung người đó trên laptop hoặc điện thoại khác (độ sáng tối đa), đưa trước camera |
| `video.mp4` | Phát một clip của người đó (ví dụ clip buổi 1) trên màn hình khác, quay lại |

Lưu ý: khung hình giả mạo **không có người thật** nào trong đó, chỉ có ảnh hoặc màn hình.

---

## 4. Chép video vào đúng thư mục

### 4.1 Cấu trúc

Thư mục `ml_report/` sẽ được tạo cùng notebook. Chép video theo đúng cấu trúc:

```
ml_report/du_lieu/video/
├── P1/
│   ├── buoi1/
│   │   ├── clip1.mp4
│   │   └── clip2.mp4
│   ├── buoi2/
│   │   ├── clip1.mp4
│   │   └── clip2.mp4
│   ├── buoi3/
│   │   ├── clip1.mp4
│   │   └── clip2.mp4
│   └── gia_mao/              (tuỳ chọn)
│       ├── anh_in.mp4
│       ├── man_hinh.mp4
│       └── video.mp4
├── P2/  …
├── P3/  …
├── P4/  …
└── P5/  …
```

Quy tắc:
- Tên thư mục **phải đúng chính xác**: `P1`…`P5`, `buoi1`, `buoi2`, `buoi3`, `gia_mao` (chữ thường, không dấu, không khoảng trắng).
- Tên file video đặt gì cũng được. Đuôi `.mp4`, `.mov` đều đọc được.
- Thư mục `ml_report/du_lieu/` đã bị chặn khỏi git, không lo đẩy video lên GitHub.

### 4.2 Kiểm tra đã chép đủ

Mở PowerShell tại thư mục repo, chạy lệnh đếm số video của từng người và từng buổi:

```powershell
Get-ChildItem ml_report\du_lieu\video -Recurse -File | Group-Object { $_.Directory.Parent.Name + '/' + $_.Directory.Name } | Select-Object Name, Count
```

Kết quả đúng: mỗi dòng `P1/buoi1`, `P1/buoi2`, `P1/buoi3`… có `Count` bằng **2**, và `P1/gia_mao` có 3 (nếu làm).

---

## 5. Tải LFW làm lớp "người lạ"

### 5.1 Tải và giải nén
1. Tìm "Labeled Faces in the Wild" trên trang của Đại học Massachusetts Amherst, hoặc bản trên Kaggle. Tải bản ảnh gốc (khoảng 170–230 MB, file `lfw.tgz` hoặc `.zip`).
2. Giải nén (file `.tgz` mở bằng 7-Zip). Bên trong là thư mục mỗi người một thư mục con:
   ```
   lfw/
   ├── Aaron_Eckhart/Aaron_Eckhart_0001.jpg
   ├── George_W_Bush/George_W_Bush_0001.jpg …
   └── …
   ```
3. Chép thành:
   ```
   ml_report/du_lieu/lfw/<Tên_người>/<ảnh>.jpg
   ```
   Nếu sau khi giải nén bị lồng hai lớp `lfw/lfw/…` thì bỏ bớt một lớp.

### 5.2 Notebook làm gì với LFW
- Chọn ngẫu nhiên (seed cố định) khoảng **150 người, mỗi người tối đa 3 ảnh**, được khoảng 400 ảnh.
- Chia **theo người**: 70% số người vào train, 30% vào test. Một người lạ không xuất hiện ở cả hai bên, để đo đúng khả năng từ chối người **chưa từng gặp**.

### 5.3 Ghi lại để trích dẫn
Huang G. B., Ramesh M., Berg T., Learned-Miller E. (2007), *Labeled Faces in the Wild: A Database for Studying Face Recognition in Unconstrained Environments*, Technical Report 07-49, University of Massachusetts, Amherst.

---

## 6. Cài môi trường và chạy notebook

### 6.1 Cài môi trường (một lần)

Cần Python 3.10 trở lên. Mở PowerShell:

```powershell
cd D:\HeThongDangKyMonHoc\ml_report
```

```powershell
python -m venv .venv
```

```powershell
.venv\Scripts\pip install -r requirements.txt
```

### 6.2 Kiểm tra mô hình ONNX
Notebook dùng lại mô hình của backend trong `backend/face_models/`. Cần có:
- [ ] `face_detection_yunet_2023mar.onnx`
- [ ] `w600k_r50.onnx`
- [ ] `MiniFASNetV2.onnx` (cho phần giả mạo)

Máy hiện đã có đủ 3 file. Thiếu thì tải lại theo `backend/face_models/README.md`.

### 6.3 Mở notebook
- **VS Code**: mở `ml_report/train_danh_gia_khuon_mat.ipynb` → góc phải trên bấm **Select Kernel** → chọn `.venv`.
- **Hoặc trình duyệt**:
  ```powershell
  .venv\Scripts\jupyter notebook
  ```

### 6.4 Chạy
1. Ô **Cấu hình** đầu notebook: đổi `DU_LIEU_GIA_LAP = True` thành `False`.
2. Bấm **Run All**.
3. Lần đầu mất khoảng **5–15 phút** (trích đặc trưng trên CPU). Các lần sau notebook dùng lại `dataset_mat.csv` đã lưu, chỉ mất vài giây. Muốn trích lại từ đầu thì xoá file đó.

### 6.5 Kiểm tra kết quả chạy
- [ ] Ô **"Thống kê ảnh"**: mỗi người, mỗi buổi có **từ 40 ảnh** trở lên. Thiếu thì xem lý do ở ô "Ảnh bị loại" và quay bổ sung.
- [ ] Ô **"Ảnh bị loại"**: tỉ lệ loại dưới khoảng 30%. Cao hơn nghĩa là video mờ hoặc mặt quá nhỏ.
- [ ] Không có ô nào báo lỗi đỏ.
- [ ] Thư mục `ml_report/ket_qua/` có đủ file ở mục 7.

### 6.6 Chụp màn hình cho báo cáo
Trong lúc chạy, chụp lại (dùng cho phần **ảnh chụp kết quả chạy chương trình kèm chú giải**):
- [ ] Cấu trúc thư mục dữ liệu.
- [ ] Ô cắt video đang chạy, thanh tiến độ.
- [ ] Vài dòng đầu `dataset_mat.csv`.
- [ ] Ô GridSearch in ra tham số tốt nhất.
- [ ] Bảng so sánh 4 mô hình.
- [ ] Ô dự đoán thử một ảnh test: ảnh + nhãn dự đoán + xác suất.

### 6.7 Lỗi thường gặp

| Thông báo | Nguyên nhân | Cách sửa |
|---|---|---|
| `No module named ...` | Chưa chọn kernel `.venv` hoặc chưa cài | Làm lại 6.1, chọn đúng kernel |
| `FileNotFoundError ... .onnx` | Thiếu mô hình | Làm 6.2 |
| "Không tìm thấy video" | Sai tên thư mục | Kiểm tra lại mục 4.1, chạy lệnh ở 4.2 |
| Một người có 0 ảnh ở một buổi | Video hỏng hoặc mặt quá nhỏ | Quay lại buổi đó |

---

## 7. Các file kết quả notebook xuất ra

Tất cả nằm trong `ml_report/ket_qua/`:

| File | Nội dung |
|---|---|
| `dataset_mat.csv` | **Dataset chính.** Mỗi dòng là một ảnh khuôn mặt (giải thích các cột ở mục 8.3) |
| `anh_bi_loai.csv` | Khung hình bị loại và lý do |
| `thong_ke.csv` | MIN, MAX, AVERAGE, COUNT, độ lệch chuẩn của từng cột số |
| `so_anh_moi_nguoi.png` | Biểu đồ cột: số ảnh của từng người theo buổi |
| `phan_bo_do_sang.png`, `phan_bo_do_net.png`, `phan_bo_goc_mat.png` | Histogram từng đặc điểm ảnh |
| `histogram_cosine.png` | Phân bố độ giống cosine của cặp cùng người và cặp khác người |
| `tsne.png` | Vector 512 chiều thu xuống 2 chiều, mỗi người một màu |
| `anh_can_chinh.png` | Ảnh trước và sau căn chỉnh 112×112 |
| `chia_du_lieu.csv` | Số ảnh mỗi lớp trong tập train và tập test |
| `gridsearch_svm.csv` | Kết quả thử các tham số SVM |
| `bang_so_sanh.csv` | Accuracy, Precision, Recall, F1, FAR, FRR, thời gian của 4 mô hình |
| `bao_cao_phan_loai_svm.csv` | Precision, Recall, F1 của từng người |
| `ma_tran_nham_lan_svm.png` | Ma trận nhầm lẫn 6×6 của SVM |
| `roc.png` | Đường ROC và AUC |
| `far_frr.png` | FAR và FRR theo ngưỡng τ, đánh dấu EER và ngưỡng đã chọn |
| `anh_doan_sai.png` | Các ảnh test bị đoán sai kèm nhãn thật và nhãn dự đoán |
| `chong_gia_mao.png`, `chong_gia_mao.csv` | Phân bố điểm "mặt thật", APCER, BPCER, ACER (nếu có video giả mạo) |
| `so_lieu_bao_cao.txt` | Tóm tắt mọi con số cần điền vào báo cáo |
| `svm.pkl` | Mô hình đã train |

---

## 8. Viết báo cáo cho đủ yêu cầu của mẫu

### 8.1 Thứ tự viết
1. Phần dữ liệu (đã có số liệu từ notebook).
2. Phần thiết kế mô hình.
3. Phần thực nghiệm và đánh giá.
4. Phần tổng quan (giới thiệu, nghiên cứu liên quan, độ đo).
5. Kết luận và hướng phát triển.
6. **Cuối cùng**: Tóm tắt, Mở đầu, Phần tự đánh giá, mục lục, danh mục hình, chữ viết tắt.

### 8.2 Giới thiệu đề tài và chức năng

Mẫu yêu cầu **liệt kê cụ thể tất cả chức năng**. Lấy từ app hiện có:
- Sinh viên: đăng ký khuôn mặt (có đồng ý), tự điểm danh bằng quét mặt real time theo thử thách (quay trái, quay phải…), kiểm tra GPS trong khuôn viên, xem lịch sử điểm danh.
- Giảng viên: mở và đóng phiên điểm danh, bật/tắt kiểm tra GPS và mã phòng (QR, Bluetooth ESP32), theo dõi danh sách, xem lượt đáng ngờ và ảnh bằng chứng, điểm danh thủ công.
- Phòng đào tạo: duyệt hoặc từ chối mẫu khuôn mặt, cấu hình đa giác khuôn viên.
- Bảo mật: chống giả mạo (MiniFASNet), mã hoá vector khuôn mặt và ảnh (AES-GCM), xoá ảnh đăng ký sau khi duyệt, nhật ký thao tác.

Nói rõ phạm vi phần học máy: **train và đánh giá bộ phân loại khuôn mặt**. Phần GPS là quy tắc hình học, không phải học máy.

### 8.3 Mô tả các trường dữ liệu (`dataset_mat.csv`)

Mẫu yêu cầu: bao nhiêu trường, kiểu dữ liệu, ý nghĩa từng trường, vì sao dùng. Viết mỗi trường một mục nhỏ:

| Trường | Kiểu | Ý nghĩa | Vì sao dùng |
|---|---|---|---|
| `nguoi` | Chuỗi (`P1`…`P5`, `NGUOI_LA`) | Nhãn: ảnh là của ai | Biến mục tiêu (y) của bài toán phân loại |
| `buoi` | Chuỗi (`buoi1`…`buoi3`, `lfw`) | Buổi quay | Chia train/test không rò rỉ; nhóm khi kiểm định chéo |
| `clip` | Chuỗi | Clip nguồn | Truy vết ảnh lỗi về video gốc |
| `file` | Chuỗi | Đường dẫn ảnh đã cắt | Hiện ảnh khi phân tích lỗi |
| `do_sang` | Số thực 0–255 | Độ sáng trung bình vùng mặt | Kiểm tra dữ liệu có đủ điều kiện sáng/tối; phân tích lỗi theo ánh sáng |
| `do_net` | Số thực ≥ 0 | Phương sai Laplacian (càng lớn càng nét) | Loại ảnh nhoè; phân tích lỗi |
| `goc_mat` | Số thực (âm: quay một bên, dương: bên kia) | Ước lượng góc quay ngang của đầu | Kiểm tra dữ liệu có đủ góc nghiêng |
| `rong_mat` | Số thực (pixel) | Chiều rộng khung mặt | Kiểm tra khoảng cách tới camera |
| `diem_that` | Số thực 0–1 | Điểm "mặt thật" của MiniFASNetV2 | Phần chống giả mạo |
| `e0` … `e511` | 512 số thực, `float32` | Vector đặc trưng ArcFace, chuẩn hoá L2 | **Đầu vào X của mô hình**. Viết chung một mục, không mô tả từng cột |

Phần **trực quan hoá**: mỗi trường số kèm một biểu đồ và bảng MIN/MAX/AVERAGE/COUNT (`thong_ke.csv`). Với vector đặc trưng, dùng `histogram_cosine.png` và `tsne.png`. Nhận xét từng hình 2–3 câu: ví dụ cụm người nào tách rõ, cặp khác người có cosine phần lớn dưới bao nhiêu.

### 8.4 Phương pháp thu thập dữ liệu

Mẫu yêu cầu: dữ liệu lấy ở đâu, có đáng tin cậy không, vì sao dùng bộ này. Viết theo các ý:
- **Nguồn 1, tự thu**: 5 người, 3 buổi, thời gian, địa điểm, thiết bị, điều kiện (lấy từ sổ thu dữ liệu), cách cắt khung, tiêu chí loại ảnh. Có giấy đồng ý.
- **Nguồn 2, LFW**: bộ công khai được dùng rộng rãi trong nghiên cứu nhận diện khuôn mặt, có báo cáo kỹ thuật gốc nên đáng tin cậy.
- **Vì sao chọn**: dữ liệu tự thu đúng với bối cảnh sử dụng thật (camera trước điện thoại, lớp học); LFW bổ sung "người lạ" mà 5 người không tự tạo được.
- **Vì sao không dùng bộ khác**: các bộ lớn như CASIA-WebFace hay MS-Celeb dùng để train mạng từ đầu, không cần vì đã dùng ArcFace học sẵn; nhiều bộ còn bị hạn chế giấy phép.

### 8.5 Chia tập huấn luyện và kiểm thử
- Train: buổi 1–2 của 5 người + 70% số danh tính LFW.
- Test: buổi 3 + 30% danh tính LFW còn lại.
- Lấy con số thật từ `chia_du_lieu.csv`.
- Giải thích vì sao **chia theo buổi và theo danh tính** chứ không dùng `train_test_split` ngẫu nhiên: khung hình liền nhau trong cùng video gần như giống hệt, chia ngẫu nhiên làm kết quả ảo.

### 8.6 Độ đo đánh giá (mỗi độ đo: công thức + ý nghĩa + vì sao dùng)

| Độ đo | Công thức | Vì sao dùng |
|---|---|---|
| Accuracy | (TP + TN) / (TP + TN + FP + FN) | Tổng quát |
| Precision | TP / (TP + FP) | Trong số ảnh đoán là P*i*, bao nhiêu đúng |
| Recall | TP / (TP + FN) | Ảnh thật của P*i*, bắt được bao nhiêu |
| F1 | 2 · P · R / (P + R) | Cân bằng P và R; dùng F1-macro vì các lớp không đều |
| FAR | Số lần chấp nhận sai / số lần thử của người không đúng | **Quan trọng nhất: chính là tỉ lệ điểm danh hộ lọt qua** |
| FRR | Số lần từ chối sai / số lần thử của chính chủ | Sinh viên thật bị bắt quét lại |
| EER | Giá trị tại đó FAR = FRR | So sánh mô hình bằng một con số |
| ROC, AUC | Đường TPR theo FPR khi đổi ngưỡng; diện tích dưới đường | Đánh giá không phụ thuộc một ngưỡng cụ thể |
| APCER, BPCER, ACER | Tỉ lệ ảnh giả bị nhận là thật; tỉ lệ người thật bị nhận là giả; trung bình hai tỉ lệ | Chuẩn ISO/IEC 30107-3 cho chống giả mạo |

### 8.7 Thiết kế mô hình
Gồm 3 phần:
- **Giới thiệu mô hình**: 2 tầng (ArcFace trích đặc trưng + SVM phân loại), vì sao dùng học chuyển giao.
- **Mô tả thuật toán**: từng bước kèm kiểu dữ liệu và kích thước:

| Bước | Dữ liệu | Kiểu, kích thước |
|---|---|---|
| Đọc khung hình | Ảnh BGR | `uint8`, H × W × 3 (cạnh dài ≤ 1280) |
| YuNet | Danh sách mặt | `float32`, N × 15 (x, y, w, h, 10 toạ độ điểm mốc, điểm tin cậy); giữ mặt lớn nhất, điểm ≥ 0,8 |
| Căn chỉnh | Ảnh mặt | `uint8`, 112 × 112 × 3 |
| Tiền xử lý | Tensor | `float32`, 1 × 3 × 112 × 112, RGB, (x − 127,5) / 127,5 |
| ArcFace | Vector đặc trưng | `float32`, 1 × 512, chuẩn hoá L2 |
| Tập dữ liệu | X, y, groups | X `float32` (n, 512); y chuỗi (n,); groups chuỗi (n,) |
| SVM | Xác suất các lớp | `float64`, (n, 6) |
| Quyết định | Nhãn | Lớp xác suất cao nhất; nếu < τ thì `NGUOI_LA` |

  Thêm công thức hàm mất mát ArcFace (lề góc *m* = 0,5, *s* = 64), bài toán tối ưu SVM lề mềm, kernel RBF, chiến lược một-đối-một, Platt scaling, GridSearchCV chia theo buổi với độ đo F1-macro. Mô tả ngắn 3 mô hình so sánh: cosine với ngưỡng 0,5 (như app), k-NN, MLP.
- **Điểm mạnh**: hiệu quả với ít dữ liệu và số chiều cao, đặc trưng ArcFace học từ khoảng 600.000 danh tính, chạy CPU, train vài giây, có từ chối người lạ, lề lớn chống học thuộc.

### 8.8 Thực nghiệm và đánh giá
- **Kết quả thực nghiệm**: dán ảnh chụp ở mục 6.6 và các hình ở mục 7, **mỗi hình có số hình và chú giải** (ví dụ "Hình 4.3 – Ma trận nhầm lẫn của SVM trên tập kiểm thử").
- **Đánh giá mô hình**, trả lời đủ 3 câu mẫu hỏi:
  - **Còn yếu ở điểm nào?** Xem `anh_doan_sai.png`: thường sai khi đeo khẩu trang, ngược sáng, quay quá nghiêng. Giả mạo bằng màn hình độ phân giải cao.
  - **Dữ liệu đã đủ chưa?** Chưa: chỉ 5 người, 3 buổi, ít thiết bị; FAR đo trên số cặp nhỏ nên độ tin cậy thống kê hạn chế.
  - **Cách cải thiện?** Thu thêm người và buổi; thêm ảnh khẩu trang; tăng cường dữ liệu (xoay, đổi sáng); thử thêm mô hình chống giả mạo thứ hai (MiniFASNetV1SE); dùng cosine 1–1 trong app thật để không phải train lại khi thêm sinh viên.

### 8.9 Kết luận và hướng phát triển
- **Kết luận**: đã thu bộ dữ liệu 5 người (khoảng ___ ảnh), xây dựng quy trình trích đặc trưng, train và so sánh 4 mô hình, SVM đạt F1 = ___, FAR = ___ trên tập test độc lập; tích hợp nhận diện mặt vào hệ thống điểm danh có GPS.
- **Hướng phát triển**: mở rộng dữ liệu, fine-tune ArcFace trên mặt người Việt, chống giả mạo 3D (mặt nạ), điểm danh nhiều người cùng lúc qua camera lớp học.

### 8.10 Các phần đầu báo cáo
- **Tóm tắt**: đề tài làm gì, giải quyết vấn đề gì (điểm danh thủ công tốn thời gian, dễ điểm danh hộ), dùng công nghệ gì (Flutter, Django, PostgreSQL, ONNX Runtime, scikit-learn), cấu trúc các chương.
- **Mở đầu**: bối cảnh, ý nghĩa, chi tiết hơn tóm tắt nhưng chưa phân tích sâu.
- **Phần tự đánh giá**: bảng nhiệm vụ (thu dữ liệu, viết notebook, train và đánh giá, viết báo cáo, xây dựng app…) và bảng điểm theo tiêu chí của mẫu.
- **Chữ viết tắt** gợi ý: CNN, SVM, k-NN, MLP, RBF, FAR, FRR, EER, ROC, AUC, APCER, BPCER, ACER, GPS, BLE, ONNX, LFW, CSDL, SV, GV, PĐT.

### 8.11 Định dạng Word
- [ ] Bìa và tờ lót theo mẫu giảng viên cung cấp.
- [ ] Header ghi tên đề tài, số trang ở footer.
- [ ] Mục lục: References → Table of Contents (tự động).
- [ ] Mỗi hình chèn caption: References → Insert Caption. Danh mục hình: Insert Table of Figures.
- [ ] Đề mục dùng Heading 1, 2, 3 để mục lục tự nhận.
- [ ] Cập nhật mục lục và danh mục hình lần cuối trước khi nộp (chuột phải → Update Field → Update entire table).

---

## 9. Tài liệu tham khảo

Mẫu **không cho dẫn link hoặc website**, chỉ sách và tạp chí. Trước khi đưa vào, tự kiểm tra lại tên, năm, nơi xuất bản.

**Nghiên cứu liên quan** (chọn 3, mỗi bài tóm tắt không quá 1 trang: bài toán, phương pháp, kết quả, liên quan gì tới đề tài):
1. Schroff F., Kalenichenko D., Philbin J. (2015), *FaceNet: A Unified Embedding for Face Recognition and Clustering*, CVPR.
2. Deng J., Guo J., Xue N., Zafeiriou S. (2019), *ArcFace: Additive Angular Margin Loss for Deep Face Recognition*, CVPR.
3. Liu Y., Jourabloo A., Liu X. (2018), *Learning Deep Models for Face Anti-Spoofing: Binary or Auxiliary Supervision*, CVPR.

**Thêm vào danh mục tài liệu tham khảo:**
- Huang G. B. và cộng sự (2007), báo cáo kỹ thuật LFW (mục 5.3).
- Cortes C., Vapnik V. (1995), *Support-Vector Networks*, Machine Learning, 20(3).
- Platt J. (1999), *Probabilistic Outputs for Support Vector Machines and Comparisons to Regularized Likelihood Methods*, Advances in Large Margin Classifiers, MIT Press.
- van der Maaten L., Hinton G. (2008), *Visualizing Data using t-SNE*, Journal of Machine Learning Research, 9.
- Pedregosa F. và cộng sự (2011), *Scikit-learn: Machine Learning in Python*, Journal of Machine Learning Research, 12.
- Wu W., Peng H., Yu S. (2023), *YuNet: A Tiny Millisecond-level Face Detector*, Machine Intelligence Research.
- He K., Zhang X., Ren S., Sun J. (2016), *Deep Residual Learning for Image Recognition*, CVPR (ResNet, nền của ArcFace R50).
- ISO/IEC 30107-3:2017, *Biometric presentation attack detection — Part 3: Testing and reporting* (định nghĩa APCER, BPCER).

**Tiếng Việt**: giáo trình Học máy hoặc Trí tuệ nhân tạo do giảng viên hay thư viện trường cung cấp. Hỏi giảng viên tên sách cụ thể.

---

## 10. Lịch làm việc và bảng đánh dấu

| Ngày | Việc | Xong |
|---|---|---|
| 1 | Chọn người, xin đồng ý, chuẩn bị thiết bị, tạo sổ thu dữ liệu (mục 1) | [ ] |
| 1 | Quay **buổi 1** cho 5 người (mục 2) | [ ] |
| 1 | Tải LFW (mục 5) | [ ] |
| 2 | Quay **buổi 2** | [ ] |
| 2 | In ảnh, quay video giả mạo (mục 3) | [ ] |
| 3 | Quay **buổi 3** (máy khác, chỗ khác) | [ ] |
| 3 | Chép video, chạy lệnh kiểm tra (mục 4) | [ ] |
| 4 | Cài môi trường, chạy notebook, kiểm tra, chụp màn hình (mục 6) | [ ] |
| 4 | Quay bổ sung nếu có người thiếu ảnh | [ ] |
| 5–6 | Đọc 3 bài nghiên cứu, tìm tài liệu tiếng Việt (mục 9) | [ ] |
| 6–9 | Viết báo cáo theo thứ tự ở mục 8.1 | [ ] |
| 10 | Định dạng Word (mục 8.11), đọc soát, nộp | [ ] |

---

## 11. Quyền riêng tư và dọn dẹp
- Không commit `ml_report/du_lieu/` (đã chặn bằng `.gitignore`). Không gửi video lên nhóm chat công khai.
- Bảng tên thật ↔ mã và giấy đồng ý để ngoài repo.
- Báo cáo chỉ dùng mã P1–P5, chỉ dán ảnh của người đồng ý làm minh hoạ.
- Sau khi chấm: xoá `ml_report/du_lieu/` (video, ảnh cắt, LFW) và `ket_qua/anh_doan_sai.png`, `ket_qua/anh_can_chinh.png`. Giữ notebook và các bảng số liệu.
