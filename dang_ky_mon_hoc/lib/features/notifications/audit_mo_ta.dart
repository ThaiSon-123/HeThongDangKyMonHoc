import '../../core/format.dart';
import '../training/training_api.dart';
import '../tuition/money.dart' show formatVnd;

/// Tên tiếng Việt của đối tượng ghi trong nhật ký (`doi_tuong`).
const tenDoiTuong = {
  'Faculty': 'Khoa/viện',
  'Major': 'Ngành',
  'Curriculum': 'CTĐT',
  'CurriculumCourse': 'Môn trong CTĐT',
  'Course': 'Môn học',
  'Prerequisite': 'Tiên quyết',
  'Semester': 'Học kỳ',
  'ClassSection': 'Lớp học phần',
  'Schedule': 'Lịch học',
  'Registration': 'Đăng ký',
  'AttendanceSession': 'Buổi điểm danh',
  'AttendanceRequest': 'Yêu cầu sửa điểm danh',
  'Grade': 'Điểm',
  'HocPhanGia': 'Bảng giá',
  'TuitionConfig': 'Hạn đóng học phí',
  'TuitionInstallment': 'Chia đợt học phí',
  'Discount': 'Miễn giảm',
  'Payment': 'Thanh toán',
  'OnlineTransaction': 'Giao dịch VNPay',
  'Tuition': 'Học phí',
  'Notification': 'Thông báo',
  'User': 'Tài khoản',
  'StudentProfile': 'Hồ sơ SV',
  'TeacherProfile': 'Hồ sơ GV',
  'SystemConfig': 'Cấu hình hệ thống',
  'Backup': 'Sao lưu',
};

const _vaiTro = {
  'ADMIN': 'Quản trị viên',
  'PHONG_DAO_TAO': 'Phòng đào tạo',
  'SINH_VIEN': 'Sinh viên',
  'GIAO_VIEN': 'Giáo viên',
  'KE_TOAN': 'Kế toán',
};

const _cauHinh = {
  'max_absent_pct': 'Ngưỡng vắng tối đa (%)',
  'so_ngay_xin_sua_diem_danh': 'Số ngày được xin sửa điểm danh',
  'so_ngay_cho_phep_nhap_diem': 'Số ngày cho phép nhập điểm',
  'backup_retention_days': 'Số ngày giữ bản sao lưu',
  'ck_ngan_hang': 'Ngân hàng nhận chuyển khoản',
  'ck_so_tai_khoan': 'Số tài khoản nhận chuyển khoản',
  'ck_chu_tai_khoan': 'Chủ tài khoản nhận chuyển khoản',
};

const _viec = {'CREATE': 'Tạo', 'UPDATE': 'Cập nhật', 'DELETE': 'Xóa'};

/// Trường nào dùng làm "tên" để gọi đối tượng, theo thứ tự ưu tiên.
const _truongTen = [
  'ten_mon',
  'ten_khoa',
  'ten_nganh',
  'ten_hk',
  'ma_lop',
  'ho_ten',
  'username',
  'tieu_de',
  'ten_ctdt',
  'ma_ctdt',
  'ma_mon',
];

/// Mô tả một dòng nhật ký bằng câu tiếng Việt, không lộ tên trường kỹ thuật (`so_tien=…`).
/// Thiếu đối tượng thì `—`.
String moTaNhatKy(Json log) {
  final dt = log.str('doi_tuong');
  if (dt.isEmpty) return '—';
  final ct = log['chi_tiet'] is Map
      ? Json.from(log['chi_tiet'] as Map)
      : Json();
  return _suKien(log.str('hanh_dong'), dt, ct, log.str('doi_tuong_id')) ??
      _chung(log.str('hanh_dong'), dt, ct);
}

String _vnd(Object? v) => formatVnd(v);

String _ngay(Object? v) => formatYmd(v?.toString());

