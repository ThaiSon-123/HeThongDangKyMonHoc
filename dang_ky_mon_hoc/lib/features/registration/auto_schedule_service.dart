/// TKB tự động (SV-06, plan.md mục 7.2) — **thuần Dart**, không phụ thuộc giao diện hay API.
///
/// Nhận danh sách lớp mở (chưa lọc trùng lịch), các môn SV chọn + ưu tiên, lịch đã có; trả các
/// tổ hợp không trùng lịch (BR-03) kèm điểm /100 và danh sách lý do. Gợi ý chỉ để tham khảo: đăng
/// ký thật vẫn do server kiểm BR-01..07.
library;

import '../training/training_api.dart';

/// Một buổi học lặp theo tuần. `thu` 2..8 (8 = Chủ nhật), tiết `a..b` gồm cả hai đầu.
class Buoi {
  const Buoi(this.thu, this.tietBatDau, this.tietKetThuc);

  factory Buoi.fromJson(Json j) =>
      Buoi(j.num0('thu'), j.num0('tiet_bat_dau'), j.num0('tiet_ket_thuc'));

  final int thu;
  final int tietBatDau;
  final int tietKetThuc;

  /// BR-03: trùng khi cùng thứ và hai khoảng tiết giao nhau (chỉ lịch định kỳ).
  bool trung(Buoi o) =>
      thu == o.thu &&
      tietBatDau <= o.tietKetThuc &&
      o.tietBatDau <= tietKetThuc;

  String get nhan => '${thuDayDu(thu)}, tiết $tietBatDau–$tietKetThuc';
}

String thuDayDu(int thu) => thu == 8 ? 'Chủ nhật' : 'Thứ $thu';

/// Ca học: tiết bắt đầu–kết thúc của ca (design 5.4: sáng 1–5, chiều 6–10, tối 11–15).
enum Ca {
  sang('Sáng', 'sáng', 1, 5),
  chieu('Chiều', 'chiều', 6, 10),
  toi('Tối', 'tối', 11, 15);

  const Ca(this.nhan, this.ten, this.tietDau, this.tietCuoi);

  final String nhan;
  final String ten;
  final int tietDau;
  final int tietCuoi;

  bool chua(Buoi b) => b.tietBatDau >= tietDau && b.tietKetThuc <= tietCuoi;

  static Ca? cua(Buoi b) {
    for (final c in values) {
      if (c.chua(b)) return c;
    }
    return null;
  }
}

/// Một lớp học phần có thể xếp.
class Lop {
  const Lop({
    required this.id,
    required this.maLop,
    required this.monId,
    required this.tenMon,
    required this.tinChi,
    required this.giaoVienId,
    required this.giaoVien,
    required this.lich,
    this.phong = '—',
    this.ngayBatDau,
    this.ngayKetThuc,
    this.siSo,
    this.siSoToiDa,
  });

  factory Lop.fromJson(Json j) => Lop(
    id: j.id,
    maLop: j.str('ma_lop'),
    monId: j.num0('mon_hoc'),
    tenMon: j.str('ten_mon'),
    tinChi: j.num0('tong_tin_chi'),
    giaoVienId: j.num0('giao_vien'),
    giaoVien: j.str('giao_vien_ten'),
    lich: [
      for (final b in (j['lich_hoc'] as List? ?? const []))
        Buoi.fromJson(Json.from(b as Map)),
    ],
    phong: _phongCua(j['lich_hoc'] as List? ?? const []),
    ngayBatDau: j['ngay_bat_dau'] as String?,
    ngayKetThuc: j['ngay_ket_thuc'] as String?,
    siSo: (j['si_so_hien_tai'] as num?)?.toInt(),
    siSoToiDa: (j['si_so_toi_da'] as num?)?.toInt(),
  );

  static String _phongCua(List<dynamic> lich) {
    final p = {
      for (final b in lich)
        if ((b as Map)['phong'] != null) b['phong'].toString(),
    };
    return p.isEmpty ? '—' : p.join(', ');
  }

  final int id;
  final String maLop;
  final int monId;
  final String tenMon;
  final int tinChi;
  final int giaoVienId;
  final String giaoVien;
  final List<Buoi> lich;
  final String phong;

  /// Ngày riêng của lớp (`yyyy-MM-dd`); null = theo học kỳ.
  final String? ngayBatDau;
  final String? ngayKetThuc;
  final int? siSo;
  final int? siSoToiDa;

  bool trungVoi(Iterable<Buoi> khac) =>
      lich.any((a) => khac.any((b) => a.trung(b)));

  /// Lớp có buổi nào giao với một buổi trong [khac]; trả buổi đó (để nêu lý do) hoặc null.
  Buoi? buoiVuongVoi(Iterable<Buoi> khac) {
    for (final a in lich) {
      for (final b in khac) {
        if (a.trung(b)) return b;
      }
    }
    return null;
  }

