import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/format.dart';
import '../../../core/layout.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/alert_banner.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/section_card.dart';
import '../../admin/accounts/account_dialogs.dart' show failureText;
import '../../registration/timetable_screen.dart' show clockProvider;
import '../../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../../training/training_api.dart';
import '../attendance_format.dart';
import 'thiet_bi.dart';
import 'tu_diem_danh_text.dart';

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// GV: chọn lớp → buổi hôm nay → mở phiên tự điểm danh (GPS chốt tâm) → theo dõi thời gian thực,
/// duyệt lượt đáng ngờ, điểm danh thủ công, tính lại tâm, đóng / mở lại (KH §7.2, §7.4).
class GvTuDiemDanhScreen extends ConsumerStatefulWidget {
  const GvTuDiemDanhScreen({super.key});

  @override
  ConsumerState<GvTuDiemDanhScreen> createState() => _GvState();
}

class _GvState extends ConsumerState<GvTuDiemDanhScreen> {
  late final Future<List<Json>> _lop = ref
      .read(trainingApiProvider)
      .listAll('/class-sections/my/');
  int? _lopId;
  Future<List<Json>>? _buoi;
  int? _sessionId;

  Future<List<Json>> _buoiHomNay(int lopId) async {
    final homNay = _ymd(ref.read(clockProvider)());
    final ds = await ref
        .read(trainingApiProvider)
        .listAll('/attendance/sessions/', query: {'lop_hoc_phan': lopId});
    return ds.where((s) => s.str('ngay_hoc') == homNay).toList();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    future: _lop,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: () => setState(() {}));
      final lop = snap.data;
      if (lop == null) return const ListSkeleton();
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              child: SizedBox(
                width: isCompact(context) ? double.infinity : 420,
                child: LabeledDropdown<int?>(
                  label: 'Lớp phụ trách',
                  value: _lopId,
                  options: [
                    (null, '— Chọn lớp —'),
                    for (final l in lop)
                      (l.id, '${l.str('ma_lop')} · ${l.str('ten_mon')}'),
                  ],
                  onChanged: (v) => setState(() {
                    _lopId = v;
                    _sessionId = null;
                    _buoi = v == null ? null : _buoiHomNay(v);
                  }),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_buoi != null)
              FutureBuilder<List<Json>>(
                future: _buoi,
                builder: (context, s) {
                  if (s.hasError) {
                    return ListErrorCard(
                      onRetry: () =>
                          setState(() => _buoi = _buoiHomNay(_lopId!)),
                    );
                  }
                  final ds = s.data;
                  if (ds == null) return const ListSkeleton();
                  if (ds.isEmpty) {
                    return const AlertBanner(
                      kind: BannerKind.info,
                      message: 'Hôm nay lớp này không có buổi học.',
                    );
                  }
                  final id = _sessionId ?? ds.first.id;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ds.length > 1)
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final b in ds)
                              ChoiceChip(
                                label: Text(buoiTiet(b)),
                                selected: b.id == id,
                                onSelected: (_) =>
                                    setState(() => _sessionId = b.id),
                              ),
                          ],
                        ),
                      _Phien(key: ValueKey(id), sessionId: id),
                    ],
                  );
                },
              ),
          ],
        ),
      );
    },
  );
}

