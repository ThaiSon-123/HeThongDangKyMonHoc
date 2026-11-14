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
  'di_tre': false,
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

/// `GET records/` của buổi (danh sách cả lớp, tỷ lệ vắng, quyền điểm danh) — dùng chung với điểm danh tay.
Map<String, dynamic> recordsJson() => {
  'session': {'id': 11, 'ngay_hoc': '2027-01-13'},
  'lop_trang_thai': 'DANG_HOC',
  'co_the_diem_danh': true,
  'con_han_sua': true,
  'so_ngay_xin_sua': 7,
  'tong_so_buoi': 1,
  'max_absent_pct': 20,
  'records': [
    for (final (id, ten, tt) in [
      (21, 'Trần Hoàng Nam', 'CO_MAT'),
      (22, 'Lê Thu Hà', 'VANG_KHONG_PHEP'),
      (23, 'Phạm Văn An', 'VANG_KHONG_PHEP'),
    ])
      {
        'sinh_vien': id,
        'ma_sv': 'SV$id',
        'ho_ten': ten,
        'trang_thai': tt,
        'di_tre': false,
        'ghi_chu': '',
        'da_luu': true,
        'so_buoi_vang_kp': 0,
        'ty_le_vang': 0.0,
        'canh_bao_vang': false,
      },
  ],
};

