# BÀI THỰC HÀNH SỐ 2 – THIẾT KẾ KIẾN TRÚC
## Bài 1. Xác định mẫu kiến trúc phần mềm (Software Architecture Patterns)

**Đề tài:** Hệ thống Đăng ký Môn Học Trực tuyến

**Nhóm thực hiện:** ....................................................
**Thành viên:** ....................................................

---

## a) Tên mẫu kiến trúc chính và các mẫu kiến trúc hỗ trợ

### Mẫu kiến trúc chính: **Client-Server Architecture Pattern** (Kiến trúc Máy chủ – Máy khách), thực hiện theo kiến trúc 3 tầng (Three-Tier Architecture).

Trong kiến trúc này, hệ thống được chia thành ba tầng rõ rệt:

- **Tầng trình bày (Presentation Tier)** – giao diện người dùng, chạy trên máy khách (Web và Mobile), chỉ gửi yêu cầu và hiển thị kết quả, không trực tiếp xử lý nghiệp vụ.
- **Tầng nghiệp vụ (Application / Business Tier)** – máy chủ xử lý toàn bộ logic nghiệp vụ, kiểm tra dữ liệu, phân quyền và thực thi các quy tắc của hệ thống.
- **Tầng dữ liệu (Data Tier)** – cơ sở dữ liệu lưu trữ và quản lý toàn bộ dữ liệu của trường.

Hệ thống Đăng ký Môn Học của nhóm được xây dựng đúng theo mẫu này: giao diện Flutter chạy trên máy khách, máy chủ Django REST Framework xử lý yêu cầu và nghiệp vụ, cơ sở dữ liệu PostgreSQL lưu dữ liệu.

### Các mẫu kiến trúc hỗ trợ

| Mẫu kiến trúc | Vai trò trong dự án |
| :--- | :--- |
| **Layered Architecture (N-tier)** | Được dùng bên trong mỗi tầng, nhất là lớp backend và giao diện khách, tách các lớp nhiều tầng (router → service → repository → database). |
| **Broker / Producer-Consumer** | Dùng cho các công việc nền không cần kết quả ngay (gửi thông báo, chạy số liệu, sao lưu dữ liệu), không ảnh hưởng tốc độ hồi đáp API. |

### Các mẫu khác không được chọn

| Mẫu | Lý do không phù hợp |
| :--- | :--- |
| Microservices | Hệ thống cùng quy mô (một trường đại học), không cần phân tách nhiều dịch vụ liên hệ. |
| Event-Driven | Chỉ hỗ trợ phần xử lý nền, không phải kết cấu chính của hệ thống. |
| Peer-to-Peer | Hệ thống có trung tâm dữ liệu rõ rệt, không phân tán dữ liệu. |
| Pipe-Filter | Phù hợp xử lý dòng dữ liệu (ETL), không phù hợp hệ thống tương tác trực tuyến. |
| Space-Based | Dành cho hệ thống cấp số không lưu trữ dữ liệu vĩnh viễn, quá phức tạp cho dự án này. |
| Microkernel | Dành cho phần mềm có nhiều plugin mở rộng, không cần thiết cho hệ thống web. |
| Master-Slave | Dành cho phân phối xử lý song song trên nhiều máy, không phù hợp với cấu trúc 3 tầng. |

---

## b) SƠ ĐỒ KIẾN TRÚC (HÌNH KHỐI)

```
+-----------------------------------------------+
|        TẦNG TRÌNH BÀY (CLIENT)                |
|                                               |
|  [ Flutter Web ]        [ Flutter App ]       |
|   (5 vai trò: SV, GV,    (SV, GV trên mobile) |
|    PĐ, KT, Admin)                             |
+----------------------+------------------------+
                       |
                 HTTPS / JWT
                       |
                       v
+-----------------------------------------------+
|       TẦNG NGHIỆP VỤ (SERVER)                 |
|                                               |
|  [ Nginx – Reverse Proxy / Web Server ]       |
|          |                                    |
|  [ Gunicorn – WSGI Application Server ]       |
|          |                                    |
|  [ Django REST Framework – API ]              |
|    - Quản lý người dùng / phân quyền          |
|    - Đăng ký môn – lịch học – điểm thực học   |
|    - Điểm – kết quả – học phí                  |
|    - Thông báo – báo cáo                        |
|          |                                    |
|  [ Celery Worker + Beat – công việc nền ]     |
|          |                                    |
|  [ Redis – Message Queue / Broker ]           |
+----------+---------------------+--------------+
           |                     |
           |    ORM (psycopg)    |  enqueue task
           v                     v
+---------------------+   +---------------------+
|  TẦNG DỮ LIỆU       |   |  XỬ LÝ NỀN          |
|  [ PostgreSQL 16 ]   |   |  - Gửi thông báo    |
|  27 thực thể DB      |   |  - Cập nhật lịch học  |
|  ~70 API endpoints   |   |  - Sao lưu dữ liệu    |
+---------------------+   +---------------------+
```

