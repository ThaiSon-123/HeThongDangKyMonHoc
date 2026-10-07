# CHI TIẾT CHỨC NĂNG CỦA ĐỀ TÀI

**Tên đề tài:** Xây dựng hệ thống đăng ký môn học

## 1. TỔNG QUAN HỆ THỐNG
Hệ thống đăng ký môn học hỗ trợ nhà trường quản lý quy trình đào tạo từ tài khoản người dùng, ngành đào tạo, chương trình đào tạo, môn học, học kỳ, lớp học phần, lịch học, đăng ký môn học, điểm danh, nhập điểm, học phí, thông báo đến báo cáo thống kê.

Hệ thống bao gồm:

| Thành phần | Mô tả |
| :--- | :--- |
| **Ứng dụng di động** | Xây dựng bằng Flutter và Dart, phục vụ Phòng đào tạo, Sinh viên, Giáo viên và Kế toán trên Android. |
| **Backend API** | Xây dựng bằng Django REST Framework, xử lý nghiệp vụ, phân quyền, đăng ký môn học, học phí, điểm danh và điểm số. |
| **Cơ sở dữ liệu** | PostgreSQL lưu trữ tài khoản, hồ sơ, môn học, lớp học phần, đăng ký, điểm danh, điểm số, học phí và thông báo. |
| **Dịch vụ hỗ trợ** | JWT dùng cho xác thực, Swagger/OpenAPI dùng để tài liệu hóa và kiểm thử API, Docker dùng để triển khai. |

## 2. ĐỐI TƯỢNG SỬ DỤNG

| STT | Vai trò | Nền tảng | Mô tả |
| :---: | :--- | :--- | :--- |
| 1 | **Phòng đào tạo** | Flutter App | Quản lý tài khoản, ngành, chương trình đào tạo, môn học, học kỳ, lớp học phần, lịch học, đăng ký môn học, thông báo và báo cáo đào tạo. |
| 2 | **Sinh viên** | Flutter App | Xem chương trình đào tạo, đăng ký môn học, tạo thời khóa biểu tự động, xem lịch học, học phí, điểm, điểm danh và thông báo. |
| 3 | **Giáo viên** | Flutter App | Xem lớp phụ trách, xem lịch dạy, điểm danh sinh viên theo từng buổi, nhập điểm và gửi thông báo cho lớp. |
| 4 | **Kế toán** | Flutter App | Cấu hình đơn giá tín chỉ, tính học phí, theo dõi thanh toán, xác nhận đóng học phí, công nợ và báo cáo tài chính học phí. |

## 3. DANH SÁCH CHỨC NĂNG TỔNG HỢP

| STT | Nhóm chức năng | Số lượng CN | Ghi chú |
| :---: | :--- | :---: | :--- |
| 1 | Phòng đào tạo | 15 | Quản lý dữ liệu đào tạo, lớp học phần, đăng ký môn học, thông báo và báo cáo. |
| 2 | Sinh viên | 13 | Đăng ký môn học, tạo thời khóa biểu, xem lịch học, học phí, điểm và thông báo. |
| 3 | Giáo viên | 12 | Quản lý lớp phụ trách, điểm danh từng buổi, nhập điểm và thông báo lớp. |
| 4 | Kế toán | 13 | Cấu hình đơn giá tín chỉ, tính học phí, xác nhận thanh toán và báo cáo công nợ. |
| 5 | Hệ thống tự động | 10 | Kiểm tra ràng buộc, tính điểm, tính học phí, cập nhật sĩ số và trạng thái thông báo. |
| | **TỔNG CỘNG** | **63** | |

## 4. CHI TIẾT CHỨC NĂNG THEO VAI TRÒ

### 4.1. Phòng đào tạo

