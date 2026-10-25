import 'package:flutter/material.dart';

import '../../core/layout.dart';
import '../../core/theme/app_colors.dart';
import '../reports/report_widgets.dart' show lapDayColor;

/// Một dòng của [BangLop]: lớp học phần + (tùy chọn) nhãn và nút hành động.
class DongLop {
  const DongLop({
    required this.maLop,
    required this.giaoVien,
    required this.lich,
    required this.phong,
    this.siSo,
    this.siSoToiDa,
    this.nhan,
    this.hanhDong,
    this.mo = false,
  });

  final String maLop;
  final String giaoVien;
  final String lich;
  final String phong;
  final int? siSo;
  final int? siSoToiDa;

  /// Chip nhỏ cạnh mã lớp (vd "Đã chọn").
  final Widget? nhan;

  /// Nút ở cuối dòng (vd "Đăng ký").
  final Widget? hanhDong;

  /// Làm mờ dòng (lớp không thuộc giáo viên đã chọn).
  final bool mo;
}

/// Bảng các lớp của một môn (mockup `SV-Web-DangKy` / `SV-Web-TKBTuDong`): tiêu đề cột viết hoa,
/// cột thẳng hàng, sĩ số có thanh lấp đầy (xanh < 70% · vàng 70–90% · đỏ > 90%).
/// Điện thoại: mỗi lớp là một khối xếp dọc.
class BangLop extends StatelessWidget {
  const BangLop({super.key, required this.dong});

  final List<DongLop> dong;

  static const _dau = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: AppColors.muted,
    letterSpacing: 0.3,
  );
  static const _maLop = TextStyle(
    fontFamily: 'monospace',
    fontWeight: FontWeight.w700,
    fontSize: 13,
  );

  @override
  Widget build(BuildContext context) {
    final coNut = dong.any((d) => d.hanhDong != null);
    if (isCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [for (final d in dong) _hangDienThoai(d)],
      );
    }
    Widget cot(int flex, Widget w) => Expanded(flex: flex, child: w);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              cot(3, const Text('MÃ LỚP', style: _dau)),
              cot(3, const Text('GIÁO VIÊN', style: _dau)),
              cot(3, const Text('LỊCH HỌC', style: _dau)),
              cot(2, const Text('PHÒNG', style: _dau)),
              cot(3, const Text('SĨ SỐ', style: _dau)),
              if (coNut) const SizedBox(width: 132),
            ],
          ),
        ),
        for (final d in dong)
          Opacity(
            opacity: d.mo ? 0.45 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  cot(
                    3,
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(d.maLop, style: _maLop),
                        if (d.nhan != null) d.nhan!,
                      ],
                    ),
                  ),
                  cot(3, Text(d.giaoVien)),
                  cot(3, Text(d.lich)),
                  cot(2, Text(d.phong)),
                  cot(
                    3,
                    Padding(
                      padding: const EdgeInsets.only(right: 20),
                      child: _siSo(d),
                    ),
                  ),
                  if (coNut)
                    SizedBox(
                      width: 132,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: d.hanhDong,
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (dong.isNotEmpty) const SizedBox(height: 4),
      ],
    );
  }

  Widget _siSo(DongLop d) {
    final si = d.siSo;
    final max = d.siSoToiDa;
    if (si == null || max == null || max <= 0) return const Text('—');
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (si / max).clamp(0, 1).toDouble(),
              minHeight: 8,
              color: lapDayColor(si * 100 / max),
              backgroundColor: AppColors.divider,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text('$si/$max', style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _hangDienThoai(DongLop d) => Opacity(
    opacity: d.mo ? 0.45 : 1,
    child: Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(d.maLop, style: _maLop),
              if (d.nhan != null) d.nhan!,
            ],
          ),
          const SizedBox(height: 4),
          Text(d.giaoVien, style: const TextStyle(fontSize: 13)),
          Text(
            '${d.lich} · ${d.phong}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          if (d.siSo != null && d.siSoToiDa != null || d.hanhDong != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _siSo(d)),
                if (d.hanhDong != null) ...[
                  const SizedBox(width: 12),
                  SizedBox(width: 120, child: d.hanhDong),
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

/// Tiêu đề một dòng môn: [mã môn] tên môn đậm ... chip (TC · loại · đã đạt · số lớp).
class TieuDeMon extends StatelessWidget {
  const TieuDeMon({
    super.key,
    required this.ten,
    this.maMon,
    this.nhan = const [],
  });

  final String ten;
  final String? maMon;
  final List<Widget> nhan;

  @override
  Widget build(BuildContext context) {
    final tenW = Text(
      ten,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    );
    final maW = maMon == null
        ? null
        : Text(
            maMon!,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: AppColors.muted,
            ),
          );
    final chips = Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: nhan,
    );
    if (isCompact(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          tenW,
          ?maW,
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: nhan,
          ),
        ],
      );
    }
    return Row(
      children: [
        if (maW != null) SizedBox(width: 96, child: maW),
        Expanded(child: tenW),
        const SizedBox(width: 12),
        Flexible(child: chips),
      ],
    );
  }
}
