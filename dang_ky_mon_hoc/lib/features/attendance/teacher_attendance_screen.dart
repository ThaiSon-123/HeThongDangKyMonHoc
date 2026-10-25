import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_failure.dart';
import '../../core/download/save_file_provider.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/status_chip.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import '../registration/registration_format.dart';
import '../registration/timetable_screen.dart' show clockProvider;
import '../training/entity_form.dart';
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart' show runAction;
import 'attendance_format.dart';

const _sessionsPath = '/attendance/sessions/';
const _requestsPath = '/attendance/requests/';

class _LopData {
  _LopData(this.sessions, this.tong, this.requests);

  final List<Json> sessions;
  final int tong;
  final List<Json> requests;

  int get choDuyet =>
      requests.where((r) => r.str('trang_thai') == 'CHO_DUYET').length;
}

/// Điểm danh của giáo viên (GV-06..09) — mockup `Web-DiemDanh` / `App-ChonLop`: chọn lớp → các buổi
/// sinh sẵn → điểm danh cả lớp; tab Yêu cầu sửa của sinh viên (duyệt / từ chối).
class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  ConsumerState<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState
    extends ConsumerState<TeacherAttendanceScreen> {
  late Future<List<Json>> _classes = _loadClasses();
  String? _hocKy; // tên học kỳ đang lọc (null = học kỳ mới nhất)
  Json? _lop;
  Future<_LopData>? _data;
  int _tab = 0;
  Json? _session;
  bool _showAll = false;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    // Lối tắt "Điểm danh" ở màn Lớp phụ trách đi kèm ?lop=<id>: chọn sẵn lớp đó.
    final id = int.tryParse(
      GoRouterState.of(context).uri.queryParameters['lop'] ?? '',
    );
    if (id == null) return;
    _classes
        .then((l) {
          final lop = l.where((c) => c.id == id).firstOrNull;
          if (mounted && lop != null) {
            _hocKy = lop.str('ten_hk'); // mở đúng học kỳ của lớp được chọn sẵn
            _pick(lop);
          }
        })
        .catchError((_) {});
  }

  Future<List<Json>> _loadClasses() =>
      ref.read(trainingApiProvider).listAll('/class-sections/my/');

  Future<_LopData> _load(int lopId) async {
    final api = ref.read(trainingApiProvider);
    final sessions = <Json>[];
    var tong = 0;
    for (var page = 1; ; page++) {
      final r = await api.page(
        _sessionsPath,
        page: page,
        query: {'lop_hoc_phan': lopId},
      );
      tong = (r['tong_so_buoi'] as num).toInt();
      final rows = [for (final e in r['results'] as List) Json.from(e as Map)];
      sessions.addAll(rows);
      if (sessions.length >= (r['count'] as num).toInt() || rows.isEmpty) break;
    }
    final requests = await api.listAll(
      _requestsPath,
      query: {'attendance__lop_hoc_phan': lopId},
    );
    return _LopData(sessions, tong, requests);
  }

  void _pick(Json? lop) {
    setState(() {
      _lop = lop;
      _session = null;
      _tab = 0;
      _showAll = false;
      _data = lop == null ? null : _load(lop.id);
    });
  }

  void _reload() {
    final lop = _lop;
    if (lop == null) return;
    final next = _load(lop.id);
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<Json>>(
    future: _classes,
    builder: (context, snap) {
      if (snap.hasError) {
        return ListErrorCard(
          onRetry: () {
            final next = _loadClasses();
            setState(() {
              _classes = next;
            });
          },
        );
      }
      final tatCa = snap.data;
      if (tatCa == null) return const ListSkeleton();
      // Lớp tôi phụ trách xếp mới nhất trước → danh sách học kỳ cũng mới nhất trước.
      final hocKy = {for (final c in tatCa) c.str('ten_hk')}.toList();
      final hk = _hocKy ?? (hocKy.isEmpty ? '' : hocKy.first);
      final classes = [
        for (final c in tatCa)
          if (c.str('ten_hk') == hk) c,
      ];
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _picker(classes, hocKy, hk),
            const SizedBox(height: 16),
            if (_lop == null)
              const _Hint(
                'Chọn lớp để xem các buổi điểm danh',
                'Danh sách buổi học và danh sách sinh viên chỉ hiển thị sau khi bạn chọn lớp học phần ở trên.',
              )
            else
              _detail(),
          ],
        ),
      );
    },
  );

  Widget _picker(
    List<Json> classes,
    List<String> hocKy,
    String hk,
  ) => Container(
    padding: const EdgeInsets.all(16),
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
        // Chọn học kỳ trước, rồi mới chọn lớp của học kỳ đó.
        if (hocKy.length > 1)
          SizedBox(
            width: isCompact(context) ? double.infinity : 300,
            child: LabeledDropdown<String>(
              label: 'Học kỳ',
              value: hk,
              options: [for (final h in hocKy) (h, h)],
              onChanged: (v) {
                setState(() => _hocKy = v);
                _pick(null); // đổi kỳ thì bỏ lớp đang chọn
              },
            ),
          ),
        SizedBox(
          width: isCompact(context) ? double.infinity : 360,
          child: LabeledDropdown<int?>(
            label: 'Lớp học phần',
            value: _lop?.id,
            options: [
              (null, '— Chọn lớp để bắt đầu —'),
              for (final c in classes)
                (c.id, '${c.str('ma_lop')} · ${c.str('ten_mon')}'),
            ],
            onChanged: (id) => _pick(
              id == null ? null : classes.firstWhere((c) => c.id == id),
            ),
          ),
        ),
        if (_lop != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Wrap(
              spacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _lopChip(_lop!.str('trang_thai')),
                Text(
                  '${lichText(_lop!['lich_hoc'] as List)} · ${_lop!.num0('si_so_hien_tai')} sinh viên',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _lopChip(String tt) => switch (tt) {
    'DANG_HOC' => StatusChip.of('Đang học', StatusChip.indigo),
    'MO' => StatusChip.of('Đang mở', StatusChip.green),
    'DA_DONG' => StatusChip.of('Đã đóng', StatusChip.gray),
    _ => StatusChip.of('Kế hoạch', StatusChip.yellow),
  };

  Widget _detail() => FutureBuilder<_LopData>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) return ListErrorCard(onRetry: _reload);
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_lop!.str('trang_thai') == 'DA_DONG') ...[
            const AlertBanner(
              kind: BannerKind.warning,
              message: 'Lớp đã đóng — chỉ xem lịch sử điểm danh.',
            ),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: Text('Các buổi (${d.sessions.length})'),
                selected: _tab == 0,
                onSelected: (_) => setState(() => _tab = 0),
              ),
              ChoiceChip(
                label: Text('Yêu cầu sửa (${d.choDuyet})'),
                selected: _tab == 1,
                onSelected: (_) => setState(() => _tab = 1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _tab == 0 ? _sessions(d) : _requests(d),
        ],
      );
    },
  );

  // ------------------------------------------------------------ các buổi
  bool _due(Json s) =>
      DateTime.parse(s.str('ngay_hoc')).compareTo(_today()) <= 0;

  DateTime _today() {
    final n = ref.read(clockProvider)();
    return DateTime(n.year, n.month, n.day);
  }

  Widget _sessions(_LopData d) {
    final due = d.sessions.where(_due).length;
    final done = d.sessions
        .where((s) => s.str('trang_thai') == 'DA_DIEM_DANH')
        .length;
    final sorted = [...d.sessions]
      ..sort((a, b) => b.str('ngay_hoc').compareTo(a.str('ngay_hoc')));
    final shown = _showAll ? sorted : sorted.take(12).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${d.tong} buổi theo lịch của lớp',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          'Đã đến hạn $due · Đã điểm danh $done · Sắp tới ${d.sessions.length - due}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 10),
        if (d.sessions.isEmpty)
          const _Hint(
            'Lớp chưa có buổi nào',
            'Buổi được sinh sẵn khi lớp mở theo lịch học.',
          ),
        for (final s in shown) ...[
          _sessionTile(s),
          // Bảng điểm danh mở ngay dưới buổi vừa bấm (bấm lại để đóng).
          if (_session?.id == s.id) _roster(),
        ],
        if (!_showAll && sorted.length > shown.length)
          TextButton(
            onPressed: () => setState(() => _showAll = true),
            child: Text('… và ${sorted.length - shown.length} buổi trước đó'),
          ),
        // Buổi đang chọn nằm trong phần "buổi trước đó" còn ẩn: hiện ở cuối để không mất bảng.
        if (_session != null && !shown.any((s) => s.id == _session!.id))
          _roster(),
      ],
    );
  }

  Widget _roster() => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: _Roster(
      key: ValueKey(_session!.id),
      session: _session!,
      onSaved: () {
        _reload();
      },
    ),
  );

  Widget _sessionTile(Json s) {
    final selected = _session?.id == s.id;
    final done = s.str('trang_thai') == 'DA_DIEM_DANH';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _session = selected ? null : s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEEF0FA) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ngayDayDu(s.str('ngay_hoc')),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      buoiTiet(s),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              done
                  ? StatusChip.of('Đã điểm danh', StatusChip.green)
                  : _due(s)
                  ? StatusChip.of('Chưa điểm danh', StatusChip.yellow)
                  : StatusChip.of('Sắp tới', StatusChip.gray),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ yêu cầu sửa
  Widget _requests(_LopData d) {
    if (d.requests.isEmpty) {
      return const _Hint(
        'Chưa có yêu cầu sửa điểm danh',
        'Yêu cầu của sinh viên lớp này sẽ hiện ở đây.',
      );
    }
    return Column(children: [for (final r in d.requests) _requestCard(r)]);
  }

  Future<void> _viewProof(Json r) async {
    final path = r.str('minh_chung').replaceFirst(RegExp(r'^/api'), '');
    try {
      final bytes = await ref.read(trainingApiProvider).getBytes(path);
      await ref.read(saveFileProvider)(
        'minh-chung-${r.id}${_ext(bytes)}',
        bytes,
      );
    } on ApiFailure catch (f) {
      if (mounted) {
        showAppToast(context, failureText(f, 'Không tải được minh chứng.'));
      }
    } on UnsupportedError {
      if (mounted) {
        showAppToast(context, 'Hiện chỉ xem được minh chứng trên bản Web.');
      }
    }
  }

  String _ext(List<int> b) {
    if (b.length > 4 && b[0] == 0x25 && b[1] == 0x50) return '.pdf'; // %P
    if (b.length > 4 && b[0] == 0x89 && b[1] == 0x50) return '.png';
    return '.jpg';
  }

  Future<void> _decide(Json r, {required bool duyet}) async {
    final api = ref.read(trainingApiProvider);
    if (duyet) {
      await runAction(
        context,
        () => api.update(_requestsPath, r.id, {'trang_thai': 'DUYET'}),
        success: 'Đã duyệt, điểm danh được cập nhật.',
        onDone: _reload,
      );
      return;
    }
    final saved = await showEntityForm(
      context,
      title: 'Từ chối yêu cầu',
      saveLabel: 'Từ chối',
      specs: const [
        TextSpec('ghi_chu', 'Ghi chú cho sinh viên', required: false),
      ],
      submit: (body) =>
          api.update(_requestsPath, r.id, {...body, 'trang_thai': 'TU_CHOI'}),
    );
    if (saved && mounted) {
      showAppToast(context, 'Đã từ chối yêu cầu.');
      _reload();
    }
  }

  Widget _requestCard(Json r) {
    final pending = r.str('trang_thai') == 'CHO_DUYET';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r.str('ho_ten')} · ${r.str('ma_sv')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                donChip(r.str('trang_thai')),
              ],
            ),
            Text(
              '${ngayDayDu(r.str('ngay_hoc'))} · ${buoiText(r.str('buoi'))} · gửi ${formatIso(r.str('ngay_gui'))}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            Text('Đổi: ${doiText(r)}', style: const TextStyle(fontSize: 14)),
            Text(
              'Lý do: ${r.str('ly_do')}',
              style: const TextStyle(fontSize: 14, color: AppColors.label),
            ),
            if (r.str('ghi_chu').isNotEmpty)
              Text(
                'Ghi chú: ${r.str('ghi_chu')}',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (r['minh_chung'] != null)
                  OutlinedButton(
                    onPressed: () => _viewProof(r),
                    child: const Text('Xem minh chứng'),
                  )
                else
                  const Text(
                    'Không đính kèm minh chứng',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                if (pending && _lop?.str('trang_thai') == 'DANG_HOC') ...[
                  OutlinedButton(
                    onPressed: () => _decide(r, duyet: false),
                    child: const Text('Từ chối'),
                  ),
                  SizedBox(
                    width: 110,
                    child: AppButton(
                      label: 'Duyệt',
                      height: 40,
                      onPressed: () => _decide(r, duyet: true),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- điểm danh cả lớp
class _Roster extends ConsumerStatefulWidget {
  const _Roster({super.key, required this.session, required this.onSaved});

  final Json session;
  final VoidCallback onSaved;

  @override
  ConsumerState<_Roster> createState() => _RosterState();
}

class _RosterState extends ConsumerState<_Roster> {
  late Future<Json> _future = _fetch();
  final _chon = <int, DiemDanhChon>{};
  final _ghiChu = <int, String>{};
  bool _init = false;
  bool _saving = false;

  Future<Json> _fetch() => ref
      .read(trainingApiProvider)
      .get('$_sessionsPath${widget.session.id}/records/');

  void _seed(Json d) {
    if (_init) return;
    _init = true;
    for (final r in d['records'] as List) {
      final row = Json.from(r as Map);
      _chon[row.num0('sinh_vien')] = DiemDanhChon.of(
        row.str('trang_thai'),
        row['di_tre'] == true,
      );
      _ghiChu[row.num0('sinh_vien')] = row.str('ghi_chu');
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(trainingApiProvider).put(
        '$_sessionsPath${widget.session.id}/records/',
        {
          'records': [
            for (final e in _chon.entries)
              {
                'sinh_vien': e.key,
                'trang_thai': e.value.trangThai,
                'di_tre': e.value.laDiTre,
                'ghi_chu': _ghiChu[e.key] ?? '',
              },
          ],
        },
      );
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

  @override
  Widget build(BuildContext context) => FutureBuilder<Json>(
    future: _future,
    builder: (context, snap) {
      if (snap.hasError) {
        return ListErrorCard(
          onRetry: () {
            final next = _fetch();
            setState(() {
              _future = next;
            });
          },
        );
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      _seed(d);
      final rows = [for (final r in d['records'] as List) Json.from(r as Map)];
      final can = d['co_the_diem_danh'] == true;
      final tong = d.num0('tong_so_buoi');
      int dem(DiemDanhChon c) => _chon.values.where((v) => v == c).length;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppColors.navy,
                  ),
                ),
                if (can)
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
            if (!can) ...[
              const SizedBox(height: 10),
              AlertBanner(
                kind: BannerKind.info,
                message: d.str('lop_trang_thai') != 'DANG_HOC'
                    ? 'Chỉ điểm danh được khi lớp đang học. Bạn đang xem dữ liệu đã lưu.'
                    : d['con_han_sua'] == false
                    ? (d.num0('so_ngay_xin_sua') == 0
                          ? 'Chỉ sửa được điểm danh trong ngày học. Bạn đang xem dữ liệu đã lưu.'
                          : 'Đã quá hạn sửa điểm danh (${d.num0('so_ngay_xin_sua')} ngày kể từ buổi học). Bạn đang xem dữ liệu đã lưu.')
                    : 'Buổi chưa tới ngày học nên chưa điểm danh được.',
              ),
            ],
            const SizedBox(height: 12),
            if (rows.isEmpty)
              const Text(
                'Chưa có sinh viên đăng ký lớp.',
                style: TextStyle(color: AppColors.muted),
              ),
            for (final r in rows) _studentRow(r, tong, can),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final c in DiemDanhChon.values)
                  Text(
                    '${c.label} ${dem(c)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.label,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Lưu điểm danh',
              height: 46,
              loading: _saving,
              onPressed: can && rows.isNotEmpty ? _save : null,
            ),
          ],
        ),
      );
    },
  );

  Widget _studentRow(Json r, int tong, bool can) {
    final id = r.num0('sinh_vien');
    final chon = _chon[id] ?? DiemDanhChon.coMat;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                r.str('ho_ten'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${r.str('ma_sv')} · Vắng KP ${r.num0('so_buoi_vang_kp')}/$tong (${(r['ty_le_vang'] as num).toStringAsFixed(0)}%)',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (r['canh_bao_vang'] == true)
                StatusChip.of('Nguy cơ cấm thi', StatusChip.red),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in DiemDanhChon.values)
                ChoiceChip(
                  label: Text(c.label),
                  selected: chon == c,
                  onSelected: can ? (_) => setState(() => _chon[id] = c) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.title, this.message);

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.muted),
        ),
      ],
    ),
  );
}
