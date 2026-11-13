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

  group('GV / PĐT — duyệt khuôn mặt', () {
    Map<String, Handler> routes() => {
      'GET /attendance/faces/pending/': (_) => reply(200, [
        {
          'id': 5,
          'sinh_vien': 21,
          'ma_sv': 'SV2023014',
          'ho_ten': 'Trần Hoàng Nam',
          'so_anh': 3,
          'tao_luc': '2027-01-12T08:00:00+07:00',
        },
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
    };

    testWidgets('PĐT xem 3 ảnh và từ chối kèm lý do', (t) async {
      final api = pdtApi(routes());
      await openPdt(t, api, '/pdt/faces');
      expect(find.text('Trần Hoàng Nam · SV2023014'), findsOneWidget);
      expect(find.byType(Image), findsNWidgets(3));
      expect(api.queries['GET /attendance/faces/5/photos/'], {
        'i': 2,
      }); // gọi đủ 3 ảnh, lần cuối i = 2

      await tapText(t, 'Từ chối');
      await t.enterText(find.byType(TextField).last, 'Ảnh tối');
      await t.pump();
      await tapText(t, 'Từ chối', index: 1);
      expect(api.bodies['POST /attendance/faces/5/review/'], {
        'duyet': false,
        'ly_do': 'Ảnh tối',
      });
    });

    testWidgets('GV duyệt', (t) async {
      final api = FakeAdapter({
        'GET /profiles/me/': (_) => reply(
          200,
          userJson('GIAO_VIEN', name: 'Trần Minh Quân', username: 'gv001'),
        ),
        ...routes(),
      });
      await openPdt(t, api, '/teacher/faces');
      await tapText(t, 'Duyệt');
      expect(api.bodies['POST /attendance/faces/5/review/'], {
        'duyet': true,
        'ly_do': '',
      });
    });

    testWidgets('không có mẫu chờ duyệt', (t) async {
      final api = pdtApi({
        'GET /attendance/faces/pending/': (_) => reply(200, []),
      });
      await openPdt(t, api, '/pdt/faces');
      expect(
        find.text('Không có khuôn mặt nào đang chờ duyệt.'),
        findsOneWidget,
      );
    });
  });
}
