# Đóng học phí một lần / chia 3 đợt + QR VNPay sandbox — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sinh viên đóng học phí một lần hoặc chia 3 đợt (KT cấu hình), thanh toán qua QR → VNPay sandbox, học phí tự cập nhật.

**Architecture:** Lịch đợt là giá trị dẫn xuất từ `phai_nop` và `thuc_thu` (không gắn `Payment` vào đợt). Giao dịch VNPay lưu ở `OnlineTransaction`; return URL và IPN dùng chung `services.xac_nhan_vnpay`, ghi `Payment` qua `ghi_thanh_toan` (idempotent theo `request_id = txn_ref`). Flutter thay khối QR chuyển khoản giả bằng QR chứa `payment_url`.

**Tech Stack:** Django 5 + DRF + pytest-django (SQLite khi test), Flutter (Riverpod, go_router, dio, qr_flutter, thêm `url_launcher`).

**Spec:** `docs/superpowers/specs/2026-10-25-dong-hoc-phi-vnpay-design.md`

## Global Constraints

- Tiền: `Decimal`, làm tròn 2 số bằng `services._lam_tron`; `vnp_Amount = int(so_tien * 100)`.
- 3 đợt đúng: `thu_tu` 1..3, Σ`ty_le` = 100, `han_dong` tăng dần ngặt; `luy_ke` đợt 3 luôn = `phai_nop`.
- `vnp_TxnRef` = `uuid.hex` (32 ký tự); `Payment.request_id` = `uuid.UUID(txn_ref)`; người thu = chính SV.
- Chữ ký: HMAC-SHA512, tham số sắp tăng theo tên, `quote_plus` giá trị, nối `&`, hex thường; loại `vnp_SecureHash`/`vnp_SecureHashType`.
- Thành công khi `vnp_ResponseCode == "00"` **và** `vnp_TransactionStatus == "00"`.
- IPN trả `{"RspCode","Message"}`: `00` OK, `01` không thấy giao dịch, `02` đã xác nhận, `04` sai số tiền, `97` sai chữ ký, `99` lỗi khác.
- Hạn thanh toán VNPay: `vnp_ExpireDate = now + 15 phút`, giờ VN, định dạng `yyyyMMddHHmmss`.
- Không commit key VNPay; chỉ đọc từ env. Văn bản giao diện và lỗi bằng tiếng Việt; mã lỗi nghiệp vụ dùng `core.exceptions.Codes` (`SO_TIEN_KHONG_HOP_LE`, `TRANG_THAI_KHONG_HOP_LE`); không thêm mã mới.
- Giữ nguyên `thong_tin_chuyen_khoan` / `thanh_toan` trong `GET /tuition/my/` và các khóa `ck_*` ở backend (chỉ UI bỏ khối QR giả).
- Lệnh backend chạy ở `backend/`: `.venv312/Scripts/pytest <path> -q`, `.venv312/Scripts/ruff check .`, `.venv312/Scripts/black --check .`. Lệnh Flutter chạy ở `dang_ky_mon_hoc/`: `flutter test`, `flutter analyze`.

## Review Focus

1. `phai_nop = 0` (miễn giảm hết) với `CHIA_DOT`: mọi đợt `da_dong`, `POST my/pay/` bị từ chối. → Task 6.
2. Trình duyệt reload return URL / VNPay gọi lại sau khi return đã ghi: chỉ một `Payment`. → Task 7.
3. Callback bị sửa số tiền hoặc thêm tham số lạ: chữ ký đúng nhưng số tiền lệch bị từ chối; tham số `vnp_*` lạ vẫn nằm trong chữ ký. → Task 7.
4. SV đọc trạng thái giao dịch của SV khác: `404`, không lộ sự tồn tại. → Task 6.
5. Thiếu `VNPAY_TMN_CODE`/`VNPAY_HASH_SECRET`: `POST my/pay/` trả `400` rõ ràng, không `500`. → Task 6.

## File Structure

| File | Trách nhiệm |
|---|---|
| `backend/apps/tuition/models.py` (sửa) | `TuitionInstallment`, `OnlineTransaction`, `Tuition.hinh_thuc`, `PhuongThuc.VNPAY` |
| `backend/apps/tuition/services.py` (sửa) | `lich_dot`, `han_va_qua_han`, `tao_giao_dich_vnpay`, `xac_nhan_vnpay`, cập nhật `thong_bao_qua_han` |
| `backend/apps/tuition/vnpay.py` (mới) | Ký, kiểm chữ ký, dựng URL VNPay — không biết gì về DB |
| `backend/apps/tuition/serializers.py`, `views.py`, `config/api_urls.py` (sửa) | API |
| `backend/apps/audit/models.py` (sửa) | Thêm `TuitionInstallment`, `OnlineTransaction` vào `SCOPE_FINANCE` |
| `backend/apps/tuition/tests/test_installments.py` (mới) | Task 1–4 |
| `backend/apps/tuition/tests/test_vnpay.py` (mới) | Task 5–7 |
| `dang_ky_mon_hoc/lib/features/tuition/*.dart`, `lib/core/router/routes_student.dart` (sửa) | Task 8–9 |

---

### Task 1: Mô hình dữ liệu + migration

