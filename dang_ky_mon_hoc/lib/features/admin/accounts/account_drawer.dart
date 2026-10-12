import 'package:flutter/material.dart';

import '../../../core/auth/auth_user.dart';
import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/status_chip.dart';
import 'admin_user.dart';

/// Màu chip theo vai trò (mockup `AD-Web-TaiKhoan`).
StatusChip roleChip(UserRole r) => switch (r) {
  UserRole.admin => StatusChip.of('Quản trị', StatusChip.darkGray),
  UserRole.pdt => StatusChip.of('Phòng đào tạo', StatusChip.indigo),
  UserRole.student => StatusChip.of('Sinh viên', StatusChip.teal),
  UserRole.teacher => StatusChip.of('Giáo viên', StatusChip.orange),
  UserRole.accountant => StatusChip.of('Kế toán', StatusChip.yellow),
};

StatusChip lockChip(bool locked) => locked
    ? StatusChip.of('Đang khóa', StatusChip.red)
    : StatusChip.of('Hoạt động', StatusChip.green);

String lastLoginText(AdminUser u) =>
    u.lastLogin == null ? 'Chưa đăng nhập' : formatDateTime(u.lastLogin!);

/// Ngăn chi tiết trượt từ phải (520px): thông tin tài khoản + hồ sơ học vụ chỉ đọc.
Future<void> showAccountDrawer(BuildContext context, AdminUser user) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Đóng',
      barrierColor: const Color(0x5911182C),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, _, _) => Align(
        alignment: Alignment.centerRight,
        child: _Drawer(user: user),
      ),
      transitionBuilder: (ctx, anim, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

class _Drawer extends StatelessWidget {
  const _Drawer({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Material(
      color: Colors.white,
      elevation: 16,
      child: SizedBox(
        width: width < 560 ? width : 520,
        height: double.infinity,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(24, 22, 16, 16),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE3E6EE))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.fullName.isEmpty ? user.username : user.fullName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            roleChip(user.role),
                            lockChip(user.isLocked),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Rows([
                      ('Email', user.email.isEmpty ? '—' : user.email),
                      ('Đăng nhập gần nhất', lastLoginText(user)),
                    ], keyWidth: 150),
                    if (user.profile != null) ...[
                      const Divider(height: 32),
                      const Text(
                        'Hồ sơ học vụ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Rows(user.profileRows, keyWidth: 170, boldValue: true),
                      const SizedBox(height: 16),
                      const _Note(
                        'Chỉ xem. Chỉnh sửa hồ sơ tại Phòng đào tạo.',
                        bg: Color(0xFFE8EAF6),
                        fg: AppColors.primaryDark,
                      ),
                    ],
                    if (user.hasProfile == false) ...[
                      const SizedBox(height: 16),
                      const _Note(
                        'Tài khoản này chưa có hồ sơ học vụ. Phòng đào tạo sẽ tạo hồ sơ.',
                        bg: Color(0xFFFFF1E6),
                        fg: Color(0xFF9A3412),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rows extends StatelessWidget {
  const _Rows(this.rows, {required this.keyWidth, this.boldValue = false});

  final List<(String, String)> rows;
  final double keyWidth;
  final bool boldValue;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (k, v) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: keyWidth,
                  child: Text(
                    k,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    v,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: boldValue ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text, {required this.bg, required this.fg});

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(fontSize: 13, color: fg, height: 1.5)),
    );
  }
}
