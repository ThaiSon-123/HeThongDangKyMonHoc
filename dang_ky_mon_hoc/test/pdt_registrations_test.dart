import 'package:dang_ky_mon_hoc/features/training/registrations_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> dk(
  int id,
  String ma,
  String ten, {
  String tt = 'DA_DANG_KY',
  String lop = 'MO',
  String ly = '',
}) => {
  'id': id,
  'lop_hoc_phan': 3,
  'ma_lop': 'CNTT101-01',
  'ma_mon': 'CNTT101',
  'ten_mon': 'Nhập môn lập trình',
  'tong_tin_chi': 3,
  'hoc_ky': 7,
  'ten_hk': 'Học kỳ 2',
  'giao_vien_ten': 'Trần Minh Quân',
  'lop_trang_thai': lop,
  'lich_hoc': [],
  'trang_thai': tt,
  'ngay_dang_ky': '2027-01-10T08:30:00+07:00',
  'ngay_huy': null,
  'ly_do_huy': ly,
  'ma_sv': ma,
  'ho_ten': ten,
  'nganh_ten': 'Công nghệ thông tin',
};

void main() {
  testWidgets(
    'bảng theo dõi; hủy hộ bắt buộc lý do rồi DELETE kèm body; chỉ lớp mở/đang học mới hủy hộ được',
    (t) async {
      final rows = [
        dk(1, 'SV2023014', 'Trần Hoàng Nam'),
        dk(2, 'SV2023015', 'Lê Văn Bình', tt: 'DA_HUY', ly: 'Đổi lịch'),
        dk(3, 'SV2023016', 'Phạm Thu Hà', lop: 'DA_DONG'),
      ];
      final api = pdtApi({
        'GET /registrations/': (_) => reply(200, pageOf(rows)),
        'DELETE /registrations/1/': (_) =>
            reply(200, {...rows[0], 'trang_thai': 'DA_HUY', 'warnings': []}),
      });
      await openPdt(t, api, '/pdt/registrations');

      expect(find.text('SV2023014'), findsOneWidget);
      expect(find.text('Đổi lịch'), findsOneWidget);
      expect(
        find.text('Hủy hộ'),
        findsOneWidget,
      ); // dòng đã hủy và lớp đã đóng không có nút

      await tapText(t, 'Hủy hộ');
      expect(find.textContaining('sĩ số lớp −1'), findsOneWidget);
      await tapText(t, 'Hủy đăng ký');
      expect(find.text('Bắt buộc nhập.'), findsOneWidget);
      expect(api.bodies['DELETE /registrations/1/'], isNull);

      await enterField(t, 'Lý do hủy (bắt buộc)', 'Sinh viên nghỉ học');
      await tapText(t, 'Hủy đăng ký');
      expect(api.bodies['DELETE /registrations/1/'], {
        'ly_do': 'Sinh viên nghỉ học',
      });
      expect(find.text('Đã hủy đăng ký hộ sinh viên.'), findsOneWidget);
    },
  );

  testWidgets('Xuất Excel gọi /registrations/export/ kèm bộ lọc và lưu tệp', (
    t,
  ) async {
    final saved = <String>[];
    final api = pdtApi({
      'GET /registrations/': (_) => reply(200, pageOf([dk(1, 'SV1', 'A')])),
      'GET /registrations/export/': (_) => reply(200, 'XLSX'),
    });
    await openPdt(
      t,
      api,
      '/pdt/registrations',
      overrides: [
        saveFileProvider.overrideWithValue(
          (name, bytes, {mime}) async => saved.add('$name:${bytes.length}'),
        ),
      ],
    );
    await tapText(t, 'Xuất Excel');
    expect(
      api.log.any((l) => l.startsWith('GET /registrations/export/')),
      isTrue,
    );
    expect(saved, hasLength(1));
    expect(saved.single, startsWith('dang_ky_mon_hoc.xlsx:'));
    expect(find.text('Đã xuất tệp Excel.'), findsOneWidget);
  });
}
