import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/status_chip.dart';
import '../reports/report_widgets.dart' show StatCard;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart';
import '../../core/api/api_failure.dart';
import 'registration_format.dart' show khoiText, loaiMonText;

enum TrangThaiMon { daDat, chuaDat, dangHoc, chuaHoc }

extension TrangThaiMonX on TrangThaiMon {
  String get nhan => switch (this) {
    TrangThaiMon.daDat => 'Đã đạt',
    TrangThaiMon.chuaDat => 'Chưa đạt (F)',
    TrangThaiMon.dangHoc => 'Đang học',
    TrangThaiMon.chuaHoc => 'Chưa học',
  };

  (Color, Color) get mau => switch (this) {
    TrangThaiMon.daDat => StatusChip.green,
    TrangThaiMon.chuaDat => StatusChip.red,
    TrangThaiMon.dangHoc => StatusChip.indigo,
    TrangThaiMon.chuaHoc => StatusChip.gray,
  };
}

/// Một môn của CTĐT kèm trạng thái cá nhân của sinh viên.
class MonCtdt {
  MonCtdt({
    required this.ma,
    required this.ten,
    required this.tinChi,
    required this.khoi,
    required this.loai,
    required this.ky,
    required this.tienQuyet,
    required this.trangThai,
    this.diem,
  });

  final String ma;
  final String ten;
  final int tinChi;
  final String khoi;
  final String loai;
  final int ky;
  final List<String> tienQuyet;
  final TrangThaiMon trangThai;

  /// Điểm tổng kết chính thức (`KHOA`), `P` cho môn đạt/không đạt, null nếu chưa có.
  final String? diem;
}

/// Gộp CTĐT (`curriculums/my`) + điểm chính thức (`grades/my`) + đăng ký (`registrations/history`)
/// thành danh sách môn có trạng thái cá nhân (design.md 5.2).
///
/// Thứ tự ưu tiên: *Đã đạt* (server `da_dat`, BR-04) › *Đang học* (đã đăng ký lớp `MO`/`DANG_HOC`, kể cả
/// học lại môn F) › *Chưa đạt (F)* › *Chưa học*.
List<MonCtdt> gopMonCtdt(Json ctdt, Json grades, List<Json> dangKy) {
  // Lần học mới nhất của từng môn = dòng điểm có học kỳ lớn nhất.
  final diem = <String, Json>{};
  for (final d in (grades['diem'] as List? ?? const [])) {
    final j = Json.from(d as Map);
    final cu = diem[j.str('ma_mon')];
    if (cu == null || j.num0('hoc_ky') >= cu.num0('hoc_ky')) {
      diem[j.str('ma_mon')] = j;
    }
  }
  final dangHoc = {
    for (final r in dangKy)
      if (r.str('trang_thai') == 'DA_DANG_KY' &&
          const ['MO', 'DANG_HOC'].contains(r.str('lop_trang_thai')))
        r.str('ma_mon'),
  };
  return [
    for (final m in (ctdt['mon'] as List))
      () {
        final j = Json.from(m as Map);
        final d = diem[j.str('ma_mon')];
        final daDat = j['da_dat'] == true;
        final trangThai = daDat
            ? TrangThaiMon.daDat
            : dangHoc.contains(j.str('ma_mon'))
            ? TrangThaiMon.dangHoc
            : d != null && d.str('diem_chu') == 'F'
            ? TrangThaiMon.chuaDat
            : TrangThaiMon.chuaHoc;
        String? diemHienThi;
        if (d != null) {
          diemHienThi = d.str('diem_chu') == 'P'
              ? 'P'
              : (double.tryParse(d.str('diem_tong_ket'))?.toStringAsFixed(2));
        }
        return MonCtdt(
          ma: j.str('ma_mon'),
          ten: j.str('ten_mon'),
          tinChi: j.num0('tong_tin_chi'),
          khoi: j.str('khoi_kien_thuc'),
          loai: j.str('loai_mon'),
          ky: j.num0('hoc_ky_goi_y'),
          tienQuyet: [
            for (final t in (j['tien_quyet'] as List? ?? const [])) '$t',
          ],
          trangThai: trangThai,
          diem: diemHienThi,
        );
      }(),
  ];
}

/// Năm học của kỳ thứ [ky] (1 = HK1 năm nhất) theo khóa tuyển sinh `K2023`/`2023`/`K23`:
/// kỳ 1 → `HK1 · 2023–2024`, kỳ 2 → `HK2 · 2023–2024`, kỳ 3 → `HK1 · 2024–2025`…
String nhanKy(int ky, String khoa) {
  final so = RegExp(r'\d+').firstMatch(khoa)?.group(0);
  final namNhap = so == null
      ? null
      : (so.length == 2 ? 2000 + int.parse(so) : int.parse(so));
  final hk = (ky - 1) % 2 + 1;
  if (namNhap == null) return 'Học kỳ $ky';
  final nam = namNhap + (ky - 1) ~/ 2;
  return 'Học kỳ $hk · Năm học $nam–${nam + 1}';
}

