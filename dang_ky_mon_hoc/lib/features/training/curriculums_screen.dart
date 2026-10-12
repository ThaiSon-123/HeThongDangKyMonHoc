import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import 'courses_screen.dart' show monLabel;
import 'entity_form.dart';
import 'resource_list.dart';
import 'training_api.dart';
import 'training_widgets.dart';

const _path = '/curriculums/';
const _ccPath = '/curriculum-courses/';

String nganhLabel(Json n) => n.str('ten_nganh');
String ctdtLabel(Json c) => c.str('ma_ctdt');

const khoiKienThuc = <(Object, String)>[
  ('chung', 'Chung'),
  ('co_so_nganh', 'Cơ sở ngành'),
  ('chuyen_nganh', 'Chuyên ngành'),
  ('tu_chon', 'Tự chọn'),
  ('tot_nghiep', 'Tốt nghiệp'),
];
const loaiMon = <(Object, String)>[
  ('bat_buoc', 'Bắt buộc'),
  ('tu_chon', 'Tự chọn'),
];

String _nhan(List<(Object, String)> opts, String v) =>
    opts.firstWhere((o) => o.$1 == v, orElse: () => (v, v)).$2;

/// CTĐT & gán môn (PDT-03) — mockup `PDT-Web-CTDT`: hai tab.
class CurriculumsScreen extends ConsumerStatefulWidget {
  const CurriculumsScreen({super.key});

  @override
  ConsumerState<CurriculumsScreen> createState() => _CurriculumsScreenState();
}

class _CurriculumsScreenState extends ConsumerState<CurriculumsScreen> {
  int _tab = 0;
  Json? _ctdt; // CTĐT đang xem ở tab "Môn trong CTĐT"

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabsRow(
          labels: const ['CTĐT', 'Môn trong CTĐT'],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 20),
        if (_tab == 0)
          _CurriculumList(
            onViewCourses: (c) => setState(() {
              _ctdt = c;
              _tab = 1;
            }),
          )
        else
          _CurriculumCourses(initial: _ctdt),
      ],
    ),
  );
}

// ---------------------------------------------------------------- Tab CTĐT
class _CurriculumList extends ConsumerStatefulWidget {
  const _CurriculumList({required this.onViewCourses});

  final ValueChanged<Json> onViewCourses;

  @override
  ConsumerState<_CurriculumList> createState() => _CurriculumListState();
}

class _CurriculumListState extends ConsumerState<_CurriculumList> {
  final _ctl = ResourceListController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static Map<String, Object?> _hoatDong(Map<String, Json?> _) => {
    'trang_thai': 'HOAT_DONG',
  };

  static const _specs = <FieldSpec>[
    TextSpec('ma_ctdt', 'Mã CTĐT', lockedOnEdit: true, half: true),
    SelectSpec(
      'nganh',
      'Ngành',
      '/majors/',
      nganhLabel,
      lockedOnEdit: true,
      half: true,
      queryOf: _hoatDong,
    ),
    TextSpec(
      'khoa_tuyen_sinh',
      'Khóa tuyển sinh',
      lockedOnEdit: true,
      half: true,
      hint: 'VD: K2023',
    ),
    TextSpec(
      'tong_tin_chi_yeu_cau',
      'Tổng tín chỉ yêu cầu',
      number: true,
      half: true,
    ),
  ];