FakeAdapter gv(Map<String, Handler> extra) => FakeAdapter({
  'GET /profiles/me/': (_) => reply(
    200,
    userJson('GIAO_VIEN', name: 'Trần Minh Quân', username: 'gv001'),
  ),
  'GET /class-sections/my/': (_) => reply(200, pageOf([lopGv()])),
  'GET /attendance/requests/': (_) => reply(200, pageOf([])),
  'GET /attendance/sessions/11/records/': (_) => reply(200, recordsJson()),
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

/// Màn "Điểm danh" của GV (đã gộp tự điểm danh): chọn lớp → bấm buổi hôm nay (13/01/2027).
Future<void> moGv(WidgetTester t, FakeAdapter api) async {
  await openPdt(t, api, '/teacher/attendance', overrides: _overrides);
  await bam(t, '— Chọn lớp để bắt đầu —');
  await t.tap(find.text('CNTT101-01 · Nhập môn lập trình').last);
  await cho(t);
  await bam(t, 'Thứ 4, 13/01/2027');
}

void main() {
  group('GV — tự điểm danh (trong màn Điểm danh)', () {
    testWidgets('mở phiên: lấy GPS rồi gửi đủ tham số', (t) async {
      var daMo = false;
      final api = gv({
        'GET /attendance/sessions/11/tu-diem-danh/': (_) =>
            reply(200, live(mo: daMo, daMo: daMo)),
        'POST /attendance/sessions/11/mo-phien/': (_) {
          daMo = true;
          return reply(200, phienJson());
        },
      });
      await moGv(t, api);
      expect(find.text('Mở phiên tự điểm danh'), findsOneWidget);
      // Chưa mở phiên: vẫn điểm danh tay và lưu cả lớp như cũ.
      expect(find.text('Lưu điểm danh'), findsOneWidget);

      await bam(t, 'Lấy vị trí và mở phiên');
      final body = api.bodies['POST /attendance/sessions/11/mo-phien/'] as Map;
      expect((body['mau_gps'] as List).length, 5);
      expect(body['thoi_han'], 10);
      expect(body['r0'], 20);
      expect(body['kiem_tra_phong'], false);
      expect(find.text('Tự điểm danh đang mở · còn 05:00'), findsOneWidget);
    });

    testWidgets(
      'phiên đang mở: không có nút lưu cả lớp, báo mỗi thay đổi lưu ngay',
      (t) async {
        final api = gv({
          'GET /attendance/sessions/11/tu-diem-danh/': (_) =>
              reply(200, live()),
        });
        await moGv(t, api);
        expect(find.text('Lưu điểm danh'), findsNothing);
        expect(
          find.textContaining('mỗi thay đổi được lưu ngay'),
          findsOneWidget,
        );
      },
    );

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
      await bam(t, 'Xem lượt'); // chỉ SV Lê Thu Hà có lượt
      expect(find.textContaining('cách 41 m / r 34 m'), findsOneWidget);
      await bam(t, 'Duyệt có mặt');
      expect(api.bodies['POST /attendance/attempts/7/quyet/'], {
        'co_mat': true,
      });
    });

    testWidgets(
      'phiên mở: bấm trạng thái lưu ngay cho riêng SV đó (kể cả Đi trễ)',
      (t) async {
        final api = gv({
          'GET /attendance/sessions/11/tu-diem-danh/': (_) =>
              reply(200, live()),
          'PATCH /attendance/sessions/11/tu-diem-danh/': (_) =>
              reply(200, live()),
        });
        await moGv(t, api);
        // Phạm Văn An (SV23, chưa có mẫu mặt) là dòng thứ 3: GV điểm danh thủ công.
        final diTre = find.widgetWithText(ChoiceChip, 'Đi trễ').at(2);
        await t.ensureVisible(diTre);
        await t.pump();
        await t.tap(diTre);
        await cho(t);
        expect(api.bodies['PATCH /attendance/sessions/11/tu-diem-danh/'], {
          'sinh_vien': [23],
          'trang_thai': 'CO_MAT',
          'di_tre': true,
        });
        // "Có mặt" thường: chip đầu tiên là bộ lọc, 3 chip tiếp theo là 3 dòng.
        final coMat = find.widgetWithText(ChoiceChip, 'Có mặt').at(3);
        await t.ensureVisible(coMat);
        await t.pump();
        await t.tap(coMat);
        await cho(t);
        expect(api.bodies['PATCH /attendance/sessions/11/tu-diem-danh/'], {
          'sinh_vien': [23],
          'trang_thai': 'CO_MAT',
          'di_tre': false,
        });
      },
    );

    testWidgets('phiên đã đóng → mở lại', (t) async {
      final api = gv({
        'GET /attendance/sessions/11/tu-diem-danh/': (_) =>
            reply(200, live(mo: false)),
        'POST /attendance/sessions/11/mo-lai/': (_) => reply(200, phienJson()),
      });
      await moGv(t, api);
      expect(find.text('Tự điểm danh đã đóng'), findsOneWidget);
      // Phiên đã đóng: trở lại chọn rồi lưu cả lớp.
      expect(find.text('Lưu điểm danh'), findsOneWidget);
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

    Map<String, dynamic> myJson() => {
      'hoc_ky': 7,
      'ten_hk': 'Học kỳ 2, 2026–2027',
      'max_absent_pct': 20,
      'so_ngay_xin_sua': 7,
      'lop_hoc_phan': <Object>[],
    };

    testWidgets('màn Điểm danh: thẻ phiên đang mở → bấm vào luồng điểm danh', (
      t,
    ) async {
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv()]),
        'GET /attendance/my/': (_) => reply(200, myJson()),
        'GET /attendance/requests/': (_) => reply(200, pageOf([])),
        'POST /attendance/sessions/11/challenge/': (_) =>
            reply(201, thuThach()),
      });
      await openPdt(t, api, '/student/attendance', overrides: _overrides);
      await cho(t);
      expect(find.text('CNTT101-01 · Nhập môn lập trình'), findsOneWidget);
      expect(find.text('Khuôn mặt điểm danh'), findsOneWidget);

      await bam(t, 'Điểm danh');
      await bam(t, 'Bắt đầu');
      expect(
        api.log.any(
          (l) => l.startsWith('POST /attendance/sessions/11/challenge/'),
        ),
        isTrue,
      );
    });

    for (final (tt, extra, nhan) in [
      ('CHUA_CO', <String, dynamic>{}, 'Chưa đăng ký'),
      ('CHO_DUYET', <String, dynamic>{}, 'Chờ duyệt'),
      ('TU_CHOI', <String, dynamic>{}, 'Bị từ chối'),
      ('DUYET', <String, dynamic>{}, 'Đã duyệt'),
      ('DUYET', <String, dynamic>{'can_dang_ky_lai': true}, 'Cần đăng ký lại'),
    ]) {
      testWidgets('màn Điểm danh: khuôn mặt $tt $extra → "$nhan"', (t) async {
        final api = svApi({
          'GET /attendance/open-sessions/': (_) => reply(200, []),
          'GET /attendance/my/': (_) => reply(200, myJson()),
          'GET /attendance/requests/': (_) => reply(200, pageOf([])),
          'GET /attendance/face/me/': (_) => reply(200, {
            'da_dong_y': true,
            'trang_thai': tt,
            'ly_do': '',
            'can_dang_ky_lai': false,
            'dang_cho_cap_nhat': false,
            ...extra,
          }),
        });
        await openPdt(t, api, '/student/attendance', overrides: _overrides);
        await cho(t);
        expect(find.text(nhan), findsOneWidget);
      });
    }

    testWidgets('màn Điểm danh: không có phiên mở thì chỉ còn lối vào khuôn mặt', (
      t,
    ) async {
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, []),
        'GET /attendance/my/': (_) => reply(200, myJson()),
        'GET /attendance/requests/': (_) => reply(200, pageOf([])),
      });
      await openPdt(t, api, '/student/attendance', overrides: _overrides);
      await cho(t);
      expect(find.text('Khuôn mặt điểm danh'), findsOneWidget);
      expect(find.text('CNTT101-01 · Nhập môn lập trình'), findsNothing);
    });

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
