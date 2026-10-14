# Hệ thống đăng ký môn học

Backend **Django REST + PostgreSQL** (chạy bằng Docker) và giao diện **Flutter** (Web + App Android/iOS).
Đặc tả đầy đủ ở [`plan.md`](plan.md), tiến độ ở [`checklist.md`](checklist.md), thiết kế giao diện ở
[`design.md`](design.md) và [`design_mockups/`](design_mockups/README.md).

```
HeThongDangKyMonHoc/
├── backend/            Django (API) + docker-compose.yml
├── dang_ky_mon_hoc/    Flutter (Web + App)
├── design_mockups/     Mockup giao diện (mở bằng trình duyệt)
├── docs/               Bản lưu plan cũ
└── plan.md · checklist.md · design.md
```

Hệ thống gồm **hai phần chạy riêng**, cần chạy cả hai mới dùng được:

```
Trình duyệt ──► Flutter (giao diện) ──gọi API──► Docker: web (Django, :8010) ──► db (PostgreSQL)
```

Mở `http://localhost:8010` sẽ thấy 404 — đó là **API**, không có trang giao diện. Giao diện chạy ở bước 2.

## 1. Chạy backend (Docker)

Cần [Docker Desktop](https://www.docker.com/products/docker-desktop/) đang mở.

```bash
cd backend
cp .env.example .env          # lần đầu (sửa DB_PASSWORD nếu muốn)
docker compose up -d --build  # dựng web, db, redis, worker, beat, nginx
docker compose exec web python manage.py seed_demo   # nạp dữ liệu demo (chạy lại an toàn)
```

Kiểm tra: `http://localhost:8010/api/health/` trả `{"status":"ok"}`; Swagger ở `http://localhost:8010/api/docs/`.

| Việc | Lệnh (trong `backend/`) |
| :--- | :--- |
| Dừng (giữ dữ liệu) | `docker compose down` |
| Xem log API | `docker compose logs -f web` |
| Làm lại từ đầu, **xóa dữ liệu** | `docker compose down -v` |
| Tạo Admin thật (vai trò tự là `ADMIN`) | `docker compose exec web python manage.py createsuperuser` |

## 2. Chạy giao diện (Flutter)

Cần [Flutter](https://docs.flutter.dev/get-started/install) (đã thêm `flutter\bin` vào PATH).

```bash
cd dang_ky_mon_hoc
flutter pub get
flutter run -d edge -t lib/main.dart       # bản Web, đủ 5 vai trò (dùng -d chrome nếu thích)
flutter run -d edge -t lib/main_app.dart   # bản App (chỉ SV/GV) — thu hẹp cửa sổ < 600px để xem bố cục điện thoại
```

Giao diện gọi API tại `http://localhost:8010/api`. Android emulator không thấy `localhost` của máy:
thêm `--dart-define=API_BASE_URL=http://10.0.2.2:8010/api`.

### Tài khoản demo
Mật khẩu chung: `Demo@12345`

| Vai trò | Tên đăng nhập |
| :--- | :--- |
| Admin | `admin` |
| Phòng đào tạo | `pdt1`, `pdt2` |
| Kế toán | `kt1`, `kt2` |
| Giáo viên | `gv1` … `gv3` |
| Sinh viên | `sv01` … `sv10` |

Các màn đã làm và pha còn lại: xem `checklist.md` (màn tổng quan `/pdt`, `/accountant`, `/teacher`, `/admin`
và TKB tự động của SV hiện còn "đang phát triển").

## 3. Chạy kiểm tra

**Backend** (Python 3.12, venv `backend/.venv312`):

```bash
cd backend
python -m venv .venv312 && .venv312/Scripts/python -m pip install -r requirements.txt -r requirements-dev.txt
.venv312/Scripts/pytest -q                 # test nhanh trên SQLite
# test trên PostgreSQL thật (cổng 5433 do docker-compose mở cho máy bạn):
TEST_DB=postgres DB_HOST=localhost DB_PORT=5433 DB_PASSWORD=postgres .venv312/Scripts/pytest -q
.venv312/Scripts/ruff check . ; .venv312/Scripts/black --check . ; .venv312/Scripts/mypy .
```

**Flutter:**

```bash
cd dang_ky_mon_hoc
flutter analyze ; flutter test
```

CI (GitHub Actions) chạy đúng các bước trên cho mỗi PR.

## 4. Sao lưu, khôi phục và load test

- **Sao lưu:** Admin → *Sao lưu* (hoặc tự động 02:00 mỗi ngày). File `hpsv_YYYYMMDD_HHMMSS.dump` nằm trong volume
  `backups` (`/backups` trong container), giữ `backup_retention_days` ngày (Admin → *Cấu hình*).
- **Khôi phục (làm tay, giao diện không có nút này):**

  ```bash
  cd backend
  docker compose exec worker sh -c 'pg_restore -c -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" /backups/<tên-file>.dump'
  ```

- **Load test đăng ký đồng thời** (cần backend + `seed_demo`; tạo một lớp `MO` ít chỗ rồi chạy):

  ```bash
  cd backend
  pip install locust
  LOCUST_CLASS_ID=<id lớp> locust -f locustfile.py --host http://localhost:8010 -u 10 -r 10 -t 30s --headless
  ```

  Đạt khi không có lỗi 5xx và sĩ số cuối không vượt chỗ tối đa (script tự kiểm, thoát mã 1 nếu vượt).
  Lưu ý: đăng nhập giới hạn 10 lần/phút/IP nên đợi ~1 phút giữa hai lần chạy.
- **Build:** `flutter build web -t lib/main.dart` (Web, đủ 5 vai trò) · `flutter build apk -t lib/main_app.dart` (App, SV/GV).