/// Một buổi: chưa mở → form mở phiên; đã mở → danh sách thời gian thực.
class _Phien extends ConsumerStatefulWidget {
  const _Phien({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<_Phien> createState() => _PhienState();
}

class _PhienState extends ConsumerState<_Phien> {
  Json? _d;
  Object? _loiTai;
  String? _loi;
  bool _busy = false;
  String _loc = 'tat_ca';
  Timer? _timer;
  int _tick = 0;

  String get _path => '/attendance/sessions/${widget.sessionId}/';
  TrainingApi get _api => ref.read(trainingApiProvider);

  @override
  void initState() {
    super.initState();
    _tai();
    // Đếm ngược mỗi giây; làm mới danh sách mỗi 4 giây khi phiên đang mở (KH §7.4).
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _tick++;
      if (_tick % 4 == 0 && _d?['session']?['dang_mo'] == true) _tai();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tai() async {
    try {
      final d = await _api.get('${_path}tu-diem-danh/');
      if (mounted) setState(() => _d = d);
    } catch (e) {
      if (mounted && _d == null) setState(() => _loiTai = e);
    }
  }

  Future<void> _lam(Future<Object?> Function() call, [String? ok]) async {
    setState(() {
      _busy = true;
      _loi = null;
    });
    try {
      await call();
      await _tai();
      if (ok != null && mounted) showAppToast(context, ok);
    } on ApiFailure catch (f) {
      setState(() => _loi = f.message ?? failureText(f, 'Thao tác thất bại.'));
    } on GpsLoi catch (e) {
      setState(() => _loi = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _datTrangThai(List<int> sv, String tt, [String? ok]) => _lam(
    () => _api.patch('${_path}tu-diem-danh/', {
      'sinh_vien': sv,
      'trang_thai': tt,
    }),
    ok,
  );

  Future<void> _dong() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Đóng phiên điểm danh?',
      message: 'Sinh viên sẽ không tự điểm danh được nữa. Bạn vẫn sửa tay được và mở lại được trong hôm nay.',
      actionLabel: 'Đóng phiên',
    );
    if (ok) {
      await _lam(() => _api.post('${_path}dong-phien/'), 'Đã đóng phiên.');
    }
  }

  Future<void> _moLai() async {
    final phut = await _chonPhut(context, 'Mở lại phiên');
    if (phut == null) return;
    await _lam(
      () => _api.post('${_path}mo-lai/', {'thoi_han': phut}),
      'Đã mở lại phiên.',
    );
  }

  Future<void> _tinhLaiTam() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Tính lại tâm phiên?',
      message:
          'Phần lớn sinh viên đã qua khuôn mặt đang lệch cùng một phía. Tâm mới = vị trí giữa của họ; '
          'kết quả chỉ được nâng lên, không bị hạ.',
      actionLabel: 'Tính lại',
    );
    if (ok) {
      await _lam(
        () => _api.post('${_path}tinh-lai-tam/'),
        'Đã tính lại tâm phiên.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loiTai != null && _d == null) {
      return ListErrorCard(
        onRetry: () {
          setState(() => _loiTai = null);
          _tai();
        },
      );
    }
    final d = _d;
    if (d == null) return const ListSkeleton();
    final s = Json.from(d['session'] as Map);
    final banner = _loi == null
        ? null
        : AlertBanner(kind: BannerKind.error, message: _loi!);
    if (s['mo_luc'] == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?banner,
          const SizedBox(height: 12),
          _MoPhien(
            busy: _busy,
            onMo: (body) => _lam(
              () => _api.post('${_path}mo-phien/', body),
              'Đã mở phiên tự điểm danh.',
            ),
          ),
        ],
      );
    }
    final dangMo = s['dang_mo'] == true;
    final now = ref.read(clockProvider)();
    final hetHan = DateTime.tryParse(s.str('het_han_luc'));
    final dem = Json.from(d['dem'] as Map);
    final rows = [for (final r in d['rows'] as List) Json.from(r as Map)];
    bool chua(Json r) =>
        r.str('trang_thai') != 'CO_MAT' && r['dang_ngo'] != true;
    final hien = rows.where(
      (r) => switch (_loc) {
        'co_mat' => r.str('trang_thai') == 'CO_MAT',
        'dang_ngo' => r['dang_ngo'] == true,
        'chua' => chua(r),
        _ => true,
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        ?banner,
        if (d['goi_y_tinh_lai_tam'] == true) ...[
          const SizedBox(height: 12),
          AlertBanner(
            kind: BannerKind.warning,
            title: 'Tâm phiên có thể bị lệch.',
            message: 'Phần lớn sinh viên đã qua khuôn mặt đang bị "lệch vị trí" về cùng một phía.',
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _busy ? null : _tinhLaiTam,
              child: const Text('Tính lại tâm'),
            ),
          ),
        ],
        const SizedBox(height: 12),
        SectionCard(
          child: Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                dangMo && hetHan != null
                    ? 'Đang mở · còn ${conLai(hetHan, now)}'
                    : 'Đã đóng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: dangMo ? AppColors.success : AppColors.muted,
                ),
              ),
              Text('Có mặt: ${dem.num0('co_mat')}'),
              Text('Đáng ngờ: ${dem.num0('dang_ngo')}'),
              Text('Chưa: ${dem.num0('chua')}'),
              Text(
                'Bán kính ${s.num0('ban_kinh_m')} m · sai số tâm ${(s['tam_sai_so_m'] as num?)?.round() ?? '—'} m',
                style: const TextStyle(color: AppColors.muted),
              ),
              if (dangMo)
                OutlinedButton(
                  onPressed: _busy ? null : _dong,
                  child: const Text('Đóng phiên'),
                )
              else
                OutlinedButton(
                  onPressed: _busy ? null : _moLai,
                  child: const Text('Mở lại'),
                ),
              TextButton(
                onPressed: _busy || !rows.any(chua)
                    ? null
                    : () async {
                        final ok = await showConfirmDialog(
                          context,
                          title: 'Đánh có mặt cho tất cả chưa điểm danh?',
                          message: 'Dùng khi mất mạng hoặc GPS phòng hỏng. Ghi là giảng viên quyết định tay.',
                          actionLabel: 'Đánh có mặt',
                        );
                        if (ok) {
                          await _datTrangThai(
                            [
                              for (final r in rows)
                                if (chua(r)) r.num0('sinh_vien'),
                            ],
                            'CO_MAT',
                            'Đã cập nhật.',
                          );
                        }
                      },
                child: const Text('Tất cả chưa điểm danh → Có mặt'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final (k, t) in [
              ('tat_ca', 'Tất cả'),
              ('co_mat', 'Có mặt'),
              ('dang_ngo', 'Đáng ngờ'),
              ('chua', 'Chưa điểm danh'),
            ])
              ChoiceChip(
                label: Text(t),
                selected: _loc == k,
                onSelected: (_) => setState(() => _loc = k),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SectionCard(
          // ListTile cần Material ngay phía trên để hiện hiệu ứng bấm (SectionCard có nền).
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                for (final r in hien)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r.str('ho_ten')} · ${r.str('ma_sv')}'),
                    subtitle: Text(
                      [
                        if (r['co_mau_mat'] != true) 'Chưa có mẫu mặt',
                        if (r['gv_da_quyet'] == true) 'GV đã quyết',
                        if (r.num0('so_luot') > 0) '${r.num0('so_luot')} lượt',
                        for (final c in (r['luot']?['co'] as List? ?? const []))
                          coText[c] ?? '$c',
                      ].join(' · '),
                    ),
                    trailing: tuDiemDanhChip(
                      r.str('trang_thai'),
                      r['dang_ngo'] == true,
                    ),
                    onTap: () => _chiTiet(r),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _chiTiet(Json r) async {
    final ketQua = await showDialog<(String, int?)>(
      context: context,
      builder: (_) => _ChiTietSv(sessionId: widget.sessionId, row: r),
    );
    if (ketQua == null) return;
    final (tt, luotId) = ketQua;
    if (luotId != null) {
      await _lam(
        () => _api.post('/attendance/attempts/$luotId/quyet/', {
          'co_mat': tt == 'CO_MAT',
        }),
        'Đã cập nhật ${r.str('ho_ten')}.',
      );
    } else {
      await _datTrangThai(
        [r.num0('sinh_vien')],
        tt,
        'Đã cập nhật ${r.str('ho_ten')}.',
      );
    }
  }
}

Future<int?> _chonPhut(BuildContext context, String title) => showDialog<int>(
  context: context,
  builder: (ctx) => AppDialog(
    title: title,
    maxWidth: 360,
    actions: [DialogButton('Hủy', onPressed: () => Navigator.of(ctx).pop())],
    child: Wrap(
      spacing: 8,
      children: [
        for (final p in const [5, 10, 15, 20])
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(p),
            child: Text('$p phút'),
          ),
      ],
    ),
  ),
);

/// Form mở phiên: thời hạn, r₀, mã phòng; lấy GPS của GV ~10 giây rồi gửi.
class _MoPhien extends ConsumerStatefulWidget {
  const _MoPhien({required this.busy, required this.onMo});

  final bool busy;
  final Future<void> Function(Json body) onMo;

  @override
  ConsumerState<_MoPhien> createState() => _MoPhienState();
}

class _MoPhienState extends ConsumerState<_MoPhien> {
  int _phut = 10;
  int _r0 = 20;
  bool _qr = false;
  bool _dangLay = false;
  int _soMau = 0;
  double? _saiSo;

  Future<void> _mo() async {
    setState(() {
      _dangLay = true;
      _soMau = 0;
      _saiSo = null;
    });
    try {
      final mau = await ref.read(layMauGpsProvider)(10, (m) {
        if (mounted) {
          setState(() {
            _soMau++;
            _saiSo = (m['acc'] as num).toDouble();
          });
        }
      });
      await widget.onMo({
        'mau_gps': mau,
        'thoi_han': _phut,
        'r0': _r0,
        'kiem_tra_phong': _qr,
      });
    } on GpsLoi catch (e) {
      if (mounted) showAppToast(context, e.message);
    } finally {
      if (mounted) setState(() => _dangLay = false);
    }
  }

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Mở phiên tự điểm danh',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Đứng trong phòng học, giữ máy yên khoảng 10 giây để chốt vị trí lớp. '
          'Sinh viên chỉ điểm danh được trong bán kính quanh vị trí này.',
          style: TextStyle(color: AppColors.label, height: 1.5),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: [
            SizedBox(
              width: 180,
              child: LabeledDropdown<int>(
                label: 'Thời hạn',
                value: _phut,
                options: [
                  for (final p in const [5, 10, 15, 20, 30]) (p, '$p phút'),
                ],
                onChanged: (v) => setState(() => _phut = v),
              ),
            ),
            SizedBox(
              width: 180,
              child: LabeledDropdown<int>(
                label: 'Bán kính gốc',
                value: _r0,
                options: [
                  for (final r in const [10, 20, 30, 50]) (r, '$r m'),
                ],
                onChanged: (v) => setState(() => _r0 = v),
              ),
            ),
          ],
        ),
        // Material trong suốt: SwitchListTile cần Material ngay phía trên (SectionCard có nền).
        Material(
          color: Colors.transparent,
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _qr,
            onChanged: (v) => setState(() => _qr = v),
            title: const Text('Bắt quét mã phòng (QR)'),
            subtitle: const Text(
              'Chắc chắn đúng phòng; cần chiếu mã lên máy chiếu.',
            ),
          ),
        ),
        if (_dangLay)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Đang lấy GPS… $_soMau mẫu'
              '${_saiSo == null ? '' : ', sai số hiện tại ${_saiSo!.round()} m'}',
            ),
          ),
        AppButton(
          label: 'Lấy vị trí và mở phiên',
          loading: _dangLay || widget.busy,
          onPressed: _mo,
        ),
      ],
    ),
  );
}