const _khoi = <(String, String)>[
  ('chung', 'Chung'),
  ('co_so_nganh', 'Cơ sở ngành'),
  ('chuyen_nganh', 'Chuyên ngành'),
  ('tu_chon', 'Tự chọn'),
  ('tot_nghiep', 'Tốt nghiệp'),
];

class _Data {
  _Data(this.ctdt, this.mon, this.tinChiTichLuy, this.tenHkDangHoc);

  final Json ctdt;
  final List<MonCtdt> mon;
  final int tinChiTichLuy;
  final String? tenHkDangHoc;
}

/// Chương trình đào tạo của sinh viên (SV-03) — mockup `SV-Web-CTDT`: tiến độ tích lũy, phân bổ theo
/// khối kiến thức, các môn theo học kỳ gợi ý với trạng thái cá nhân.
class CurriculumScreen extends ConsumerStatefulWidget {
  const CurriculumScreen({super.key});

  @override
  ConsumerState<CurriculumScreen> createState() => _CurriculumScreenState();
}

class _CurriculumScreenState extends ConsumerState<CurriculumScreen> {
  late Future<_Data> _data = _fetch();
  TrangThaiMon? _loc;

  Future<_Data> _fetch() async {
    final api = ref.read(trainingApiProvider);
    final ctdt = await api.get('/curriculums/my/');
    final grades = await api.get('/grades/my/');
    final dangKy = await api.listAll('/registrations/history/');
    final tenHk = [
      for (final r in dangKy)
        if (r.str('trang_thai') == 'DA_DANG_KY' &&
            const ['MO', 'DANG_HOC'].contains(r.str('lop_trang_thai')))
          r.str('ten_hk'),
    ];
    return _Data(
      ctdt,
      gopMonCtdt(ctdt, grades, dangKy),
      grades.num0('tin_chi_tich_luy'),
      tenHk.isEmpty ? null : tenHk.first,
    );
  }

