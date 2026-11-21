import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_chip.dart';

/// Cờ của một lượt (server `CheckinAttempt.co`) → chữ cho GV.
const coText = {
  'LECH_NHE': 'Sát mép khuôn viên',
  'SAT_NGUONG': 'Mặt sát ngưỡng',
  'VI_TRI_GIA': 'Vị trí giả',
  'BUOC_NHAY': 'Vị trí nhảy bất thường',
  'CUNG_MAY': 'Cùng máy với SV khác',
  'KHONG_BLUETOOTH': 'Không xác nhận Bluetooth',
};

/// Mã lý do dừng (server `CheckinAttempt.ly_do`) → chữ cho GV.
const lyDoText = {
  'MA_PHONG_SAI': 'Sai mã phòng',
  'MA_BLUETOOTH_SAI': 'Sai mã Bluetooth',
  'GPS_KEM': 'GPS kém',
  'QUA_XA': 'Ngoài khuôn viên',
  'CHUA_CO_KHUON_VIEN': 'Chưa vẽ khuôn viên',
  'KHONG_THAY_MAT': 'Không thấy mặt',
  'NHIEU_MAT': 'Nhiều người',
  'THIEU_SANG': 'Thiếu sáng',
  'ANH_MO': 'Ảnh mờ',
  'SAI_HANH_DONG': 'Sai hành động',
  'ANH_GIA': 'Ảnh giả / màn hình',
  'KHONG_KHOP': 'Mặt không khớp',
  'CHUA_CO_MAT': 'Chưa có mẫu mặt',
};

const hanhDongText = {
  'turn_left': 'Quay đầu sang trái',
  'turn_right': 'Quay đầu sang phải',
};

/// Trạng thái tự điểm danh: có mặt / đáng ngờ (vắng + cờ) / vắng có phép / chưa điểm danh.
Widget tuDiemDanhChip(String trangThai, bool dangNgo) => switch ((
  trangThai,
  dangNgo,
)) {
  ('CO_MAT', _) => StatusChip(
    'Có mặt',
    bg: AppColors.successBg,
    fg: AppColors.success,
  ),
  (_, true) => StatusChip(
    'Đáng ngờ',
    bg: AppColors.warnBannerBg,
    fg: AppColors.warnBannerText,
  ),
  ('VANG_CO_PHEP', _) => StatusChip(
    'Vắng có phép',
    bg: AppColors.infoBannerBg,
    fg: AppColors.infoBannerText,
  ),
  _ => StatusChip('Chưa điểm danh', bg: AppColors.divider, fg: AppColors.muted),
};

/// `mm:ss` còn lại tới [hetHan]; âm thì `00:00`.
String conLai(DateTime hetHan, DateTime now) {
  final s = hetHan.difference(now).inSeconds.clamp(0, 99 * 60);
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}