**Files:**
- Modify: `backend/apps/tuition/models.py`, `backend/apps/audit/models.py:36-42`
- Create: `backend/apps/tuition/migrations/0003_*.py` (do `makemigrations` sinh)
- Test: `backend/apps/tuition/tests/test_installments.py`

**Interfaces:**
- Produces:
  - `class HinhThucDong(TextChoices)`: `MOT_LAN`, `CHIA_DOT`; `Tuition.hinh_thuc` (CharField, default `MOT_LAN`).
  - `TuitionInstallment(hoc_ky FK→Semester related_name="dot_hoc_phi", thu_tu PositiveSmallInteger, ty_le Decimal(5,2), han_dong Date)`, `UNIQUE(hoc_ky, thu_tu)`, check `thu_tu BETWEEN 1 AND 3`, ordering `["hoc_ky_id","thu_tu"]`.
  - `class TrangThaiGiaoDich(TextChoices)`: `CHO`, `THANH_CONG`, `THAT_BAI`, `LOI`.
  - `OnlineTransaction(txn_ref UUIDField unique default uuid4, tuition FK→Tuition related_name="giao_dich_online", so_tien Decimal(14,2), trang_thai default CHO, vnp_transaction_no CharField(30, blank), tao_luc auto_now_add, ket_thuc_luc null)`.
  - `PhuongThuc.VNPAY = "VNPAY", "VNPay"`.

- [ ] **Step 1: Write failing tests** in `test_installments.py` (`pytestmark = pytest.mark.django_db`):
  - `test_dot_trung_thu_tu_bi_chan`: tạo hai `TuitionInstallment` cùng `(hoc_ky, thu_tu=1)` → `IntegrityError`.
  - `test_online_transaction_mac_dinh_cho_va_txn_ref_duy_nhat`: tạo `OnlineTransaction` (cần `Tuition`), `trang_thai == "CHO"`, `txn_ref` là `uuid.UUID`.
  - `test_tuition_mac_dinh_mot_lan`: `Tuition.objects.create(...)` → `hinh_thuc == "MOT_LAN"`.
  - Helper `hoc_phi(sv, hk, tong)` giống `test_tuition.py:50` (sao chép 4 dòng, dùng `StudentProfileFactory`, `SemesterFactory`).
- [ ] **Step 2: Run to verify fail:** `.venv312/Scripts/pytest apps/tuition/tests/test_installments.py -q` → FAIL (import error).
- [ ] **Step 3: Implement** các model trên trong `models.py`; thêm `"TuitionInstallment"`, `"OnlineTransaction"` vào `SCOPE_FINANCE`; chạy `.venv312/Scripts/python manage.py makemigrations tuition -n chia_dot_vnpay`.
- [ ] **Step 4: Verify:** `pytest apps/tuition/tests/test_installments.py -q` PASS; `python manage.py makemigrations --check --dry-run` báo "No changes".
- [ ] **Step 5: Commit** `feat(tuition): mô hình chia đợt và giao dịch VNPay`.

---

### Task 2: Lịch đợt dẫn xuất + hạn/quá hạn

**Files:**
- Modify: `backend/apps/tuition/services.py` (cạnh `gia_tri_dan_xuat`, sau dòng 170)
- Test: `backend/apps/tuition/tests/test_installments.py`

**Interfaces:**
- Consumes: `TuitionInstallment`, `HinhThucDong` (Task 1), `_lam_tron`.
- Produces:
  - `dot_cua_hoc_ky(hoc_ky_id: int) -> list[TuitionInstallment]` — sắp theo `thu_tu`; `[]` nếu không đủ 3 đợt.
  - `lich_dot(phai_nop: Decimal, thuc_thu: Decimal, dots: Sequence[TuitionInstallment]) -> list[dict]` — mỗi dict `{"thu_tu": int, "ty_le": Decimal, "han_dong": date, "phai_nop": Decimal, "luy_ke": Decimal, "da_dong": bool}`; `[]` nếu `dots` rỗng.
  - `dot_tiep_theo(lich: list[dict], thuc_thu: Decimal) -> dict | None` — `{"thu_tu": int, "can_dong": Decimal}` cho đợt đầu chưa `da_dong`, `can_dong = luy_ke − thuc_thu`; `None` nếu đã đóng hết hoặc `lich` rỗng.
  - `han_va_qua_han(hinh_thuc: str, dx: dict, han_mot_lan: date | None, lich: list[dict], hom_nay: date) -> tuple[date | None, bool]` — `dx` là kết quả `gia_tri_dan_xuat`. `MOT_LAN` hoặc `lich` rỗng: `(han_mot_lan, bool(han_mot_lan and hom_nay > han_mot_lan and dx["con_no"] > 0))`. `CHIA_DOT`: hạn = `han_dong` của đợt tiếp theo chưa đóng (đợt cuối nếu đã đóng hết); quá hạn khi tồn tại đợt chưa `da_dong` có `han_dong < hom_nay`.