| Mã CN | Tên chức năng | Mô tả | Đối tượng |
| :--- | :--- | :--- | :--- |
| PDT-01 | Quản lý tài khoản | Tạo, cập nhật, khóa hoặc mở khóa tài khoản Sinh viên, Giáo viên và Kế toán. | Phòng đào tạo |
| PDT-02 | Quản lý hồ sơ người dùng | Quản lý mã sinh viên, mã giáo viên, ngành học, khoa/bộ môn và thông tin liên hệ. | Phòng đào tạo |
| PDT-03 | Quản lý ngành đào tạo | Thêm, sửa, ngừng sử dụng ngành đào tạo và thời gian đào tạo. | Phòng đào tạo |
| PDT-04 | Quản lý chương trình đào tạo | Tạo chương trình theo ngành, khóa tuyển sinh, tổng tín chỉ yêu cầu và danh sách môn học. | Phòng đào tạo |
| PDT-05 | Quản lý môn học | Thêm, sửa môn học, số tín chỉ, số tiết lý thuyết, số tiết thực hành và trạng thái môn học. | Phòng đào tạo |
| PDT-06 | Quản lý môn tiên quyết | Thiết lập môn học cần đạt trước khi sinh viên được đăng ký môn tiếp theo. | Phòng đào tạo |
| PDT-07 | Quản lý học kỳ | Tạo học kỳ, cập nhật thời gian học kỳ, mở hoặc đóng học kỳ. | Phòng đào tạo |
| PDT-08 | Cấu hình thời gian đăng ký | Thiết lập thời gian bắt đầu và kết thúc đăng ký môn học trong từng học kỳ. | Phòng đào tạo |
| PDT-09 | Quản lý lớp học phần | Mở lớp học phần, phân công giáo viên, thiết lập sĩ số tối đa và trạng thái lớp. | Phòng đào tạo |
| PDT-10 | Quản lý lịch học | Thiết lập thứ học, buổi học, tiết học, số tiết mỗi buổi và phòng học cho lớp học phần. | Phòng đào tạo |
| PDT-11 | Theo dõi đăng ký môn học | Xem danh sách sinh viên đăng ký theo môn, lớp học phần, ngành và học kỳ. | Phòng đào tạo |
| PDT-12 | Hủy đăng ký khi cần | Hủy đăng ký môn học của sinh viên trong trường hợp có lý do hợp lệ. | Phòng đào tạo |
| PDT-13 | Gửi thông báo | Gửi thông báo đến sinh viên, giáo viên, kế toán hoặc toàn hệ thống. | Phòng đào tạo |
| PDT-14 | Báo cáo đào tạo | Xem thống kê sinh viên, lớp học phần, số lượng đăng ký, lớp đầy/còn chỗ theo học kỳ. | Phòng đào tạo |
| PDT-15 | Tra cứu dữ liệu đào tạo | Tìm kiếm, lọc và xem chi tiết ngành, môn học, lớp học phần, lịch học và đăng ký. | Phòng đào tạo |

### 4.2. Sinh viên

| Mã CN | Tên chức năng | Mô tả | Đối tượng |
| :--- | :--- | :--- | :--- |
| SV-01 | Đăng nhập hệ thống | Sinh viên đăng nhập bằng tài khoản được cấp để sử dụng các chức năng cá nhân. | Sinh viên |
| SV-02 | Xem hồ sơ cá nhân | Xem thông tin sinh viên, ngành học, năm nhập học, GPA và tín chỉ tích lũy. | Sinh viên |
| SV-03 | Xem chương trình đào tạo | Xem danh sách môn học theo ngành, môn bắt buộc, môn tự chọn và học kỳ gợi ý. | Sinh viên |
| SV-04 | Xem môn được đăng ký | Xem danh sách môn/lớp học phần đang mở trong học kỳ. | Sinh viên |
| SV-05 | Đăng ký môn học thủ công | Chọn lớp học phần và xác nhận đăng ký môn học. | Sinh viên |
| SV-06 | Tạo thời khóa biểu tự động | Chọn danh sách môn và ưu tiên giáo viên, ngày, buổi hoặc tiết học để hệ thống gợi ý lịch phù hợp. | Sinh viên |
| SV-07 | Hủy đăng ký môn học | Hủy lớp học phần trong thời gian đăng ký cho phép. | Sinh viên |
| SV-08 | Xem thời khóa biểu | Xem lịch học theo tuần hoặc học kỳ, gồm môn học, lớp, giáo viên, phòng và tiết học. | Sinh viên |
| SV-09 | Xem lịch sử đăng ký | Xem các môn đã đăng ký, đã hủy, đang học và lý do hủy nếu có. | Sinh viên |
| SV-10 | Xem điểm danh | Xem trạng thái điểm danh theo từng buổi học của từng lớp học phần. | Sinh viên |
| SV-11 | Xem điểm | Xem điểm quá trình, giữa kỳ, cuối kỳ, tổng kết, điểm chữ và GPA. | Sinh viên |
| SV-12 | Xem học phí | Xem học phí tạm tính/chính thức theo số tín chỉ và môn học đã đăng ký. | Sinh viên |
| SV-13 | Nhận thông báo | Nhận thông báo từ Phòng đào tạo, Giáo viên hoặc Kế toán. | Sinh viên |

