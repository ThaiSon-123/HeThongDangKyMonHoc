import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_failure.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/format.dart';
import '../../../core/serial/esp32_serial.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/alert_banner.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_dialog.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/labeled_dropdown.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/status_chip.dart';
import '../../admin/accounts/account_dialogs.dart' show failureText;
import '../../registration/timetable_screen.dart' show clockProvider;
import '../../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../../training/training_api.dart';
import '../attendance_format.dart';
import 'tu_diem_danh_text.dart';

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Một buổi của GV: khối tự điểm danh (mở / theo dõi / đóng) + danh sách sinh viên dùng chung
/// (điểm danh tay, cờ đáng ngờ, đơn xin sửa). Gộp "Điểm danh" và "Tự điểm danh" (docs/ke-hoach-gop-diem-danh.md).
///
/// - Phiên đang mở: mỗi lần GV bấm một trạng thái là lưu ngay cho riêng sinh viên đó (`PATCH tu-diem-danh/`),
///   danh sách làm mới mỗi 4 giây; không có nút lưu cả lớp (tránh ghi đè kết quả sinh viên vừa tự điểm danh).
/// - Còn lại: chọn rồi `Lưu điểm danh` cả lớp (`PUT records/`) như điểm danh tay trước đây.
class GvBuoiPanel extends ConsumerStatefulWidget {
  const GvBuoiPanel({
    super.key,
    required this.session,
    required this.donCho,
    required this.onXemDon,
    required this.onSaved,
  });

  final Json session;

  /// Mã SV có đơn xin sửa đang chờ duyệt ở buổi này.
  final Set<String> donCho;
  final VoidCallback onXemDon;
  final VoidCallback onSaved;

  @override
  ConsumerState<GvBuoiPanel> createState() => _GvBuoiPanelState();
}

class _GvBuoiPanelState extends ConsumerState<GvBuoiPanel> {
  Json? _tdd; // GET tu-diem-danh/: phiên, đếm, cờ, lượt
  Json? _rec; // GET records/: tỷ lệ vắng, hạn sửa, quyền điểm danh cả lớp
  Object? _loiTai;
  String? _loi;
  bool _busy = false;
  bool _saving = false;
  bool _dangMoTruoc = false;
  String _loc = 'tat_ca';
  Timer? _timer;
  int _tick = 0;
  final _chon = <int, DiemDanhChon>{};
  final _ghiChu = <int, String>{};

  int get _id => widget.session.id;
  String get _path => '/attendance/sessions/$_id/';
  TrainingApi get _api => ref.read(trainingApiProvider);

  bool get _dangMo => _tdd?['session']?['dang_mo'] == true;

