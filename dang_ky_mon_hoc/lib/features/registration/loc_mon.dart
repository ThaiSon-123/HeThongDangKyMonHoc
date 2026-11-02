import 'package:flutter/material.dart';

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

/// Ô tìm học phần dùng chung của *Đăng ký môn học* và *TKB tự động* (tên môn / mã môn / mã lớp).
/// Không lọc theo học kỳ: cả hai màn chỉ hiện lớp của học kỳ đang mở đăng ký (mới nhất).
class LocMon extends StatelessWidget {
  const LocMon({super.key, required this.tim, required this.onTim});

  final TextEditingController tim;
  final ValueChanged<String> onTim;

  @override
  Widget build(BuildContext context) => LabeledField(
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
}