### 4.3. Giáo viên

| Mã CN | Tên chức năng | Mô tả | Đối tượng |
| :--- | :--- | :--- | :--- |
| GV-01 | Đăng nhập hệ thống | Giáo viên đăng nhập bằng tài khoản được cấp. | Giáo viên |
| GV-02 | Xem hồ sơ cá nhân | Xem mã giáo viên, khoa/bộ môn, thông tin liên hệ và thông tin công tác. | Giáo viên |
| GV-03 | Xem lớp phụ trách | Xem danh sách lớp học phần được phân công giảng dạy. | Giáo viên |
| GV-04 | Xem chi tiết lớp | Xem thông tin môn học, lịch học, phòng học, sĩ số và danh sách sinh viên. | Giáo viên |
| GV-05 | Xem thời khóa biểu cá nhân | Xem lịch dạy theo tuần hoặc theo học kỳ. | Giáo viên |
| GV-06 | Tạo buổi điểm danh | Chọn lớp học phần, ngày học, buổi học và tiết học để thực hiện điểm danh. | Giáo viên |
| GV-07 | Điểm danh sinh viên | Đánh dấu từng sinh viên theo trạng thái Có mặt, Vắng có phép, Vắng không phép hoặc Đi trễ. | Giáo viên |
| GV-08 | Cập nhật điểm danh | Sửa trạng thái điểm danh khi có lý do hợp lệ và lưu thời gian cập nhật. | Giáo viên |
| GV-09 | Xem lịch sử điểm danh | Xem lại danh sách điểm danh theo từng buổi của lớp học phần. | Giáo viên |
| GV-10 | Nhập điểm | Nhập điểm quá trình, giữa kỳ và cuối kỳ cho sinh viên trong lớp phụ trách. | Giáo viên |
| GV-11 | Gửi thông báo cho lớp | Gửi thông báo đến sinh viên trong lớp mình phụ trách. | Giáo viên |
| GV-12 | Xuất danh sách lớp | Xuất danh sách sinh viên, bảng điểm hoặc bảng điểm danh khi cần. | Giáo viên |

### 4.4. Kế toán

| Mã CN | Tên chức năng | Mô tả | Đối tượng |
| :--- | :--- | :--- | :--- |
| KT-01 | Quản lý cấu hình học phí | Thiết lập chính sách tính học phí dùng trong từng học kỳ. | Kế toán |
| KT-02 | Thiết lập giá tín chỉ toàn ngành | Cấu hình đơn giá tín chỉ mặc định theo từng ngành đào tạo. | Kế toán |
| KT-03 | Thiết lập giá theo khối kiến thức | Cấu hình giá tín chỉ theo kiến thức chung, cơ sở ngành, chuyên ngành, tự chọn và tốt nghiệp. | Kế toán |
| KT-04 | Thiết lập giá tín chỉ lý thuyết | Cấu hình đơn giá riêng cho tín chỉ lý thuyết của môn học. | Kế toán |
| KT-05 | Thiết lập giá tín chỉ thực hành | Cấu hình đơn giá riêng cho tín chỉ thực hành, thí nghiệm hoặc đồ án nếu môn học có phần thực hành. | Kế toán |
| KT-06 | Thiết lập miễn giảm học phí | Cấu hình học bổng, miễn giảm, hoàn tiền hoặc khoản giảm trừ theo chính sách. | Kế toán |
| KT-07 | Tính học phí tự động | Hệ thống tính học phí dựa trên môn sinh viên đăng ký, số tín chỉ và bảng giá đang áp dụng. | Kế toán |
| KT-08 | Xem danh sách học phí | Xem học phí của sinh viên theo học kỳ, ngành, lớp, trạng thái thanh toán. | Kế toán |
| KT-09 | Xác nhận thanh toán | Ghi nhận sinh viên đã đóng học phí bằng tiền mặt, chuyển khoản hoặc hình thức khác. | Kế toán |
| KT-10 | Theo dõi công nợ | Xem danh sách sinh viên chưa đóng, đóng thiếu hoặc quá hạn. | Kế toán |
| KT-11 | Điều chỉnh học phí | Điều chỉnh học phí khi có thay đổi đăng ký, hủy môn, miễn giảm hoặc thu bổ sung. | Kế toán |
| KT-12 | Xuất biên lai/hóa đơn | Xuất phiếu thu, biên lai hoặc hóa đơn học phí cho sinh viên. | Kế toán |
| KT-13 | Báo cáo tài chính học phí | Thống kê tổng học phí phải thu, đã thu, còn nợ theo học kỳ, ngành, lớp hoặc sinh viên. | Kế toán |

