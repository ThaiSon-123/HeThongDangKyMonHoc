import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_failure.dart';
import '../../core/download/save_file_provider.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/status_chip.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import '../registration/timetable_screen.dart' show clockProvider;
import '../training/classes_screen.dart' show hocKyLabel;
import '../training/curriculums_screen.dart' show nganhLabel;
import '../training/entity_form.dart' show ApiSelect;
import '../training/resource_list.dart';
import '../training/training_api.dart';
import '../training/training_widgets.dart';
import 'money.dart';
import 'payment_form.dart';

const _xlsxMime =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

Widget hienThiChip(String h) => StatusChip.of(hienThiLabel(h), switch (h) {
  'CON_NO' => StatusChip.red,
  'CHO_HOAN_TIEN' => StatusChip.yellow,
  'DA_DONG' => StatusChip.green,
  _ => StatusChip.gray,
});

// =================================================================== Học phí (KT-06..08, KT-10)

/// Học phí (KT-07) — mockup `KT-Web-HocPhi`: danh sách theo học kỳ/ngành/lớp/trạng thái, tính hàng loạt,
/// bấm một dòng để ghi thu / ghi hoàn và tải biên lai.
class AccountantTuitionScreen extends ConsumerStatefulWidget {
  const AccountantTuitionScreen({super.key});

  @override
  ConsumerState<AccountantTuitionScreen> createState() =>
      _AccountantTuitionScreenState();
}