- [ ] **Step 1: Write failing tests** (hàm thuần, dùng object giả `_Dot(thu_tu, ty_le, han_dong)` như `_D`/`_P` ở `test_tuition.py:70`):
  - `test_lich_dot_40_30_30`: `phai_nop=1000`, dots 40/30/30 → `[d["phai_nop"] for d in lich] == [400, 300, 300]`, `luy_ke == [400, 700, 1000]`.
  - `test_lich_dot_lam_tron_dot_cuoi_bu_lech`: `phai_nop=100`, tỷ lệ 33.33/33.33/33.34 → tổng ba `phai_nop` đúng bằng `100`, `luy_ke[-1] == 100`.
  - `test_da_dong_theo_thuc_thu_chay_tu_dot_1`: `thuc_thu=500` → `da_dong == [True, False, False]`; `dot_tiep_theo(...) == {"thu_tu": 2, "can_dong": D(200)}`; `thuc_thu=1000` → `dot_tiep_theo` là `None`.
  - `test_phai_nop_0_moi_dot_da_dong`: `phai_nop=0` → mọi `da_dong` là `True`, `dot_tiep_theo is None`.
  - `test_han_va_qua_han_chia_dot`: đợt 1 hạn quá khứ chưa đóng → `(han_dot_1, True)`; đã đóng đợt 1, đợt 2 hạn tương lai → `(han_dot_2, False)`.
  - `test_han_va_qua_han_mot_lan_va_thieu_dot`: `MOT_LAN` dùng `han_mot_lan`; `CHIA_DOT` nhưng `lich == []` rơi về hành vi `MOT_LAN`.
- [ ] **Step 2: Run to verify fail** → FAIL (thiếu hàm).
- [ ] **Step 3: Implement** bốn hàm trên. `luy_ke` các đợt trước cuối = `_lam_tron(phai_nop * Σty_le / 100)`; đợt cuối = `phai_nop`. `da_dong = thuc_thu >= luy_ke`. `dot_cua_hoc_ky` trả `[]` khi số đợt ≠ 3.
- [ ] **Step 4: Verify** pass cả file.
- [ ] **Step 5: Commit** `feat(tuition): lịch đợt dẫn xuất và hạn quá hạn theo đợt`.

---

### Task 3: API cấu hình 3 đợt (KT)

**Files:**
- Modify: `backend/apps/tuition/serializers.py`, `backend/apps/tuition/views.py`, `backend/config/api_urls.py:71` (thêm cạnh `tuition/my/`)
- Test: `backend/apps/tuition/tests/test_installments.py`

**Interfaces:**
- Consumes: `dot_cua_hoc_ky`, `chon_hoc_ky`, `write_audit`, `IsKeToan`.
- Produces:
  - `InstallmentSerializer(thu_tu: int 1..3, ty_le: Decimal(5,2) >0, han_dong: date)`; `InstallmentsPutSerializer(dots=InstallmentSerializer(many=True))` — validate đúng 3 phần tử với `thu_tu` = {1,2,3}, Σ`ty_le` = 100, `han_dong` tăng ngặt theo `thu_tu`; lỗi theo kiểu `serializers.ValidationError({"dots": [...]})`.
  - `InstallmentsView` (`APIView`, `IsKeToan`): `GET /api/tuition/installments/?hoc_ky=` → `{"hoc_ky": id, "dots": [{thu_tu, ty_le, han_dong}, ...]}` (`[]` nếu chưa cấu hình); `PUT` cùng đường dẫn, body `{"dots": [...]}`, thay cả 3 đợt trong `transaction.atomic`, ghi `write_audit(request, HanhDong.UPDATE, "TuitionInstallment", f"hk{hoc_ky.id}", {"dots": [...]})`, trả như GET.

- [ ] **Step 1: Write failing tests** (`kt` fixture `login_as(UserFactory(role=Role.KE_TOAN))` như `test_tuition.py:38`):
  - `test_put_ba_dot_hop_le_roi_get`: PUT 40/30/30 hạn tăng dần → `200`; GET trả đúng 3 đợt; có đúng một `AuditLog` với `doi_tuong == "TuitionInstallment"`.
  - `test_put_tong_khac_100_bi_tu_choi`: 40/30/20 → `400`.
  - `test_put_thieu_dot_hoac_han_khong_tang_bi_tu_choi`: 2 đợt → `400`; hạn đợt 2 ≤ hạn đợt 1 → `400`.
  - `test_put_hai_lan_thay_the_khong_nhan_doi`: PUT hai lần → `TuitionInstallment.objects.filter(hoc_ky=hk).count() == 3`.
  - `test_chi_ke_toan_duoc_cau_hinh`: SV, PĐT → `403` ở GET và PUT.
- [ ] **Step 2: Run to verify fail** → `404`/FAIL.
- [ ] **Step 3: Implement** serializer, view, thêm `path("tuition/installments/", tuition.InstallmentsView.as_view())` vào `api_urls.py`.
- [ ] **Step 4: Verify** pass; `ruff check .` sạch.
- [ ] **Step 5: Commit** `feat(tuition): API cấu hình 3 đợt học phí`.

---

### Task 4: Đổi hình thức + lịch đợt trong `tuition/my`, quá hạn theo đợt

**Files:**
- Modify: `backend/apps/tuition/views.py` (`_hang` ~dòng 77, `_rows` ~dòng 117, `MyTuitionView`, `TuitionDetailView`), `backend/apps/tuition/serializers.py`, `backend/apps/tuition/services.py` (`thong_bao_qua_han`), `backend/config/api_urls.py`
- Test: `backend/apps/tuition/tests/test_installments.py`

