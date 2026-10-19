import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_failure.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../registration/timetable_screen.dart' show clockProvider;
import '../reports/report_widgets.dart' show BarRow, LuoiStat, StatCard;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart' show PanelCard, sectionTitleStyle;
import '../tuition/money.dart';
import 'dashboard_widgets.dart';

/// Tổng quan Kế toán — mockup `KT-Web-TongQuan`: 4 thẻ tiền, các nhắc việc (quá hạn · chờ hoàn ·
/// chưa tính), biểu đồ phải thu / đã thu theo ngành. Dữ liệu từ `reports/finance`.
class AccountantDashboard extends ConsumerStatefulWidget {
  const AccountantDashboard({super.key});

  @override
  ConsumerState<AccountantDashboard> createState() =>
      _AccountantDashboardState();
}

class _AccountantDashboardState extends ConsumerState<AccountantDashboard> {
  late Future<Json> _data = _fetch();

  Future<Json> _fetch() =>
      ref.read(trainingApiProvider).get('/reports/finance/');

  void _taiLai() {
    final next = _fetch();
    setState(() {
      _data = next;
    });
  }

  Widget _nhac(BannerKind kind, String text, String nhan, String duong) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: AlertBanner(kind: kind, message: text),
            ),
            SizedBox(
              width: 150,
              child: AppButton(
                label: nhan,
                height: 40,
                outlined: true,
                onPressed: () => context.go(duong),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) {
        final f = snap.error;
        if (f is ApiFailure && f.fields.containsKey('hoc_ky')) {
          return const AlertBanner(
            kind: BannerKind.warning,
            message: 'Chưa có học kỳ nào để lập báo cáo.',
          );
        }
        return ListErrorCard(onRetry: _taiLai);
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final now = ref.read(clockProvider)();
      final t = Json.from(d['tong'] as Map);
      final nganh = [
        for (final n in d['theo_nganh'] as List) Json.from(n as Map),
      ];
      final max = nganh.fold<double>(1, (a, n) {
        final v = vnd(n, 'phai_thu') > vnd(n, 'da_thu')
            ? vnd(n, 'phai_thu')
            : vnd(n, 'da_thu');
        return v > a ? v : a;
      });
      const phaiThu = Color(0xFFC5CAE9);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoiChao(
              ten: tenNguoiDung(ref, 'Phòng kế toán'),
              phu: '${d.str('ten_hk')} · ${ngayDayDu(now)}',
            ),
            const SizedBox(height: 16),
            LuoiStat(
              children: [
                StatCard(
                  label: 'Phải thu',
                  value: formatVnd(t['phai_thu']),
                  note:
                      '${t.num0('so_sinh_vien') - t.num0('so_chua_tinh')} sinh viên đã tính học phí',
                  accent: AppColors.navy,
                  width: 260,
                ),
                StatCard(
                  label: 'Đã thu',
                  value: formatVnd(t['da_thu']),
                  note: 'Sau khi trừ các khoản đã hoàn',
                  accent: AppColors.primary,
                  valueColor: AppColors.primary,
                  width: 260,
                ),
                StatCard(
                  label: 'Còn nợ',
                  value: formatVnd(t['con_no']),
                  note: '${t.num0('so_con_no')} sinh viên còn nợ',
                  accent: AppColors.danger,
                  valueColor: AppColors.danger,
                  width: 260,
                ),
                StatCard(
                  label: 'Chờ hoàn tiền',
                  value: formatVnd(t['cho_hoan']),
                  note: '${t.num0('so_cho_hoan')} sinh viên đóng dư',
                  accent: AppColors.warning,
                  valueColor: const Color(0xFFB26A00),
                  width: 260,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (t.num0('so_qua_han') > 0)
              _nhac(
                BannerKind.error,
                '${t.num0('so_qua_han')} sinh viên quá hạn đóng học phí.',
                'Xem công nợ',
                '/accountant/debts',
              ),
            if (t.num0('so_cho_hoan') > 0)
              _nhac(
                BannerKind.warning,
                '${t.num0('so_cho_hoan')} sinh viên đóng dư, đang chờ hoàn tiền.',
                'Xem danh sách hoàn',
                '/accountant/debts',
              ),
            if (t.num0('so_chua_tinh') > 0)
              _nhac(
                BannerKind.info,
                '${t.num0('so_chua_tinh')} sinh viên chưa được tính học phí.',
                'Tính học phí',
                '/accountant/tuition',
              ),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Phải thu và đã thu theo ngành',
                    style: sectionTitleStyle,
                  ),
                  const SizedBox(height: 12),
                  if (nganh.isEmpty)
                    const Text(
                      'Chưa có học phí nào trong học kỳ này.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  for (final n in nganh) ...[
                    BarRow(
                      label: n.str('nganh_ma'),
                      fraction: vnd(n, 'phai_thu') / max,
                      valueText: formatVnd(n['phai_thu']),
                      color: phaiThu,
                      labelWidth: 70,
                      valueWidth: 120,
                    ),
                    BarRow(
                      label: '',
                      fraction: vnd(n, 'da_thu') / max,
                      valueText: formatVnd(n['da_thu']),
                      color: AppColors.primary,
                      labelWidth: 70,
                      valueWidth: 120,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const LoiTat([
              ('Học phí', '/accountant/tuition'),
              ('Công nợ', '/accountant/debts'),
              ('Cấu hình học phí', '/accountant/config'),
              ('Báo cáo', '/accountant/reports'),
            ]),
          ],
        ),
      );
    },
  );
}