class _AccountantTuitionScreenState
    extends ConsumerState<AccountantTuitionScreen> {
  final _ctl = ResourceListController();
  Json? _hocKy;
  String? _failText;
  bool _calc = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    setState(() {
      _calc = true;
      _failText = null;
    });
    try {
      final id = _hocKy?.id;
      final r = await ref
          .read(trainingApiProvider)
          .create(
            id == null
                ? '/tuition/calculate/'
                : '/tuition/calculate/?hoc_ky=$id',
            {},
          );
      if (mounted) {
        showAppToast(
          context,
          'Đã tính học phí cho ${r.num0('so_sinh_vien')} sinh viên.',
        );
      }
      _ctl.reload();
    } on ApiFailure catch (f) {
      if (mounted) {
        setState(
          () => _failText = f.code == 'CHUA_CAU_HINH_GIA'
              ? 'Chưa cấu hình đủ đơn giá: ${f.message ?? ''}'
              : failureText(f, 'Không tính được học phí.'),
        );
      }
    } finally {
      if (mounted) setState(() => _calc = false);
    }
  }

  Future<void> _open(Json r) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => TuitionDetailDialog(tuitionId: r.id),
    );
    if (changed == true && mounted) _ctl.reload();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListToolbar(
          children: [
            SearchBox(
              controller: _ctl,
              label: 'Tìm sinh viên',
              hint: 'Mã SV hoặc họ tên',
            ),
            SizedBox(
              width: 210,
              child: ApiSelect(
                key: ValueKey('hk-${_hocKy?.id}'),
                label: 'Học kỳ',
                path: '/semesters/',
                labelOf: hocKyLabel,
                hint: 'Học kỳ hiện tại',
                onChanged: (o) {
                  setState(() => _hocKy = o);
                  _ctl
                    ..filters.remove('lop_hoc_phan')
                    ..setFilter('hoc_ky', o?.id);
                },
              ),
            ),
            SizedBox(
              width: 200,
              child: ApiSelect(
                label: 'Ngành',
                path: '/majors/',
                labelOf: nganhLabel,
                hint: 'Tất cả ngành',
                onChanged: (o) => _ctl.setFilter('nganh', o?.id),
              ),
            ),
            SizedBox(
              width: 220,
              child: ApiSelect(
                key: ValueKey('lop-${_hocKy?.id}'),
                label: 'Lớp học phần',
                path: '/class-sections/',
                query: {'hoc_ky': _hocKy?.id},
                labelOf: (l) => l.str('ma_lop'),
                hint: 'Tất cả lớp',
                onChanged: (o) => _ctl.setFilter('lop_hoc_phan', o?.id),
              ),
            ),
            FilterDropdown(
              controller: _ctl,
              filterKey: 'hien_thi',
              label: 'Trạng thái',
              options: const [
                ('', 'Tất cả'),
                ('CHUA_TINH', 'Chưa tính'),
                ('CON_NO', 'Còn nợ'),
                ('CHO_HOAN_TIEN', 'Chờ hoàn tiền'),
                ('DA_DONG', 'Đã đóng đủ'),
              ],
            ),
            SizedBox(
              width: 210,
              child: AppButton(
                label: 'Tính học phí hàng loạt',
                height: 44,
                loading: _calc,
                onPressed: _calculate,
              ),
            ),
          ],
        ),
        if (_failText != null) ...[
          const SizedBox(height: 12),
          AlertBanner(kind: BannerKind.error, message: _failText!),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => context.go('/accountant/config'),
              child: const Text('Mở cấu hình giá →'),
            ),
          ),
        ],
        const SizedBox(height: 24),
        ResourceList(
          controller: _ctl,
          path: '/tuition/',
          minWidth: 1350,
          emptyText: 'Chưa có học phí nào trong học kỳ này. Hãy bấm "Tính học phí hàng loạt".',
          onRowTap: _open,
          columns: const [
            ListColumn('Mã SV', width: 100),
            ListColumn('Họ tên', flex: 2),
            ListColumn('Ngành', flex: 2),
            ListColumn('Tín chỉ', width: 70),
            ListColumn('Tổng tiền', width: 120),
            ListColumn('Miễn giảm', width: 110),
            ListColumn('Phải nộp', width: 120),
            ListColumn('Đã thu', width: 120),
            ListColumn('Còn nợ', width: 120),
            ListColumn('Cần hoàn', width: 110),
            ListColumn('Trạng thái', width: 150),
          ],
          cells: (r) => [
            Text(r.str('ma_sv'), style: monoStyle),
            Text(r.str('ho_ten'), overflow: TextOverflow.ellipsis),
            Text(r.str('nganh_ten'), overflow: TextOverflow.ellipsis),
            Text('${r.num0('tong_tin_chi')}'),
            Text(formatVnd(r['tong_tien'])),
            Text(formatVnd(r['mien_giam'])),
            Text(formatVnd(r['phai_nop'])),
            Text(formatVnd(r['thuc_thu'])),
            Text(
              formatVnd(r['con_no']),
              style: TextStyle(
                color: vnd(r, 'con_no') > 0 ? AppColors.danger : null,
              ),
            ),
            Text(formatVnd(r['can_hoan'])),
            Wrap(
              spacing: 6,
              children: [
                hienThiChip(r.str('hien_thi')),
                if (r['qua_han'] == true)
                  StatusChip.of('Quá hạn', StatusChip.red),
              ],
            ),
          ],
        ),
      ],
    ),
  );
}

/// Chi tiết một học phí: giá trị dẫn xuất, ghi thu/hoàn, giao dịch (kèm biên lai Excel), chi tiết môn.
class TuitionDetailDialog extends ConsumerStatefulWidget {
  const TuitionDetailDialog({super.key, required this.tuitionId});

  final int tuitionId;

  @override
  ConsumerState<TuitionDetailDialog> createState() =>
      _TuitionDetailDialogState();
}

class _TuitionDetailDialogState extends ConsumerState<TuitionDetailDialog> {
  late Future<Json> _future = _fetch();
  bool _changed = false;

  Future<Json> _fetch() =>
      ref.read(trainingApiProvider).get('/tuition/${widget.tuitionId}/');

  void _reload() {
    final next = _fetch();
    setState(() {
      _future = next;
    });
  }

  Future<void> _pay(Json d, {required bool hoan}) async {
    final ok = await showPaymentForm(context, ref, d, hoan: hoan);
    if (ok && mounted) {
      showAppToast(context, hoan ? 'Đã ghi hoàn tiền.' : 'Đã ghi thu học phí.');
      _changed = true;
      _reload();
    }
  }