  String get lichText => lich.map((b) => b.nhan).join('; ');
}

/// Một môn SV muốn học và các lớp đang mở của nó.
class MonChon {
  const MonChon({
    required this.id,
    required this.ten,
    required this.tinChi,
    required this.lop,
    this.batBuoc = false,
    this.kyGoiY,
    this.hocLai = false,
    this.giaoVienMongMuon,
  });

  final int id;
  final String ten;
  final int tinChi;
  final List<Lop> lop;
  final bool batBuoc;
  final int? kyGoiY;
  final bool hocLai;

  /// `id` giáo viên mong muốn; null = "Tự động chọn".
  final int? giaoVienMongMuon;

  String get tenHienThi => hocLai ? '$ten (học lại)' : ten;
}

/// Ưu tiên cá nhân (client; điểm theo plan mục 7.2).
class UuTien {
  const UuTien({this.tranhNgay = const {}, this.ngayMuon = const {}, this.ca});

  final Set<int> tranhNgay;
  final Set<int> ngayMuon;
  final Ca? ca;
}

class DauVao {
  const DauVao({
    required this.mon,
    this.uuTien = const UuTien(),
    this.lichCoSan = const [],
    this.tinChiDaDangKy = 0,
    this.tranTinChi = 1 << 20,
  });

  final List<MonChon> mon;
  final UuTien uuTien;

  /// Buổi của các lớp SV đã đăng ký trong học kỳ — coi như cố định, không được xếp trùng.
  final List<Buoi> lichCoSan;
  final int tinChiDaDangKy;

  /// Trần tín chỉ áp dụng cho SV (đã gồm giới hạn thấp hơn khi bị cảnh báo học vụ, BR-07).
  final int tranTinChi;
}

/// Một dòng giải thích điểm: [dat] = ✓ (đạt) hoặc ! (chưa đạt / bị vướng).
class LyDo {
  const LyDo(this.dat, this.text);

  final bool dat;
  final String text;
}

class ToHop {
  const ToHop({
    required this.chon,
    required this.khongXep,
    required this.diem,
    required this.lyDo,
    required this.tongTinChi,
  });

  /// `monId → lớp` đã xếp.
  final Map<int, Lop> chon;

  /// `monId → lý do` các môn không xếp được.
  final Map<int, String> khongXep;
  final int diem;
  final List<LyDo> lyDo;
  final int tongTinChi;

  Set<int> get idLop => {for (final l in chon.values) l.id};
}

const _diemCoBan = 70;
const _diemToiThieu = 40;
const _diemToiDa = 99;
const _nhanhMoiMon = 6; // số lớp thử cho mỗi môn khi rẽ nhánh
const _beRong = 60; // số tổ hợp dở dang giữ lại sau mỗi môn (beam search)

class _Dang {
  _Dang(this.chon, this.lich, this.tinChi, this.diem);

  final Map<int, Lop> chon;
  final List<Buoi> lich;
  final int tinChi;
  final int diem;
}

/// Sinh các tổ hợp tìm được (tối đa [toiDa] nếu có, mặc định là tất cả), sắp theo (xếp được nhiều môn
/// hơn, điểm cao hơn). Beam search chỉ giữ [_beRong] tổ hợp tốt nhất nên danh sách không quá [_beRong].
///
/// Môn bắt buộc theo `kyGoiY` đứng trước. Duyệt từng môn bằng *beam search*: giữ [_beRong] tổ hợp dở
/// dang tốt nhất (theo điểm riêng từng lớp) nên các tổ hợp khác nhau ngay từ những môn đầu, không
/// chỉ khác ở môn cuối. Môn không lớp nào vừa thì bỏ qua và ghi lý do.
List<ToHop> goiY(DauVao v, {int? toiDa}) {
  final mon = [...v.mon]
    ..sort((a, b) {
      if (a.batBuoc != b.batBuoc) return a.batBuoc ? -1 : 1;
      return (a.kyGoiY ?? 99).compareTo(b.kyGoiY ?? 99);
    });
  var beam = [
    _Dang({}, [...v.lichCoSan], v.tinChiDaDangKy, 0),
  ];
  for (final m in mon) {
    final tiep = <_Dang>[];
    for (final d in beam) {
      final ungVien =
          m.lop
              .where(
                (l) =>
                    !l.trungVoi(d.lich) && d.tinChi + l.tinChi <= v.tranTinChi,
              )
              .toList()
            ..sort(
              (a, b) => _diemRieng(b, m, v.uuTien) - _diemRieng(a, m, v.uuTien),
            );
      if (ungVien.isEmpty) {
        tiep.add(d); // bỏ qua môn này
        continue;
      }
      for (final l in ungVien.take(_nhanhMoiMon)) {
        tiep.add(
          _Dang(
            {...d.chon, m.id: l},
            [...d.lich, ...l.lich],
            d.tinChi + l.tinChi,
            d.diem + _diemRieng(l, m, v.uuTien),
          ),
        );
      }
    }
    tiep.sort((a, b) {
      final xep = b.chon.length - a.chon.length;
      return xep != 0 ? xep : b.diem - a.diem;
    });
    beam = tiep.take(_beRong).toList();
  }

  final daCo = <String>{};
  final toHop = <ToHop>[];
  for (final d in beam) {
    final khoa = (d.chon.values.map((l) => l.id).toList()..sort()).join(',');
    if (daCo.add(khoa)) toHop.add(danhGia(v, d.chon));
  }
  toHop.sort((a, b) {
    final xep = b.chon.length - a.chon.length;
    return xep != 0 ? xep : b.diem - a.diem;
  });
  return toiDa == null ? toHop : toHop.take(toiDa).toList();
}