**Interfaces:**
- Consumes: `dot_cua_hoc_ky`, `lich_dot`, `dot_tiep_theo`, `han_va_qua_han` (Task 2).
- Produces:
  - `_hang(...)` nhận thêm `dots=()`; dòng kết quả thêm `hinh_thuc`; `han_dong` và `qua_han` lấy từ `han_va_qua_han`. `_rows` nạp `dot_cua_hoc_ky(hoc_ky.id)` một lần cho cả lô.
  - `TuitionRowSerializer` thêm `hinh_thuc` (CharField). `MyTuitionSerializer` thêm `cac_dot` (list `{thu_tu, han_dong, phai_nop, luy_ke, da_dong}`) và `dot_tiep_theo` (`{thu_tu, can_dong}` hoặc `null`).
  - `MyPlanView` (`APIView`, `IsSinhVien`): `PATCH /api/tuition/my/plan/?hoc_ky=` body `{"hinh_thuc": "MOT_LAN" | "CHIA_DOT"}` → `200` `{"hinh_thuc": ...}`. Lỗi `TRANG_THAI_KHONG_HOP_LE` (`400`) khi không có `Tuition` `DA_TINH` của SV ở học kỳ đó, hoặc chọn `CHIA_DOT` khi `dot_cua_hoc_ky` rỗng.
  - `thong_bao_qua_han`: xét mọi học kỳ có `TuitionConfig.han_dong < hôm nay` **hoặc** có `TuitionInstallment.han_dong < hôm nay`; điều kiện báo = `han_va_qua_han(...)[1]`; câu thông báo dùng hạn trả về.

- [ ] **Step 1: Write failing tests:**
  - `test_my_chia_dot_tra_ba_dot_va_dot_tiep_theo`: `Tuition.hinh_thuc="CHIA_DOT"`, 3 đợt 40/30/30, `phai_nop=1000`, đã `Payment` THU 500 → `GET /api/tuition/my/?hoc_ky=` có `hinh_thuc == "CHIA_DOT"`, `[d["da_dong"] for d in cac_dot] == [True, False, False]`, `dot_tiep_theo == {"thu_tu": 2, "can_dong": "200.00"}`.
  - `test_my_mot_lan_van_thay_lich_nhung_khong_co_dot_tiep_theo`: `MOT_LAN` + học kỳ đủ 3 đợt → `len(cac_dot) == 3` và `dot_tiep_theo is None`; học kỳ chưa cấu hình đợt → `cac_dot == []`. (Quy ước: `cac_dot` luôn trả lịch khi học kỳ đủ 3 đợt để SV xem trước khi chọn; `dot_tiep_theo` chỉ có khi `CHIA_DOT`.)
  - `test_plan_doi_giua_chung_khong_doi_con_no`: đã thu 500, PATCH `MOT_LAN` → `CHIA_DOT` → `con_no` trước/sau bằng nhau.
  - `test_plan_chia_dot_khi_chua_cau_hinh_bi_tu_choi`: không có đợt → `400`, `error.code == "TRANG_THAI_KHONG_HOP_LE"` (xem cấu trúc envelope ở `core.exceptions`).
  - `test_plan_khong_co_hoc_phi_bi_tu_choi`; `test_plan_chi_sinh_vien`: KT `403`.
  - `test_danh_sach_kt_qua_han_theo_dot`: `CHIA_DOT`, đợt 1 hạn hôm qua, chưa thu → dòng có `qua_han is True` và `han_dong` = hạn đợt 1.
  - `test_job_qua_han_bao_theo_dot`: cùng tình huống, `thong_bao_qua_han()` trả `1` và gọi lần hai trả `0`.
- [ ] **Step 2: Run to verify fail.**
- [ ] **Step 3: Implement** theo Interfaces; thêm `path("tuition/my/plan/", tuition.MyPlanView.as_view())` vào `api_urls.py` (cạnh `tuition/my/`, trước `tuition/<int:pk>/`).
- [ ] **Step 4: Verify:** `pytest apps/tuition -q` toàn bộ PASS (các test cũ của `qua_han`, `han_dong` vẫn xanh).
- [ ] **Step 5: Commit** `feat(tuition): đổi hình thức đóng và lịch đợt trong học phí của tôi`.

---

### Task 5: Mô-đun VNPay (ký, kiểm, dựng URL) + cấu hình

**Files:**
- Create: `backend/apps/tuition/vnpay.py`
- Modify: `backend/config/settings/base.py` (cạnh khối `env(...)`), `backend/.env.example`
- Test: `backend/apps/tuition/tests/test_vnpay.py`

**Interfaces:**
- Produces (settings, đọc bằng `env()` có sẵn): `VNPAY_TMN_CODE=""`, `VNPAY_HASH_SECRET=""`, `VNPAY_URL="https://sandbox.vnpayment.vn/paymentv2/vpcpay.html"`, `VNPAY_RETURN_URL="http://localhost:8000/api/tuition/vnpay/return/"`, `APP_RESULT_URL="http://localhost:8080/student/tuition/pay-result"`.
- Produces (`vnpay.py`, chỉ dùng `django.conf.settings`, `hmac`, `hashlib`, `urllib.parse`):
  - `da_cau_hinh() -> bool` — cả `VNPAY_TMN_CODE` và `VNPAY_HASH_SECRET` khác rỗng.
  - `ky(params: Mapping[str, str]) -> str` — chữ ký theo Global Constraints (bỏ `vnp_SecureHash`, `vnp_SecureHashType`).
  - `kiem_chu_ky(params: Mapping[str, str]) -> bool` — so `params["vnp_SecureHash"]` với `ky(params)` bằng `hmac.compare_digest`; `False` nếu thiếu.
  - `tao_url(txn_ref: str, so_tien: Decimal, order_info: str, ip: str, now: datetime) -> str` — đủ tham số bắt buộc theo spec mục 5, `now` là aware datetime (đổi sang giờ VN), kèm `vnp_SecureHash`; không gửi `vnp_BankCode`.

