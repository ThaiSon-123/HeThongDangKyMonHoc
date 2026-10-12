import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/status_chip.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import '../training/entity_form.dart';
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import 'grade_calc.dart';

Widget gradeStatusChip(String? trangThai) => switch (trangThai) {
  'NHAP_TAM' => StatusChip.of('Nháp', StatusChip.yellow),
  'CHINH_THUC' => StatusChip.of('Chính thức', StatusChip.indigo),
  'KHOA' => StatusChip.of('Đã khóa', StatusChip.green),
  _ => StatusChip.of('Chưa nhập', StatusChip.gray),
};

class _Row {
  _Row(this.json)
    : qt = TextEditingController(text: _init(json['diem_qua_trinh'])),
      gk = TextEditingController(text: _init(json['diem_giua_ky'])),
      ck = TextEditingController(text: _init(json['diem_cuoi_ky']));

  final Json json;
  final TextEditingController qt, gk, ck;

  static String _init(Object? v) {
    final h = scoreFromApi(v);
    return h == null ? '' : formatScore(h);
  }

  int get id => json.num0('sinh_vien');
  String? get trangThai => json['trang_thai'] as String?;
  bool get editable => trangThai == null || trangThai == 'NHAP_TAM';

  bool get invalid => [qt, gk, ck].any((c) => parseScore(c.text).invalid);

  void dispose() {
    qt.dispose();
    gk.dispose();
    ck.dispose();
  }
}

/// Bảng điểm cả lớp dùng chung cho GV (nhập, khóa/mở khóa — mockup `Web-NhapDiem`) và PĐT (nhập hộ,
/// gia hạn, duyệt cả lớp — mockup `PDT-Web-DuyetDiem`). Tổng kết/điểm chữ xem trước ngay khi gõ (BR-10/11).
class GradeSheetPanel extends ConsumerStatefulWidget {
  const GradeSheetPanel({
    super.key,
    required this.lopId,
    required this.isPdt,
    this.onChanged,
  });

  final int lopId;
  final bool isPdt;
  final VoidCallback? onChanged;

  @override
  ConsumerState<GradeSheetPanel> createState() => _GradeSheetPanelState();
}

class _GradeSheetPanelState extends ConsumerState<GradeSheetPanel> {
  late Future<Json> _future = _fetch();
  List<_Row> _rows = [];
  bool _busy = false;
  int _version = 0; // đổi sau mỗi lần tải lại để dựng lại ô nhập

  String get _path => '/class-sections/${widget.lopId}/grades/';

  Future<Json> _fetch() async {
    final d = await ref.read(trainingApiProvider).get(_path);
    for (final r in _rows) {
      r.dispose();
    }
    _rows = [for (final r in d['records'] as List) _Row(Json.from(r as Map))];
    _version++;
    return d;
  }