/// Điểm riêng của một lớp — chỉ dùng để thử lớp tốt trước, không phải điểm tổ hợp.
int _diemRieng(Lop l, MonChon m, UuTien u) {
  var d = 0;
  if (m.giaoVienMongMuon != null && l.giaoVienId == m.giaoVienMongMuon) d += 8;
  for (final b in l.lich) {
    if (u.tranhNgay.contains(b.thu)) d -= 12;
    if (u.ngayMuon.contains(b.thu)) d += 2;
  }
  if (u.ca != null && l.lich.every(u.ca!.chua)) d += 4;
  return d;
}

/// Chấm điểm và giải thích một tổ hợp [chon] (`monId → lớp`). Dùng cả khi SV đổi lớp của một môn.
ToHop danhGia(DauVao v, Map<int, Lop> chon) {
  final u = v.uuTien;
  final lyDo = <LyDo>[];
  var diem = _diemCoBan;
  final mon = {for (final m in v.mon) m.id: m};
  final lopChon = chon.values.toList();
  final tinChiMoi = lopChon.fold<int>(0, (s, l) => s + l.tinChi);

  // Môn không xếp được: nêu buổi gây vướng hoặc vượt trần tín chỉ.
  final lichDaXep = [...v.lichCoSan, for (final l in lopChon) ...l.lich];
  final khongXep = <int, String>{};
  for (final m in v.mon) {
    if (chon.containsKey(m.id)) continue;
    khongXep[m.id] = _lyDoKhongXep(m, lichDaXep, v, tinChiMoi);
  }

  // 1. Ngày muốn tránh.
  if (u.tranhNgay.isNotEmpty) {
    final vi = [
      for (final l in lopChon)
        for (final b in l.lich)
          if (u.tranhNgay.contains(b.thu)) (l, b),
    ];
    diem -= 12 * vi.length;
    final ten = (u.tranhNgay.toList()..sort()).map(thuDayDu).join(', ');
    lyDo.add(
      vi.isEmpty
          ? LyDo(true, 'Không có buổi nào vào $ten như bạn muốn tránh.')
          : LyDo(
              false,
              'Có ${vi.length} buổi vào ngày bạn muốn tránh: '
              '${vi.map((e) => '${e.$1.maLop} (${thuDayDu(e.$2.thu)})').join(', ')}.',
            ),
    );
  }

  // 2. Ngày muốn học.
  if (u.ngayMuon.isNotEmpty && lopChon.isNotEmpty) {
    final dung = lopChon
        .where((l) => l.lich.any((b) => u.ngayMuon.contains(b.thu)))
        .toList();
    diem += 6 * dung.length;
    final ten = (u.ngayMuon.toList()..sort()).map(thuDayDu).join(', ');
    lyDo.add(
      LyDo(
        dung.length == lopChon.length,
        '${dung.length}/${lopChon.length} môn có buổi vào ngày bạn muốn học ($ten).',
      ),
    );
  }

  // 3. Ca học ưu tiên.
  if (u.ca != null && lopChon.isNotEmpty) {
    final dung = lopChon.where((l) => l.lich.every(u.ca!.chua)).toList();
    diem += 4 * dung.length;
    final sai = lopChon.where((l) => !dung.contains(l)).toList();
    if (sai.isEmpty) {
      lyDo.add(
        LyDo(
          true,
          'Cả ${lopChon.length} môn học đúng ca bạn ưu tiên (${u.ca!.ten}).',
        ),
      );
    } else if (dung.isEmpty) {
      lyDo.add(const LyDo(false, 'Không có môn nào học đúng ca bạn ưu tiên.'));
    } else {
      lyDo.add(
        LyDo(
          false,
          'Chỉ ${dung.length}/${lopChon.length} môn học đúng ca ưu tiên; còn lại: '
          '${sai.map((l) => '${l.maLop} (ca ${_caText(l)})').join(', ')}.',
        ),
      );
    }
  }

  // 4. Số ngày học mỗi tuần (gồm cả lớp đã đăng ký).
  final ngay = {for (final b in lichDaXep) b.thu};
  if (ngay.isNotEmpty) {
    final gon = ngay.length <= 4;
    if (gon) diem += 4;
    lyDo.add(
      LyDo(
        gon,
        gon
            ? 'Chỉ học ${ngay.length} ngày/tuần, lịch gọn.'
            : 'Học ${ngay.length} ngày/tuần, nhiều hơn 4 ngày.',
      ),
    );
  }

  // 5. Không trùng tiết (luôn đúng với tổ hợp do goiY sinh ra; có thể sai khi SV tự đổi lớp).
  final trung = <String>[];
  for (var i = 0; i < lopChon.length; i++) {
    for (var j = i + 1; j < lopChon.length; j++) {
      if (lopChon[i].trungVoi(lopChon[j].lich)) {
        trung.add('${lopChon[i].maLop} và ${lopChon[j].maLop}');
      }
    }
    final voiCoSan = lopChon[i].buoiVuongVoi(v.lichCoSan);
    if (voiCoSan != null) {
      trung.add('${lopChon[i].maLop} và lớp đã đăng ký (${voiCoSan.nhan})');
    }
  }
  lyDo.add(
    trung.isEmpty
        ? LyDo(
            true,
            v.lichCoSan.isEmpty ? 'Không trùng tiết giữa các môn đã chọn.' : 'Không trùng tiết giữa các môn đã chọn và các lớp bạn đã đăng ký.',
          )
        : LyDo(false, 'Trùng tiết: ${trung.join('; ')}.'),
  );

  // 6. Giáo viên mong muốn.
  for (final l in lopChon) {
    final m = mon[l.monId];
    final mong = m?.giaoVienMongMuon;
    if (m == null || mong == null) continue;
    if (l.giaoVienId == mong) {
      diem += 8;
      lyDo.add(
        LyDo(true, 'Đúng giáo viên mong muốn: ${m.ten} – ${l.giaoVien}.'),
      );
    } else {
      diem -= 10;
      final ten = m.lop
          .where((x) => x.giaoVienId == mong)
          .firstOrNull
          ?.giaoVien;
      lyDo.add(
        LyDo(
          false,
          'Chưa xếp được giáo viên mong muốn: ${m.ten} học với ${l.giaoVien}'
          '${ten == null ? '' : ' thay vì $ten'}.',
        ),
      );
    }
  }
  for (final e in khongXep.entries) {
    final m = mon[e.key]!;
    if (m.giaoVienMongMuon != null) diem -= 10;
    lyDo.add(LyDo(false, 'Không xếp được ${m.ten}: ${e.value}'));
  }

  return ToHop(
    chon: Map.of(chon),
    khongXep: khongXep,
    diem: diem.clamp(_diemToiThieu, _diemToiDa),
    lyDo: lyDo,
    tongTinChi: tinChiMoi,
  );
}

