import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/status_chip.dart';
import '../registration/registration_format.dart' show thuText;
import '../registration/timetable_screen.dart' show clockProvider;
import '../reports/report_widgets.dart' show LuoiStat, StatCard;
import '../teacher/teacher_classes_screen.dart' show hanNhapDiemInfo;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart' show PanelCard;
import 'dashboard_widgets.dart';

/// Lớp còn ≤ ngưỡng này ngày tới hạn nhập điểm thì coi là "sắp đến hạn" (design.md 6.0).
const _sapDenHanNgay = 3;

class _Data {
  _Data(this.hoSo, this.lop, this.tkb, this.tuanNay);

  final Json hoSo;
  final List<Json> lop;
  final Json tkb;

  /// Các buổi điểm danh trong tuần này của lớp đang dạy.
  final List<Json> tuanNay;
}

/// Tổng quan giáo viên — mockup `Main` / `App-TongQuan`: cảnh báo hạn nhập điểm, 4 thẻ, lịch dạy hôm
/// nay, danh sách lớp với lối tắt Điểm danh / Nhập điểm (mở sẵn lớp qua `?lop=`).
class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
  late Future<_Data> _data = _fetch();

  Future<_Data> _fetch() async {
    final api = ref.read(trainingApiProvider);
    final now = ref.read(clockProvider)();
    final r = await Future.wait<Object?>([
      api.get('/profiles/me/'),
      api.listAll('/class-sections/my/'),
      hoacNull(() => api.get('/timetable/my/')),
    ]);
    final lop = r[1]! as List<Json>;
    final thu2 = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    final cn = thu2.add(const Duration(days: 6));
    final tuanNay = <Json>[];
    for (final l in lop.where((l) => l.str('trang_thai') == 'DANG_HOC')) {
      final buoi = await hoacNull(
        () => api.list(
          '/attendance/sessions/',
          pageSize: 50,
          query: {'lop_hoc_phan': l.id},
        ),
      );
      for (final b in buoi?.items ?? const <Json>[]) {
        final ngay = DateTime.tryParse(b.str('ngay_hoc'));
        if (ngay != null && !ngay.isBefore(thu2) && !ngay.isAfter(cn)) {
          tuanNay.add(b);
        }
      }
    }
    return _Data(
      r[0]! as Json,
      lop,
      (r[2] as Json?) ?? {'lop_hoc_phan': <dynamic>[]},
      tuanNay,
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
      final dang = [
        for (final l in d.lop)
          if (l.str('trang_thai') == 'DANG_HOC') l,
      ];
      final canXuLy = <(Json, int)>[];
      for (final l in dang) {
        final ngay = soNgayDen(l.str('han_nhap_diem_hieu_luc'), now);
        if (ngay != null && ngay <= _sapDenHanNgay) canXuLy.add((l, ngay));
      }
      final quaHan = canXuLy.where((e) => e.$2 < 0).length;
      final dacChot = d.tuanNay
          .where((b) => b.str('trang_thai') == 'DA_DIEM_DANH')
          .length;
      final hs = d.hoSo;
      final homNay = lichHomNay(d.tkb, now);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoiChao(
              ten: hs.str('ho_ten'),
              phu: '${hs.str('ma_gv')} · ${hs.str('khoa')} · ${ngayDayDu(now)}',
            ),
            if (canXuLy.isNotEmpty) ...[
              const SizedBox(height: 16),
              AlertBanner(
                kind: quaHan > 0 ? BannerKind.error : BannerKind.warning,
                message: [
                  for (final (l, ngay) in canXuLy)
                    ngay < 0
                        ? '${l.str('ma_lop')} · ${l.str('ten_mon')} đã quá hạn nhập điểm ${-ngay} ngày — liên hệ Phòng đào tạo để gia hạn hoặc nhập hộ.'
                        : '${l.str('ma_lop')} · ${l.str('ten_mon')} còn $ngay ngày nhập điểm.',
                ].join('\n'),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => context.go('/teacher/grades'),
                  child: const Text('Nhập điểm ngay ›'),
                ),
              ),
            ],
            const SizedBox(height: 16),
            LuoiStat(
              children: [
                StatCard(
                  label: 'Lớp đang dạy',
                  value: '${dang.length}',
                  note: 'Trạng thái Đang học',
                ),
                StatCard(
                  label: 'Sinh viên đang dạy',
                  value:
                      '${dang.fold<int>(0, (s, l) => s + l.num0('si_so_hien_tai'))}',
                  note: dang.isEmpty
                      ? null
                      : '${dang.map((l) => l.num0('si_so_hien_tai')).join(' + ')} sinh viên',
                ),
                StatCard(
                  label: 'Lớp cần xử lý',
                  value: '${canXuLy.length}',
                  note: canXuLy.isEmpty
                      ? 'Không có lớp nào sắp hết hạn'
                      : '${canXuLy.length - quaHan} sắp đến hạn · $quaHan quá hạn nhập điểm',
                  valueColor: quaHan > 0 ? AppColors.danger : null,
                ),
                StatCard(
                  label: 'Buổi điểm danh tuần này',
                  value: '${d.tuanNay.length}',
                  note:
                      'Đã chốt $dacChot · Còn mở ${d.tuanNay.length - dacChot}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            KhoiTongQuan(
              tieuDe: 'Lịch dạy hôm nay',
              trong: 'Hôm nay bạn không có tiết dạy.',
              lienKet: 'Xem lịch dạy cả tuần',
              duongDan: '/teacher/schedule',
              children: [
                for (final t in homNay)
                  DongTiet(
                    tiet: t,
                    phu: '${t.lop.num0('si_so_hien_tai')} sinh viên',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Lớp của tôi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (d.lop
                      .where((l) => l.str('trang_thai') != 'DA_DONG')
                      .isEmpty)
                    const Text(
                      'Bạn chưa có lớp nào đang dạy.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  for (final l in d.lop.where(
                    (l) => l.str('trang_thai') != 'DA_DONG',
                  ))
                    _theLop(l, now),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _theLop(Json l, DateTime now) {
    final (han, mau) = hanNhapDiemInfo(l.str('han_nhap_diem_hieu_luc'), now);
    final lich = [
      for (final b in (l['lich_hoc'] as List))
        '${thuText((b as Map)['thu'] as int)} T${b['tiet_bat_dau']}-${b['tiet_ket_thuc']}',
    ].join(' · ');
    return Container(
      // Web: thẻ lớp giãn hết bề ngang, nút nằm sát phải (Android giữ nguyên).
      width: kIsWeb ? double.infinity : null,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Builder(
        builder: (context) {
          final thongTin = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    l.str('ten_mon'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  l.str('trang_thai') == 'DANG_HOC'
                      ? StatusChip.of('Đang học', StatusChip.indigo)
                      : StatusChip.of('Đang mở', StatusChip.green),
                ],
              ),
              Text(
                '${l.str('ma_lop')} · ${l.num0('si_so_hien_tai')}/${l.num0('si_so_toi_da')} SV · $lich',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              Text(
                'Hạn nhập điểm: $han',
                style: TextStyle(fontSize: 12, color: mau),
              ),
            ],
          );
          Widget nut(String nhan, String duong, {bool vien = false}) {
            final n = AppButton(
              label: nhan,
              height: 40,
              outlined: vien,
              onPressed: () => context.go('$duong?lop=${l.id}'),
            );
            return isCompact(context)
                ? Expanded(child: n)
                : SizedBox(width: 120, child: n);
          }

          final nuts = [
            nut('Điểm danh', '/teacher/attendance', vien: true),
            const SizedBox(width: 8),
            nut('Nhập điểm', '/teacher/grades'),
          ];
          return isCompact(context)
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    thongTin,
                    const SizedBox(height: 10),
                    Row(children: nuts),
                  ],
                )
              : kIsWeb
              ? Row(
                  children: [
                    Expanded(child: thongTin),
                    const SizedBox(width: 16),
                    Row(mainAxisSize: MainAxisSize.min, children: nuts),
                  ],
                )
              : Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    thongTin,
                    Row(mainAxisSize: MainAxisSize.min, children: nuts),
                  ],
                );
        },
      ),
    );
  }
}
