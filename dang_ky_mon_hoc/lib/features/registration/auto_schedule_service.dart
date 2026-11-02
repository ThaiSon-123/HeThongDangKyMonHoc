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

/// Ưu tiên cá nhân (client; cách chấm điểm xem [danhGia] và plan mục 7.2).
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

/// Một dòng giải thích điểm: [dat] = ✓ (đạt trọn) hoặc ! (chưa đạt / bị vướng); [diem] = `"đạt/tối đa"`
/// của tiêu chí (null = dòng chỉ giải thích, không có điểm riêng).
class LyDo {
  const LyDo(this.dat, this.text, [this.diem]);

  final bool dat;
  final String text;
  final String? diem;
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

// Trọng số tiêu chí; chỉ tiêu chí đang dùng mới tính, rồi quy về thang 100 (plan mục 7.2).
const _wXepMon = 40;
const _wKhongTrung = 15;
const _wTranhNgay = 15;
const _wNgayMuon = 10;
const _wCa = 10;
const _wGiaoVien = 10;
const _wGon = 5;
const _nhanhMoiMon = 6; // số lớp thử cho mỗi môn khi rẽ nhánh
const _beRong = 60; // số tổ hợp dở dang giữ lại sau mỗi môn (beam search)

class _Dang {
  _Dang(this.chon, this.lich, this.tinChi, this.diem);

  final Map<int, Lop> chon;
  final List<Buoi> lich;
  final int tinChi;
  final int diem;
}

/// Sinh các tổ hợp tìm được (tối đa [toiDa] nếu có, mặc định là tất cả), sắp theo điểm giảm dần (cùng
/// điểm thì tổ hợp xếp được nhiều môn hơn đứng trước). Beam search chỉ giữ [_beRong] tổ hợp tốt nhất nên danh sách không quá [_beRong].
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
    final diem = b.diem - a.diem;
    return diem != 0 ? diem : b.chon.length - a.chon.length;
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

class _TieuChi {
  _TieuChi(this.trongSo, this.tyLe, this.text);

