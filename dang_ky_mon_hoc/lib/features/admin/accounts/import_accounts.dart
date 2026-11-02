import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../training/training_api.dart';
import 'account_dialogs.dart' show failureText;

const _path = '/users/import/';

/// Tệp Excel đã chọn.
typedef TepExcel = ({String ten, List<int> bytes});

/// Hộp chọn tệp .xlsx, thay được trong test.
final excelPickerProvider = Provider<Future<TepExcel?> Function()>(
  (ref) => () async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
    );
    return f == null ? null : (ten: f.name, bytes: await f.readAsBytes());
  },
);

/// Tạo tài khoản hàng loạt từ Excel: chọn tệp → server kiểm tra (`POST /users/import/`) → sai mẫu thì báo
/// lỗi, đúng mẫu thì xem trước từng dòng (dòng lỗi ghi lý do) → xác nhận tạo các dòng hợp lệ.
/// Trả số tài khoản đã tạo (null nếu hủy / lỗi).
Future<int?> nhapTaiKhoanExcel(BuildContext context, WidgetRef ref) async {
  final tep = await ref.read(excelPickerProvider)();
  if (tep == null || !context.mounted) return null;
  final api = ref.read(trainingApiProvider);
  Future<Json> gui(bool xacNhan) => api.createForm(
    _path,
    {'xac_nhan': xacNhan ? '1' : '0'},
    fileField: 'file',
    fileName: tep.ten,
    fileBytes: tep.bytes,
  );

  final Json xem;
  try {
    xem = await gui(false);
  } on ApiFailure catch (f) {
    if (context.mounted) {
      await _baoLoi(
        context,
        f.fields['file'] ?? failureText(f, 'Không kiểm tra được tệp.'),
      );
    }
    return null;
  }
  if (!context.mounted) return null;
  return showDialog<int>(
    context: context,
    builder: (_) => _XemTruoc(ten: tep.ten, data: xem, tao: () => gui(true)),
  );
}

Future<void> _baoLoi(BuildContext context, String loi) => showDialog<void>(
  context: context,
  builder: (ctx) => AppDialog(
    title: 'File không đúng mẫu',
    actions: [DialogButton('Đóng', onPressed: () => Navigator.of(ctx).pop())],
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loi, style: const TextStyle(color: AppColors.danger, height: 1.5)),
        const SizedBox(height: 10),
        const Text(
          'Bấm "Tải file mẫu" để lấy đúng mẫu, điền rồi nhập lại.',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      ],
    ),
  ),
);

class _XemTruoc extends StatefulWidget {
  const _XemTruoc({required this.ten, required this.data, required this.tao});

  final String ten;
  final Json data;
  final Future<Json> Function() tao;

  @override
  State<_XemTruoc> createState() => _XemTruocState();
}

class _XemTruocState extends State<_XemTruoc> {
  bool _dangTao = false;
  String? _loi;

  Future<void> _tao() async {
    setState(() {
      _dangTao = true;
      _loi = null;
    });
    try {
      final r = await widget.tao();
      if (mounted) Navigator.of(context).pop(r.num0('da_tao'));
    } on ApiFailure catch (f) {
      if (mounted) {
        setState(() {
          _dangTao = false;
          _loi =
              f.fields['file'] ?? failureText(f, 'Không tạo được tài khoản.');
        });
      }
    }
  }

  static const _dau = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.muted,
  );

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final r in widget.data['rows'] as List) Json.from(r as Map),
    ];
    final hopLe = widget.data.num0('hop_le');
    final loi = widget.data.num0('loi');
    return AppDialog(
      title: 'Tài khoản sẽ tạo từ Excel',
      maxWidth: 920,
      actions: [
        DialogButton(
          'Hủy',
          onPressed: _dangTao ? null : () => Navigator.of(context).pop(),
        ),
        DialogButton(
          'Tạo $hopLe tài khoản',
          filled: true,
          loading: _dangTao,
          onPressed: hopLe == 0 || _dangTao ? null : _tao,
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${widget.ten} · ${rows.length} dòng: $hopLe hợp lệ'
            '${loi > 0 ? ', $loi lỗi (dòng lỗi sẽ bị bỏ qua)' : ''}.',
            style: const TextStyle(fontSize: 14),
          ),
          if (_loi != null) ...[
            const SizedBox(height: 8),
            Text(_loi!, style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                SizedBox(width: 48, child: Text('DÒNG', style: _dau)),
                Expanded(flex: 3, child: Text('TÊN ĐĂNG NHẬP', style: _dau)),
                Expanded(flex: 3, child: Text('HỌ TÊN', style: _dau)),
                Expanded(flex: 4, child: Text('EMAIL', style: _dau)),
                Expanded(flex: 2, child: Text('VAI TRÒ', style: _dau)),
                Expanded(flex: 4, child: Text('KẾT QUẢ', style: _dau)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 420),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: rows.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (_, i) => _dong(rows[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dong(Json r) {
    final loi = [for (final e in r['loi'] as List) '$e'];
    final o = loi.isEmpty;
    String hoac(String s) => s.isEmpty ? '—' : s;
    return Container(
      color: o ? null : AppColors.errorBannerBg.withValues(alpha: 0.5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 48, child: Text('${r.num0('dong')}')),
          Expanded(
            flex: 3,
            child: Text(
              hoac(r.str('username')),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(flex: 3, child: Text(hoac(r.str('full_name')))),
          Expanded(flex: 4, child: Text(hoac(r.str('email')))),
          Expanded(flex: 2, child: Text(hoac(r.str('role_label')))),
          Expanded(
            flex: 4,
            child: o
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip.of('Hợp lệ', StatusChip.green),
                  )
                : Text(
                    loi.join(' '),
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 13,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
