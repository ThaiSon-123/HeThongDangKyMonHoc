import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_user.dart';
import '../../core/download/print_html.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/status_chip.dart';
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import 'registration_format.dart';

/// Đồng hồ, thay được trong test.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Hàm in HTML, thay được trong test; `null` = không in được (bản App).
final printHtmlProvider = Provider<Future<void> Function(String)?>(
  (ref) => kIsWeb ? printHtml : null,
);

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

const _rowH = 34.0;
const _labelW = 56.0;
const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

// Màu theo lớp (nền nhạt + chữ đậm), xoay vòng.
const _palette = <(Color, Color)>[
  (Color(0xFFE8EAF6), Color(0xFF2C3A7A)),
  (Color(0xFFE0F2F1), Color(0xFF00695C)),
  (Color(0xFFFFF4D6), Color(0xFF8A5A00)),
  (Color(0xFFFDECEA), Color(0xFF8C1D18)),
  (Color(0xFFE6F4EA), Color(0xFF2E7D32)),
  (Color(0xFFF3E5F5), Color(0xFF6A1B9A)),
];

DateTime _date(String s) => DateTime.parse(s.substring(0, 10));

DateTime _monday(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

String _dm(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

class _Block {
  _Block(this.day, this.start, this.end, this.lop, this.color, this.phong);

  final int day; // 0 = T2 … 6 = CN
  final int start;
  final int end;
  final Json lop;
  final (Color, Color) color;
  final String phong;
}

/// Thời khóa biểu (SV-08; dùng chung cho GV-05) — mockup `SV-Web-TKB` / `SV-App-TKB`:
/// lưới tuần có ngày thật (tiết 1–15), chuyển tuần, hoặc xem cả học kỳ.
class TimetableScreen extends ConsumerStatefulWidget {
  const TimetableScreen({super.key});

  @override
  ConsumerState<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends ConsumerState<TimetableScreen> {
  late Future<Json> _data = _fetch();
  bool _weekly = true;
  int _offset = 0; // số tuần lệch so với tuần chứa hôm nay

  Future<Json> _fetch() => ref.read(trainingApiProvider).get('/timetable/my/');

  void _reload() {
    final next = _fetch();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final lop = [
        for (final l in d['lop_hoc_phan'] as List) Json.from(l as Map),
      ];
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _toolbar(d),
            const SizedBox(height: 16),
            _legend(lop),
            const SizedBox(height: 16),
            _body(d, lop),
          ],
        ),
      );
    },
  );

  DateTime get _weekStart =>
      _monday(ref.read(clockProvider)()).add(Duration(days: 7 * _offset));

  Widget _toolbar(Json d) {
    final mon = _weekStart;
    final sun = mon.add(const Duration(days: 6));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            d.str('ten_hk'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('Theo tuần'),
                selected: _weekly,
                onSelected: (_) => setState(() => _weekly = true),
              ),
              ChoiceChip(
                label: const Text('Cả học kỳ'),
                selected: !_weekly,
                onSelected: (_) => setState(() => _weekly = false),
              ),
            ],
          ),
          if (_weekly && ref.watch(printHtmlProvider) != null)
            OutlinedButton.icon(
              onPressed: () => _print(d),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('In thời khóa biểu'),
            ),
          if (_weekly)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Tuần trước',
                  onPressed: () => setState(() => _offset--),
                  icon: const Icon(Icons.chevron_left),
                ),
                Flexible(
                  child: TextButton(
                    onPressed: _offset == 0
                        ? null
                        : () => setState(() => _offset = 0),
                    child: Text(
                      'Tuần này · ${_dm(mon)} – ${_dm(sun)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tuần sau',
                  onPressed: () => setState(() => _offset++),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Tài liệu in A4 ngang của tuần đang xem: tiêu đề, thông tin SV/GV, bảng tiết × thứ có ngày thật.
  String _printDocument(Json d, String who) {
    final lop = [
      for (final l in d['lop_hoc_phan'] as List) Json.from(l as Map),
    ];
    final blocks = _blocks(d, lop);
    final mon = _weekStart;
    final rows = StringBuffer();
    final skip = <String>{}; // ô đã bị rowspan của khối phía trên chiếm
    for (var t = 1; t <= 15; t++) {
      rows.write('<tr><th>Tiết $t</th>');
      for (var day = 0; day < 7; day++) {
        if (skip.contains('$day-$t')) continue;
        final b = blocks.where((b) => b.day == day && b.start == t).firstOrNull;
        if (b == null) {
          rows.write('<td></td>');
          continue;
        }
        final n = b.end - b.start + 1;
        for (var k = 1; k < n; k++) {
          skip.add('$day-${t + k}');
        }
        rows.write(
          '<td class="b" rowspan="$n"><b>${_esc(b.lop.str('ten_mon'))}</b><br>'
          '${_esc(b.lop.str('ma_lop'))} · ${_esc(b.phong)}<br>'
          'GV ${_esc(b.lop.str('giao_vien_ten'))}</td>',
        );
      }
      rows.write('</tr>');
      if (t == 5 || t == 10) {
        rows.write('<tr class="sep"><td colspan="8"></td></tr>');
      }
    }
    final head = [
      for (var i = 0; i < 7; i++)
        '<th>${_days[i]}<br>${_dm(mon.add(Duration(days: i)))}</th>',
    ].join();
    return '<!doctype html><html lang="vi"><head><meta charset="utf-8">'
        '<title>Thời khóa biểu</title><style>'
        '@page{size:A4 landscape;margin:10mm}'
        'body{font-family:Arial,sans-serif;font-size:11px;color:#111}'
        'h1{font-size:16px;margin:0 0 4px}p{margin:0 0 8px;color:#444}'
        'table{border-collapse:collapse;width:100%;table-layout:fixed}'
        'th,td{border:1px solid #999;padding:3px;text-align:center;vertical-align:top;height:18px}'
        'td.b{background:#e8eaf6;text-align:left}tr.sep td{height:2px;padding:0;background:#555}'
        '</style></head><body>'
        '<h1>Thời khóa biểu</h1>'
        '<p>${_esc(who)} · ${_esc(d.str('ten_hk'))} · Tuần ${_dm(mon)} – ${_dm(mon.add(const Duration(days: 6)))}</p>'
        '<table><tr><th style="width:48px"></th>$head</tr>$rows</table>'
        '<p style="margin-top:6px">Sáng 1–5 · Chiều 6–10 · Tối 11–15 · In lúc ${formatDateTime(DateTime.now())}</p>'
        '</body></html>';
  }

  Future<void> _print(Json d) async {
    final profile = await ref.read(myProfileProvider.future);
    final who = [
      profile.fullName,
      profile.subtitle,
    ].where((e) => e.isNotEmpty).join(' · ');
    await ref.read(printHtmlProvider)!(_printDocument(d, who));
  }

  Widget _legend(List<Json> lop) => lop.isEmpty
      ? const SizedBox.shrink()
      : Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, l) in lop.indexed)
              StatusChip(
                '${l.str('ma_lop')} · ${l.str('ten_mon')}',
                bg: _palette[i % _palette.length].$1,
                fg: _palette[i % _palette.length].$2,
              ),
          ],
        );

  Widget _body(Json d, List<Json> lop) {
    if (lop.isEmpty) {
      return const _Empty(
        'Chưa có lớp nào trong thời khóa biểu',
        'Hãy đăng ký môn học để thời khóa biểu hiện ở đây.',
      );
    }
    return _weekly ? _week(d, lop) : _semester(lop);
  }

  // ------------------------------------------------------------ theo tuần
  List<_Block> _blocks(Json d, List<Json> lop) {
    final mon = _weekStart;
    final blocks = <_Block>[];
    for (final (i, l) in lop.indexed) {
      final from = _date(
        l['ngay_bat_dau'] != null
            ? l.str('ngay_bat_dau')
            : d.str('ngay_bat_dau'),
      );
      final to = _date(
        l['ngay_ket_thuc'] != null
            ? l.str('ngay_ket_thuc')
            : d.str('ngay_ket_thuc'),
      );
      for (final s in l['lich_hoc'] as List) {
        final lich = Json.from(s as Map);
        final day = lich.num0('thu') - 2;
        final date = mon.add(Duration(days: day));
        if (date.isBefore(from) || date.isAfter(to)) continue;
        blocks.add(
          _Block(
            day,
            lich.num0('tiet_bat_dau'),
            lich.num0('tiet_ket_thuc'),
            l,
            _palette[i % _palette.length],
            lich.str('phong'),
          ),
        );
      }
    }
    return blocks;
  }

  Widget _week(Json d, List<Json> lop) {
    final blocks = _blocks(d, lop);
    final mon = _weekStart;
    if (blocks.isEmpty) {
      // Màn dùng chung SV (học) và GV (dạy).
      final coDay =
          ref.read(authControllerProvider).user?.role == UserRole.teacher;
      return _Empty(
        coDay ? 'Tuần này không có tiết dạy' : 'Tuần này không có tiết học',
        'Chuyển sang tuần khác hoặc xem cả học kỳ.',
      );
    }
    final today = _monday(ref.read(clockProvider)()) == mon
        ? ref.read(clockProvider)().weekday - 1
        : -1;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final colW = ((box.maxWidth - 24 - _labelW) / 7).clamp(104.0, 400.0);
          final width = _labelW + colW * 7;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: _labelW),
                      for (var i = 0; i < 7; i++)
                        SizedBox(
                          width: colW,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
                                Text(
                                  _days[i],
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: i == today
                                        ? AppColors.primary
                                        : AppColors.label,
                                  ),
                                ),
                                Text(
                                  _dm(mon.add(Duration(days: i))),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: _rowH * 15,
                    child: Stack(
                      children: [
                        for (var t = 1; t <= 15; t++)
                          Positioned(
                            top: (t - 1) * _rowH,
                            left: 0,
                            right: 0,
                            height: _rowH,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: t == 6 || t == 11
                                        ? AppColors.border
                                        : AppColors.divider,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Tiết $t',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        for (final b in blocks)
                          Positioned(
                            top: (b.start - 1) * _rowH + 1,
                            left: _labelW + b.day * colW + 2,
                            width: colW - 4,
                            height: (b.end - b.start + 1) * _rowH - 2,
                            child: _BlockView(b),
                          ),
                      ],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Sáng 1–5 · Chiều 6–10 · Tối 11–15',
                      style: TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ cả học kỳ
  Widget _semester(List<Json> lop) => Column(
    children: [
      for (final (i, l) in lop.indexed)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.cardShadow,
              border: Border(
                left: BorderSide(
                  color: _palette[i % _palette.length].$2,
                  width: 4,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.str('ten_mon'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Text(
                  '${l.str('ma_lop')} · GV ${l.str('giao_vien_ten')}',
                  style: const TextStyle(fontSize: 13, color: AppColors.label),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lichText(l['lich_hoc'] as List)} · ${phongText(l['lich_hoc'] as List)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class _BlockView extends StatelessWidget {
  const _BlockView(this.b);

  final _Block b;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: b.color.$1,
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: b.color.$2, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          b.lop.str('ten_mon'),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: b.color.$2,
          ),
        ),
        Text(
          '${b.lop.str('ma_lop')} · ${b.phong}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: b.color.$2),
        ),
        Text(
          'GV ${b.lop.str('giao_vien_ten')}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: b.color.$2),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty(this.title, this.message);

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      ],
    ),
  );
}
