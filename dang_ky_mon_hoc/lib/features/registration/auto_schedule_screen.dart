import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_failure.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/status_chip.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart' show PanelCard, monoStyle;
import 'auto_schedule_service.dart';
import 'registration_format.dart' show loaiMonText, newIdempotencyKey;

/// Nghỉ giữa hai lần đăng ký liên tiếp để không vượt 30 lần/phút/người dùng (plan mục 8.2).
/// Thay được trong test.
final autoScheduleDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 2200),
);

class _Data {
  _Data(this.meta, this.lop, this.daDat, this.lichCoSan, this.monDaDangKy);

  final Json meta;
  final List<Json> lop;
  final Map<int, bool> daDat;
  final List<Buoi> lichCoSan;
  final Set<int> monDaDangKy;

  String get tenHk => meta.str('ten_hk');
  int get tinChiDaDangKy => meta.num0('tin_chi_da_dang_ky');

  /// Trần tín chỉ áp dụng cho SV này (BR-07): thấp hơn nếu bị cảnh báo học vụ.
  int get tran => meta['bi_canh_bao_hoc_vu'] == true
      ? meta.num0('tin_chi_toi_da_canh_bao')
      : meta.num0('tin_chi_toi_da');
}

enum _KQ { cho, dang, ok, loi }

class _Dong {
  _Dong(this.lop, this.ten);

  final Lop lop;
  final String ten;
  _KQ kq = _KQ.cho;
  String? thongBao;
}

/// Tạo TKB tự động (SV-06, **tùy chọn**) — mockup `SV-Web-TKBTuDong` / `SV-App-TKBTuDong`.
/// Gợi ý chạy ở client ([goiY]); đăng ký thật gọi `POST /registrations/` từng môn.
class AutoScheduleScreen extends ConsumerStatefulWidget {
  const AutoScheduleScreen({super.key});

  @override
  ConsumerState<AutoScheduleScreen> createState() => _AutoScheduleScreenState();
}

class _AutoScheduleScreenState extends ConsumerState<AutoScheduleScreen> {
  late Future<_Data> _data = _fetch();
  int _buoc = 0; // 0 chọn môn · 1 tổ hợp · 2 kết quả
  bool _daChonSan = false;

  // Bước 1
  int _mode = 0; // 0 = tất cả môn đang mở, 1 = theo CTĐT
  int? _ky;
  bool _chuaHoc = false;
  final _chon = <int>{};
  final _gv = <int, int>{}; // monId → giáo viên mong muốn
  final _tranh = <int>{};
  final _muon = <int>{};
  Ca? _ca;

  // Bước 2
  DauVao? _dauVao;
  List<ToHop> _toHop = [];
  int? _toHopChon;

  // Bước 3
  List<_Dong> _dong = [];
  bool _dangDangKy = false;

  Future<_Data> _fetch() async {
    final api = ref.read(trainingApiProvider);
    final lop = <Json>[];
    var meta = <String, dynamic>{};
    for (var page = 1; ; page++) {
      final r = await api.page('/auto-schedule/available-courses/', page: page);
      meta = Json.from(r['meta'] as Map);
      final rows = [for (final e in r['results'] as List) Json.from(e as Map)];
      lop.addAll(rows);
      if (lop.length >= (r['count'] as num).toInt() || rows.isEmpty) break;
    }
    final daDat = <int, bool>{};
    try {
      final c = await api.get('/curriculums/my/');
      for (final m in c['mon'] as List) {
        daDat[(m as Map)['mon_hoc'] as int] = m['da_dat'] == true;
      }
    } on ApiFailure {
      // Chưa gán CTĐT: bỏ qua bộ lọc "Môn chưa học".
    }
    final tkb = await api.get('/timetable/my/');
    final lichCoSan = <Buoi>[];
    final monDaDangKy = <int>{};
    for (final l in tkb['lop_hoc_phan'] as List) {
      final j = Json.from(l as Map);
      if (j.num0('hoc_ky') != meta.num0('hoc_ky')) continue;
      monDaDangKy.add(j.num0('mon_hoc'));
      for (final b in j['lich_hoc'] as List) {
        lichCoSan.add(Buoi.fromJson(Json.from(b as Map)));
      }
    }
    return _Data(meta, lop, daDat, lichCoSan, monDaDangKy);
  }

