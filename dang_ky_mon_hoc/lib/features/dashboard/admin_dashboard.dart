import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/page_result.dart';
import '../../core/format.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/alert_banner.dart';
import '../admin/system/backups_screen.dart' show formatBytes;
import '../notifications/audit_log_screen.dart' show hanhDongLabel, tomTat;
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
                  d.suc != null,
                  d.suc != null ? 'Phản hồi bình thường' : 'Không phản hồi',
                ),
                _Suc(
                  'Cơ sở dữ liệu',
                  d.suc?['db'] == true,
                  d.suc?['db'] == true
                      ? 'Kết nối ổn định'
                      : 'Không kết nối được',
                ),
                _Suc(
                  'Bộ nhớ đệm',
                  d.suc?['redis'] == true,
                  d.suc?['redis'] == true
                      ? 'Kết nối ổn định'
                      : 'Không kết nối được',
                ),
                _Suc(
                  'Tác vụ chạy nền',
                  d.suc?['worker'] == true,
                  d.suc?['worker'] == true
                      ? 'Đang chạy'
                      : 'Không thấy tiến trình nền',
                ),
              ],
            ),
            const SizedBox(height: 16),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tài khoản theo vai trò',
                          style: sectionTitleStyle,
                        ),
                      ),
                      Text(
                        d.dangKhoa == 0
                            ? 'Không có tài khoản bị khóa'
                            : '${d.dangKhoa} tài khoản đang khóa',
                        style: TextStyle(
                          fontSize: 13,
                          color: d.dangKhoa == 0
                              ? AppColors.muted
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final (ma, ten) in _vaiTro)
                        Container(
                          width: 140,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF4F5FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ten,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.muted,
                                ),
                              ),
                              Text(
                                '${d.soTaiKhoan[ma]}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const LoiTat([
              ('Tài khoản', '/admin/accounts'),
              ('Cấu hình', '/admin/config'),
              ('Sao lưu', '/admin/backups'),
            ]),
            const SizedBox(height: 16),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sao lưu gần nhất', style: sectionTitleStyle),
                  const SizedBox(height: 10),
                  if (file == null)
                    const Text(
                      'Chưa có bản sao lưu nào.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else ...[
                    _dong('Tên tệp', (file as Map)['ten'] as String),
                    _dong('Thời gian', formatIso(file['tao_luc'] as String)),
                    _dong('Dung lượng', formatBytes(file['dung_luong'] as num)),
                  ],
                  if (file == null || (gio ?? 0) >= _canhBaoSauGio) ...[
                    const SizedBox(height: 10),
                    AlertBanner(
                      kind: BannerKind.warning,
                      message: file == null
                          ? 'Chưa có bản sao lưu nào. Hãy kiểm tra lịch sao lưu tự động hoặc tạo bản sao lưu ngay.'
                          : 'Đã hơn $_canhBaoSauGio giờ chưa có bản sao lưu mới. Hãy kiểm tra lịch sao lưu tự động hoặc tạo bản sao lưu ngay.',
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.go('/admin/backups'),
                      child: const Text('Mở trang Sao lưu ›'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            PanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hoạt động gần đây', style: sectionTitleStyle),
                  const SizedBox(height: 10),
                  if (d.nhatKy.isEmpty)
                    const Text(
                      'Chưa có thao tác nào được ghi nhận.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  for (final l in d.nhatKy)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 2,
                        children: [
                          Text(
                            formatIso(l.str('thoi_gian')),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                          Text(
                            l.str('nguoi_thuc_hien'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(hanhDongLabel(l.str('hanh_dong'))),
                          Text(
                            '${l.str('doi_tuong')} · ${tomTat(l)}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () => context.go('/admin/logs'),
                      child: const Text('Xem toàn bộ nhật ký ›'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );

  Widget _dong(String nhan, String giaTri) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 110,
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

/// Thẻ tình trạng một thành phần hệ thống: chấm xanh/đỏ + trạng thái + ghi chú.
class _Suc extends StatelessWidget {
  const _Suc(this.ten, this.tot, this.ghiChu);

  final String ten;
  final bool tot;
  final String ghiChu;

  @override
  Widget build(BuildContext context) => Container(
    width: 240,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: AppColors.cardShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ten, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tot ? AppColors.success : AppColors.danger,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              tot ? 'Hoạt động' : 'Có sự cố',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: tot ? AppColors.navy : AppColors.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          ghiChu,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
}