  @override
  void initState() {
    super.initState();
    _taiRec();
    _tai();
    // Đếm ngược mỗi giây; làm mới danh sách mỗi 4 giây khi phiên đang mở (KH §7.4).
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_dangMo) return;
      _tick++;
      if (_tick % 4 == 0) _tai();
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
      if (!mounted) return;
      final dangMo = d['session']?['dang_mo'] == true;
      final hetPhien = _dangMoTruoc && !dangMo;
      setState(() {
        _tdd = d;
        _dangMoTruoc = dangMo;
      });
      // Phiên vừa hết hạn / đóng: sinh viên có thể đã tự điểm danh → tải lại để chọn tay theo dữ liệu mới.
      if (hetPhien) await _taiRec();
    } catch (e) {
      if (mounted && _tdd == null) setState(() => _loiTai = e);
    }
  }

  Future<void> _taiRec() async {
    try {
      final d = await _api.get('${_path}records/');
      if (!mounted) return;
      setState(() {
        _rec = d;
        _chon.clear();
        _ghiChu.clear();
        for (final r in d['records'] as List) {
          final row = Json.from(r as Map);
          _chon[row.num0('sinh_vien')] = DiemDanhChon.of(
            row.str('trang_thai'),
            row['di_tre'] == true,
          );
          _ghiChu[row.num0('sinh_vien')] = row.str('ghi_chu');
        }
      });
    } catch (e) {
      if (mounted && _rec == null) setState(() => _loiTai = e);
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
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _datTrangThai(
    List<int> sv,
    DiemDanhChon c, [
    String? ok,
  ]) => _lam(
    () => _api.patch('${_path}tu-diem-danh/', {
      'sinh_vien': sv,
      'trang_thai': c.trangThai,
      'di_tre': c.laDiTre,
    }),
    ok,
  );

  Future<void> _dong() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Đóng phiên điểm danh?',
      message:
          'Sinh viên sẽ không tự điểm danh được nữa. Bạn vẫn sửa tay được và mở lại được trong hôm nay.',
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

  Future<void> _luu() async {
    setState(() => _saving = true);
    try {
      await _api.put('${_path}records/', {
        'records': [
          for (final e in _chon.entries)
            {
              'sinh_vien': e.key,
              'trang_thai': e.value.trangThai,
              'di_tre': e.value.laDiTre,
              'ghi_chu': _ghiChu[e.key] ?? '',
            },
        ],
      });
      if (!mounted) return;
      showAppToast(
        context,
        'Đã lưu điểm danh cả lớp. Buổi chuyển sang “Đã điểm danh”.',
      );
      widget.onSaved();
    } on ApiFailure catch (f) {
      if (mounted) {
        showAppToast(context, failureText(f, 'Không lưu được điểm danh.'));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Json? _hang(int svId) {
    for (final r in (_tdd?['rows'] as List? ?? const [])) {
      if ((r as Map)['sinh_vien'] == svId) return Json.from(r);
    }
    return null;
  }

  /// Trạng thái đang hiển thị của một SV: phiên mở lấy từ server, còn lại là lựa chọn chưa lưu.
  DiemDanhChon _hienTai(int svId) {
    if (_dangMo) {
      final t = _hang(svId);
      if (t != null) {
        return DiemDanhChon.of(t.str('trang_thai'), t['di_tre'] == true);
      }
    }
    return _chon[svId] ?? DiemDanhChon.coMat;
  }

  Future<void> _chonTrangThai(int svId, DiemDanhChon c) async {
    if (_dangMo) {
      await _datTrangThai([svId], c);
    } else {
      setState(() => _chon[svId] = c);
    }
  }

  bool _chua(Json t) => t.str('trang_thai') == 'VANG_KHONG_PHEP' && t['dang_ngo'] != true;

  @override
  Widget build(BuildContext context) {
    if (_loiTai != null && (_tdd == null || _rec == null)) {
      return ListErrorCard(
        onRetry: () {
          setState(() => _loiTai = null);
          _taiRec();
          _tai();
        },
      );
    }
    final tdd = _tdd;
    final rec = _rec;
    if (tdd == null || rec == null) return const ListSkeleton();
    final s = Json.from(tdd['session'] as Map);
    final moLuc = s['mo_luc'] != null;
    final dangMo = s['dang_mo'] == true;
    final laHomNay =
        widget.session.str('ngay_hoc').substring(0, 10) ==
        _ymd(ref.read(clockProvider)());
    final lopDangHoc = rec.str('lop_trang_thai') == 'DANG_HOC';
    final can = dangMo || rec['co_the_diem_danh'] == true;
    final rows = [for (final r in rec['records'] as List) Json.from(r as Map)];
    final tong = rec.num0('tong_so_buoi');
    final hangTdd = [for (final r in tdd['rows'] as List) Json.from(r as Map)];
    final banner = _loi == null
        ? null
        : AlertBanner(kind: BannerKind.error, message: _loi!);
    final locOk = <int>{
      for (final t in hangTdd)
        if (switch (_loc) {
          'co_mat' => t.str('trang_thai') == 'CO_MAT',
          'dang_ngo' => t['dang_ngo'] == true,
          'chua' => t.str('trang_thai') != 'CO_MAT' && t['dang_ngo'] != true,
          _ => true,
        })
          t.num0('sinh_vien'),
    };
    int dem(DiemDanhChon c) =>
        rows.where((r) => _hienTai(r.num0('sinh_vien')) == c).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?banner,
          if (!moLuc && laHomNay && lopDangHoc)
            _MoPhien(
              busy: _busy,
              onMo: (body) => _lam(
                () => _api.post('${_path}mo-phien/', body),
                'Đã mở phiên tự điểm danh.',
              ),
            ),
          if (moLuc) ..._khoiPhien(tdd, s, dangMo, laHomNay && lopDangHoc, hangTdd),
          const SizedBox(height: 12),
          if (moLuc)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
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
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: AppColors.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      '${ngayDayDu(widget.session.str('ngay_hoc'))} · ${buoiTiet(widget.session)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: AppColors.navy,
                      ),
                    ),
                    if (can && dangMo)
                      TextButton(
                        onPressed: _busy || !hangTdd.any(_chua)
                            ? null
                            : _tatCaChuaCoMat,
                        child: const Text('Tất cả chưa điểm danh → Có mặt'),
                      )
                    else if (can)
                      OutlinedButton(
                        onPressed: () => setState(() {
                          for (final k in _chon.keys) {
                            _chon[k] = DiemDanhChon.coMat;
                          }
                        }),
                        child: const Text('Tất cả có mặt'),
                      ),
                  ],
                ),
                if (dangMo) ...[
                  const SizedBox(height: 10),
                  const AlertBanner(
                    kind: BannerKind.info,
                    message:
                        'Đang có phiên tự điểm danh: mỗi thay đổi được lưu ngay cho sinh viên đó.',
                  ),
                ] else if (!can) ...[
                  const SizedBox(height: 10),
                  AlertBanner(
                    kind: BannerKind.info,
                    message: rec.str('lop_trang_thai') != 'DANG_HOC'
                        ? 'Chỉ điểm danh được khi lớp đang học. Bạn đang xem dữ liệu đã lưu.'
                        : rec['con_han_sua'] == false
                        ? (rec.num0('so_ngay_xin_sua') == 0
                              ? 'Chỉ sửa được điểm danh trong ngày học. Bạn đang xem dữ liệu đã lưu.'
                              : 'Đã quá hạn sửa điểm danh (${rec.num0('so_ngay_xin_sua')} ngày kể từ buổi học). Bạn đang xem dữ liệu đã lưu.')
                        : 'Buổi chưa tới ngày học nên chưa điểm danh được.',
                  ),
                ],
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Text(
                    'Chưa có sinh viên đăng ký lớp.',
                    style: TextStyle(color: AppColors.muted),
                  ),
                for (final r in rows)
                  if (!moLuc || locOk.contains(r.num0('sinh_vien')))
                    _dongSv(r, tong, can),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    for (final c in DiemDanhChon.values)
                      Text(
                        '${c.label} ${dem(c)}',
                        style: TextStyle(fontSize: 13, color: AppColors.label),
                      ),
                  ],
                ),
                if (!dangMo) ...[
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'Lưu điểm danh',
                    height: 46,
                    loading: _saving,
                    onPressed: can && rows.isNotEmpty ? _luu : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _tatCaChuaCoMat() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Đánh có mặt cho tất cả chưa điểm danh?',
      message:
          'Dùng khi mất mạng hoặc GPS phòng hỏng. Ghi là giảng viên quyết định tay.',
      actionLabel: 'Đánh có mặt',
    );
    if (!ok || !mounted) return;
    final ids = [
      for (final t in (_tdd!['rows'] as List).map((e) => Json.from(e as Map)))
        if (_chua(t)) t.num0('sinh_vien'),
    ];
    await _datTrangThai(ids, DiemDanhChon.coMat, 'Đã cập nhật.');
  }

  /// Khối trạng thái phiên: đếm ngược, bộ đếm, đóng / mở lại, gợi ý tính lại tâm.
  List<Widget> _khoiPhien(
    Json tdd,
    Json s,
    bool dangMo,
    bool choPhepDieuKhien,
    List<Json> hang,
  ) {
    final now = ref.read(clockProvider)();
    final hetHan = DateTime.tryParse(s.str('het_han_luc'));
    final dem = Json.from(tdd['dem'] as Map);
    return [
      SectionCard(
        child: Wrap(
          spacing: 24,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              dangMo && hetHan != null
                  ? 'Tự điểm danh đang mở · còn ${conLai(hetHan, now)}'
                  : 'Tự điểm danh đã đóng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: dangMo ? AppColors.success : AppColors.muted,
              ),
            ),
            Text('Có mặt: ${dem.num0('co_mat')}'),
            Text('Đáng ngờ: ${dem.num0('dang_ngo')}'),
            Text('Chưa: ${dem.num0('chua')}'),
            if (choPhepDieuKhien)
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
          ],
        ),
      ),
      if (dangMo && s['kiem_tra_phong'] == true) ...[
        const SizedBox(height: 12),
        _MaPhong(key: ValueKey('ma-phong-$_id'), path: _path),
      ],
    ];
  }

  Widget _dongSv(Json r, int tong, bool can) {
    final id = r.num0('sinh_vien');
    final chon = _hienTai(id);
    final t = _hang(id);
    final coDon = widget.donCho.contains(r.str('ma_sv'));
    final tag = [
      if (t != null && t['co_mau_mat'] != true && _tdd?['session']?['mo_luc'] != null)
        'Chưa có mẫu mặt',
      if (t != null && t['gv_da_quyet'] == true) 'GV đã quyết',
      if (t != null && t.num0('so_luot') > 0) '${t.num0('so_luot')} lượt',
      for (final c in (t?['luot']?['co'] as List? ?? const [])) coText[c] ?? '$c',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                r.str('ho_ten'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${r.str('ma_sv')} · Vắng KP ${r.num0('so_buoi_vang_kp')}/$tong (${(r['ty_le_vang'] as num).toStringAsFixed(0)}%)',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (r['canh_bao_vang'] == true)
                StatusChip.of('Nguy cơ cấm thi', StatusChip.red),
              if (t != null && t['dang_ngo'] == true)
                tuDiemDanhChip(t.str('trang_thai'), true),
              if (coDon)
                ActionChip(
                  label: const Text('Có đơn chờ duyệt'),
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.onXemDon,
                ),
            ],
          ),
          if (tag.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                tag.join(' · '),
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final c in DiemDanhChon.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: chon == c && t?['dang_ngo'] != true,
                  onSelected: can && !_busy
                      ? (_) => _chonTrangThai(id, c)
                      : null,
                ),
              if (t != null && (t.num0('so_luot') > 0 || t['dang_ngo'] == true))
                TextButton(
                  onPressed: () => _chiTiet(t, can),
                  child: const Text('Xem lượt'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _chiTiet(Json t, bool choPhepSua) async {
    final ketQua = await showDialog<(String, int?)>(
      context: context,
      builder: (_) =>
          _ChiTietSv(sessionId: _id, row: t, choPhepSua: choPhepSua),
    );
    if (ketQua == null) return;
    final (tt, luotId) = ketQua;
    if (luotId != null) {
      await _lam(
        () => _api.post('/attendance/attempts/$luotId/quyet/', {
          'co_mat': tt == 'CO_MAT',
        }),
        'Đã cập nhật ${t.str('ho_ten')}.',
      );
    } else {
      await _datTrangThai(
        [t.num0('sinh_vien')],
        DiemDanhChon.of(tt, false),
        'Đã cập nhật ${t.str('ho_ten')}.',
      );
    }
    // Duyệt / quyết tay khi phiên không mở: dữ liệu cả lớp đã đổi → tải lại bảng chọn.
    if (!_dangMo) await _taiRec();
  }
}

/// Mã phòng đang hiệu lực (đổi mỗi 30 giây) và đẩy xuống ESP32 qua Web Serial để phát BLE
/// (docs/ke-hoach-gps-khuon-vien-va-esp32.md §4.2). Không cắm ESP32 thì GV đọc mã cho lớp gõ tay.
class _MaPhong extends ConsumerStatefulWidget {
  const _MaPhong({super.key, required this.path});

  final String path;

  @override
  ConsumerState<_MaPhong> createState() => _MaPhongState();
}

class _MaPhongState extends ConsumerState<_MaPhong> {
  final _esp = Esp32Serial();
  String? _ma;
  String? _loi;
  Timer? _doiMa; // lấy mã mới khi mã cũ hết hạn
  Timer? _guiLai;

  @override
  void initState() {
    super.initState();
    _layMa();
    // Mở cổng có thể làm ESP32 khởi động lại và bỏ lỡ lần gửi đầu → gửi lại mã đang có mỗi 5 giây.
    _guiLai = Timer.periodic(const Duration(seconds: 5), (_) => _gui());
  }

  @override
  void dispose() {
    _doiMa?.cancel();
    _guiLai?.cancel();
    _esp.dong();
    super.dispose();
  }

  void _hen(int ms) {
    _doiMa?.cancel();
    _doiMa = Timer(Duration(milliseconds: ms), _layMa);
  }

  Future<void> _layMa() async {
    try {
      final d = await ref
          .read(trainingApiProvider)
          .get('${widget.path}room-token/');
      if (!mounted) return;
      setState(() {
        _ma = d.str('ma');
        _loi = null;
      });
      _gui();
      _hen(((d['het_han_sau_giay'] as num) * 1000).round() + 300);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loi = 'Không lấy được mã phòng, đang thử lại…');
      _hen(3000);
    }
  }

  Future<void> _gui() async {
    final ma = _ma;
    if (ma == null || !_esp.daKetNoi) return;
    try {
      await _esp.gui(ma);
    } catch (_) {
      if (mounted) {
        setState(
          () => _loi = 'Mất kết nối ESP32. Cắm lại rồi bấm "Kết nối ESP32".',
        );
      }
    }
  }

  Future<void> _ketNoi() async {
    try {
      await _esp.ketNoi();
    } catch (e) {
      // NotFoundError = GV bấm Hủy trong hộp chọn cổng.
      if (mounted && !'$e'.contains('NotFoundError')) {
        setState(() => _loi = 'Không mở được cổng ESP32: $e');
      }
      return;
    }
    if (!mounted) return;
    setState(() => _loi = null);
    await _gui();
  }

  Future<void> _ngat() async {
    await _esp.dong();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final ma = _ma;
    return SectionCard(
      title: 'Mã phòng',
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SelectableText(
            ma == null || ma.length != 8
                ? (ma ?? '—')
                : '${ma.substring(0, 4)} ${ma.substring(4)}',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 4,
            ),
          ),
          if (Esp32Serial.hoTro)
            if (_esp.daKetNoi)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bluetooth, color: AppColors.success),
                  const SizedBox(width: 6),
                  const Text('ESP32 đang phát mã'),
                  TextButton(onPressed: _ngat, child: const Text('Ngắt')),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _ketNoi,
                icon: const Icon(Icons.usb),
                label: const Text('Kết nối ESP32'),
              ),
          if (_loi != null)
            Text(_loi!, style: TextStyle(color: AppColors.danger)),
        ],
      ),
    );
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

