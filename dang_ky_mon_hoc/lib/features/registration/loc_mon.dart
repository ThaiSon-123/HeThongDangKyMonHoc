import 'package:flutter/material.dart';

import '../../shared/widgets/labeled_dropdown.dart';
import '../../shared/widgets/labeled_field.dart';

const _dau = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};
final _bangBoDau = {
  for (final e in _dau.entries)
    for (final c in e.value.split('')) c: e.key,
};

/// Chữ thường, bỏ dấu tiếng Việt: "Học MÁY" → "hoc may".
String chuanHoaTim(String s) =>
    s.toLowerCase().split('').map((c) => _bangBoDau[c] ?? c).join();

/// `true` khi mọi từ của [tuKhoa] đều có mặt trong một trong các [truong] (không phân biệt hoa thường
/// và dấu). Từ khóa rỗng khớp tất cả.
bool khopTuKhoa(String tuKhoa, Iterable<String> truong) {
  final tu = chuanHoaTim(tuKhoa)
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty);
  if (tu.isEmpty) return true;
  final chuoi = truong.map(chuanHoaTim).join('\n');
  return tu.every(chuoi.contains);
}

/// Hàng lọc dùng chung của *Đăng ký môn học* và *TKB tự động*: ô tìm học phần (tên môn / mã môn / mã
/// lớp) và ô chọn học kỳ trong chương trình đào tạo (`0` = tất cả).
class LocMon extends StatelessWidget {
  const LocMon({
    super.key,
    required this.tim,
    required this.ky,
    required this.cacKy,
    required this.onTim,
    required this.onKy,
  });

  final TextEditingController tim;
  final int ky;

  /// Các học kỳ trong CTĐT có môn để chọn (đã sắp xếp, không gồm 0).
  final List<int> cacKy;
  final ValueChanged<String> onTim;
  final ValueChanged<int> onKy;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final hep = box.maxWidth < 640;
      final oTim = LabeledField(
        label: 'Tìm học phần',
        controller: tim,
        hint: 'Tên môn, mã môn hoặc mã lớp',
        onChanged: onTim,
        suffix: ValueListenableBuilder<TextEditingValue>(
          valueListenable: tim,
          builder: (context, v, _) => v.text.isEmpty
              ? const Icon(Icons.search)
              : IconButton(
                  tooltip: 'Xóa tìm kiếm',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    tim.clear();
                    onTim('');
                  },
                ),
        ),
      );
      final oKy = LabeledDropdown<int>(
        label: 'Học kỳ trong CTĐT',
        value: cacKy.contains(ky) ? ky : 0,
        options: [
          (0, 'Tất cả học kỳ'),
          for (final k in cacKy) (k, 'Học kỳ $k'),
        ],
        onChanged: onKy,
      );
      return hep
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [oTim, const SizedBox(height: 12), oKy],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(flex: 3, child: oTim),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: oKy),
              ],
            );
    },
  );
}
