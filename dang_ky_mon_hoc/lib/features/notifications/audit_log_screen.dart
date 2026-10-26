import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_user.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/status_chip.dart';
import '../training/resource_list.dart';
import '../training/training_api.dart';
import '../training/training_widgets.dart' show monoStyle;
import 'audit_mo_ta.dart';

const _hanhDong = <(String, String)>[
  ('', 'Tất cả'),
  ('CREATE', 'Tạo mới'),
  ('UPDATE', 'Cập nhật'),
  ('DELETE', 'Xóa'),
  ('LOGIN', 'Đăng nhập'),
  ('PHAN_QUYEN', 'Phân quyền'),
];

String hanhDongLabel(String h) =>
    _hanhDong.firstWhere((e) => e.$1 == h, orElse: () => (h, h)).$2;

/// Mô tả thao tác bằng câu tiếng Việt cho cột "Tóm tắt" (xem `moTaNhatKy`).
String tomTat(Json log) => moTaNhatKy(log);

/// Nhật ký thao tác (ADM-06) — mockup `AD-Web-NhatKy`: Admin xem tất cả, PĐT chỉ phạm vi đào tạo,
/// KT chỉ phạm vi tài chính (server tự lọc). Bấm một dòng để xem toàn bộ chi tiết.
class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  final _ctl = ResourceListController();
  DateTime? _tu, _den;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _chonNgay(bool tu) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (tu ? _tu : _den) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null) return;
    setState(() => tu ? _tu = d : _den = d);
    _ctl.setFilter(tu ? 'tu_ngay' : 'den_ngay', _ymd(d));
  }

  void _xoaNgay() {
    setState(() {
      _tu = null;
      _den = null;
    });
    _ctl
      ..filters.remove('tu_ngay')
      ..setFilter('den_ngay', null);
  }

  Future<void> _xem(Json r) => showDialog<void>(
    context: context,
    builder: (_) => AppDialog(
      title: 'Chi tiết thao tác #${r.id}',
      maxWidth: 640,
      actions: [
        DialogButton(
          'Đóng',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.str('nguoi_thuc_hien')} · ${hanhDongLabel(r.str('hanh_dong'))} · '
            '${tenDoiTuong[r.str('doi_tuong')] ?? r.str('doi_tuong')} #${r.str('doi_tuong_id')}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '${formatIso(r.str('thoi_gian'))}${r['ip'] != null ? ' · IP ${r.str('ip')}' : ''}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F5FA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              tomTat(r),
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final admin =
        ref.watch(authControllerProvider).user?.role == UserRole.admin;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListToolbar(
            children: [
              SearchBox(
                controller: _ctl,
                label: 'Tìm kiếm',
                hint: 'Người thực hiện hoặc đối tượng',
              ),
              FilterDropdown(
                controller: _ctl,
                filterKey: 'hanh_dong',
                label: 'Hành động',
                options: _hanhDong,
              ),
              if (admin)
                FilterDropdown(
                  controller: _ctl,
                  filterKey: 'scope',
                  label: 'Phạm vi',
                  options: const [
                    ('', 'Tất cả'),
                    ('training', 'Đào tạo'),
                    ('finance', 'Tài chính'),
                    ('other', 'Hệ thống'),
                  ],
                ),
              SizedBox(
                width: 150,
                child: AppButton(
                  label: _tu == null ? 'Từ ngày' : 'Từ ${_ymd(_tu!)}',
                  height: 48,
                  outlined: true,
                  onPressed: () => _chonNgay(true),
                ),
              ),
              SizedBox(
                width: 150,
                child: AppButton(
                  label: _den == null ? 'Đến ngày' : 'Đến ${_ymd(_den!)}',
                  height: 48,
                  outlined: true,
                  onPressed: () => _chonNgay(false),
                ),
              ),
              if (_tu != null || _den != null)
                TextButton(
                  onPressed: _xoaNgay,
                  child: const Text('Xóa lọc ngày'),
                ),
            ],
          ),
          const SizedBox(height: 24),
          ResourceList(
            controller: _ctl,
            path: '/admin/audit-logs/',
            minWidth: 900,
            emptyText: 'Chưa có thao tác nào phù hợp.',
            onRowTap: _xem,
            columns: const [
              ListColumn('Thời gian', width: 150),
              ListColumn('Người thực hiện', width: 150),
              ListColumn('Hành động', width: 120),
              ListColumn('Đối tượng', flex: 2),
              ListColumn('Tóm tắt', flex: 3),
            ],
            cells: (r) => [
              Text(
                formatIso(r.str('thoi_gian')),
                style: const TextStyle(fontSize: 13),
              ),
              Text(r.str('nguoi_thuc_hien'), overflow: TextOverflow.ellipsis),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip.of(
                  hanhDongLabel(r.str('hanh_dong')),
                  switch (r.str('hanh_dong')) {
                    'CREATE' => StatusChip.green,
                    'DELETE' => StatusChip.red,
                    'UPDATE' => StatusChip.indigo,
                    _ => StatusChip.gray,
                  },
                ),
              ),
              Text(
                '${tenDoiTuong[r.str('doi_tuong')] ?? r.str('doi_tuong')} #${r.str('doi_tuong_id')}',
                style: monoStyle,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                tomTat(r),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: AppColors.label),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