  Future<void> _form([Json? row]) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Thêm CTĐT' : 'Sửa CTĐT',
      specs: _specs,
      initial: row,
      note: 'Mỗi ngành theo từng khóa chỉ có một CTĐT đang hoạt động.',
      initialSelected: row == null
          ? const {}
          : {
              'nganh': {'id': row['nganh'], 'ten_nganh': row['nganh_ten']},
            },
      submit: (body) async => row == null
          ? api.create(_path, body)
          : api.update(_path, row.id, body),
    );
    if (saved && mounted) _ctl.reload();
  }

  void _setStatus(Json row, String status) {
    final stop = status == 'NGUNG';
    confirmAndRun(
      context,
      title: stop ? 'Ngừng CTĐT?' : 'Mở lại CTĐT?',
      message: stop
          ? 'Ngừng ${row.str('ma_ctdt')}? Hồ sơ sinh viên hiện có được giữ nguyên.'
          : 'Mở lại ${row.str('ma_ctdt')}? Mỗi ngành theo từng khóa chỉ có một CTĐT đang hoạt động.',
      actionLabel: stop ? 'Ngừng CTĐT' : 'Mở lại',
      danger: stop,
      call: () => ref.read(trainingApiProvider).update(_path, row.id, {
        'trang_thai': status,
      }),
      success: stop ? 'Đã ngừng CTĐT.' : 'Đã mở lại CTĐT.',
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
            label: 'Tìm CTĐT',
            hint: 'Mã CTĐT hoặc ngành',
          ),
          SizedBox(
            width: 240,
            child: ApiSelect(
              label: 'Ngành',
              path: '/majors/',
              labelOf: nganhLabel,
              hint: 'Tất cả ngành',
              onChanged: (o) => _ctl.setFilter('nganh', o?.id),
            ),
          ),
          FilterDropdown(
            controller: _ctl,
            filterKey: 'trang_thai',
            options: dungOptions,
          ),
          AddButton('+ Thêm CTĐT', _form),
        ],
      ),
      const SizedBox(height: 24),
      ResourceList(
        controller: _ctl,
        path: _path,
        emptyText: 'Chưa có CTĐT nào.',
        columns: const [
          ListColumn('Mã CTĐT', flex: 2),
          ListColumn('Ngành', flex: 2),
          ListColumn('Khóa tuyển sinh', width: 140),
          ListColumn('Tổng TC yêu cầu', width: 140),
          ListColumn('Trạng thái', width: 130),
          ListColumn('', width: 250),
        ],
        cells: (r) => [
          Text(r.str('ma_ctdt'), style: monoStyle),
          Text(r.str('nganh_ten'), overflow: TextOverflow.ellipsis),
          Text(r.str('khoa_tuyen_sinh')),
          Text('${r.num0('tong_tin_chi_yeu_cau')}'),
          trangThaiChip(r.str('trang_thai')),
          RowActions([
            RowButton('Xem môn', () => widget.onViewCourses(r)),
            RowButton('Sửa', () => _form(r)),
            if (r.str('trang_thai') == 'HOAT_DONG')
              RowButton('Ngừng', () => _setStatus(r, 'NGUNG'), danger: true)
            else
              RowButton('Mở lại', () => _setStatus(r, 'HOAT_DONG')),
          ]),
        ],
      ),
    ],
  );
}

// ------------------------------------------------------- Tab Môn trong CTĐT
class _CurriculumCourses extends ConsumerStatefulWidget {
  const _CurriculumCourses({this.initial});

  final Json? initial;

  @override
  ConsumerState<_CurriculumCourses> createState() => _CurriculumCoursesState();
}

class _CurriculumCoursesState extends ConsumerState<_CurriculumCourses> {
  final _ctl = ResourceListController();
  Json? _ctdt;
  Future<int>? _assigned;

