import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_failure.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../registration/timetable_screen.dart' show clockProvider;
import '../reports/report_widgets.dart' show LuoiStat, StatCard;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart' show PanelCard, sectionTitleStyle;
import 'dashboard_widgets.dart';

/// Cửa sổ đăng ký còn ≤ ngưỡng này ngày thì nhắc (design.md 7.0).
const _cuaSoSapDongNgay = 10;

class _Data {
  _Data(this.baoCao, this.hocKy, this.lop, this.choDuyet);

  final Json baoCao;
  final Json hocKy;
  final List<Json> lop;
  final List<Json> choDuyet;
}

/// Một dòng "Việc cần làm": số lượng + mô tả + (tùy chọn) chi tiết + liên kết.
class _Viec {
  _Viec(this.so, this.nhan, this.lienKet, this.duongDan, [this.chiTiet]);

  final int so;
  final String nhan;
  final String lienKet;
  final String duongDan;
  final String? chiTiet;
}

/// Tổng quan Phòng đào tạo — mockup `PDT-Web-TongQuan`: lớp theo trạng thái, đăng ký, việc cần làm,
/// thông tin học kỳ, lối tắt. Chỉ ghép từ các danh sách đã có (không thêm endpoint).
class PdtDashboard extends ConsumerStatefulWidget {
  const PdtDashboard({super.key});

  @override
  ConsumerState<PdtDashboard> createState() => _PdtDashboardState();
}

class _PdtDashboardState extends ConsumerState<PdtDashboard> {
  late Future<_Data> _data = _fetch();

