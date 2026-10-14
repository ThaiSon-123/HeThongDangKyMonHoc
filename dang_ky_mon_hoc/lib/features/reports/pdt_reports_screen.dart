import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../training/classes_screen.dart' show hocKyLabel;
import '../training/courses_screen.dart' show monLabel;
import '../training/curriculums_screen.dart' show nganhLabel;
import '../training/entity_form.dart' show ApiSelect;
import '../training/resource_list.dart';
import '../training/training_api.dart';
import '../training/training_widgets.dart';
import 'report_widgets.dart';

const _path = '/reports/training/';

num _pct(Json lop) => (lop['ty_le_lap_day'] as num?) ?? 0;

String _pctText(num pct) => '${pct.round()}%';

/// Báo cáo đào tạo (PDT-14) — mockup `PDT-Web-BaoCao`: thẻ tổng quan, hai biểu đồ cột, bảng theo lớp.
class PdtReportsScreen extends ConsumerStatefulWidget {
  const PdtReportsScreen({super.key});

  @override
  ConsumerState<PdtReportsScreen> createState() => _PdtReportsScreenState();
}

class _PdtReportsScreenState extends ConsumerState<PdtReportsScreen> {
  Json? _hocKy, _nganh, _mon;
  late Future<Json> _future = _fetch();
  String _sortKey = 'pct';
  bool _asc = false;

  Map<String, Object?> get _query => {
    'hoc_ky': _hocKy?.id,
    'nganh': _nganh?.id,
    'mon_hoc': _mon?.id,
  };

  Future<Json> _fetch() =>
      ref.read(trainingApiProvider).get(_path, query: _query);

  void _reload() {
    final next = _fetch();
    setState(() {
      _future = next;
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
              width: 230,
              child: ApiSelect(
                label: 'Học kỳ',
                path: '/semesters/',
                labelOf: hocKyLabel,
                hint: 'Học kỳ hiện tại',
                onChanged: (o) {
                  _hocKy = o;
                  _reload();
                },
              ),
            ),
            SizedBox(
              width: 230,
              child: ApiSelect(
                label: 'Ngành',
                path: '/majors/',
                labelOf: nganhLabel,
                hint: 'Tất cả ngành',
                onChanged: (o) {
                  _nganh = o;
                  _mon = null;
                  setState(() {}); // đổi ngành → ô Môn học dựng lại
                  _reload();
                },
              ),
            ),
            SizedBox(
              width: 260,
              child: ApiSelect(
                key: ValueKey('mon-${_nganh?.id}'),
                label: 'Môn học',
                path: '/courses/',
                query: {'nganh': _nganh?.id},
                labelOf: monLabel,
                hint: 'Tất cả môn',
                onChanged: (o) {
                  _mon = o;
                  _reload();
                },
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
                  fileName: 'bao_cao_dao_tao.xlsx',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        FutureBuilder<Json>(
          future: _future,
          builder: (context, snap) {
            if (snap.hasError) return ListErrorCard(onRetry: _reload);
            if (!snap.hasData) return const ListSkeleton();
            return _Body(
              data: snap.data!,
              sortKey: _sortKey,
              asc: _asc,
              onSort: (key) => setState(() {
                _asc = key == _sortKey
                    ? !_asc
                    : !const {'si_so', 'pct'}.contains(key);
                _sortKey = key;
              }),
            );
          },
        ),
      ],
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.data,
    required this.sortKey,
    required this.asc,
    required this.onSort,
  });

  final Json data;
  final String sortKey;
  final bool asc;
  final ValueChanged<String> onSort;

  @override
  Widget build(BuildContext context) {
    final tong = Json.from(data['tong'] as Map);
    final theoMon = [
      for (final m in data['theo_mon'] as List) Json.from(m as Map),
    ];
    final theoLop = [
      for (final l in data['theo_lop'] as List) Json.from(l as Map),
    ];
    final maxLuot = theoMon.fold<int>(1, (a, m) {
      final v = m.num0('luot_dang_ky');
      return v > a ? v : a;
    });

    final monChart = PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lượt đăng ký theo môn', style: sectionTitleStyle),
          const SizedBox(height: 12),
          if (theoMon.isEmpty) const _Empty(),
          for (final m in theoMon.take(10))
            BarRow(
              label: '${m.str('ma_mon')} · ${m.str('ten_mon')}',
              fraction: m.num0('luot_dang_ky') / maxLuot,
              valueText: '${m.num0('luot_dang_ky')}',
              color: AppColors.primary,
            ),
        ],
      ),
    );
    final lopChart = PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tỷ lệ lấp đầy theo lớp', style: sectionTitleStyle),
          const SizedBox(height: 12),
          if (theoLop.isEmpty) const _Empty(),
          for (final l in theoLop.take(10))
            BarRow(
              label: l.str('ma_lop'),
              fraction: _pct(l) / 100,
              valueText: _pctText(_pct(l)),
              color: lapDayColor(_pct(l)),
              labelWidth: 110,
            ),
          const SizedBox(height: 8),
          const Text(
            'Xanh < 70% · vàng 70–90% · đỏ > 90%',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            StatCard(
              label: 'Số sinh viên',
              value: '${tong.num0('so_sinh_vien')}',
              note: 'đang đăng ký',
            ),
            StatCard(
              label: 'Số lớp',
              value: '${tong.num0('so_lop')}',
              note: 'đang mở / học / đã đóng',
            ),
            StatCard(
              label: 'Tổng lượt đăng ký',
              value: '${tong.num0('tong_luot_dang_ky')}',
              note: 'đang đăng ký',
            ),
            StatCard(
              label: 'Lớp đầy',
              value: '${tong.num0('lop_day')}',
              note: 'hết chỗ',
            ),
            StatCard(
              label: 'Lớp còn chỗ',
              value: '${tong.num0('lop_con_cho')}',
              note: 'đang nhận thêm',
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) => box.maxWidth >= 900
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: monChart),
                    const SizedBox(width: 24),
                    Expanded(child: lopChart),
                  ],
                )
              : Column(
                  children: [monChart, const SizedBox(height: 24), lopChart],
                ),
        ),
        const SizedBox(height: 24),
        _ClassTable(rows: theoLop, sortKey: sortKey, asc: asc, onSort: onSort),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Text(
      'Không có lớp nào phù hợp với bộ lọc.',
      style: TextStyle(color: AppColors.muted),
    ),
  );
}