String _caText(Lop l) {
  final ca = l.lich.map(Ca.cua).toSet();
  return ca.length == 1 && ca.first != null ? ca.first!.ten : 'khác';
}

String _lyDoKhongXep(MonChon m, List<Buoi> lichDaXep, DauVao v, int tinChiMoi) {
  if (m.lop.isEmpty) return 'môn chưa có lớp nào đang mở.';
  if (v.tinChiDaDangKy + tinChiMoi + m.tinChi > v.tranTinChi) {
    return 'vượt giới hạn ${v.tranTinChi} tín chỉ của học kỳ.';
  }
  for (final l in m.lop) {
    final vuong = l.buoiVuongVoi(lichDaXep);
    if (vuong != null) {
      return 'mọi lớp đều vướng lịch, ví dụ ${l.maLop} (${l.lich.first.nhan}) '
          'trùng ${vuong.nhan}.';
    }
  }
  return 'không có lớp phù hợp.';
}

/// Các lớp khác của môn [monId] mà SV có thể đổi sang trong tổ hợp [t] mà không trùng lịch với
/// những lớp còn lại (và lớp đã đăng ký) — dùng cho ô chọn "đổi lớp".
List<Lop> lopThayThe(DauVao v, ToHop t, int monId) {
  final hienTai = t.chon[monId];
  final mon = v.mon.where((m) => m.id == monId).firstOrNull;
  if (mon == null) return const [];
  final lichKhac = [
    ...v.lichCoSan,
    for (final e in t.chon.entries)
      if (e.key != monId) ...e.value.lich,
  ];
  return [
    for (final l in mon.lop)
      if (l.id == hienTai?.id || !l.trungVoi(lichKhac)) l,
  ];
}
