import 'dart:convert';
import 'dart:typed_data';

import 'package:dang_ky_mon_hoc/features/attendance/face/face_capture.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

// PNG 1×1 hợp lệ (Image.memory giải mã được trong test).
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

Map<String, dynamic> me({
  bool dongY = true,
  String tt = 'CHUA_CO',
  String lyDo = '',
  bool dangKyLai = false,
}) => {
  'da_dong_y': dongY,
  'trang_thai': tt,
  'ly_do': lyDo,
  'can_dang_ky_lai': dangKyLai,
  'dang_cho_cap_nhat': false,
};

final _chupGia = faceCaptureProvider.overrideWithValue(
  (context, buoc) async => [
    for (var i = 0; i < buoc.length; i++) Uint8List.fromList([i]),
  ],
);

void main() {
  group('SV — khuôn mặt của tôi', () {
    testWidgets('chưa đồng ý → đồng ý → thấy nút đăng ký', (t) async {
      final api = svApi({
        'GET /attendance/face/me/': (_) => reply(200, me(dongY: false)),
        'POST /attendance/consent/': (_) => reply(200, me()),
      });
      await openPdt(t, api, '/student/face');
      expect(find.text('Đồng ý xử lý dữ liệu sinh trắc học'), findsOneWidget);

      await tapText(t, 'Tôi đồng ý');
      expect(
        api.log.any((l) => l.startsWith('POST /attendance/consent/')),
        isTrue,
      );
      expect(find.text('Chưa đăng ký'), findsOneWidget);
      expect(find.text('Đăng ký khuôn mặt'), findsOneWidget);
    });

    testWidgets('chụp 3 tư thế → gửi multipart → chờ duyệt', (t) async {
      final api = svApi({
        'GET /attendance/face/me/': (_) => reply(200, me()),
        'POST /attendance/faces/enroll/': (_) =>
            reply(201, me(tt: 'CHO_DUYET')),
      });
      await openPdt(t, api, '/student/face', overrides: [_chupGia]);

      await tapText(t, 'Đăng ký khuôn mặt');
      final body = api.bodies['POST /attendance/faces/enroll/'] as FormData;
      expect(body.files.map((f) => f.key), ['anh', 'anh', 'anh']);
      expect(find.text('Chờ duyệt'), findsOneWidget);
      expect(find.text('Xóa dữ liệu khuôn mặt'), findsOneWidget);
    });

    testWidgets('ảnh lỗi → hiện lý do từng ảnh của server', (t) async {
      const loi = 'Ảnh 2: Ảnh bị mờ, hãy giữ máy chắc tay.';
      final api = svApi({
        'GET /attendance/face/me/': (_) => reply(200, me()),
        'POST /attendance/faces/enroll/': (_) => reply(400, {
          'anh': [loi],
        }),
      });
      await openPdt(t, api, '/student/face', overrides: [_chupGia]);

      await tapText(t, 'Đăng ký khuôn mặt');
      expect(find.text(loi), findsOneWidget);
    });

    testWidgets('đổi mô hình → cần đăng ký lại', (t) async {
      final api = svApi({
        'GET /attendance/face/me/': (_) =>
            reply(200, me(tt: 'DUYET', dangKyLai: true)),
      });
      await openPdt(t, api, '/student/face');
      expect(find.text('Cần đăng ký lại'), findsOneWidget);
      expect(find.text('Đăng ký lại khuôn mặt'), findsOneWidget);
    });
    testWidgets('bị từ chối → hiện lý do', (t) async {
      final api = svApi({
        'GET /attendance/face/me/': (_) =>
            reply(200, me(tt: 'TU_CHOI', lyDo: 'Ảnh tối')),
      });
      await openPdt(t, api, '/student/face');
      expect(find.textContaining('Lý do: Ảnh tối'), findsOneWidget);
    });

    testWidgets('xóa khuôn mặt phải xác nhận', (t) async {
      final api = svApi({
        'GET /attendance/face/me/': (_) => reply(200, me(tt: 'DUYET')),
        'DELETE /attendance/face/me/': (_) => reply(200, me()),
      });
      await openPdt(t, api, '/student/face');

      await tapText(t, 'Xóa dữ liệu khuôn mặt');
      expect(find.text('Xóa dữ liệu khuôn mặt?'), findsOneWidget);
      await tapText(t, 'Xóa');
      expect(
        api.log.any((l) => l.startsWith('DELETE /attendance/face/me/')),
        isTrue,
      );
      expect(find.text('Chưa đăng ký'), findsOneWidget);
    });
  });

  group('PĐT — duyệt khuôn mặt', () {
    Map<String, dynamic> mau({String tt = 'CHO_DUYET'}) => {
      'id': 5,
      'trang_thai': tt,
      'ly_do': '',
      'tao_luc': '2027-01-12T08:00:00+07:00',
      'ngay_duyet': null,
      'nguoi_duyet': '',
      'sinh_vien': 21,
      'ma_sv': 'SV2023014',
      'ho_ten': 'Trần Hoàng Nam',
      'nganh': 'Công nghệ thông tin',
      'khoa_nhap_hoc': 'K2023',
      'so_anh': 3,
      'lan_thu': 2,
      'co_mau_khac_da_duyet': false,
      'lich_su': [
        {
          'id': 4,
          'trang_thai': 'TU_CHOI',
          'ly_do': 'Ảnh tối',
          'tao_luc': '2027-01-10T08:00:00+07:00',
          'ngay_duyet': '2027-01-11T08:00:00+07:00',
          'nguoi_duyet': 'Nguyễn Thị Phương Anh',
        },
      ],
    };

    Map<String, Handler> routes() => {
      'GET /attendance/faces/': (o) => reply(200, [
        mau(tt: o.queryParameters['trang_thai'] as String? ?? 'CHO_DUYET'),
      ]),
      'GET /attendance/faces/5/photos/': (_) => ResponseBody.fromBytes(
        _png,
        200,
        headers: {
          Headers.contentTypeHeader: ['image/png'],
        },
      ),
      'POST /attendance/faces/5/review/': (_) =>
          reply(200, {'id': 5, 'trang_thai': 'TU_CHOI'}),
      'POST /attendance/faces/5/thu-hoi/': (_) =>
          reply(200, {'id': 5, 'trang_thai': 'THU_HOI'}),
    };

    testWidgets(
      'xem thông tin, lịch sử, 3 ảnh và từ chối bằng lý do chọn nhanh',
      (t) async {
        final api = pdtApi(routes());
        await openPdt(t, api, '/pdt/faces');
        expect(find.text('Trần Hoàng Nam · SV2023014'), findsOneWidget);
        expect(
          find.textContaining('Công nghệ thông tin · Khóa K2023'),
          findsOneWidget,
        );
        expect(find.text('Lần đăng ký thứ 2'), findsOneWidget);
        expect(find.text('Các lần đăng ký khác (1)'), findsOneWidget);
        expect(find.byType(Image), findsNWidgets(3));
        expect(api.queries['GET /attendance/faces/5/photos/'], {
          'i': 2,
        }); // gọi đủ 3 ảnh, lần cuối i = 2

        await t.tap(find.widgetWithText(OutlinedButton, 'Từ chối'));
        await t.pumpAndSettle();
        await tapText(t, 'Ảnh mờ'); // lý do chọn nhanh
        await t.tap(find.text('Từ chối').last); // nút trong hộp thoại
        await t.pumpAndSettle();
        expect(api.bodies['POST /attendance/faces/5/review/'], {
          'duyet': false,
          'ly_do': 'Ảnh mờ',
        });
      },
    );

    testWidgets('duyệt', (t) async {
      final api = pdtApi(routes());
      await openPdt(t, api, '/pdt/faces');
      await t.tap(find.widgetWithText(FilledButton, 'Duyệt'));
      await t.pumpAndSettle();
      expect(api.bodies['POST /attendance/faces/5/review/'], {
        'duyet': true,
        'ly_do': '',
      });
    });

    testWidgets('tab Đã duyệt → thu hồi kèm lý do; tìm theo MSSV', (t) async {
      final api = pdtApi(routes());
      await openPdt(t, api, '/pdt/faces');
      await t.tap(find.widgetWithText(ChoiceChip, 'Đã duyệt'));
      await t.pumpAndSettle();
      expect(api.queries['GET /attendance/faces/'], {'trang_thai': 'DUYET'});
      await t.tap(find.widgetWithText(OutlinedButton, 'Thu hồi'));
      await t.pumpAndSettle();
      await tapText(t, 'Không phải sinh viên này');
      await t.tap(find.text('Thu hồi').last);
      await t.pumpAndSettle();
      expect(api.bodies['POST /attendance/faces/5/thu-hoi/'], {
        'ly_do': 'Không phải sinh viên này',
      });

      await t.enterText(find.byType(TextField).first, 'SV2023');
      await t.pump(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      expect(api.queries['GET /attendance/faces/'], {
        'trang_thai': 'DUYET',
        'q': 'SV2023',
      });
    });

    testWidgets('không có mẫu chờ duyệt', (t) async {
      final api = pdtApi({'GET /attendance/faces/': (_) => reply(200, [])});
      await openPdt(t, api, '/pdt/faces');
      expect(find.text('Không có mẫu nào chờ duyệt.'), findsOneWidget);
    });
  });
}
