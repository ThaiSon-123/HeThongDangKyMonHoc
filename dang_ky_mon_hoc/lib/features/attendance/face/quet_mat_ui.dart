import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_button.dart';
import '../../registration/timetable_screen.dart' show clockProvider;
import '../tu_diem_danh/tu_diem_danh_text.dart' show conLai;

/// Kết quả lượt điểm danh hiện ngay trên màn camera.
enum LoaiKetQua { dat, choDuyet, khongDat }

typedef KetQuaQuet = ({LoaiKetQua loai, String tieuDe, String? chiTiet});

/// Gửi các khung vừa chụp lên server, trả kết quả để màn camera hiện.
typedef GuiKhung = Future<KetQuaQuet> Function(List<Uint8List> khung);

/// Mũi tên nhấp nháy chỉ hướng quay đầu (`turn_left` / `hoi_trai` → trái, `turn_right` / `hoi_phai` → phải).
/// Camera trước hiện như gương nên mũi tên trái = sinh viên quay sang trái của mình.
class HuongQuay extends StatefulWidget {
  const HuongQuay({super.key, required this.tuThe});

  final String? tuThe;

  @override
  State<HuongQuay> createState() => _HuongQuayState();
}

class _HuongQuayState extends State<HuongQuay>
    with SingleTickerProviderStateMixin {
  late final _nhip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _nhip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trai = widget.tuThe == 'turn_left' || widget.tuThe == 'hoi_trai';
    final phai = widget.tuThe == 'turn_right' || widget.tuThe == 'hoi_phai';
    if (!trai && !phai) return const SizedBox.shrink();
    final huong = trai ? -1.0 : 1.0;
    return Align(
      alignment: Alignment(huong * 0.92, 0),
      child: AnimatedBuilder(
        animation: _nhip,
        builder: (_, child) => Transform.translate(
          offset: Offset(huong * 14 * _nhip.value, 0),
          child: child,
        ),
        child: Icon(
          trai ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
          key: ValueKey(trai ? 'mui-ten-trai' : 'mui-ten-phai'),
          color: Colors.white,
          size: 64,
          semanticLabel: trai ? 'Quay sang trái' : 'Quay sang phải',
        ),
      ),
    );
  }
}

/// Đếm ngược thời hạn thử thách (`Còn mm:ss`), đỏ khi còn ≤ 10 giây.
class DemNguoc extends ConsumerStatefulWidget {
  const DemNguoc({super.key, required this.hetHan});

  final DateTime hetHan;

  @override
  ConsumerState<DemNguoc> createState() => _DemNguocState();
}

class _DemNguocState extends ConsumerState<DemNguoc> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    final gap = widget.hetHan.difference(now).inSeconds <= 10;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: gap ? AppColors.danger : Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Text(
            'Còn ${conLai(widget.hetHan, now)}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thanh "Bước i/n" của chuỗi chụp lúc điểm danh.
class TienDoBuoc extends StatelessWidget {
  const TienDoBuoc({super.key, required this.buoc, required this.tong});

  final int buoc; // 1-based
  final int tong;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Bước $buoc/$tong',
        style: const TextStyle(color: Colors.white70),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 6),
      LinearProgressIndicator(
        value: buoc / tong,
        backgroundColor: Colors.white24,
        color: Colors.white,
        minHeight: 4,
        borderRadius: BorderRadius.circular(2),
      ),
    ],
  );
}

/// Kết quả lượt điểm danh ngay trên màn camera: đạt / chờ duyệt / không đạt + "Xong".
class KetQuaQuetView extends StatelessWidget {
  const KetQuaQuetView({super.key, required this.ketQua, required this.onXong});

  final KetQuaQuet ketQua;
  final VoidCallback onXong;

  @override
  Widget build(BuildContext context) {
    final (icon, mau) = switch (ketQua.loai) {
      LoaiKetQua.dat => (Icons.check_circle_rounded, AppColors.success),
      LoaiKetQua.choDuyet => (Icons.hourglass_top_rounded, AppColors.warning),
      LoaiKetQua.khongDat => (Icons.cancel_rounded, AppColors.danger),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: mau, size: 96),
            const SizedBox(height: 16),
            Text(
              ketQua.tieuDe,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            if (ketQua.chiTiet != null && ketQua.chiTiet!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                ketQua.chiTiet!,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              child: AppButton(label: 'Xong', onPressed: onXong),
            ),
          ],
        ),
      ),
    );
  }
}
