"""Thuật toán giá (BR-16/17) — plan.md dòng 334-335.

BR-16: duyệt **2 trục** theo thứ tự — (1) `hoc_ky` = học kỳ đang tính, (2)
`hoc_ky IS NULL`. Trong mỗi trục xét `pham_vi` theo thứ tự `KHOI_KIEN_THUC` →
`NGANH` → `MAC_DINH`, dừng ở bản ghi khớp đầu tiên = **đơn giá gốc**.

BR-17: `LECH_LT`/`LECH_TH`/`GIA_TH` KHÔNG phải trục so sánh mà là hệ số điều
chỉnh áp lên đơn giá gốc, khớp theo **khối kiến thức của môn trong CTĐT của SV**
(không xét trục ngành), tra độc lập theo cùng 2 trục `hoc_ky`.

`bang_gia` là list dòng `HocPhanGia` (queryset cũng iterable nên truyền thẳng
được) — nhận list để self-check chạy được không cần DB.
`hieu_luc_tu` không xét (BR-16 loại khỏi thuật toán).
"""

from dataclasses import dataclass
from decimal import Decimal

from apps.tuition.models import HocPhanGia


@dataclass
class GiaApDung:
    don_gia_goc: Decimal
    don_gia_lt: Decimal
    don_gia_th: Decimal
    tong_tien: Decimal
    pham_vi_goc: str
    hoc_ky_goc_id: int | None


def tra_bang_gia(
    bang_gia,
    nganh: str,
    khoi_kien_thuc: str,
    *,
    tin_chi_lt: int,
    tin_chi_th: int,
    hoc_ky_id: int | None = None,
) -> GiaApDung:
    P = HocPhanGia.PhamVi
    truc = (hoc_ky_id, None)  # (1) học kỳ đang tính, (2) mặc định

    def khop(pham_vi, tham_chieu, hk):
        return next(
            (
                r
                for r in bang_gia
                if r.pham_vi == pham_vi and r.tham_chieu == tham_chieu and r.hoc_ky_id == hk
            ),
            None,
        )

    def tra(pham_vi, tham_chieu):
        """Tra 1 loại bản ghi theo 2 trục — mỗi loại tra độc lập (BR-17)."""
        for hk in truc:
            row = khop(pham_vi, tham_chieu, hk)
            if row is not None:
                return row
        return None

    goc = next(
        (
            row
            for hk in truc
            for pv, tc in ((P.KHOI_KIEN_THUC, khoi_kien_thuc), (P.NGANH, nganh), (P.MAC_DINH, None))
            if (row := khop(pv, tc, hk)) is not None
        ),
        None,
    )
    if goc is None:
        raise ValueError(f"Không có bảng giá khớp: nganh={nganh} khoi={khoi_kien_thuc}")

    lech_lt = tra(P.LECH_LT, khoi_kien_thuc)
    don_gia_lt = goc.don_gia * (1 + lech_lt.don_gia) if lech_lt else goc.don_gia

    gia_th, lech_th = tra(P.GIA_TH, khoi_kien_thuc), tra(P.LECH_TH, khoi_kien_thuc)
    if gia_th is not None:
        don_gia_th = gia_th.don_gia
    elif lech_th is not None:
        don_gia_th = goc.don_gia * (1 + lech_th.don_gia)
    else:
        don_gia_th = goc.don_gia

    return GiaApDung(
        goc.don_gia,
        don_gia_lt,
        don_gia_th,
        tin_chi_lt * don_gia_lt + tin_chi_th * don_gia_th,
        goc.pham_vi,
        goc.hoc_ky_id,
    )


if (
    __name__ == "__main__"
):  # self-check: DJANGO_SETTINGS_MODULE=config.settings.dev python -m apps.tuition.pricing
    P, D = HocPhanGia.PhamVi, Decimal

    def row(pham_vi, tham_chieu, don_gia, hk=None):
        return type(
            "R",
            (),
            {"pham_vi": pham_vi, "tham_chieu": tham_chieu, "don_gia": D(don_gia), "hoc_ky_id": hk},
        )()

    kw = dict(tin_chi_lt=3, tin_chi_th=2)
    day_du = [
        row(P.MAC_DINH, None, "100"),
        row(P.NGANH, "CNTT", "120"),
        row(P.KHOI_KIEN_THUC, "chuyen_nganh", "150"),
    ]
    assert tra_bang_gia(day_du, "CNTT", "chuyen_nganh", **kw).don_gia_goc == D(
        "150"
    ), "khối > ngành"
    assert tra_bang_gia(day_du, "CNTT", "co_so_nganh", **kw).don_gia_goc == D(
        "120"
    ), "ngành > mặc định"
    assert tra_bang_gia(day_du, "KTPM", "co_so_nganh", **kw).don_gia_goc == D(
        "100"
    ), "rơi về mặc định"

    # Trục (1) học kỳ thắng trục (2) rỗng, dù phạm vi ở trục (2) cụ thể hơn.
    hai_truc = day_du + [row(P.MAC_DINH, None, "200", hk=9)]
    assert tra_bang_gia(hai_truc, "CNTT", "chuyen_nganh", hoc_ky_id=9, **kw).don_gia_goc == D("200")

    # BR-17: LECH_LT nhân (1 + hệ số); GIA_TH thắng LECH_TH; LT/TH cộng theo tín chỉ.
    g = tra_bang_gia(day_du + [row(P.LECH_LT, "chuyen_nganh", "0.1")], "CNTT", "chuyen_nganh", **kw)
    assert g.don_gia_lt == D("165") and g.don_gia_th == D("150"), "lệch LT chỉ áp cho LT"
    assert g.tong_tien == 3 * D("165") + 2 * D("150"), "3 LT × 165 + 2 TH × 150"

    g = tra_bang_gia(
        day_du + [row(P.LECH_TH, "chuyen_nganh", "0.5"), row(P.GIA_TH, "chuyen_nganh", "77")],
        "CNTT",
        "chuyen_nganh",
        **kw,
    )
    assert g.don_gia_th == D("77"), "GIA_TH thắng LECH_TH"

    try:
        tra_bang_gia([row(P.NGANH, "KTPM", "120")], "CNTT", "chuyen_nganh", **kw)
    except ValueError:
        pass
    else:
        raise AssertionError("phải raise khi không có bảng giá nào khớp")
    print("pricing ok")