  @override
  void initState() {
    super.initState();
    _ctdt = widget.initial;
    final c = _ctdt;
    if (c != null) {
      _ctl.filters['ctdt'] = c.id;
      _loadAssigned();
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _loadAssigned() {
    final c = _ctdt;
    _assigned = c == null
        ? null
        : ref
              .read(trainingApiProvider)
              .listAll(_ccPath, query: {'ctdt': c.id})
              .then(
                (l) => l.fold<int>(0, (s, e) => s + e.num0('tong_tin_chi')),
              );
  }

  void _select(Json? c) {
    _ctdt = c;
    _ctl.setFilter('ctdt', c?.id);
    setState(_loadAssigned);
  }

  void _afterChange() {
    _ctl.reload();
    setState(_loadAssigned);
  }

  static Map<String, Object?> _hoatDong(Map<String, Json?> _) => {
    'trang_thai': 'HOAT_DONG',
  };

  static final _ky = <(Object, String)>[
    for (var i = 1; i <= 12; i++) (i, 'Kỳ $i'),
  ];

  static final _specs = <FieldSpec>[
    SelectSpec(
      'mon_hoc',
      'Môn học',
      '/courses/',
      monLabel,
      lockedOnEdit: true,
      queryOf: _hoatDong,
    ),
    ChoiceSpec('khoi_kien_thuc', 'Khối kiến thức', khoiKienThuc, half: true),
    ChoiceSpec('loai_mon', 'Loại môn', loaiMon, half: true),
    ChoiceSpec('hoc_ky_goi_y', 'Học kỳ gợi ý', _ky, half: true),
  ];

  Future<void> _form([Json? row]) async {
    final ctdt = _ctdt;
    if (ctdt == null) return;
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Gán môn vào CTĐT' : 'Sửa môn trong CTĐT',
      saveLabel: row == null ? 'Gán môn' : 'Lưu',
      specs: _specs,
      initial: row,
      note: 'Đổi khối kiến thức có thể làm thay đổi học phí.',
      initialSelected: row == null
          ? const {}
          : {
              'mon_hoc': {
                'id': row['mon_hoc'],
                'ten_mon': row['ten_mon'],
                'ma_mon': row['ma_mon'],
              },
            },
      submit: (body) async => row == null
          ? api.create(_ccPath, {...body, 'ctdt': ctdt.id})
          : api.update(_ccPath, row.id, body),
    );
    if (saved && mounted) _afterChange();
  }

  void _remove(Json row) => confirmAndRun(
    context,
    title: 'Bỏ môn khỏi CTĐT?',
    message: 'Bỏ ${row.str('ten_mon')} khỏi ${_ctdt?.str('ma_ctdt')}?',
    actionLabel: 'Bỏ môn',
    call: () => ref.read(trainingApiProvider).delete(_ccPath, row.id),
    success: 'Đã bỏ môn khỏi CTĐT.',
    onDone: _afterChange,
  );

  Widget _summary() {
    final ctdt = _ctdt!;
    final required = ctdt.num0('tong_tin_chi_yeu_cau');
    return FutureBuilder<int>(
      future: _assigned,
      builder: (context, snap) {
        final got = snap.data;
        final gap = got == null ? null : required - got;
        return Wrap(
          spacing: 8,
          children: [
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Đã gán '),
                  TextSpan(
                    text: got == null ? '…' : '$got',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: ' / $required tín chỉ'),
                ],
              ),
              style: const TextStyle(fontSize: 14),
            ),
            if (got != null)
              Text(
                gap! > 0
                    ? '· còn thiếu $gap tín chỉ'
                    : gap < 0
                    ? '· vượt ${-gap} tín chỉ'
                    : '· đủ tín chỉ yêu cầu',
                style: TextStyle(
                  fontSize: 14,
                  color: gap == 0 ? AppColors.success : AppColors.warning,
                ),
              ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListToolbar(
        children: [
          SizedBox(
            width: 300,
            child: ApiSelect(
              key: ValueKey(_ctdt?.id),
              label: 'Chương trình đào tạo',
              path: _path,
              labelOf: ctdtLabel,
              selected: _ctdt,
              onChanged: _select,
            ),
          ),
          if (_ctdt != null) _summary(),
          if (_ctdt != null) AddButton('+ Gán môn vào CTĐT', _form),
        ],
      ),
      const SizedBox(height: 24),
      if (_ctdt == null)
        const PanelCard(
          child: Text(
            'Chọn một CTĐT ở trên để xem và gán môn.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        )
      else
        ResourceList(
          controller: _ctl,
          path: _ccPath,
          emptyText: 'CTĐT này chưa có môn nào.',
          columns: const [
            ListColumn('Môn học', flex: 3),
            ListColumn('TC', width: 60),
            ListColumn('Khối kiến thức', width: 150),
            ListColumn('Loại môn', width: 120),
            ListColumn('Học kỳ gợi ý', width: 120),
            ListColumn('', width: 150),
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
            Text('${r.num0('tong_tin_chi')}'),
            Text(_nhan(khoiKienThuc, r.str('khoi_kien_thuc'))),
            Text(_nhan(loaiMon, r.str('loai_mon'))),
            Text('Kỳ ${r.num0('hoc_ky_goi_y')}'),
            RowActions([
              RowButton('Sửa', () => _form(r)),
              RowButton('Bỏ', () => _remove(r), danger: true),
            ]),
          ],
        ),
    ],
  );
}
