import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/labeled_field.dart';
import '../../shared/widgets/status_chip.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import '../reports/report_widgets.dart' show lapDayColor;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import 'attendance_format.dart';
import 'proof_picker.dart';

const _requestsPath = '/attendance/requests/';

class _Data {
  _Data(this.my, this.requests);

  final Json my;
  final List<Json> requests;

  List<Json> get lop => [
    for (final l in my['lop_hoc_phan'] as List) Json.from(l as Map),
  ];
}

/// Điểm danh của sinh viên (SV-10) — mockup `SV-Web-DiemDanh` / `SV-App-DiemDanh`: chọn lớp →
/// thống kê tỷ lệ vắng + cờ, từng buổi, xin sửa điểm danh (lý do + minh chứng tùy chọn).
class StudentAttendanceScreen extends ConsumerStatefulWidget {
  const StudentAttendanceScreen({super.key});

  @override
  ConsumerState<StudentAttendanceScreen> createState() =>
      _StudentAttendanceScreenState();
}

class _StudentAttendanceScreenState
    extends ConsumerState<StudentAttendanceScreen> {
  late Future<_Data> _data = _fetch();
  int? _hocKy; // null = học kỳ mặc định của hệ thống
  int? _lopId;
  int _tab = 0;
  Json? _buoi;

  Future<_Data> _fetch() async {
    final api = ref.read(trainingApiProvider);
    final my = await api.get('/attendance/my/', query: {'hoc_ky': _hocKy});
    final requests = await api.listAll(_requestsPath);
    return _Data(my, requests);
  }

  void _reload() {
    final next = _fetch();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_Data>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) {
        final f = snap.error;
        if (f is ApiFailure && f.fields.containsKey('hoc_ky')) {
          return const AlertBanner(
            kind: BannerKind.warning,
            message: 'Chưa có học kỳ nào đang diễn ra.',
          );
        }
        return ListErrorCard(onRetry: _reload);
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final lop = d.lop;
      final hocKy = [
        for (final h in (d.my['cac_hoc_ky'] as List? ?? const []))
          Json.from(h as Map),
      ];
      final cur = lop
          .where((l) => l.num0('lop_hoc_phan') == _lopId)
          .firstOrNull;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Card(
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  // Chọn xem điểm danh của học kỳ khác (chỉ hiện khi có đăng ký ở từ 2 kỳ).
                  if (hocKy.length > 1)
                    SizedBox(
                      width: isCompact(context) ? double.infinity : 300,
                      child: LabeledDropdown<int>(
                        label: 'Học kỳ',
                        value: d.my.num0('hoc_ky'),
                        options: [
                          for (final h in hocKy)
                            (h.num0('id'), h.str('ten_hk')),
                        ],
                        onChanged: (v) {
                          _hocKy = v;
                          _lopId = null;
                          _buoi = null;
                          _tab = 0;
                          _reload();
                        },
                      ),
                    )
                  else
                    Text(
                      d.my.str('ten_hk'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.navy,
                      ),
                    ),
                  SizedBox(
                    width: isCompact(context) ? double.infinity : 360,
                    child: LabeledDropdown<int?>(
                      label: 'Lớp đã đăng ký',
                      value: _lopId,
                      options: [
                        (null, '— Chọn lớp —'),
                        for (final l in lop)
                          (
                            l.num0('lop_hoc_phan'),
                            '${l.str('ma_lop')} · ${l.str('ten_mon')}',
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _lopId = v;
                        _buoi = null;
                        _tab = 0;
                      }),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (lop.isEmpty)
              const _Hint(
                'Bạn chưa đăng ký lớp nào',
                'Hãy đăng ký môn học để xem điểm danh.',
              )
            else if (cur == null)
              const _Hint(
                'Chọn lớp để xem thống kê điểm danh',
                'Số liệu và danh sách buổi học sẽ hiện sau khi bạn chọn lớp.',
              )
            else
              _lopView(d, cur),
          ],
        ),
      );
    },
  );

  Widget _lopView(_Data d, Json lop) {
    final yeuCau = d.requests
        .where((r) => r.num0('lop_hoc_phan') == lop.num0('lop_hoc_phan'))
        .toList();
    return _lopViewCard(d, lop, yeuCau);
  }

  // ------------------------------------------------------------ bố cục (mockup SV-Web-DiemDanh; App xếp 3 ô/hàng)
  Widget _lopViewCard(_Data d, Json lop, List<Json> yeuCau) {
    final buoi = [for (final e in lop['buoi'] as List) Json.from(e as Map)];
    final compact = isCompact(context);
    final le = compact ? 16.0 : 22.0;
    Widget tab(int i, String nhan) {
      final chon = _tab == i;
      final o = InkWell(
        onTap: () => setState(() => _tab = i),
        child: Container(
          alignment: compact ? Alignment.center : null,
          padding: EdgeInsets.symmetric(horizontal: le, vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: chon ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            nhan,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: chon ? AppColors.primary : AppColors.muted,
            ),
          ),
        ),
      );
      return compact ? Expanded(child: o) : o;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stats(d, lop, buoi),
        const SizedBox(height: 16),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppColors.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    tab(
                      0,
                      compact
                          ? 'Các buổi (${buoi.length})'
                          : 'Các buổi học (${buoi.length})',
                    ),
                    tab(
                      1,
                      compact
                          ? 'Yêu cầu (${yeuCau.length})'
                          : 'Yêu cầu sửa đã gửi (${yeuCau.length})',
                    ),
                  ],
                ),
              ),
              if (_tab == 0)
                for (final b in buoi) ...[
                  _buoiRow(b),
                  // Chi tiết mở ngay dưới buổi vừa bấm (bấm lại để đóng).
                  if (_buoi?.num0('session') == b.num0('session'))
                    Container(
                      color: const Color(0xFFF7F8FC),
                      padding: EdgeInsets.all(compact ? 8 : 16),
                      child: _detail(lop, _buoi!, d.my.num0('so_ngay_xin_sua')),
                    ),
                ]
              else if (yeuCau.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Bạn chưa gửi yêu cầu sửa điểm danh nào ở lớp này.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [for (final r in yeuCau) _requestCard(r)],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buoiRow(Json b) {
    final le = isCompact(context) ? 16.0 : 22.0;
    final selected = _buoi?.num0('session') == b.num0('session');
    final yc = b['yeu_cau'] == null ? null : Json.from(b['yeu_cau'] as Map);
    return InkWell(
      onTap: () => setState(() => _buoi = selected ? null : b),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: le, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEEF0FA) : null,
          border: const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ngayDayDu(b.str('ngay_hoc')),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    buoiTiet(b),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 6,
              children: [
                if (yc != null && yc.str('trang_thai') == 'CHO_DUYET')
                  StatusChip.of('Chờ duyệt', StatusChip.yellow),
                diemDanhChip(b['trang_thai'] as String?, b['di_tre'] == true),
              ],
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: AppColors.muted,
            ),
          ],
        ),
      ),
    );
  }

  /// Thống kê lớp: 6 ô số liệu + thanh tỷ lệ vắng không phép so với ngưỡng cờ (design.md SV-10).
  Widget _stats(_Data d, Json lop, List<Json> buoi) {
    final tong = lop.num0('tong_so_buoi');
    final kp = lop.num0('so_vang_kp');
    final pct = d.my.num0('max_absent_pct');
    final conLai = lop.num0('so_buoi_vang_cho_phep') - kp;
    final nguong =
        tong * pct / 100; // số buổi vắng không phép tối đa (có thể lẻ, vd 8,4)
    final tiLe = nguong > 0 ? kp / nguong : (kp > 0 ? 1.0 : 0.0);
    final daDiemDanh = buoi.where((b) => b['trang_thai'] != null).length;
    const nau = Color(0xFFB26A00);
    final compact = isCompact(context);
    Widget o(String nhan, int v, {Color mau = AppColors.navy}) => Expanded(
      child: Container(
        padding: EdgeInsets.fromLTRB(
          compact ? 10 : 16,
          12,
          compact ? 10 : 16,
          12,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                nhan,
                maxLines: 1,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$v',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: mau,
              ),
            ),
          ],
        ),
      ),
    );
    const cach = SizedBox(width: 12);
    final tiles = [
      o('Tổng số buổi', tong),
      o('Đã điểm danh', daDiemDanh),
      o('Có mặt', lop.num0('so_co_mat'), mau: AppColors.success),
      o('Đi trễ', lop.num0('so_di_tre'), mau: nau),
      o('Vắng có phép', lop.num0('so_vang_co_phep'), mau: nau),
      o('Vắng không phép', kp, mau: AppColors.danger),
    ];
    Widget hang(List<Widget> ts) => Row(
      children: [
        for (final (i, t) in ts.indexed) ...[if (i > 0) cach, t],
      ],
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${lop.str('ma_lop')} · ${lop.str('ten_mon')}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              if (lop['canh_bao_vang'] == true)
                StatusChip.of('Nguy cơ cấm thi', StatusChip.red),
            ],
          ),
          const SizedBox(height: 14),
          if (compact) ...[
            hang(tiles.sublist(0, 3)),
            const SizedBox(height: 12),
            hang(tiles.sublist(3)),
          ] else
            hang(tiles),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tỷ lệ vắng không phép',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$kp/$tong buổi (${(lop['ty_le_vang'] as num).toStringAsFixed(1)}%)',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: tiLe.clamp(0, 1).toDouble(),
              minHeight: 10,
              color: lapDayColor(tiLe * 100),
              backgroundColor: AppColors.divider,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            conLai >= 0
                ? 'Còn được vắng không phép thêm $conLai buổi (ngưỡng $pct%).'
                : 'Đã vượt ngưỡng $pct% số buổi vắng không phép.',
            style: TextStyle(
              fontSize: 13,
              color: conLai >= 0 ? AppColors.muted : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detail(Json lop, Json b, int soNgayXinSua) {
    final yc = b['yeu_cau'] == null ? null : Json.from(b['yeu_cau'] as Map);
    final cho = yc != null && yc.str('trang_thai') == 'CHO_DUYET';
    final dongLop = lop.str('lop_trang_thai') != 'DANG_HOC';
    final chuaDiemDanh = b['trang_thai'] == null;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ngayDayDu(b.str('ngay_hoc')),
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.navy,
            ),
          ),
          Text(
            '${buoiText(b.str('buoi'))} · tiết ${b.num0('tiet_bat_dau')}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('Trạng thái hiện tại: '),
              diemDanhChip(b['trang_thai'] as String?, b['di_tre'] == true),
            ],
          ),
          if (b.str('ghi_chu').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Ghi chú giáo viên: ${b.str('ghi_chu')}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
          const SizedBox(height: 12),
          if (chuaDiemDanh)
            const Text(
              'Buổi chưa diễn ra nên chưa có điểm danh.',
              style: TextStyle(color: AppColors.muted),
            )
          else if (cho)
            const Text(
              'Yêu cầu sửa của bạn đang chờ giáo viên duyệt.',
              style: TextStyle(color: AppColors.muted),
            )
          else if (dongLop)
            const Text(
              'Lớp đã đóng nên không thể gửi yêu cầu sửa điểm danh.',
              style: TextStyle(color: AppColors.muted),
            )
          else if (b['con_han_xin_sua'] == false)
            Text(
              soNgayXinSua == 0
                  ? 'Chỉ được xin sửa điểm danh trong ngày học.'
                  : 'Đã quá hạn xin sửa điểm danh ($soNgayXinSua ngày kể từ buổi học).',
              style: const TextStyle(color: AppColors.muted),
            )
          else
            FilledButton(
              onPressed: () => _openRequest(b),
              child: const Text('Xin sửa điểm danh buổi này'),
            ),
        ],
      ),
    );
  }

  Future<void> _openRequest(Json b) async {
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestDialog(buoi: b),
    );
    if (sent == true && mounted) {
      showAppToast(context, 'Đã gửi yêu cầu. Giáo viên sẽ xem và duyệt.');
      setState(() => _buoi = null);
      _reload();
    }
  }

  Widget _requestCard(Json r) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${ngayDayDu(r.str('ngay_hoc'))} · ${buoiText(r.str('buoi'))}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              donChip(r.str('trang_thai')),
            ],
          ),
          const SizedBox(height: 6),
          Text('Đổi: ${doiText(r)}'),
          Text(
            'Lý do: ${r.str('ly_do')}',
            style: const TextStyle(color: AppColors.label),
          ),
          if (r.str('ghi_chu').isNotEmpty)
            Text(
              'Giáo viên: ${r.str('ghi_chu')}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          Text(
            '${r['minh_chung'] != null ? 'Có minh chứng · ' : ''}Gửi lúc ${formatIso(r.str('ngay_gui'))}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class _RequestDialog extends ConsumerStatefulWidget {
  const _RequestDialog({required this.buoi});

  final Json buoi;

  @override
  ConsumerState<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends ConsumerState<_RequestDialog> {
  static const _options = [
    DiemDanhChon.coMat,
    DiemDanhChon.diTre,
    DiemDanhChon.vangCoPhep,
  ];

  DiemDanhChon? _chon;
  final _lyDo = TextEditingController();
  PickedProof? _file;
  String? _errChon, _errLyDo, _banner;
  bool _loading = false;

  @override
  void dispose() {
    _lyDo.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final f = await ref.read(proofPickerProvider)();
    if (f == null || !mounted) return;
    if (f.bytes.length > maxProofBytes) {
      setState(() => _banner = 'Minh chứng tối đa 5 MB.');
      return;
    }
    setState(() {
      _file = f;
      _banner = null;
    });
  }

  Future<void> _send() async {
    setState(() {
      _errChon = _chon == null ? 'Vui lòng chọn trạng thái mong muốn.' : null;
      _errLyDo = _lyDo.text.trim().isEmpty ? 'Vui lòng nhập lý do.' : null;
    });
    if (_errChon != null || _errLyDo != null) return;
    setState(() {
      _loading = true;
      _banner = null;
    });
    try {
      await ref
          .read(trainingApiProvider)
          .createForm(
            _requestsPath,
            {
              'attendance': widget.buoi.num0('attendance'),
              'trang_thai_mong_muon': _chon!.trangThai,
              'di_tre_mong_muon': _chon!.laDiTre,
              'ly_do': _lyDo.text.trim(),
            },
            fileField: _file == null ? null : 'minh_chung',
            fileName: _file?.name,
            fileBytes: _file?.bytes,
          );
      if (mounted) Navigator.of(context).pop(true);
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _banner =
            f.fields['minh_chung'] ??
            failureText(f, 'Không gửi được yêu cầu, vui lòng thử lại.');
      });
    }
  }

  @override
  Widget build(BuildContext context) => AppDialog(
    title: 'Gửi yêu cầu sửa điểm danh',
    actions: [
      DialogButton(
        'Hủy',
        onPressed: _loading ? null : () => Navigator.of(context).pop(false),
      ),
      DialogButton(
        'Gửi yêu cầu',
        filled: true,
        loading: _loading,
        onPressed: _send,
      ),
    ],
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ngayDayDu(widget.buoi.str('ngay_hoc')),
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        LabeledDropdown<DiemDanhChon?>(
          label: 'Trạng thái mong muốn',
          value: _chon,
          options: [(null, '— Chọn —'), for (final o in _options) (o, o.label)],
          onChanged: (v) => setState(() {
            _chon = v;
            _errChon = null;
          }),
        ),
        if (_errChon != null) _err(_errChon!),
        const SizedBox(height: 14),
        LabeledField(
          label: 'Lý do (bắt buộc)',
          controller: _lyDo,
          error: _errLyDo,
          enabled: !_loading,
        ),
        const SizedBox(height: 14),
        const Text(
          'Minh chứng (không bắt buộc)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.label,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _loading ? null : _pick,
              child: const Text('Chọn ảnh hoặc PDF'),
            ),
            const Text(
              'Tối đa 5 MB',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (_file != null)
              InputChip(
                label: Text(_file!.name),
                onDeleted: () => setState(() => _file = null),
              ),
          ],
        ),
        if (_banner != null) ...[
          const SizedBox(height: 12),
          AlertBanner(kind: BannerKind.error, message: _banner!),
        ],
      ],
    ),
  );

  Widget _err(String m) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Text(
      m,
      style: const TextStyle(fontSize: 12, color: AppColors.danger),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}

class _Hint extends StatelessWidget {
  const _Hint(this.title, this.message);

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => _Card(
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
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      ],
    ),
  );
}
