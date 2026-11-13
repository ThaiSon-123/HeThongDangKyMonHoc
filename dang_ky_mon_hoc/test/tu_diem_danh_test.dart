import 'dart:typed_data';

import 'package:dang_ky_mon_hoc/features/attendance/face/face_capture.dart';
import 'package:dang_ky_mon_hoc/features/attendance/tu_diem_danh/thiet_bi.dart';
import 'package:dang_ky_mon_hoc/features/registration/timetable_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'attendance_test.dart' show lopGv;
import 'helpers/pdt_helpers.dart';

final _now = DateTime(2027, 1, 13, 8, 0);

final _overrides = [
  clockProvider.overrideWithValue(() => _now),
  layMauGpsProvider.overrideWithValue((giay, onMau) async {
    final ds = [
      for (var i = 0; i < 5; i++)
        <String, Object>{
          'lat': 10.98,
          'lng': 106.67,
          'acc': 8.0,
          'ts': i * 1000,
          'mock': false,
        },
    ];
    ds.forEach(onMau);
    return ds;
  }),
  faceBurstProvider.overrideWithValue(
    (context, chuoi) async => [
      for (var i = 0; i < 6; i++) Uint8List.fromList([i]),
    ],
  ),
];

/// Màn có Timer đếm ngược mỗi giây → không dùng pumpAndSettle (không bao giờ "yên").
Future<void> cho(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

/// Bấm phần tử khớp [text] xuất hiện sau cùng (nút trên màn / hộp thoại, không phải mục menu).
Future<void> bam(WidgetTester t, String text) async {
  await t.tap(find.text(text).last);
  await cho(t);
}

Map<String, dynamic> phienJson({bool mo = true, bool daMo = true}) => {
  'id': 11,
  'mo_luc': daMo ? '2027-01-13T07:55:00+07:00' : null,
  'het_han_luc': '2027-01-13T08:05:00+07:00',
  'dong_luc': null,
  'dang_mo': mo,
  'ban_kinh_m': 20,
  'tam_sai_so_m': 6.0,
  'kiem_tra_phong': false,
};

Map<String, dynamic> row(
  int id,
  String ten, {
  String tt = 'VANG_KHONG_PHEP',
  bool dangNgo = false,
  bool coMau = true,
  Map<String, dynamic>? luot,
}) => {
  'sinh_vien': id,
  'ma_sv': 'SV$id',
  'ho_ten': ten,
  'trang_thai': tt,
  'dang_ngo': dangNgo,
  'gv_da_quyet': false,
  'co_mau_mat': coMau,
  'so_luot': luot == null ? 0 : 1,
  'luot_cuoi_luc': null,
  'luot': luot,
};

Map<String, dynamic> live({bool mo = true, bool daMo = true}) => {
  'session': phienJson(mo: mo, daMo: daMo),
  'dang_mo': mo,
  'dem': {'co_mat': 1, 'dang_ngo': 1, 'chua': 1},
  'goi_y_tinh_lai_tam': false,
  'rows': [
    row(21, 'Trần Hoàng Nam', tt: 'CO_MAT'),
    row(
      22,
      'Lê Thu Hà',
      dangNgo: true,
      luot: {
        'id': 7,
        'ket_qua': 'DANG_NGO',
        'co': ['LECH_NHE'],
      },
    ),
    row(23, 'Phạm Văn An', coMau: false),
  ],
};

FakeAdapter gv(Map<String, Handler> extra) => FakeAdapter({
  'GET /profiles/me/': (_) => reply(
    200,
    userJson('GIAO_VIEN', name: 'Trần Minh Quân', username: 'gv001'),
  ),
  'GET /class-sections/my/': (_) => reply(200, pageOf([lopGv()])),
  'GET /attendance/sessions/': (_) => reply(200, {
    ...pageOf([
      {
        'id': 11,
        'lop_hoc_phan': 3,
        'ngay_hoc': '2027-01-13',
        'buoi': 'SANG',
        'tiet_bat_dau': 1,
        'trang_thai': 'MO',
      },
    ]),
    'tong_so_buoi': 1,
  }),
  ...extra,
});

Future<void> moGv(WidgetTester t, FakeAdapter api) async {
  await openPdt(t, api, '/teacher/self-attendance', overrides: _overrides);
  await bam(t, '— Chọn lớp —');
  await t.tap(find.text('CNTT101-01 · Nhập môn lập trình').last);
  await cho(t);
}

void main() {
  group('GV — tự điểm danh', () {
    testWidgets('mở phiên: lấy GPS rồi gửi đủ tham số', (t) async {
      var daMo = false;
      final api = gv({
        'GET /attendance/sessions/11/tu-diem-danh/': (_) =>
            reply(200, live(daMo: daMo)),
        'POST /attendance/sessions/11/mo-phien/': (_) {
          daMo = true;
          return reply(200, phienJson());
        },
      });
      await moGv(t, api);
      expect(find.text('Mở phiên tự điểm danh'), findsOneWidget);

      await bam(t, 'Lấy vị trí và mở phiên');
      final body = api.bodies['POST /attendance/sessions/11/mo-phien/'] as Map;
      expect((body['mau_gps'] as List).length, 5);
      expect(body['thoi_han'], 10);
      expect(body['r0'], 20);
      expect(body['kiem_tra_phong'], false);
      expect(find.text('Đang mở · còn 05:00'), findsOneWidget);
    });

    testWidgets('danh sách: đếm, cờ, SV chưa có mẫu mặt', (t) async {
      final api = gv({
        'GET /attendance/sessions/11/tu-diem-danh/': (_) => reply(200, live()),
      });
      await moGv(t, api);
      expect(find.text('Có mặt: 1'), findsOneWidget);
      expect(find.text('Đáng ngờ: 1'), findsOneWidget);
      expect(find.textContaining('Lệch vị trí'), findsOneWidget);
      expect(find.textContaining('Chưa có mẫu mặt'), findsOneWidget);
    });

    testWidgets('duyệt lượt đáng ngờ → POST quyet', (t) async {
      final api = gv({
        'GET /attendance/sessions/11/tu-diem-danh/': (_) => reply(200, live()),
        'GET /attendance/sessions/11/luot/': (_) => reply(200, [
          {
            'id': 7,
            'ket_qua': 'DANG_NGO',
            'buoc_dung': null,
            'ly_do': '',
            'co': ['LECH_NHE'],
            'diem_mat': 0.91,
            'diem_that': 0.97,
            'd_m': 41.0,
            'r_m': 34.0,
            'nen_tang': 'android',
            'co_anh_bang_chung': false,
            'tao_luc': '2027-01-13T07:58:00+07:00',
          },
        ]),
        'POST /attendance/attempts/7/quyet/': (_) =>
            reply(200, {'id': 7, 'co_mat': true}),
      });
      await moGv(t, api);
      await bam(t, 'Lê Thu Hà · SV22');
      expect(find.textContaining('cách 41 m / r 34 m'), findsOneWidget);
      await bam(t, 'Duyệt có mặt');
      expect(api.bodies['POST /attendance/attempts/7/quyet/'], {
        'co_mat': true,
      });
    });

    testWidgets('điểm danh thủ công SV chưa có mẫu mặt', (t) async {
      final api = gv({
        'GET /attendance/sessions/11/tu-diem-danh/': (_) => reply(200, live()),
        'GET /attendance/sessions/11/luot/': (_) => reply(200, []),
        'PATCH /attendance/sessions/11/tu-diem-danh/': (_) =>
            reply(200, live()),
      });
      await moGv(t, api);
      await bam(t, 'Phạm Văn An · SV23');
      expect(find.textContaining('điểm danh thủ công'), findsOneWidget);
      await bam(t, 'Có mặt');
      expect(api.bodies['PATCH /attendance/sessions/11/tu-diem-danh/'], {
        'sinh_vien': [23],
        'trang_thai': 'CO_MAT',
      });
    });

    testWidgets('phiên đã đóng → mở lại', (t) async {
      final api = gv({
        'GET /attendance/sessions/11/tu-diem-danh/': (_) =>
            reply(200, live(mo: false)),
        'POST /attendance/sessions/11/mo-lai/': (_) => reply(200, phienJson()),
      });
      await moGv(t, api);
      expect(find.text('Đã đóng'), findsOneWidget);
      await bam(t, 'Mở lại');
      await bam(t, '15 phút');
      expect(api.bodies['POST /attendance/sessions/11/mo-lai/'], {
        'thoi_han': 15,
      });
    });
  });

  group('SV — tự điểm danh', () {
    Map<String, dynamic> moSv({int con = 5, String tt = 'VANG_KHONG_PHEP'}) => {
      'id': 11,
      'lop_hoc_phan': 3,
      'ma_lop': 'CNTT101-01',
      'ten_mon': 'Nhập môn lập trình',
      'ngay_hoc': '2027-01-13',
      'buoi': 'SANG',
      'het_han_luc': '2027-01-13T08:05:00+07:00',
      'kiem_tra_phong': false,
      'trang_thai': tt,
      'dang_ngo': false,
      'luot_con_lai': con,
    };

    Map<String, dynamic> thuThach({bool qr = false}) => {
      'nonce': 'n1',
      'hanh_dong': 'turn_left',
      'het_han_luc': '2027-01-13T08:01:00+07:00',
      'luot_con_lai': 4,
      'kiem_tra_phong': qr,
    };

    Future<void> moSvScreen(WidgetTester t, FakeAdapter api) =>
        openPdt(t, api, '/student/checkin', overrides: _overrides);

    testWidgets('không có phiên mở', (t) async {
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, []),
      });
      await moSvScreen(t, api);
      expect(
        find.textContaining('Chưa có phiên điểm danh nào'),
        findsOneWidget,
      );
    });

    testWidgets('đủ bước: thử thách → GPS → chụp → có mặt', (t) async {
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv()]),
        'POST /attendance/sessions/11/challenge/': (_) =>
            reply(201, thuThach()),
        'POST /attendance/sessions/11/checkin/': (_) => reply(200, {
          'ket_qua': 'CO_MAT',
          'trang_thai': 'CO_MAT',
          'dang_ngo': false,
          'ly_do': null,
          'luot_con_lai': 4,
        }),
      });
      await moSvScreen(t, api);
      await bam(t, 'Điểm danh');
      await bam(t, 'Bắt đầu');
      final body =
          api.bodies['POST /attendance/sessions/11/checkin/'] as FormData;
      final f = Map.fromEntries(body.fields);
      expect(f['nonce'], 'n1');
      expect(f['mau_gps'], contains('"lat":10.98'));
      expect(f['nen_tang'], 'android');
      expect(f['device_id'], hasLength(32));
      expect(body.files.length, 6);
      expect(find.text('Đã ghi nhận có mặt.'), findsOneWidget);
    });

    testWidgets('phiên bật mã phòng → nhập mã rồi mới gửi', (t) async {
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv()]),
        'POST /attendance/sessions/11/challenge/': (_) =>
            reply(201, thuThach(qr: true)),
        'POST /attendance/sessions/11/checkin/': (_) => reply(200, {
          'ket_qua': 'KHONG_DAT',
          'trang_thai': 'VANG_KHONG_PHEP',
          'dang_ngo': false,
          'ly_do': {
            'ma': 'QUA_XA',
            'thong_bao': 'Bạn đang ở xa vị trí lớp học.',
          },
          'luot_con_lai': 3,
        }),
      });
      await moSvScreen(t, api);
      await bam(t, 'Điểm danh');
      await bam(t, 'Bắt đầu');
      expect(
        api.bodies.containsKey('POST /attendance/sessions/11/checkin/'),
        isFalse,
      );
      await t.enterText(find.byType(TextField), 'k7q2 m9xa');
      await bam(t, 'Tiếp tục');
      final body =
          api.bodies['POST /attendance/sessions/11/checkin/'] as FormData;
      expect(Map.fromEntries(body.fields)['ma_phong'], 'k7q2 m9xa');
      expect(find.text('Bạn đang ở xa vị trí lớp học.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
    });

    testWidgets('hết lượt → báo nhờ giảng viên', (t) async {
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv(con: 0)]),
      });
      await moSvScreen(t, api);
      expect(find.textContaining('Bạn đã hết lượt'), findsOneWidget);
    });

    testWidgets('chưa có mẫu mặt → hiện thông điệp server', (t) async {
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv()]),
        'POST /attendance/sessions/11/challenge/': (_) => apiError(
          409,
          'TRANG_THAI_KHONG_HOP_LE',
          'Bạn chưa có mẫu khuôn mặt được duyệt. Hãy báo giảng viên để điểm danh thủ công.',
        ),
      });
      await moSvScreen(t, api);
      await bam(t, 'Điểm danh');
      await bam(t, 'Bắt đầu');
      expect(find.textContaining('Hãy báo giảng viên'), findsOneWidget);
    });
  });
}
