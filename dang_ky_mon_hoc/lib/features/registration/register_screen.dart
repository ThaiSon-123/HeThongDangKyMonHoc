import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_failure.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_dialog.dart';
import '../../shared/widgets/app_toast.dart';
import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/status_chip.dart';
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import 'bang_lop.dart';
import 'loc_mon.dart';
import 'registration_format.dart';

const _regPath = '/registrations/';

class _RegData {
  _RegData(this.meta, this.lop, this.history, this.daDat);

  final Json meta;
  final List<Json>
  lop; // lớp có thể đăng ký (đã lọc CTĐT / còn chỗ / không trùng lịch)
  final List<Json> history;
  final Map<int, bool> daDat; // mon_hoc → đã đạt (từ CTĐT của tôi)

  bool get trongCuaSo => meta['trong_cua_so'] == true;
  int get hocKy => meta.num0('hoc_ky');

  List<Json> get dangKy => [
    for (final h in history)
      if (h.str('trang_thai') == 'DA_DANG_KY' && h.num0('hoc_ky') == hocKy) h,
  ];
}

/// Đăng ký môn học (SV-04/05/07/09) — mockup `SV-Web-DangKy` / `SV-App-DangKy`:
/// lớp gom theo môn, bấm môn để xem các lớp; tab Đã đăng ký (hủy) và Lịch sử.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  late Future<_RegData> _data = _fetch();
  int _tab = 0;
  final _tim = TextEditingController();
  int _kyCtdt = 0; // 0 = tất cả học kỳ trong CTĐT
  int _mode = 0; // 0 = tất cả môn đang mở, 1 = theo CTĐT (lọc theo kỳ)
  bool _chuaHoc = false;
  int? _hkLichSu; // lọc tab Lịch sử theo học kỳ (null = tất cả)
  String _ttLichSu = ''; // '' = tất cả · DA_DANG_KY · DA_HUY
  int? _busy; // id lớp / đăng ký đang gọi API

  @override
  void dispose() {
    _tim.dispose();
    super.dispose();
  }

  Future<_RegData> _fetch() async {
    final api = ref.read(trainingApiProvider);
    final lop = <Json>[];
    var meta = <String, dynamic>{};
    for (var page = 1; ; page++) {
      final r = await api.page('/courses/available/', page: page);
      meta = Json.from(r['meta'] as Map);
      final rows = [for (final e in r['results'] as List) Json.from(e as Map)];
      lop.addAll(rows);
      if (lop.length >= (r['count'] as num).toInt() || rows.isEmpty) break;
    }
    final history = await api.listAll('${_regPath}history/');
    final daDat = <int, bool>{};
    try {
      final c = await api.get('/curriculums/my/');
      for (final m in c['mon'] as List) {
        daDat[(m as Map)['mon_hoc'] as int] = m['da_dat'] == true;
      }
    } on ApiFailure {
      // Chưa gán CTĐT: bỏ qua bộ lọc "Môn chưa học".
    }
    return _RegData(meta, lop, history, daDat);
  }

  void _reload() {
    final next = _fetch();
    setState(() {
      _data = next;
    });
  }

  String _msg(ApiFailure f, String fallback) {
    if (f.isNetwork) {
      return 'Không thể kết nối máy chủ. Kiểm tra mạng rồi thử lại.';
    }
    if (f.isRateLimited) {
      return 'Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.';
    }
    return f.message ??
        (f.fields.isNotEmpty ? f.fields.values.first : fallback);
  }

  Future<void> _register(Json lop) async {
    setState(() => _busy = lop.id);
    try {
      final res = await ref
          .read(trainingApiProvider)
          .create(
            _regPath,
            {'lop_hoc_phan': lop.id},
            headers: {'Idempotency-Key': newIdempotencyKey()},
          );
      // Cấu hình giá là việc của Kế toán, sinh viên không cần thấy.
      final canhBao = [
        for (final w in res['warnings'] as List)
          if ((w as Map)['code'] != 'CHUA_CAU_HINH_GIA') w['message'],
      ];
      if (mounted) {
        showAppToast(
          context,
          'Đã đăng ký lớp ${lop.str('ma_lop')}.${canhBao.isEmpty ? '' : ' ${canhBao.first}'}',
        );
      }
      _reload();
    } on ApiFailure catch (f) {
      if (mounted) {
        showAppToast(context, _msg(f, 'Không đăng ký được, vui lòng thử lại.'));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _cancel(Json reg) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Hủy đăng ký?',
      message:
          'Hủy lớp ${reg.str('ma_lop')} — ${reg.str('ten_mon')}? Học phí của môn này sẽ được tính lại.',
      actionLabel: 'Hủy đăng ký',
      danger: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = reg.id);
    try {
      await ref.read(trainingApiProvider).cancel(_regPath, reg.id, {});
      if (mounted) {
        showAppToast(context, 'Đã hủy đăng ký lớp ${reg.str('ma_lop')}.');
      }
      _reload();
    } on ApiFailure catch (f) {
      if (mounted) {
        showAppToast(context, _msg(f, 'Không hủy được, vui lòng thử lại.'));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<_RegData>(
    future: _data,
    builder: (context, snap) {
      if (snap.hasError) {
        final f = snap.error;
        // Chưa chọn được học kỳ (ngoài mọi học kỳ) → thông báo thay vì "lỗi kết nối".
        if (f is ApiFailure && f.fields.containsKey('hoc_ky')) {
          return AlertBanner(
            kind: BannerKind.warning,
            message: 'Chưa có học kỳ nào đang mở đăng ký.',
          );
        }
        return ListErrorCard(onRetry: _reload);
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(d),
            const SizedBox(height: 16),
            _tabs(d),
            const SizedBox(height: 16),
            switch (_tab) {
              0 => _openClasses(d),
              1 => _registered(d),
              _ => _history(d),
            },
          ],
        ),
      );
    },
  );

  Widget _tabs(_RegData d) {
    final labels = [
      isCompact(context) ? 'Đang mở' : 'Lớp đang mở',
      isCompact(context) ? 'Đã đăng ký' : 'Đã đăng ký (${d.dangKy.length})',
      'Lịch sử',
    ];
    // App: thanh chia đoạn đủ bề ngang (mockup), không để tab rớt dòng; Web: chip như cũ.
    if (isCompact(context)) {
      return SegmentedButton<int>(
        showSelectedIcon: false,
        segments: [
          for (final (i, l) in labels.indexed)
            ButtonSegment(
              value: i,
              label: Text(l, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
        ],
        selected: {_tab},
        onSelectionChanged: (s) => setState(() => _tab = s.first),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (i, l) in labels.indexed)
          ChoiceChip(
            label: Text(l),
            selected: _tab == i,
            onSelected: (_) => setState(() => _tab = i),
          ),
      ],
    );
  }

  // ------------------------------------------------------------ lớp đang mở
  Widget _openClasses(_RegData d) {
    final lop = [
      for (final l in d.lop)
        // "Theo CTĐT": chỉ môn có trong chương trình đào tạo của mình.
        if ((_mode == 0 || l['hoc_ky_goi_y'] != null) &&
            !(_chuaHoc && d.daDat[l.num0('mon_hoc')] == true) &&
            (_kyCtdt == 0 || l['hoc_ky_goi_y'] == _kyCtdt) &&
            khopTuKhoa(_tim.text, [
              l.str('ten_mon'),
              l.str('ma_mon'),
              l.str('ma_lop'),
            ]))
          l,
    ];
    final cacKy = ({
      for (final l in d.lop)
        if (l['hoc_ky_goi_y'] != null) l.num0('hoc_ky_goi_y'),
    }.toList()..sort());
    final groups = <int, List<Json>>{};
    for (final l in lop) {
      groups.putIfAbsent(l.num0('mon_hoc'), () => []).add(l);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        Text(
          '${groups.length} môn · ${lop.length} lớp học phần đang mở',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          _Card(
            child: Text(
              d.lop.isEmpty
                  ? 'Hiện không có lớp nào để đăng ký.'
                  : 'Không có môn phù hợp với bộ lọc.',
              style: const TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ),
        for (final g in groups.values) _courseTile(d, g),
      ],
    );
  }

  Widget _courseTile(_RegData d, List<Json> classes) {
    final c = classes.first;
    final daDat = d.daDat[c.num0('mon_hoc')] == true;
    // Môn đã đạt: làm mờ để phân biệt với môn còn học được.
    return Opacity(
      opacity: daDat ? 0.55 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _Card(
          padding: 0,
          child: ExpansionTile(
            key: PageStorageKey('mon-${c.num0('mon_hoc')}'),
            shape: const Border(),
            collapsedShape: const Border(),
            title: TieuDeMon(
              maMon: c.str('ma_mon'),
              ten: c.str('ten_mon'),
              nhan: [
                StatusChip.of('${c.num0('tong_tin_chi')} TC', StatusChip.gray),
                if (c['loai_mon'] != null)
                  StatusChip.of(
                    loaiMonText(c.str('loai_mon')),
                    StatusChip.indigo,
                  ),
                if (c['khoi_kien_thuc'] != null)
                  StatusChip.of(
                    khoiText(c.str('khoi_kien_thuc')),
                    StatusChip.gray,
                  ),
                if (daDat) StatusChip.of('Đã đạt', StatusChip.green),
                Text(
                  '${classes.length} lớp',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
            // Mặc định ExpansionTile căn GIỮA khối nội dung đã co theo chiều rộng → neo trái, dòng lớp giãn hết.
            expandedAlignment: Alignment.centerLeft,
            expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BangLop(
                dong: [
                  for (final l in classes)
                    DongLop(
                      maLop: l.str('ma_lop'),
                      giaoVien: l.str('giao_vien_ten'),
                      lich: lichText(l['lich_hoc'] as List),
                      phong: phongText(l['lich_hoc'] as List),
                      thoiGian: thoiGianHoc(
                        l['ngay_bat_dau'],
                        l['ngay_ket_thuc'],
                        macDinhBatDau: d.meta['ngay_bat_dau'],
                        macDinhKetThuc: d.meta['ngay_ket_thuc'],
                      ),
                      siSo: l.num0('si_so_hien_tai'),
                      siSoToiDa: l.num0('si_so_toi_da'),
                      hanhDong: AppButton(
                        label: 'Đăng ký',
                        height: 40,
                        loading: _busy == l.id,
                        onPressed: d.trongCuaSo && _busy == null
                            ? () => _register(l)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------ đã đăng ký
  Widget _registered(_RegData d) {
    final rows = d.dangKy;
    if (rows.isEmpty) {
      return const _Card(
        child: Text(
          'Bạn chưa đăng ký môn nào trong học kỳ này.',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      );
    }
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Card(
              child: Wrap(
                spacing: 16,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: r.str('ten_mon'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            TextSpan(
                              text: ' · ${r.num0('tong_tin_chi')} TC',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Lớp ${r.str('ma_lop')} · GV ${r.str('giao_vien_ten')}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.label,
                        ),
                      ),
                      Text(
                        lichText(r['lich_hoc'] as List),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                  if (d.trongCuaSo && r.str('lop_trang_thai') == 'MO')
                    SizedBox(
                      width: 140,
                      child: AppButton(
                        label: 'Hủy đăng ký',
                        height: 40,
                        outlined: true,
                        loading: _busy == r.id,
                        onPressed: _busy == null ? () => _cancel(r) : null,
                      ),
                    )
                  else
                    const Text(
                      'Liên hệ Phòng đào tạo để hủy',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ------------------------------------------------------------ lịch sử
  Widget _history(_RegData d) {
    if (d.history.isEmpty) {
      return const _Card(
        child: Text(
          'Chưa có lịch sử đăng ký.',
          style: TextStyle(color: AppColors.muted, fontSize: 14),
        ),
      );
    }
    final hocKy = <int, String>{
      for (final h in d.history) h.num0('hoc_ky'): h.str('ten_hk'),
    };
    final maHk = hocKy.keys.toList()
      ..sort((a, b) => b.compareTo(a)); // học kỳ mới nhất trước
    final ds = [
      for (final h in d.history)
        if ((_hkLichSu == null || h.num0('hoc_ky') == _hkLichSu) &&
            (_ttLichSu.isEmpty || h.str('trang_thai') == _ttLichSu))
          h,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            SizedBox(
              width: 320,
              child: LabeledDropdown<int?>(
                label: 'Học kỳ',
                value: _hkLichSu,
                options: [
                  (null, 'Tất cả học kỳ'),
                  for (final k in maHk) (k, hocKy[k]!),
                ],
                onChanged: (v) => setState(() => _hkLichSu = v),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (ma, nhan) in const [
                  ('', 'Tất cả'),
                  ('DA_DANG_KY', 'Đã đăng ký'),
                  ('DA_HUY', 'Đã hủy'),
                ])
                  ChoiceChip(
                    label: Text(nhan),
                    selected: _ttLichSu == ma,
                    onSelected: (_) => setState(() => _ttLichSu = ma),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          '${ds.length} đăng ký',
          style: const TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 8),
        if (ds.isEmpty)
          const _Card(
            child: Text(
              'Không có đăng ký nào phù hợp với bộ lọc.',
              style: TextStyle(color: AppColors.muted, fontSize: 14),
            ),
          ),
        for (final h in ds)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Card(
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        h.str('ten_mon'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        '${h.str('ma_mon')} · ${h.str('ten_hk')} · ĐK ${formatIso(h.str('ngay_dang_ky')).split(' ').first}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                      if (h.str('trang_thai') == 'DA_HUY')
                        Text(
                          'Hủy ${formatIso(h.str('ngay_huy')).split(' ').first}'
                          '${h.str('ly_do_huy').isEmpty ? '' : ' · ${h.str('ly_do_huy')}'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  h.str('trang_thai') == 'DA_DANG_KY'
                      ? StatusChip.of('Đã đăng ký', StatusChip.green)
                      : StatusChip.of('Đã hủy', StatusChip.gray),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.d);

  final _RegData d;

  @override
  Widget build(BuildContext context) {
    final meta = d.meta;
    final da = meta.num0('tin_chi_da_dang_ky');
    final min = meta.num0('tin_chi_toi_thieu');
    final max = meta.num0('tin_chi_toi_da');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    meta.str('ten_hk'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                  d.trongCuaSo
                      ? StatusChip.of('Đang mở đăng ký', StatusChip.green)
                      : StatusChip.of(
                          'Ngoài thời gian đăng ký',
                          StatusChip.gray,
                        ),
                ],
              ),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Đã đăng ký '),
                    TextSpan(
                      text: '$da tín chỉ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: ' · tối đa $max'),
                  ],
                ),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        if (!d.trongCuaSo) ...[
          const SizedBox(height: 12),
          const AlertBanner(
            kind: BannerKind.warning,
            title: 'Ngoài thời gian đăng ký.',
            message: 'Bạn chỉ xem được môn đã đăng ký. Cần hủy hoặc điều chỉnh, vui lòng liên hệ Phòng đào tạo.',
          ),
        ] else if (da < min) ...[
          const SizedBox(height: 12),
          AlertBanner(
            kind: BannerKind.info,
            message:
                'Bạn mới đăng ký $da tín chỉ, dưới mức tối thiểu $min. Bạn vẫn có thể đăng ký thêm.',
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = 16});

  final Widget child;
  final double padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: child,
  );
}