  void _taiLai() {
    final next = _fetch();
    setState(() {
      _data = next;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_Data>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) {
        final f = snap.error;
        if (f is ApiFailure && f.status == 404) {
          return const AlertBanner(
            kind: BannerKind.warning,
            message: 'Bạn chưa được gán chương trình đào tạo. Hãy liên hệ Phòng đào tạo.',
          );
        }
        return ListErrorCard(onRetry: _taiLai);
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _tongQuan(d),
            const SizedBox(height: 16),
            _phanBo(d),
            const SizedBox(height: 16),
            _boLoc(),
            const SizedBox(height: 8),
            ..._cacKy(d),
          ],
        ),
      );
    },
  );

  Widget _tongQuan(_Data d) {
    final yeuCau = d.ctdt.num0('tong_tin_chi_yeu_cau');
    final daDat = d.mon.where((m) => m.trangThai == TrangThaiMon.daDat).length;
    final chuaDat = d.mon
        .where((m) => m.trangThai == TrangThaiMon.chuaDat)
        .length;
    final dangHoc = d.mon
        .where((m) => m.trangThai == TrangThaiMon.dangHoc)
        .length;
    final pct = yeuCau == 0 ? 0 : (100 * d.tinChiTichLuy / yeuCau).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${d.ctdt.str('nganh_ten')} · Khóa ${d.ctdt.str('khoa_tuyen_sinh').replaceFirst(RegExp(r'^[Kk]'), '')}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Text(
                'Mã CTĐT: ${d.ctdt.str('ma_ctdt')} · Yêu cầu $yeuCau tín chỉ',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tiến độ tích lũy',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0, 1).toDouble(),
                  minHeight: 12,
                  color: AppColors.primary,
                  backgroundColor: AppColors.divider,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${d.tinChiTichLuy} / $yeuCau tín chỉ ($pct%)',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            StatCard(
              label: 'Tổng số môn',
              value: '${d.mon.length}',
              note: 'Trong chương trình đào tạo',
            ),
            StatCard(
              label: 'Tín chỉ đã đạt',
              value: '${d.tinChiTichLuy}',
              note: 'Trên $yeuCau tín chỉ yêu cầu',
            ),
            StatCard(
              label: 'Môn đã đạt',
              value: '$daDat',
              note: chuaDat == 0
                  ? 'Không có môn chưa đạt'
                  : '$chuaDat môn chưa đạt cần học lại',
            ),
            StatCard(
              label: 'Đang học',
              value: '$dangHoc',
              note: d.tenHkDangHoc,
            ),
          ],
        ),
      ],
    );
  }

  Widget _phanBo(_Data d) => PanelCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phân bổ theo khối kiến thức', style: sectionTitleStyle),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (ma, nhan) in _khoi)
                () {
                  final trongKhoi = d.mon.where((m) => m.khoi == ma).toList();
                  final dat = trongKhoi
                      .where((m) => m.trangThai == TrangThaiMon.daDat)
                      .fold<int>(0, (s, m) => s + m.tinChi);
                  final tong = trongKhoi.fold<int>(0, (s, m) => s + m.tinChi);
                  return Container(
                    width: 170,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F5FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nhan,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dat / $tong TC',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${trongKhoi.length} môn',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                }(),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _boLoc() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      ChoiceChip(
        label: const Text('Tất cả'),
        selected: _loc == null,
        onSelected: (_) => setState(() => _loc = null),
      ),
      for (final t in TrangThaiMon.values)
        ChoiceChip(
          label: Text(t.nhan),
          selected: _loc == t,
          onSelected: (_) => setState(() => _loc = t),
        ),
    ],
  );

  List<Widget> _cacKy(_Data d) {
    final khoa = d.ctdt.str('khoa_tuyen_sinh');
    final theoKy = <int, List<MonCtdt>>{};
    for (final m in d.mon) {
      theoKy.putIfAbsent(m.ky, () => []).add(m);
    }
    // Học kỳ hiện tại = kỳ có nhiều môn "Đang học" nhất.
    int? kyHienTai;
    var nhieuNhat = 0;
    for (final e in theoKy.entries) {
      final n = e.value
          .where((m) => m.trangThai == TrangThaiMon.dangHoc)
          .length;
      if (n > nhieuNhat) {
        nhieuNhat = n;
        kyHienTai = e.key;
      }
    }
    final ky = theoKy.keys.toList()..sort();
    final out = <Widget>[];
    for (final k in ky) {
      final tatCa = theoKy[k]!;
      final hien = [
        for (final m in tatCa)
          if (_loc == null || m.trangThai == _loc) m,
      ];
      if (hien.isEmpty) continue; // bộ lọc ẩn học kỳ không còn môn phù hợp
      final tc = tatCa.fold<int>(0, (s, m) => s + m.tinChi);
      final bb = tatCa.where((m) => m.loai == 'bat_buoc').length;
      out.add(const SizedBox(height: 16));
      out.add(
        PanelCard(
          padding: 0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(nhanKy(k, khoa), style: sectionTitleStyle),
                    if (k == kyHienTai)
                      StatusChip.of('Học kỳ hiện tại', StatusChip.indigo),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  '${tatCa.length} môn · $tc tín chỉ · $bb bắt buộc · ${tatCa.length - bb} tự chọn',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              if (isCompact(context))
                for (final m in hien) _theMon(m)
              else ...[_hang(null), for (final m in hien) _hang(m)],
            ],
          ),
        ),
      );
    }
    if (out.isEmpty) {
      out.add(const SizedBox(height: 16));
      out.add(
        const PanelCard(
          child: Text(
            'Không có môn nào phù hợp với bộ lọc.',
            style: TextStyle(color: AppColors.muted),
          ),
        ),
      );
    }
    return out;
  }

  Widget _hang(MonCtdt? m) {
    const dau = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.muted,
    );
    Widget c(double? w, Widget child, {int flex = 1}) => w != null
        ? SizedBox(width: w, child: child)
        : Expanded(flex: flex, child: child);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: m == null ? const Color(0xFFF7F8FC) : null,
        border: const Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: m == null
            ? [
                c(100, const Text('MÃ MÔN', style: dau)),
                c(null, const Text('TÊN MÔN', style: dau), flex: 3),
                c(40, const Text('TC', style: dau)),
                c(140, const Text('KHỐI KIẾN THỨC', style: dau)),
                c(90, const Text('LOẠI', style: dau)),
                c(70, const Text('ĐIỂM', style: dau)),
                c(120, const Text('TRẠNG THÁI', style: dau)),
              ]
            : [
                c(100, Text(m.ma, style: monoStyle)),
                c(
                  null,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.ten,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (m.tienQuyet.isNotEmpty)
                        Text(
                          'Tiên quyết: ${m.tienQuyet.join(', ')}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  flex: 3,
                ),
                c(40, Text('${m.tinChi}')),
                c(140, Text(khoiText(m.khoi))),
                c(90, Text(loaiMonText(m.loai))),
                c(70, Text(m.diem ?? '—')),
                c(
                  120,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip.of(m.trangThai.nhan, m.trangThai.mau),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _theMon(MonCtdt m) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.divider)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(m.ten, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                '${m.ma} · ${m.tinChi} TC${m.tienQuyet.isEmpty ? '' : ' · Tiên quyết: ${m.tienQuyet.join(', ')}'}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  StatusChip.of(khoiText(m.khoi), StatusChip.gray),
                  StatusChip.of(loaiMonText(m.loai), StatusChip.indigo),
                ],
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              m.diem ?? '—',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 4),
            StatusChip.of(m.trangThai.nhan, m.trangThai.mau),
          ],
        ),
      ],
    ),
  );
}