---

## c) DANH SÁCH THÀNH PHẦN

### Tầng trình bày (Client)

1. **Flutter Web** – giao diện web chạy trên trình duyệt, dùng cho 5 vai trò (SV, GV, PĐ, KT, Admin).
2. **Flutter App** – ứng dụng di động, dùng cho SV và GV.
3. **Router (GoRouter)** – quản lý đường dẫn trang và phân quyền giao diện.
4. **State Manager (Riverpod)** – quản lý trạng thái người dùng và dữ liệu đang hiển thị.
5. **HTTP Client (Dio)** – gửi yêu cầu API tới máy chủ, tự động làm mới JWT token.
6. **Local Storage (flutter_secure_storage)** – lưu JWT token và các thông tin cần thiết trên thiết bị.

### Tầng nghiệp vụ (Server)

7. **Nginx** – reverse proxy, tiếp nhận kết nối, phân tải, tăng tốc và chỗ nghe HTTPS.
8. **Gunicorn** – WSGI application server, chạy nhiều worker xử lý cùng lúc các yêu cầu API.
9. **Django REST Framework** – API chính, chứa toàn bộ logic nghiệp vụ của hệ thống.
10. **Quản lý người dùng và xác thực JWT** – đăng nhập, kiểm tra token, phân quyền theo vai trò.
11. **Module nghiệp vụ** – 10 nhóm chức năng: quản lý người dùng, hồ sơ, đào tạo, đăng ký môn, chấm điểm, điểm, học phí, thông báo, nhật ký hệ thống, cài đặt.
12. **Celery Worker + Beat** – xử lý công việc nền theo lịch (job), không chạm vào phần hồi đáp API.
13. **Redis** – hàng đợi tin nhắn và cơ sở dữ liệu tạm cho Celery.

### Tầng dữ liệu (Data)

14. **PostgreSQL 16** – cơ sở dữ liệu chính, lưu 27 thực thể (người dùng, lớp học, môn học, lịch Đăng ký, điểm, học phí...).
15. **Database Migration** – quản lý cấu trúc dữ liệu theo phiên bản.

---

## d) CHỨC NĂNG CỦA TỪNG THÀNH PHẦN

| THÀNH PHẦN | CHỨC NĂNG | VÍ DỤ NGHIỆP VỤ THỰC TẾ |
| :--- | :--- | :--- |
| Flutter Web / App | Hiển thị giao diện, thu thập yêu cầu người dùng, gửi lên máy chủ | SV chọn môn, GV nhập điểm, KT duyệt học phí |
| Router + State | Định hướng trang, lưu trạng thái | Chuyển đổi trang theo vai trò, lưu kết quả tìm kiếm môn |
| Dio (HTTP Client) | Tự động gửi JWT, làm mới token khi hết hạn | Khi hết hạn access token, tự động làm mới, người dùng không cần đăng nhập lại |
| Nginx | Phân giải tải, chặn HTTPS, tăng tốc | Chấm nhận cả yêu cầu, gửi tới Gunicorn; tăng tốc tài nguyên tĩnh |
| Gunicorn | Chạy nhiều worker xử lý cùng lúc | Nhiều SV đăng ký cùng lượt, cùng lúc xử lý song song |
| Django REST Framework | Xử lý logic nghiệp vụ, kiểm tra dữ liệu, phân quyền | BR-06: khi đăng ký môn, dùng `SELECT ... FOR UPDATE` để kiểm tra sỗ chỗn không vượt sỗ lưu |
| Quản lý JWT | Xác thực, phân quyền theo vai trò | PĐ chỉ xem được dân khóa của khoa mình, KT chỉ duyệt học phí |
| Module nghiệp vụ (10 app) | Tách riêng từng lĩnh vực | Đăng ký môn, chấm điểm, điểm, học phí, thông báo... mỗi lĩnh vực 1 app |
| Celery Worker + Beat | Xử lý công việc nền theo lịch | 5 job: chuyển trạng thái lịch học (00:05), quét cấm thi (00:30), thông báo học phí quá hạn (07:00), tính lại GPA (01:00), sao lưu DB (02:00) |
| Redis | Hàng đợi tin nhắn giữa API và Celery | Khi API có công việc nền, đưa vào Redis, Celery worker lấy ra chạy |
| PostgreSQL 16 | Lưu và quản lý dữ liệu, bảo toàn tính nhất quán | 27 thực thể; ghi đồng bộ (transaction) khi đăng ký để không ghi dữ liệu sai |

