import 'package:dang_ky_mon_hoc/core/download/save_file_provider.dart';
import 'package:dang_ky_mon_hoc/features/attendance/attendance_format.dart';
import 'package:dang_ky_mon_hoc/features/attendance/proof_picker.dart';
import 'package:dang_ky_mon_hoc/features/registration/timetable_screen.dart';
import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

// "Hôm nay" cố định 13/01/2027.
final _homNay = DateTime(2027, 1, 13);

Map<String, dynamic> buoi(int id, String ngay, {String tt = 'DA_DIEM_DANH'}) =>
    {
      'id': id,
      'lop_hoc_phan': 3,
      'ngay_hoc': ngay,
      'buoi': 'SANG',
      'tiet_bat_dau': 1,
      'trang_thai': tt,
    };

Map<String, dynamic> lopGv() => {
  'id': 3,
  'ma_lop': 'CNTT101-01',
  'ten_mon': 'Nhập môn lập trình',
  'trang_thai': 'DANG_HOC',
  'si_so_hien_tai': 2,
  'si_so_toi_da': 45,
  'lich_hoc': [
    {
      'id': 1,
      'thu': 5,
      'tiet_bat_dau': 1,
      'so_tiet_moi_buoi': 3,
      'tiet_ket_thuc': 3,
      'buoi': 'SANG',
      'phong': 'A101',
    },
  ],
};

Map<String, dynamic> yeuCau({String tt = 'CHO_DUYET', bool coFile = true}) => {
  'id': 8,
  'attendance': 70,
  'ngay_hoc': '2027-01-07',
  'buoi': 'SANG',
  'lop_hoc_phan': 3,
  'ma_lop': 'CNTT101-01',
  'ten_mon': 'Nhập môn lập trình',
  'ma_sv': 'SV2023014',
  'ho_ten': 'Trần Hoàng Nam',
  'trang_thai_hien_tai': 'VANG_KHONG_PHEP',
  'di_tre_hien_tai': false,
  'trang_thai_mong_muon': 'CO_MAT',
  'di_tre_mong_muon': true,
  'ly_do': 'Xe hỏng, đến muộn',
  'minh_chung': coFile ? '/api/attendance/requests/8/minh-chung/' : null,
  'ngay_gui': '2027-01-08T09:00:00+07:00',
  'trang_thai': tt,
  'ghi_chu': '',
};

Map<String, dynamic> records({bool can = true}) => {
  'session': buoi(11, '2027-01-07'),
  'lop_trang_thai': 'DANG_HOC',
  'co_the_diem_danh': can,
  'tong_so_buoi': 6,
  'max_absent_pct': 20,
  'records': [
    {
      'sinh_vien': 21,
      'ma_sv': 'SV2023014',
      'ho_ten': 'Trần Hoàng Nam',
      'trang_thai': 'CO_MAT',
      'di_tre': false,
      'ghi_chu': '',
      'da_luu': true,
      'so_buoi_vang_kp': 2,
      'ty_le_vang': 33.3,
      'canh_bao_vang': true,
    },
    {
      'sinh_vien': 22,
      'ma_sv': 'SV2023015',
      'ho_ten': 'Lê Văn Bình',
      'trang_thai': 'CO_MAT',
      'di_tre': false,
      'ghi_chu': '',
      'da_luu': true,
      'so_buoi_vang_kp': 0,
      'ty_le_vang': 0.0,
      'canh_bao_vang': false,
    },
  ],
};

Future<void> openTeacher(
  WidgetTester t,
  FakeAdapter api, {
  List<Override> overrides = const [],
  Size size = bigScreen,
}) async {
  await pumpApp(
    t,
    router: webRouterProvider,
    adapter: api,
    tokens: signedIn,
    size: size,
    overrides: [clockProvider.overrideWithValue(() => _homNay), ...overrides],
  );
  GoRouter.of(t.element(find.byType(Scaffold).first)).go('/teacher/attendance');
  await t.pumpAndSettle();
}

FakeAdapter gvApi({Map<String, Handler> extra = const {}}) => FakeAdapter({
  'GET /profiles/me/': (_) => reply(
    200,
    userJson('GIAO_VIEN', name: 'Trần Minh Quân', username: 'gv001'),
  ),
  'GET /class-sections/my/': (_) => reply(200, pageOf([lopGv()])),
  'GET /attendance/sessions/': (_) => reply(200, {
    ...pageOf([
      buoi(11, '2027-01-07'),
      buoi(12, '2027-01-14', tt: 'MO'),
      buoi(13, '2027-01-21', tt: 'MO'),
    ]),
    'tong_so_buoi': 3,
  }),
  'GET /attendance/requests/': (_) => reply(200, pageOf([yeuCau()])),
  'GET /attendance/sessions/11/records/': (_) => reply(200, records()),
  ...extra,
});

