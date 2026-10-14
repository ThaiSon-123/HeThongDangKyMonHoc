import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../shared/widgets/app_button.dart';
import '../training/classes_screen.dart' show hocKyLabel;
import '../training/curriculums_screen.dart' show khoiKienThuc;
import '../training/entity_form.dart';
import '../training/resource_list.dart';
import '../training/training_api.dart';
import '../training/training_widgets.dart';
import 'money.dart';

const _configPath = '/tuition/config/';
const _pricingPath = '/tuition/pricing/';
const _discountPath = '/tuition/discounts/';

String _svLabel(Json s) => '${s.str('ho_ten')} (${s.str('ma_sv')})';

/// Cấu hình học phí (KT-01..05) — mockup `KT-Web-CauHinh`: hạn đóng, đơn giá tín chỉ, miễn giảm / học bổng.
class TuitionConfigScreen extends ConsumerStatefulWidget {
  const TuitionConfigScreen({super.key});

  @override
  ConsumerState<TuitionConfigScreen> createState() =>
      _TuitionConfigScreenState();
}

class _TuitionConfigScreenState extends ConsumerState<TuitionConfigScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TabsRow(
          labels: const ['Hạn đóng', 'Đơn giá', 'Miễn giảm / học bổng'],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 20),
        switch (_tab) {
          0 => const _HanDong(),
          1 => const _DonGia(),
          _ => const _MienGiam(),
        },
      ],
    ),
  );
}

// ---------------------------------------------------------------- hạn đóng
class _HanDong extends ConsumerStatefulWidget {
  const _HanDong();

  @override
  ConsumerState<_HanDong> createState() => _HanDongState();
}

class _HanDongState extends ConsumerState<_HanDong> {
  final _ctl = ResourceListController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _specs = <FieldSpec>[
    SelectSpec(
      'hoc_ky',
      'Học kỳ',
      '/semesters/',
      hocKyLabel,
      lockedOnEdit: true,
    ),
    DateSpec('han_dong', 'Hạn đóng'),
    TextSpec('ghi_chu', 'Ghi chú', required: false),
  ];

