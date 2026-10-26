import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_failure.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/hang_chip.dart';
import '../../shared/widgets/status_chip.dart';
import '../admin/accounts/account_dialogs.dart' show failureText;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart' show PanelCard;
import 'auto_schedule_service.dart';
import 'luoi_tkb_tuan.dart';
import 'bang_lop.dart';
import 'loc_mon.dart';
import 'registration_format.dart'
    show loaiMonText, newIdempotencyKey, thoiGianHoc;

/// Nghỉ giữa hai lần đăng ký liên tiếp để không vượt 30 lần/phút/người dùng (plan mục 8.2).
/// Thay được trong test.
final autoScheduleDelayProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 2200),
);

/// Số thẻ tổ hợp dựng mỗi trang: dựng cả chục thẻ cùng lúc làm màn gợi ý giật.
const _theMoiTrang = 6;

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
  Json _meta = {}; // meta của lần tải gần nhất (ngày học kỳ…)
  late Future<_Data> _data = _fetch();
  int _buoc = 0; // 0 chọn môn · 1 tổ hợp · 2 kết quả
  bool _daChonSan = false;

  // Bước 1
  int _mode = 0; // 0 = tất cả môn đang mở, 1 = theo CTĐT
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
  final _tim = TextEditingController();
  int _kyCtdt = 0; // 0 = tất cả học kỳ trong CTĐT
  int _trang = 0; // trang đang xem (từ 0) của danh sách tổ hợp

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
    _meta = meta;
    return _Data(meta, lop, daDat, lichCoSan, monDaDangKy);
  }

  @override
  void dispose() {
    _tim.dispose();
    super.dispose();
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
      _trang = 0;
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
      _trang = 0;
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
    final hienThi = [
      for (final m in mon)
        // "Theo CTĐT": chỉ môn có trong chương trình đào tạo của mình.
        if ((_mode == 0 || m.kyGoiY != null) &&
            !(_chuaHoc && d.daDat[m.id] == true) &&
            (_kyCtdt == 0 || m.kyGoiY == _kyCtdt) &&
            khopTuKhoa(_tim.text, [m.ten, for (final l in m.lop) l.maLop]))
          m,
    ];
    final cacKy = ({
      for (final m in mon)
        if (m.kyGoiY != null) m.kyGoiY!,
    }.toList()..sort());
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
              LocMon(
                tim: _tim,
                ky: _kyCtdt,
                cacKy: cacKy,
                onTim: (_) => setState(() {}),
                onKy: (k) => setState(() => _kyCtdt = k),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text('Tất cả môn đang mở'),
                    selected: _mode == 0,
                    onSelected: (_) => setState(() => _mode = 0),
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
    // Môn đã đạt: làm mờ để phân biệt với môn còn học được.
    return Opacity(
      opacity: daDat ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          color: _chon.contains(m.id) ? const Color(0xFFF4F6FE) : Colors.white,
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
          title: TieuDeMon(
            ten: m.lop.first.tenMon,
            nhan: [
              StatusChip.of('${m.tinChi} TC', StatusChip.gray),
              StatusChip.of(
                loaiMonText(m.batBuoc ? 'bat_buoc' : 'tu_chon'),
                m.batBuoc ? StatusChip.indigo : StatusChip.yellow,
              ),
              if (daDat) StatusChip.of('Đã đạt', StatusChip.green),
              Text(
                '${m.lop.length} lớp đang mở',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          // Mặc định ExpansionTile căn GIỮA khối nội dung đã co theo chiều rộng → neo sát trái.
          expandedAlignment: Alignment.centerLeft,
          expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: Text(
                'Giáo viên mong muốn',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
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
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _gv[m.id] == null
                    ? 'Để hệ thống tự chọn lớp phù hợp nhất với ưu tiên của bạn.'
                    : 'Lớp của giáo viên đã chọn được ưu tiên xếp.',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 4),
            BangLop(
              dong: [
                for (final l in m.lop)
                  DongLop(
                    maLop: l.maLop,
                    giaoVien: l.giaoVien,
                    lich: l.lichText,
                    phong: l.phong,
                    thoiGian: _thoiGian(d.meta, l),
                    siSo: l.siSo,
                    siSoToiDa: l.siSoToiDa,
                    mo: _gv[m.id] != null && l.giaoVienId != _gv[m.id],
                    nhan: _gv[m.id] != null && l.giaoVienId == _gv[m.id]
                        ? StatusChip.of('Đã chọn', StatusChip.green)
                        : null,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Thời gian học của lớp; lớp chưa có ngày riêng thì theo học kỳ (meta của API).
  String? _thoiGian(Json meta, Lop l) => thoiGianHoc(
    l.ngayBatDau,
    l.ngayKetThuc,
    macDinhBatDau: meta['ngay_bat_dau'],
    macDinhKetThuc: meta['ngay_ket_thuc'],
  );

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
        HangChip(
          muc: [
            for (final (v, nhan) in ngay)
              (
                nhan: nhan,
                chon: tap.contains(v),
                onChon: (b) => setState(() {
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
          HangChip(
            chonMot: true,
            muc: [
              for (final c in Ca.values)
                (
                  nhan: '${c.nhan} (tiết ${c.tietDau}–${c.tietCuoi})',
                  chon: _ca == c,
                  onChon: (b) => setState(() => _ca = b ? c : null),
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
            final soTrang = (_toHop.length / _theMoiTrang).ceil();
            final trang = _trang.clamp(0, soTrang - 1);
            final dau = trang * _theMoiTrang;
            final cuoi = math.min(_toHop.length, dau + _theMoiTrang);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    for (var i = dau; i < cuoi; i++)
                      SizedBox(
                        width: rong ? w.clamp(300, 460).toDouble() : w,
                        child: _theToHop(v, i, _toHop[i]),
                      ),
                  ],
                ),
                if (soTrang > 1) _phanTrang(trang, soTrang, dau, cuoi),
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

  Widget _phanTrang(int trang, int soTrang, int dau, int cuoi) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      children: [
        IconButton(
          tooltip: 'Trang trước',
          onPressed: trang > 0
              ? () => setState(() => _trang = trang - 1)
              : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text(
          'Trang ${trang + 1}/$soTrang · tổ hợp ${dau + 1}–$cuoi trong ${_toHop.length}',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        IconButton(
          tooltip: 'Trang sau',
          onPressed: trang < soTrang - 1
              ? () => setState(() => _trang = trang + 1)
              : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  /// Hộp thoại nổi trên màn hình hiện tại: lưới tuần của tổ hợp [i] — lớp của tổ hợp (mỗi lớp một
  /// màu) + lớp đã đăng ký (xám). Hộp thoại là modal nên dữ liệu không đổi khi đang mở.
  Future<void> _xemTkb(DauVao v, int i) => showDialog<void>(
    context: context,
    builder: (ctx) => AppDialog(
      title: 'Thời khóa biểu — Tổ hợp ${i + 1}',
      maxWidth: 1100,
      actions: [DialogButton('Đóng', onPressed: () => Navigator.of(ctx).pop())],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lịch lặp hằng tuần. Ô xám là các lớp bạn đã đăng ký trong học kỳ.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          LuoiTkbTuan(
            o: [
              for (final b in v.lichCoSan)
                OTkb(
                  thu: b.thu,
                  tietBatDau: b.tietBatDau,
                  tietKetThuc: b.tietKetThuc,
                  tieuDe: 'Đã đăng ký',
                  xam: true,
                ),
              for (final (k, l) in _toHop[i].chon.values.indexed)
                for (final b in l.lich)
                  OTkb(
                    thu: b.thu,
                    tietBatDau: b.tietBatDau,
                    tietKetThuc: b.tietKetThuc,
                    tieuDe: l.tenMon,
                    dong2: '${l.maLop} · ${l.phong}',
                    dong3: 'GV ${l.giaoVien}',
                    mau: k,
                  ),
            ],
          ),
        ],
      ),
    ),
  );

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
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppButton(
              label: 'Xem TKB',
              height: 40,
              outlined: true,
              onPressed: t.chon.isEmpty ? null : () => _xemTkb(v, i),
            ),
          ),
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
          if (_thoiGian(_meta, l) != null)
            Text(
              'Thời gian học: ${_thoiGian(_meta, l)}',
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
          // Điện thoại chỉ hiện nhãn của bước đang làm, các bước khác chỉ còn số — vừa một hàng.
          if (!isCompact(context) || i == buoc)
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
