import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import 'grade_sheet_panel.dart';

/// Nhập điểm của giáo viên (GV-10) — mockup `Web-NhapDiem`: chọn lớp → bảng điểm cả lớp.
class TeacherGradesScreen extends ConsumerStatefulWidget {
  const TeacherGradesScreen({super.key});

  @override
  ConsumerState<TeacherGradesScreen> createState() =>
      _TeacherGradesScreenState();
}

class _TeacherGradesScreenState extends ConsumerState<TeacherGradesScreen> {
  late Future<List<Json>> _classes = _load();
  String? _hocKy; // tên học kỳ đang lọc (null = học kỳ mới nhất)
  int? _lopId;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    // Lối tắt "Nhập điểm" ở màn Lớp phụ trách đi kèm ?lop=<id>: chọn sẵn lớp đó.
    final id = int.tryParse(
      GoRouterState.of(context).uri.queryParameters['lop'] ?? '',
    );
    if (id == null) return;
    _classes
        .then((l) {
          final lop = l.where((c) => c.id == id).firstOrNull;
          if (mounted && lop != null) {
            setState(() {
              _lopId = id;
              _hocKy = lop.str(
                'ten_hk',
              ); // mở đúng học kỳ của lớp được chọn sẵn
            });
          }
        })
        .catchError((_) {});
  }

  Future<List<Json>> _load() => ref
      .read(trainingApiProvider)
      .listAll('/class-sections/my/')
      .then(
        (l) => [
          for (final c in l)
            if (c.str('trang_thai') != 'KE_HOACH') c,
        ],
      );

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    future: _classes,
    builder: (context, snap) {
      if (snap.hasError) {
        return ListErrorCard(
          onRetry: () {
            final next = _load();
            setState(() {
              _classes = next;
            });
          },
        );
      }
      final tatCa = snap.data;
      if (tatCa == null) return const ListSkeleton();
      // Lớp tôi phụ trách xếp mới nhất trước → danh sách học kỳ cũng mới nhất trước.
      final hocKy = {for (final c in tatCa) c.str('ten_hk')}.toList();
      final hk = _hocKy ?? (hocKy.isEmpty ? '' : hocKy.first);
      final classes = [
        for (final c in tatCa)
          if (c.str('ten_hk') == hk) c,
      ];
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      // Chọn học kỳ trước, rồi mới chọn lớp của học kỳ đó.
                      if (hocKy.length > 1)
                        SizedBox(
                          width: isCompact(context) ? double.infinity : 320,
                          child: LabeledDropdown<String>(
                            label: 'Học kỳ',
                            value: hk,
                            options: [for (final h in hocKy) (h, h)],
                            onChanged: (v) => setState(() {
                              _hocKy = v;
                              _lopId = null;
                            }),
                          ),
                        ),
                      SizedBox(
                        width: isCompact(context) ? double.infinity : 380,
                        child: LabeledDropdown<int?>(
                          label: 'Lớp học phần',
                          value: _lopId,
                          options: [
                            (null, '— Chọn lớp để nhập điểm —'),
                            for (final c in classes)
                              (
                                c.id,
                                '${c.str('ma_lop')} · ${c.str('ten_mon')}',
                              ),
                          ],
                          onChanged: (v) => setState(() => _lopId = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Điểm đã khóa vẫn chưa hiển thị cho sinh viên cho tới khi Phòng đào tạo duyệt.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (_lopId == null)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 36,
                  horizontal: 24,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: AppColors.cardShadow,
                ),
                child: const Column(
                  children: [
                    Text(
                      'Chọn lớp để nhập điểm',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Bảng điểm cả lớp hiển thị sau khi bạn chọn lớp học phần ở trên.',
                      style: TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
                  ],
                ),
              )
            else
              GradeSheetPanel(
                key: ValueKey(_lopId),
                lopId: _lopId!,
                isPdt: false,
              ),
          ],
        ),
      );
    },
  );
}
