import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import 'courses_screen.dart' show monLabel;
import 'curriculums_screen.dart' show nganhLabel;
import 'entity_form.dart';
import 'resource_list.dart';
import 'training_api.dart';
import 'training_widgets.dart';

const _path = '/class-sections/';
const _schedulePath = '/schedules/';

String hocKyLabel(Json h) => h.str('ten_hk');
String giaoVienLabel(Json g) => g.str('ma_gv').isEmpty
    ? g.str('ho_ten')
    : '${g.str('ho_ten')} (${g.str('ma_gv')})';

const _thu = <(Object, String)>[
  (2, 'Thứ 2'),
  (3, 'Thứ 3'),
  (4, 'Thứ 4'),
  (5, 'Thứ 5'),
  (6, 'Thứ 6'),
  (7, 'Thứ 7'),
  (8, 'Chủ nhật'),
];

String _thuText(int thu) => thu == 8 ? 'Chủ nhật' : 'Thứ $thu';

String _buoiText(String buoi) => switch (buoi) {
  'SANG' => 'sáng',
  'CHIEU' => 'chiều',
  _ => 'tối',
};

/// Lớp học phần & lịch (PDT-08/09) — mockup `PDT-Web-LopHP`: bộ lọc liên động, bảng, ngăn chi tiết.
class ClassesScreen extends ConsumerStatefulWidget {
  const ClassesScreen({super.key});

  @override
  ConsumerState<ClassesScreen> createState() => _ClassesScreenState();
}