- [ ] **Step 1: Write failing tests** (`settings` fixture của pytest-django đặt `VNPAY_TMN_CODE="TESTTMN1"`, `VNPAY_HASH_SECRET="secret"`):
  - `test_ky_khop_vector_tu_tinh`: `ky({"vnp_Command": "pay", "vnp_Amount": "1000000", "vnp_OrderInfo": "HOCPHI SV01 HK1"}) == hmac.new(b"secret", b"vnp_Amount=1000000&vnp_Command=pay&vnp_OrderInfo=HOCPHI+SV01+HK1", hashlib.sha512).hexdigest()` (chuỗi ký viết tay trong test, không gọi hàm của module).
  - `test_ky_bo_qua_truong_chu_ky`: thêm `vnp_SecureHash`/`vnp_SecureHashType` không đổi kết quả.
  - `test_kiem_chu_ky_dung_sai_va_thieu`: đúng → `True`; đổi một ký tự giá trị → `False`; không có `vnp_SecureHash` → `False`.
  - `test_tao_url_co_du_tham_so`: parse query của kết quả: `vnp_Amount == "100000000"` khi `so_tien=D("1000000")`, `vnp_TxnRef`, `vnp_ExpireDate == "20261025101500"` khi `now` = 25/10/2026 10:00 giờ VN, `vnp_Version == "2.1.0"`, `vnp_Command == "pay"`, không có `vnp_BankCode`; `kiem_chu_ky(dict)` của các tham số parse được → `True`.
  - `test_da_cau_hinh`: có/không key.
- [ ] **Step 2: Run to verify fail.**
- [ ] **Step 3: Implement** `vnpay.py`, settings, và thêm năm khóa vào `.env.example` (key để trống, kèm comment đường đăng ký `http://sandbox.vnpayment.vn/devreg/`).
- [ ] **Step 4: Verify** pass.
- [ ] **Step 5: Commit** `feat(tuition): mô-đun ký và dựng URL VNPay`.

---

### Task 6: API tạo giao dịch thanh toán + xem trạng thái

**Files:**
- Modify: `backend/apps/tuition/services.py`, `serializers.py`, `views.py`, `config/api_urls.py`
- Test: `backend/apps/tuition/tests/test_vnpay.py`

**Interfaces:**
- Consumes: `vnpay.da_cau_hinh`, `vnpay.tao_url`, `dan_xuat_cua`, `dot_cua_hoc_ky`, `lich_dot`, `dot_tiep_theo`.
- Produces:
  - `services.tao_giao_dich_vnpay(sv_user: User, hoc_ky: Semester, muc: str, so_tien: Decimal | None, ip: str) -> tuple[OnlineTransaction, str]` — trả `(txn, payment_url)`. Quy tắc: `Tuition` phải `DA_TINH` và `con_no > 0` (`TRANG_THAI_KHONG_HOP_LE`); chưa `da_cau_hinh()` → `ValidationError({"vnpay": ["Chưa cấu hình cổng thanh toán VNPay."]})` (`400`); `muc="TOAN_BO"` → `con_no`; `"DOT_TIEP"` → `min(can_dong, con_no)` khi `CHIA_DOT` có lịch, ngược lại `con_no`; `"TUY_Y"` cần `0 < so_tien <= con_no` (`SO_TIEN_KHONG_HOP_LE`). `order_info = f"HOCPHI {ma_sv} HK{hoc_ky.id}"`.
  - `MyPayView` (`IsSinhVien`) `POST /api/tuition/my/pay/?hoc_ky=` body `{"muc": "DOT_TIEP"|"TOAN_BO"|"TUY_Y", "so_tien"?: decimal}` → `201` `{"payment_url", "txn_ref" (hex), "so_tien"}`; `ip = core.utils.client_ip(request)`.
  - `MyPayStatusView` (`IsSinhVien`) `GET /api/tuition/my/pay/<str:txn_ref>/` → `{"txn_ref", "trang_thai", "so_tien"}`; không tồn tại **hoặc thuộc SV khác** → `404`.