/// Chi tiết SV trong phiên: các lượt, cờ, ảnh bằng chứng; GV đặt trạng thái.
/// Trả `(trạng thái, id lượt đáng ngờ được duyệt | null)`.
class _ChiTietSv extends ConsumerWidget {
  const _ChiTietSv({required this.sessionId, required this.row});

  final int sessionId;
  final Json row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final luot = ref
        .read(trainingApiProvider)
        .getList(
          '/attendance/sessions/$sessionId/luot/',
          query: {'sinh_vien': row.num0('sinh_vien')},
        );
    final dangNgo = row['dang_ngo'] == true;
    final luotDangNgo = (row['luot'] as Map?)?['id'] as int?;
    void tra(String tt, [int? id]) => Navigator.of(context).pop((tt, id));
    return AppDialog(
      title: '${row.str('ho_ten')} · ${row.str('ma_sv')}',
      maxWidth: 560,
      actions: [
        DialogButton('Đóng', onPressed: () => Navigator.of(context).pop()),
        if (dangNgo && luotDangNgo != null) ...[
          DialogButton(
            'Từ chối',
            onPressed: () => tra('VANG_KHONG_PHEP', luotDangNgo),
          ),
          DialogButton(
            'Duyệt có mặt',
            filled: true,
            onPressed: () => tra('CO_MAT', luotDangNgo),
          ),
        ] else ...[
          DialogButton('Vắng có phép', onPressed: () => tra('VANG_CO_PHEP')),
          DialogButton('Vắng', onPressed: () => tra('VANG_KHONG_PHEP')),
          DialogButton('Có mặt', filled: true, onPressed: () => tra('CO_MAT')),
        ],
      ],
      child: FutureBuilder<List<Json>>(
        future: luot,
        builder: (context, s) {
          final ds = s.data;
          if (s.hasError) return const Text('Không tải được các lượt.');
          if (ds == null) return const LinearProgressIndicator();
          if (ds.isEmpty) {
            return Text(
              row['co_mau_mat'] == true ? 'Sinh viên chưa gửi lượt nào.' : 'Sinh viên chưa có mẫu khuôn mặt được duyệt — điểm danh thủ công.',
            );
          }
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in ds) ...[
                  Text(
                    '${formatIso(l['tao_luc'] as String?)} · '
                    '${switch (l.str('ket_qua')) {
                      'CO_MAT' => 'Có mặt',
                      'DANG_NGO' => 'Đáng ngờ',
                      _ => 'Không đạt: ${lyDoText[l.str('ly_do')] ?? l.str('ly_do')}',
                    }}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    [
                      if (l['diem_mat'] != null)
                        'mặt ${(l['diem_mat'] as num).toStringAsFixed(2)}',
                      if (l['diem_that'] != null)
                        'người thật ${(l['diem_that'] as num).toStringAsFixed(2)}',
                      if (l['d_m'] != null)
                        'cách ${(l['d_m'] as num).round()} m / r ${(l['r_m'] as num).round()} m',
                      l.str('nen_tang'),
                      for (final c in (l['co'] as List? ?? const []))
                        coText[c] ?? '$c',
                    ].join(' · '),
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  if (l['co_anh_bang_chung'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _AnhBangChung(luotId: l.id),
                    ),
                  const Divider(),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _AnhBangChung extends ConsumerWidget {
  const _AnhBangChung({required this.luotId});

  final int luotId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<Uint8List>(
    future: ref
        .read(apiClientProvider)
        .dio
        .get<List<int>>(
          '/attendance/attempts/$luotId/evidence/',
          options: Options(responseType: ResponseType.bytes),
        )
        .then((r) => Uint8List.fromList(r.data ?? const [])),
    builder: (_, s) => s.hasData
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(s.data!, height: 200),
          )
        : const SizedBox(height: 40, child: Text('Đang tải ảnh bằng chứng…')),
  );
}
