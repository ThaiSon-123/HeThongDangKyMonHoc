import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/status_chip.dart';
import '../dashboard/dashboard_widgets.dart' show soNgayDen;
import '../registration/registration_format.dart';
import '../registration/timetable_screen.dart'
    show TimetableScreen, clockProvider;
import '../reports/report_widgets.dart' show exportXlsx, lapDayColor;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart';

const _filters = <(String, String)>[
  ('', 'Tất cả'),
  ('DANG_HOC', 'Đang học'),
  ('DA_DONG', 'Đã đóng'),
];

/// Dòng hạn nhập điểm kèm đếm ngược: `23/01/2027 · còn 105 ngày` (vàng khi còn ≤ 3 ngày) hoặc
/// `09/10/2026 · quá hạn 1 ngày` (đỏ). [ymd] là ngày của API (`yyyy-MM-dd`).
(String, Color) hanNhapDiemInfo(String ymd, DateTime now) {
  final conLai = soNgayDen(ymd, now);
  if (conLai == null) return ('—', AppColors.muted);
  final ngay = formatYmd(ymd);
  if (conLai < 0) return ('$ngay · quá hạn ${-conLai} ngày', AppColors.danger);
  if (conLai == 0) return ('$ngay · hết hạn hôm nay', const Color(0xFFB26A00));
  return (
    '$ngay · còn $conLai ngày',
    conLai <= 3 ? const Color(0xFFB26A00) : AppColors.muted,
  );
}

String _lichChip(Json l) =>
    '${thuText(l.num0('thu'))} · T${l.num0('tiet_bat_dau')}–${l.num0('tiet_ket_thuc')}';

String _buoiText(String buoi) => switch (buoi) {
  'SANG' => 'Sáng',
  'CHIEU' => 'Chiều',
  _ => 'Tối',
};

Widget _trangThaiLop(String tt) => switch (tt) {
  'DANG_HOC' => StatusChip.of('Đang học', StatusChip.indigo),
  'MO' => StatusChip.of('Đang mở', StatusChip.green),
  'DA_DONG' => StatusChip.of('Đã đóng', StatusChip.gray),
  _ => StatusChip.of('Kế hoạch', StatusChip.yellow),
};

/// Lớp phụ trách của giáo viên (GV-03/04/05/12) — mockup `Web-Lop` / `App-Lop` / `App-ChiTietLop`:
/// danh sách lớp, chi tiết 4 tab (App: 3 tab, lịch dạy cá nhân ở màn Thời khóa biểu).
class TeacherClassesScreen extends ConsumerStatefulWidget {
  const TeacherClassesScreen({super.key});

  @override
  ConsumerState<TeacherClassesScreen> createState() =>
      _TeacherClassesScreenState();
}

class _TeacherClassesScreenState extends ConsumerState<TeacherClassesScreen> {
  late Future<List<Json>> _classes = _load();
  String _filter = '';
  int? _selected;

  Future<List<Json>> _load() =>
      ref.read(trainingApiProvider).listAll('/class-sections/my/');

  void _retry() {
    final next = _load();
    setState(() {
      _classes = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    future: _classes,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _retry);
      final all = snap.data;
      if (all == null) return const ListSkeleton();
      final shown = [
        for (final c in all)
          if (_filter.isEmpty || c.str('trang_thai') == _filter) c,
      ];
      final compact = isCompact(context);
      final list = _ClassList(
        classes: shown,
        total: all.length,
        filter: _filter,
        selected: compact ? null : _selected,
        onFilter: (f) => setState(() => _filter = f),
        onSelect: (id) => setState(() => _selected = id),
      );
      if (compact) {
        return PopScope(
          canPop: _selected == null,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _selected = null);
          },
          child: _selected == null
              ? SingleChildScrollView(child: list)
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _selected = null),
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Lớp phụ trách'),
                        ),
                      ),
                      _ClassDetail(
                        key: ValueKey(_selected),
                        lopId: _selected!,
                        compact: true,
                      ),
                    ],
                  ),
                ),
        );
      }
      return SingleChildScrollView(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 380, child: list),
            const SizedBox(width: 24),
            Expanded(
              child: _selected == null
                  ? const PanelCard(
                      child: Text(
                        'Chọn một lớp ở danh sách bên trái để xem chi tiết.',
                        style: TextStyle(color: AppColors.muted),
                      ),
                    )
                  : _ClassDetail(
                      key: ValueKey(_selected),
                      lopId: _selected!,
                      compact: false,
                    ),
            ),
          ],
        ),
      );
    },
  );
}

