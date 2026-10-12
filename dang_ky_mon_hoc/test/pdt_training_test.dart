import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> mon(
  int id,
  String ma,
  String ten, {
  int lt = 2,
  int th = 1,
  String tt = 'HOAT_DONG',
}) => {
  'id': id,
  'ma_mon': ma,
  'ten_mon': ten,
  'tong_tin_chi': lt + th,
  'tin_chi_ly_thuyet': lt,
  'tin_chi_thuc_hanh': th,
  'so_tiet_ly_thuyet': 30,
  'so_tiet_thuc_hanh': 15,
  'loai_danh_gia': 'DIEM',
  'khoa': 1,
  'khoa_ten': 'Khoa CNTT',
  'trang_thai': tt,
};

Map<String, dynamic> hocKy({String tt = 'MO'}) => {
  'id': 7,
  'ten_hk': 'Học kỳ 2',
  'nam_hoc': '2026-2027',
  'ngay_bat_dau': '2027-01-04',
  'ngay_ket_thuc': '2027-05-30',
  'cua_so_dk_bat_dau': '2027-01-05T08:00:00+07:00',
  'cua_so_dk_ket_thuc': '2027-01-19T08:00:00+07:00',
  'tin_chi_toi_thieu': 12,
  'tin_chi_toi_da': 24,
  'tin_chi_toi_da_canh_bao': 14,
  'trang_thai': tt,
};

Map<String, dynamic> lop({
  String tt = 'KE_HOACH',
  List<Map<String, dynamic>> lich = const [],
}) => {
  'id': 3,
  'ma_lop': 'CNTT101-01',
  'mon_hoc': 1,
  'ma_mon': 'CNTT101',
  'ten_mon': 'Nhập môn lập trình',
  'hoc_ky': 7,
  'ten_hk': 'Học kỳ 2',
  'giao_vien': 4,
  'giao_vien_ten': 'Trần Minh Quân',
  'si_so_toi_da': 45,
  'si_so_hien_tai': 40,
  'ngay_bat_dau': '2027-01-04',
  'ngay_ket_thuc': '2027-04-30',
  'han_nhap_diem': null,
  'han_nhap_diem_hieu_luc': '2027-05-14',
  'trang_thai': tt,
  'lich_hoc': lich,
};

