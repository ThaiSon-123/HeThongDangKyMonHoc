import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/page_result.dart';
import '../../core/format.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../../shared/widgets/status_chip.dart';
import '../admin/system/backups_screen.dart' show formatBytes;
import '../notifications/audit_log_screen.dart' show hanhDongLabel, tomTat;
import '../notifications/audit_mo_ta.dart' show tenDoiTuong;
import '../registration/timetable_screen.dart' show clockProvider;
import '../training/resource_list.dart' show ListErrorCard, ListSkeleton;
import '../training/training_api.dart';
import '../training/training_widgets.dart' show PanelCard, sectionTitleStyle;
import 'dashboard_widgets.dart';

const _vaiTro = <(String, String)>[
  ('ADMIN', 'Quản trị'),
  ('PHONG_DAO_TAO', 'Phòng đào tạo'),
  ('SINH_VIEN', 'Sinh viên'),
  ('GIAO_VIEN', 'Giáo viên'),
  ('KE_TOAN', 'Kế toán'),
];

/// Sau số giờ này chưa có bản sao lưu mới thì cảnh báo (design.md 9.0).
const _canhBaoSauGio = 48;

class _Data {
  _Data(this.suc, this.soTaiKhoan, this.dangKhoa, this.sao, this.nhatKy);

  final Json? suc;
  final Map<String, int> soTaiKhoan;
  final int dangKhoa;
  final Json? sao;
  final List<Json> nhatKy;
}