void main() {
  group('Giáo viên', () {
    testWidgets(
      'chọn lớp → các buổi (đến hạn / đã điểm danh / sắp tới); chưa chọn lớp thì chỉ có gợi ý',
      (t) async {
        final api = gvApi();
        await openTeacher(t, api);
        expect(find.text('Chọn lớp để xem các buổi điểm danh'), findsOneWidget);
        expect(
          api.log.any((l) => l.startsWith('GET /attendance/sessions/')),
          isFalse,
        );

        await tapText(t, '— Chọn lớp để bắt đầu —');
        await t.tap(find.text('CNTT101-01 · Nhập môn lập trình').last);
        await t.pumpAndSettle();
        expect(api.queries['GET /attendance/sessions/']!['lop_hoc_phan'], 3);
        expect(find.text('3 buổi theo lịch của lớp'), findsOneWidget);
        expect(
          find.text('Đã đến hạn 1 · Đã điểm danh 1 · Sắp tới 2'),
          findsOneWidget,
        );
        expect(
          find.text('Sắp tới'),
          findsNWidgets(2),
        ); // 14/01 và 21/01 đều sau hôm nay 13/01
        expect(find.text('Yêu cầu sửa (1)'), findsOneWidget);
      },
    );

    testWidgets(
      'điểm danh cả lớp: 4 lựa chọn, cờ nguy cơ cấm thi, Tất cả có mặt, Lưu gửi đủ danh sách',
      (t) async {
        final api = gvApi(
          extra: {
            'PUT /attendance/sessions/11/records/': (_) =>
                reply(200, records()),
          },
        );
        await openTeacher(t, api);
        await tapText(t, '— Chọn lớp để bắt đầu —');
        await t.tap(find.text('CNTT101-01 · Nhập môn lập trình').last);
        await t.pumpAndSettle();

        await tapText(t, 'Thứ 5, 07/01/2027');
        expect(find.text('Trần Hoàng Nam'), findsOneWidget);
        expect(find.text('Nguy cơ cấm thi'), findsOneWidget);
        expect(find.textContaining('Vắng KP 2/6 (33%)'), findsOneWidget);

        await tapText(t, 'Đi trễ', index: 0);
        await tapText(t, 'Vắng không phép', index: 1);
        await tapText(t, 'Lưu điểm danh');
        expect(api.bodies['PUT /attendance/sessions/11/records/'], {
          'records': [
            {
              'sinh_vien': 21,
              'trang_thai': 'CO_MAT',
              'di_tre': true,
              'ghi_chu': '',
            },
            {
              'sinh_vien': 22,
              'trang_thai': 'VANG_KHONG_PHEP',
              'di_tre': false,
              'ghi_chu': '',
            },
          ],
        });
        expect(find.textContaining('Đã lưu điểm danh cả lớp'), findsOneWidget);

        await tapText(t, 'Tất cả có mặt');
        await tapText(t, 'Lưu điểm danh');
        final recs =
            (api.bodies['PUT /attendance/sessions/11/records/']
                    as Map)['records']
                as List;
        expect(
          recs.every(
            (r) => r['trang_thai'] == 'CO_MAT' && r['di_tre'] == false,
          ),
          isTrue,
        );
      },
    );

    testWidgets('buổi chưa tới ngày: không điểm danh được, nút Lưu khóa', (
      t,
    ) async {
      final api = gvApi(
        extra: {
          'GET /attendance/sessions/12/records/': (_) =>
              reply(200, records(can: false)),
        },
      );
      await openTeacher(t, api);
      await tapText(t, '— Chọn lớp để bắt đầu —');
      await t.tap(find.text('CNTT101-01 · Nhập môn lập trình').last);
      await t.pumpAndSettle();
      await tapText(t, 'Thứ 5, 14/01/2027');
      expect(find.textContaining('chưa điểm danh được'), findsOneWidget);
      final save = t.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Lưu điểm danh'),
      );
      expect(save.onPressed, isNull);
    });

    testWidgets(
      'tab Yêu cầu sửa: xem minh chứng, Duyệt → PATCH, Từ chối kèm ghi chú',
      (t) async {
        final saved = <String>[];
        final api = gvApi(
          extra: {
            'GET /attendance/requests/8/minh-chung/': (_) =>
                reply(200, 'PNGDATA'),
            'PATCH /attendance/requests/8/': (_) =>
                reply(200, yeuCau(tt: 'DUYET')),
          },
        );
        await openTeacher(
          t,
          api,
          overrides: [
            saveFileProvider.overrideWithValue(
              (name, bytes, {mime}) async => saved.add(name),
            ),
          ],
        );
        await tapText(t, '— Chọn lớp để bắt đầu —');
        await t.tap(find.text('CNTT101-01 · Nhập môn lập trình').last);
        await t.pumpAndSettle();
        await tapText(t, 'Yêu cầu sửa (1)');

        expect(
          find.textContaining('Trần Hoàng Nam · SV2023014'),
          findsOneWidget,
        );
        expect(find.text('Đổi: Vắng không phép → Đi trễ'), findsOneWidget);
        expect(find.text('Lý do: Xe hỏng, đến muộn'), findsOneWidget);

        await tapText(t, 'Xem minh chứng');
        expect(saved.single, startsWith('minh-chung-8'));
        expect(
          api.log.any(
            (l) => l.startsWith('GET /attendance/requests/8/minh-chung/'),
          ),
          isTrue,
        );

        await tapText(t, 'Từ chối');
        await enterField(t, 'Ghi chú cho sinh viên', 'Thiếu minh chứng');
        await tapText(t, 'Từ chối', index: 1);
        expect(api.bodies['PATCH /attendance/requests/8/'], {
          'ghi_chu': 'Thiếu minh chứng',
          'trang_thai': 'TU_CHOI',
        });

        await tapText(t, 'Duyệt');
        expect(api.bodies['PATCH /attendance/requests/8/'], {
          'trang_thai': 'DUYET',
        });
      },
    );
  });

  group('Sinh viên', () {
    Map<String, dynamic> lopSv({
      String lopTt = 'DANG_HOC',
      List<Map<String, dynamic>>? buoiList,
    }) => {
      'lop_hoc_phan': 3,
      'ma_lop': 'CNTT101-01',
      'ma_mon': 'CNTT101',
      'ten_mon': 'Nhập môn lập trình',
      'lop_trang_thai': lopTt,
      'tong_so_buoi': 6,
      'so_co_mat': 3,
      'so_di_tre': 1,
      'so_vang_co_phep': 1,
      'so_vang_kp': 2,
      'ty_le_vang': 33.3,
      'canh_bao_vang': true,
      'so_buoi_vang_cho_phep': 1,
      'buoi':
          buoiList ??
          [
            {
              'session': 11,
              'attendance': 70,
              'ngay_hoc': '2027-01-07',
              'buoi': 'SANG',
              'tiet_bat_dau': 1,
              'trang_thai': 'VANG_KHONG_PHEP',
              'di_tre': false,
              'ghi_chu': 'Không báo',
              'yeu_cau': null,
            },
            {
              'session': 12,
              'attendance': null,
              'ngay_hoc': '2027-01-14',
              'buoi': 'SANG',
              'tiet_bat_dau': 1,
              'trang_thai': null,
              'di_tre': false,
              'ghi_chu': '',
              'yeu_cau': null,
            },
          ],
    };

    FakeAdapter svApi2({
      String lopTt = 'DANG_HOC',
      Map<String, Handler> extra = const {},
      List<Map<String, dynamic>>? buoiList,
    }) => svApi({
      'GET /attendance/my/': (_) => reply(200, {
        'hoc_ky': 7,
        'ten_hk': 'Học kỳ 2, 2026–2027',
        'max_absent_pct': 20,
        'lop_hoc_phan': [lopSv(lopTt: lopTt, buoiList: buoiList)],
      }),
      'GET /attendance/requests/': (_) => reply(200, pageOf([])),
      ...extra,
    });

    Future<void> open(
      WidgetTester t,
      FakeAdapter api, {
      List<Override> overrides = const [],
      Size size = bigScreen,
    }) async {
      await openStudent(
        t,
        api,
        '/student/attendance',
        size: size,
        overrides: [
          clockProvider.overrideWithValue(() => _homNay),
          ...overrides,
        ],
      );
      await tapText(t, '— Chọn lớp —');
      await t.tap(find.text('CNTT101-01 · Nhập môn lập trình').last);
      await t.pumpAndSettle();
    }

    testWidgets(
      'thống kê: tỷ lệ vắng không phép, cờ nguy cơ cấm thi, buổi chưa điểm danh',
      (t) async {
        await openStudent(t, svApi2(), '/student/attendance');
        expect(find.text('Chọn lớp để xem thống kê điểm danh'), findsOneWidget);
        await tapText(t, '— Chọn lớp —');
        await t.tap(find.text('CNTT101-01 · Nhập môn lập trình').last);
        await t.pumpAndSettle();

        expect(find.text('Nguy cơ cấm thi'), findsOneWidget);
        expect(
          find.text('Tỷ lệ vắng không phép: 2/6 buổi (33%)'),
          findsOneWidget,
        );
        expect(find.textContaining('Đã vượt ngưỡng 20%'), findsOneWidget);
        expect(find.text('Chưa điểm danh'), findsOneWidget);
        expect(find.text('Vắng không phép'), findsWidgets);
      },
    );

    testWidgets(
      'xin sửa: bắt buộc trạng thái + lý do; gửi multipart kèm minh chứng',
      (t) async {
        final api = svApi2(
          extra: {'POST /attendance/requests/': (_) => reply(201, yeuCau())},
        );
        await open(
          t,
          api,
          overrides: [
            proofPickerProvider.overrideWithValue(
              () async => const PickedProof('giay.png', [1, 2, 3]),
            ),
          ],
        );
        await tapText(t, 'Thứ 5, 07/01/2027');
        expect(find.text('Ghi chú giáo viên: Không báo'), findsOneWidget);
        await tapText(t, 'Xin sửa điểm danh buổi này');

        await tapText(t, 'Gửi yêu cầu');
        expect(
          find.text('Vui lòng chọn trạng thái mong muốn.'),
          findsOneWidget,
        );
        expect(find.text('Vui lòng nhập lý do.'), findsOneWidget);

        await tapText(t, '— Chọn —');
        await t.tap(find.text('Đi trễ').last);
        await t.pumpAndSettle();
        await enterField(t, 'Lý do (bắt buộc)', 'Xe hỏng');
        await tapText(t, 'Chọn ảnh hoặc PDF');
        expect(find.text('giay.png'), findsOneWidget);
        await tapText(t, 'Gửi yêu cầu');

        expect(
          api.log.any((l) => l.startsWith('POST /attendance/requests/')),
          isTrue,
        );
        final form = api.bodies['POST /attendance/requests/'];
        expect(form.toString(), contains('FormData'));
        expect(find.textContaining('Đã gửi yêu cầu'), findsOneWidget);
      },
    );

    testWidgets(
      'lớp đã đóng: không gửi được yêu cầu; buổi chưa điểm danh: thông báo',
      (t) async {
        await open(t, svApi2(lopTt: 'DA_DONG'));
        await tapText(t, 'Thứ 5, 07/01/2027');
        expect(
          find.text('Lớp đã đóng nên không thể gửi yêu cầu sửa điểm danh.'),
          findsOneWidget,
        );
        expect(find.text('Xin sửa điểm danh buổi này'), findsNothing);

        await tapText(t, 'Thứ 5, 14/01/2027');
        expect(
          find.text('Buổi chưa diễn ra nên chưa có điểm danh.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'đã có yêu cầu chờ duyệt: hiện nhãn Chờ duyệt, không gửi thêm',
      (t) async {
        final dangCho = [
          {
            'session': 11,
            'attendance': 70,
            'ngay_hoc': '2027-01-07',
            'buoi': 'SANG',
            'tiet_bat_dau': 1,
            'trang_thai': 'VANG_KHONG_PHEP',
            'di_tre': false,
            'ghi_chu': '',
            'yeu_cau': {'id': 8, 'trang_thai': 'CHO_DUYET'},
          },
        ];
        await open(t, svApi2(buoiList: dangCho));
        expect(find.text('Chờ duyệt'), findsOneWidget);
        await tapText(t, 'Thứ 5, 07/01/2027');
        expect(
          find.text('Yêu cầu sửa của bạn đang chờ giáo viên duyệt.'),
          findsOneWidget,
        );
        expect(find.text('Xin sửa điểm danh buổi này'), findsNothing);
      },
    );

    testWidgets('bố cục App 390 px: không tràn', (t) async {
      await open(t, svApi2(), size: const Size(390, 844));
      expect(
        find.text('Tỷ lệ vắng không phép: 2/6 buổi (33%)'),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  });

  test('DiemDanhChon: Đi trễ = CO_MAT + di_tre; vắng thì bỏ qua cờ trễ', () {
    expect(DiemDanhChon.of('CO_MAT', true), DiemDanhChon.diTre);
    expect(DiemDanhChon.of('CO_MAT', false), DiemDanhChon.coMat);
    expect(DiemDanhChon.of('VANG_CO_PHEP', true), DiemDanhChon.vangCoPhep);
    expect(
      DiemDanhChon.of('VANG_KHONG_PHEP', false),
      DiemDanhChon.vangKhongPhep,
    );
    expect(DiemDanhChon.diTre.trangThai, 'CO_MAT');
    expect(DiemDanhChon.diTre.laDiTre, isTrue);
  });
}