  Future<void> _receipt(Json p) async {
    try {
      final bytes = await ref
          .read(trainingApiProvider)
          .getBytes('/tuition/payments/${p.id}/receipt/');
      await ref.read(saveFileProvider)(
        '${p.str('bien_lai_ma')}.xlsx',
        bytes,
        mime: _xlsxMime,
      );
    } on ApiFailure catch (f) {
      if (mounted) {
        showAppToast(context, failureText(f, 'Không tải được biên lai.'));
      }
    } on UnsupportedError {
      if (mounted) showAppToast(context, 'Chỉ tải được biên lai trên bản Web.');
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) Navigator.of(context).pop(_changed);
    },
    child: AppDialog(
      title: 'Chi tiết học phí',
      maxWidth: 720,
      actions: [
        DialogButton(
          'Đóng',
          onPressed: () => Navigator.of(context).pop(_changed),
        ),
      ],
      child: FutureBuilder<Json>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return ListErrorCard(onRetry: _reload);
          final d = snap.data;
          if (d == null) return const ListSkeleton();
          return _body(d);
        },
      ),
    ),
  );

  Widget _kv(String k, String v) => SizedBox(
    width: 200,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(k, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );

  Widget _body(Json d) {
    final chuaTinh = d.str('trang_thai') == 'CHUA_TINH';
    final chiTiet = [
      for (final c in d['chi_tiet'] as List) Json.from(c as Map),
    ];
    final gd = [for (final p in d['payments'] as List) Json.from(p as Map)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${d.str('ho_ten')} · ${d.str('ma_sv')}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.navy,
              ),
            ),
            hienThiChip(d.str('hien_thi')),
            if (d['qua_han'] == true) StatusChip.of('Quá hạn', StatusChip.red),
          ],
        ),
        Text(
          '${d.str('nganh_ten')} · ${d.str('ten_hk')}${d['han_dong'] != null ? ' · hạn đóng ${formatYmd(d.str('han_dong'))}' : ''}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            _kv('Tổng tiền', formatVnd(d['tong_tien'])),
            _kv('Miễn giảm', formatVnd(d['mien_giam'])),
            _kv('Phải nộp', formatVnd(d['phai_nop'])),
            _kv('Đã thu', formatVnd(d['thuc_thu'])),
            _kv('Còn nợ', formatVnd(d['con_no'])),
            _kv('Cần hoàn', formatVnd(d['can_hoan'])),
          ],
        ),
        const SizedBox(height: 14),
        if (chuaTinh)
          const Text(
            'Cần tính học phí trước khi ghi thu / hoàn.',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          )
        else
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 150,
                child: AppButton(
                  label: 'Ghi thu',
                  height: 42,
                  onPressed: vnd(d, 'con_no') > 0
                      ? () => _pay(d, hoan: false)
                      : null,
                ),
              ),
              SizedBox(
                width: 150,
                child: AppButton(
                  label: 'Ghi hoàn',
                  height: 42,
                  outlined: true,
                  onPressed: vnd(d, 'can_hoan') > 0
                      ? () => _pay(d, hoan: true)
                      : null,
                ),
              ),
            ],
          ),
        const SizedBox(height: 18),
        const Text('Giao dịch', style: sectionTitleStyle),
        const SizedBox(height: 6),
        if (gd.isEmpty)
          const Text(
            'Chưa có giao dịch nào.',
            style: TextStyle(color: AppColors.muted),
          ),
        for (final p in gd)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: StatusChip.of(
                    p.str('loai') == 'HOAN' ? 'Hoàn' : 'Thu',
                    p.str('loai') == 'HOAN'
                        ? StatusChip.yellow
                        : StatusChip.green,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${formatVnd(p['so_tien'])} · ${formatIso(p.str('ngay'))} · ${phuongThucLabel(p.str('phuong_thuc'))}\n'
                    'Biên lai ${p.str('bien_lai_ma')} · ${p.str('nguoi_thu_ten')}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                OutlinedButton(
                  onPressed: () => _receipt(p),
                  child: const Text('Biên lai Excel'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        const Text('Chi tiết từng môn', style: sectionTitleStyle),
        const SizedBox(height: 6),
        if (chiTiet.isEmpty)
          const Text(
            'Chưa có môn nào (hoặc chưa cấu hình giá).',
            style: TextStyle(color: AppColors.muted),
          ),
        for (final c in chiTiet)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${c.str('ten_mon')} (${c.str('ma_mon')})',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '${c.num0('tin_chi_ly_thuyet')} LT · ${c.num0('tin_chi_thuc_hanh')} TH   ',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                Text(
                  formatVnd(c['thanh_tien']),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// =================================================================== Công nợ (KT-09)

/// Công nợ (KT-09) — mockup `KT-Web-CongNo`: sinh viên còn nợ và đang chờ hoàn tiền.
class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  final _ctl = ResourceListController()..filters['hien_thi'] = 'CON_NO';
  int _tab = 0; // 0 = còn nợ, 1 = chờ hoàn tiền
  bool _quaHan = false;
  Json? _hocKy;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  bool get _hoan => _tab == 1;

  Future<void> _pay(Json r) async {
    final ok = await showPaymentForm(context, ref, r, hoan: _hoan);
    if (ok && mounted) {
      showAppToast(
        context,
        _hoan ? 'Đã ghi hoàn tiền.' : 'Đã ghi thu học phí.',
      );
      _ctl.reload();
    }
  }

  String _tre(Json r) {
    final han = r['han_dong'] == null
        ? null
        : DateTime.tryParse(r.str('han_dong'));
    if (han == null || r['qua_han'] != true) return '—';
    final n = ref.read(clockProvider)();
    return '${DateTime(n.year, n.month, n.day).difference(han).inDays} ngày';
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabsRow(
          labels: const ['Còn nợ', 'Chờ hoàn tiền'],
          index: _tab,
          onChanged: (i) => setState(() {
            _tab = i;
            _ctl.setFilter('hien_thi', i == 0 ? 'CON_NO' : 'CHO_HOAN_TIEN');
          }),
        ),
        const SizedBox(height: 20),
        ListToolbar(
          children: [
            SearchBox(
              controller: _ctl,
              label: 'Tìm sinh viên',
              hint: 'Mã SV hoặc họ tên',
            ),
            SizedBox(
              width: 220,
              child: ApiSelect(
                label: 'Học kỳ',
                path: '/semesters/',
                labelOf: hocKyLabel,
                hint: 'Học kỳ hiện tại',
                selected: _hocKy,
                onChanged: (o) {
                  _hocKy = o;
                  _ctl.setFilter('hoc_ky', o?.id);
                },
              ),
            ),
            if (!_hoan)
              FilterChip(
                label: const Text('Chỉ hiện quá hạn'),
                selected: _quaHan,
                onSelected: (v) {
                  setState(() => _quaHan = v);
                  _ctl.setFilter('qua_han', v ? '1' : null);
                },
              ),
          ],
        ),
        const SizedBox(height: 24),
        ResourceList(
          controller: _ctl,
          path: '/tuition/debts/',
          minWidth: 900,
          emptyText: _hoan
              ? 'Không có sinh viên nào chờ hoàn tiền.'
              : 'Không có sinh viên nào còn nợ.',
          footer: (page) {
            final tong = page.items.fold<double>(
              0,
              (s, r) => s + vnd(r, _hoan ? 'can_hoan' : 'con_no'),
            );
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Tổng (trang này): ${formatVnd(tong)}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            );
          },
          columns: const [
            ListColumn('Sinh viên', flex: 2),
            ListColumn('Học kỳ', flex: 2),
            ListColumn('Số tiền', width: 140),
            ListColumn('Hạn đóng', width: 120),
            ListColumn('Số ngày trễ', width: 170),
            ListColumn('', width: 120),
          ],
          cells: (r) => [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.str('ho_ten'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '${r.str('ma_sv')} · ${r.str('nganh_ten')}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ),
            Text(r.str('ten_hk')),
            Text(
              formatVnd(r[_hoan ? 'can_hoan' : 'con_no']),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(r['han_dong'] == null ? '—' : formatYmd(r.str('han_dong'))),
            r['qua_han'] == true
                ? Text(
                    '${_tre(r)}  Quá hạn',
                    style: const TextStyle(color: AppColors.danger),
                  )
                : const Text('—'),
            RowActions([
              RowButton(_hoan ? 'Ghi hoàn' : 'Ghi thu', () => _pay(r)),
            ]),
          ],
        ),
      ],
    ),
  );
}
