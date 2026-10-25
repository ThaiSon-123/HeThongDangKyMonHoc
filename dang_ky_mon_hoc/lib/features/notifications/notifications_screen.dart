import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/auth/auth_user.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/shell/bell_badge.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/status_chip.dart';
import '../training/entity_form.dart';
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart' show confirmAndRun, runAction;

const _path = '/notifications/';

String _nguoiNhanLabel(Json n) {
  final refs = (n['target_refs'] as List).length;
  return switch (n.str('audience')) {
    'ROLE' =>
      'Vai trò: ${(n['target_refs'] as List).map(_roleLabel).join(', ')}',
    'CLASS' => 'Lớp học phần ($refs)',
    _ => refs == 1 ? 'Một người' : '$refs người',
  };
}

String _roleLabel(Object? r) => switch (r) {
  'ADMIN' => 'Quản trị',
  'PHONG_DAO_TAO' => 'Phòng đào tạo',
  'KE_TOAN' => 'Kế toán',
  'SINH_VIEN' => 'Sinh viên',
  'GIAO_VIEN' => 'Giáo viên',
  _ => '$r',
};

/// Thông báo cho cả 5 vai trò (SV-13, GV-11, PDT-13, KT, ADM-07): hộp thư (đọc/đánh dấu đã đọc), và với
/// vai trò được gửi: soạn gửi theo vai trò / lớp / từng người, xem thông báo đã gửi và thu hồi.
/// Giáo viên chỉ gửi cho lớp mình phụ trách.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _tab = 0; // 0 = hộp thư, 1 = đã gửi
  bool _chuaDoc = false;
  late Future<Json> _inbox = _fetch();
  late Future<Json> _sent = _fetch(gui: true);

  UserRole? get _role => ref.read(authControllerProvider).user?.role;
  bool get _coTheGui => _role != null && _role != UserRole.student;
  bool get _laGv => _role == UserRole.teacher;

  Future<Json> _fetch({bool gui = false}) => ref
      .read(trainingApiProvider)
      .page(
        _path,
        pageSize: 50,
        query: gui ? {'gui': 'true'} : {if (_chuaDoc) 'da_doc': 'false'},
      );

  void _reload() {
    final inbox = _fetch();
    final sent = _fetch(gui: true);
    setState(() {
      _inbox = inbox;
      _sent = sent;
    });
    ref.invalidate(unreadCountProvider);
  }

  Future<void> _read(Json n) async {
    if (n['da_doc'] == true) return;
    await runAction(
      context,
      () => ref.read(trainingApiProvider).patchAction(_path, n.id, 'read', {}),
      success: 'Đã đánh dấu đã đọc.',
      onDone: _reload,
    );
  }

  Future<void> _readAll() => runAction(
    context,
    () => ref.read(trainingApiProvider).create('${_path}read-all/', {}),
    success: 'Đã đánh dấu tất cả đã đọc.',
    onDone: _reload,
  );

  Future<void> _recall(Json n) => confirmAndRun(
    context,
    title: 'Thu hồi thông báo?',
    message:
        'Thông báo “${n.str('tieu_de')}” sẽ biến khỏi hộp thư của người nhận.',
    actionLabel: 'Thu hồi',
    call: () => ref.read(trainingApiProvider).delete(_path, n.id),
    success: 'Đã thu hồi thông báo.',
    onDone: _reload,
  );

  Future<void> _send(String audience) async {
    final api = ref.read(trainingApiProvider);
    final specs = <FieldSpec>[
      switch (audience) {
        'ROLE' => const ChoiceSpec('doi_tuong', 'Vai trò nhận', [
          ('SINH_VIEN', 'Sinh viên'),
          ('GIAO_VIEN', 'Giáo viên'),
          ('PHONG_DAO_TAO', 'Phòng đào tạo'),
          ('KE_TOAN', 'Kế toán'),
          ('ADMIN', 'Quản trị'),
        ]),
        'CLASS' => SelectSpec(
          'doi_tuong',
          'Lớp học phần',
          _laGv ? '/class-sections/my/' : '/class-sections/',
          (c) => '${c.str('ma_lop')} · ${c.str('ten_mon')}',
        ),
        _ => SelectSpec(
          'doi_tuong',
          'Người nhận',
          '${_path}recipients/',
          (u) =>
              '${u.str('full_name').isEmpty ? u.str('username') : u.str('full_name')} (${u.str('username')})',
        ),
      },
      const TextSpec('tieu_de', 'Tiêu đề'),
      const TextSpec('noi_dung', 'Nội dung'),
    ];
    final saved = await showEntityForm(
      context,
      title: switch (audience) {
        'ROLE' => 'Gửi theo vai trò',
        'CLASS' => 'Gửi cho lớp học phần',
        _ => 'Gửi cho một người',
      },
      saveLabel: 'Gửi thông báo',
      specs: specs,
      submit: (body) => api.create(_path, {
        'tieu_de': body['tieu_de'],
        'noi_dung': body['noi_dung'],
        'audience': audience,
        'target_refs': [body['doi_tuong']],
      }),
    );
    if (saved && mounted) {
      showAppToast(context, 'Đã gửi thông báo.');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = isCompact(context);
    Widget tab(int i, String nhan) {
      final chon = _tab == i;
      return InkWell(
        onTap: () => setState(() => _tab = i),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 22,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: chon ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            nhan,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: chon ? AppColors.primary : AppColors.muted,
            ),
          ),
        ),
      );
    }

    final soan = <Widget>[
      if (!_laGv)
        SizedBox(
          width: 190,
          child: AppButton(
            label: '+ Gửi theo vai trò',
            height: 40,
            onPressed: () => _send('ROLE'),
          ),
        ),
      SizedBox(
        width: 190,
        child: AppButton(
          label: '+ Gửi cho lớp',
          height: 40,
          outlined: !_laGv,
          onPressed: _role == UserRole.admin ? null : () => _send('CLASS'),
        ),
      ),
      if (!_laGv)
        SizedBox(
          width: 190,
          child: AppButton(
            label: '+ Gửi cho một người',
            height: 40,
            outlined: true,
            onPressed: () => _send('USER'),
          ),
        ),
    ];
    return SingleChildScrollView(
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_coTheGui)
              Container(
                padding: EdgeInsets.fromLTRB(compact ? 6 : 14, 0, 16, 0),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [tab(0, 'Hộp thư'), tab(1, 'Đã gửi')],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Wrap(spacing: 8, runSpacing: 8, children: soan),
                    ),
                  ],
                ),
              ),
            if (_tab == 0) _inboxView() else _sentView(),
          ],
        ),
      ),
    );
  }

  Widget _trong(String text) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Text(text, style: const TextStyle(color: AppColors.muted)),
    ),
  );

  Widget _inboxView() => FutureBuilder<Json>(
    future: _inbox,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final d = snap.data;
      if (d == null) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: ListSkeleton(),
        );
      }
      final ds = [for (final n in d['results'] as List) Json.from(n as Map)];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text('Tất cả'),
                      selected: !_chuaDoc,
                      onSelected: (_) {
                        _chuaDoc = false;
                        _reload();
                      },
                    ),
                    ChoiceChip(
                      label: const Text('Chưa đọc'),
                      selected: _chuaDoc,
                      onSelected: (_) {
                        _chuaDoc = true;
                        _reload();
                      },
                    ),
                    Text(
                      '${d.num0('chua_doc')} chưa đọc',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: d.num0('chua_doc') == 0 ? null : _readAll,
                  child: const Text('Đánh dấu tất cả đã đọc'),
                ),
              ],
            ),
          ),
          if (ds.isEmpty)
            _trong(
              _chuaDoc
                  ? 'Không có thông báo chưa đọc.'
                  : 'Chưa có thông báo nào.',
            ),
          for (final n in ds) _item(n),
        ],
      );
    },
  );

  Widget _item(Json n) {
    final chua = n['da_doc'] != true;
    final compact = isCompact(context);
    final gio = Text(
      formatIso(n.str('ngay_gui')),
      style: const TextStyle(fontSize: 12, color: AppColors.muted),
    );
    return InkWell(
      onTap: () => _read(n),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 16 : 20,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: chua ? const Color(0xFFF6F7FD) : Colors.white,
          border: const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 12),
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: chua ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                    color: chua ? AppColors.primary : AppColors.border,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          n.str('tieu_de'),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: chua
                                ? FontWeight.w700
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (chua) ...[
                        const SizedBox(width: 8),
                        StatusChip.of('Mới', StatusChip.indigo),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.str('noi_dung'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.label,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Từ ${n.str('nguoi_gui_ten')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                  if (compact) ...[const SizedBox(height: 2), gio],
                ],
              ),
            ),
            if (!compact) ...[const SizedBox(width: 16), gio],
          ],
        ),
      ),
    );
  }

  Widget _sentView() => FutureBuilder<Json>(
    future: _sent,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final d = snap.data;
      if (d == null) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: ListSkeleton(),
        );
      }
      final ds = [for (final n in d['results'] as List) Json.from(n as Map)];
      if (ds.isEmpty) return _trong('Chưa gửi thông báo nào.');
      final compact = isCompact(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final n in ds)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 20,
                vertical: 14,
              ),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.str('tieu_de'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      n.str('trang_thai') == 'THU_HOI'
                          ? StatusChip.of('Đã thu hồi', StatusChip.gray)
                          : StatusChip.of('Đã gửi', StatusChip.green),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    n.str('noi_dung'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.label,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Tới ${_nguoiNhanLabel(n)} · ${formatIso(n.str('ngay_gui'))}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      if (n.str('trang_thai') == 'DA_GUI')
                        OutlinedButton(
                          onPressed: () => _recall(n),
                          child: const Text('Thu hồi'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
