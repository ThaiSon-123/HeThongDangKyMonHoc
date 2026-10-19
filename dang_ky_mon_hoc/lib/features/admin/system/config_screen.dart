import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../../training/training_api.dart';
import '../../training/training_widgets.dart';
import '../accounts/account_dialogs.dart' show failureText;

/// Nhãn và gợi ý hiển thị cho từng khóa (backend chỉ trả khóa, nhóm, giá trị, mặc định).
const _truong = <String, (String, String?)>{
  'max_absent_pct': ('Tỷ lệ vắng tối đa (%)', 'Từ 0 đến 100.'),
  'so_ngay_cho_phep_nhap_diem': (
    'Số ngày được nhập điểm sau khi kết thúc',
    'Số nguyên từ 0.',
  ),
  'backup_retention_days': ('Số ngày giữ bản sao lưu', 'Số nguyên từ 1.'),
  'ck_ngan_hang': ('Ngân hàng', null),
  'ck_so_tai_khoan': ('Số tài khoản', 'Chỉ gồm chữ số.'),
  'ck_chu_tai_khoan': ('Chủ tài khoản', 'Chữ in hoa, không dấu.'),
};

const _nhomMoTa = <String, String>{
  'Điểm danh': 'Quy định cảnh báo nguy cơ cấm thi theo tỷ lệ vắng.',
  'Nhập điểm': 'Thời gian giáo viên được nhập điểm sau khi lớp kết thúc.',
  'Sao lưu': 'Thời gian giữ các bản sao lưu tự động.',
  'Nhận chuyển khoản học phí':
      'Thông tin hiển thị cho sinh viên khi thanh toán bằng mã QR.',
};

/// Cấu hình hệ thống (ADM-05) — mockup `AD-Web-CauHinh`: đúng 6 khóa chia 4 nhóm, lưu từng nhóm.
class ConfigScreen extends ConsumerStatefulWidget {
  const ConfigScreen({super.key});

  @override
  ConsumerState<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends ConsumerState<ConfigScreen> {
  static const _path = '/admin/config/';
  late Future<Json> _future = _fetch();

  Future<Json> _fetch() => ref.read(trainingApiProvider).get(_path);

  void _retry() {
    final next = _fetch();
    setState(() {
      _future = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _retry);
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final items = [for (final i in d['items'] as List) Json.from(i as Map)];
      final nhom = <String, List<Json>>{};
      for (final i in items) {
        nhom.putIfAbsent(i.str('nhom'), () => []).add(i);
      }
      final sua = d['sua_lan_cuoi'];
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.infoBannerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Thay đổi chỉ áp dụng cho thao tác về sau, không tính lại dữ liệu đã có.'
                '${sua is Map ? ' Sửa lần cuối bởi ${sua['boi']} · ${formatIso(sua['luc'] as String?)}.' : ''}',
                style: const TextStyle(color: AppColors.infoBannerText),
              ),
            ),
            for (final e in nhom.entries) ...[
              const SizedBox(height: 16),
              _GroupCard(
                // Sau khi lưu, dữ liệu mới về → dựng lại để ô nhập nhận giá trị server đã chuẩn hóa.
                key: ValueKey('${e.key}-${items.map((i) => i.str('gia_tri'))}'),
                title: e.key,
                items: e.value,
                onSaved: _retry,
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _GroupCard extends ConsumerStatefulWidget {
  const _GroupCard({
    super.key,
    required this.title,
    required this.items,
    required this.onSaved,
  });

  final String title;
  final List<Json> items;
  final VoidCallback onSaved;

  @override
  ConsumerState<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends ConsumerState<_GroupCard> {
  late final _ctl = {
    for (final i in widget.items)
      i.str('khoa'): TextEditingController(text: i.str('gia_tri')),
  };
  Map<String, String> _errors = {};
  bool _saving = false;

  /// Nhóm nhận chuyển khoản không có giá trị mặc định → không có nút "Đặt lại mặc định".
  bool get _coMacDinh =>
      widget.items.every((i) => i.str('mac_dinh').isNotEmpty);

  @override
  void dispose() {
    for (final c in _ctl.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _reset() => setState(() {
    for (final i in widget.items) {
      _ctl[i.str('khoa')]!.text = i.str('mac_dinh');
    }
    _errors = {};
  });

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errors = {};
    });
    try {
      await ref.read(trainingApiProvider).patch('/admin/config/', {
        for (final e in _ctl.entries) e.key: e.value.text.trim(),
      });
      if (!mounted) return;
      setState(() => _saving = false);
      showAppToast(context, 'Đã lưu cấu hình “${widget.title}”.');
      widget.onSaved();
    } on ApiFailure catch (f) {
      if (!mounted) return;
      setState(() {
        _errors = f.fields;
        _saving = false;
      });
      if (f.fields.isEmpty) {
        showAppToast(context, failureText(f, 'Không lưu được cấu hình.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) => PanelCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: sectionTitleStyle),
                  Text(
                    _nhomMoTa[widget.title] ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (_coMacDinh)
              SizedBox(
                width: 170,
                child: AppButton(
                  label: 'Đặt lại mặc định',
                  height: 40,
                  outlined: true,
                  onPressed: _reset,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        for (final i in widget.items) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: LabeledField(
                label: _truong[i.str('khoa')]?.$1 ?? i.str('khoa'),
                controller: _ctl[i.str('khoa')]!,
                helper: [
                  ?_truong[i.str('khoa')]?.$2,
                  if (i.str('mac_dinh').isNotEmpty)
                    'Mặc định ${i.str('mac_dinh')}.',
                ].join(' '),
                hint: i.str('khoa') == 'ck_ngan_hang'
                    ? 'VD: Vietcombank'
                    : null,
                error: _errors[i.str('khoa')],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: 160,
            child: AppButton(
              label: 'Lưu nhóm này',
              height: 44,
              loading: _saving,
              onPressed: _save,
            ),
          ),
        ),
      ],
    ),
  );
}
