import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api/api_failure.dart';
import '../../core/layout.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/labeled_field.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import '../dashboard/dashboard_widgets.dart' show soNgayDen;
import '../registration/timetable_screen.dart' show clockProvider;
import '../reports/report_widgets.dart' show LuoiStat, StatCard;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import 'money.dart';
import 'tuition_ledger_screens.dart' show hienThiChip;

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

/// Học phí của sinh viên (SV-12) — mockup `SV-Web-HocPhi` / `SV-App-HocPhi`: chọn học kỳ, thẻ trạng thái
/// kèm thanh đã nộp, 5 thẻ số tiền, chi tiết từng môn và giao dịch.
class StudentTuitionScreen extends ConsumerStatefulWidget {
  const StudentTuitionScreen({super.key});

  @override
  ConsumerState<StudentTuitionScreen> createState() =>
      _StudentTuitionScreenState();
}

class _StudentTuitionScreenState extends ConsumerState<StudentTuitionScreen> {
  int? _hocKy; // null = học kỳ mặc định của hệ thống
  late Future<Json> _data = _fetch();

  Future<Json> _fetch() => ref
      .read(trainingApiProvider)
      .get('/tuition/my/', query: {'hoc_ky': _hocKy});

  void _reload() {
    final next = _fetch();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final compact = isCompact(context);
      final chiTiet = [
        for (final c in d['chi_tiet'] as List) Json.from(c as Map),
      ];
      final gd = [for (final p in d['payments'] as List) Json.from(p as Map)];
      final hocKy = [
        for (final h in (d['cac_hoc_ky'] as List? ?? const []))
          Json.from(h as Map),
      ];
      final conNo = vnd(d, 'con_no');
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hocKy.length > 1) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: compact ? double.infinity : 320,
                  child: LabeledDropdown<int>(
                    label: 'Học kỳ',
                    value: d.num0('hoc_ky'),
                    options: [
                      for (final h in hocKy) (h.num0('id'), h.str('ten_hk')),
                    ],
                    onChanged: (v) {
                      _hocKy = v;
                      _reload();
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                d.str('ten_hk'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 12),
            ],
            _trangThai(d, conNo, compact),
            const SizedBox(height: 16),
            LuoiStat(
              children: [
                StatCard(
                  label: 'Tổng tiền học phí',
                  value: formatVnd(d['tong_tien']),
                ),
                StatCard(
                  label: 'Miễn giảm / học bổng',
                  value: formatVnd(d['mien_giam']),
                  valueColor: AppColors.success,
                ),
                StatCard(label: 'Phải nộp', value: formatVnd(d['phai_nop'])),
                StatCard(
                  label: 'Đã thu',
                  value: formatVnd(d['thuc_thu']),
                  valueColor: AppColors.primary,
                ),
                StatCard(
                  label: 'Còn nợ',
                  value: formatVnd(conNo),
                  valueColor: conNo > 0 ? AppColors.danger : AppColors.success,
                ),
                if (vnd(d, 'can_hoan') > 0)
                  StatCard(
                    label: 'Chờ hoàn tiền',
                    value: formatVnd(d['can_hoan']),
                    valueColor: const Color(0xFFB26A00),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (compact) ...[
              _chiTietCard(chiTiet, compact),
              const SizedBox(height: 16),
              _giaoDichCard(gd),
            ] else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _chiTietCard(chiTiet, compact)),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: _giaoDichCard(gd)),
                ],
              ),
          ],
        ),
      );
    },
  );

  /// Thẻ trạng thái: chip + nút thanh toán; bên phải thanh "Đã nộp" và hạn đóng.
  Widget _trangThai(Json d, double conNo, bool compact) {
    final phaiNop = vnd(d, 'phai_nop');
    final thu = vnd(d, 'thuc_thu');
    final tiLe = phaiNop > 0 ? (thu / phaiNop).clamp(0, 1).toDouble() : 0.0;
    final han = d['han_dong'] == null ? '' : d.str('han_dong');
    final con = han.isEmpty ? null : soNgayDen(han, ref.read(clockProvider)());
    final quaHan = d['qua_han'] == true;
    final hanText = han.isEmpty
        ? null
        : 'Hạn đóng: ${formatYmd(han)}'
              '${quaHan ? ' · Quá hạn' : (conNo > 0 && con != null && con >= 0 ? ' · còn $con ngày' : '')}';
    final trai = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Trạng thái học phí',
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 6),
        hienThiChip(d.str('hien_thi')),
        if (conNo > 0) ...[
          const SizedBox(height: 14),
          SizedBox(
            width: compact ? double.infinity : 240,
            child: AppButton(
              label: 'Thanh toán học phí',
              height: 46,
              onPressed: () => context.go('/student/tuition/pay'),
            ),
          ),
        ],
      ],
    );
    final phai = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Đã nộp',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${formatVnd(thu)} / ${formatVnd(phaiNop)}',
              style: const TextStyle(fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: tiLe,
            minHeight: 10,
            color: tiLe >= 1 ? AppColors.success : AppColors.primary,
            backgroundColor: AppColors.divider,
          ),
        ),
        if (hanText != null) ...[
          const SizedBox(height: 6),
          Text(
            hanText,
            style: TextStyle(
              fontSize: 13,
              color: quaHan ? AppColors.danger : AppColors.muted,
            ),
          ),
        ],
      ],
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [trai, const SizedBox(height: 16), phai],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: trai),
                    const SizedBox(width: 32),
                    Expanded(child: phai),
                  ],
                ),
          if (d.str('hien_thi') == 'CHUA_TINH') ...[
            const SizedBox(height: 12),
            const AlertBanner(
              kind: BannerKind.info,
              message: 'Học phí chưa được tính. Phòng Kế toán sẽ cập nhật sau khi cấu hình đơn giá.',
            ),
          ],
        ],
      ),
    );
  }

  Widget _chiTietCard(List<Json> chiTiet, bool compact) {
    const dau = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
      letterSpacing: 0.3,
    );
    Widget so(String t, {TextStyle? style}) => SizedBox(
      width: 64,
      child: Text(t, textAlign: TextAlign.center, style: style),
    );
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
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
            child: Text(
              'Chi tiết học phí từng môn',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: AppColors.navy,
              ),
            ),
          ),
          if (chiTiet.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Text(
                'Chưa có môn nào được tính học phí.',
                style: TextStyle(color: AppColors.muted),
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF7F8FC),
                border: Border.symmetric(
                  horizontal: BorderSide(color: AppColors.divider),
                ),
              ),
              child: Row(
                children: [
                  const Expanded(child: Text('MÔN HỌC', style: dau)),
                  if (!compact) ...[
                    so('TC LT', style: dau),
                    so('TC TH', style: dau),
                  ],
                  const SizedBox(
                    width: 110,
                    child: Text(
                      'THÀNH TIỀN',
                      textAlign: TextAlign.right,
                      style: dau,
                    ),
                  ),
                ],
              ),
            ),
            for (final c in chiTiet)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.str('ten_mon'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            compact
                                ? '${c.str('ma_mon')} · ${c.num0('tin_chi_ly_thuyet')} TC LT · ${c.num0('tin_chi_thuc_hanh')} TC TH'
                                : c.str('ma_mon'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      so('${c.num0('tin_chi_ly_thuyet')}'),
                      so('${c.num0('tin_chi_thuc_hanh')}'),
                    ],
                    SizedBox(
                      width: 110,
                      child: Text(
                        formatVnd(c['thanh_tien']),
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _giaoDichCard(List<Json> gd) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Giao dịch',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 12),
        if (gd.isEmpty)
          const Text(
            'Chưa có giao dịch nào.',
            style: TextStyle(color: AppColors.muted),
          ),
        for (final p in gd)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p.str('loai') == 'HOAN' ? 'Hoàn' : 'Thu'} · ${formatVnd(p['so_tien'])}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${formatIso(p.str('ngay'))} · ${phuongThucLabel(p.str('phuong_thuc'))}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  p.str('bien_lai_ma'),
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        const Text(
          'Thanh toán trực tiếp tại phòng Kế toán hoặc chuyển khoản qua mã QR.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}

/// Thanh toán học phí qua VNPay (SV-12): chọn đóng một lần / chia 3 đợt (đổi được bất cứ lúc nào), xem lịch
/// đợt, chọn mức thanh toán rồi quét QR (chứa `payment_url` của VNPay) hoặc mở trang thanh toán. Màn hình
/// poll trạng thái giao dịch tới khi VNPay báo kết quả; học phí do backend tự cập nhật.
class StudentPayScreen extends ConsumerStatefulWidget {
  const StudentPayScreen({super.key});

  @override
  ConsumerState<StudentPayScreen> createState() => _StudentPayScreenState();
}

class _StudentPayScreenState extends ConsumerState<StudentPayScreen> {
  late Future<Json> _data = _fetch();
  final _amount = TextEditingController();
  String? _muc; // null = mặc định theo dữ liệu (đợt tiếp theo nếu có, ngược lại toàn bộ)
  Json?
  _giaoDich; // `payment_url`, `txn_ref`, `so_tien` của mã đang chờ thanh toán
  String? _ketQua; // THANH_CONG | THAT_BAI | LOI sau khi giao dịch kết thúc
  String? _loi;
  bool _dangTao = false;
  bool _dangDoi = false;
  Timer? _timer;

  Future<Json> _fetch() => ref.read(trainingApiProvider).get('/tuition/my/');

  void _reload() => setState(() {
    _data = _fetch();
  });

  @override
  void dispose() {
    _timer?.cancel();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _doiHinhThuc(String hinhThuc) async {
    setState(() {
      _loi = null;
      _dangDoi = true;
    });
    try {
      await ref.read(trainingApiProvider).patch('/tuition/my/plan/', {
        'hinh_thuc': hinhThuc,
      });
      _muc = null;
      if (mounted) _reload();
    } on ApiFailure catch (f) {
      if (mounted) {
        setState(() => _loi = failureText(f, 'Không đổi được hình thức đóng.'));
      }
    } finally {
      if (mounted) setState(() => _dangDoi = false);
    }
  }

  Future<void> _taoMa(String muc, int? soTien) async {
    setState(() {
      _loi = null;
      _ketQua = null;
      _dangTao = true;
    });
    try {
      final r = await ref.read(trainingApiProvider).create('/tuition/my/pay/', {
        'muc': muc,
        if (muc == 'TUY_Y') 'so_tien': soTien,
      });
      if (!mounted) return;
      setState(() => _giaoDich = r);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _hoi());
    } on ApiFailure catch (f) {
      if (mounted) {
        setState(() => _loi = failureText(f, 'Không tạo được mã thanh toán.'));
      }
    } finally {
      if (mounted) setState(() => _dangTao = false);
    }
  }

  Future<void> _hoi() async {
    final gd = _giaoDich;
    if (gd == null) return;
    try {
      final r = await ref
          .read(trainingApiProvider)
          .get('/tuition/my/pay/${gd.str('txn_ref')}/');
      if (!mounted || r.str('trang_thai') == 'CHO') return;
      _timer?.cancel();
      setState(() {
        _ketQua = r.str('trang_thai');
        _giaoDich = null;
      });
      _reload();
    } on ApiFailure {
      // mạng chập chờn: lần poll sau thử lại
    }
  }

  void _boMa() {
    _timer?.cancel();
    setState(() => _giaoDich = null);
  }

  Future<void> _moTrang(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) {
        return ListErrorCard(onRetry: () => context.go('/student/tuition'));
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final conNo = vnd(d, 'con_no');
      final hinhThuc = d.str('hinh_thuc');
      final dots = [for (final e in d['cac_dot'] as List) Json.from(e as Map)];
      final coDot = dots.isNotEmpty;
      final dotTiep = d['dot_tiep_theo'] == null
          ? null
          : Json.from(d['dot_tiep_theo'] as Map);
      final muc = switch (_muc) {
        'DOT_TIEP' when dotTiep != null => 'DOT_TIEP',
        'TUY_Y' => 'TUY_Y',
        null when dotTiep != null => 'DOT_TIEP',
        _ => 'TOAN_BO',
      };
      final nhap = int.tryParse(_amount.text.trim());
      final soTien = switch (muc) {
        'DOT_TIEP' => math.min(vnd(dotTiep!, 'can_dong'), conNo),
        'TOAN_BO' => conNo,
        _ => nhap?.toDouble(),
      };
      final hopLe = soTien != null && soTien > 0 && soTien <= conNo;
      final cho = _giaoDich;
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go('/student/tuition'),
                child: const Text('← Quay lại học phí'),
              ),
            ),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.str('ten_hk'),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Công nợ hiện tại',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  Text(
                    formatVnd(conNo),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  if (conNo <= 0) ...[
                    const SizedBox(height: 10),
                    const AlertBanner(
                      kind: BannerKind.info,
                      message: 'Bạn không còn công nợ học phí.',
                    ),
                  ] else ...[
                    const SizedBox(height: 14),
                    const Text(
                      'Hình thức đóng',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Đóng một lần'),
                          selected: hinhThuc == 'MOT_LAN',
                          onSelected: _dangDoi || hinhThuc == 'MOT_LAN'
                              ? null
                              : (_) => _doiHinhThuc('MOT_LAN'),
                        ),
                        ChoiceChip(
                          label: const Text('Chia 3 đợt'),
                          selected: hinhThuc == 'CHIA_DOT',
                          onSelected:
                              !coDot || _dangDoi || hinhThuc == 'CHIA_DOT'
                              ? null
                              : (_) => _doiHinhThuc('CHIA_DOT'),
                        ),
                      ],
                    ),
                    if (!coDot)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          'Học kỳ này chưa cấu hình chia đợt.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (coDot) ...[
              const SizedBox(height: 16),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Lịch 3 đợt',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final dot in dots) _dongDot(dot),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_ketQua != null) ...[
              _bangKetQua(_ketQua!),
              const SizedBox(height: 16),
            ],
            if (conNo > 0)
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thanh toán qua VNPay',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Quét mã QR bằng điện thoại để mở trang thanh toán VNPay (môi trường thử nghiệm). '
                      'Thanh toán xong, học phí được cập nhật tự động.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    if (cho == null) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (dotTiep != null)
                            ChoiceChip(
                              label: const Text('Đợt tiếp theo'),
                              selected: muc == 'DOT_TIEP',
                              onSelected: (_) =>
                                  setState(() => _muc = 'DOT_TIEP'),
                            ),
                          ChoiceChip(
                            label: const Text('Toàn bộ công nợ'),
                            selected: muc == 'TOAN_BO',
                            onSelected: (_) => setState(() => _muc = 'TOAN_BO'),
                          ),
                          ChoiceChip(
                            label: const Text('Số tiền khác'),
                            selected: muc == 'TUY_Y',
                            onSelected: (_) => setState(() => _muc = 'TUY_Y'),
                          ),
                        ],
                      ),
                      if (muc == 'TUY_Y') ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: 300,
                          child: LabeledField(
                            label: 'Số tiền muốn thanh toán (₫)',
                            controller: _amount,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (_) => setState(() {}),
                            error: _amount.text.isNotEmpty && !hopLe
                                ? 'Số tiền phải lớn hơn 0 và không vượt quá công nợ ${formatVnd(conNo)}.'
                                : null,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      if (soTien != null && soTien > 0)
                        Text(
                          'Số tiền thanh toán: ${formatVnd(soTien)}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      if (_loi != null) ...[
                        const SizedBox(height: 10),
                        AlertBanner(kind: BannerKind.error, message: _loi!),
                      ],
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 240,
                        child: AppButton(
                          label: 'Tạo mã thanh toán',
                          loading: _dangTao,
                          onPressed: hopLe ? () => _taoMa(muc, nhap) : null,
                        ),
                      ),
                    ] else
                      _khoiQr(cho),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _dongDot(Json dot) {
    final xong = dot['da_dong'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              'Đợt ${dot.str('thu_tu')}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              'Hạn ${formatYmd(dot.str('han_dong'))}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          Text(formatVnd(dot['phai_nop'])),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              xong ? 'Đã đóng' : 'Chưa đóng',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: xong ? AppColors.success : AppColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bangKetQua(String ketQua) => switch (ketQua) {
    'THANH_CONG' => const AlertBanner(
      kind: BannerKind.info,
      message: 'Thanh toán thành công.',
    ),
    'LOI' => const AlertBanner(kind: BannerKind.error, message: _loiGhiHocPhi),
    _ => const AlertBanner(
      kind: BannerKind.warning,
      message: 'Thanh toán không thành công.',
    ),
  };

  Widget _khoiQr(Json gd) {
    final url = gd.str('payment_url');
    return Wrap(
      spacing: 24,
      runSpacing: 16,
      alignment: isCompact(context)
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: [
        Semantics(
          label: 'Mã QR thanh toán VNPay',
          child: QrImageView(key: ValueKey(url), data: url, size: 200),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Số tiền: ${formatVnd(gd['so_tien'])}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 260,
              child: AppButton(
                label: 'Mở trang thanh toán VNPay',
                outlined: true,
                onPressed: () => _moTrang(url),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Đang chờ thanh toán… (tự cập nhật khi VNPay báo kết quả)',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            TextButton(onPressed: _boMa, child: const Text('Tạo mã khác')),
          ],
        ),
      ],
    );
  }
}

const _loiGhiHocPhi =
    'Đã nhận tiền nhưng chưa ghi được học phí, vui lòng liên hệ Phòng Kế toán.';

/// Trang đích khi VNPay chuyển trình duyệt về (`/student/tuition/pay-result?status=`): hiện kết quả
/// do backend ghi nhận rồi cho quay lại học phí.
class StudentPayResultScreen extends StatelessWidget {
  const StudentPayResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final status = GoRouterState.of(context).uri.queryParameters['status'];
    final (kind, message) = switch (status) {
      'thanh_cong' => (BannerKind.info, 'Thanh toán thành công.'),
      'that_bai' => (BannerKind.warning, 'Thanh toán không thành công.'),
      'loi' => (BannerKind.error, _loiGhiHocPhi),
      _ => (BannerKind.error, 'Kết quả thanh toán không hợp lệ.'),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AlertBanner(kind: kind, message: message),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => context.go('/student/tuition'),
            child: const Text('← Quay lại học phí'),
          ),
        ),
      ],
    );
  }
}