### 4.5. Chức năng tự động của hệ thống

| Mã CN | Tên chức năng | Mô tả | Đối tượng |
| :--- | :--- | :--- | :--- |
| SYS-01 | Kiểm tra trùng lịch | Không cho sinh viên đăng ký lớp bị trùng thứ, buổi hoặc tiết học. | Hệ thống |
| SYS-02 | Kiểm tra sĩ số | Không cho đăng ký khi lớp học phần đã đủ số lượng sinh viên tối đa. | Hệ thống |
| SYS-03 | Kiểm tra môn tiên quyết | Chỉ cho đăng ký khi sinh viên đã đạt môn học tiên quyết. | Hệ thống |
| SYS-04 | Tự cập nhật sĩ số | Tăng hoặc giảm sĩ số khi sinh viên đăng ký hoặc hủy đăng ký môn học. | Hệ thống |
| SYS-05 | Gợi ý thời khóa biểu | Tìm tổ hợp lớp học phần hợp lệ và phù hợp với ưu tiên của sinh viên. | Hệ thống |
| SYS-06 | Tự tính điểm tổng kết | Tính điểm tổng kết theo công thức điểm quá trình, giữa kỳ và cuối kỳ. | Hệ thống |
| SYS-07 | Quy đổi điểm | Quy đổi điểm tổng kết sang điểm chữ và GPA thang 4. | Hệ thống |
| SYS-08 | Tự tính học phí | Tính học phí theo tín chỉ, loại tín chỉ và bảng giá do Kế toán cấu hình. | Hệ thống |
| SYS-09 | Lưu trạng thái điểm danh | Lưu lịch sử điểm danh từng sinh viên theo từng buổi học. | Hệ thống |
| SYS-10 | Lưu trạng thái thông báo | Theo dõi thông báo đã đọc hoặc chưa đọc của từng người dùng. | Hệ thống |

## 5. QUY TẮC NGHIỆP VỤ CHÍNH

| Mã | Quy tắc nghiệp vụ |
| :--- | :--- |
| BR-01 | Sinh viên chỉ đăng ký môn học khi học kỳ đang mở và còn trong thời gian đăng ký. |
| BR-02 | Sinh viên không được đăng ký lớp học phần đã đủ sĩ số. |
| BR-03 | Sinh viên không được đăng ký lớp học phần bị trùng lịch với lớp đã đăng ký. |
| BR-04 | Sinh viên chỉ được đăng ký môn học nếu đã đạt môn tiên quyết theo quy định. |
| BR-05 | Sinh viên được hủy đăng ký trong thời gian đăng ký môn học. |
| BR-06 | Giáo viên chỉ được điểm danh và nhập điểm cho lớp học phần được phân công. |
| BR-07 | Điểm tổng kết được tính theo công thức: 10% điểm quá trình, 40% điểm giữa kỳ, 50% điểm cuối kỳ. |
| BR-08 | Học phí được tính theo môn học đã đăng ký, số tín chỉ và đơn giá tín chỉ do Kế toán cấu hình. |
| BR-09 | Nếu môn học có tín chỉ thực hành, hệ thống áp dụng đơn giá tín chỉ thực hành theo cấu hình học phí. |
| BR-10 | Trạng thái điểm danh của sinh viên được lưu theo từng buổi học để phục vụ tra cứu và báo cáo. |

## 6. CÔNG NGHỆ SỬ DỤNG

| Thành phần | Công nghệ |
| :--- | :--- |
| **Ứng dụng di động** | Flutter, Dart |
| **Backend API** | Python, Django REST Framework |
| **Cơ sở dữ liệu** | PostgreSQL, SQL, Django ORM |
| **Xác thực** | JWT access token, refresh token, phân quyền theo vai trò |
| **Tài liệu và kiểm thử API**| Swagger/OpenAPI |
| **Triển khai** | Docker, Docker Compose |