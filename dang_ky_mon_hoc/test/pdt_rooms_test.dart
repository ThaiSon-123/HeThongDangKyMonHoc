import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> phong(int id, String ma, int sc, String loai) => {
  'id': id,
  'ma': ma,
  'suc_chua': sc,
  'loai': loai,
};

void main() {
  testWidgets('phòng học: hiện bảng, thêm mới gửi số, xóa bị chặn → toast', (
    t,
  ) async {
    final api = pdtApi({
      'GET /rooms/': (_) => reply(
        200,
        pageOf([
          phong(1, 'A101', 60, 'LY_THUYET'),
          phong(2, 'LAB01', 40, 'THUC_HANH'),
        ]),
      ),
      'POST /rooms/': (_) => reply(201, phong(3, 'B202', 50, 'LY_THUYET')),
      'DELETE /rooms/1/': (_) => apiError(
        409,
        'TRANG_THAI_KHONG_HOP_LE',
        'Phòng đang có lịch học, không xóa được.',
      ),
    });
    await openPdt(t, api, '/pdt/rooms');

    for (final s in [
      'A101',
      'LAB01',
      '60',
      'Lý thuyết',
      'Thực hành',
      '+ Thêm phòng',
    ]) {
      expect(find.text(s), findsWidgets, reason: s);
    }

    await tapText(t, '+ Thêm phòng');
    await enterField(t, 'Mã phòng', 'B202');
    await enterField(t, 'Sức chứa', '50');
    await tapText(t, 'Lưu');
    expect(api.bodies['POST /rooms/'], {
      'ma': 'B202',
      'suc_chua': 50,
      'loai': 'LY_THUYET',
    });

    await tapText(t, 'Xóa');
    await tapText(t, 'Xóa phòng');
    expect(
      find.text('Phòng đang có lịch học, không xóa được.'),
      findsOneWidget,
    );
  });
}