class _ClassList extends ConsumerWidget {
  const _ClassList({
    required this.classes,
    required this.total,
    required this.filter,
    required this.selected,
    required this.onFilter,
    required this.onSelect,
  });

  final List<Json> classes;
  final int total;
  final String filter;
  final int? selected;
  final ValueChanged<String> onFilter;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.read(clockProvider)();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (key, label) in _filters)
              ChoiceChip(
                label: Text(label),
                selected: filter == key,
                showCheckmark: false,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: filter == key ? Colors.white : AppColors.label,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => onFilter(key),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (classes.isEmpty)
          PanelCard(
            child: Text(
              total == 0
                  ? 'Bạn chưa được phân công lớp nào.'
                  : 'Không có lớp nào ở trạng thái này.',
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
        for (final c in classes)
          _ClassCard(
            lop: c,
            now: now,
            selected: c.id == selected,
            onTap: () => onSelect(c.id),
          ),
      ],
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.lop,
    required this.now,
    required this.selected,
    required this.onTap,
  });

  final Json lop;
  final DateTime now;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final si = lop.num0('si_so_hien_tai'), toiDa = lop.num0('si_so_toi_da');
    final pct = toiDa == 0 ? 0 : 100 * si / toiDa;
    final dong = lop.str('trang_thai') == 'DA_DONG';
    final (hanText, hanColor) = hanNhapDiemInfo(
      lop.str('han_nhap_diem_hieu_luc'),
      now,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        lop.str('ten_mon'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                    _trangThaiLop(lop.str('trang_thai')),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${lop.str('ma_lop')} · ${lop.str('ten_hk')}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final l in lop['lich_hoc'] as List)
                      _Pill(_lichChip(Json.from(l as Map))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (pct / 100).clamp(0, 1).toDouble(),
                          minHeight: 6,
                          color: lapDayColor(pct),
                          backgroundColor: AppColors.divider,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$si/$toiDa SV',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  dong
                      ? (lop['diem_da_duyet'] == true
                            ? 'Điểm đã được duyệt'
                            : 'Lớp đã đóng')
                      : 'Hạn nhập điểm $hanText',
                  style: TextStyle(
                    fontSize: 12,
                    color: dong ? AppColors.muted : hanColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F3FA),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 11, color: AppColors.label),
    ),
  );
}

/// Chi tiết một lớp: thông tin · lịch học · danh sách SV (+ Xuất Excel) · lịch dạy cá nhân (chỉ Web).
class _ClassDetail extends ConsumerStatefulWidget {
  const _ClassDetail({super.key, required this.lopId, required this.compact});

  final int lopId;
  final bool compact;

  @override
  ConsumerState<_ClassDetail> createState() => _ClassDetailState();
}

class _ClassDetailState extends ConsumerState<_ClassDetail> {
  late Future<Json> _lop = _fetch();
  Future<Json>? _students;
  int _tab = 0;

  Future<Json> _fetch() =>
      ref.read(trainingApiProvider).get('/class-sections/${widget.lopId}/');

  void _retry() {
    final next = _fetch();
    setState(() {
      _lop = next;
    });
  }

  List<String> get _tabs => [
    'Thông tin',
    'Lịch học',
    widget.compact ? 'Sinh viên' : 'Danh sách SV',
    if (!widget.compact) 'Lịch dạy của tôi',
  ];

