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
  profileTests();
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

void profileTests() {
  group('Hồ sơ SV / GV', () {
    final pending = [
      {
        'id': 21,
        'username': 'sv2025011',
        'email': 'a@x.vn',
        'role': 'SINH_VIEN',
      },
      {'id': 22, 'username': 'gv006', 'email': 'b@x.vn', 'role': 'GIAO_VIEN'},
    ];
    final sv = {
      'id': 1,
      'user': 12,
      'username': 'sv2023014',
      'ma_sv': 'SV2023014',
      'ho_ten': 'Trần Hoàng Nam',
      'nganh': 1,
      'nganh_ten': 'Công nghệ thông tin',
      'khoa_nhap_hoc': 'K2023',
      'ctdt': 1,
      'ctdt_ma': 'CTDT-CNTT-K2023',
      'gpa': '3.21',
      'tin_chi_tich_luy': 96,
      'email': 'nam@x.vn',
      'sdt': '',
    };

    testWidgets(
      'chip tài khoản chưa có hồ sơ → form tạo đã chọn sẵn tài khoản; lưu → POST',
      (t) async {
        final api = pdtApi({
          'GET /profiles/pending-accounts/': (_) => reply(200, pageOf(pending)),
          'GET /profiles/students/': (_) => reply(200, pageOf([sv])),
          'GET /profiles/teachers/': (_) => reply(200, pageOf([])),
          'GET /majors/': (_) => reply(
            200,
            pageOf([
              {'id': 1, 'ma_nganh': 'CNTT', 'ten_nganh': 'Công nghệ thông tin'},
            ]),
          ),
          'POST /profiles/students/': (_) => reply(201, sv),
        });
        await openPdt(t, api, '/pdt/profiles');
        expect(find.text('2 tài khoản'), findsOneWidget);
        expect(find.text('CTDT-CNTT-K2023'), findsOneWidget);
        expect(find.text('96'), findsOneWidget);

        await tapText(t, 'sv2025011 · Sinh viên — Tạo hồ sơ');
        expect(
          find.textContaining('CTĐT được chọn theo ngành và khóa'),
          findsOneWidget,
        );
        await enterField(t, 'Mã sinh viên', 'SV2025011');
        await enterField(t, 'Họ tên', 'Lê Văn Bình');
        await enterField(t, 'Ngành', 'Công');
        await t.pumpAndSettle();
        await t.tap(find.text('Công nghệ thông tin').last);
        await t.pumpAndSettle();
        await enterField(t, 'Khóa nhập học', 'K2025');
        await tapText(t, 'Lưu hồ sơ');
        expect(api.bodies['POST /profiles/students/'], {
          'user': 21,
          'ma_sv': 'SV2025011',
          'ho_ten': 'Lê Văn Bình',
          'nganh': 1,
          'khoa_nhap_hoc': 'K2025',
          'email': '',
          'sdt': '',
        });
      },
    );

    testWidgets(
      'tab Giáo viên đổi bảng; không có CTĐT khớp → lỗi hiện trong form',
      (t) async {
        final api = pdtApi({
          'GET /profiles/pending-accounts/': (_) => reply(200, pageOf([])),
          'GET /profiles/students/': (_) => reply(200, pageOf([sv])),
          'GET /profiles/teachers/': (_) => reply(
            200,
            pageOf([
              {
                'id': 4,
                'user': 30,
                'username': 'gv001',
                'ma_gv': 'GV001',
                'ho_ten': 'Trần Minh Quân',
                'khoa': 1,
                'khoa_ten': 'Khoa CNTT',
                'hoc_vi': 'Thạc sĩ',
                'email': 'q@x.vn',
                'sdt': '',
              },
            ]),
          ),
          'PATCH /profiles/teachers/4/': (_) => reply(400, {
            'ho_ten': ['Họ tên không hợp lệ.'],
          }),
        });
        await openPdt(t, api, '/pdt/profiles');
        expect(find.text('Tài khoản chưa có hồ sơ'), findsNothing);
        await tapText(t, 'Giáo viên');
        expect(find.text('GV001'), findsOneWidget);
        expect(find.text('Thạc sĩ'), findsOneWidget);

        await tapText(t, 'Sửa');
        await enterField(t, 'Họ tên', 'X');
        await tapText(t, 'Lưu');
        expect(find.text('Họ tên không hợp lệ.'), findsOneWidget);
      },
    );
  });
}