---

## e) CÔNG NGHỆ SỬ DỤNG

### Phần mềm (Software)

| Tầng | Công nghệ | Mô tả |
| :--- | :--- | :--- |
| Tầng trình bày | Flutter + Dart | Framework UI cho Web và App từ cùng 1 mã nguồn |
| | Material 3 | Bộ thư viện và UI của Flutter |
| | GoRouter | Quản lý đường dẫn và phân quyền giao diện |
| | Riverpod | Quản lý trạng thái ứng dụng |
| | Dio | HTTP client gửi yêu cầu API, tự động làm mới JWT |
| | flutter_secure_storage | Lưu JWT token an toàn trên thiết bị |
| Tầng nghiệp vụ | Python 3.12 | Ngôn ngữ lập trình backend |
| | Django 5.1 | Web framework chính |
| | Django REST Framework | Xây dựng API REST |
| | SimpleJWT | Xác thực JWT cho API |
| | drf-spectacular | Tạo tài liệu API (Swagger) |
| | Nginx 1.27 | Reverse proxy + web server |
| | Gunicorn | WSGI application server |
| Tầng dữ liệu | PostgreSQL 16 | Cơ sở dữ liệu chính |
| | psycopg | Bộ driver kết nối Django đến PostgreSQL |
| Xử lý nền | Celery | Khung làm việc nền (task queue) |
| | django-celery-beat | Lịch chạy công việc nền |
| | Redis 7 | Hàng đợi tin nhắn (message broker) |
| Triển khai & kiểm thử | Docker + Docker Compose | Đóng 6 dịch vụ trong 1 lệnh |
| | GitHub Actions | Tự động kiểm thử khi có commit mới |
| | pytest / factory-boy | Kiểm thử backend |
| | Flutter tests | Kiểm thử giao diện |

---
### Phần cứng (Hardware)

| Thiết bị | Cấu hình tối thiểu | Vai trò |
| :--- | :--- | :--- |
| Máy chủ (Server) | CPU 4 nhân, RAM 8 GB, SSD 100 GB, Ubuntu 22.04 LTS | Chạy toàn bộ tầng nghiệp vụ và dữ liệu: Nginx, Gunicorn, Django, Celery, Redis, PostgreSQL (6 dịch vụ trong Docker) |
| Máy khách – PC/Laptop | CPU 2 nhân, RAM 4 GB, trình duyệt Chrome/Edge | Chạy Flutter Web cho 5 vai trò (SV, GV, PĐ, KT, Admin) |
| Máy khách – Điện thoại | Android 8+ hoặc iOS 12+ | Chạy Flutter App cho SV và GV |
| Mạng | Internet / mạng nội bộ trường | Kết nối máy khách tới máy chủ qua HTTPS |

---

## KẾT LUẬN

Hệ thống Đăng ký Môn Học phù hợp với mẫu **Client-Server (3 tầng)** vì ba lý do:

1. **Dữ liệu tập trung, cần nhất quán cao** – lịch đăng ký, sĩ số lớp, điểm và học phí phải do một nơi quản lý duy nhất để tránh đăng ký trùng hoặc vượt sĩ số.
2. **Nhiều vai trò dùng chung một hệ thống** – 5 vai trò với quyền hạn khác nhau; máy chủ kiểm soát phân quyền tập trung, máy khách chỉ hiển thị theo vai trò.
3. **Quy mô và độ phức tạp phù hợp** – hệ thống phục vụ một trường đại học, không cần phân tách microservices; kiến trúc 3 tầng dễ phát triển, dễ bảo trì và đủ khả năng mở rộng khi số người dùng tăng.

Mẫu **Layered** giúp tách bạch lớp xử lý trong mỗi tầng, mẫu **Broker** giúp các công việc nền (thông báo, tính điểm, sao lưu) chạy độc lập mà không làm chậm phản hồi API.