/// Form mở phiên: thời hạn và có bắt mã phòng (ESP32) hay không.
class _MoPhien extends ConsumerStatefulWidget {
  const _MoPhien({required this.busy, required this.onMo});

  final bool busy;
  final Future<void> Function(Json body) onMo;

  @override
  ConsumerState<_MoPhien> createState() => _MoPhienState();
}

class _MoPhienState extends ConsumerState<_MoPhien> {
  int _phut = 10;
  bool _qr = false;
  bool _gps = true;

  @override
  Widget build(BuildContext context) => SectionCard(
    title: 'Mở phiên tự điểm danh',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Khuôn mặt luôn được kiểm tra. GPS (trong khuôn viên) và ESP32 (trong phòng) '
          'bật hoặc tắt riêng từng cái.',
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
          ],
        ),
        // Material trong suốt: SwitchListTile cần Material ngay phía trên (SectionCard có nền).
        Material(
          color: Colors.transparent,
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _gps,
                onChanged: (v) => setState(() => _gps = v),
                title: const Text('Kiểm tra GPS'),
                subtitle: const Text(
                  'Sinh viên phải ở trong khuôn viên trường (Phòng đào tạo vẽ ở mục Quy chế).',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _qr,
                onChanged: (v) => setState(() => _qr = v),
                title: const Text('Bắt mã phòng (ESP32)'),
                subtitle: const Text(
                  'Mã đổi mỗi 30 giây; sinh viên đọc từ ESP32 (cắm vào máy này) hoặc gõ tay mã hiện trên màn.',
                ),
              ),
            ],
          ),
        ),
        AppButton(
          label: 'Mở phiên',
          loading: widget.busy,
          onPressed: () => widget.onMo({
            'thoi_han': _phut,
            'kiem_tra_phong': _qr,
            'kiem_tra_gps': _gps,
          }),
        ),
      ],
    ),
  );
}

/// Chi tiết SV trong phiên: các lượt, cờ, ảnh bằng chứng; GV đặt trạng thái.
/// Trả `(trạng thái, id lượt đáng ngờ được duyệt | null)`.
class _ChiTietSv extends ConsumerWidget {
  const _ChiTietSv({
    required this.sessionId,
    required this.row,
    required this.choPhepSua,
  });

  final int sessionId;
  final Json row;

  /// Sửa được trong hạn (phiên đang mở hoặc buổi còn trong hạn sửa); không thì chỉ xem.
  final bool choPhepSua;

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
        if (!choPhepSua) ...[] else if (dangNgo && luotDangNgo != null) ...[
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
                        'ngoài khuôn viên ${(l['d_m'] as num).round()} m / cho phép ${(l['r_m'] as num).round()} m',
                      l.str('nen_tang'),
                      for (final c in (l['co'] as List? ?? const []))
                        coText[c] ?? '$c',
                    ].join(' · '),
                    style: TextStyle(color: AppColors.muted),
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
