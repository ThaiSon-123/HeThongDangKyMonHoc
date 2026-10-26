import 'package:dang_ky_mon_hoc/features/registration/auto_schedule_service.dart';
import 'package:flutter_test/flutter_test.dart';

int _seq = 0;

Lop lop(
  int mon,
  String ma,
  List<Buoi> lich, {
  int gv = 1,
  String gvTen = 'Nguyễn Thị Mai',
  int tinChi = 3,
}) => Lop(
  id: ++_seq,
  maLop: ma,
  monId: mon,
  tenMon: 'Môn $mon',
  tinChi: tinChi,
  giaoVienId: gv,
  giaoVien: gvTen,
  lich: lich,
);

MonChon mon(
  int id,
  List<Lop> lops, {
  int? gv,
  bool batBuoc = true,
  int tc = 3,
}) => MonChon(
  id: id,
  ten: 'Môn $id',
  tinChi: tc,
  lop: lops,
  batBuoc: batBuoc,
  giaoVienMongMuon: gv,
);

const t2 = Buoi(2, 1, 3);

void main() {
  group('Buoi / Ca', () {
    test('trùng lịch BR-03: cùng thứ và giao tiết', () {
      expect(const Buoi(2, 1, 3).trung(const Buoi(2, 3, 5)), isTrue);
      expect(const Buoi(2, 1, 3).trung(const Buoi(2, 4, 5)), isFalse);
      expect(const Buoi(2, 1, 3).trung(const Buoi(3, 1, 3)), isFalse);
      expect(
        const Buoi(8, 6, 8).trung(const Buoi(8, 8, 9)),
        isTrue,
      ); // Chủ nhật
    });

    test('ca học theo tiết (sáng 1–5, chiều 6–10, tối 11–15)', () {
      expect(Ca.cua(const Buoi(2, 1, 3)), Ca.sang);
      expect(Ca.cua(const Buoi(2, 6, 8)), Ca.chieu);
      expect(Ca.cua(const Buoi(2, 11, 13)), Ca.toi);
      expect(Ca.cua(const Buoi(2, 4, 7)), isNull); // vắt qua hai ca
    });
  });

  group('goiY', () {
    test('không có tổ hợp trùng lịch; mỗi môn đúng một lớp; điểm giảm dần', () {
      final v = DauVao(
        mon: [
          for (var m = 1; m <= 4; m++)
            mon(m, [
              lop(m, 'M$m-01', [Buoi(2 + (m % 3), 1, 3)]),
              lop(m, 'M$m-02', [Buoi(2 + (m % 3), 6, 8)]),
              lop(m, 'M$m-03', [Buoi(5 + (m % 2), 11, 13)]),
            ]),
        ],
      );
      final r = goiY(v, toiDa: 3);
      expect(r, hasLength(3));
      for (final t in r) {
        expect(t.chon.keys.toSet(), {1, 2, 3, 4});
        final lich = [for (final l in t.chon.values) ...l.lich];
        for (var i = 0; i < lich.length; i++) {
          for (var j = i + 1; j < lich.length; j++) {
            expect(lich[i].trung(lich[j]), isFalse);
          }
        }
        expect(
          t.lyDo.any((l) => l.text.startsWith('Không trùng tiết')),
          isTrue,
        );
      }
      expect(
        r.map((t) => t.diem).toList(),
        [...r.map((t) => t.diem)]..sort((a, b) => b - a),
      );
      expect(
        r.map((t) => t.idLop.toString()).toSet(),
        hasLength(3),
      ); // khác nhau
    });

    test('mặc định trả về mọi tổ hợp tìm được (không cắt ở 3); toiDa cắt đúng đầu danh sách', () {
      final v = DauVao(
        mon: [
          for (var m = 1; m <= 4; m++)
            mon(m, [
              for (var k = 0; k < 6; k++)
                lop(m, 'M$m-0$k', [
                  Buoi(2 + k, 1 + 5 * (m % 2), 3 + 5 * (m % 2)),
                ]),
            ]),
        ],
      );
      final tatCa = goiY(v);
      expect(tatCa.length, greaterThan(3));
      expect(tatCa.length, lessThanOrEqualTo(60)); // beam search giữ tối đa 60
      final ba = goiY(v, toiDa: 3);
      expect(ba, hasLength(3));
      expect(
        ba.map((t) => t.idLop.toString()).toList(),
        tatCa.take(3).map((t) => t.idLop.toString()).toList(),
      );
      // Không tổ hợp nào bị lặp.
      expect(
        tatCa.map((t) => t.idLop.toString()).toSet(),
        hasLength(tatCa.length),
      );
    });

    test('điểm cơ bản: 70 + 4 khi học ≤ 4 ngày/tuần; lý do đúng', () {
      final v = DauVao(
        mon: [
          mon(1, [
            lop(1, 'A-01', [t2]),
          ]),
        ],
      );
      final t = goiY(v).single;
      expect(t.diem, 74);
      expect(t.tongTinChi, 3);
      expect(t.lyDo.map((l) => l.text), [
        'Chỉ học 1 ngày/tuần, lịch gọn.',
        'Không trùng tiết giữa các môn đã chọn.',
      ]);
    });

    test(
      'tránh ngày: −12 mỗi buổi vào ngày tránh; lớp không vướng được ưu tiên',
      () {
        final v = DauVao(
          uuTien: const UuTien(tranhNgay: {7}),
          mon: [
            mon(1, [
              lop(1, 'A-T7', [const Buoi(7, 1, 3)]),
              lop(1, 'A-T3', [const Buoi(3, 1, 3)]),
            ]),
          ],
        );
        final r = goiY(v);
        expect(r.first.chon[1]!.maLop, 'A-T3');
        expect(r.first.diem, 74);
        expect(r.first.lyDo.first.dat, isTrue);
        expect(
          r.first.lyDo.first.text,
          'Không có buổi nào vào Thứ 7 như bạn muốn tránh.',
        );
        final xau = r.last;
        expect(xau.chon[1]!.maLop, 'A-T7');
        expect(xau.diem, 70 - 12 + 4);
        expect(xau.lyDo.first.dat, isFalse);
        expect(xau.lyDo.first.text, contains('A-T7 (Thứ 7)'));
      },
    );

    test('ngày muốn học +6 mỗi môn; ca ưu tiên +4 mỗi môn đúng ca', () {
      final v = DauVao(
        uuTien: const UuTien(ngayMuon: {8}, ca: Ca.sang),
        mon: [
          mon(1, [
            lop(1, 'A-CN', [const Buoi(8, 1, 3)]),
          ]),
          mon(2, [
            lop(2, 'B-C', [const Buoi(3, 6, 8)]),
          ]),
        ],
      );
      final t = goiY(v).single;
      // 70 + 6 (A có buổi Chủ nhật) + 4 (A đúng ca sáng) + 4 (≤ 4 ngày)
      expect(t.diem, 84);
      expect(
        t.lyDo.map((l) => l.text),
        containsAll([
          '1/2 môn có buổi vào ngày bạn muốn học (Chủ nhật).',
          'Chỉ 1/2 môn học đúng ca ưu tiên; còn lại: B-C (ca chiều).',
        ]),
      );
    });

    test(
      'giáo viên mong muốn: +8 khi xếp đúng, −10 và nêu lý do khi không',
      () {
        final dung = lop(1, 'A-01', [t2], gv: 7, gvTen: 'Vũ Đức Anh');
        final khac = lop(1, 'A-02', [const Buoi(3, 1, 3)], gv: 1);
        final v = DauVao(
          mon: [
            mon(1, [dung, khac], gv: 7),
          ],
        );
        final r = goiY(v);
        expect(r.first.chon[1], dung);
        expect(r.first.diem, 70 + 4 + 8);
        expect(
          r.first.lyDo.last.text,
          'Đúng giáo viên mong muốn: Môn 1 – Vũ Đức Anh.',
        );
        expect(r.last.chon[1], khac);
        expect(r.last.diem, 70 + 4 - 10);
        expect(
          r.last.lyDo.last.text,
          'Chưa xếp được giáo viên mong muốn: Môn 1 học với Nguyễn Thị Mai thay vì Vũ Đức Anh.',
        );
      },
    );

    test('lớp đã đăng ký là lịch cố định: lớp trùng bị loại, nêu lý do khi hết lớp', () {
      final v = DauVao(
        lichCoSan: const [Buoi(2, 1, 3)],
        mon: [
          mon(1, [
            lop(1, 'A-01', [const Buoi(2, 2, 4)]),
          ]),
          mon(2, [
            lop(2, 'B-01', [const Buoi(4, 1, 3)]),
          ]),
        ],
      );
      final t = goiY(v).single;
      expect(t.chon.keys, [2]);
      expect(t.khongXep[1], contains('vướng lịch'));
      expect(t.khongXep[1], contains('A-01'));
      expect(t.lyDo.last.dat, isFalse);
      expect(t.lyDo.last.text, startsWith('Không xếp được Môn 1: '));
    });

    test('trần tín chỉ: không xếp quá giới hạn, gồm cả tín chỉ đã đăng ký', () {
      final v = DauVao(
        tinChiDaDangKy: 9,
        tranTinChi: 12,
        mon: [
          mon(1, [
            lop(1, 'A', [t2]),
          ]),
          mon(2, [
            lop(2, 'B', [const Buoi(3, 1, 3)]),
          ]),
        ],
      );
      final t = goiY(v).single;
      expect(t.chon.keys, [1]); // môn bắt buộc đầu tiên vào, môn kế vượt 12
      expect(t.khongXep[2], 'vượt giới hạn 12 tín chỉ của học kỳ.');
    });

    test('môn bắt buộc được xếp trước môn tự chọn khi chỉ đủ chỗ cho một', () {
      final v = DauVao(
        mon: [
          mon(1, [
            lop(1, 'TC', [t2]),
          ], batBuoc: false),
          mon(2, [
            lop(2, 'BB', [t2]),
          ]),
        ],
      );
      expect(goiY(v).single.chon.keys, [2]);
    });

    test('không có môn nào xếp được → vẫn trả tổ hợp rỗng kèm lý do', () {
      final v = DauVao(
        lichCoSan: const [Buoi(2, 1, 5)],
        mon: [
          mon(1, [
            lop(1, 'A', [t2]),
          ]),
        ],
      );
      final t = goiY(v).single;
      expect(t.chon, isEmpty);
      expect(t.khongXep, hasLength(1));
    });

    test('điểm kẹp trong [40, 99]', () {
      final nhieuBuoi = [for (var i = 0; i < 6; i++) Buoi(7, 1 + i, 1 + i)];
      final xau = DauVao(
        uuTien: const UuTien(tranhNgay: {7}),
        mon: [
          mon(1, [lop(1, 'A', nhieuBuoi)]),
        ],
      );
      expect(goiY(xau).single.diem, 40);
      final tot = DauVao(
        uuTien: const UuTien(ngayMuon: {2, 3, 4, 5, 6}, ca: Ca.sang),
        mon: [
          for (var m = 1; m <= 5; m++)
            mon(m, [
              lop(m, 'M$m', [Buoi(1 + m, 1, 3)], gv: 7),
            ], gv: 7),
        ],
      );
      expect(goiY(tot).single.diem, 99);
    });
  });

  group('đổi lớp thủ công', () {
    test(
      'lopThayThe chỉ gồm lớp không trùng các lớp còn lại; danhGia chấm lại',
      () {
        final a1 = lop(1, 'A-01', [t2]);
        final a2 = lop(1, 'A-02', [const Buoi(3, 1, 3)]);
        final a3 = lop(1, 'A-03', [const Buoi(4, 1, 3)]);
        final b1 = lop(2, 'B-01', [const Buoi(3, 2, 4)]);
        final v = DauVao(
          mon: [
            mon(1, [a1, a2, a3]),
            mon(2, [b1]),
          ],
        );
        final t = danhGia(v, {1: a1, 2: b1});
        expect(lopThayThe(v, t, 1).map((l) => l.maLop), [
          'A-01',
          'A-03',
        ]); // A-02 trùng B-01
        final doi = danhGia(v, {
          1: a2,
          2: b1,
        }); // đổi tay sang lớp trùng → báo trùng
        expect(doi.lyDo.last.dat, isFalse);
        expect(doi.lyDo.last.text, contains('A-02 và B-01'));
      },
    );
  });
}