void main() {
  group('Môn học & tiên quyết', () {
    testWidgets(
      'bảng môn: tín chỉ (LT + TH); thêm môn gửi LT/TH, không gửi tổng',
      (t) async {
        final api = pdtApi({
          'GET /courses/': (_) => reply(
            200,
            pageOf([
              mon(1, 'CNTT101', 'Nhập môn lập trình'),
              mon(2, 'MAT101', 'Giải tích 1', tt: 'NGUNG_SU_DUNG'),
            ]),
          ),
          'GET /faculties/': (_) => reply(
            200,
            pageOf([
              {'id': 1, 'ten_khoa': 'Khoa CNTT', 'ma_khoa': 'CNTT'},
            ]),
          ),
          'POST /courses/': (_) => reply(201, mon(9, 'X', 'Y')),
          'PATCH /courses/1/': (_) => reply(
            200,
            mon(1, 'CNTT101', 'Nhập môn lập trình', tt: 'NGUNG_SU_DUNG'),
          ),
        });
        await openPdt(t, api, '/pdt/courses');
        expect(
          find.textContaining('(2 LT + 1 TH)', findRichText: true),
          findsWidgets,
        );
        expect(find.text('Dùng lại'), findsOneWidget); // môn đã ngừng sử dụng

        await tapText(t, 'Ngừng sử dụng'); // nút của dòng 1
        await tapText(
          t,
          'Ngừng sử dụng',
          index: 2,
        ); // nút xác nhận trong hộp thoại
        expect(api.bodies['PATCH /courses/1/'], {
          'trang_thai': 'NGUNG_SU_DUNG',
        });

        await tapText(t, '+ Thêm môn học');
        expect(find.textContaining('hệ thống tự tính'), findsOneWidget);
        await enterField(t, 'Mã môn', 'IT9');
        await enterField(t, 'Tên môn', 'Môn mới');
        await enterField(t, 'TC lý thuyết', '2');
        await enterField(t, 'TC thực hành', '1');
        await enterField(t, 'Số tiết LT', '30');
        await enterField(t, 'Số tiết TH', '15');
        await enterField(t, 'Khoa / viện phụ trách', 'Khoa');
        await t.pumpAndSettle();
        await t.tap(find.text('Khoa CNTT').last); // gợi ý nằm trên lớp phủ
        await t.pumpAndSettle();
        await tapText(t, 'Lưu');
        final body = api.bodies['POST /courses/'] as Map;
        expect(body['tin_chi_ly_thuyet'], 2);
        expect(body['khoa'], 1);
        expect(body.containsKey('tong_tin_chi'), isFalse);
      },
    );

    testWidgets(
      'tab Tiên quyết: chọn môn, thêm; vòng bị server chặn hiện lỗi',
      (t) async {
        final api = pdtApi({
          'GET /courses/': (_) => reply(
            200,
            pageOf([
              mon(1, 'CNTT101', 'Nhập môn lập trình'),
              mon(2, 'CNTT201', 'Cấu trúc dữ liệu'),
            ]),
          ),
          'GET /prerequisites/': (_) => reply(
            200,
            pageOf([
              {
                'id': 5,
                'mon_hoc': 2,
                'ma_mon': 'CNTT201',
                'mon_tien_quyet': 1,
                'ma_mon_tien_quyet': 'CNTT101',
              },
            ]),
          ),
          'POST /prerequisites/': (_) => reply(400, {
            'mon_tien_quyet': ['Tạo vòng lặp tiên quyết (chu trình).'],
          }),
        });
        await openPdt(t, api, '/pdt/courses');
        await tapText(t, 'Tiên quyết');
        expect(
          find.text(
            'Chọn một môn ở trên để xem và chỉnh môn tiên quyết của môn đó.',
          ),
          findsOneWidget,
        );

        await enterField(t, 'Chọn môn cần thiết lập tiên quyết', 'Cấu trúc');
        await t.pumpAndSettle();
        await tapText(t, 'Cấu trúc dữ liệu (CNTT201)', index: 0);
        expect(find.text('CNTT101'), findsOneWidget); // chip tiên quyết hiện có
        expect(api.queries['GET /prerequisites/']!['mon_hoc'], 2);

        await enterField(t, 'Thêm môn tiên quyết', 'Nhập');
        await t.pumpAndSettle();
        await tapText(t, 'Nhập môn lập trình (CNTT101)', index: 0);
        await tapText(t, 'Thêm');
        expect(api.bodies['POST /prerequisites/'], {
          'mon_hoc': 2,
          'mon_tien_quyet': 1,
        });
        expect(
          find.text('Tạo vòng lặp tiên quyết (chu trình).'),
          findsOneWidget,
        );
      },
    );
  });

  group('CTĐT & gán môn', () {
    testWidgets('Xem môn → tab môn của CTĐT: tổng tín chỉ đã gán, bỏ môn', (
      t,
    ) async {
      final api = pdtApi({
        'GET /curriculums/': (_) => reply(
          200,
          pageOf([
            {
              'id': 1,
              'ma_ctdt': 'CTDT-CNTT-K2023',
              'nganh': 1,
              'nganh_ten': 'CNTT',
              'khoa_tuyen_sinh': 'K2023',
              'tong_tin_chi_yeu_cau': 130,
              'trang_thai': 'HOAT_DONG',
            },
          ]),
        ),
        'GET /curriculum-courses/': (_) => reply(
          200,
          pageOf([
            {
              'id': 11,
              'ctdt': 1,
              'mon_hoc': 1,
              'ma_mon': 'CNTT101',
              'ten_mon': 'Nhập môn lập trình',
              'tong_tin_chi': 3,
              'khoi_kien_thuc': 'co_so_nganh',
              'loai_mon': 'bat_buoc',
              'hoc_ky_goi_y': 1,
            },
            {
              'id': 12,
              'ctdt': 1,
              'mon_hoc': 2,
              'ma_mon': 'CNTT201',
              'ten_mon': 'Cấu trúc dữ liệu',
              'tong_tin_chi': 4,
              'khoi_kien_thuc': 'chuyen_nganh',
              'loai_mon': 'tu_chon',
              'hoc_ky_goi_y': 3,
            },
          ]),
        ),
        'DELETE /curriculum-courses/11/': (_) => reply(204, {}),
      });
      await openPdt(t, api, '/pdt/curriculums');
      expect(find.text('CTDT-CNTT-K2023'), findsOneWidget);

      await tapText(t, 'Xem môn');
      expect(api.queries['GET /curriculum-courses/']!['ctdt'], 1);
      expect(find.text('Cơ sở ngành'), findsOneWidget);
      expect(find.text('Kỳ 3'), findsOneWidget);
      expect(find.textContaining('còn thiếu 123 tín chỉ'), findsOneWidget);

      await tapText(t, 'Bỏ');
      await tapText(t, 'Bỏ môn');
      expect(
        api.log.any((l) => l.startsWith('DELETE /curriculum-courses/11/')),
        isTrue,
      );
    });
  });

  group('Học kỳ', () {
    testWidgets(
      'chọn dòng → chi tiết; đóng bị chặn hiện thông điệp; sửa giới hạn tín chỉ',
      (t) async {
        final api = pdtApi({
          'GET /semesters/': (_) => reply(200, pageOf([hocKy()])),
          'POST /semesters/7/close/': (_) => apiError(
            409,
            'TRANG_THAI_KHONG_HOP_LE',
            'Không đóng được: học kỳ còn lớp đang mở hoặc đang học.',
          ),
          'PATCH /semesters/7/': (_) =>
              reply(200, {...hocKy(), 'tin_chi_toi_da': 20}),
        });
        await openPdt(t, api, '/pdt/semesters');
        expect(find.text('Chọn một học kỳ ở bảng phía trên.'), findsOneWidget);
        expect(find.text('12-24'), findsOneWidget);

        await tapText(t, 'Học kỳ 2');
        expect(find.text('Học kỳ 2 · 2026-2027'), findsOneWidget);
        expect(
          find.text('05/01/2027 08:00 – 19/01/2027 08:00'),
          findsOneWidget,
        );

        await tapText(t, 'Đóng học kỳ');
        await tapText(t, 'Đóng học kỳ', index: 1);
        expect(
          find.text('Không đóng được: học kỳ còn lớp đang mở hoặc đang học.'),
          findsOneWidget,
        );

        await tapText(t, 'Sửa giới hạn');
        await enterField(t, 'Tối đa', '20');
        await tapText(t, 'Lưu');
        expect(
          (api.bodies['PATCH /semesters/7/'] as Map)['tin_chi_toi_da'],
          20,
        );
        expect(find.textContaining('Tối đa 20'), findsOneWidget);
      },
    );
  });

  group('Lớp học phần', () {
    testWidgets('bảng; chi tiết: thêm lịch (Chủ nhật), mở lớp', (t) async {
      var lichDs = <Map<String, dynamic>>[];
      var tt = 'KE_HOACH';
      final api = pdtApi({
        'GET /class-sections/': (_) => reply(200, pageOf([lop(tt: tt)])),
        'GET /class-sections/3/': (_) => reply(200, lop(tt: tt, lich: lichDs)),
        'GET /semesters/': (_) => reply(200, pageOf([hocKy()])),
        'POST /schedules/': (_) {
          lichDs = [
            {
              'id': 1,
              'lop_hoc_phan': 3,
              'thu': 8,
              'tiet_bat_dau': 1,
              'so_tiet_moi_buoi': 3,
              'tiet_ket_thuc': 3,
              'buoi': 'SANG',
              'phong': 'A101',
            },
          ];
          return reply(201, lichDs.first);
        },
        'POST /class-sections/3/open/': (_) {
          tt = 'MO';
          return reply(200, lop(tt: tt, lich: lichDs));
        },
      });
      await openPdt(t, api, '/pdt/classes');
      expect(find.text('CNTT101-01'), findsOneWidget);
      expect(find.text('40/45'), findsOneWidget);
      expect(find.text('14/05/2027'), findsOneWidget); // hạn mặc định (BR-13)

      await tapText(t, 'Nhập môn lập trình');
      expect(find.text('Lớp chưa có lịch học.'), findsOneWidget);

      await tapText(t, 'Thêm buổi học');
      await tapText(t, 'Thứ 2');
      await tapText(t, 'Chủ nhật');
      await enterField(t, 'Phòng', 'A101');
      await tapText(t, 'Thêm lịch');
      expect(api.bodies['POST /schedules/'], {
        'thu': 8,
        'tiet_bat_dau': 1,
        'so_tiet_moi_buoi': 1,
        'phong': 'A101',
        'lop_hoc_phan': 3,
      });
      expect(find.text('Chủ nhật'), findsOneWidget);
      expect(find.text('Tiết 1–3 · sáng'), findsOneWidget);
      expect(find.byKey(const ValueKey('week-grid')), findsOneWidget);

      await tapText(t, 'Mở lớp');
      await tapText(t, 'Mở lớp', index: 1);
      expect(
        find.textContaining('Lớp tự chuyển sang Đang học'),
        findsOneWidget,
      );
    });

    testWidgets('mở lớp bị server từ chối → toast thông điệp', (t) async {
      final api = pdtApi({
        'GET /class-sections/': (_) => reply(200, pageOf([lop()])),
        'GET /class-sections/3/': (_) => reply(200, lop()),
        'POST /class-sections/3/open/': (_) =>
            apiError(409, 'TRANG_THAI_KHONG_HOP_LE', 'Lớp chưa có lịch học.'),
      });
      await openPdt(t, api, '/pdt/classes');
      await tapText(t, 'Nhập môn lập trình');
      await tapText(t, 'Mở lớp');
      await tapText(t, 'Mở lớp', index: 1);
      expect(find.text('Lớp chưa có lịch học.'), findsWidgets);
    });
  });
}