  void _taiLai() {
    final next = _fetch();
    setState(() {
      _data = next;
      _buoc = 0;
      _daChonSan = false;
      _chon.clear();
      _gv.clear();
      _toHop = [];
      _toHopChon = null;
      _dong = [];
    });
  }

  /// Môn của học kỳ: gom lớp theo môn, bỏ môn đã đăng ký (BR-04d) và môn không có lớp.
  List<MonChon> _monChon(_Data d) {
    final nhom = <int, List<Json>>{};
    for (final l in d.lop) {
      if (d.monDaDangKy.contains(l.num0('mon_hoc'))) continue;
      nhom.putIfAbsent(l.num0('mon_hoc'), () => []).add(l);
    }
    return [
      for (final e in nhom.entries)
        MonChon(
          id: e.key,
          ten: e.value.first.str('ten_mon'),
          tinChi: e.value.first.num0('tong_tin_chi'),
          lop: [for (final l in e.value) Lop.fromJson(l)],
          batBuoc: e.value.first.str('loai_mon') == 'bat_buoc',
          kyGoiY: e.value.first['hoc_ky_goi_y'] as int?,
          giaoVienMongMuon: _gv[e.key],
        ),
    ];
  }

  void _chonSan(_Data d, List<MonChon> mon) {
    if (_daChonSan) return;
    _daChonSan = true;
    // Môn bắt buộc theo học kỳ gợi ý được chọn sẵn (trừ môn đã đạt).
    _chon.addAll([
      for (final m in mon)
        if (m.batBuoc && d.daDat[m.id] != true) m.id,
    ]);
  }

  void _goiYTohop(_Data d) {
    final mon = [
      for (final m in _monChon(d))
        if (_chon.contains(m.id)) m,
    ];
    final v = DauVao(
      mon: mon,
      uuTien: UuTien(tranhNgay: {..._tranh}, ngayMuon: {..._muon}, ca: _ca),
      lichCoSan: d.lichCoSan,
      tinChiDaDangKy: d.tinChiDaDangKy,
      tranTinChi: d.tran,
    );
    setState(() {
      _dauVao = v;
      _toHop = goiY(v);
      _toHopChon = null;
      _buoc = 1;
    });
  }

