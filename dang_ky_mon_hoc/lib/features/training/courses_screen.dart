import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import 'entity_form.dart';
import 'majors_screen.dart' show khoaLabel;
import 'resource_list.dart';
import 'training_api.dart';
import 'training_widgets.dart';

const _path = '/courses/';
const _prereqPath = '/prerequisites/';

String monLabel(Json m) => '${m.str('ten_mon')} (${m.str('ma_mon')})';

/// Môn học & tiên quyết (PDT-04/05) — mockup `PDT-Web-MonHoc`: hai tab.
class CoursesScreen extends ConsumerStatefulWidget {
  const CoursesScreen({super.key});

  @override
  ConsumerState<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends ConsumerState<CoursesScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabsRow(
          labels: const ['Môn học', 'Tiên quyết'],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 20),
        if (_tab == 0) const _CourseList() else const _PrerequisitePanel(),
      ],
    ),
  );
}

// ------------------------------------------------------------------- Môn học
class _CourseList extends ConsumerStatefulWidget {
  const _CourseList();

  @override
  ConsumerState<_CourseList> createState() => _CourseListState();
}

class _CourseListState extends ConsumerState<_CourseList> {
  final _ctl = ResourceListController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _danhGia = <(Object, String)>[
    ('DIEM', 'Điểm'),
    ('DAT_KHONG_DAT', 'Đạt / Không đạt'),
  ];

  static const _specs = <FieldSpec>[
    TextSpec('ma_mon', 'Mã môn', lockedOnEdit: true, half: true),
    TextSpec('ten_mon', 'Tên môn', half: true),
    TextSpec('tin_chi_ly_thuyet', 'TC lý thuyết', number: true, half: true),
    TextSpec('tin_chi_thuc_hanh', 'TC thực hành', number: true, half: true),
    TextSpec('so_tiet_ly_thuyet', 'Số tiết LT', number: true, half: true),
    TextSpec('so_tiet_thuc_hanh', 'Số tiết TH', number: true, half: true),
    SelectSpec(
      'khoa',
      'Khoa / viện phụ trách',
      '/faculties/',
      khoaLabel,
      half: true,
      queryOf: _hoatDong,
    ),
    ChoiceSpec('loai_danh_gia', 'Loại đánh giá', _danhGia, half: true),
  ];

  static Map<String, Object?> _hoatDong(Map<String, Json?> _) => {
    'trang_thai': 'HOAT_DONG',
  };

  Future<void> _form([Json? row]) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Thêm môn học' : 'Sửa môn học',
      specs: _specs,
      initial: row,
      note: 'Tổng tín chỉ = TC lý thuyết + TC thực hành, hệ thống tự tính.',
      initialSelected: row == null
          ? const {}
          : {
              'khoa': {'id': row['khoa'], 'ten_khoa': row['khoa_ten']},
            },
      submit: (body) async => row == null
          ? api.create(_path, body)
          : api.update(_path, row.id, body),
    );
    if (saved && mounted) _ctl.reload();
  }

  void _setStatus(Json row, String status) {
    final stop = status == 'NGUNG_SU_DUNG';
    confirmAndRun(
      context,
      title: stop ? 'Ngừng sử dụng môn học?' : 'Dùng lại môn học?',
      message: stop
          ? '${row.str('ten_mon')} sẽ không mở được lớp mới; lớp và CTĐT hiện có được giữ nguyên.'
          : 'Cho phép mở lớp mới cho ${row.str('ten_mon')}?',
      actionLabel: stop ? 'Ngừng sử dụng' : 'Dùng lại',
      danger: stop,
      call: () => ref.read(trainingApiProvider).update(_path, row.id, {
        'trang_thai': status,
      }),
      success: stop ? 'Đã ngừng sử dụng môn học.' : 'Đã dùng lại môn học.',
      onDone: _ctl.reload,
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListToolbar(
        children: [
          SearchBox(
            controller: _ctl,
            label: 'Tìm theo mã / tên môn',
            hint: 'Nhập mã hoặc tên',
          ),
          SizedBox(
            width: 260,
            child: ApiSelect(
              label: 'Khoa / viện',
              path: '/faculties/',
              labelOf: khoaLabel,
              hint: 'Tất cả khoa / viện',
              onChanged: (o) => _ctl.setFilter('khoa', o?.id),
            ),
          ),
          FilterDropdown(
            controller: _ctl,
            filterKey: 'trang_thai',
            options: const [
              ('', 'Tất cả'),
              ('HOAT_DONG', 'Đang sử dụng'),
              ('NGUNG_SU_DUNG', 'Ngừng sử dụng'),
            ],
          ),
          AddButton('+ Thêm môn học', _form),
        ],
      ),
      const SizedBox(height: 24),
      ResourceList(
        controller: _ctl,
        path: _path,
        emptyText: 'Chưa có môn học nào.',
        columns: const [
          ListColumn('Môn học', flex: 3),
          ListColumn('Khoa / viện', flex: 2),
          ListColumn('Tín chỉ', width: 150),
          ListColumn('Số tiết LT / TH', width: 120),
          ListColumn('Đánh giá', width: 130),
          ListColumn('Trạng thái', width: 140),
          ListColumn('', width: 200),
        ],
        cells: (r) => [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.str('ten_mon'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                r.str('ma_mon'),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          Text(r.str('khoa_ten'), overflow: TextOverflow.ellipsis),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${r.num0('tong_tin_chi')} ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text:
                      '(${r.num0('tin_chi_ly_thuyet')} LT + ${r.num0('tin_chi_thuc_hanh')} TH)',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Text(
            '${r.num0('so_tiet_ly_thuyet')} / ${r.num0('so_tiet_thuc_hanh')}',
          ),
          Text(r.str('loai_danh_gia') == 'DIEM' ? 'Điểm' : 'Đạt / Không đạt'),
          trangThaiChip(r.str('trang_thai')),
          RowActions([
            RowButton('Sửa', () => _form(r)),
            if (r.str('trang_thai') == 'HOAT_DONG')
              RowButton(
                'Ngừng sử dụng',
                () => _setStatus(r, 'NGUNG_SU_DUNG'),
                danger: true,
              )
            else
              RowButton('Dùng lại', () => _setStatus(r, 'HOAT_DONG')),
          ]),
        ],
      ),
    ],
  );
}

