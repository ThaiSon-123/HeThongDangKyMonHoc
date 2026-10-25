import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/layout.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/labeled_field.dart';
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

/// Thanh toán học phí bằng chuyển khoản QR (SV-12) — mockup `SV-Web-ThanhToan`: chọn toàn bộ / một
/// phần ≤ `con_no`, QR sinh ở client từ `tuition/my.thanh_toan`, sao chép thông tin. Học phí chỉ cập nhật
/// khi Kế toán xác nhận đã nhận tiền.
class StudentPayScreen extends ConsumerStatefulWidget {
  const StudentPayScreen({super.key});

  @override
  ConsumerState<StudentPayScreen> createState() => _StudentPayScreenState();
}

class _StudentPayScreenState extends ConsumerState<StudentPayScreen> {
  late final Future<Json> _data = ref
      .read(trainingApiProvider)
      .get('/tuition/my/');
  final _amount = TextEditingController();
  bool _full = true;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _copy(String label, String v) async {
    await Clipboard.setData(ClipboardData(text: v));
    if (mounted) showAppToast(context, 'Đã sao chép $label.');
  }

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
      final tt = Json.from(d['thanh_toan'] as Map);
      final nhap = int.tryParse(_amount.text.trim());
      final soTien = _full ? conNo : (nhap?.toDouble());
      final hopLe = soTien != null && soTien > 0 && soTien <= conNo;
      final chuaCauHinh = tt.str('so_tai_khoan').isEmpty;
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
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Toàn bộ công nợ'),
                          selected: _full,
                          onSelected: (_) => setState(() => _full = true),
                        ),
                        ChoiceChip(
                          label: const Text('Một phần'),
                          selected: !_full,
                          onSelected: (_) => setState(() => _full = false),
                        ),
                      ],
                    ),
                    if (!_full) ...[
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
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (conNo > 0)
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quét mã QR để chuyển khoản',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Học phí chỉ được cập nhật sau khi Phòng Kế toán xác nhận đã nhận tiền (thường trong 1–2 ngày làm việc). '
                      'Hãy giữ nguyên nội dung chuyển khoản để kế toán đối soát.',
                      style: TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 14),
                    if (chuaCauHinh)
                      const AlertBanner(
                        kind: BannerKind.warning,
                        message: 'Nhà trường chưa cấu hình tài khoản nhận chuyển khoản. Vui lòng thanh toán tại phòng Kế toán.',
                      )
                    else if (!hopLe)
                      const Text(
                        'Nhập số tiền hợp lệ để tạo mã QR.',
                        style: TextStyle(color: AppColors.muted),
                      )
                    else
                      Wrap(
                        spacing: 24,
                        runSpacing: 16,
                        alignment: isCompact(context)
                            ? WrapAlignment.center
                            : WrapAlignment.start,
                        children: [
                          Semantics(
                            label: 'Mã QR chuyển khoản',
                            child: QrImageView(
                              key: const ValueKey('qr'),
                              data:
                                  'Ngân hàng: ${tt.str('ngan_hang')}\nSTK: ${tt.str('so_tai_khoan')}\n'
                                  'Chủ TK: ${tt.str('chu_tai_khoan')}\nSố tiền: ${soTien.round()}\n'
                                  'Nội dung: ${tt.str('noi_dung_ck')}',
                              size: 200,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _copyRow('Ngân hàng', tt.str('ngan_hang')),
                              _copyRow('Số tài khoản', tt.str('so_tai_khoan')),
                              _copyRow(
                                'Chủ tài khoản',
                                tt.str('chu_tai_khoan'),
                              ),
                              _copyRow(
                                'Số tiền',
                                '${soTien.round()}',
                                hien: formatVnd(soTien),
                              ),
                              _copyRow('Nội dung', tt.str('noi_dung_ck')),
                              const Padding(
                                padding: EdgeInsets.only(top: 6),
                                child: Text(
                                  'Mã QR minh họa — mã thật do ngân hàng cung cấp.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );

  Widget _copyRow(String k, String v, {String? hien}) {
    final compact = isCompact(context);
    final gia = Text(
      hien ?? v,
      style: const TextStyle(fontWeight: FontWeight.w600),
    );
    // Điện thoại: giá trị chiếm phần còn lại của hàng (tự xuống dòng) để nút Sao chép không tràn.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          SizedBox(
            width: compact ? 92 : 110,
            child: Text(
              k,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
          if (compact)
            Expanded(child: gia)
          else
            SizedBox(width: 200, child: gia),
          TextButton(
            onPressed: () => _copy(k.toLowerCase(), v),
            child: const Text('Sao chép'),
          ),
        ],
      ),
    );
  }
}