/// Bảng chi tiết theo lớp; bấm tiêu đề cột để sắp xếp (dữ liệu đã tải đủ nên sắp ở client).
class _ClassTable extends StatelessWidget {
  const _ClassTable({
    required this.rows,
    required this.sortKey,
    required this.asc,
    required this.onSort,
  });

  final List<Json> rows;
  final String sortKey;
  final bool asc;
  final ValueChanged<String> onSort;

  static const _cols = <(String, String, double?, int)>[
    ('ma_lop', 'Mã lớp', 120, 0),
    ('ten_mon', 'Môn học', null, 2),
    ('giao_vien', 'Giáo viên', null, 2),
    ('si_so', 'Sĩ số', 90, 0),
    ('pct', 'Lấp đầy', 100, 0),
    ('trang_thai', 'Trạng thái', 120, 0),
  ];

  Comparable<Object> _key(Json r) => switch (sortKey) {
    'ma_lop' => r.str('ma_lop'),
    'ten_mon' => r.str('ten_mon'),
    'giao_vien' => r.str('giao_vien_ten'),
    'si_so' => r.num0('si_so_hien_tai'),
    'trang_thai' => r.str('trang_thai'),
    _ => _pct(r),
  };

  @override
  Widget build(BuildContext context) {
    final sorted = [...rows]
      ..sort((a, b) {
        final c = _key(a).compareTo(_key(b));
        return asc ? c : -c;
      });
    return PanelCard(
      padding: 0,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            // Giãn hết thẻ khi đủ rộng; hẹp hơn 900 thì cuộn ngang.
            width: box.maxWidth < 900 ? 900 : box.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
                  child: Text('Chi tiết theo lớp', style: sectionTitleStyle),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: Text(
                    'Bấm tiêu đề cột để sắp xếp.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
                _row([
                  for (final c in _cols)
                    _cell(
                      c,
                      InkWell(
                        onTap: () => onSort(c.$1),
                        child: Text(
                          '${c.$2.toUpperCase()}${c.$1 == sortKey ? (asc ? ' ▲' : ' ▼') : ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                ], header: true),
                if (sorted.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Không có lớp nào phù hợp với bộ lọc.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                for (final r in sorted)
                  _row([
                    _cell(_cols[0], Text(r.str('ma_lop'), style: monoStyle)),
                    _cell(_cols[1], Text(r.str('ten_mon'))),
                    _cell(_cols[2], Text(r.str('giao_vien_ten'))),
                    _cell(
                      _cols[3],
                      Text(
                        '${r.num0('si_so_hien_tai')}/${r.num0('si_so_toi_da')}',
                      ),
                    ),
                    _cell(
                      _cols[4],
                      Text(
                        _pctText(_pct(r)),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    _cell(_cols[5], trangThaiChip(r.str('trang_thai'))),
                  ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell((String, String, double?, int) col, Widget child) =>
      col.$3 != null
      ? SizedBox(width: col.$3, child: child)
      : Expanded(flex: col.$4, child: child);

  Widget _row(List<Widget> cells, {bool header = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    decoration: BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.divider)),
      color: header ? const Color(0xFFF7F8FC) : null,
    ),
    child: Row(
      children: [
        for (final (i, c) in cells.indexed) ...[
          if (i > 0) const SizedBox(width: 12),
          c,
        ],
      ],
    ),
  );
}
