import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/status_chip.dart';
import '../dashboard/dashboard_widgets.dart' show hoacNull;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';

String _d(Object? v, [String empty = '—']) => v == null ? empty : v.toString();

const _nau = Color(0xFFB26A00);
const _nenO = Color(0xFFF4F5FA);

/// Khoảng GPA thang 4 của từng xếp loại (BR-25f) — hiện dưới thẻ Xếp loại.
const _khoangXepLoai = <String, String>{
  'Xuất sắc': '3.60 – 4.00',
  'Giỏi': '3.20 – 3.59',
  'Khá': '2.50 – 3.19',
  'Trung bình': '2.00 – 2.49',
  'Yếu': '1.00 – 1.99',
  'Kém': 'dưới 1.00',
};

/// Điểm của sinh viên (SV-11) — mockup `SV-Web-Diem` / `SV-App-Diem`: chỉ điểm đã được PĐT duyệt,
/// GPA tích lũy, thống kê và bảng điểm từng học kỳ (BR-25g).
class StudentGradesScreen extends ConsumerStatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  ConsumerState<StudentGradesScreen> createState() =>
      _StudentGradesScreenState();
}

class _StudentGradesScreenState extends ConsumerState<StudentGradesScreen> {
  late Future<(Json, int?)> _data = _fetch();
  int? _hk; // null = tất cả học kỳ

  /// Điểm + số tín chỉ CTĐT yêu cầu (từ hồ sơ; thiếu thì chỉ hiện số tích lũy).
  Future<(Json, int?)> _fetch() async {
    final api = ref.read(trainingApiProvider);
    final r = await Future.wait<Json?>([
      api.get('/grades/my/'),
      hoacNull(() => api.get('/profiles/me/')),
    ]);
    final ctdt = r[1]?['ctdt'];
    final yeuCau = ctdt is Map
        ? (ctdt['tong_tin_chi_yeu_cau'] as num?)?.toInt()
        : null;
    return (r[0]!, yeuCau);
  }

  void _reload() {
    final next = _fetch();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<(Json, int?)>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final data = snap.data;
      if (data == null) return const ListSkeleton();
      final (d, yeuCau) = data;
      final stats = [
        for (final s in d['thong_ke'] as List) Json.from(s as Map),
      ];
      final diem = [for (final g in d['diem'] as List) Json.from(g as Map)];
      final shown = stats.reversed
          .where((s) => _hk == null || s.num0('hoc_ky') == _hk)
          .toList();
      final compact = isCompact(context);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (stats.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: compact ? double.infinity : 320,
                  child: LabeledDropdown<int?>(
                    label: 'Học kỳ',
                    value: _hk,
                    options: [
                      (null, 'Tất cả học kỳ'),
                      for (final s in stats.reversed)
                        (s.num0('hoc_ky'), s.str('ten_hk')),
                    ],
                    onChanged: (v) => setState(() => _hk = v),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _tongKet(d, yeuCau, compact),
            const SizedBox(height: 16),
            if (stats.isEmpty)
              const _Card(
                child: Text(
                  'Chưa có điểm chính thức. Điểm hiển thị sau khi Phòng đào tạo duyệt.',
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            for (final s in shown)
              _semester(s, [
                for (final g in diem)
                  if (g.num0('hoc_ky') == s.num0('hoc_ky')) g,
              ], compact),
          ],
        ),
      );
    },
  );

