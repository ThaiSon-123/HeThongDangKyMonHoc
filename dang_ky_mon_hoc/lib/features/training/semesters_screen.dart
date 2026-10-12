import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import 'entity_form.dart';
import 'resource_list.dart';
import 'training_api.dart';
import 'training_widgets.dart';

const _path = '/semesters/';

/// Học kỳ & cửa sổ đăng ký (PDT-06/07) — mockup `PDT-Web-HocKy`: bảng + phần chi tiết bên dưới.
class SemestersScreen extends ConsumerStatefulWidget {
  const SemestersScreen({super.key});

  @override
  ConsumerState<SemestersScreen> createState() => _SemestersScreenState();
}

class _SemestersScreenState extends ConsumerState<SemestersScreen> {
  final _ctl = ResourceListController();
  Json? _sel;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _createSpecs = <FieldSpec>[
    TextSpec('ten_hk', 'Học kỳ', hint: 'VD: Học kỳ 1', half: true),
    TextSpec('nam_hoc', 'Năm học', hint: 'VD: 2026-2027', half: true),
    DateSpec('ngay_bat_dau', 'Ngày bắt đầu', half: true),
    DateSpec('ngay_ket_thuc', 'Ngày kết thúc', half: true),
    DateTimeSpec('cua_so_dk_bat_dau', 'Cửa sổ đăng ký: bắt đầu', half: true),
    DateTimeSpec('cua_so_dk_ket_thuc', 'Cửa sổ đăng ký: kết thúc', half: true),
  ];

  Future<void> _create() async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: 'Thêm học kỳ',
      specs: _createSpecs,
      note: 'Cửa sổ đăng ký phải nằm trong thời gian học kỳ. Giới hạn tín chỉ mặc định 12 / 24 / 14, chỉnh sau ở phần chi tiết.',
      submit: (body) => api.create(_path, body),
    );
    if (saved && mounted) _ctl.reload();
  }

  void _changed(Json updated) {
    setState(() => _sel = updated);
    _ctl.reload();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListToolbar(
            children: [
              SearchBox(
                controller: _ctl,
                label: 'Tìm học kỳ',
                hint: 'Tên học kỳ hoặc năm học',
              ),
              FilterDropdown(
                controller: _ctl,
                filterKey: 'trang_thai',
                options: const [
                  ('', 'Tất cả'),
                  ('MO', 'Đang mở'),
                  ('DONG', 'Đã đóng'),
                ],
              ),
              AddButton('+ Thêm học kỳ', _create),
            ],
          ),
          const SizedBox(height: 24),
          ResourceList(
            controller: _ctl,
            path: _path,
            minWidth: 760,
            emptyText: 'Chưa có học kỳ nào.',
            onRowTap: (r) => setState(() => _sel = r),
            columns: const [
              ListColumn('Học kỳ', flex: 2),
              ListColumn('Cửa sổ đăng ký', flex: 3),
              ListColumn('Tín chỉ', width: 90),
              ListColumn('Trạng thái', width: 130),
            ],
            cells: (r) => [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.str('ten_hk'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Năm học ${r.str('nam_hoc')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              Text(
                '${formatIso(r.str('cua_so_dk_bat_dau')).split(' ').first} – '
                '${formatIso(r.str('cua_so_dk_ket_thuc')).split(' ').first}',
              ),
              Text(
                '${r.num0('tin_chi_toi_thieu')}-${r.num0('tin_chi_toi_da')}',
              ),
              trangThaiChip(r.str('trang_thai')),
            ],
          ),
          const SizedBox(height: 24),
          if (_sel == null)
            const PanelCard(
              child: Text(
                'Chọn một học kỳ ở bảng phía trên.',
                style: TextStyle(color: AppColors.muted, fontSize: 14),
              ),
            )
          else
            _SemesterDetail(
              key: ValueKey(_sel!.id),
              semester: _sel!,
              onChanged: _changed,
            ),
        ],
      ),
    );
  }
}

class _SemesterDetail extends ConsumerWidget {
  const _SemesterDetail({
    super.key,
    required this.semester,
    required this.onChanged,
  });

  final Json semester;
  final ValueChanged<Json> onChanged;

