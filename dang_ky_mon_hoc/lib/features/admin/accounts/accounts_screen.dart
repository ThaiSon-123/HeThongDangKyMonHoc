import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/labeled_field.dart';
import '../../../shared/widgets/status_chip.dart';
import 'account_dialogs.dart';
import 'account_drawer.dart';
import 'accounts_repository.dart';
import 'admin_user.dart';

/// Quản lý tài khoản (ADM-02) — mockup `AD-Web-TaiKhoan`: bộ lọc, bảng, bật/tắt khóa,
/// sửa, đặt lại mật khẩu, tạo mới, ngăn chi tiết.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(accountsFilterProvider.notifier).setSearch(v);
    });
  }

  void _refresh() => ref.invalidate(accountsProvider);

  Future<void> _create() async {
    final username = await showDialog<String>(
      context: context,
      builder: (_) => const CreateAccountDialog(),
    );
    if (username == null || !mounted) return;
    _refresh();
    showAppToast(context, 'Đã tạo tài khoản $username.');
  }

  Future<void> _edit(AdminUser u) async {
    final isSelf = ref.read(authControllerProvider).user?.id == '${u.id}';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => EditAccountDialog(user: u, isSelf: isSelf),
    );
    if (ok != true || !mounted) return;
    _refresh();
    showAppToast(context, 'Đã cập nhật tài khoản.');
  }

  Future<void> _resetPassword(AdminUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => ResetPasswordDialog(user: u),
    );
    if (ok != true || !mounted) return;
    showAppToast(context, 'Đã đặt lại mật khẩu cho ${u.username}.');
  }

  Future<void> _toggleLock(AdminUser u) async {
    final unlock = u.isLocked;
    final ok = await showConfirmDialog(
      context,
      title: unlock ? 'Mở khóa tài khoản?' : 'Khóa tài khoản?',
      message: unlock
          ? 'Mở khóa ${u.username}? Người dùng có thể đăng nhập lại.'
          : 'Khóa ${u.username}? Người dùng sẽ bị chặn đăng nhập, kể cả phiên đang đăng nhập.',
      actionLabel: unlock ? 'Mở khóa' : 'Khóa tài khoản',
      danger: !unlock,
    );
    if (!ok || !mounted) return;
    try {
      await ref.read(accountsRepositoryProvider).setLocked(u.id, !unlock);
      if (!mounted) return;
      _refresh();
      showAppToast(
        context,
        unlock ? 'Đã mở khóa ${u.username}.' : 'Đã khóa ${u.username}.',
      );
    } on ApiFailure catch (f) {
      if (mounted) {
        showAppToast(
          context,
          failureText(f, 'Không thể đổi trạng thái tài khoản.'),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(accountsFilterProvider);
    final accounts = ref.watch(accountsProvider);
    final meId = ref.watch(authControllerProvider).user?.id;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            controller: _search,
            filter: filter,
            onSearch: _onSearch,
            onCreate: _create,
          ),
          const SizedBox(height: 24),
          accounts.when(
            loading: () => const _Skeleton(),
            error: (_, _) => _ErrorCard(onRetry: _refresh),
            data: (page) => _TableCard(
              page: page,
              filter: filter,
              meId: meId,
              onRow: (u) => showAccountDrawer(context, u),
              onEdit: _edit,
              onReset: _resetPassword,
              onToggle: _toggleLock,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Bộ lọc
class _FilterBar extends ConsumerWidget {
  const _FilterBar({
    required this.controller,
    required this.filter,
    required this.onSearch,
    required this.onCreate,
  });

  final TextEditingController controller;
  final AccountsFilter filter;
  final ValueChanged<String> onSearch;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(accountsFilterProvider.notifier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 300,
            child: LabeledField(
              label: 'Tìm tài khoản',
              controller: controller,
              hint: 'Tên đăng nhập hoặc email',
              onChanged: onSearch,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Vai trò',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.label,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _RoleChipButton(
                    label: 'Tất cả',
                    on: filter.role == null,
                    onTap: () => notifier.setRole(null),
                  ),
                  for (final (r, label) in accountRoleOptions)
                    _RoleChipButton(
                      label: label,
                      on: filter.role == r,
                      onTap: () => notifier.setRole(r),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(
            width: 190,
            child: LabeledDropdown<bool?>(
              label: 'Trạng thái',
              value: filter.locked,
              options: const [
                (null, 'Tất cả'),
                (false, 'Hoạt động'),
                (true, 'Đang khóa'),
              ],
              onChanged: notifier.setLocked,
            ),
          ),
          SizedBox(
            width: 160,
            child: AppButton(
              label: '+ Tạo tài khoản',
              height: 44,
              onPressed: onCreate,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleChipButton extends StatelessWidget {
  const _RoleChipButton({
    required this.label,
    required this.on,
    required this.onTap,
  });

  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: on ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: on ? AppColors.primary : AppColors.border,
            ),
          ),
          // widthFactor: ôm vừa nhãn (Container có `alignment` sẽ nở hết chiều rộng Wrap).
          child: Center(
            widthFactor: 1,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: on ? Colors.white : AppColors.label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- Bảng
const _colWidths = [130.0, 150.0, 200.0, 130.0, 130.0, 150.0, 150.0, 190.0];

class _TableCard extends StatelessWidget {
  const _TableCard({
    required this.page,
    required this.filter,
    required this.meId,
    required this.onRow,
    required this.onEdit,
    required this.onReset,
    required this.onToggle,
  });

  final PageResult<AdminUser> page;
  final AccountsFilter filter;
  final String? meId;
  final ValueChanged<AdminUser> onRow;
  final ValueChanged<AdminUser> onEdit;
  final ValueChanged<AdminUser> onReset;
  final ValueChanged<AdminUser> onToggle;

  @override
  Widget build(BuildContext context) {
    final pages = page.pages(AccountsFilter.pageSize);
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
          LayoutBuilder(
            builder: (context, c) {
              final width = math.max(c.maxWidth, 1250.0);
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      const _HeaderRow(),
                      for (final u in page.items)
                        _UserRow(
                          user: u,
                          isSelf: meId == '${u.id}',
                          onTap: () => onRow(u),
                          onEdit: () => onEdit(u),
                          onReset: () => onReset(u),
                          onToggle: () => onToggle(u),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (page.items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Center(
                child: Text(
                  'Không có tài khoản phù hợp với bộ lọc.',
                  style: TextStyle(fontSize: 14, color: AppColors.muted),
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  '${page.count} bản ghi',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                _Pager(filter: filter, pages: pages),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pager extends ConsumerWidget {
  const _Pager({required this.filter, required this.pages});

  final AccountsFilter filter;
  final int pages;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(accountsFilterProvider.notifier);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Trang trước',
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: filter.page > 1
              ? () => notifier.setPage(filter.page - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          'Trang ${filter.page}/$pages · ${AccountsFilter.pageSize} dòng/trang',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        IconButton(
          tooltip: 'Trang sau',
          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          onPressed: filter.page < pages
              ? () => notifier.setPage(filter.page + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

Widget _cell(int i, Widget child) => i == 1 || i == 2
    ? Expanded(flex: i == 1 ? 3 : 4, child: child)
    : SizedBox(width: _colWidths[i], child: child);

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  static const _titles = [
    'Tên đăng nhập',
    'Họ tên',
    'Email',
    'Vai trò',
    'Hồ sơ',
    'Trạng thái',
    'Đăng nhập gần nhất',
    '',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          for (var i = 0; i < _titles.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            _cell(
              i,
              Text(
                _titles[i].toUpperCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isSelf,
    required this.onTap,
    required this.onEdit,
    required this.onReset,
    required this.onToggle,
  });

  final AdminUser user;
  final bool isSelf;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onReset;
  final VoidCallback onToggle;

  Widget _profileCell() {
    switch (user.hasProfile) {
      case null:
        return const Text('—', style: TextStyle(color: AppColors.border));
      case true:
        return const Text(
          '✓ Đã có',
          style: TextStyle(
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
        );
      case false:
        return const Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(
            'Chưa có hồ sơ',
            bg: Color(0xFFFFF1E6),
            fg: Color(0xFF9A3412),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      Text(
        user.username,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          fontFamily: 'monospace',
        ),
      ),
      Text(user.fullName, overflow: TextOverflow.ellipsis),
      Text(
        user.email,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13, color: AppColors.label),
      ),
      Align(alignment: Alignment.centerLeft, child: roleChip(user.role)),
      _profileCell(),
      Row(
        children: [
          Semantics(
            label: 'Trạng thái tài khoản ${user.username}',
            child: Switch(
              value: !user.isLocked,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              activeTrackColor: const Color(0xFF2E9D5B),
              inactiveTrackColor: AppColors.border,
              inactiveThumbColor: Colors.white,
              activeThumbColor: Colors.white,
              trackOutlineColor: const WidgetStatePropertyAll(
                Colors.transparent,
              ),
              // Không tự khóa chính mình (backend cũng chặn).
              onChanged: isSelf ? null : (_) => onToggle(),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              user.isLocked ? 'Đang khóa' : 'Hoạt động',
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      Text(
        lastLoginText(user),
        style: const TextStyle(fontSize: 13, color: AppColors.label),
      ),
      // Hai nút co lại vừa cột (không bao giờ tràn), canh phải.
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SmallButton('Sửa', onEdit),
            const SizedBox(width: 8),
            _SmallButton('Đặt lại MK', onReset),
          ],
        ),
      ),
    ];
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: user.isLocked ? const Color(0xFFFFF8F8) : Colors.white,
          border: const Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              if (i > 0) const SizedBox(width: 16),
              _cell(i, cells[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton(this.label, this.onPressed);

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(color: Color(0xFFC4C9D4)),
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}

// ------------------------------------------------------- Đang tải / lỗi tải
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double h, [double? w]) => Container(
      height: h,
      width: w,
      decoration: BoxDecoration(
        color: const Color(0xFFECEFF5),
        borderRadius: BorderRadius.circular(10),
      ),
    );
    return Semantics(
      label: 'Đang tải dữ liệu',
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            bar(20, 220),
            for (var i = 0; i < 5; i++) ...[
              const SizedBox(height: 14),
              bar(44),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 56, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFFDECEA),
            ),
            child: const Text(
              '!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: AppColors.danger,
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Không tải được dữ liệu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Kết nối bị gián đoạn hoặc máy chủ đang bận. Hãy thử lại sau ít giây.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: 140,
            child: AppButton(label: 'Thử lại', height: 44, onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}