class _ClassesScreenState extends ConsumerState<ClassesScreen> {
  final _ctl = ResourceListController();
  Json? _hocKy, _nganh, _mon;
  String _trangThai = '';
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    // `Xem lớp →` ở màn học kỳ đi kèm ?hoc_ky=<id>: lọc sẵn và tải nhãn học kỳ.
    final id = GoRouterState.of(context).uri.queryParameters['hoc_ky'];
    if (id != null) {
      _ctl.filters['hoc_ky'] = id;
      ref
          .read(trainingApiProvider)
          .get('$_semestersPath$id/')
          .then((h) {
            if (mounted) setState(() => _hocKy = h);
          })
          .catchError((_) {});
    }
  }

  static const _semestersPath = '/semesters/';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _trangThaiOpts = <(String, String)>[
    ('', 'Tất cả'),
    ('KE_HOACH', 'Kế hoạch'),
    ('MO', 'Đang mở'),
    ('DANG_HOC', 'Đang học'),
    ('DA_DONG', 'Đã đóng'),
  ];

  static Map<String, Object?> _nganhHoatDong(Map<String, Json?> _) => {
    'trang_thai': 'HOAT_DONG',
  };

  static Map<String, Object?> _monTheoNganh(Map<String, Json?> sel) => {
    'trang_thai': 'HOAT_DONG',
    'nganh': sel['nganh']?.id,
  };

  static Map<String, Object?> _gvTheoMon(Map<String, Json?> sel) => {
    'khoa': sel['mon_hoc']?['khoa'],
  };

  static const _specs = <FieldSpec>[
    SelectSpec(
      'nganh',
      'Ngành',
      '/majors/',
      nganhLabel,
      required: false,
      send: false,
      half: true,
      queryOf: _nganhHoatDong,
      helper: 'Chọn ngành để lọc danh sách môn.',
    ),
    SelectSpec('hoc_ky', 'Học kỳ', '/semesters/', hocKyLabel, half: true),
    SelectSpec(
      'mon_hoc',
      'Môn học',
      '/courses/',
      monLabel,
      dependsOn: ['nganh'],
      queryOf: _monTheoNganh,
    ),
    SelectSpec(
      'giao_vien',
      'Giáo viên',
      '/profiles/teachers/',
      giaoVienLabel,
      dependsOn: ['mon_hoc'],
      queryOf: _gvTheoMon,
      helper: 'Chỉ gợi ý giáo viên cùng khoa / viện với môn.',
    ),
    TextSpec('ma_lop', 'Mã lớp', lockedOnEdit: true, half: true),
    TextSpec('si_so_toi_da', 'Sĩ số tối đa', number: true, half: true),
    DateSpec(
      'ngay_bat_dau',
      'Ngày bắt đầu',
      required: false,
      half: true,
      helper: 'Để trống = theo học kỳ.',
    ),
    DateSpec(
      'ngay_ket_thuc',
      'Ngày kết thúc',
      required: false,
      half: true,
      helper: 'Để trống = theo học kỳ.',
    ),
  ];

  static Json _sel(Json row, String idKey, Json labels) => {
    'id': row[idKey],
    ...labels,
  };

  Future<void> _form([Json? row]) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Tạo lớp học phần' : 'Sửa lớp học phần',
      specs: _specs,
      initial: row,
      maxWidth: 620,
      initialSelected: row == null
          ? {'hoc_ky': ?_hocKy}
          : {
              'hoc_ky': _sel(row, 'hoc_ky', {'ten_hk': row['ten_hk']}),
              'mon_hoc': _sel(row, 'mon_hoc', {
                'ten_mon': row['ten_mon'],
                'ma_mon': row['ma_mon'],
              }),
              'giao_vien': _sel(row, 'giao_vien', {
                'ho_ten': row['giao_vien_ten'],
                'ma_gv': '',
              }),
            },
      submit: (body) async => row == null
          ? api.create(_path, body)
          : api.update(_path, row.id, body),
    );
    if (saved && mounted) _ctl.reload();
  }

  Future<void> _detail(Json row) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => ClassDetailDialog(classId: row.id),
    );
    if (changed == true && mounted) _ctl.reload();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListToolbar(
            children: [
              SizedBox(
                width: 220,
                child: ApiSelect(
                  key: ValueKey('hk-${_hocKy?.id}'),
                  label: 'Học kỳ',
                  path: _semestersPath,
                  labelOf: hocKyLabel,
                  selected: _hocKy,
                  hint: 'Tất cả học kỳ',
                  onChanged: (o) {
                    _hocKy = o;
                    _ctl.setFilter('hoc_ky', o?.id);
                  },
                ),
              ),
              SizedBox(
                width: 220,
                child: ApiSelect(
                  label: 'Ngành',
                  path: '/majors/',
                  labelOf: nganhLabel,
                  hint: 'Tất cả ngành',
                  onChanged: (o) {
                    setState(() {
                      _nganh = o;
                      _mon = null;
                    });
                    _ctl
                      ..filters.remove('mon_hoc')
                      ..filters.remove('giao_vien')
                      ..setFilter('nganh', o?.id);
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
                    setState(() {
                      _mon = o;
                    });
                    _ctl
                      ..filters.remove('giao_vien')
                      ..setFilter('mon_hoc', o?.id);
                  },
                ),
              ),
              SizedBox(
                width: 260,
                child: ApiSelect(
                  key: ValueKey('gv-${_mon?.id}'),
                  label: 'Giáo viên',
                  path: '/profiles/teachers/',
                  query: {'khoa': _mon?['khoa']},
                  labelOf: giaoVienLabel,
                  hint: 'Tất cả giáo viên',
                  onChanged: (o) {
                    _ctl.setFilter('giao_vien', o?.id);
                  },
                ),
              ),
              SizedBox(
                width: 170,
                child: LabeledDropdown<String>(
                  label: 'Trạng thái',
                  value: _trangThai,
                  options: _trangThaiOpts,
                  onChanged: (v) {
                    setState(() => _trangThai = v);
                    _ctl.setFilter('trang_thai', v.isEmpty ? null : v);
                  },
                ),
              ),
              AddButton('+ Tạo lớp học phần', _form),
            ],
          ),
          const SizedBox(height: 24),
          ResourceList(
            controller: _ctl,
            path: _path,
            minWidth: 1000,
            emptyText: 'Không có lớp học phần phù hợp với bộ lọc.',
            onRowTap: _detail,
            columns: const [
              ListColumn('Mã lớp', width: 150),
              ListColumn('Môn học', flex: 2),
              ListColumn('Giáo viên', flex: 2),
              ListColumn('Sĩ số', width: 150),
              ListColumn('Bắt đầu – kết thúc', width: 190),
              ListColumn('Hạn nhập điểm', width: 120),
              ListColumn('Trạng thái', width: 120),
            ],
            cells: (r) => [
              Text(r.str('ma_lop'), style: monoStyle),
              Text(
                r.str('ten_mon'),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(r.str('giao_vien_ten'), overflow: TextOverflow.ellipsis),
              _SiSo(r.num0('si_so_hien_tai'), r.num0('si_so_toi_da')),
              Text(
                '${formatYmd(r.str('ngay_bat_dau'))} – ${formatYmd(r.str('ngay_ket_thuc'))}',
                style: const TextStyle(fontSize: 13),
              ),
              Text(
                formatYmd(r.str('han_nhap_diem_hieu_luc')),
                style: const TextStyle(fontSize: 13),
              ),
              trangThaiChip(r.str('trang_thai')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Sĩ số + thanh tỷ lệ (vàng ≥ 80%, đỏ ≥ 95%) như mockup.
class _SiSo extends StatelessWidget {
  const _SiSo(this.now, this.max);

  final int now;
  final int max;

  @override
  Widget build(BuildContext context) {
    final ratio = max == 0 ? 0.0 : (now / max).clamp(0.0, 1.0);
    final color = ratio >= .95
        ? AppColors.danger
        : ratio >= .8
        ? AppColors.warning
        : AppColors.success;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              color: color,
              backgroundColor: const Color(0xFFECEFF5),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$now/$max', style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

// ----------------------------------------------------------- Ngăn chi tiết lớp
/// Chi tiết một lớp: mở/đóng lớp, lịch học, gia hạn nhập điểm. Trả `true` khi có thay đổi.
class ClassDetailDialog extends ConsumerStatefulWidget {
  const ClassDetailDialog({super.key, required this.classId});

  final int classId;

  @override
  ConsumerState<ClassDetailDialog> createState() => _ClassDetailDialogState();
}

class _ClassDetailDialogState extends ConsumerState<ClassDetailDialog> {
  Json? _lop;
  bool _error = false;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final l = await ref
          .read(trainingApiProvider)
          .get('$_path${widget.classId}/');
      if (mounted) {
        setState(() {
          _lop = l;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = true);
      }
    }
  }

  void _done() {
    _changed = true;
    _load();
  }

  static const _soTiet = <(Object, String)>[
    (1, '1 tiết'),
    (2, '2 tiết'),
    (3, '3 tiết'),
    (4, '4 tiết'),
    (5, '5 tiết'),
  ];

  static final _tiet = <(Object, String)>[
    for (var i = 1; i <= 15; i++) (i, 'Tiết $i'),
  ];

  static final _lichSpecs = <FieldSpec>[
    ChoiceSpec('thu', 'Thứ', _thu, half: true),
    ChoiceSpec('tiet_bat_dau', 'Tiết bắt đầu', _tiet, half: true),
    ChoiceSpec('so_tiet_moi_buoi', 'Số tiết/buổi', _soTiet, half: true),
    const TextSpec('phong', 'Phòng', half: true),
  ];

  Future<void> _addSchedule() async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: 'Thêm buổi học',
      saveLabel: 'Thêm lịch',
      specs: _lichSpecs,
      note: 'Buổi sáng tiết 1–5, chiều 6–10, tối 11–15; số tiết không vượt hết buổi. Phòng và giáo viên không được trùng giờ với lớp khác cùng học kỳ.',
      submit: (body) =>
          api.create(_schedulePath, {...body, 'lop_hoc_phan': widget.classId}),
    );
    if (saved) _done();
  }

  Future<void> _removeSchedule(Json lich) => runAction(
    context,
    () => ref.read(trainingApiProvider).delete(_schedulePath, lich.id),
    success: 'Đã xóa buổi học.',
    onDone: _done,
  );

  Future<void> _openOrClose(bool open) async {
    final lop = _lop!;
    final name = lop.str('ma_lop');
    final ok = await showConfirmDialog(
      context,
      title: open ? 'Mở lớp?' : 'Đóng lớp?',
      message: open
          ? 'Mở $name cho sinh viên đăng ký? Cần có lịch học và môn đang sử dụng.'
          : 'Đóng $name? Điểm danh và nhập điểm sẽ bị khóa. Chỉ đóng được khi lớp đã kết thúc và mọi sinh viên có điểm chính thức.',
      actionLabel: open ? 'Mở lớp' : 'Đóng lớp',
      danger: !open,
    );
    if (!ok || !mounted) return;
    await runAction(
      context,
      () => ref
          .read(trainingApiProvider)
          .action(_path, widget.classId, open ? 'open' : 'close'),
      success: open ? 'Đã mở lớp.' : 'Đã đóng lớp.',
      onDone: _done,
    );
  }

  Future<void> _edit() async {
    final lop = _lop!;
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: 'Sửa lớp học phần',
      specs: const [
        TextSpec('si_so_toi_da', 'Sĩ số tối đa', number: true, half: true),
        DateSpec('ngay_bat_dau', 'Ngày bắt đầu', required: false, half: true),
        DateSpec('ngay_ket_thuc', 'Ngày kết thúc', required: false, half: true),
      ],
      initial: lop,
      submit: (body) => api.update(_path, lop.id, body),
    );
    if (saved) _done();
  }

  Future<void> _extend() async {
    final lop = _lop!;
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: 'Gia hạn nhập điểm',
      saveLabel: 'Gia hạn',
      specs: const [
        DateSpec('han_nhap_diem', 'Hạn mới (phải sau hạn hiện tại)'),
      ],
      initial: lop,
      submit: (body) => api.action(_path, lop.id, 'grade-deadline', body),
    );
    if (saved) {
      if (mounted) showAppToast(context, 'Đã gia hạn nhập điểm.');
      _done();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lop = _lop;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: AppDialog(
        title: lop == null ? 'Chi tiết lớp' : lop.str('ma_lop'),
        maxWidth: 680,
        actions: [
          DialogButton(
            'Đóng',
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
        ],
        child: _error
            ? ListErrorCard(onRetry: _load)
            : lop == null
            ? const ListSkeleton()
            : _body(lop),
      ),
    );
  }

  Widget _body(Json lop) {
    final tt = lop.str('trang_thai');
    final lich = [for (final l in lop['lich_hoc'] as List) Json.from(l as Map)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${lop.str('ten_mon')} · GV ${lop.str('giao_vien_ten')}',
              style: const TextStyle(fontSize: 14, color: AppColors.label),
            ),
            trangThaiChip(tt),
            Text(
              'Sĩ số ${lop.num0('si_so_hien_tai')}/${lop.num0('si_so_toi_da')}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (tt != 'DA_DONG') RowButton('Sửa lớp', _edit),
            if (tt == 'KE_HOACH') RowButton('Mở lớp', () => _openOrClose(true)),
            if (tt == 'DANG_HOC')
              RowButton('Đóng lớp', () => _openOrClose(false), danger: true),
          ],
        ),
        const SizedBox(height: 8),
        Text(switch (tt) {
          'MO' => 'Lớp tự chuyển sang Đang học khi đến ngày bắt đầu. Muốn học sớm hơn, hãy sửa ngày bắt đầu của lớp.',
          'DA_DONG' => 'Lớp đã đóng — điểm danh và nhập điểm đã bị khóa.',
          _ => '',
        }, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(child: Text('Lịch học', style: sectionTitleStyle)),
            if (tt != 'DA_DONG') RowButton('Thêm buổi học', _addSchedule),
          ],
        ),
        const SizedBox(height: 8),
        if (lich.isEmpty)
          const Text(
            'Lớp chưa có lịch học.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
          ),
        for (final l in lich)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(
                    _thuText(l.num0('thu')),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Tiết ${l.num0('tiet_bat_dau')}–${l.num0('tiet_ket_thuc')} · ${_buoiText(l.str('buoi'))}',
                  ),
                ),
                Text(l.str('phong'), style: monoStyle),
                if (tt != 'DA_DONG')
                  IconButton(
                    tooltip: 'Xóa buổi học',
                    onPressed: () => _removeSchedule(l),
                    icon: const Icon(Icons.close, size: 18),
                  ),
              ],
            ),
          ),
        if (lich.isNotEmpty) ...[
          const SizedBox(height: 12),
          _WeekGrid(lich, key: const ValueKey('week-grid')),
        ],
        const SizedBox(height: 18),
        const Text('Hạn nhập điểm', style: sectionTitleStyle),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                lop['han_nhap_diem'] == null
                    ? '${formatYmd(lop.str('han_nhap_diem_hieu_luc'))} (mặc định, sau khi lớp kết thúc)'
                    : formatYmd(lop.str('han_nhap_diem_hieu_luc')),
              ),
            ),
            if (tt != 'DA_DONG') RowButton('Gia hạn nhập điểm', _extend),
          ],
        ),
      ],
    );
  }
}