  void _reload() {
    final next = _fetch();
    setState(() {
      _future = next;
    });
    widget.onChanged?.call();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _run(
    Future<Object?> Function() call,
    String ok, {
    bool reload = true,
  }) async {
    setState(() => _busy = true);
    try {
      await call();
      if (mounted) showAppToast(context, ok);
      if (reload) _reload();
    } on ApiFailure catch (f) {
      if (mounted) {
        showAppToast(
          context,
          failureText(f, 'Không thực hiện được, vui lòng thử lại.'),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _dec(String text) {
    final v = parseScore(text).value;
    return v == null ? null : formatScore(v);
  }

  Future<void> _save(Json d) async {
    final editable = _rows.where((r) => r.editable).toList();
    if (editable.any((r) => r.invalid)) {
      showAppToast(
        context,
        'Có ô điểm sai định dạng (0–10, tối đa 2 chữ số thập phân).',
      );
      return;
    }
    await _run(
      () => ref.read(trainingApiProvider).put(_path, {
        'records': [
          for (final r in editable)
            {
              'sinh_vien': r.id,
              'diem_qua_trinh': _dec(r.qt.text),
              'diem_giua_ky': _dec(r.gk.text),
              'diem_cuoi_ky': _dec(r.ck.text),
            },
        ],
      }),
      widget.isPdt ? 'Đã lưu điểm chính thức (nhập hộ).' : 'Đã lưu điểm nháp.',
    );
  }

  Future<void> _lock(bool lock) => _run(
    () => ref.read(trainingApiProvider).create('${_path}lock/', {
      'action': lock ? 'lock' : 'unlock',
    }),
    lock ? 'Đã khóa điểm cả lớp.' : 'Đã mở khóa điểm cả lớp.',
  );

  Future<void> _approve(Json d) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Duyệt điểm cả lớp?',
      message:
          'Duyệt ${_rows.length} sinh viên của lớp ${d.str('ma_lop')}? Sau khi duyệt, điểm không sửa được nữa; '
          'GPA và tín chỉ tích lũy được cập nhật và sinh viên nhận thông báo.',
      actionLabel: 'Duyệt cả lớp',
    );
    if (!ok || !mounted) return;
    await _run(
      () => ref.read(trainingApiProvider).create('${_path}approve/', {}),
      'Đã duyệt điểm cả lớp.',
    );
  }

  Future<void> _extend(Json d) async {
    final api = ref.read(trainingApiProvider);
    final saved = await showEntityForm(
      context,
      title: 'Gia hạn nhập điểm',
      saveLabel: 'Gia hạn',
      note:
          'Hạn mới phải sau hạn hiện tại (${formatYmd(d.str('han_nhap_diem'))}). Giáo viên có thể nhập điểm lại đến hạn mới.',
      specs: const [DateSpec('han_nhap_diem', 'Hạn mới')],
      submit: (body) =>
          api.action('/class-sections/', widget.lopId, 'grade-deadline', body),
    );
    if (saved && mounted) {
      showAppToast(context, 'Đã gia hạn nhập điểm.');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      return _body(d);
    },
  );

  Widget _body(Json d) {
    final nhap = d['co_the_nhap'] == true;
    final datKhongDat = d.str('loai_danh_gia') == 'DAT_KHONG_DAT';
    final lopDong = d.str('lop_trang_thai') == 'DA_DONG';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${d.str('ma_lop')} · ${d.str('ten_mon')}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Text(
                'Hạn nhập điểm ${formatYmd(d.str('han_nhap_diem'))}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
          if (!widget.isPdt && d['qua_han'] == true) ...[
            const SizedBox(height: 10),
            const AlertBanner(
              kind: BannerKind.warning,
              title: 'Đã quá hạn nhập điểm.',
              message: 'Liên hệ Phòng đào tạo để gia hạn hoặc nhập hộ.',
            ),
          ] else if (lopDong) ...[
            const SizedBox(height: 10),
            AlertBanner(
              kind: BannerKind.info,
              message: widget.isPdt
                  ? 'Lớp đã đóng — duyệt điểm cả lớp khi mọi sinh viên đã có điểm chính thức.'
                  : 'Lớp đã đóng — điểm đã khóa, chờ Phòng đào tạo duyệt.',
            ),
          ] else if (!nhap) ...[
            const SizedBox(height: 10),
            const AlertBanner(
              kind: BannerKind.info,
              message: 'Chỉ nhập điểm khi lớp đang học.',
            ),
          ],
          const SizedBox(height: 12),
          if (_rows.isEmpty)
            const Text(
              'Chưa có sinh viên đăng ký lớp.',
              style: TextStyle(color: AppColors.muted),
            ),
          for (final r in _rows) _rowView(r, nhap, datKhongDat),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (nhap)
                SizedBox(
                  width: 190,
                  child: AppButton(
                    label: widget.isPdt ? 'Lưu điểm chính thức' : 'Lưu nháp',
                    height: 44,
                    loading: _busy,
                    onPressed: _rows.any((r) => r.editable)
                        ? () => _save(d)
                        : null,
                  ),
                ),
              if (d['co_the_khoa'] == true)
                SizedBox(
                  width: 150,
                  child: AppButton(
                    label: 'Khóa điểm',
                    height: 44,
                    outlined: true,
                    onPressed: _busy ? null : () => _lock(true),
                  ),
                ),
              if (d['co_the_mo_khoa'] == true)
                SizedBox(
                  width: 150,
                  child: AppButton(
                    label: 'Mở khóa',
                    height: 44,
                    outlined: true,
                    onPressed: _busy ? null : () => _lock(false),
                  ),
                ),
              if (widget.isPdt && !lopDong)
                SizedBox(
                  width: 150,
                  child: AppButton(
                    label: 'Gia hạn',
                    height: 44,
                    outlined: true,
                    onPressed: () => _extend(d),
                  ),
                ),
              if (widget.isPdt && d['co_the_duyet'] == true)
                SizedBox(
                  width: 170,
                  child: AppButton(
                    label: 'Duyệt cả lớp',
                    height: 44,
                    onPressed: _busy ? null : () => _approve(d),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hiển thị ${_rows.length} sinh viên. Duyệt luôn áp dụng cho cả lớp — không duyệt lẻ từng sinh viên.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label, bool enabled) =>
      SizedBox(
        width: 84,
        child: TextField(
          controller: c,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            errorText: parseScore(c.text).invalid ? '0–10' : null,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );

  Widget _rowView(_Row r, bool nhap, bool datKhongDat) {
    final enabled = nhap && r.editable;
    final tong = r.editable
        ? tinhTongKet(
            parseScore(r.qt.text).value,
            parseScore(r.gk.text).value,
            parseScore(r.ck.text).value,
          )
        : scoreFromApi(r.json['diem_tong_ket']);
    final (chu, _) = r.editable
        ? xepLoai(tong, datKhongDat: datKhongDat)
        : (r.json.str('diem_chu'), null);
    return Container(
      key: ValueKey('${r.id}-$_version'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 190,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.json.str('ho_ten'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  r.json.str('ma_sv'),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
          _field(r.qt, 'QT (10%)', enabled),
          _field(r.gk, 'GK (40%)', enabled),
          _field(r.ck, 'CK (50%)', enabled),
          SizedBox(
            width: 120,
            child: Text(
              tong == null
                  ? 'Tổng kết —'
                  : 'Tổng kết ${formatScore(tong)} · $chu',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          gradeStatusChip(r.trangThai),
        ],
      ),
    );
  }
}
