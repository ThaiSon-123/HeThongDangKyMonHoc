import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/status_chip.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import '../training/entity_form.dart';
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../dashboard/dashboard_widgets.dart' show soNgayDen;
import '../registration/timetable_screen.dart' show clockProvider;
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
    final compact = isCompact(context);
    final han = d['han_nhap_diem'] == null ? '' : d.str('han_nhap_diem');
    final con = han.isEmpty ? null : soNgayDen(han, ref.read(clockProvider)());
    final thieuCk = _rows.where((r) => r.editable && r.ck.text.trim().isEmpty);
    final ghiChuDuoi = widget.isPdt
        ? 'Hiển thị ${_rows.length} sinh viên. Duyệt luôn áp dụng cho cả lớp — không duyệt lẻ từng sinh viên.'
        : thieuCk.isNotEmpty && nhap
        ? '${thieuCk.length} sinh viên chưa có điểm cuối kỳ — khi khóa sẽ tính CK = 0.'
        : 'Hiển thị ${_rows.length} sinh viên · Ô trống = chưa nhập (khác với điểm 0).';
    final nut = <Widget>[
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
          width: 140,
          child: AppButton(
            label: 'Gia hạn',
            height: 44,
            outlined: true,
            onPressed: () => _extend(d),
          ),
        ),
      if (nhap)
        SizedBox(
          width: widget.isPdt ? 200 : 150,
          child: AppButton(
            label: widget.isPdt ? 'Lưu điểm chính thức' : 'Lưu nháp',
            height: 44,
            outlined: d['co_the_khoa'] == true || widget.isPdt,
            loading: _busy,
            onPressed: _rows.any((r) => r.editable) ? () => _save(d) : null,
          ),
        ),
      if (d['co_the_khoa'] == true)
        SizedBox(
          width: 190,
          child: AppButton(
            label: 'Khóa điểm cả lớp',
            height: 44,
            onPressed: _busy ? null : () => _lock(true),
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
    ];
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 20, 18, 20, 12),
            child: Wrap(
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
                if (con != null)
                  StatusChip.of(
                    con >= 0
                        ? 'Còn $con ngày để nhập điểm'
                        : 'Đã quá hạn nhập điểm',
                    con >= 0 ? StatusChip.gray : StatusChip.red,
                  ),
                Text(
                  'Hạn nhập điểm ${formatYmd(han)}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
          if (!widget.isPdt && d['qua_han'] == true)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AlertBanner(
                kind: BannerKind.warning,
                title: 'Đã quá hạn nhập điểm.',
                message: 'Liên hệ Phòng đào tạo để gia hạn hoặc nhập hộ.',
              ),
            )
          else if (lopDong)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AlertBanner(
                kind: BannerKind.info,
                message: widget.isPdt
                    ? 'Lớp đã đóng — duyệt điểm cả lớp khi mọi sinh viên đã có điểm chính thức.'
                    : 'Lớp đã đóng — điểm đã khóa, chờ Phòng đào tạo duyệt.',
              ),
            )
          else if (!nhap)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: AlertBanner(
                kind: BannerKind.info,
                message: 'Chỉ nhập điểm khi lớp đang học.',
              ),
            ),
          if (_rows.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Text(
                'Chưa có sinh viên đăng ký lớp.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else if (compact)
            for (final r in _rows) _rowCompact(r, nhap, datKhongDat)
          else
            _bang(nhap, datKhongDat),
          Container(
            padding: EdgeInsets.fromLTRB(compact ? 16 : 20, 12, 20, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ghiChuDuoi,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(spacing: 10, runSpacing: 10, children: nut),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: Text(
                          ghiChuDuoi,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                      Wrap(spacing: 10, runSpacing: 10, children: nut),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ giá trị xem trước một dòng
  int? _tongKet(_Row r) => r.editable
      ? tinhTongKet(
          parseScore(r.qt.text).value,
          parseScore(r.gk.text).value,
          parseScore(r.ck.text).value,
        )
      : scoreFromApi(r.json['diem_tong_ket']);

  String _chu(_Row r, int? tong, bool datKhongDat) => r.editable
      ? xepLoai(tong, datKhongDat: datKhongDat).$1
      : r.json.str('diem_chu');

  Widget _chuChip(String chu) {
    if (chu.isEmpty) return const Text('—');
    return StatusChip.of(chu, switch (chu[0]) {
      'A' || 'B' || 'P' => StatusChip.green,
      'F' => StatusChip.red,
      _ => StatusChip.yellow,
    });
  }

  Widget _o(
    TextEditingController c,
    bool enabled, {
    bool compact = false,
  }) => TextField(
    controller: c,
    enabled: enabled,
    textAlign: TextAlign.center,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: (_) => setState(() {}),
    decoration: InputDecoration(
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      // Ô sai định dạng: viền đỏ + chú thích ngắn dưới bảng (không làm lệch hàng).
      errorText: parseScore(c.text).invalid ? (compact ? '0–10' : '') : null,
      errorStyle: compact ? null : const TextStyle(height: 0, fontSize: 0),
    ),
  );

  // ------------------------------------------------------------ bảng (Web)
  Widget _bang(bool nhap, bool datKhongDat) {
    const dau = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
      letterSpacing: 0.3,
    );
    Widget h(String t, {bool giua = false}) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Text(t, style: dau, textAlign: giua ? TextAlign.center : null),
    );
    Widget o(Widget w) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: w,
    );
    final coLoi = _rows.any((r) => r.editable && r.invalid);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(2.6),
            2: FlexColumnWidth(1.1),
            3: FlexColumnWidth(1.1),
            4: FlexColumnWidth(1.1),
            5: FlexColumnWidth(1.2),
            6: FlexColumnWidth(0.9),
            7: FlexColumnWidth(1.4),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: AppColors.divider),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F8FC),
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppColors.divider),
                ),
              ),
              children: [
                h('MÃ SV'),
                h('HỌ TÊN'),
                h('QT (10%)', giua: true),
                h('GK (40%)', giua: true),
                h('CK (50%)', giua: true),
                h('TỔNG KẾT', giua: true),
                h('CHỮ', giua: true),
                h('TRẠNG THÁI', giua: true),
              ],
            ),
            for (final r in _rows) _hangBang(r, nhap, datKhongDat, o),
          ],
        ),
        if (coLoi)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Ô viền đỏ sai định dạng: nhập số từ 0 đến 10, tối đa 2 chữ số thập phân.',
              style: TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
      ],
    );
  }

  TableRow _hangBang(
    _Row r,
    bool nhap,
    bool datKhongDat,
    Widget Function(Widget) o,
  ) {
    final enabled = nhap && r.editable;
    final tong = _tongKet(r);
    final chu = _chu(r, tong, datKhongDat);
    return TableRow(
      key: ValueKey('${r.id}-$_version'),
      children: [
        o(
          Text(
            r.json.str('ma_sv'),
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
        o(
          Text(
            r.json.str('ho_ten'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        o(_o(r.qt, enabled)),
        o(_o(r.gk, enabled)),
        o(_o(r.ck, enabled)),
        o(
          Text(
            tong == null ? '—' : formatScore(tong),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        o(Center(child: _chuChip(chu))),
        o(Center(child: gradeStatusChip(r.trangThai))),
      ],
    );
  }

  // ------------------------------------------------------------ dòng (App)
  Widget _rowCompact(_Row r, bool nhap, bool datKhongDat) {
    final enabled = nhap && r.editable;
    final tong = _tongKet(r);
    final chu = _chu(r, tong, datKhongDat);
    return Container(
      key: ValueKey('${r.id}-$_version'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
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
          const SizedBox(height: 10),
          Row(
            children: [
              for (final (c, nhan) in [
                (r.qt, 'QT 10%'),
                (r.gk, 'GK 40%'),
                (r.ck, 'CK 50%'),
              ]) ...[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nhan,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _o(c, enabled, compact: true),
                    ],
                  ),
                ),
                if (c != r.ck) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                tong == null ? 'Tổng kết —' : 'Tổng kết ${formatScore(tong)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              _chuChip(chu),
              const Spacer(),
              gradeStatusChip(r.trangThai),
            ],
          ),
        ],
      ),
    );
  }
}
