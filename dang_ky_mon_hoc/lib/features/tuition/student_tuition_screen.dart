import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/labeled_field.dart';
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

Widget _stat(String k, String v, {Color? color}) => SizedBox(
  width: 170,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        v,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: color ?? AppColors.navy,
        ),
      ),
      Text(k, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
    ],
  ),
);

/// Học phí của sinh viên (SV-12) — mockup `SV-Web-HocPhi`: tổng hợp, chi tiết từng môn, giao dịch.
class StudentTuitionScreen extends ConsumerStatefulWidget {
  const StudentTuitionScreen({super.key});

  @override
  ConsumerState<StudentTuitionScreen> createState() =>
      _StudentTuitionScreenState();
}

class _StudentTuitionScreenState extends ConsumerState<StudentTuitionScreen> {
  late Future<Json> _data = ref.read(trainingApiProvider).get('/tuition/my/');

  void _reload() {
    final next = ref.read(trainingApiProvider).get('/tuition/my/');
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
      final chiTiet = [
        for (final c in d['chi_tiet'] as List) Json.from(c as Map),
      ];
      final gd = [for (final p in d['payments'] as List) Json.from(p as Map)];
      final conNo = vnd(d, 'con_no');
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        d.str('ten_hk'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy,
                        ),
                      ),
                      hienThiChip(d.str('hien_thi')),
                      if (d['han_dong'] != null)
                        Text(
                          'Hạn đóng ${formatYmd(d.str('han_dong'))}',
                          style: TextStyle(
                            fontSize: 13,
                            color: d['qua_han'] == true
                                ? AppColors.danger
                                : AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      _stat('Tổng tiền', formatVnd(d['tong_tien'])),
                      _stat('Miễn giảm', formatVnd(d['mien_giam'])),
                      _stat('Phải nộp', formatVnd(d['phai_nop'])),
                      _stat(
                        'Đã nộp',
                        '${formatVnd(d['thuc_thu'])} / ${formatVnd(d['phai_nop'])}',
                      ),
                      _stat(
                        'Còn nợ',
                        formatVnd(conNo),
                        color: conNo > 0 ? AppColors.danger : AppColors.success,
                      ),
                      if (vnd(d, 'can_hoan') > 0)
                        _stat('Chờ hoàn tiền', formatVnd(d['can_hoan'])),
                    ],
                  ),
                  if (d.str('hien_thi') == 'CHUA_TINH') ...[
                    const SizedBox(height: 12),
                    const AlertBanner(
                      kind: BannerKind.info,
                      message: 'Học phí chưa được tính. Phòng Kế toán sẽ cập nhật sau khi cấu hình đơn giá.',
                    ),
                  ],
                  if (conNo > 0) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: 240,
                      child: AppButton(
                        label: 'Thanh toán học phí',
                        height: 46,
                        onPressed: () => context.go('/student/tuition/pay'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Chi tiết học phí từng môn',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (chiTiet.isEmpty)
                    const Text(
                      'Chưa có môn nào được tính học phí.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  for (final c in chiTiet)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 220,
                            child: Text(
                              '${c.str('ten_mon')} (${c.str('ma_mon')})',
                            ),
                          ),
                          Text(
                            '${c.num0('tin_chi_ly_thuyet')} TC LT · ${c.num0('tin_chi_thuc_hanh')} TC TH',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            formatVnd(c['thanh_tien']),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Giao dịch',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  if (gd.isEmpty)
                    const Text(
                      'Chưa có giao dịch nào.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  for (final p in gd)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${p.str('loai') == 'HOAN' ? 'Hoàn' : 'Thu'} · ${formatVnd(p['so_tien'])} · '
                        '${formatIso(p.str('ngay'))} · ${phuongThucLabel(p.str('phuong_thuc'))} · ${p.str('bien_lai_ma')}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  const SizedBox(height: 8),
                  const Text(
                    'Thanh toán trực tiếp tại phòng Kế toán hoặc chuyển khoản qua mã QR.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
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

  Widget _copyRow(String k, String v, {String? hien}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            k,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        SizedBox(
          width: 200,
          child: Text(
            hien ?? v,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () => _copy(k.toLowerCase(), v),
          child: const Text('Sao chép'),
        ),
      ],
    ),
  );
}