  static const _windowSpecs = <FieldSpec>[
    DateTimeSpec('cua_so_dk_bat_dau', 'Bắt đầu'),
    DateTimeSpec('cua_so_dk_ket_thuc', 'Kết thúc'),
  ];

  static const _limitSpecs = <FieldSpec>[
    TextSpec('tin_chi_toi_thieu', 'Tối thiểu', number: true),
    TextSpec('tin_chi_toi_da', 'Tối đa', number: true),
    TextSpec(
      'tin_chi_toi_da_canh_bao',
      'Tối đa khi bị cảnh báo học vụ',
      number: true,
    ),
  ];

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<FieldSpec> specs,
    required Future<Json> Function(TrainingApi api, Json body) call,
    String? note,
    required String success,
  }) async {
    final api = ref.read(trainingApiProvider);
    Json? result;
    final saved = await showEntityForm(
      context,
      title: title,
      specs: specs,
      initial: semester,
      note: note,
      submit: (body) async => result = await call(api, body),
    );
    if (saved && result != null && context.mounted) {
      onChanged(result!);
      showAppToast(context, success);
    }
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref) async {
    final open = semester.str('trang_thai') == 'MO';
    final name = semester.str('ten_hk');
    Json? result;
    await confirmAndRun(
      context,
      title: open ? 'Đóng học kỳ?' : 'Mở học kỳ?',
      message: open
          ? 'Đóng $name? Chỉ đóng được khi không còn lớp đang mở hoặc đang học.'
          : 'Mở lại $name?',
      actionLabel: open ? 'Đóng học kỳ' : 'Mở học kỳ',
      danger: open,
      call: () async => result = await ref
          .read(trainingApiProvider)
          .action(_path, semester.id, open ? 'close' : 'open'),
      success: open ? 'Đã đóng học kỳ.' : 'Đã mở học kỳ.',
      onDone: () {
        if (result != null) onChanged(result!);
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = semester.str('trang_thai') == 'MO';
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${semester.str('ten_hk')} · ${semester.str('nam_hoc')}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              trangThaiChip(semester.str('trang_thai')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${formatYmd(semester.str('ngay_bat_dau'))} – ${formatYmd(semester.str('ngay_ket_thuc'))}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          const Text('Cửa sổ đăng ký', style: sectionTitleStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${formatIso(semester.str('cua_so_dk_bat_dau'))} – ${formatIso(semester.str('cua_so_dk_ket_thuc'))}',
              ),
              RowButton(
                'Sửa cửa sổ',
                () => _edit(
                  context,
                  ref,
                  title: 'Cửa sổ đăng ký',
                  specs: _windowSpecs,
                  note:
                      'Cửa sổ phải nằm trong thời gian học kỳ (${formatYmd(semester.str('ngay_bat_dau'))} – ${formatYmd(semester.str('ngay_ket_thuc'))}).',
                  call: (api, body) =>
                      api.patchAction(_path, semester.id, 'window', body),
                  success: 'Đã lưu cửa sổ đăng ký.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Giới hạn tín chỉ đăng ký', style: sectionTitleStyle),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Tối thiểu ${semester.num0('tin_chi_toi_thieu')} · '
                'Tối đa ${semester.num0('tin_chi_toi_da')} · '
                'Tối đa khi bị cảnh báo học vụ ${semester.num0('tin_chi_toi_da_canh_bao')}',
              ),
              RowButton(
                'Sửa giới hạn',
                () => _edit(
                  context,
                  ref,
                  title: 'Giới hạn tín chỉ đăng ký',
                  specs: _limitSpecs,
                  note: 'Áp dụng cho mọi sinh viên đăng ký trong học kỳ này. Dưới mức tối thiểu vẫn đăng ký được nhưng có cảnh báo; vượt mức tối đa thì bị chặn.',
                  call: (api, body) => api.update(_path, semester.id, body),
                  success: 'Đã lưu giới hạn tín chỉ.',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 170,
                child: AppButton(
                  label: open ? 'Đóng học kỳ' : 'Mở học kỳ',
                  height: 44,
                  outlined: open,
                  onPressed: () => _toggle(context, ref),
                ),
              ),
              SizedBox(
                width: 130,
                child: AppButton(
                  label: 'Xem lớp →',
                  height: 44,
                  outlined: true,
                  onPressed: () =>
                      context.go('/pdt/classes?hoc_ky=${semester.id}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
