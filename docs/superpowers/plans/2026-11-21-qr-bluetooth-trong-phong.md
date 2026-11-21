# QR + Bluetooth (hai mã) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bước "trong phòng" cần mã QR (màn GV) + mã Bluetooth (chỉ ESP32 phát); thiếu Bluetooth thì lượt thành đáng ngờ.

**Architecture:** `room_token` sinh hai kênh mã từ cùng bí mật phiên. Server kiểm mã QR + (tùy chọn) mã BLE lúc cấp thử thách, lưu `Challenge.co_bluetooth`; `diem_danh` thêm cờ `KHONG_BLUETOOTH`. GV hiện QR và đẩy mã BLE xuống ESP32; SV quét QR (`mobile_scanner`) rồi dò BLE.

**Tech Stack:** Django/DRF + pytest; Flutter (Riverpod, `qr_flutter`, `mobile_scanner` 7.5.0, `flutter_blue_plus`).

**Spec:** `docs/superpowers/specs/2026-11-21-qr-bluetooth-trong-phong-design.md`

## Global Constraints
- Mã QR giữ nguyên cách sinh cũ (`f"{session_id}|{window}"`); mã BLE: `f"ble|{session_id}|{window}"`. Cùng cửa sổ `room_token_window_s` (30), nhận cửa sổ hiện tại + trước.
- Sai/thiếu mã QR → `MA_PHONG_SAI`, sai mã BLE (có gửi) → `MA_BLUETOOTH_SAI`; cả hai không tính lượt.
- Firmware ESP32 không sửa (mã BLE 8 ký tự ≤ 20).
- Backend test chạy: container tạm, `env -u GPS_MAX_ACC_SV_M -u GPS_MAX_ACC_GV_M python -m pytest apps/attendance`.

## Review Focus
- Mã BLE dán vào ô mã QR → phải bị từ chối `MA_PHONG_SAI` (hai kênh không lẫn) → test Task 1.
- Phiên tắt "Bắt mã phòng" → không đòi mã nào, không gắn cờ `KHONG_BLUETOOTH` → test Task 1.
- SV hủy hộp quét QR → ở lại bước, không gọi API → test Task 3.
- Bluetooth không hỗ trợ (iPhone) → không tự dò, hiện "Tiếp tục không có Bluetooth" → test Task 3.
- `ma_bluetooth` gửi chuỗi rỗng → coi như không gửi (đáng ngờ), không lỗi → test Task 1.

---

### Task 1: Server — mã BLE, thử thách, cờ
**Files:** Modify `backend/apps/attendance/room_token.py`, `models.py` (Challenge.co_bluetooth), new migration `0008_challenge_co_bluetooth.py`, `tu_diem_danh.py` (`ma_phong`, `xin_thu_thach`, `diem_danh`, `LY_DO`), `views_tu_diem_danh.py` (ThuThachSerializer). Test: `apps/attendance/tests/test_room_token.py`, `test_tu_diem_danh.py`.

**Interfaces — Produces:**
- `room_code(secret, session_id, t, window_s=30, kenh="qr")`, `verify_room_code(code, secret, session_id, now, window_s=30, kenh="qr")`.
- `GET room-token/` → `{"ma", "ma_ble", "het_han_sau_giay"}`.
- `POST challenge/` body `{"ma_phong", "ma_bluetooth"?}`; response thêm `"co_bluetooth": bool`.
- Cờ lượt `"KHONG_BLUETOOTH"`; lý do `LY_DO["MA_BLUETOOTH_SAI"]`.

- [ ] Test: `test_hai_kenh_ma_khac_nhau` (room_token): `room_code(..., kenh="ble") != room_code(...)`, mã BLE không qua `verify_room_code` kênh qr và ngược lại.
- [ ] Test: `test_qr_va_bluetooth_du_hai_ma_co_mat`: mã QR + mã BLE → 201 `co_bluetooth=True`, checkin `CO_MAT`.
- [ ] Test: `test_thieu_bluetooth_thanh_dang_ngo`: chỉ mã QR (và `ma_bluetooth=""`) → 201 `co_bluetooth=False`, checkin `DANG_NGO` với `"KHONG_BLUETOOTH" in luot.co`.
- [ ] Test: `test_ma_bluetooth_sai_hoac_dan_nham_kenh`: BLE sai → 409 `MA_BLUETOOTH_SAI`; mã BLE vào `ma_phong` → 409 `MA_PHONG_SAI`; `Challenge` rỗng.
- [ ] Test: phiên tắt phòng → không có cờ `KHONG_BLUETOOTH` (sửa/khẳng định test có sẵn).
- [ ] Chạy → FAIL; implement; chạy toàn bộ `apps/attendance` → PASS; ruff.

### Task 2: GV — QR + đẩy mã BLE
**Files:** Modify `dang_ky_mon_hoc/lib/features/attendance/tu_diem_danh/gv_buoi_panel.dart` (`_MaPhongState`), `tu_diem_danh_text.dart` (nhãn cờ). Test: `test/tu_diem_danh_test.dart`.
**Consumes:** `room-token/` `{ma, ma_ble}`.
- [ ] `_MaPhong` lưu `_ma` (QR) và `_maBle`; `_gui()` đẩy `_maBle`; hiện `QrImageView(data: _ma, size: 220)` + chữ mã QR.
- [ ] Nhãn `'KHONG_BLUETOOTH': 'Không xác nhận Bluetooth'`.
- [ ] Test widget: phiên bật mã phòng → thấy `QrImageView` và chữ mã QR.

### Task 3: SV — quét QR, Bluetooth, tiếp tục không BT
**Files:** Create `dang_ky_mon_hoc/lib/features/attendance/tu_diem_danh/quet_qr.dart` (`quetQrProvider`: `Future<String?> Function(BuildContext)`; mặc định dialog `MobileScanner`). Modify `sv_tu_diem_danh_screen.dart`, `pubspec.yaml`, `AndroidManifest.xml` (đã có CAMERA). Test: `test/tu_diem_danh_test.dart`.
**Consumes:** `docEsp32Provider`; `POST challenge/` từ Task 1.
- [ ] Hai dòng bước: "Mã QR trên màn chiếu", "Bluetooth (gần máy giảng viên)". Thứ tự GPS → QR → BT → thử thách.
- [ ] Bước QR: nút "Quét QR" (gọi `quetQrProvider`, null = hủy, ở lại) + ô gõ mã + "Tiếp tục".
- [ ] Bước BT: tự dò (tuDong), nút "Kiểm tra Bluetooth (chọn thiết bị)" (web), "Dò lại"; khi không đạt/không hỗ trợ: nút "Tiếp tục không có Bluetooth" + cảnh báo "lượt sẽ chờ giảng viên duyệt".
- [ ] Gửi `{'ma_phong': qr, 'ma_bluetooth': ble}` (bỏ khóa khi không có BLE). Lỗi `MA_BLUETOOTH_SAI` → ở lại bước BT.
- [ ] Tests: Android đủ hai mã → body đúng, ✓ cả hai; không hỗ trợ BT → nút tiếp tục → body không có `ma_bluetooth`; hủy quét QR → không gọi challenge; gõ tay mã QR vẫn chạy.

### Task 4: Kiểm tra & tài liệu
- [ ] `flutter analyze`, `flutter test`, `flutter build web`, `flutter build apk --debug`; backend toàn bộ `apps/attendance`.
- [ ] Cập nhật `docs/ke-hoach-gps-khuon-vien-va-esp32.md` §4; rebuild `web worker beat`, chạy migration.
