import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/auth/auth_user.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/avatar.dart';
import '../../shared/widgets/section_card.dart';
import 'change_password_card.dart';
import 'contact_form.dart';
import 'my_profile.dart';

/// Hồ sơ cá nhân của SV / GV (SV-02, GV-02) — design.md 5.1, 6.1; mockup `SV-*-HoSo`, `*-HoSo`.
/// Khối chỉ đọc (học vụ), khối sửa email/sđt, khối đổi mật khẩu.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);
    return profile.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) =>
          _ErrorState(onRetry: () => ref.invalidate(myProfileProvider)),
      data: (p) => _ProfileBody(profile: p),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: AppColors.muted,
          ),
          const SizedBox(height: 12),
          const Text('Không tải được hồ sơ.'),
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            child: AppButton(label: 'Thử lại', height: 48, onPressed: onRetry),
          ),
        ],
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile});

  final MyProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compact = isCompact(context);
    return LayoutBuilder(
      builder: (context, c) {
        final twoColumns = !compact && c.maxWidth >= 860;
        final info = _infoRows(profile, compact: compact);
        final left = [
          if (compact)
            _CompactIdentity(profile: profile, info: info)
          else
            _WideIdentity(profile: profile, info: info),
          SectionCard(
            title: 'Thông tin liên hệ',
            child: ContactForm(profile: profile),
          ),
        ];
        const password = ChangePasswordCard();
        return SingleChildScrollView(
          child: twoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _spaced(left)),
                    const SizedBox(width: 24),
                    const SizedBox(width: 400, child: password),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _spaced([
                      ...left,
                      password,
                      if (compact)
                        AppButton(
                          label: 'Đăng xuất',
                          outlined: true,
                          onPressed: () => ref
                              .read(authControllerProvider.notifier)
                              .logout(),
                        ),
                    ]),
                  ],
                ),
        );
      },
    );
  }

  Widget _spaced(List<Widget> children) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) const SizedBox(height: 24),
        children[i],
      ],
    ],
  );
}

/// Các dòng thông tin học vụ chỉ đọc theo vai trò (mockup: SV 8 dòng web / 7 dòng app, GV 4 dòng).
List<(String, String)> _infoRows(MyProfile p, {required bool compact}) {
  String orDash(String? v) => (v == null || v.isEmpty) ? '—' : v;
  if (p.role == UserRole.student) {
    final ctdt = p.maCtdt == null
        ? '—'
        : '${p.maCtdt}${p.tongTinChiYeuCau == null ? '' : ' (${p.tongTinChiYeuCau} tín chỉ)'}';
    final tinChi = p.tongTinChiYeuCau == null
        ? '${p.tinChiTichLuy ?? 0}'
        : '${p.tinChiTichLuy ?? 0} / ${p.tongTinChiYeuCau}';
    final gpa = p.gpa == null
        ? 'Chưa có'
        : (compact && p.xepLoai != null ? '${p.gpa} · ${p.xepLoai}' : p.gpa!);
    return [
      ('Mã sinh viên', orDash(p.maSv)),
      ('Ngành', orDash(p.tenNganh)),
      (compact ? 'Khóa' : 'Khóa nhập học', orDash(p.khoaNhapHoc)),
      (compact ? 'CTĐT' : 'Chương trình đào tạo', ctdt),
      ('GPA tích lũy', gpa),
      ('Tín chỉ tích lũy', tinChi),
      if (!compact) ('Xếp loại học lực', orDash(p.xepLoai)),
      ('Tên đăng nhập', p.username),
    ];
  }
  return [
    ('Mã giáo viên', orDash(p.maGv)),
    ('Học vị', orDash(p.hocVi)),
    ('Khoa / viện', orDash(p.khoaBoMon)),
    ('Tên đăng nhập', p.username),
  ];
}

const _readOnlyNote =
    'Thông tin học vụ do Phòng đào tạo quản lý — liên hệ Phòng đào tạo nếu cần chỉnh sửa.';

class _WideIdentity extends StatelessWidget {
  const _WideIdentity({required this.profile, required this.info});

  final MyProfile profile;
  final List<(String, String)> info;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Avatar(
                initials: initialsOf(profile.fullName),
                size: 72,
                soft: true,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RoleChip(profile.role.label),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'THÔNG TIN HỌC VỤ · CHỈ ĐỌC',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.muted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              for (final (k, v) in info)
                SizedBox(
                  width: 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        v,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            _readOnlyNote,
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CompactIdentity extends StatelessWidget {
  const _CompactIdentity({required this.profile, required this.info});

  final MyProfile profile;
  final List<(String, String)> info;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Avatar(initials: initialsOf(profile.fullName), size: 84, soft: true),
        const SizedBox(height: 8),
        Text(
          profile.fullName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        RoleChip(profile.role.label),
        const SizedBox(height: 14),
        SectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'THÔNG TIN HỌC VỤ · CHỈ ĐỌC',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              for (final (k, v) in info)
                Container(
                  padding: const EdgeInsets.only(bottom: 10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.divider),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        k,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.muted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          v,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'Liên hệ Phòng đào tạo nếu cần chỉnh sửa thông tin này.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