  void _openTab(int i) => setState(() {
    _tab = i;
    if (i == 2) {
      _students ??= ref
          .read(trainingApiProvider)
          .get('/class-sections/${widget.lopId}/students/');
    }
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _lop,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _retry);
      final lop = snap.data;
      if (lop == null) return const ListSkeleton();
      return PanelCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(lop),
            const SizedBox(height: 12),
            // Màn hẹp: 3 tab không đủ chỗ thì vuốt ngang thay vì tràn.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: TabsRow(labels: _tabs, index: _tab, onChanged: _openTab),
            ),
            const SizedBox(height: 16),
            switch (_tab) {
              0 => _info(lop),
              1 => _schedule(lop),
              2 => _studentList(lop),
              _ => const SizedBox(height: 640, child: TimetableScreen()),
            },
          ],
        ),
      );
    },
  );

  Widget _header(Json lop) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lop.str('ten_mon'),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        Text(
          '${lop.str('ma_lop')} · ${lop.str('ten_hk')}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      ],
    );
    final buttons = [
      SizedBox(
        width: 130,
        child: AppButton(
          label: 'Điểm danh',
          height: 40,
          outlined: true,
          onPressed: () =>
              context.go('/teacher/attendance?lop=${widget.lopId}'),
        ),
      ),
      SizedBox(
        width: 130,
        child: AppButton(
          label: 'Nhập điểm',
          height: 40,
          onPressed: () => context.go('/teacher/grades?lop=${widget.lopId}'),
        ),
      ),
    ];
    return widget.compact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 12),
              Wrap(spacing: 8, children: buttons),
            ],
          )
        : Row(
            children: [
              Expanded(child: title),
              ...buttons.expand((b) => [b, const SizedBox(width: 8)]),
            ],
          );
  }

  Widget _field(String label, Widget value) => SizedBox(
    width: 250,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 2),
        value,
      ],
    ),
  );

  Widget _info(Json lop) {
    String ngay(String key) => lop.str(key).isEmpty
        ? '${formatYmd(lop.str('${key}_hieu_luc'))} (theo học kỳ)'
        : formatYmd(lop.str(key));
    Widget text(String t, {Color? color}) => Text(
      t,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color ?? AppColors.text,
      ),
    );
    final (hanText, hanColor) = hanNhapDiemInfo(
      lop.str('han_nhap_diem_hieu_luc'),
      ref.read(clockProvider)(),
    );
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      children: [
        _field('Học phần', text(lop.str('ten_mon'))),
        _field(
          'Số tín chỉ',
          text(
            '${lop.num0('tong_tin_chi')} (${lop.num0('tin_chi_ly_thuyet')} LT + ${lop.num0('tin_chi_thuc_hanh')} TH)',
          ),
        ),
        _field('Học kỳ', text(lop.str('ten_hk'))),
        _field(
          'Sĩ số',
          text('${lop.num0('si_so_hien_tai')}/${lop.num0('si_so_toi_da')}'),
        ),
        _field('Ngày bắt đầu', text(ngay('ngay_bat_dau'))),
        _field('Ngày kết thúc', text(ngay('ngay_ket_thuc'))),
        _field('Hạn nhập điểm', text(hanText, color: hanColor)),
        _field(
          'Trạng thái lớp',
          Align(
            alignment: Alignment.centerLeft,
            child: _trangThaiLop(lop.str('trang_thai')),
          ),
        ),
        _field(
          'Tổng số buổi',
          text('${lop.num0('tong_so_buoi')} buổi theo lịch'),
        ),
      ],
    );
  }

  Widget _schedule(Json lop) {
    final lich = [for (final l in lop['lich_hoc'] as List) Json.from(l as Map)];
    if (lich.isEmpty) {
      return const Text(
        'Lớp chưa có lịch học.',
        style: TextStyle(color: AppColors.muted),
      );
    }
    return Column(
      children: [
        for (final l in lich)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    thuText(l.num0('thu')),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Tiết ${l.num0('tiet_bat_dau')}–${l.num0('tiet_ket_thuc')} · ${_buoiText(l.str('buoi'))}',
                  ),
                ),
                Text(l.str('phong'), style: monoStyle),
              ],
            ),
          ),
      ],
    );
  }

  Widget _studentList(Json lop) => FutureBuilder<Json>(
    future: _students,
    builder: (context, snap) {
      if (snap.hasError) {
        return ListErrorCard(
          onRetry: () {
            final next = ref
                .read(trainingApiProvider)
                .get('/class-sections/${widget.lopId}/students/');
            setState(() {
              _students = next;
            });
          },
        );
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final rows = [for (final r in d['records'] as List) Json.from(r as Map)];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${d.num0('si_so')}/${d.num0('si_so_toi_da')} sinh viên đã đăng ký',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              SizedBox(
                width: 140,
                child: AppButton(
                  label: 'Xuất Excel',
                  height: 40,
                  outlined: true,
                  onPressed: () => exportXlsx(
                    context,
                    ref,
                    path: '/class-sections/${widget.lopId}/export/',
                    query: const {},
                    fileName: '${lop.str('ma_lop')}.xlsx',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Text(
              'Chưa có sinh viên nào đăng ký lớp này.',
              style: TextStyle(color: AppColors.muted),
            ),
          for (final (i, r) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  SizedBox(width: 36, child: Text('${i + 1}')),
                  SizedBox(
                    width: 110,
                    child: Text(r.str('ma_sv'), style: monoStyle),
                  ),
                  Expanded(
                    child: Text(
                      r.str('ho_ten'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (!widget.compact)
                    Expanded(child: Text(r.str('nganh_ten'))),
                ],
              ),
            ),
        ],
      );
    },
  );
}
