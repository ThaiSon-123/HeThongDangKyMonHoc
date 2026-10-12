import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/widgets/status_chip.dart';
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';

String _d(Object? v, [String empty = '—']) => v == null ? empty : v.toString();

/// Điểm của sinh viên (SV-11) — mockup `SV-Web-Diem`: chỉ điểm đã được PĐT duyệt, GPA tích lũy,
/// thống kê từng học kỳ (BR-25g).
class StudentGradesScreen extends ConsumerStatefulWidget {
  const StudentGradesScreen({super.key});

  @override
  ConsumerState<StudentGradesScreen> createState() =>
      _StudentGradesScreenState();
}

class _StudentGradesScreenState extends ConsumerState<StudentGradesScreen> {
  late Future<Json> _data = ref.read(trainingApiProvider).get('/grades/my/');
  int? _hk; // null = tất cả học kỳ

  void _reload() {
    final next = ref.read(trainingApiProvider).get('/grades/my/');
    setState(() => _data = next);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final stats = [
        for (final s in d['thong_ke'] as List) Json.from(s as Map),
      ];
      final diem = [for (final g in d['diem'] as List) Json.from(g as Map)];
      final shown = stats.reversed
          .where((s) => _hk == null || s.num0('hoc_ky') == _hk)
          .toList();
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Card(
              child: Wrap(
                spacing: 32,
                runSpacing: 12,
                children: [
                  _Stat('GPA tích lũy', _d(d['gpa'], 'Chưa có')),
                  _Stat('Tín chỉ tích lũy', _d(d['tin_chi_tich_luy'])),
                  _Stat('Xếp loại', _d(d['xep_loai'], 'Chưa có')),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (stats.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả học kỳ'),
                    selected: _hk == null,
                    onSelected: (_) => setState(() => _hk = null),
                  ),
                  for (final s in stats.reversed)
                    ChoiceChip(
                      label: Text(s.str('ten_hk')),
                      selected: _hk == s.num0('hoc_ky'),
                      onSelected: (_) => setState(() => _hk = s.num0('hoc_ky')),
                    ),
                ],
              ),
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
              ]),
          ],
        ),
      );
    },
  );

  Widget _semester(Json s, List<Json> rows) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: _Card(
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
          const SizedBox(height: 8),
          Wrap(
            spacing: 24,
            runSpacing: 6,
            children: [
              _Mini('Tín chỉ học', _d(s['tin_chi_hoc'])),
              _Mini('Tín chỉ đạt', _d(s['tin_chi_dat'])),
              _Mini('Điểm TB (hệ 10)', _d(s['diem_tb'])),
              _Mini('GPA học kỳ', _d(s['gpa'])),
              _Mini('Xếp loại', _d(s['xep_loai'])),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20,
              headingRowHeight: 36,
              dataRowMinHeight: 36,
              dataRowMaxHeight: 40,
              columns: const [
                DataColumn(label: Text('Mã môn')),
                DataColumn(label: Text('Tên môn')),
                DataColumn(label: Text('TC')),
                DataColumn(label: Text('QT')),
                DataColumn(label: Text('GK')),
                DataColumn(label: Text('CK')),
                DataColumn(label: Text('Tổng kết')),
                DataColumn(label: Text('Chữ')),
                DataColumn(label: Text('Hệ 4')),
              ],
              rows: [
                for (final g in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(g.str('ma_mon'))),
                      DataCell(Text(g.str('ten_mon'))),
                      DataCell(Text(_d(g['tin_chi']))),
                      DataCell(Text(_d(g['diem_qua_trinh']))),
                      DataCell(Text(_d(g['diem_giua_ky']))),
                      DataCell(Text(_d(g['diem_cuoi_ky']))),
                      DataCell(Text(_d(g['diem_tong_ket']))),
                      DataCell(
                        g.str('diem_chu') == 'F'
                            ? StatusChip.of('F', StatusChip.red)
                            : Text(
                                g.str('diem_chu'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                      DataCell(Text(_d(g['gpa_thang_4']))),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ],
  );
}

class _Mini extends StatelessWidget {
  const _Mini(this.k, this.v);

  final String k;
  final String v;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$k: ',
          style: const TextStyle(color: AppColors.muted),
        ),
        TextSpan(
          text: v,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
    style: const TextStyle(fontSize: 13),
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