  Future<void> _dangKy() async {
    final t = _toHop[_toHopChon!];
    final dong = [
      for (final l in t.chon.values) _Dong(l, '${l.tenMon} · ${l.maLop}'),
    ];
    final ok = await showConfirmDialog(
      context,
      title: 'Đăng ký tổ hợp này?',
      message:
          'Hệ thống sẽ đăng ký lần lượt ${dong.length} lớp:\n'
          '${dong.map((e) => '• ${e.ten}').join('\n')}\n'
          'Môn nào bị từ chối sẽ không ảnh hưởng các môn đã đăng ký thành công.',
      actionLabel: 'Đăng ký',
    );
    if (!ok || !mounted) return;
    setState(() {
      _dong = dong;
      _buoc = 2;
      _dangDangKy = true;
    });
    final nghi = ref.read(autoScheduleDelayProvider);
    final api = ref.read(trainingApiProvider);
    for (final (i, d) in dong.indexed) {
      if (!mounted) return;
      if (i > 0) await Future<void>.delayed(nghi);
      if (!mounted) return;
      setState(() => d.kq = _KQ.dang);
      try {
        await api.create(
          '/registrations/',
          {'lop_hoc_phan': d.lop.id},
          headers: {'Idempotency-Key': newIdempotencyKey()},
        );
        d.kq = _KQ.ok;
        d.thongBao = 'Đăng ký thành công';
      } on ApiFailure catch (f) {
        d.kq = _KQ.loi;
        d.thongBao = failureText(f, 'Không đăng ký được, vui lòng thử lại.');
      }
      if (mounted) setState(() {});
    }
    if (mounted) setState(() => _dangDangKy = false);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_Data>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) {
        final f = snap.error;
        if (f is ApiFailure && f.fields.containsKey('hoc_ky')) {
          return const AlertBanner(
            kind: BannerKind.warning,
            message: 'Chưa có học kỳ nào đang mở đăng ký.',
          );
        }
        return ListErrorCard(onRetry: _taiLai);
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final mon = _monChon(d);
      _chonSan(d, mon);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Stepper(buoc: _buoc),
            const SizedBox(height: 16),
            switch (_buoc) {
              0 => _buoc1(d, mon),
              1 => _buoc2(d),
              _ => _buoc3(),
            },
          ],
        ),
      );
    },
  );

  // ================================================================ bước 1
  Widget _buoc1(_Data d, List<MonChon> mon) {
    final ky = {
      for (final m in mon)
        if (m.kyGoiY != null) m.kyGoiY!,
    }.toList()..sort();
    final hienThi = [
      for (final m in mon)
        if ((_mode == 0 || _ky == null || m.kyGoiY == _ky) &&
            !(_chuaHoc && d.daDat[m.id] == true))
          m,
    ];
    final tinChi = mon
        .where((m) => _chon.contains(m.id))
        .fold<int>(0, (s, m) => s + m.tinChi);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Chọn môn muốn học',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Text(
                '${d.tenHk} · môn bắt buộc theo học kỳ gợi ý được chọn sẵn',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả môn đang mở'),
                    selected: _mode == 0,
                    onSelected: (_) => setState(() {
                      _mode = 0;
                      _ky = null;
                    }),
                  ),
                  ChoiceChip(
                    label: const Text('Theo CTĐT'),
                    selected: _mode == 1,
                    onSelected: (_) => setState(() => _mode = 1),
                  ),
                  FilterChip(
                    label: const Text('Môn chưa học'),
                    selected: _chuaHoc,
                    onSelected: (v) => setState(() => _chuaHoc = v),
                  ),
                ],
              ),
              if (_mode == 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: 280,
                  child: LabeledDropdown<int?>(
                    label: 'Kỳ trong chương trình đào tạo',
                    value: _ky,
                    options: [
                      (null, 'Tất cả các kỳ'),
                      for (final k in ky) (k, 'Kỳ $k'),
                    ],
                    onChanged: (v) => setState(() => _ky = v),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (hienThi.isEmpty)
                Text(
                  mon.isEmpty
                      ? 'Hiện không có lớp nào để xếp lịch.'
                      : 'Không có môn phù hợp với bộ lọc.',
                  style: const TextStyle(color: AppColors.muted),
                ),
              for (final m in hienThi) _monTile(d, m),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _uuTien(),
        const SizedBox(height: 16),
        PanelCard(
          padding: 16,
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Đã chọn ${_chon.length} môn · $tinChi tín chỉ',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(
                width: 190,
                child: AppButton(
                  label: 'Gợi ý tổ hợp',
                  onPressed: _chon.isEmpty ? null : () => _goiYTohop(d),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _monTile(_Data d, MonChon m) {
    final daDat = d.daDat[m.id] == true;
    final gv = <int, String>{for (final l in m.lop) l.giaoVienId: l.giaoVien};
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        border: Border.all(
          color: _chon.contains(m.id) ? AppColors.primary : AppColors.divider,
          width: _chon.contains(m.id) ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ExpansionTile(
        key: PageStorageKey('tkb-mon-${m.id}'),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Checkbox(
          value: _chon.contains(m.id),
          onChanged: daDat
              ? null
              : (v) => setState(() {
                  v == true ? _chon.add(m.id) : _chon.remove(m.id);
                }),
        ),
        title: Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              m.lop.first.tenMon,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            Text(
              '${m.tinChi} TC',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            StatusChip.of(
              loaiMonText(m.batBuoc ? 'bat_buoc' : 'tu_chon'),
              StatusChip.indigo,
            ),
            if (daDat) StatusChip.of('Đã đạt', StatusChip.green),
            if (m.kyGoiY != null)
              Text(
                'Kỳ ${m.kyGoiY}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
          ],
        ),
        subtitle: Text(
          '${m.lop.length} lớp đang mở',
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Giáo viên mong muốn',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Tự động chọn'),
                selected: _gv[m.id] == null,
                onSelected: (_) => setState(() => _gv.remove(m.id)),
              ),
              for (final e in gv.entries)
                ChoiceChip(
                  label: Text(e.value),
                  selected: _gv[m.id] == e.key,
                  onSelected: daDat
                      ? null
                      : (_) => setState(() {
                          _gv[m.id] = e.key;
                          _chon.add(m.id); // chọn giáo viên thì tự tick môn
                        }),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _gv[m.id] == null
                ? 'Để hệ thống tự chọn lớp phù hợp nhất với ưu tiên của bạn.'
                : 'Lớp của giáo viên đã chọn được ưu tiên xếp.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          for (final l in m.lop) _lopRow(l, _gv[m.id]),
        ],
      ),
    );
  }

  Widget _lopRow(Lop l, int? gvChon) {
    final mo = gvChon != null && l.giaoVienId != gvChon;
    return Opacity(
      opacity: mo ? 0.45 : 1,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.divider)),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(width: 110, child: Text(l.maLop, style: monoStyle)),
            SizedBox(
              width: 150,
              child: Text(l.giaoVien, style: const TextStyle(fontSize: 13)),
            ),
            Text(l.lichText, style: const TextStyle(fontSize: 13)),
            if (gvChon != null && !mo)
              StatusChip.of('Đã chọn', StatusChip.green),
          ],
        ),
      ),
    );
  }

  Widget _uuTien() {
    const ngay = <(int, String)>[
      (2, 'T2'),
      (3, 'T3'),
      (4, 'T4'),
      (5, 'T5'),
      (6, 'T6'),
      (7, 'T7'),
      (8, 'CN'),
    ];
    Widget nhomNgay(
      String tieuDe,
      String chuThich,
      Set<int> tap,
      Set<int> doiLap,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tieuDe, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            for (final (v, nhan) in ngay)
              FilterChip(
                label: Text(nhan),
                selected: tap.contains(v),
                onSelected: (b) => setState(() {
                  if (b) {
                    tap.add(v);
                    doiLap.remove(
                      v,
                    ); // chọn ngày này thì tự bỏ khỏi nhóm đối lập
                  } else {
                    tap.remove(v);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          chuThich,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '2. Ưu tiên cá nhân',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 16),
          nhomNgay(
            'Tránh ngày trong tuần',
            'Chọn các thứ bạn KHÔNG muốn xếp lịch học.',
            _tranh,
            _muon,
          ),
          const SizedBox(height: 16),
          nhomNgay(
            'Ngày muốn học',
            'Hệ thống sẽ ưu tiên xếp các môn vào ngày bạn chọn (vd: chọn Chủ nhật thì các lớp có buổi CN được điểm cao hơn).',
            _muon,
            _tranh,
          ),
          const SizedBox(height: 16),
          const Text(
            'Ca học ưu tiên',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final c in Ca.values)
                ChoiceChip(
                  label: Text('${c.nhan} (tiết ${c.tietDau}–${c.tietCuoi})'),
                  selected: _ca == c,
                  onSelected: (b) => setState(() => _ca = b ? c : null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ================================================================ bước 2
  Widget _buoc2(_Data d) {
    final v = _dauVao!;
    final coToHop = _toHop.isNotEmpty && _toHop.first.chon.isNotEmpty;
    final dangKyDuoc =
        _toHopChon != null && _toHop[_toHopChon!].chon.isNotEmpty;
    final lyDoDau = coToHop
        ? _toHop.first.lyDo.where((l) => l.dat).take(2).map((l) => l.text)
        : const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                coToHop
                    ? 'Có ${_toHop.length} tổ hợp không trùng lịch'
                    : 'Không xếp được tổ hợp nào',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(height: 6),
              if (coToHop && lyDoDau.isNotEmpty)
                Text(
                  'Tổ hợp 1 được điểm cao nhất vì: ${lyDoDau.map((t) => t.replaceFirst(RegExp(r'\.$'), '')).join('; ')}.',
                )
              else if (!coToHop)
                const Text(
                  'Các môn đã chọn đều vướng lịch hoặc vượt giới hạn tín chỉ. '
                  'Hãy bỏ bớt môn hoặc đổi ưu tiên rồi thử lại.',
                ),
              const SizedBox(height: 4),
              const Text(
                'Gợi ý chỉ để tham khảo — chưa đăng ký. Điểm tính theo ưu tiên bạn đã chọn.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 190,
                child: AppButton(
                  label: 'Đổi môn / ưu tiên',
                  height: 40,
                  outlined: true,
                  onPressed: () => setState(() => _buoc = 0),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final rong = box.maxWidth >= 900;
            final w = rong ? (box.maxWidth - 32) / 3 : box.maxWidth;
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final (i, t) in _toHop.indexed)
                  SizedBox(
                    width: rong ? w.clamp(300, 460).toDouble() : w,
                    child: _theToHop(v, i, t),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: isCompact(context) ? double.infinity : 240,
            child: AppButton(
              label: 'Đăng ký tổ hợp đã chọn',
              onPressed: dangKyDuoc ? _dangKy : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _theToHop(DauVao v, int i, ToHop t) {
    final chon = _toHopChon == i;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
        border: Border.all(
          color: chon ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Tổ hợp ${i + 1}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    if (i == 0)
                      StatusChip.of('Điểm cao nhất', StatusChip.orange),
                  ],
                ),
              ),
              Text(
                '${t.diem}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text('/100', style: TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: t.diem / 100,
              minHeight: 8,
              color: AppColors.warning,
              backgroundColor: AppColors.divider,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Vì sao có điểm này',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          for (final l in t.lyDo) _lyDo(l),
          const Divider(height: 24),
          for (final l in t.chon.values) _dongLop(v, t, i, l),
          const SizedBox(height: 8),
          Text(
            'Tổng ${t.tongTinChi} tín chỉ',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: chon ? 'Đã chọn tổ hợp này' : 'Chọn tổ hợp này',
            height: 44,
            outlined: !chon,
            onPressed: t.chon.isEmpty
                ? null
                : () => setState(() => _toHopChon = i),
          ),
        ],
      ),
    );
  }

  Widget _lyDo(LyDo l) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: l.dat ? AppColors.success : AppColors.warning,
          ),
          child: Text(
            l.dat ? '✓' : '!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(l.text, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );

  Widget _dongLop(DauVao v, ToHop t, int i, Lop l) {
    final khac = lopThayThe(v, t, l.monId);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.tenMon,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          Text(
            '${l.maLop} · GV ${l.giaoVien} · ${l.lichText}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (khac.length > 1)
            DropdownButton<int>(
              isDense: true,
              isExpanded: true,
              value: l.id,
              underline: const SizedBox.shrink(),
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
              items: [
                for (final k in khac)
                  DropdownMenuItem(
                    value: k.id,
                    child: Text(
                      '${k.maLop} · ${k.giaoVien} · ${k.lichText}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (id) {
                final moi = khac.firstWhere((k) => k.id == id);
                setState(() {
                  _toHop[i] = danhGia(v, {...t.chon, l.monId: moi});
                });
              },
            ),
        ],
      ),
    );
  }

  // ================================================================ bước 3
  Widget _buoc3() {
    final loi = _dong.any((e) => e.kq == _KQ.loi);
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kết quả đăng ký',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          for (final e in _dong)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 24, child: _bieuTuong(e.kq)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.ten,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          switch (e.kq) {
                            _KQ.cho => 'Đang chờ',
                            _KQ.dang => 'Đang đăng ký…',
                            _ => e.thongBao ?? '',
                          },
                          style: TextStyle(
                            fontSize: 13,
                            color: e.kq == _KQ.loi
                                ? AppColors.danger
                                : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          if (!_dangDangKy) ...[
            const SizedBox(height: 8),
            if (loi)
              const Text(
                'Môn lỗi không làm hủy các môn đã đăng ký thành công. Bạn có thể đăng ký lại môn lỗi ở trang Đăng ký môn học.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 210,
                  child: AppButton(
                    label: 'Xem lớp đã đăng ký',
                    onPressed: () => context.go('/student/register'),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: AppButton(
                    label: 'Làm lại',
                    outlined: true,
                    onPressed: _taiLai,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bieuTuong(_KQ k) => switch (k) {
    _KQ.ok => const Text(
      '✓',
      style: TextStyle(
        color: AppColors.success,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
    ),
    _KQ.loi => const Text(
      '✕',
      style: TextStyle(
        color: AppColors.danger,
        fontWeight: FontWeight.w700,
        fontSize: 18,
      ),
    ),
    _KQ.dang => const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    ),
    _KQ.cho => const Text('•', style: TextStyle(color: AppColors.muted)),
  };
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.buoc});

  final int buoc;

  @override
  Widget build(BuildContext context) {
    const nhan = ['Chọn môn và ưu tiên', 'Xem tổ hợp gợi ý', 'Kết quả đăng ký'];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final (i, n) in nhan.indexed) ...[
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i <= buoc ? AppColors.primary : AppColors.divider,
            ),
            child: Text(
              i < buoc ? '✓' : '${i + 1}',
              style: TextStyle(
                color: i <= buoc ? Colors.white : AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            n,
            style: TextStyle(
              fontWeight: i == buoc ? FontWeight.w700 : FontWeight.w500,
              color: i == buoc ? AppColors.navy : AppColors.muted,
            ),
          ),
          if (i < nhan.length - 1)
            const Text('›', style: TextStyle(color: AppColors.muted)),
        ],
      ],
    );
  }
}