- [ ] **Step 1: Write failing tests** (fixture `settings` đặt key giả; SV có `Tuition` `DA_TINH`, `tong_tien=1000`):
  - `test_pay_toan_bo`: `muc="TOAN_BO"` → `201`; tạo đúng một `OnlineTransaction` `CHO` với `so_tien == 1000`; `payment_url` bắt đầu bằng `settings.VNPAY_URL`, chứa `vnp_Amount=100000`.
  - `test_pay_dot_tiep_chia_dot`: `CHIA_DOT` 40/30/30, chưa thu → `so_tien == 400`; đã thu 400 → `300`.
  - `test_pay_dot_tiep_mot_lan_bang_con_no`.
  - `test_pay_tuy_y_vuot_con_no_hoac_khong_duong_bi_tu_choi`: `so_tien` 1001, 0, thiếu → `400`, mã `SO_TIEN_KHONG_HOP_LE` (hoặc lỗi field khi thiếu).
  - `test_pay_khi_phai_nop_bang_0_bi_tu_choi`: miễn giảm 100% → `400` `TRANG_THAI_KHONG_HOP_LE`, không tạo giao dịch.
  - `test_pay_chua_cau_hinh_vnpay_tra_400`: để trống key → `400`, không `500`, không tạo giao dịch.
  - `test_pay_chua_tinh_hoc_phi_bi_tu_choi` (`CHUA_TINH`).
  - `test_status_cua_toi_va_cua_nguoi_khac`: SV A tạo giao dịch; A `GET` → `200` `trang_thai == "CHO"`; SV B `GET` → `404`; txn_ref bậy → `404`.
  - `test_pay_chi_sinh_vien`: KT `403`.
- [ ] **Step 2: Run to verify fail.**
- [ ] **Step 3: Implement**; thêm hai `path(...)` vào `api_urls.py` trước `tuition/<int:pk>/`.
- [ ] **Step 4: Verify** `pytest apps/tuition -q` PASS.
- [ ] **Step 5: Commit** `feat(tuition): tạo giao dịch VNPay và xem trạng thái`.

---

### Task 7: Xác nhận kết quả VNPay (return + IPN)

**Files:**
- Modify: `backend/apps/tuition/services.py`, `views.py`, `config/api_urls.py`
- Test: `backend/apps/tuition/tests/test_vnpay.py`

**Interfaces:**
- Consumes: `vnpay.kiem_chu_ky`, `ghi_thanh_toan(kt, tuition_id, loai, so_tien, phuong_thuc, request_id)` (`services.py:185`; truyền chính SV làm `kt`, `request_id=txn.txn_ref`), `AuditLog.objects.create` (không có `request` trong callback nên ghi trực tiếp, `user=txn.tuition.sinh_vien`, `hanh_dong=HanhDong.UPDATE`, `doi_tuong="OnlineTransaction"`).
- Produces:
  - `services.xac_nhan_vnpay(params: Mapping[str, str]) -> tuple[str, OnlineTransaction | None]` — trả `(rsp_code, txn)`. Thứ tự: sai chữ ký → `("97", None)`; không thấy `vnp_TxnRef` (parse `uuid.UUID(hex)`, lỗi parse cũng là không thấy) → `("01", None)`; `int(vnp_Amount) != int(txn.so_tien * 100)` → `("04", txn)` không đổi trạng thái; trong `transaction.atomic` + `select_for_update` trên `OnlineTransaction`: đã khác `CHO` → `("02", txn)`; thành công theo Global Constraints → `ghi_thanh_toan(..., PhuongThuc.VNPAY, ...)`, `THANH_CONG`, lưu `vnp_transaction_no`, `ket_thuc_luc`; nếu `ghi_thanh_toan` ném `BusinessError` → `LOI` + audit; không thành công → `THAT_BAI`. Mọi nhánh đã xử lý trả `("00", txn)`. Lỗi không lường trước → `("99", None)`.
  - `VnpayIpnView` (`APIView`, `authentication_classes = []`, `permission_classes = [AllowAny]`) `GET /api/tuition/vnpay/ipn/` → JSON `{"RspCode", "Message"}` (thông điệp theo Global Constraints).
  - `VnpayReturnView` (cùng quyền) `GET /api/tuition/vnpay/return/` → `HttpResponseRedirect(f"{settings.APP_RESULT_URL}?status={s}&txn={hex}")` với `s` ∈ `thanh_cong` (`THANH_CONG`), `that_bai`, `loi`, `sai_chu_ky` (rsp `97`), `khong_hop_le` (các rsp còn lại); `txn` bỏ trống khi không có giao dịch.

- [ ] **Step 1: Write failing tests** (helper `ky_callback(txn, code="00", status="00", amount=None)` dựng `params` đúng chữ ký bằng `vnpay.ky`):
  - `test_ipn_thanh_cong_ghi_mot_payment`: IPN hợp lệ → `{"RspCode": "00"}`; `txn.trang_thai == "THANH_CONG"`; đúng một `Payment` `THU`, `phuong_thuc == "VNPAY"`, `nguoi_thu == sv.user`, `request_id == txn.txn_ref`; `con_no` giảm đúng `so_tien`.
  - `test_return_va_ipn_hai_lan_chi_mot_payment`: return → IPN → return, `Payment.objects.count() == 1`; lần sau `RspCode == "02"`; return redirect `status=thanh_cong`.
  - `test_sai_chu_ky_bi_tu_choi`: đổi `vnp_Amount` sau khi ký → `97`, không đổi trạng thái, không `Payment`.
  - `test_so_tien_lech_nhung_chu_ky_dung`: ký lại với `vnp_Amount` sai → `04`, giao dịch vẫn `CHO`, không `Payment`.
  - `test_tham_so_vnp_la_van_nam_trong_chu_ky`: thêm `vnp_Extra=1` đã ký → vẫn xử lý được; thêm sau khi ký → `97`.
  - `test_that_bai_khi_response_code_khac_00`: `vnp_ResponseCode="24"` → `THAT_BAI`, không `Payment`; `vnp_TransactionStatus="02"` cùng `ResponseCode="00"` → `THAT_BAI`.
  - `test_con_no_giam_giua_chung_danh_dau_loi`: sau khi tạo giao dịch 1000, KT thu tiền mặt 500 (qua `ghi_thanh_toan`) → callback thành công → `trang_thai == "LOI"`, không có `Payment` VNPAY, có `AuditLog` `doi_tuong="OnlineTransaction"`.
  - `test_khong_thay_giao_dich`: `vnp_TxnRef` ngẫu nhiên và chuỗi không phải hex → `01`.
  - `test_return_redirect_sai_chu_ky`: `status=sai_chu_ky`.
  - `test_callback_khong_can_dang_nhap`: client không token vẫn nhận `200` (IPN) / `302` (return).
