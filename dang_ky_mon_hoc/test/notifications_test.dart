import 'package:dang_ky_mon_hoc/core/router/router_web.dart';
import 'package:dang_ky_mon_hoc/features/notifications/audit_log_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/fake_api.dart';
import 'helpers/pdt_helpers.dart';

Map<String, dynamic> tb(
  int id,
  String tieu, {
  bool daDoc = false,
  String tt = 'DA_GUI',
  String aud = 'USER',
  List<dynamic> refs = const [21],
  bool tuToi = false,
}) => {
  'id': id,
  'tieu_de': tieu,
  'noi_dung': 'Nội dung $tieu',
  'audience': aud,
  'target_refs': refs,
  'nguoi_gui_ten': 'pdt01',
  'ngay_gui': '2027-01-12T08:00:00+07:00',
  'trang_thai': tt,
  'da_doc': daDoc,
  'tu_toi': tuToi,
};

Map<String, dynamic> inbox(List<Map<String, dynamic>> rows, {int? chuaDoc}) => {
  ...pageOf(rows),
  'chua_doc': chuaDoc ?? rows.where((r) => r['da_doc'] != true).length,
};

FakeAdapter svApi2(Map<String, Handler> extra) =>
    svApi({'GET /notifications/': (_) => reply(200, inbox([])), ...extra});

