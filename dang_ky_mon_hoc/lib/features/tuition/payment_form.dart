import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../registration/registration_format.dart' show newIdempotencyKey;
import '../training/entity_form.dart';
import '../training/training_api.dart';
import 'money.dart';

/// Hộp thoại **ghi thu / ghi hoàn** (BR-26) cho một dòng học phí `row` (từ `GET /tuition/`).
/// Giao dịch đã ghi không sửa/xóa được — sai thì ghi khoản hoàn bù. Trả `true` nếu đã ghi.
Future<bool> showPaymentForm(
  BuildContext context,
  WidgetRef ref,
  Json row, {
  required bool hoan,
}) {
  final toiDa = vnd(row, hoan ? 'can_hoan' : 'con_no');
  final api = ref.read(trainingApiProvider);
  return showEntityForm(
    context,
    title: hoan ? 'Ghi hoàn tiền' : 'Ghi thu học phí',
    saveLabel: 'Ghi giao dịch',
    note:
        '${row.str('ho_ten')} (${row.str('ma_sv')}) — ${row.str('ten_hk')}. '
        '${hoan ? 'Cần hoàn tối đa' : 'Còn nợ'} ${formatVnd(toiDa)}. '
        'Giao dịch đã ghi không sửa hoặc xóa được; nếu nhập sai, hãy ghi một khoản hoàn bù.',
    specs: [
      const TextSpec('so_tien', 'Số tiền (₫)', number: true, half: true),
      const ChoiceSpec(
        'phuong_thuc',
        'Phương thức',
        phuongThucOptions,
        half: true,
      ),
    ],
    submit: (body) => api.create(
      '/tuition/payments/',
      {...body, 'tuition': row.id, 'loai': hoan ? 'HOAN' : 'THU'},
      headers: {'Idempotency-Key': newIdempotencyKey()},
    ),
  );
}
