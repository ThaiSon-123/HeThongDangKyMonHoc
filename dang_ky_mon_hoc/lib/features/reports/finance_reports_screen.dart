import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/status_chip.dart';
import '../tuition/money.dart';
import '../tuition/tuition_ledger_screens.dart' show hienThiChip;
import '../training/classes_screen.dart' show hocKyLabel;
import '../training/curriculums_screen.dart' show nganhLabel;
import '../training/entity_form.dart' show ApiSelect;
import '../training/resource_list.dart';
import '../training/training_api.dart';
import '../training/training_widgets.dart';
import 'report_widgets.dart';

const _path = '/reports/finance/';
const _filterKeys = ['hoc_ky', 'nganh', 'lop_hoc_phan', 'sinh_vien'];

String _svLabel(Json s) => '${s.str('ho_ten')} (${s.str('ma_sv')})';

/// Báo cáo tài chính (KT-11) — mockup `KT-Web-BaoCao`: bốn thẻ tổng, biểu đồ theo ngành, bảng từng sinh viên.
/// Thẻ + biểu đồ lấy từ `reports/finance`, bảng lấy từ `tuition/` với cùng bộ lọc nên hai phần luôn khớp.
class FinanceReportsScreen extends ConsumerStatefulWidget {
  const FinanceReportsScreen({super.key});

  @override
  ConsumerState<FinanceReportsScreen> createState() =>
      _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends ConsumerState<FinanceReportsScreen> {
  final _ctl = ResourceListController();
  Json? _hocKy;
  late Future<Json> _summary = _fetch();
  String _signature = '';

  Map<String, Object?> get _query => {
    for (final k in _filterKeys) k: _ctl.filters[k],
  };

  Future<Json> _fetch() =>
      ref.read(trainingApiProvider).get(_path, query: _query);

  @override
  void initState() {
    super.initState();
    _signature = _query.toString();
    _ctl.addListener(_onFilters);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  /// Đổi trang / tải lại bảng không cần tính lại tổng — chỉ làm mới khi bộ lọc đổi.
  void _onFilters() {
    final sig = _query.toString();
    if (sig == _signature) return;
    _signature = sig;
    final next = _fetch();
    setState(() {
      _summary = next;
    });
  }

  void _retry() {
    final next = _fetch();
    setState(() {
      _summary = next;
    });
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListToolbar(
          children: [
            SizedBox(
              width: 220,
              child: ApiSelect(
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
            SizedBox(
              width: 240,
              child: ApiSelect(
                label: 'Sinh viên',
                path: '/tuition/students/',
                labelOf: _svLabel,
                hint: 'Tất cả sinh viên',
                onChanged: (o) => _ctl.setFilter('sinh_vien', o?.id),
              ),
            ),
            SizedBox(
              width: 140,
              child: AppButton(
                label: 'Xuất Excel',
                height: 44,
                outlined: true,
                onPressed: () => exportXlsx(
                  context,
                  ref,
                  path: '${_path}export/',
                  query: _query,
                  fileName: 'bao_cao_tai_chinh.xlsx',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder<Json>(
          future: _summary,
          builder: (context, snap) {
            if (snap.hasError) return ListErrorCard(onRetry: _retry);
            if (!snap.hasData) return const ListSkeleton();
            return _Summary(data: snap.data!);
          },
        ),
        const SizedBox(height: 24),
        const Text('Chi tiết theo sinh viên', style: sectionTitleStyle),
        const SizedBox(height: 12),
        ResourceList(
          controller: _ctl,
          path: '/tuition/',
          minWidth: 1050,
          emptyText: 'Không có học phí nào phù hợp với bộ lọc.',
          columns: const [
            ListColumn('Mã SV', width: 110),
            ListColumn('Họ tên', flex: 2),
            ListColumn('Ngành', width: 80),
            ListColumn('Phải nộp', width: 130),
            ListColumn('Đã thu', width: 130),
            ListColumn('Còn nợ', width: 130),
            ListColumn('Cần hoàn', width: 120),
            ListColumn('Trạng thái', width: 150),
          ],
          cells: (r) {
            final conNo = vnd(r, 'con_no'), canHoan = vnd(r, 'can_hoan');
            final chuaTinh = r.str('hien_thi') == 'CHUA_TINH';
            return [
              Text(r.str('ma_sv'), style: monoStyle),
              Text(r.str('ho_ten'), overflow: TextOverflow.ellipsis),
              Text(r.str('nganh_ma')),
              Text(chuaTinh ? '—' : formatVnd(r['phai_nop'])),
              Text(formatVnd(r['thuc_thu'])),
              Text(
                chuaTinh ? '—' : formatVnd(r['con_no']),
                style: TextStyle(color: conNo > 0 ? AppColors.danger : null),
              ),
              Text(canHoan > 0 ? formatVnd(r['can_hoan']) : '—'),
              Wrap(
                spacing: 6,
                children: [
                  hienThiChip(r.str('hien_thi')),
                  if (r['qua_han'] == true)
                    StatusChip.of('Quá hạn', StatusChip.red),
                ],
              ),
            ];
          },
        ),
      ],
    ),
  );
}

class _Summary extends StatelessWidget {
  const _Summary({required this.data});

  final Json data;

  @override
  Widget build(BuildContext context) {
    final tong = Json.from(data['tong'] as Map);
    final nganh = [
      for (final n in data['theo_nganh'] as List) Json.from(n as Map),
    ];
    final max = nganh.fold<double>(1, (a, n) {
      final v = vnd(n, 'phai_thu') > vnd(n, 'da_thu')
          ? vnd(n, 'phai_thu')
          : vnd(n, 'da_thu');
      return v > a ? v : a;
    });
    const phaiThuColor = Color(0xFFC5CAE9);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            StatCard(
              width: 260,
              label: 'Phải thu',
              value: formatVnd(tong['phai_thu']),
              accent: AppColors.navy,
            ),
            StatCard(
              width: 260,
              label: 'Đã thu',
              value: formatVnd(tong['da_thu']),
              accent: AppColors.primary,
              valueColor: AppColors.primary,
            ),
            StatCard(
              width: 260,
              label: 'Còn nợ',
              value: formatVnd(tong['con_no']),
              accent: AppColors.danger,
              valueColor: AppColors.danger,
            ),
            StatCard(
              width: 260,
              label: 'Chờ hoàn tiền',
              value: formatVnd(tong['cho_hoan']),
              accent: AppColors.warning,
              valueColor: const Color(0xFFB26A00),
            ),
          ],
        ),
        const SizedBox(height: 24),
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Theo ngành', style: sectionTitleStyle),
                  ),
                  _legend('Phải thu', phaiThuColor),
                  const SizedBox(width: 16),
                  _legend('Đã thu', AppColors.primary),
                ],
              ),
              const SizedBox(height: 12),
              if (nganh.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Chưa có học phí nào trong phạm vi này.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                ),
              for (final n in nganh) ...[
                BarRow(
                  label: n.str('nganh_ma'),
                  fraction: vnd(n, 'phai_thu') / max,
                  valueText: formatVnd(n['phai_thu']),
                  color: phaiThuColor,
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
      ],
    );
  }

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ],
  );
}