  Future<_Data> _fetch() async {
    final api = ref.read(trainingApiProvider);
    final bc = await api.get(
      '/reports/training/',
    ); // chọn học kỳ mặc định của server
    final id = bc.num0('hoc_ky');
    final r = await Future.wait<Object?>([
      api.get('/semesters/$id/'),
      api.listAll('/class-sections/', query: {'hoc_ky': id}),
      hoacNull(
        () => api.listAll(
          '/grade-sheets/',
          query: {'hoc_ky': id, 'trang_thai': 'DA_DONG'},
        ),
      ),
    ]);
    return _Data(
      bc,
      r[0]! as Json,
      r[1]! as List<Json>,
      (r[2] as List<Json>?) ?? const [],
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
        if (f is ApiFailure && f.fields.containsKey('hoc_ky')) {
          return const AlertBanner(
            kind: BannerKind.warning,
            message: 'Chưa có học kỳ nào. Hãy tạo học kỳ ở mục Học kỳ.',
          );
        }
        return ListErrorCard(onRetry: _taiLai);
      }
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final now = ref.read(clockProvider)();
      final dem = <String, int>{};
      for (final l in d.lop) {
        dem[l.str('trang_thai')] = (dem[l.str('trang_thai')] ?? 0) + 1;
      }
      final tong = Json.from(d.baoCao['tong'] as Map);
      final viec = _viecCanLam(d, now);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoiChao(
              ten: tenNguoiDung(ref, 'Phòng đào tạo'),
              phu: '${d.hocKy.str('ten_hk')} · ${ngayDayDu(now)}',
            ),
            const SizedBox(height: 16),
            LuoiStat(
              children: [
                StatCard(
                  label: 'Kế hoạch',
                  value: '${dem['KE_HOACH'] ?? 0}',
                  note: 'chưa mở đăng ký',
                ),
                StatCard(
                  label: 'Đang mở',
                  value: '${dem['MO'] ?? 0}',
                  note: 'nhận đăng ký',
                ),
                StatCard(
                  label: 'Đang học',
                  value: '${dem['DANG_HOC'] ?? 0}',
                  note: 'đã qua ngày bắt đầu',
                ),
                StatCard(
                  label: 'Đã đóng',
                  value: '${dem['DA_DONG'] ?? 0}',
                  note: 'khóa điểm danh/nhập điểm',
                ),
                StatCard(
                  label: 'Lượt đăng ký',
                  value: '${tong.num0('tong_luot_dang_ky')}',
                  note: 'đang đăng ký',
                ),
                StatCard(
                  label: 'Lớp đầy',
                  value: '${tong.num0('lop_day')}',
                  note: 'hết chỗ',
                ),
                StatCard(
                  label: 'Lớp còn chỗ',
                  value: '${tong.num0('lop_con_cho')}',
                  note: 'đang nhận thêm',
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, box) {
                final viecKhoi = KhoiTongQuan(
                  tieuDe: 'Việc cần làm',
                  trong: 'Không có việc nào cần xử lý. 🎉',
                  children: [for (final v in viec) _dongViec(v)],
                );
                final hocKyKhoi = PanelCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Học kỳ đang chọn', style: sectionTitleStyle),
                      const SizedBox(height: 10),
                      _thongTin(
                        'Thời gian',
                        '${formatYmd(d.hocKy.str('ngay_bat_dau'))} – ${formatYmd(d.hocKy.str('ngay_ket_thuc'))}',
                      ),
                      _thongTin(
                        'Cửa sổ đăng ký',
                        '${formatIso(d.hocKy.str('cua_so_dk_bat_dau')).substring(0, 10)} – ${formatIso(d.hocKy.str('cua_so_dk_ket_thuc')).substring(0, 10)}',
                      ),
                      _thongTin(
                        'Trạng thái',
                        d.hocKy.str('trang_thai') == 'MO'
                            ? 'Đang mở'
                            : 'Đã đóng',
                      ),
                    ],
                  ),
                );
                return box.maxWidth >= 900
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 3, child: viecKhoi),
                          const SizedBox(width: 16),
                          Expanded(flex: 2, child: hocKyKhoi),
                        ],
                      )
                    : Column(
                        children: [
                          viecKhoi,
                          const SizedBox(height: 16),
                          hocKyKhoi,
                        ],
                      );
              },
            ),
            const SizedBox(height: 16),
            const LoiTat([
              ('Học kỳ', '/pdt/semesters'),
              ('Lớp học phần', '/pdt/classes'),
              ('Đăng ký', '/pdt/registrations'),
              ('Duyệt điểm', '/pdt/grade-sheets'),
            ]),
          ],
        ),
      );
    },
  );

  /// Việc cần làm (design.md 7.0), tính từ danh sách lớp + phiếu điểm của học kỳ đang chọn.
  List<_Viec> _viecCanLam(_Data d, DateTime now) {
    final viec = <_Viec>[];
    final thieuLich = [
      for (final l in d.lop)
        if (l.str('trang_thai') == 'KE_HOACH' &&
            (l['lich_hoc'] as List).isEmpty)
          l,
    ];
    if (thieuLich.isNotEmpty) {
      viec.add(
        _Viec(
          thieuLich.length,
          'lớp chưa đủ điều kiện mở',
          'Xem lớp',
          '/pdt/classes?hoc_ky=${d.hocKy.id}',
          '${thieuLich.take(3).map((l) => '${l.str('ma_lop')} (thiếu lịch học)').join(' · ')}${thieuLich.length > 3 ? ' · …' : ''}',
        ),
      );
    }
    final quaHan = [
      for (final l in d.lop)
        if (l.str('trang_thai') == 'DANG_HOC' &&
            (soNgayDen(l.str('han_nhap_diem_hieu_luc'), now) ?? 0) < 0)
          l,
    ];
    if (quaHan.isNotEmpty) {
      viec.add(
        _Viec(
          quaHan.length,
          'lớp quá hạn nhập điểm',
          'Gia hạn / nhập hộ',
          '/pdt/grade-sheets',
          quaHan.take(3).map((l) => l.str('ma_lop')).join(' · '),
        ),
      );
    }
    final choDuyet = [
      for (final s in d.choDuyet)
        if (s.num0('chinh_thuc') > 0) s,
    ];
    if (choDuyet.isNotEmpty) {
      viec.add(
        _Viec(
          choDuyet.length,
          'lớp chờ duyệt điểm',
          'Duyệt điểm',
          '/pdt/grade-sheets',
        ),
      );
    }
    final ngayDong = soNgayDen(d.hocKy.str('cua_so_dk_ket_thuc'), now);
    if (d.hocKy.str('trang_thai') == 'MO' &&
        ngayDong != null &&
        ngayDong >= 0 &&
        ngayDong <= _cuaSoSapDongNgay) {
      viec.add(
        _Viec(
          ngayDong,
          'ngày nữa đóng cửa sổ đăng ký',
          'Xem học kỳ',
          '/pdt/semesters',
        ),
      );
    }
    return viec;
  }

  Widget _dongViec(_Viec v) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFF4F5FA),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Text(
          '${v.so}',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.navy,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(v.nhan, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (v.chiTiet != null)
                Text(
                  v.chiTiet!,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
            ],
          ),
        ),
        TextButton(
          onPressed: () => context.go(v.duongDan),
          child: Text(v.lienKet),
        ),
      ],
    ),
  );

  Widget _thongTin(String nhan, String giaTri) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 130,
          child: Text(
            nhan,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            giaTri,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}