  final int trongSo;
  final double tyLe; // 0..1
  final String text;
}

/// Điểm tối đa mỗi tiêu chí trên thang 100 (chia theo trọng số, phần lẻ dồn cho phần dư lớn nhất) —
/// đạt trọn mọi tiêu chí thì tổng đúng 100.
List<int> _diemToiDa(List<int> trongSo) {
  final tong = trongSo.fold<int>(0, (s, w) => s + w);
  final tho = [for (final w in trongSo) 100 * w / tong];
  final ket = [for (final x in tho) x.floor()];
  final thuTu = List.generate(trongSo.length, (i) => i)
    ..sort((i, j) => (tho[j] - ket[j]).compareTo(tho[i] - ket[i]));
  final du = 100 - ket.fold<int>(0, (s, x) => s + x);
  for (var k = 0; k < du; k++) {
    ket[thuTu[k]]++;
  }
  return ket;
}

/// Chấm điểm và giải thích một tổ hợp [chon] (`monId → lớp`). Dùng cả khi SV đổi lớp của một môn.
///
/// Mỗi tiêu chí có trọng số và **tỷ lệ đạt** 0..1; điểm = Σ (điểm tối đa của tiêu chí × tỷ lệ đạt),
/// thang 100, chỉ tính tiêu chí đang dùng: xếp đủ môn (tín chỉ xếp được / đã chọn, môn bắt buộc nặng gấp
/// đôi), không trùng tiết, tránh ngày / ngày muốn học / ca ưu tiên (tính theo **từng buổi**), giáo viên
/// mong muốn (theo môn), lịch gọn (≤ 4 ngày/tuần). Không đạt chỗ nào thì mất đúng phần điểm đó.
ToHop danhGia(DauVao v, Map<int, Lop> chon) {
  final u = v.uuTien;
  final mon = {for (final m in v.mon) m.id: m};
  final lopChon = chon.values.toList();
  final tinChiMoi = lopChon.fold<int>(0, (s, l) => s + l.tinChi);
  final buoi = [for (final l in lopChon) ...l.lich];

  // Môn không xếp được: nêu buổi gây vướng hoặc vượt trần tín chỉ.
  final lichDaXep = [...v.lichCoSan, ...buoi];
  final khongXep = <int, String>{};
  for (final m in v.mon) {
    if (chon.containsKey(m.id)) continue;
    khongXep[m.id] = _lyDoKhongXep(m, lichDaXep, v, tinChiMoi);
  }

  final tieuChi = <_TieuChi>[];

  // 1. Xếp đủ các môn đã chọn (môn bắt buộc nặng gấp đôi).
  if (v.mon.isNotEmpty) {
    int nang(MonChon m) => m.tinChi * (m.batBuoc ? 2 : 1);
    final tong = v.mon.fold<int>(0, (s, m) => s + nang(m));
    final xep = v.mon
        .where((m) => chon.containsKey(m.id))
        .fold<int>(0, (s, m) => s + nang(m));
    final tcChon = v.mon.fold<int>(0, (s, m) => s + m.tinChi);
    final thieuBb = [
      for (final m in v.mon)
        if (m.batBuoc && !chon.containsKey(m.id)) m.ten,
    ];
    tieuChi.add(
      _TieuChi(
        _wXepMon,
        tong == 0 ? 1 : xep / tong,
        'Xếp được ${chon.length}/${v.mon.length} môn đã chọn ($tinChiMoi/$tcChon tín chỉ)'
        '${thieuBb.isEmpty ? '' : '; thiếu môn bắt buộc: ${thieuBb.join(', ')}'}.',
      ),
    );
  }

  if (lopChon.isNotEmpty) {
    // 2. Ngày muốn tránh — theo từng buổi.
    if (u.tranhNgay.isNotEmpty) {
      final vi = [
        for (final l in lopChon)
          for (final b in l.lich)
            if (u.tranhNgay.contains(b.thu)) (l, b),
      ];
      final ten = (u.tranhNgay.toList()..sort()).map(thuDayDu).join(', ');
      tieuChi.add(
        _TieuChi(
          _wTranhNgay,
          1 - vi.length / buoi.length,
          vi.isEmpty
              ? 'Không có buổi nào vào $ten như bạn muốn tránh.'
              : 'Có ${vi.length}/${buoi.length} buổi vào ngày bạn muốn tránh: '
                    '${vi.map((e) => '${e.$1.maLop} (${thuDayDu(e.$2.thu)})').join(', ')}.',
        ),
      );
    }

    // 3. Ngày muốn học — theo từng buổi.
    if (u.ngayMuon.isNotEmpty) {
      final dung = buoi.where((b) => u.ngayMuon.contains(b.thu)).length;
      final ten = (u.ngayMuon.toList()..sort()).map(thuDayDu).join(', ');
      tieuChi.add(
        _TieuChi(
          _wNgayMuon,
          dung / buoi.length,
          '$dung/${buoi.length} buổi học vào ngày bạn muốn học ($ten).',
        ),
      );
    }

    // 4. Ca học ưu tiên — theo từng buổi.
    if (u.ca != null) {
      final dung = buoi.where(u.ca!.chua).length;
      final sai = lopChon.where((l) => !l.lich.every(u.ca!.chua)).toList();
      tieuChi.add(
        _TieuChi(
          _wCa,
          dung / buoi.length,
          sai.isEmpty
              ? 'Cả ${buoi.length} buổi học đúng ca bạn ưu tiên (${u.ca!.ten}).'
              : '$dung/${buoi.length} buổi học đúng ca ưu tiên (${u.ca!.ten}); lệch ca: '
                    '${sai.map((l) => '${l.maLop} (ca ${_caText(l)})').join(', ')}.',
        ),
      );
    }

    // 5. Số ngày học mỗi tuần (gồm cả lớp đã đăng ký): ≤ 4 đạt trọn, 5 được nửa, ≥ 6 không được.
    final ngay = {for (final b in lichDaXep) b.thu}.length;
    tieuChi.add(
      _TieuChi(
        _wGon,
        ngay <= 4
            ? 1
            : ngay == 5
            ? 0.5
            : 0,
        ngay <= 4
            ? 'Chỉ học $ngay ngày/tuần, lịch gọn.'
            : 'Học $ngay ngày/tuần, nhiều hơn 4 ngày.',
      ),
    );

    // 6. Không trùng tiết (luôn đúng với tổ hợp do goiY sinh ra; có thể sai khi SV tự đổi lớp).
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
    tieuChi.add(
      _TieuChi(
        _wKhongTrung,
        trung.isEmpty ? 1 : 0,
        trung.isEmpty
            ? (v.lichCoSan.isEmpty
                  ? 'Không trùng tiết giữa các môn đã chọn.'
                  : 'Không trùng tiết giữa các môn đã chọn và các lớp bạn đã đăng ký.')
            : 'Trùng tiết: ${trung.join('; ')}.',
      ),
    );

    // 7. Giáo viên mong muốn — theo môn có chọn giáo viên (môn không xếp được tính là chưa đạt).
    final coMong = v.mon.where((m) => m.giaoVienMongMuon != null).toList();
    if (coMong.isNotEmpty) {
      final phan = <String>[];
      var dung = 0;
      for (final m in coMong) {
        final l = chon[m.id];
        if (l == null) {
          phan.add('chưa xếp được ${m.ten}');
        } else if (l.giaoVienId == m.giaoVienMongMuon) {
          dung++;
          phan.add('${m.ten} – ${l.giaoVien}');
        } else {
          final ten = m.lop
              .where((x) => x.giaoVienId == m.giaoVienMongMuon)
              .firstOrNull
              ?.giaoVien;
          phan.add(
            '${m.ten} học với ${l.giaoVien}${ten == null ? '' : ' thay vì $ten'}',
          );
        }
      }
      tieuChi.add(
        _TieuChi(
          _wGiaoVien,
          dung / coMong.length,
          dung == coMong.length
              ? 'Đúng giáo viên mong muốn: ${phan.join('; ')}.'
              : 'Đúng giáo viên mong muốn $dung/${coMong.length} môn: ${phan.join('; ')}.',
        ),
      );
    }
  }

  final toiDa = _diemToiDa([for (final c in tieuChi) c.trongSo]);
  var diem = 0;
  final lyDo = <LyDo>[];
  for (final (i, c) in tieuChi.indexed) {
    final dat = (toiDa[i] * c.tyLe).round();
    diem += dat;
    lyDo.add(LyDo(c.tyLe >= 1, c.text, '$dat/${toiDa[i]}'));
  }
  for (final e in khongXep.entries) {
    lyDo.add(LyDo(false, 'Không xếp được ${mon[e.key]!.ten}: ${e.value}'));
  }

  return ToHop(
    chon: Map.of(chon),
    khongXep: khongXep,
    diem: diem,
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