- [ ] **Step 2: Run to verify fail.**
- [ ] **Step 3: Implement**; thêm `path("tuition/vnpay/ipn/", ...)`, `path("tuition/vnpay/return/", ...)` vào `api_urls.py`.
- [ ] **Step 4: Verify:** `pytest -q` toàn bộ backend PASS; `ruff check .`, `black --check .` sạch.
- [ ] **Step 5: Commit** `feat(tuition): xác nhận kết quả VNPay qua return URL và IPN`.

---

### Task 8: Flutter — KT cấu hình 3 đợt

**Files:**
- Modify: `dang_ky_mon_hoc/lib/features/tuition/tuition_config_screen.dart` (thêm tab và widget `_ChiaDot`, cạnh `_HanDong` ở dòng ~63)
- Test: `dang_ky_mon_hoc/test/tuition_test.dart` (thêm nhóm test, dùng `FakeAdapter`/`reply`/`tapText`/`enterField` như hiện có)

**Interfaces:**
- Consumes: `GET/PUT /tuition/installments/?hoc_ky=<id>` (Task 3), `trainingApiProvider` (`get`, `put(path, body)`), `TabsRow`, `LabeledField`, widget chọn học kỳ/ngày có sẵn trong `entity_form.dart`.
- Produces: tab thứ 4 `'Chia đợt'` trong `TuitionConfigScreen`; `_ChiaDot` gồm chọn học kỳ, 3 hàng (Đợt 1..3: ô `Tỷ lệ (%)` và ô ngày `Hạn đóng`), dòng tổng `Tổng: X%`, nút `Lưu 3 đợt` vô hiệu khi tổng ≠ 100 hoặc thiếu ngày hoặc hạn không tăng dần. Lưu gọi `put('/tuition/installments/?hoc_ky=$id', {'dots': [{'thu_tu','ty_le','han_dong'}...]})`, thành công hiện `showAppToast(context, 'Đã lưu 3 đợt.')`.

- [ ] **Step 1: Write failing widget tests:** (a) mở tab `Chia đợt`, học kỳ đã có 3 đợt → ba ô tỷ lệ hiển thị `40`, `30`, `30` và `Tổng: 100%`; (b) sửa đợt 3 thành `20` → `Tổng: 90%` và nút `Lưu 3 đợt` bị vô hiệu; (c) sửa đợt 2/3 thành `35`/`25`, bấm lưu → request `PUT /tuition/installments/` có body `dots` đủ 3 phần tử tỷ lệ `40, 35, 25`.
- [ ] **Step 2: Run:** `flutter test test/tuition_test.dart` → FAIL.
- [ ] **Step 3: Implement** theo Interfaces, dùng widget/khoảng cách/màu sẵn có (không thêm theme).
- [ ] **Step 4: Verify:** `flutter test test/tuition_test.dart` PASS; `flutter analyze` sạch.
- [ ] **Step 5: Commit** `feat(app): kế toán cấu hình 3 đợt học phí`.

---

### Task 9: Flutter — SV chọn hình thức, xem đợt, thanh toán VNPay bằng QR

**Files:**
- Modify: `dang_ky_mon_hoc/pubspec.yaml` (thêm `url_launcher: ^6.3.0`), `dang_ky_mon_hoc/lib/features/tuition/student_tuition_screen.dart` (thay thân `_StudentPayScreenState`, bỏ `_copyRow`/`_copy` nếu hết dùng), `dang_ky_mon_hoc/lib/core/router/routes_student.dart` (cạnh route `/student/tuition/pay`, dòng ~75)
- Test: `dang_ky_mon_hoc/test/tuition_test.dart` (viết lại 3 test QR chuyển khoản ở nhóm `Sinh viên — học phí`, dòng ~446–497)