String _chuThuong(String s) =>
    s.length > 1 && s[1] == s[1].toUpperCase() && s[1] != s[1].toLowerCase()
    ? s // "CTĐT", "SV"… giữ nguyên
    : s[0].toLowerCase() + s.substring(1);

String _tenThuong(String dt) =>
    tenDoiTuong.containsKey(dt) ? _chuThuong(tenDoiTuong[dt]!) : dt;

String? _suKien(String hd, String dt, Json ct, String id) {
  switch (ct['hanh_dong']) {
    case 'luu_diem_danh':
      return 'Lưu điểm danh ${ct['so_dong']} sinh viên';
    case 'nhap_diem':
      return 'Lưu nháp điểm ${ct['so_dong']} sinh viên';
    case 'nhap_ho':
      return 'Nhập hộ điểm ${ct['so_dong']} sinh viên';
    case 'khoa_diem':
      return 'Khóa điểm ${ct['so_dong']} sinh viên';
    case 'mo_khoa_diem':
      return 'Mở khóa điểm ${ct['so_dong']} sinh viên';
    case 'duyet_diem':
      return 'Duyệt điểm ${ct['so_sinh_vien']} sinh viên';
    case 'gia_han_nhap_diem':
      final tu = ct['tu'] == null ? '' : ' từ ${_ngay(ct['tu'])}';
      return 'Gia hạn nhập điểm$tu đến ${_ngay(ct['den'])}';
    case 'thu_hoi':
      return 'Thu hồi thông báo';
    case 'tao_backup':
      return 'Tạo bản sao lưu dữ liệu';
    case 'reset_password':
      return 'Đặt lại mật khẩu tài khoản';
    case 'tinh_hang_loat':
      return 'Tính lại học phí cho ${ct['so_sv']} sinh viên';
    case 'doi_hinh_thuc':
      return 'Đổi hình thức đóng học phí sang '
          '${ct['hinh_thuc'] == 'CHIA_DOT' ? 'chia 3 đợt' : 'đóng một lần'}';
    case 'huy_dang_ky':
      final ai = _vaiTro[ct['boi']] ?? 'Sinh viên';
      final ly = ct.str('ly_do').trim();
      return '$ai hủy đăng ký${ly.isEmpty ? '' : ' — lý do: $ly'}';
  }
  switch (hd) {
    case 'LOGIN':
      return 'Đăng nhập hệ thống';
    case 'PHAN_QUYEN':
      final r = ct['role'];
      if (r is List && r.length == 2) {
        return 'Đổi vai trò từ ${_vaiTro[r[0]] ?? r[0]} sang ${_vaiTro[r[1]] ?? r[1]}';
      }
  }
  switch (dt) {
    case 'Registration':
      if (hd == 'CREATE') return 'Đăng ký lớp học phần';
    case 'User':
      if (ct.containsKey('is_locked')) {
        return ct['is_locked'] == true ? 'Khóa tài khoản' : 'Mở khóa tài khoản';
      }
    case 'Semester':
    case 'ClassSection':
      if (ct.length == 1 && ct.containsKey('trang_thai')) {
        const ten = {
          'MO': 'mở',
          'DONG': 'đóng',
          'KE_HOACH': 'kế hoạch',
          'DANG_HOC': 'đang học',
          'DA_DONG': 'đã đóng',
        };
        return 'Chuyển ${_tenThuong(dt)} sang trạng thái “${ten[ct['trang_thai']] ?? ct['trang_thai']}”';
      }
    case 'AttendanceRequest':
      if (ct['quyet_dinh'] != null) {
        return ct['quyet_dinh'] == 'DA_DUYET'
            ? 'Duyệt yêu cầu sửa điểm danh'
            : 'Từ chối yêu cầu sửa điểm danh';
      }
      if (ct['mong_muon'] != null) {
        const tt = {
          'CO_MAT': 'Có mặt',
          'VANG_CO_PHEP': 'Vắng có phép',
          'VANG_KHONG_PHEP': 'Vắng không phép',
        };
        return 'Gửi yêu cầu sửa điểm danh thành “${tt[ct['mong_muon']] ?? ct['mong_muon']}”';
      }
    case 'Notification':
      if (hd == 'CREATE') {
        const doiTuong = {
          'ROLE': 'vai trò',
          'CLASS': 'lớp học phần',
          'USER': 'người dùng',
        };
        return 'Gửi thông báo “${ct.str('tieu_de')}” tới ${doiTuong[ct['audience']] ?? 'người nhận'}';
      }
    case 'SystemConfig':
      if (ct.containsKey('tu') || ct.containsKey('den')) {
        return 'Đổi “${_cauHinh[id] ?? id}” từ ${ct['tu']} sang ${ct['den']}';
      }
    case 'TuitionInstallment':
      if (ct['dots'] is List) {
        final cac = [
          for (final d in ct['dots'] as List)
            '${_so(double.tryParse('${(d as Map)['ty_le']}'))}% hạn ${_ngay(d['han_dong'])}',
        ];
        return 'Cấu hình 3 đợt đóng học phí: ${cac.join(' · ')}';
      }
    case 'Payment':
      if (hd == 'CREATE' && ct['so_tien'] != null) {
        return '${ct['loai'] == 'HOAN' ? 'Hoàn' : 'Thu'} ${_vnd(ct['so_tien'])}';
      }
    case 'OnlineTransaction':
      if (hd == 'CREATE') return 'Tạo giao dịch VNPay ${_vnd(ct['so_tien'])}';
      switch (ct['trang_thai']) {
        case 'THANH_CONG':
          return 'VNPay: thanh toán thành công ${_vnd(ct['so_tien'])}';
        case 'THAT_BAI':
          return 'VNPay: thanh toán không thành công';
        case 'LOI':
          return 'VNPay: đã nhận ${_vnd(ct['so_tien'])} nhưng chưa ghi được học phí — cần kế toán xử lý';
      }
  }
  return null;
}