  Future<void> _form([Json? row]) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Thêm hạn đóng' : 'Hạn đóng — ${row.str('ten_hk')}',
      saveLabel: 'Lưu hạn đóng',
      note: 'Mỗi học kỳ có một hạn đóng học phí. Sau hạn, sinh viên còn nợ được tính là quá hạn.',
      specs: _specs,
      initial: row,
      initialSelected: row == null
          ? const {}
          : {
              'hoc_ky': {'id': row['hoc_ky'], 'ten_hk': row['ten_hk']},
            },
      submit: (body) async => row == null
          ? api.create(_configPath, body)
          : api.update(_configPath, row.id, body),
    );
    if (saved && mounted) _ctl.reload();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListToolbar(children: [AddButton('+ Thêm hạn đóng', _form)]),
      const SizedBox(height: 24),
      ResourceList(
        controller: _ctl,
        path: _configPath,
        minWidth: 640,
        emptyText: 'Chưa có hạn đóng nào.',
        columns: const [
          ListColumn('Học kỳ', flex: 2),
          ListColumn('Hạn đóng', width: 140),
          ListColumn('Ghi chú', flex: 3),
          ListColumn('', width: 90),
        ],
        cells: (r) => [
          Text(
            r.str('ten_hk'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(formatYmd(r.str('han_dong'))),
          Text(
            r.str('ghi_chu').isEmpty ? '—' : r.str('ghi_chu'),
            overflow: TextOverflow.ellipsis,
          ),
          RowActions([RowButton('Sửa', () => _form(r))]),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------- đơn giá
class _DonGia extends ConsumerStatefulWidget {
  const _DonGia();

  @override
  ConsumerState<_DonGia> createState() => _DonGiaState();
}

class _DonGiaState extends ConsumerState<_DonGia> {
  final _ctl = ResourceListController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _phamVi = {
    'MAC_DINH': 'Mặc định',
    'KHOI_KIEN_THUC': 'Khối kiến thức',
    'NGANH': 'Ngành',
    'GIA_TH': 'Thực hành',
  };

  List<FieldSpec> _specs(String phamVi) => [
    const SelectSpec(
      'hoc_ky',
      'Học kỳ',
      '/semesters/',
      hocKyLabel,
      required: false,
      lockedOnEdit: true,
      helper: 'Để trống = áp dụng cho mọi học kỳ.',
    ),
    if (phamVi == 'NGANH')
      const TextSpec(
        'tham_chieu',
        'Mã ngành',
        lockedOnEdit: true,
        hint: 'VD: CNTT',
        half: true,
      ),
    if (phamVi == 'KHOI_KIEN_THUC')
      ChoiceSpec(
        'tham_chieu',
        'Khối kiến thức',
        khoiKienThuc,
        lockedOnEdit: true,
        half: true,
      ),
    const TextSpec(
      'don_gia',
      'Đơn giá mỗi tín chỉ (₫)',
      number: true,
      half: true,
    ),
  ];

  Future<void> _form(String phamVi, [Json? row]) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null ? 'Thêm đơn giá — ${_phamVi[phamVi]}' : 'Sửa đơn giá',
      note:
          'Cách tra giá: ưu tiên đơn giá của chính học kỳ, sau đó đơn giá chung. Trong mỗi nhóm: theo khối '
          'kiến thức, rồi theo ngành, rồi mặc định. Tín chỉ thực hành tính theo đơn giá thực hành nếu có.',
      specs: _specs(phamVi),
      initial: row,
      initialSelected: row == null || row['hoc_ky'] == null
          ? const {}
          : {
              'hoc_ky': {'id': row['hoc_ky'], 'ten_hk': row['ten_hk']},
            },
      submit: (body) async => row == null
          ? api.create(_pricingPath, {...body, 'pham_vi': phamVi})
          : api.update(_pricingPath, row.id, body),
    );
    if (saved && mounted) _ctl.reload();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListToolbar(
        children: [
          FilterDropdown(
            controller: _ctl,
            filterKey: 'pham_vi',
            label: 'Phạm vi',
            options: [
              ('', 'Tất cả'),
              for (final e in _phamVi.entries) (e.key, e.value),
            ],
          ),
          for (final e in _phamVi.entries)
            SizedBox(
              width: 190,
              child: AppButton(
                label: '+ Giá ${e.value.toLowerCase()}',
                height: 44,
                outlined: e.key != 'MAC_DINH',
                onPressed: () => _form(e.key),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      ResourceList(
        controller: _ctl,
        path: _pricingPath,
        minWidth: 760,
        emptyText: 'Chưa cấu hình đơn giá — chưa tính được học phí.',
        columns: const [
          ListColumn('Học kỳ', flex: 2),
          ListColumn('Phạm vi', width: 140),
          ListColumn('Áp dụng cho', flex: 2),
          ListColumn('Đơn giá / tín chỉ', width: 160),
          ListColumn('', width: 160),
        ],
        cells: (r) => [
          Text(r['hoc_ky'] == null ? 'Mọi học kỳ' : r.str('ten_hk')),
          Text(_phamVi[r.str('pham_vi')] ?? r.str('pham_vi')),
          Text(r.str('tham_chieu').isEmpty ? '—' : r.str('tham_chieu')),
          Text(
            formatVnd(r['don_gia']),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          RowActions([
            RowButton('Sửa', () => _form(r.str('pham_vi'), r)),
            RowButton(
              'Xóa',
              () => confirmAndRun(
                context,
                title: 'Xóa đơn giá?',
                message: 'Xóa đơn giá này? Học phí đã tính không đổi cho đến khi tính lại.',
                actionLabel: 'Xóa',
                call: () =>
                    ref.read(trainingApiProvider).delete(_pricingPath, r.id),
                success: 'Đã xóa đơn giá.',
                onDone: _ctl.reload,
              ),
              danger: true,
            ),
          ]),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------- miễn giảm
class _MienGiam extends ConsumerStatefulWidget {
  const _MienGiam();

  @override
  ConsumerState<_MienGiam> createState() => _MienGiamState();
}

class _MienGiamState extends ConsumerState<_MienGiam> {
  final _ctl = ResourceListController();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  static const _loai = <(Object, String)>[
    ('MIEN_GIAM', 'Miễn giảm'),
    ('HOC_BONG', 'Học bổng'),
  ];

  static const _specs = <FieldSpec>[
    SelectSpec(
      'sinh_vien',
      'Sinh viên',
      '/tuition/students/',
      _svLabel,
      lockedOnEdit: true,
    ),
    SelectSpec(
      'hoc_ky',
      'Học kỳ',
      '/semesters/',
      hocKyLabel,
      lockedOnEdit: true,
      half: true,
    ),
    ChoiceSpec('loai', 'Loại', _loai, half: true),
    TextSpec(
      'so_tien',
      'Số tiền (₫)',
      number: true,
      required: false,
      half: true,
      helper: 'Nhập số tiền HOẶC tỷ lệ.',
    ),
    TextSpec('ty_le', 'Tỷ lệ (%)', number: true, required: false, half: true),
    TextSpec('ly_do', 'Lý do', required: false),
  ];

  Future<void> _form([Json? row]) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: row == null
          ? 'Thêm miễn giảm / học bổng'
          : 'Sửa miễn giảm / học bổng',
      note: 'Tổng miễn giảm của một sinh viên không vượt quá tổng tiền học phí. Mọi thay đổi được ghi nhật ký.',
      specs: _specs,
      initial: row,
      initialSelected: row == null
          ? const {}
          : {
              'sinh_vien': {
                'id': row['sinh_vien'],
                'ho_ten': row['ho_ten'],
                'ma_sv': row['ma_sv'],
              },
              'hoc_ky': {'id': row['hoc_ky'], 'ten_hk': row['ten_hk']},
            },
      submit: (body) async => row == null
          ? api.create(_discountPath, body)
          : api.update(_discountPath, row.id, body),
    );
    if (saved && mounted) _ctl.reload();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ListToolbar(
        children: [
          SearchBox(
            controller: _ctl,
            label: 'Tìm sinh viên',
            hint: 'Mã SV hoặc họ tên',
          ),
          AddButton('+ Thêm miễn giảm / học bổng', _form),
        ],
      ),
      const SizedBox(height: 24),
      ResourceList(
        controller: _ctl,
        path: _discountPath,
        minWidth: 820,
        emptyText: 'Chưa có miễn giảm hoặc học bổng nào.',
        columns: const [
          ListColumn('Sinh viên', flex: 2),
          ListColumn('Học kỳ', flex: 2),
          ListColumn('Loại', width: 120),
          ListColumn('Giá trị', width: 130),
          ListColumn('Lý do', flex: 2),
          ListColumn('', width: 160),
        ],
        cells: (r) => [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.str('ho_ten'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(r.str('ma_sv'), style: const TextStyle(fontSize: 11)),
            ],
          ),
          Text(r.str('ten_hk')),
          Text(r.str('loai') == 'HOC_BONG' ? 'Học bổng' : 'Miễn giảm'),
          Text(
            r['so_tien'] != null
                ? formatVnd(r['so_tien'])
                : '${double.tryParse(r.str('ty_le'))?.toStringAsFixed(0)}%',
          ),
          Text(
            r.str('ly_do').isEmpty ? '—' : r.str('ly_do'),
            overflow: TextOverflow.ellipsis,
          ),
          RowActions([
            RowButton('Sửa', () => _form(r)),
            RowButton(
              'Xóa',
              () => confirmAndRun(
                context,
                title: 'Xóa miễn giảm?',
                message:
                    'Xóa khoản này của ${r.str('ho_ten')}? Học phí phải nộp sẽ tăng tương ứng.',
                actionLabel: 'Xóa',
                call: () =>
                    ref.read(trainingApiProvider).delete(_discountPath, r.id),
                success: 'Đã xóa miễn giảm.',
                onDone: _ctl.reload,
              ),
              danger: true,
            ),
          ]),
        ],
      ),
    ],
  );
}
