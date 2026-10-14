import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/page_result.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../registration/timetable_screen.dart' show clockProvider;
import '../reports/report_widgets.dart' show StatCard;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../tuition/money.dart';
import 'dashboard_widgets.dart';

class _Data {
  _Data({
    required this.hoSo,
    required this.tkb,
    this.hocPhi,
    this.diemDanh,
    this.thongBao = const [],
  });

  final Json hoSo;
  final Json tkb;
  final Json? hocPhi;
  final Json? diemDanh;
  final List<Json> thongBao;
}

/// Tổng quan sinh viên (SV-02 tóm tắt) — mockup `SV-Web-TongQuan` / `SV-App-TongQuan`: lời chào, 4 thẻ
/// (tín chỉ · GPA · cảnh báo vắng · học phí), lịch học hôm nay, thông báo mới, lối tắt.
/// Chỉ ghép từ endpoint sẵn có; khối nào lỗi thì bỏ qua chứ không làm trắng cả trang.
class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  late Future<_Data> _data = _fetch();

  Future<_Data> _fetch() async {
    final api = ref.read(trainingApiProvider);
    final r = await Future.wait<Object?>([
      api.get('/profiles/me/'),
      hoacNull(() => api.get('/timetable/my/')),
      hoacNull(() => api.get('/tuition/my/')),
      hoacNull(() => api.get('/attendance/my/')),
      hoacNull(() => api.list('/notifications/', pageSize: 3)),
    ]);
    return _Data(
      hoSo: r[0]! as Json,
      tkb: (r[1] as Json?) ?? {'lop_hoc_phan': <dynamic>[]},
      hocPhi: r[2] as Json?,
      diemDanh: r[3] as Json?,
      thongBao: (r[4] as PageResult<Json>?)?.items ?? const [],
    );
  }

  void _taiLai() {
    final next = _fetch();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_Data>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _taiLai);
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final now = ref.read(clockProvider)();
      final hs = d.hoSo;
      final nganh = hs['nganh'] is Map
          ? (hs['nganh'] as Map)['ten_nganh']
          : hs.str('nganh_ten');
      final lop = [
        for (final l in (d.tkb['lop_hoc_phan'] as List)) Json.from(l as Map),
      ];
      final tinChi = lop.fold<int>(0, (s, l) => s + l.num0('tong_tin_chi'));
      final canhBao = [
        for (final l in (d.diemDanh?['lop_hoc_phan'] as List? ?? const []))
          if ((l as Map)['canh_bao_vang'] == true) Json.from(l),
      ];
      final gpa = hs.str('gpa');
      final conNo = d.hocPhi == null ? 0 : vnd(d.hocPhi!, 'con_no');
      final canHoan = d.hocPhi == null ? 0 : vnd(d.hocPhi!, 'can_hoan');
      final quaHan = d.hocPhi?['qua_han'] == true;
      final homNay = lichHomNay(d.tkb, now);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoiChao(
              ten: hs.str('ho_ten'),
              phu:
                  '${hs.str('ma_sv')} · $nganh · ${hs.str('khoa_nhap_hoc')} · ${ngayDayDu(now)}',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                StatCard(
                  label: 'Tín chỉ đã đăng ký',
                  value: '$tinChi',
                  note: d.tkb.str('ten_hk'),
                  width: 220,
                ),
                StatCard(
                  label: 'GPA tích lũy',
                  value: gpa.isEmpty ? 'Chưa có' : gpa,
                  note:
                      '${hs.num0('tin_chi_tich_luy')} tín chỉ tích lũy${hs.str('xep_loai').isEmpty ? '' : ' · ${hs.str('xep_loai')}'}',
                  width: 220,
                ),
                StatCard(
                  label: 'Cảnh báo vắng',
                  value: canhBao.isEmpty ? 'Không' : '${canhBao.length} môn',
                  note: canhBao.isEmpty
                      ? 'Không có môn nguy cơ cấm thi'
                      : '${canhBao.first.str('ten_mon')} — nguy cơ cấm thi',
                  valueColor: canhBao.isEmpty ? null : AppColors.danger,
                  width: 220,
                ),
                StatCard(
                  label: 'Học phí còn nợ',
                  value: formatVnd(conNo),
                  note: canHoan > 0
                      ? 'Chờ hoàn tiền ${formatVnd(canHoan)}'
                      : d.hocPhi?.str('han_dong') == null ||
                            d.hocPhi!.str('han_dong').isEmpty
                      ? null
                      : '${quaHan ? 'Quá hạn · ' : ''}Hạn đóng ${formatYmd(d.hocPhi!.str('han_dong'))}',
                  valueColor: quaHan && conNo > 0
                      ? AppColors.danger
                      : canHoan > 0
                      ? const Color(0xFFB26A00)
                      : null,
                  width: 220,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, box) {
                final homNayKhoi = KhoiTongQuan(
                  tieuDe: 'Hôm nay học gì',
                  trong: 'Hôm nay bạn không có lớp.',
                  lienKet: 'Xem thời khóa biểu cả tuần',
                  duongDan: '/student/schedule',
                  children: [
                    for (final t in homNay)
                      DongTiet(
                        tiet: t,
                        phu: 'GV ${t.lop.str('giao_vien_ten')}',
                      ),
                  ],
                );
                final thongBaoKhoi = KhoiTongQuan(
                  tieuDe: 'Thông báo mới',
                  trong: 'Chưa có thông báo nào.',
                  lienKet: 'Tất cả',
                  duongDan: '/student/notifications',
                  children: [
                    for (final n in d.thongBao)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.str('tieu_de'),
                              style: TextStyle(
                                fontWeight: n['da_doc'] == true
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${n.str('nguoi_gui_ten')} · ${formatIso(n.str('ngay_gui'))}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                );
                return box.maxWidth >= 900
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: homNayKhoi),
                          const SizedBox(width: 16),
                          Expanded(child: thongBaoKhoi),
                        ],
                      )
                    : Column(
                        children: [
                          homNayKhoi,
                          const SizedBox(height: 16),
                          thongBaoKhoi,
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            const LoiTat([
              ('Đăng ký môn học', '/student/register'),
              ('Xem điểm', '/student/grades'),
              ('Điểm danh', '/student/attendance'),
              ('Học phí', '/student/tuition'),
            ]),
          ],
        ),
      );
    },
  );
}