/// `25.0` → `25`, `33.33` giữ nguyên.
String _so(double? v) {
  if (v == null) return '?';
  return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Câu chung "Tạo/Cập nhật/Xóa <đối tượng> …" khi không có mô tả riêng.
String _chung(String hd, String dt, Json ct) {
  final viec = _viec[hd] ?? hd;
  final goc = ct['serialized'] is Map ? Json.from(ct['serialized'] as Map) : ct;
  final dau = '$viec ${_tenThuong(dt)}';
  switch (dt) {
    case 'HocPhanGia':
      if (goc['don_gia'] != null) {
        const pv = {
          'MAC_DINH': 'mặc định',
          'GIA_TH': 'thực hành',
          'NGANH': 'ngành',
          'KHOI_KIEN_THUC': 'khối kiến thức',
        };
        final cu = goc.str('tham_chieu');
        final loai = '${pv[goc['pham_vi']] ?? ''}${cu.isEmpty ? '' : ' $cu'}'
            .trim();
        return '$dau${loai.isEmpty ? '' : ' $loai'}: ${_vnd(goc['don_gia'])}/tín chỉ';
      }
    case 'Discount':
      final ten = goc['loai'] == 'HOC_BONG' ? 'học bổng' : 'miễn giảm';
      final gt = goc['ty_le'] != null
          ? '${_so(double.tryParse('${goc['ty_le']}'))}%'
          : goc['so_tien'] != null
          ? _vnd(goc['so_tien'])
          : '';
      return '$viec $ten${gt.isEmpty ? '' : ' $gt'}';
    case 'TuitionConfig':
      if (goc['han_dong'] != null) return '$dau ${_ngay(goc['han_dong'])}';
  }
  for (final k in _truongTen) {
    final v = goc.str(k).trim();
    if (v.isNotEmpty) return '$dau “$v”';
  }
  return dau;
}
