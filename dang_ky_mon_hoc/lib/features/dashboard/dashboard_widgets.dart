import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_failure.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../training/training_api.dart';
import '../training/training_widgets.dart';

/// `Thứ 7, 10/10/2026` — Chủ nhật là `Chủ nhật`.
String ngayDayDu(DateTime d) {
  final thu = d.weekday == 7 ? 'Chủ nhật' : 'Thứ ${d.weekday + 1}';
  String hai(int n) => n.toString().padLeft(2, '0');
  return '$thu, ${hai(d.day)}/${hai(d.month)}/${d.year}';
}

String buoiCuaTiet(int tiet) => tiet <= 5
    ? 'Sáng'
    : tiet <= 10
    ? 'Chiều'
    : 'Tối';

/// Một tiết học hôm nay: lớp (`timetable/my`) + dòng lịch của lớp.
typedef TietHomNay = ({Json lop, Json lich});

/// Lịch học/dạy của **hôm nay** từ `GET /timetable/my/`: dòng lịch có `thu` trùng thứ hôm nay (CN = 8)
/// và hôm nay nằm trong `[ngay_bat_dau, ngay_ket_thuc]` của lớp (không có thì theo học kỳ). Sắp theo tiết.
List<TietHomNay> lichHomNay(Json tkb, DateTime now) {
  final hom = DateTime(now.year, now.month, now.day);
  final thu = now.weekday == 7 ? 8 : now.weekday + 1;
  DateTime? ngay(String? s) =>
      s == null || s.length < 10 ? null : DateTime.tryParse(s.substring(0, 10));
  final ra = <TietHomNay>[];
  for (final l in (tkb['lop_hoc_phan'] as List? ?? const [])) {
    final lop = Json.from(l as Map);
    // Lớp chưa đặt ngày thì theo học kỳ; không đọc được ngày nào thì không lọc theo ngày.
    final tu = ngay(
      lop['ngay_bat_dau'] != null
          ? lop.str('ngay_bat_dau')
          : tkb.str('ngay_bat_dau'),
    );
    final den = ngay(
      lop['ngay_ket_thuc'] != null
          ? lop.str('ngay_ket_thuc')
          : tkb.str('ngay_ket_thuc'),
    );
    if ((tu != null && hom.isBefore(tu)) || (den != null && hom.isAfter(den))) {
      continue;
    }
    for (final b in (lop['lich_hoc'] as List? ?? const [])) {
      final lich = Json.from(b as Map);
      if (lich.num0('thu') == thu) ra.add((lop: lop, lich: lich));
    }
  }
  ra.sort(
    (a, b) =>
        a.lich.num0('tiet_bat_dau').compareTo(b.lich.num0('tiet_bat_dau')),
  );
  return ra;
}

/// Số ngày từ hôm nay tới [ymd] (`yyyy-MM-dd`): âm = đã qua; null nếu không đọc được.
int? soNgayDen(String ymd, DateTime now) {
  final d = DateTime.tryParse(ymd);
  if (d == null) return null;
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
}

/// Họ tên người đang đăng nhập (vai trò không có hồ sơ như PĐT, KT, Admin); thiếu thì dùng [macDinh].
String tenNguoiDung(WidgetRef ref, String macDinh) {
  final ten = ref.read(authControllerProvider).user?.fullName ?? '';
  return ten.isEmpty ? macDinh : ten;
}

/// Gọi API; lỗi thì trả null để một khối hỏng không làm trắng cả trang tổng quan.
Future<T?> hoacNull<T>(Future<T> Function() goi) async {
  try {
    return await goi();
  } on ApiFailure {
    return null;
  }
}

/// Lời chào đầu trang: tên + dòng phụ.
class LoiChao extends StatelessWidget {
  const LoiChao({super.key, required this.ten, required this.phu});

  final String ten;
  final String phu;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Xin chào, $ten',
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
      ),
      const SizedBox(height: 2),
      Text(phu, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
    ],
  );
}

/// Khối trắng có tiêu đề, nội dung và (tùy chọn) liên kết cuối khối.
class KhoiTongQuan extends StatelessWidget {
  const KhoiTongQuan({
    super.key,
    required this.tieuDe,
    required this.children,
    this.lienKet,
    this.duongDan,
    this.trong,
  });

  final String tieuDe;
  final List<Widget> children;
  final String? lienKet;
  final String? duongDan;

  /// Thông điệp khi [children] rỗng.
  final String? trong;

  @override
  Widget build(BuildContext context) => PanelCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tieuDe, style: sectionTitleStyle),
        const SizedBox(height: 10),
        if (children.isEmpty && trong != null)
          Text(trong!, style: const TextStyle(color: AppColors.muted)),
        ...children,
        if (lienKet != null && duongDan != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 40),
              ),
              onPressed: () => context.go(duongDan!),
              child: Text('$lienKet ›'),
            ),
          ),
      ],
    ),
  );
}

/// Hàng lối tắt (nút viền) tới các màn hay dùng.
class LoiTat extends StatelessWidget {
  const LoiTat(this.muc, {super.key});

  final List<(String, String)> muc;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 12,
    runSpacing: 8,
    children: [
      for (final (nhan, duong) in muc)
        SizedBox(
          width: isCompact(context) ? soCot2(context, 12) : 170,
          child: AppButton(
            label: nhan,
            height: 44,
            outlined: true,
            onPressed: () => context.go(duong),
          ),
        ),
    ],
  );
}

/// Dòng "Tiết 1–3 · Sáng · P.A101 / Môn / mã lớp · phụ" trong khối lịch hôm nay.
class DongTiet extends StatelessWidget {
  const DongTiet({super.key, required this.tiet, required this.phu});

  final TietHomNay tiet;
  final String phu;

  @override
  Widget build(BuildContext context) {
    final bd = tiet.lich.num0('tiet_bat_dau');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tiết $bd–${tiet.lich.num0('tiet_ket_thuc')} · ${buoiCuaTiet(bd)} · P.${tiet.lich.str('phong')}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          Text(
            tiet.lop.str('ten_mon'),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Text(
            '${tiet.lop.str('ma_lop')} · $phu',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