/// Tổng quan Quản trị — mockup `AD-Web-TongQuan`: sức khỏe hệ thống, tài khoản theo vai trò, sao lưu
/// gần nhất, hoạt động gần đây. Chỉ ghép từ endpoint sẵn có (`health?full=1`, `users`, `backups`, `audit-logs`).
class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  late Future<_Data> _data = _fetch();

  Future<_Data> _fetch() async {
    final api = ref.read(trainingApiProvider);
    Future<int> dem(Map<String, Object?> q) async =>
        (await api.list('/users/', pageSize: 1, query: q)).count;
    final r = await Future.wait<Object?>([
      hoacNull(() => api.get('/health/', query: {'full': 1})),
      Future.wait<int>([
        for (final (ma, _) in _vaiTro) dem({'role': ma}),
      ]),
      dem({'is_locked': 'true'}),
      hoacNull(() => api.get('/admin/backups/')),
      hoacNull(() => api.list('/admin/audit-logs/', pageSize: 10)),
    ]);
    final soTk = r[1]! as List<int>;
    return _Data(
      r[0] as Json?,
      {for (final (i, (ma, _)) in _vaiTro.indexed) ma: soTk[i]},
      r[2]! as int,
      r[3] as Json?,
      (r[4] as PageResult<Json>?)?.items ?? const [],
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
      if (snap.hasError) return ListErrorCard(onRetry: _taiLai);
      final d = snap.data;
      if (d == null) return const ListSkeleton();
      final now = ref.read(clockProvider)();
      final file = (d.sao?['results'] as List?)?.firstOrNull;
      final gio = file == null
          ? null
          : now
                .difference(
                  DateTime.parse((file as Map)['tao_luc'] as String).toLocal(),
                )
                .inHours;
      final taiKhoan = _khoiTaiKhoan(d);
      final saoLuu = _khoiSaoLuu(file as Map?, gio);
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LoiChao(
              ten: tenNguoiDung(ref, 'Quản trị viên'),
              phu: ngayDayDu(now),
            ),
            const SizedBox(height: 16),
            HangThe(
              children: [
                _Suc(
                  'Máy chủ ứng dụng',
                  Icons.dns_outlined,
                  d.suc != null,
                  d.suc != null ? 'Phản hồi bình thường' : 'Không phản hồi',
                ),
                _Suc(
                  'Cơ sở dữ liệu',
                  Icons.storage_outlined,
                  d.suc?['db'] == true,
                  d.suc?['db'] == true
                      ? 'Kết nối ổn định'
                      : 'Không kết nối được',
                ),
                _Suc(
                  'Bộ nhớ đệm',
                  Icons.bolt_outlined,
                  d.suc?['redis'] == true,
                  d.suc?['redis'] == true
                      ? 'Kết nối ổn định'
                      : 'Không kết nối được',
                ),
                _Suc(
                  'Tác vụ chạy nền',
                  Icons.sync_outlined,
                  d.suc?['worker'] == true,
                  d.suc?['worker'] == true
                      ? 'Đang chạy'
                      : 'Không thấy tiến trình nền',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const LoiTat([
              ('Tài khoản', '/admin/accounts'),
              ('Cấu hình', '/admin/config'),
              ('Sao lưu', '/admin/backups'),
            ]),
            const SizedBox(height: 16),
            // Web rộng: tài khoản và sao lưu cạnh nhau; hẹp/điện thoại: xếp dọc.
            if (isWide(context))
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 3, child: taiKhoan),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: saoLuu),
                  ],
                ),
              )
            else ...[
              taiKhoan,
              const SizedBox(height: 16),
              saoLuu,
            ],
            const SizedBox(height: 16),
            _khoiNhatKy(d.nhatKy),
          ],
        ),
      );
    },
  );

  /// Mỗi vai trò một dòng: tên, số tài khoản, thanh tỉ lệ so với tổng.
  Widget _khoiTaiKhoan(_Data d) {
    final tong = d.soTaiKhoan.values.fold<int>(0, (a, b) => a + b);
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              const Text('Tài khoản theo vai trò', style: sectionTitleStyle),
              d.dangKhoa == 0
                  ? StatusChip.of(
                      'Không có tài khoản bị khóa',
                      StatusChip.green,
                    )
                  : StatusChip.of(
                      '${d.dangKhoa} tài khoản đang khóa',
                      StatusChip.red,
                    ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Tổng $tong tài khoản',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          for (final (ma, ten) in _vaiTro)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: isCompact(context) ? 100 : 130,
                    child: Text(
                      ten,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.label,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: tong == 0 ? 0 : d.soTaiKhoan[ma]! / tong,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFECEFF5),
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    child: Text(
                      '${d.soTaiKhoan[ma]}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _khoiSaoLuu(Map? file, int? gio) {
    final cu = file == null || (gio ?? 0) >= _canhBaoSauGio;
    return PanelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Sao lưu gần nhất', style: sectionTitleStyle),
              ),
              if (file != null)
                cu
                    ? StatusChip.of('Đã cũ', StatusChip.yellow)
                    : StatusChip.of('Mới', StatusChip.green),
            ],
          ),
          const SizedBox(height: 12),
          if (file == null)
            const Text(
              'Chưa có bản sao lưu nào.',
              style: TextStyle(color: AppColors.muted),
            )
          else ...[
            _dong('Tên tệp', file['ten'] as String),
            _dong('Thời gian', formatIso(file['tao_luc'] as String)),
            _dong('Dung lượng', formatBytes(file['dung_luong'] as num)),
          ],
          if (cu) ...[
            const SizedBox(height: 10),
            AlertBanner(
              kind: BannerKind.warning,
              message: file == null
                  ? 'Chưa có bản sao lưu nào. Hãy kiểm tra lịch sao lưu tự động hoặc tạo bản sao lưu ngay.'
                  : 'Đã hơn $_canhBaoSauGio giờ chưa có bản sao lưu mới. Hãy kiểm tra lịch sao lưu tự động hoặc tạo bản sao lưu ngay.',
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
              ),
              onPressed: () => context.go('/admin/backups'),
              child: const Text('Mở trang Sao lưu ›'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _khoiNhatKy(List<Json> nhatKy) {
    final compact = isCompact(context);
    return PanelCard(
      padding: 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 12),
            child: Text('Hoạt động gần đây', style: sectionTitleStyle),
          ),
          if (nhatKy.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Text(
                'Chưa có thao tác nào được ghi nhận.',
                style: TextStyle(color: AppColors.muted),
              ),
            ),
          for (final l in nhatKy)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 16 : 24,
                vertical: 10,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: compact ? _dongNhatKyHep(l) : _dongNhatKy(l),
            ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => context.go('/admin/logs'),
                child: const Text('Xem toàn bộ nhật ký ›'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static (Color, Color) _mauHanhDong(String h) => switch (h) {
    'CREATE' => StatusChip.green,
    'DELETE' => StatusChip.red,
    'UPDATE' => StatusChip.indigo,
    _ => StatusChip.gray,
  };

  Widget _dongNhatKy(Json l) => Row(
    children: [
      SizedBox(
        width: 140,
        child: Text(
          formatIso(l.str('thoi_gian')),
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ),
      SizedBox(
        width: 170,
        child: Text(
          l.str('nguoi_thuc_hien'),
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      SizedBox(
        width: 120,
        child: Align(
          alignment: Alignment.centerLeft,
          child: StatusChip.of(
            hanhDongLabel(l.str('hanh_dong')),
            _mauHanhDong(l.str('hanh_dong')),
          ),
        ),
      ),
      Expanded(
        child: Text(
          '${tenDoiTuong[l.str('doi_tuong')] ?? l.str('doi_tuong')} · ${tomTat(l)}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: AppColors.muted),
        ),
      ),
    ],
  );

  Widget _dongNhatKyHep(Json l) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              l.str('nguoi_thuc_hien'),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          StatusChip.of(
            hanhDongLabel(l.str('hanh_dong')),
            _mauHanhDong(l.str('hanh_dong')),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        '${tenDoiTuong[l.str('doi_tuong')] ?? l.str('doi_tuong')} · ${tomTat(l)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      Text(
        formatIso(l.str('thoi_gian')),
        style: const TextStyle(fontSize: 12, color: AppColors.muted),
      ),
    ],
  );

  Widget _dong(String nhan, String giaTri) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
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

/// Thẻ tình trạng một thành phần hệ thống: biểu tượng + chấm xanh/đỏ + trạng thái + ghi chú.
class _Suc extends StatelessWidget {
  const _Suc(this.ten, this.icon, this.tot, this.ghiChu);

  final String ten;
  final IconData icon;
  final bool tot;
  final String ghiChu;

  @override
  Widget build(BuildContext context) {
    final mau = tot ? AppColors.success : AppColors.danger;
    return Container(
      width: isCompact(context) ? MediaQuery.sizeOf(context).width - 32 : 240,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: mau.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 22, color: mau),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ten,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: mau,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tot ? 'Hoạt động' : 'Có sự cố',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: tot ? AppColors.navy : AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  ghiChu,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