void main() {
  group('Hộp thư', () {
    testWidgets(
      'sinh viên: danh sách, Mới/đã đọc, bấm để đánh dấu đã đọc, không có nút gửi',
      (t) async {
        var daDoc = false;
        final api = svApi2({
          'GET /notifications/': (_) => reply(
            200,
            inbox([
              tb(1, 'Điểm mới', daDoc: daDoc),
              tb(2, 'Lịch thi', daDoc: true),
            ]),
          ),
          'PATCH /notifications/1/read/': (_) {
            daDoc = true;
            return reply(200, tb(1, 'Điểm mới', daDoc: true));
          },
        });
        await openStudent(t, api, '/student/notifications');
        expect(find.text('Điểm mới'), findsOneWidget);
        expect(find.text('Mới'), findsOneWidget);
        expect(find.text('1 chưa đọc'), findsOneWidget);
        expect(find.textContaining('Từ pdt01'), findsNWidgets(2));
        expect(find.text('+ Gửi theo vai trò'), findsNothing);
        expect(find.text('Đã gửi'), findsNothing);

        await tapText(t, 'Điểm mới');
        expect(
          api.log.any((l) => l.startsWith('PATCH /notifications/1/read/')),
          isTrue,
        );
        expect(find.text('Mới'), findsNothing);
        expect(find.text('0 chưa đọc'), findsOneWidget);
      },
    );

    testWidgets(
      'Chưa đọc gửi da_doc=false; Đánh dấu tất cả đã đọc gọi read-all',
      (t) async {
        final api = svApi2({
          'GET /notifications/': (_) =>
              reply(200, inbox([tb(1, 'A'), tb(2, 'B')])),
          'POST /notifications/read-all/': (_) =>
              reply(200, {'da_danh_dau': 2}),
        });
        await openStudent(t, api, '/student/notifications');
        await tapText(t, 'Chưa đọc');
        expect(api.queries['GET /notifications/']!['da_doc'], 'false');
        await tapText(t, 'Đánh dấu tất cả đã đọc');
        expect(
          api.log.any((l) => l.startsWith('POST /notifications/read-all/')),
          isTrue,
        );
        expect(find.text('Đã đánh dấu tất cả đã đọc.'), findsOneWidget);
      },
    );

    testWidgets('trống: thông báo thay vì danh sách rỗng', (t) async {
      await openStudent(t, svApi2({}), '/student/notifications');
      expect(find.text('Chưa có thông báo nào.'), findsOneWidget);
    });

    testWidgets('chuông hiện số chưa đọc (9+ khi nhiều)', (t) async {
      final api = svApi2({
        'GET /notifications/': (_) =>
            reply(200, inbox([tb(1, 'A')], chuaDoc: 12)),
      });
      await openStudent(t, api, '/student/notifications');
      expect(find.text('9+'), findsOneWidget);
    });
  });

  group('Gửi và thu hồi', () {
    FakeAdapter pdt(Map<String, Handler> extra) => pdtApi({
      'GET /notifications/': (o) => reply(
        200,
        o.queryParameters['gui'] == 'true'
            ? inbox([
                tb(7, 'Họp lớp', tuToi: true, aud: 'ROLE', refs: ['SINH_VIEN']),
              ], chuaDoc: 0)
            : inbox([]),
      ),
      ...extra,
    });

    testWidgets('PĐT gửi theo vai trò: body đúng; thiếu tiêu đề báo lỗi', (
      t,
    ) async {
      final api = pdt({'POST /notifications/': (_) => reply(201, tb(9, 'X'))});
      await openPdt(t, api, '/pdt/notifications');
      await tapText(t, '+ Gửi theo vai trò');
      await enterField(t, 'Nội dung', 'Nghỉ lễ 2/9');
      await tapText(t, 'Gửi thông báo');
      expect(find.text('Bắt buộc nhập.'), findsOneWidget);

      await enterField(t, 'Tiêu đề', 'Lịch nghỉ');
      await tapText(t, 'Gửi thông báo');
      expect(api.bodies['POST /notifications/'], {
        'tieu_de': 'Lịch nghỉ',
        'noi_dung': 'Nghỉ lễ 2/9',
        'audience': 'ROLE',
        'target_refs': ['SINH_VIEN'],
      });
      expect(find.text('Đã gửi thông báo.'), findsOneWidget);
    });

    testWidgets('PĐT gửi cho lớp và cho một người (chọn từ gợi ý)', (t) async {
      final api = pdt({
        'GET /class-sections/': (_) => reply(
          200,
          pageOf([
            {'id': 3, 'ma_lop': 'CNTT101-01', 'ten_mon': 'Nhập môn'},
          ]),
        ),
        'GET /notifications/recipients/': (_) => reply(
          200,
          pageOf([
            {
              'id': 21,
              'username': 'sv01',
              'full_name': 'Trần Hoàng Nam',
              'role': 'SINH_VIEN',
            },
          ]),
        ),
        'POST /notifications/': (_) => reply(201, tb(9, 'X')),
      });
      await openPdt(t, api, '/pdt/notifications');

      await tapText(t, '+ Gửi cho lớp');
      await enterField(t, 'Lớp học phần', 'CNTT');
      await t.pumpAndSettle();
      await t.tap(find.text('CNTT101-01 · Nhập môn').last);
      await t.pumpAndSettle();
      await enterField(t, 'Tiêu đề', 'Nghỉ học');
      await enterField(t, 'Nội dung', 'Thứ 5 nghỉ');
      await tapText(t, 'Gửi thông báo');
      expect(api.bodies['POST /notifications/'], {
        'tieu_de': 'Nghỉ học',
        'noi_dung': 'Thứ 5 nghỉ',
        'audience': 'CLASS',
        'target_refs': [3],
      });

      await tapText(t, '+ Gửi cho một người');
      await enterField(t, 'Người nhận', 'Nam');
      await t.pumpAndSettle();
      await t.tap(find.text('Trần Hoàng Nam (sv01)').last);
      await t.pumpAndSettle();
      await enterField(t, 'Tiêu đề', 'Nhắc nhở');
      await enterField(t, 'Nội dung', 'Nộp hồ sơ');
      await tapText(t, 'Gửi thông báo');
      expect((api.bodies['POST /notifications/'] as Map)['target_refs'], [21]);
      expect((api.bodies['POST /notifications/'] as Map)['audience'], 'USER');
    });

    testWidgets('tab Đã gửi: thu hồi có xác nhận → DELETE', (t) async {
      final api = pdt({'DELETE /notifications/7/': (_) => reply(204, {})});
      await openPdt(t, api, '/pdt/notifications');
      await tapText(t, 'Đã gửi');
      expect(find.text('Họp lớp'), findsOneWidget);
      expect(
        find.text('Tới Vai trò: Sinh viên · 12/01/2027 08:00'),
        findsOneWidget,
      );
      await tapText(t, 'Thu hồi');
      await tapText(t, 'Thu hồi', index: 1);
      expect(
        api.log.any((l) => l.startsWith('DELETE /notifications/7/')),
        isTrue,
      );
      expect(find.text('Đã thu hồi thông báo.'), findsOneWidget);
    });

    testWidgets(
      'giáo viên chỉ có nút gửi cho lớp (không vai trò / người); Admin không gửi lớp',
      (t) async {
        final gv = FakeAdapter({
          'GET /profiles/me/': (_) => reply(
            200,
            userJson('GIAO_VIEN', name: 'Trần Minh Quân', username: 'gv001'),
          ),
          'GET /notifications/': (_) => reply(200, inbox([])),
        });
        await pumpApp(
          t,
          router: webRouterProvider,
          adapter: gv,
          tokens: signedIn,
          size: bigScreen,
        );
        GoRouter.of(t.element(find.byType(Scaffold).first))
            .go('/teacher/notifications');
        await t.pumpAndSettle();
        expect(find.text('+ Gửi cho lớp'), findsOneWidget);
        expect(find.text('+ Gửi theo vai trò'), findsNothing);
        expect(find.text('+ Gửi cho một người'), findsNothing);
      },
    );
  });

  group('Nhật ký thao tác', () {
    Map<String, dynamic> log(
      int id,
      String hd,
      String dt,
      Map<String, dynamic> ct,
    ) => {
      'id': id,
      'nguoi_thuc_hien': 'pdt01',
      'hanh_dong': hd,
      'doi_tuong': dt,
      'doi_tuong_id': '5',
      'chi_tiet': ct,
      'thoi_gian': '2027-01-12T09:30:00+07:00',
      'ip': '10.0.0.1',
      'scope': 'training',
    };

    Map<String, dynamic> nk(
      String hd,
      String dt,
      Map<String, dynamic> ct, {
      String id = '5',
    }) => {
      'hanh_dong': hd,
      'doi_tuong': dt,
      'doi_tuong_id': id,
      'chi_tiet': ct,
    };

    test(
      'tomTat: mô tả bằng tiếng Việt tự nhiên, không lộ tên trường kỹ thuật',
      () {
        final ca = <(Map<String, dynamic>, String)>[
          // thao tác chung trên danh mục
          (
            nk('CREATE', 'Course', {
              'serialized': {'ma_mon': 'IT1', 'ten_mon': 'Lập trình'},
            }),
            'Tạo môn học “Lập trình”',
          ),
          (
            nk('UPDATE', 'ClassSection', {
              'serialized': {'ma_lop': 'IT1-01'},
            }),
            'Cập nhật lớp học phần “IT1-01”',
          ),
          (
            nk('DELETE', 'Semester', {
              'serialized': {'ten_hk': 'HK1'},
            }),
            'Xóa học kỳ “HK1”',
          ),
          (
            nk('UPDATE', 'Semester', {'trang_thai': 'DONG'}),
            'Chuyển học kỳ sang trạng thái “đóng”',
          ),
          (
            nk('UPDATE', 'ClassSection', {'trang_thai': 'DANG_HOC'}),
            'Chuyển lớp học phần sang trạng thái “đang học”',
          ),
          (
            nk('UPDATE', 'ClassSection', {
              'hanh_dong': 'gia_han_nhap_diem',
              'tu': '2027-01-10',
              'den': '2027-02-01',
            }),
            'Gia hạn nhập điểm từ 10/01/2027 đến 01/02/2027',
          ),
          // tài khoản
          (nk('LOGIN', 'User', {}), 'Đăng nhập hệ thống'),
          (
            nk('PHAN_QUYEN', 'User', {
              'role': ['SINH_VIEN', 'GIAO_VIEN'],
            }),
            'Đổi vai trò từ Sinh viên sang Giáo viên',
          ),
          (nk('UPDATE', 'User', {'is_locked': true}), 'Khóa tài khoản'),
          (nk('UPDATE', 'User', {'is_locked': false}), 'Mở khóa tài khoản'),
          (
            nk('UPDATE', 'User', {'hanh_dong': 'reset_password'}),
            'Đặt lại mật khẩu tài khoản',
          ),
          // đăng ký
          (
            nk('CREATE', 'Registration', {'lop_hoc_phan': 3, 'sinh_vien': 9}),
            'Đăng ký lớp học phần',
          ),
          (
            nk('UPDATE', 'Registration', {
              'hanh_dong': 'huy_dang_ky',
              'boi': 'PHONG_DAO_TAO',
              'ly_do': 'Nghỉ',
            }),
            'Phòng đào tạo hủy đăng ký — lý do: Nghỉ',
          ),
          (
            nk('UPDATE', 'Registration', {
              'hanh_dong': 'huy_dang_ky',
              'boi': 'SINH_VIEN',
              'ly_do': '',
            }),
            'Sinh viên hủy đăng ký',
          ),
          // điểm danh, điểm
          (
            nk('UPDATE', 'AttendanceSession', {
              'hanh_dong': 'luu_diem_danh',
              'so_dong': 40,
            }),
            'Lưu điểm danh 40 sinh viên',
          ),
          (
            nk('CREATE', 'AttendanceRequest', {
              'attendance': 1,
              'mong_muon': 'VANG_CO_PHEP',
            }),
            'Gửi yêu cầu sửa điểm danh thành “Vắng có phép”',
          ),
          (
            nk('UPDATE', 'AttendanceRequest', {
              'quyet_dinh': 'DA_DUYET',
              'attendance': 1,
            }),
            'Duyệt yêu cầu sửa điểm danh',
          ),
          (
            nk('UPDATE', 'AttendanceRequest', {
              'quyet_dinh': 'TU_CHOI',
              'attendance': 1,
            }),
            'Từ chối yêu cầu sửa điểm danh',
          ),
          (
            nk('UPDATE', 'Grade', {
              'hanh_dong': 'nhap_diem',
              'lop_hoc_phan': 1,
              'so_dong': 30,
            }),
            'Lưu nháp điểm 30 sinh viên',
          ),
          (
            nk('UPDATE', 'Grade', {
              'hanh_dong': 'nhap_ho',
              'lop_hoc_phan': 1,
              'so_dong': 30,
            }),
            'Nhập hộ điểm 30 sinh viên',
          ),
          (
            nk('UPDATE', 'Grade', {'hanh_dong': 'khoa_diem', 'so_dong': 30}),
            'Khóa điểm 30 sinh viên',
          ),
          (
            nk('UPDATE', 'Grade', {'hanh_dong': 'mo_khoa_diem', 'so_dong': 30}),
            'Mở khóa điểm 30 sinh viên',
          ),
          (
            nk('UPDATE', 'Grade', {
              'hanh_dong': 'duyet_diem',
              'so_sinh_vien': 12,
            }),
            'Duyệt điểm 12 sinh viên',
          ),
          // thông báo, hệ thống
          (
            nk('CREATE', 'Notification', {
              'audience': 'CLASS',
              'target_refs': [1],
              'tieu_de': 'Nghỉ học',
            }),
            'Gửi thông báo “Nghỉ học” tới lớp học phần',
          ),
          (
            nk('CREATE', 'Notification', {
              'audience': 'ROLE',
              'target_refs': ['SINH_VIEN'],
              'tieu_de': 'Họp',
            }),
            'Gửi thông báo “Họp” tới vai trò',
          ),
          (
            nk('UPDATE', 'Notification', {'hanh_dong': 'thu_hoi'}),
            'Thu hồi thông báo',
          ),
          (
            nk('CREATE', 'Backup', {'hanh_dong': 'tao_backup'}, id: ''),
            'Tạo bản sao lưu dữ liệu',
          ),
          (
            nk('UPDATE', 'SystemConfig', {
              'tu': '20',
              'den': '25',
            }, id: 'max_absent_pct'),
            'Đổi “Ngưỡng vắng tối đa (%)” từ 20 sang 25',
          ),
          // học phí
          (
            nk('CREATE', 'HocPhanGia', {
              'serialized': {
                'pham_vi': 'NGANH',
                'tham_chieu': 'CNTT',
                'don_gia': '120000.00',
              },
            }),
            'Tạo bảng giá ngành CNTT: 120.000 ₫/tín chỉ',
          ),
          (
            nk('CREATE', 'Discount', {
              'serialized': {
                'loai': 'HOC_BONG',
                'ty_le': '25.00',
                'so_tien': null,
              },
            }),
            'Tạo học bổng 25%',
          ),
          (
            nk('UPDATE', 'Discount', {
              'serialized': {
                'loai': 'MIEN_GIAM',
                'so_tien': '500000.00',
                'ty_le': null,
              },
            }),
            'Cập nhật miễn giảm 500.000 ₫',
          ),
          (
            nk('UPDATE', 'TuitionConfig', {
              'serialized': {'han_dong': '2027-02-01'},
            }),
            'Cập nhật hạn đóng học phí 01/02/2027',
          ),
          (
            nk('UPDATE', 'TuitionInstallment', {
              'dots': [
                {'thu_tu': 1, 'ty_le': '40.00', 'han_dong': '2026-11-15'},
                {'thu_tu': 2, 'ty_le': '30.00', 'han_dong': '2026-12-15'},
                {'thu_tu': 3, 'ty_le': '30.00', 'han_dong': '2027-01-15'},
              ],
            }, id: 'hk1'),
            'Cấu hình 3 đợt đóng học phí: 40% hạn 15/11/2026 · 30% hạn 15/12/2026 · 30% hạn 15/01/2027',
          ),
          (
            nk('UPDATE', 'Tuition', {
              'hanh_dong': 'tinh_hang_loat',
              'so_sv': 12,
            }, id: 'hk1'),
            'Tính lại học phí cho 12 sinh viên',
          ),
          (
            nk('UPDATE', 'Tuition', {
              'hanh_dong': 'doi_hinh_thuc',
              'hinh_thuc': 'CHIA_DOT',
            }),
            'Đổi hình thức đóng học phí sang chia 3 đợt',
          ),
          (
            nk('UPDATE', 'Tuition', {
              'hanh_dong': 'doi_hinh_thuc',
              'hinh_thuc': 'MOT_LAN',
            }),
            'Đổi hình thức đóng học phí sang đóng một lần',
          ),
          (
            nk('CREATE', 'Payment', {
              'tuition': 7,
              'loai': 'THU',
              'so_tien': '6770000.00',
            }),
            'Thu 6.770.000 ₫',
          ),
          (
            nk('CREATE', 'Payment', {
              'tuition': 7,
              'loai': 'HOAN',
              'so_tien': '500000.00',
            }),
            'Hoàn 500.000 ₫',
          ),
          (
            nk('CREATE', 'OnlineTransaction', {
              'tuition': 7,
              'so_tien': '6770000.00',
            }),
            'Tạo giao dịch VNPay 6.770.000 ₫',
          ),
          (
            nk('UPDATE', 'OnlineTransaction', {
              'trang_thai': 'THANH_CONG',
              'so_tien': '6770000.00',
              'payment': 2080,
            }),
            'VNPay: thanh toán thành công 6.770.000 ₫',
          ),
          (
            nk('UPDATE', 'OnlineTransaction', {
              'trang_thai': 'THAT_BAI',
              'so_tien': '6770000.00',
              'payment': null,
            }),
            'VNPay: thanh toán không thành công',
          ),
          (
            nk('UPDATE', 'OnlineTransaction', {
              'trang_thai': 'LOI',
              'so_tien': '6770000.00',
              'payment': null,
            }),
            'VNPay: đã nhận 6.770.000 ₫ nhưng chưa ghi được học phí — cần kế toán xử lý',
          ),
        ];
        for (final (log, mong) in ca) {
          expect(
            tomTat(log),
            mong,
            reason: '${log['doi_tuong']} ${log['chi_tiet']}',
          );
        }
      },
    );

    test('tomTat: không lộ cặp khóa=giá trị; thiếu đối tượng thì —', () {
      expect(tomTat({'chi_tiet': {}}), '—');
      final la = tomTat(nk('UPDATE', 'Lạ', {'khoa_la': 'x', 'khac': 1}));
      expect(la, 'Cập nhật Lạ');
      expect(la.contains('='), isFalse);
      expect(tomTat(nk('DELETE', 'Course', {})), 'Xóa môn học');
    });

    testWidgets(
      'PĐT: bảng, lọc hành động gửi query, bấm dòng xem chi tiết bằng tiếng Việt; không có lọc phạm vi',
      (t) async {
        final api = pdtApi({
          'GET /admin/audit-logs/': (_) => reply(
            200,
            pageOf([
              log(1, 'CREATE', 'Course', {
                'serialized': {'ma_mon': 'IT1'},
              }),
              log(2, 'UPDATE', 'Registration', {
                'hanh_dong': 'huy_dang_ky',
                'ly_do': 'Nghỉ học',
              }),
            ]),
          ),
        });
        await openPdt(t, api, '/pdt/logs');
        expect(find.text('Môn học #5'), findsOneWidget);
        expect(find.text('Đăng ký #5'), findsOneWidget);
        expect(find.text('Tạo mới'), findsWidgets);
        expect(find.text('Phạm vi'), findsNothing);

        await tapText(t, 'Tất cả');
        await t.tap(find.text('Xóa').last);
        await t.pumpAndSettle();
        expect(api.queries['GET /admin/audit-logs/']!['hanh_dong'], 'DELETE');

        await tapText(t, 'Đăng ký #5');
        expect(find.text('Chi tiết thao tác #2'), findsOneWidget);
        // Chi tiết là câu tiếng Việt (có ở cả cột Tóm tắt và hộp thoại), không phải JSON thô.
        expect(find.textContaining('lý do: Nghỉ học'), findsWidgets);
        expect(find.textContaining('"ly_do"'), findsNothing);
        expect(find.textContaining('huy_dang_ky'), findsNothing);
        expect(find.textContaining('IP 10.0.0.1'), findsOneWidget);
      },
    );

    testWidgets('Admin có lọc phạm vi; KT cũng xem được nhật ký tài chính', (
      t,
    ) async {
      final admin = FakeAdapter({
        'GET /profiles/me/': (_) =>
            reply(200, userJson('ADMIN', name: 'Quản trị', username: 'admin')),
        'GET /admin/audit-logs/': (_) => reply(
          200,
          pageOf([
            log(1, 'CREATE', 'Payment', {'so_tien': '1000'}),
          ]),
        ),
      });
      await pumpApp(
        t,
        router: webRouterProvider,
        adapter: admin,
        tokens: signedIn,
        size: bigScreen,
      );
      GoRouter.of(t.element(find.byType(Scaffold).first)).go('/admin/logs');
      await t.pumpAndSettle();
      expect(find.text('Phạm vi'), findsOneWidget);
      expect(find.text('Thanh toán #5'), findsOneWidget);
    });
  });
}