**Interfaces:**
- Consumes: `GET /tuition/my/` (thêm `hinh_thuc`, `cac_dot`, `dot_tiep_theo`), `PATCH /tuition/my/plan/`, `POST /tuition/my/pay/`, `GET /tuition/my/pay/<txn_ref>/` (Task 4, 6); `QrImageView`, `launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`.
- Produces:
  - `StudentPayScreen` mới: (1) thẻ công nợ + `ChoiceChip` `Đóng một lần` / `Chia 3 đợt` (gọi PATCH rồi tải lại; chip `Chia 3 đợt` vô hiệu kèm chú thích khi `cac_dot` rỗng); (2) khi `cac_dot` không rỗng: bảng 3 đợt (Đợt n, hạn, số tiền, `Đã đóng`/`Chưa đóng`); (3) chọn mức `Đợt tiếp theo` (chỉ khi `dot_tiep_theo != null`) / `Toàn bộ công nợ` / `Số tiền khác` (ô nhập ≤ `con_no`); (4) nút `Tạo mã thanh toán` → POST; hiện `QrImageView(key: ValueKey('qr'), data: payment_url)`, nút `Mở trang thanh toán VNPay`, dòng `Đang chờ thanh toán…`; (5) `Timer.periodic(3s)` poll `GET /tuition/my/pay/<txn_ref>/` tới khi `trang_thai != 'CHO'` rồi tải lại dữ liệu và hiện kết quả; hủy timer trong `dispose`.
  - `StudentPayResultScreen` (route `/student/tuition/pay-result`, đọc query `status`, `txn`): thông báo theo `status` (`thanh_cong` → `Thanh toán thành công.`, `that_bai` → `Thanh toán không thành công.`, `loi` → `Đã nhận tiền nhưng chưa ghi được học phí, vui lòng liên hệ Phòng Kế toán.`, khác → `Kết quả thanh toán không hợp lệ.`) và nút `← Quay lại học phí`.
  - Kiểm tra chiến lược URL của router (`grep -n usePathUrlStrategy dang_ky_mon_hoc/lib`) và chỉnh mặc định `APP_RESULT_URL` ở `backend/config/settings/base.py` cho khớp.

- [ ] **Step 1: Write failing widget tests** (cập nhật helper `my(...)` thêm `hinh_thuc`, `cac_dot`, `dot_tiep_theo`; bỏ khóa `thanh_toan` không cần nữa):
  - `trang thanh toán: đổi sang Chia 3 đợt gọi PATCH rồi hiện 3 đợt`.
  - `chưa cấu hình đợt: chip Chia 3 đợt bị vô hiệu`.
  - `tạo mã: bấm Tạo mã thanh toán sinh QR chứa payment_url` — `POST /tuition/my/pay/` trả `{'payment_url': 'https://sandbox.vnpayment.vn/x', 'txn_ref': 'abc', 'so_tien': '1000000.00'}`; `find.byType(QrImageView)` có `data == 'https://sandbox.vnpayment.vn/x'`; body POST có `muc`.
  - `poll: khi trạng thái chuyển THANH_CONG hiện Thanh toán thành công` — `tester.pump(const Duration(seconds: 3))`, `GET /tuition/my/pay/abc/` đổi từ `CHO` sang `THANH_CONG`; không còn timer treo khi kết thúc test.
  - `Số tiền khác vượt công nợ → lỗi, nút Tạo mã bị vô hiệu` (giữ logic cũ của test "một phần").
  - `không còn công nợ: thông báo, không QR` (giữ).
  - `trang kết quả: status=thanh_cong và status=that_bai hiện đúng thông báo`.
- [ ] **Step 2: Run:** `flutter test test/tuition_test.dart` → FAIL.
- [ ] **Step 3: Implement**; `flutter pub get`; đăng ký route kết quả.
- [ ] **Step 4: Verify:** `flutter test` (toàn bộ) PASS; `flutter analyze` sạch.
- [ ] **Step 5: Commit** `feat(app): sinh viên chọn hình thức đóng và thanh toán VNPay bằng QR`.

---

### Task 10: Tài liệu + kiểm tra cuối

**Files:**
- Modify: `plan.md` (mục 1 bảng quyết định dòng ~31; BR-26; mô tả `Tuition`/`Payment`; thêm model `TuitionInstallment`, `OnlineTransaction`; bảng API), `chuc_nang.md` (SV-12, bảng API ~dòng 488–517), `docs/superpowers/specs/2026-10-25-dong-hoc-phi-vnpay-design.md` (trạng thái → "đã triển khai")
- Không có test mới.

- [ ] **Step 1:** Cập nhật `plan.md` và `chuc_nang.md`: bỏ câu "Cổng thanh toán online tự động đối soát" khỏi danh sách không làm, ghi VNPay sandbox + chia đợt, thêm 6 endpoint mới và hai model mới.
- [ ] **Step 2:** `cd backend && .venv312/Scripts/pytest -q` → toàn bộ PASS; `.venv312/Scripts/ruff check .` và `.venv312/Scripts/black --check .` sạch; `.venv312/Scripts/mypy .` không thêm lỗi mới so với trước (chạy `git stash` để so nếu có lỗi).
- [ ] **Step 3:** `cd dang_ky_mon_hoc && flutter test && flutter analyze` → PASS, sạch.
- [ ] **Step 4 (cần người dùng, không tự chạy được):** sau khi có key sandbox, đặt vào `backend/.env`, chạy backend + Web, tạo giao dịch, mở `payment_url`, trả bằng thẻ NCB test (`9704198526191432198`, `NGUYEN VAN A`, `07/15`, OTP `123456`), xác nhận `Payment` `VNPAY` xuất hiện và học phí cập nhật; thử cả `vnp_BankCode=VNPAYQR`. Ghi kết quả vào mục 9 của spec.
- [ ] **Step 5: Commit** `docs: cập nhật plan/chuc_nang cho chia đợt và VNPay` (kèm spec và plan này nếu chưa commit).