/// Lưới tuần: cột Thứ 2 → Chủ nhật, hàng tiết 1–15; ô xanh = tiết lớp này có học (kèm phòng).
class _WeekGrid extends StatelessWidget {
  const _WeekGrid(this.lich, {super.key});

  final List<Json> lich;

  static const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  /// Phòng nếu `tiet` của `thu` là tiết đầu của một buổi; '' nếu chỉ nằm giữa; null nếu trống.
  String? _cell(int thu, int tiet) {
    for (final l in lich) {
      if (l.num0('thu') == thu &&
          tiet >= l.num0('tiet_bat_dau') &&
          tiet <= l.num0('tiet_ket_thuc')) {
        return tiet == l.num0('tiet_bat_dau') ? l.str('phong') : '';
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget head(String t) => Expanded(
      child: Center(
        child: Text(
          t,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.muted,
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Lưới tuần của lớp',
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: 44),
              for (final d in _days) head(d),
            ],
          ),
          for (var tiet = 1; tiet <= 15; tiet++)
            Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    'Tiết $tiet',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                for (var thu = 2; thu <= 8; thu++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final c = _cell(thu, tiet);
                        return Container(
                          height: 20,
                          margin: const EdgeInsets.all(1),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: c == null
                                ? const Color(0xFFF4F5FA)
                                : const Color(0xFFC5CAE9),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: c == null || c.isEmpty
                              ? null
                              : Text(
                                  c,
                                  overflow: TextOverflow.clip,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
