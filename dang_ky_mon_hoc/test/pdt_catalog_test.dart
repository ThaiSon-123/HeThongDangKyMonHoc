import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> khoa(
  int id,
  String ma,
  String ten, {
  String tt = 'HOAT_DONG',
}) => {
  'id': id,
  'ma_khoa': ma,
  'ten_khoa': ten,
  'trang_thai': tt,
  'so_nganh': 2,
  'so_giao_vien': 5,
  'so_mon': 10,
};

void main() {
  group('Khoa / viện', () {
    testWidgets(
      'hiện bảng đúng mockup; sửa không đổi được mã; ngừng bị server chặn → toast',
      (t) async {
        final rows = [
          khoa(1, 'CNTT', 'Công nghệ thông tin'),
          khoa(2, 'TOAN', 'Toán – Tin', tt: 'NGUNG'),
        ];
        final api = pdtApi({
          'GET /faculties/': (_) => reply(200, pageOf(rows)),
          'PATCH /faculties/1/': (o) =>
              (o.data as Map).containsKey('trang_thai')
              ? apiError(
                  409,
                  'TRANG_THAI_KHONG_HOP_LE',
                  'Khoa/viện còn ngành đang hoạt động.',
                )
              : reply(200, khoa(1, 'CNTT', 'CNTT & TT')),
        });
        await openPdt(t, api, '/pdt/faculties');

        for (final s in [
          'MÃ',
          'TÊN KHOA / VIỆN',
          'GIÁO VIÊN',
          'CNTT',
          'Công nghệ thông tin',
          'Hoạt động',
          'Ngừng',
          '2 bản ghi',
          '+ Thêm khoa / viện',
        ]) {
          expect(find.text(s), findsWidgets, reason: s);
        }
        expect(find.text('Mở lại'), findsOneWidget); // khoa đã ngừng

        await tapText(t, 'Sửa');
        expect(find.text('Không đổi sau khi tạo.'), findsOneWidget);
        await enterField(t, 'Tên khoa / viện', 'CNTT & TT');
        await tapText(t, 'Lưu');
        expect(api.bodies['PATCH /faculties/1/'], {'ten_khoa': 'CNTT & TT'});

        await tapText(
          t,
          'Ngừng',
        ); // nút của dòng CNTT (đứng trước chip của dòng 2)
        await tapText(t, 'Ngừng khoa / viện');
        expect(
          find.text('Khoa/viện còn ngành đang hoạt động.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('thêm mới: thiếu tên → báo bắt buộc; hợp lệ → POST + tải lại', (
      t,
    ) async {
      final api = pdtApi({
        'GET /faculties/': (_) => reply(200, pageOf([])),
        'POST /faculties/': (_) => reply(201, khoa(9, 'X', 'Y')),
      });
      await openPdt(t, api, '/pdt/faculties');
      expect(find.text('Chưa có khoa / viện nào.'), findsOneWidget);

      await tapText(t, '+ Thêm khoa / viện');
      await enterField(t, 'Mã khoa / viện', 'KTMP');
      await tapText(t, 'Lưu');
      expect(find.text('Bắt buộc nhập.'), findsOneWidget);
      expect(api.bodies['POST /faculties/'], isNull);

      await enterField(t, 'Tên khoa / viện', 'Kỹ thuật phần mềm');
      await tapText(t, 'Lưu');
      expect(api.bodies['POST /faculties/'], {
        'ma_khoa': 'KTMP',
        'ten_khoa': 'Kỹ thuật phần mềm',
      });
      expect(api.log.where((l) => l.startsWith('GET /faculties/')).length, 2);
    });

    testWidgets('lỗi tải → "Thử lại" tải lại được', (t) async {
      var n = 0;
      final api = pdtApi({
        'GET /faculties/': (_) => n++ == 0
            ? apiError(500, 'X')
            : reply(200, pageOf([khoa(1, 'CNTT', 'A')])),
      });
      await openPdt(t, api, '/pdt/faculties');
      expect(find.text('Không tải được dữ liệu'), findsOneWidget);
      await tapText(t, 'Thử lại');
      expect(find.text('CNTT'), findsOneWidget);
    });
  });

  testWidgets(
    'Khoa / viện: lọc Trạng thái gửi ?trang_thai=; không còn dòng mô tả',
    (t) async {
      final api = pdtApi({
        'GET /faculties/': (_) => reply(200, pageOf([khoa(1, 'CNTT', 'A')])),
      });
      await openPdt(t, api, '/pdt/faculties');
      expect(find.textContaining('chỉ có thể ngừng'), findsNothing);

      await tapText(t, 'Tất cả');
      await t.tap(find.text('Ngừng').last); // mục trong danh sách thả xuống
      await t.pumpAndSettle();
      expect(api.queries['GET /faculties/']!['trang_thai'], 'NGUNG');
    },
  );

  group('Ngành', () {
    testWidgets(
      'chọn khoa/viện bằng ô gợi ý khi thêm; lọc theo khoa gửi ?khoa=',
      (t) async {
        final api = pdtApi({
          'GET /majors/': (_) => reply(
            200,
            pageOf([
              {
                'id': 1,
                'ma_nganh': 'CNTT',
                'ten_nganh': 'Công nghệ thông tin',
                'thoi_gian_dao_tao': 4,
                'khoa': 1,
                'khoa_ten': 'Khoa CNTT',
                'so_ctdt': 3,
                'trang_thai': 'HOAT_DONG',
              },
            ]),
          ),
          'GET /faculties/': (_) => reply(
            200,
            pageOf([
              khoa(1, 'CNTT', 'Khoa CNTT'),
              khoa(2, 'TOAN', 'Khoa Toán'),
            ]),
          ),
          'POST /majors/': (_) => reply(201, {'id': 5}),
        });
        await openPdt(t, api, '/pdt/majors');
        expect(find.text('4 năm'), findsOneWidget);
        expect(find.text('Khoa CNTT'), findsWidgets);

        await tapText(t, '+ Thêm ngành');
        await enterField(t, 'Mã ngành', 'KTPM');
        await enterField(t, 'Thời gian đào tạo (năm)', '4');
        await enterField(t, 'Tên ngành', 'Kỹ thuật phần mềm');
        await tapText(t, 'Lưu');
        expect(find.text('Bắt buộc chọn.'), findsOneWidget);

        await enterField(t, 'Khoa / viện quản lý', 'Toán');
        await t.pumpAndSettle();
        await tapText(t, 'Khoa Toán', index: 0);
        await tapText(t, 'Lưu');
        expect(api.bodies['POST /majors/'], {
          'ma_nganh': 'KTPM',
          'thoi_gian_dao_tao': 4,
          'ten_nganh': 'Kỹ thuật phần mềm',
          'khoa': 2,
        });
      },
    );
  });
}
