import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Một ô trên lưới tuần: buổi học lặp hằng tuần. `thu` 2..8 (8 = Chủ nhật), tiết `a..b` gồm cả hai đầu.
class OTkb {
  const OTkb({
    required this.thu,
    required this.tietBatDau,
    required this.tietKetThuc,
    required this.tieuDe,
    this.dong2,
    this.dong3,
    this.mau = 0,
    this.xam = false,
  });

  final int thu;
  final int tietBatDau;
  final int tietKetThuc;
  final String tieuDe;
  final String? dong2;
  final String? dong3;

  /// Chỉ số màu (xoay vòng theo bảng màu của lưới).
  final int mau;

  /// Ô nền xám: lịch đã có sẵn, chỉ để tham khảo khung giờ.
  final bool xam;
}

const _rowH = 34.0;
const _labelW = 56.0;
const _days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

// Cùng bảng màu với lưới ở trang Thời khóa biểu (nền nhạt + chữ đậm), xoay vòng.
const _palette = <(Color, Color)>[
  (Color(0xFFE8EAF6), Color(0xFF2C3A7A)),
  (Color(0xFFE0F2F1), Color(0xFF00695C)),
  (Color(0xFFFFF4D6), Color(0xFF8A5A00)),
  (Color(0xFFFDECEA), Color(0xFF8C1D18)),
  (Color(0xFFE6F4EA), Color(0xFF2E7D32)),
  (Color(0xFFF3E5F5), Color(0xFF6A1B9A)),
];
const _xam = (Color(0xFFEEF0F5), Color(0xFF6B7280));

/// Lưới thời khóa biểu theo tuần (T2–CN × tiết 1–15) cho lịch lặp hằng tuần, không gắn ngày cụ thể.
/// Mỗi ô có khóa `tkb-o-<thứ>-<tiết bắt đầu>`; cả lưới có khóa `tkb-luoi`.
class LuoiTkbTuan extends StatelessWidget {
  const LuoiTkbTuan({super.key, required this.o});

  final List<OTkb> o;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final colW = ((box.maxWidth - _labelW) / 7).clamp(104.0, 400.0);
      final width = _labelW + colW * 7;
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          key: const ValueKey('tkb-luoi'),
          width: width,
          child: Column(
            children: [
              Row(
                children: [
                  const SizedBox(width: _labelW),
                  for (final d in _days)
                    SizedBox(
                      width: colW,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.label,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(
                height: _rowH * 15,
                child: Stack(
                  children: [
                    for (var t = 1; t <= 15; t++)
                      Positioned(
                        top: (t - 1) * _rowH,
                        left: 0,
                        right: 0,
                        height: _rowH,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: t == 6 || t == 11
                                    ? AppColors.border
                                    : AppColors.divider,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Tiết $t',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    for (final b in o)
                      Positioned(
                        key: ValueKey('tkb-o-${b.thu}-${b.tietBatDau}'),
                        top: (b.tietBatDau - 1) * _rowH + 1,
                        left: _labelW + (b.thu - 2) * colW + 2,
                        width: colW - 4,
                        height: (b.tietKetThuc - b.tietBatDau + 1) * _rowH - 2,
                        child: _O(b),
                      ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Sáng 1–5 · Chiều 6–10 · Tối 11–15',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _O extends StatelessWidget {
  const _O(this.b);

  final OTkb b;

  @override
  Widget build(BuildContext context) {
    final mau = b.xam ? _xam : _palette[b.mau % _palette.length];
    // Ô cao _rowH × số tiết: 1 tiết chỉ đủ tiêu đề, từ 2 tiết thêm dòng phụ, từ 3 tiết tiêu đề được 2 dòng.
    final tiet = b.tietKetThuc - b.tietBatDau + 1;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: mau.$1,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: mau.$2, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            b.tieuDe,
            maxLines: tiet >= 3 ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: mau.$2,
            ),
          ),
          if (tiet >= 2 && b.dong2 != null)
            Text(
              b.dong2!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: mau.$2),
            ),
          if (tiet >= 2 && b.dong3 != null)
            Text(
              b.dong3!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: mau.$2),
            ),
        ],
      ),
    );
  }
}