  // ------------------------------------------------------------ 3 thẻ tổng kết
  Widget _tongKet(Json d, int? yeuCau, bool compact) {
    final xep = d['xep_loai'] as String?;
    final cards = [
      _TheTong(
        'GPA tích lũy',
        _d(d['gpa'], 'Chưa có'),
        'Trên toàn bộ môn đã có điểm chính thức',
        mau: AppColors.primary,
      ),
      _TheTong(
        'Tín chỉ tích lũy',
        _d(d['tin_chi_tich_luy']),
        'Chỉ tính môn đã đạt',
        phu: yeuCau == null ? null : ' / $yeuCau',
      ),
      _TheTong(
        'Xếp loại học lực',
        _d(xep, 'Chưa có'),
        xep == null ? '' : 'Thang 4: ${_khoangXepLoai[xep] ?? '—'}',
        mau: xep == null ? AppColors.navy : AppColors.success,
      ),
    ];
    if (compact) {
      return Column(
        children: [
          for (final (i, c) in cards.indexed) ...[
            if (i > 0) const SizedBox(height: 12),
            c,
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in cards.indexed) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: c),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ từng học kỳ
  Widget _semester(Json s, List<Json> rows, bool compact) {
    const cach = SizedBox(width: 12);
    final dat = s.num0('tin_chi_dat');
    final hoc = s.num0('tin_chi_hoc');
    final tiles = [
      _O('Số môn', _d(s['so_mon'] ?? rows.length), compact),
      _O('Tín chỉ đã học', _d(s['tin_chi_hoc']), compact),
      _O(
        'Tín chỉ đạt',
        _d(s['tin_chi_dat']),
        compact,
        mau: dat >= hoc ? AppColors.success : _nau,
      ),
      _O('Điểm TB (hệ 10)', _d(s['diem_tb']), compact, mau: AppColors.primary),
      _O('GPA học kỳ (hệ 4)', _d(s['gpa']), compact, mau: AppColors.primary),
      _O('Xếp loại học kỳ', _d(s['xep_loai']), compact, mau: AppColors.success),
    ];
    Widget hang(List<Widget> ts) => Row(
      children: [
        for (final (i, t) in ts.indexed) ...[if (i > 0) cach, t],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 20,
                16,
                compact ? 16 : 20,
                14,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.str('ten_hk'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (compact) ...[
                    hang(tiles.sublist(0, 3)),
                    const SizedBox(height: 12),
                    hang(tiles.sublist(3)),
                  ] else
                    hang(tiles),
                ],
              ),
            ),
            if (compact)
              for (final g in rows) _theMon(g)
            else
              _bang(rows),
          ],
        ),
      ),
    );
  }

  /// Web: bảng điểm — dải tiêu đề xám, tên môn đậm, chip điểm chữ.
  Widget _bang(List<Json> rows) {
    const dau = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
      letterSpacing: 0.3,
    );
    Widget o(String t, {TextStyle? style, TextAlign? canh}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
      child: Text(t, style: style, textAlign: canh),
    );
    // Cột chia theo tỷ lệ để tên môn không chiếm hết chiều ngang, các cột điểm không bị đẩy ra mép.
    const cot = {
      0: FlexColumnWidth(1.2),
      1: FlexColumnWidth(3),
      2: FlexColumnWidth(0.6),
      3: FlexColumnWidth(0.7),
      4: FlexColumnWidth(0.7),
      5: FlexColumnWidth(0.7),
      6: FlexColumnWidth(1),
      7: FlexColumnWidth(0.8),
      8: FlexColumnWidth(0.7),
    };
    return Table(
      columnWidths: cot,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        horizontalInside: BorderSide(color: AppColors.divider),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(
            color: Color(0xFFF7F8FC),
            border: Border(
              top: BorderSide(color: AppColors.divider),
              bottom: BorderSide(color: AppColors.divider),
            ),
          ),
          children: [
            for (final (i, t) in const [
              'MÃ MÔN',
              'TÊN MÔN',
              'TC',
              'QT',
              'GK',
              'CK',
              'TỔNG KẾT',
              'CHỮ',
              'HỆ 4',
            ].indexed)
              o(
                t,
                style: dau,
                canh: i >= 2 && i <= 8 ? TextAlign.center : null,
              ),
          ],
        ),
        for (final g in rows)
          TableRow(
            children: [
              o(
                g.str('ma_mon'),
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              o(
                g.str('ten_mon'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              o(_d(g['tin_chi']), canh: TextAlign.center),
              o(_d(g['diem_qua_trinh']), canh: TextAlign.center),
              o(_d(g['diem_giua_ky']), canh: TextAlign.center),
              o(_d(g['diem_cuoi_ky']), canh: TextAlign.center),
              o(
                _d(g['diem_tong_ket']),
                style: const TextStyle(fontWeight: FontWeight.w700),
                canh: TextAlign.center,
              ),
              Center(child: _chuChip(g.str('diem_chu'))),
              o(_d(g['gpa_thang_4']), canh: TextAlign.center),
            ],
          ),
      ],
    );
  }
}

/// Chip điểm chữ: A/B xanh · C/D vàng · F đỏ · P xanh.
Widget _chuChip(String chu) {
  if (chu.isEmpty) return const Text('—');
  final mau = switch (chu[0]) {
    'A' || 'B' || 'P' => StatusChip.green,
    'F' => StatusChip.red,
    _ => StatusChip.yellow,
  };
  return StatusChip.of(chu, mau);
}

/// App: mỗi môn một dòng trong thẻ học kỳ (bảng 10 cột không vừa điện thoại).
Widget _theMon(Json g) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  decoration: const BoxDecoration(
    border: Border(top: BorderSide(color: AppColors.divider)),
  ),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              g.str('ten_mon'),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Text(
              '${g.str('ma_mon')} · ${_d(g['tin_chi'])} TC',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'QT ${_d(g['diem_qua_trinh'])} · GK ${_d(g['diem_giua_ky'])} · CK ${_d(g['diem_cuoi_ky'])}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _d(g['diem_tong_ket']),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          _chuChip(g.str('diem_chu')),
          if (g['gpa_thang_4'] != null)
            Text(
              'Hệ 4: ${g['gpa_thang_4']}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
        ],
      ),
    ],
  ),
);

/// Thẻ tổng kết: nhãn · giá trị lớn (+ phụ " / 130") · ghi chú.
class _TheTong extends StatelessWidget {
  const _TheTong(
    this.nhan,
    this.giaTri,
    this.ghiChu, {
    this.mau = AppColors.navy,
    this.phu,
  });

  final String nhan;
  final String giaTri;
  final String ghiChu;
  final Color mau;
  final String? phu;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          nhan,
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              giaTri,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: mau,
              ),
            ),
            if (phu != null)
              Text(
                phu!,
                style: const TextStyle(fontSize: 18, color: AppColors.muted),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          ghiChu,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

/// Ô số liệu nhỏ của một học kỳ.
class _O extends StatelessWidget {
  const _O(this.nhan, this.giaTri, this.compact, {this.mau = AppColors.navy});

  final String nhan;
  final String giaTri;
  final bool compact;
  final Color mau;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        10,
        compact ? 10 : 14,
        10,
      ),
      decoration: BoxDecoration(
        color: _nenO,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              nhan,
              maxLines: 1,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              giaTri,
              maxLines: 1,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: mau,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}