// ------------------------------------------------------------------ Tiên quyết
/// Chọn một môn → xem/sửa các môn tiên quyết của nó. Server chặn tự tiên quyết và vòng (A → B → A).
class _PrerequisitePanel extends ConsumerStatefulWidget {
  const _PrerequisitePanel();

  @override
  ConsumerState<_PrerequisitePanel> createState() => _PrerequisitePanelState();
}

class _PrerequisitePanelState extends ConsumerState<_PrerequisitePanel> {
  Json? _mon;
  Json? _them;
  int _addKey = 0;
  String? _error;
  late Future<List<Json>> _list = Future.value(const []);

  void _reload() {
    final mon = _mon;
    final next = mon == null
        ? Future.value(const <Json>[])
        : ref
              .read(trainingApiProvider)
              .list(_prereqPath, pageSize: 50, query: {'mon_hoc': mon.id})
              .then((p) => p.items);
    setState(() {
      _list = next;
    });
  }

  Future<void> _add() async {
    final mon = _mon, them = _them;
    if (mon == null || them == null) return;
    try {
      await ref.read(trainingApiProvider).create(_prereqPath, {
        'mon_hoc': mon.id,
        'mon_tien_quyet': them.id,
      });
    } on ApiFailure catch (f) {
      if (mounted) {
        setState(
          () => _error =
              f.fields.values.firstOrNull ?? 'Không thêm được môn tiên quyết.',
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = null;
      _them = null;
      _addKey++;
    });
    _reload();
  }

  Future<void> _remove(Json p) async {
    await runAction(
      context,
      () => ref.read(trainingApiProvider).delete(_prereqPath, p.id),
      success: 'Đã bỏ môn tiên quyết.',
      onDone: _reload,
    );
  }

  @override
  Widget build(BuildContext context) => PanelCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 420,
          child: ApiSelect(
            label: 'Chọn môn cần thiết lập tiên quyết',
            path: _path,
            labelOf: monLabel,
            onChanged: (o) {
              _mon = o;
              _them = null;
              _error = null;
              _addKey++;
              _reload();
            },
          ),
        ),
        const SizedBox(height: 20),
        if (_mon == null)
          const Text(
            'Chọn một môn ở trên để xem và chỉnh môn tiên quyết của môn đó.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          )
        else ...[
          Text(
            'Môn tiên quyết của ${_mon!.str('ten_mon')}',
            style: sectionTitleStyle,
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<Json>>(
            future: _list,
            builder: (context, snap) {
              if (snap.hasError) {
                return ListErrorCard(onRetry: _reload);
              }
              final items = snap.data;
              if (items == null) return const ListSkeleton();
              if (items.isEmpty) {
                return const Text(
                  'Môn này chưa có môn tiên quyết.',
                  style: TextStyle(color: AppColors.muted, fontSize: 14),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in items)
                    InputChip(
                      label: Text(p.str('ma_mon_tien_quyet')),
                      deleteButtonTooltipMessage:
                          'Bỏ ${p.str('ma_mon_tien_quyet')}',
                      onDeleted: () => _remove(p),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              SizedBox(
                width: 380,
                child: ApiSelect(
                  key: ValueKey('them-${_mon!.id}-$_addKey'),
                  label: 'Thêm môn tiên quyết',
                  path: _path,
                  labelOf: monLabel,
                  onChanged: (o) => _them = o,
                ),
              ),
              SizedBox(
                width: 120,
                child: AppButton(label: 'Thêm', height: 44, onPressed: _add),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_error != null)
            AlertBanner(kind: BannerKind.error, message: _error!)
          else
            const Text(
              'Không cho phép môn tự tiên quyết hoặc tạo vòng (A → B → A).',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
        ],
      ],
    ),
  );
}
