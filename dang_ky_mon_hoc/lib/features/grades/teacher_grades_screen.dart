import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  int? _lopId;

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
      final classes = snap.data;
      if (classes == null) return const ListSkeleton();
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
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 380,
                  child: LabeledDropdown<int?>(
                    label: 'Lớp học phần',
                    value: _lopId,
                    options: [
                      (null, '— Chọn lớp để nhập điểm —'),
                      for (final c in classes)
                        (c.id, '${c.str('ma_lop')} · ${c.str('ten_mon')}'),
                    ],
                    onChanged: (v) => setState(() => _lopId = v),
                  ),
                ),
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
