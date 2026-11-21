import 'dart:typed_data';

import 'package:dang_ky_mon_hoc/features/attendance/face/face_capture.dart';
import 'package:dang_ky_mon_hoc/features/attendance/face/quet_mat_ui.dart';
import 'package:dang_ky_mon_hoc/features/attendance/tu_diem_danh/quet_qr.dart';
import 'package:dang_ky_mon_hoc/features/attendance/tu_diem_danh/thiet_bi.dart';
import 'package:dang_ky_mon_hoc/features/registration/timetable_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'helpers/fake_api.dart';
import 'attendance_test.dart' show lopGv;
import 'helpers/pdt_helpers.dart';

final _now = DateTime(2027, 1, 13, 8, 0);

/// Đồng hồ + GPS giả (chưa có camera) — test nào tự giả camera thì dùng danh sách này.
final _overridesKhongCamera = [
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
];

final _overrides = [
  ..._overridesKhongCamera,
  // Camera giả: trả 6 khung và gửi luôn như màn camera thật (kết quả hiện trên màn camera bị bỏ qua).
  faceBurstProvider.overrideWithValue((context, chuoi, {hetHan, gui}) async {
    final khung = [
      for (var i = 0; i < 6; i++) Uint8List.fromList([i]),
    ];
    await gui?.call(khung);
    return khung;
  }),
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
    testWidgets('mở phiên: không lấy GPS giảng viên, gửi thời hạn + mã phòng', (
      t,
    ) async {
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

      await bam(t, 'Mở phiên');
      expect(api.bodies['POST /attendance/sessions/11/mo-phien/'], {
        'thoi_han': 10,
        'kiem_tra_phong': false,
        'kiem_tra_gps': true,
      });
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

    testWidgets('phiên bắt mã phòng: hiện QR mã QR, không lộ mã Bluetooth', (
      t,
    ) async {
      final api = gv({
        'GET /attendance/sessions/11/tu-diem-danh/': (_) => reply(200, {
          ...live(),
          'session': {...phienJson(), 'kiem_tra_phong': true},
        }),
        'GET /attendance/sessions/11/room-token/': (_) => reply(200, {
          'ma': 'K7Q2M9XA',
          'ma_ble': 'B1E2C3D4',
          'het_han_sau_giay': 20,
        }),
      });
      await moGv(t, api);
      expect(find.byType(QrImageView), findsOneWidget);
      final qr = t.widget<QrImageView>(find.byType(QrImageView));
      expect(qr.key, const ValueKey('K7Q2M9XA'));
      expect(find.text('K7Q2 M9XA'), findsOneWidget);
      expect(find.textContaining('B1E2'), findsNothing);
    });

    testWidgets('danh sách: đếm, cờ, SV chưa có mẫu mặt', (t) async {
      final api = gv({
        'GET /attendance/sessions/11/tu-diem-danh/': (_) => reply(200, live()),
      });
      await moGv(t, api);
      expect(find.text('Có mặt: 1'), findsOneWidget);
      expect(find.text('Đáng ngờ: 1'), findsOneWidget);
      expect(find.textContaining('Sát mép khuôn viên'), findsOneWidget);
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
      expect(
        find.textContaining('ngoài khuôn viên 41 m / cho phép 34 m'),
        findsOneWidget,
      );
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
    Map<String, dynamic> moSv({
      int con = 5,
      String tt = 'VANG_KHONG_PHEP',
      bool qr = false,
      bool gps = true,
    }) => {
      'id': 11,
      'lop_hoc_phan': 3,
      'ma_lop': 'CNTT101-01',
      'ten_mon': 'Nhập môn lập trình',
      'ngay_hoc': '2027-01-13',
      'buoi': 'SANG',
      'het_han_luc': '2027-01-13T08:05:00+07:00',
      'kiem_tra_phong': qr,
      'kiem_tra_gps': gps,
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

    final viTriDat = <String, Handler>{
      'POST /attendance/sessions/11/kiem-tra-vi-tri/': (_) => reply(200, {
        'dat': true,
        'ma': null,
        'thong_bao': 'Bạn đang trong khuôn viên trường.',
      }),
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
        ...viTriDat,
        'POST /attendance/sessions/11/challenge/': (_) =>
            reply(201, thuThach()),
      });
      await openPdt(t, api, '/student/attendance', overrides: _overrides);
      await cho(t);
      expect(find.text('CNTT101-01 · Nhập môn lập trình'), findsOneWidget);
      expect(find.text('Khuôn mặt điểm danh'), findsOneWidget);

      await bam(t, 'Điểm danh'); // thẻ phiên → vào luồng
      await bam(t, 'Điểm danh'); // nút bắt đầu trong luồng
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

    testWidgets(
      'màn Điểm danh: không có phiên mở thì chỉ còn lối vào khuôn mặt',
      (t) async {
        final api = svApi({
          'GET /attendance/open-sessions/': (_) => reply(200, []),
          'GET /attendance/my/': (_) => reply(200, myJson()),
          'GET /attendance/requests/': (_) => reply(200, pageOf([])),
        });
        await openPdt(t, api, '/student/attendance', overrides: _overrides);
        await cho(t);
        expect(find.text('Khuôn mặt điểm danh'), findsOneWidget);
        expect(find.text('CNTT101-01 · Nhập môn lập trình'), findsNothing);
      },
    );

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

    testWidgets(
      'đủ bước: GPS (báo trong khuôn viên) → thử thách → chụp → có mặt',
      (t) async {
        final api = svApi({
          'GET /attendance/open-sessions/': (_) => reply(200, [moSv()]),
          ...viTriDat,
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
        await bam(t, 'Điểm danh');
        final body =
            api.bodies['POST /attendance/sessions/11/checkin/'] as FormData;
        final f = Map.fromEntries(body.fields);
        expect(f['nonce'], 'n1');
        expect(f['mau_gps'], contains('"lat":10.98'));
        expect(f['nen_tang'], 'android');
        expect(f['device_id'], hasLength(32));
        expect(body.files.length, 6);
        expect(find.text('Đã ghi nhận có mặt.'), findsOneWidget);
        // GPS được kiểm tra (gửi đúng mẫu) trước khi xin thử thách.
        final viTri = api.log.indexWhere(
          (l) => l.startsWith('POST /attendance/sessions/11/kiem-tra-vi-tri/'),
        );
        final thu = api.log.indexWhere(
          (l) => l.startsWith('POST /attendance/sessions/11/challenge/'),
        );
        expect(viTri, greaterThanOrEqualTo(0));
        expect(viTri, lessThan(thu));
        final mau =
            (api.bodies['POST /attendance/sessions/11/kiem-tra-vi-tri/']
                    as Map)['mau_gps']
                as List;
        expect(mau, hasLength(5));
        expect(find.text('Bạn đang trong khuôn viên trường.'), findsOneWidget);
      },
    );

    testWidgets('màn camera nhận hạn thử thách và hiện kết quả gửi lượt', (
      t,
    ) async {
      DateTime? hanNhan;
      final ketQua = <KetQuaQuet>[];
      var luot = 0;
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv()]),
        ...viTriDat,
        'POST /attendance/sessions/11/challenge/': (_) =>
            reply(201, thuThach()),
        'POST /attendance/sessions/11/checkin/': (_) => ++luot == 1
            ? reply(200, {
                'ket_qua': 'KHONG_DAT',
                'trang_thai': 'VANG_KHONG_PHEP',
                'dang_ngo': false,
                'ly_do': {'ma': 'ANH_MO', 'thong_bao': 'Ảnh bị mờ.'},
                'luot_con_lai': 3,
              })
            : apiError(409, 'TRANG_THAI_KHONG_HOP_LE', 'Thử thách hết hạn.'),
      });
      await openPdt(
        t,
        api,
        '/student/checkin',
        overrides: [
          ..._overridesKhongCamera,
          faceBurstProvider.overrideWithValue((
            context,
            chuoi, {
            hetHan,
            gui,
          }) async {
            hanNhan = hetHan;
            final khung = [
              Uint8List.fromList([1]),
            ];
            ketQua.add(await gui!(khung));
            return khung;
          }),
        ],
      );
      await bam(t, 'Điểm danh');
      await bam(t, 'Điểm danh');
      expect(hanNhan, DateTime.parse('2027-01-13T08:01:00+07:00'));
      expect(ketQua.single, (
        loai: LoaiKetQua.khongDat,
        tieuDe: 'Chưa điểm danh được.',
        chiTiet: 'Ảnh bị mờ.',
      ));
      expect(find.text('Chưa điểm danh được.'), findsOneWidget);

      // Gửi lỗi: màn camera báo lỗi, về màn điểm danh hiện thông điệp server.
      await bam(t, 'Thử lại');
      expect(ketQua.last.tieuDe, 'Gửi lượt điểm danh thất bại.');
      expect(ketQua.last.chiTiet, 'Thử thách hết hạn.');
      expect(find.text('Thử thách hết hạn.'), findsOneWidget);
    });

    testWidgets(
      'phiên tắt GPS → bỏ bước vị trí (mau_gps rỗng dù máy có GPS), có mặt',
      (t) async {
        final api = svApi({
          'GET /attendance/open-sessions/': (_) =>
              reply(200, [moSv(gps: false)]),
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
        await bam(t, 'Điểm danh');
        final body =
            api.bodies['POST /attendance/sessions/11/checkin/'] as FormData;
        final f = Map.fromEntries(body.fields);
        expect(f['mau_gps'], '[]');
        expect(find.text('Đã ghi nhận có mặt.'), findsOneWidget);
      },
    );

    testWidgets(
      'bắt mã phòng, máy không có Bluetooth: gõ mã QR → tiếp tục không Bluetooth',
      (t) async {
        final api = svApi({
          'GET /attendance/open-sessions/': (_) => reply(200, [moSv(qr: true)]),
          ...viTriDat,
          'POST /attendance/sessions/11/challenge/': (_) =>
              reply(201, thuThach(qr: true)),
          'POST /attendance/sessions/11/checkin/': (_) => reply(200, {
            'ket_qua': 'DANG_NGO',
            'trang_thai': 'VANG_KHONG_PHEP',
            'dang_ngo': true,
            'ly_do': null,
            'luot_con_lai': 3,
          }),
        });
        await moSvScreen(t, api); // test chạy trên VM: không có Bluetooth
        await bam(t, 'Điểm danh');
        await bam(t, 'Điểm danh');
        // Chưa có mã QR thì chưa xin thử thách (chưa tính lượt).
        expect(api.log.any((l) => l.contains('/challenge/')), isFalse);
        await t.enterText(find.byType(TextField), 'k7q2 m9xa');
        await bam(t, 'Tiếp tục');
        expect(find.text('Đã có mã QR.'), findsOneWidget);
        expect(
          find.text('Máy hoặc trình duyệt này không kiểm tra được Bluetooth.'),
          findsOneWidget,
        );
        expect(api.log.any((l) => l.contains('/challenge/')), isFalse);
        await bam(t, 'Tiếp tục không có Bluetooth');
        expect(api.bodies['POST /attendance/sessions/11/challenge/'], {
          'ma_phong': 'k7q2 m9xa',
        });
        expect(
          find.text(
            'Không xác nhận Bluetooth: lượt này sẽ chờ giảng viên duyệt.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Đã ghi nhận, chờ giảng viên xác nhận.'),
          findsWidgets,
        );
      },
    );

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
        ...viTriDat,
        'POST /attendance/sessions/11/challenge/': (_) => apiError(
          409,
          'TRANG_THAI_KHONG_HOP_LE',
          'Bạn chưa có mẫu khuôn mặt được duyệt. Hãy báo giảng viên để điểm danh thủ công.',
        ),
      });
      await moSvScreen(t, api);
      await bam(t, 'Điểm danh');
      await bam(t, 'Điểm danh');
      expect(find.textContaining('Hãy báo giảng viên'), findsOneWidget);
    });

    testWidgets('GPS ngoài khuôn viên → dừng trước quét mặt, chưa tính lượt', (
      t,
    ) async {
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv(qr: true)]),
        'POST /attendance/sessions/11/kiem-tra-vi-tri/': (_) => reply(200, {
          'dat': false,
          'ma': 'QUA_XA',
          'thong_bao':
              'Bạn đang ở ngoài khuôn viên trường (cách khoảng 250 m).',
        }),
      });
      await moSvScreen(t, api);
      await bam(t, 'Điểm danh');
      await bam(t, 'Điểm danh');
      expect(
        find.text('Bạn đang ở ngoài khuôn viên trường (cách khoảng 250 m).'),
        findsOneWidget,
      );
      expect(find.text('Chưa bị tính lượt.'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      // Không sang bước QR, không xin thử thách.
      expect(find.text('Quét QR'), findsNothing);
      expect(
        api.log.any(
          (l) => l.contains('/challenge/') || l.contains('/checkin/'),
        ),
        isFalse,
      );
    });

    /// Máy có Bluetooth (app Android: [tuDong], web: bấm chọn); [qr] = kết quả quét QR (null = hủy).
    List<Override> esp({
      required bool tuDong,
      String? ma,
      List<int>? dem,
      String? qr = 'K7Q2M9XA',
    }) => [
      ..._overrides,
      docEsp32Provider.overrideWithValue((
        hoTro: true,
        tuDong: tuDong,
        doc: () async {
          dem?.add(1);
          return ma;
        },
      )),
      quetQrProvider.overrideWithValue((_) async => qr),
    ];

    Map<String, Handler> coMat() => {
      'POST /attendance/sessions/11/checkin/': (_) => reply(200, {
        'ket_qua': 'CO_MAT',
        'trang_thai': 'CO_MAT',
        'dang_ngo': false,
        'ly_do': null,
        'luot_con_lai': 4,
      }),
    };

    testWidgets(
      'app Android: GPS → quét QR → tự dò Bluetooth → gửi đủ hai mã → có mặt',
      (t) async {
        final api = svApi({
          'GET /attendance/open-sessions/': (_) => reply(200, [moSv(qr: true)]),
          ...viTriDat,
          'POST /attendance/sessions/11/challenge/': (_) =>
              reply(201, thuThach(qr: true)),
          ...coMat(),
        });
        await openPdt(
          t,
          api,
          '/student/checkin',
          overrides: esp(tuDong: true, ma: 'B1E2C3D4'),
        );
        await bam(t, 'Điểm danh');
        await bam(t, 'Điểm danh');
        expect(api.log.any((l) => l.contains('/challenge/')), isFalse);
        await bam(t, 'Quét QR');
        expect(api.bodies['POST /attendance/sessions/11/challenge/'], {
          'ma_phong': 'K7Q2M9XA',
          'ma_bluetooth': 'B1E2C3D4',
        });
        expect(find.text('Bạn đang trong khuôn viên trường.'), findsOneWidget);
        expect(find.text('Mã QR hợp lệ.'), findsOneWidget);
        expect(
          find.text('Đã xác nhận bạn đang trong phòng học.'),
          findsOneWidget,
        );
        expect(find.text('Khuôn mặt khớp với tài khoản.'), findsOneWidget);
        expect(find.text('Đã ghi nhận có mặt.'), findsOneWidget);
      },
    );

    testWidgets('hủy quét QR → ở lại bước QR, không gọi API', (t) async {
      final dem = <int>[];
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv(qr: true)]),
        ...viTriDat,
      });
      await openPdt(
        t,
        api,
        '/student/checkin',
        overrides: esp(tuDong: true, ma: 'B1E2C3D4', dem: dem, qr: null),
      );
      await bam(t, 'Điểm danh');
      await bam(t, 'Điểm danh');
      await bam(t, 'Quét QR');
      expect(find.text('Quét QR'), findsOneWidget);
      expect(dem, isEmpty);
      expect(api.log.any((l) => l.contains('/challenge/')), isFalse);
    });

    testWidgets(
      'app Android: không thấy thiết bị → báo, dò lại, rồi tiếp tục không Bluetooth',
      (t) async {
        final dem = <int>[];
        final api = svApi({
          'GET /attendance/open-sessions/': (_) => reply(200, [moSv(qr: true)]),
          ...viTriDat,
          'POST /attendance/sessions/11/challenge/': (_) =>
              reply(201, thuThach(qr: true)),
          ...coMat(),
        });
        await openPdt(
          t,
          api,
          '/student/checkin',
          overrides: esp(tuDong: true, dem: dem),
        );
        await bam(t, 'Điểm danh');
        await bam(t, 'Điểm danh');
        await bam(t, 'Quét QR');
        expect(
          find.textContaining('Không thấy thiết bị của giảng viên'),
          findsOneWidget,
        );
        expect(api.log.any((l) => l.contains('/challenge/')), isFalse);
        expect(dem, hasLength(1));
        await bam(t, 'Dò lại');
        expect(dem, hasLength(2));
        await bam(t, 'Tiếp tục không có Bluetooth');
        expect(api.bodies['POST /attendance/sessions/11/challenge/'], {
          'ma_phong': 'K7Q2M9XA',
        });
      },
    );

    testWidgets('web: sau QR đợi sinh viên bấm chọn thiết bị (không tự dò)', (
      t,
    ) async {
      final dem = <int>[];
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv(qr: true)]),
        ...viTriDat,
        'POST /attendance/sessions/11/challenge/': (_) =>
            reply(201, thuThach(qr: true)),
        ...coMat(),
      });
      await openPdt(
        t,
        api,
        '/student/checkin',
        overrides: esp(tuDong: false, ma: 'B1E2C3D4', dem: dem),
      );
      await bam(t, 'Điểm danh');
      await bam(t, 'Điểm danh');
      await bam(t, 'Quét QR');
      expect(dem, isEmpty);
      expect(api.log.any((l) => l.contains('/challenge/')), isFalse);
      await bam(t, 'Kiểm tra Bluetooth (chọn thiết bị)');
      expect(dem, hasLength(1));
      expect(api.bodies['POST /attendance/sessions/11/challenge/'], {
        'ma_phong': 'K7Q2M9XA',
        'ma_bluetooth': 'B1E2C3D4',
      });
    });

    testWidgets('server báo sai mã Bluetooth → ở lại bước Bluetooth', (
      t,
    ) async {
      final api = svApi({
        'GET /attendance/open-sessions/': (_) => reply(200, [moSv(qr: true)]),
        ...viTriDat,
        'POST /attendance/sessions/11/challenge/': (_) => reply(409, {
          'error': {
            'code': 'TRANG_THAI_KHONG_HOP_LE',
            'message': 'Mã Bluetooth không đúng hoặc đã hết hạn.',
            'details': {'ly_do': 'MA_BLUETOOTH_SAI'},
          },
        }),
      });
      await openPdt(
        t,
        api,
        '/student/checkin',
        overrides: esp(tuDong: true, ma: 'B1E2C3D4'),
      );
      await bam(t, 'Điểm danh');
      await bam(t, 'Điểm danh');
      await bam(t, 'Quét QR');
      expect(
        find.text('Mã Bluetooth không đúng hoặc đã hết hạn.'),
        findsOneWidget,
      );
      expect(find.text('Dò lại'), findsOneWidget);
      expect(find.text('Đã có mã QR.'), findsOneWidget);
    });
  });
}
