import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../../training/training_api.dart';
import '../../training/training_widgets.dart';

const _vaiTro = {
  'ADMIN': 'QUẢN TRỊ',
  'PHONG_DAO_TAO': 'PHÒNG ĐÀO TẠO',
  'SINH_VIEN': 'SINH VIÊN',
  'GIAO_VIEN': 'GIÁO VIÊN',
  'KE_TOAN': 'KẾ TOÁN',
};

String _hoa(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Ma trận quyền (ADM-04) — mockup `AD-Web-MaTranQuyen`. **Chỉ đọc**: dữ liệu từ
/// `GET /api/admin/permissions/` (cố định trong mã nguồn), không có nút lưu hay ô sửa được.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  late Future<Json> _future = _fetch();

  Future<Json> _fetch() =>
      ref.read(trainingApiProvider).get('/admin/permissions/');

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
      final roles = [for (final r in d['vai_tro'] as List) r.toString()];
      final rows = [for (final r in d['results'] as List) Json.from(r as Map)];
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
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  const Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Quyền theo vai trò là '),
                        TextSpan(
                          text: 'cố định',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: ', không chỉnh sửa tại đây. Muốn thay đổi quyền của một người, hãy đổi vai trò của tài khoản.',
                        ),
                      ],
                    ),
                    style: TextStyle(color: AppColors.infoBannerText),
                  ),
                  SizedBox(
                    width: 190,
                    child: AppButton(
                      label: 'Mở trang Tài khoản',
                      height: 40,
                      outlined: true,
                      onPressed: () => context.go('/admin/accounts'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const _Legend(),
            const SizedBox(height: 16),
            _Matrix(roles: roles, rows: rows),
          ],
        ),
      );
    },
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) => PanelCard(
    padding: 16,
    child: Wrap(
      spacing: 20,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text(
          'Chú thích:',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        ),
        _item(const _Yes(), 'Được phép'),
        _item(const _No(), 'Không có quyền'),
        _item(const _Limited('Của mình'), 'Được phép trong phạm vi giới hạn'),
      ],
    ),
  );

  Widget _item(Widget icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.label)),
    ],
  );
}

class _Matrix extends StatelessWidget {
  const _Matrix({required this.roles, required this.rows});

  final List<String> roles;
  final List<Json> rows;

  @override
  Widget build(BuildContext context) {
    const quyenMin = 300.0, cotWidth = 140.0;
    Widget row(Widget first, List<Widget> cells, {Color? color}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        border: const Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(child: first),
          for (final c in cells)
            SizedBox(
              width: cotWidth,
              child: Align(alignment: Alignment.center, child: c),
            ),
        ],
      ),
    );

    final body = <Widget>[];
    String? nhom;
    for (final r in rows) {
      if (r.str('nhom') != nhom) {
        nhom = r.str('nhom');
        body.add(
          row(
            Text(
              nhom.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
            [for (final _ in roles) const SizedBox.shrink()],
            color: const Color(0xFFF1F3FA),
          ),
        );
      }
      body.add(
        row(Text(r.str('quyen'), style: const TextStyle(fontSize: 14)), [
          for (final role in roles) _cell(Json.from(r[role] as Map)),
        ]),
      );
    }

    return PanelCard(
      padding: 0,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            // Giãn hết thẻ khi đủ rộng; hẹp hơn thì cuộn ngang.
            width: box.maxWidth < quyenMin + cotWidth * roles.length + 40
                ? quyenMin + cotWidth * roles.length + 40
                : box.maxWidth,
            child: Column(
              children: [
                row(
                  const Text(
                    'QUYỀN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.muted,
                    ),
                  ),
                  [
                    for (final r in roles)
                      Text(
                        _vaiTro[r] ?? r,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
                ...body,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cell(Json o) {
    if (o['co'] != true) return const _No();
    final gioiHan = o.str('gioi_han');
    return gioiHan.isEmpty ? const _Yes() : _Limited(_hoa(gioiHan));
  }
}

class _Yes extends StatelessWidget {
  const _Yes();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Được phép',
    child: Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        '✓',
        style: TextStyle(
          color: AppColors.success,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),
  );
}

class _No extends StatelessWidget {
  const _No();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Không có quyền',
    child: Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF1),
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Text(
        '✕',
        style: TextStyle(color: AppColors.muted, fontSize: 13),
      ),
    ),
  );
}

class _Limited extends StatelessWidget {
  const _Limited(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF4D6),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Color(0xFF8A5A00),
      ),
    ),
  );
}
