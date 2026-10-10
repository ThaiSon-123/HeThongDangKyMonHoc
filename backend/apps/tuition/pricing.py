"""Thuật toán giá (BR-16/17) — plan.md mục 4.3.

BR-16: duyệt **2 trục** theo thứ tự — (1) `hoc_ky` = học kỳ đang tính, (2)
`hoc_ky IS NULL`. Trong mỗi trục xét `pham_vi` theo thứ tự `KHOI_KIEN_THUC` →
`NGANH` → `MAC_DINH`, dừng ở bản ghi khớp đầu tiên = **đơn giá gốc**.

BR-17: đơn giá phần lý thuyết = đơn giá gốc; đơn giá phần thực hành = bản ghi
`GIA_TH` (tra cùng 2 trục `hoc_ky`) nếu có, ngược lại = đơn giá gốc.

`bang_gia` là list dòng `HocPhanGia` (queryset cũng iterable nên truyền thẳng
được) — nhận list để self-check chạy được không cần DB.
"""

from dataclasses import dataclass
from decimal import Decimal

from apps.tuition.models import HocPhanGia


@dataclass
class GiaApDung:
    don_gia_goc: Decimal
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

    gia_th = next((row for hk in truc if (row := khop(P.GIA_TH, None, hk)) is not None), None)
    don_gia_th = gia_th.don_gia if gia_th is not None else goc.don_gia

    return GiaApDung(
        goc.don_gia,
        don_gia_th,
        tin_chi_lt * goc.don_gia + tin_chi_th * don_gia_th,
        goc.pham_vi,
        goc.hoc_ky_id,
    )


if (
    __name__ == "__main__"
):  # self-check: python manage.py shell -c "import runpy; runpy.run_module('apps.tuition.pricing', run_name='__main__')"
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

    # BR-17: không có GIA_TH → TH = đơn giá gốc; có GIA_TH → TH dùng GIA_TH, LT vẫn là gốc.
    g = tra_bang_gia(day_du, "CNTT", "chuyen_nganh", **kw)
    assert g.don_gia_th == D("150") and g.tong_tien == 5 * D("150"), "không GIA_TH → 5 × gốc"
    g = tra_bang_gia(day_du + [row(P.GIA_TH, None, "77")], "CNTT", "chuyen_nganh", **kw)
    assert g.don_gia_th == D("77"), "GIA_TH thắng đơn giá gốc"
    assert g.tong_tien == 3 * D("150") + 2 * D("77"), "3 LT × 150 + 2 TH × 77"

    # GIA_TH cũng tra theo 2 trục: bản ghi của học kỳ thắng bản mặc định.
    g = tra_bang_gia(
        day_du + [row(P.GIA_TH, None, "77"), row(P.GIA_TH, None, "60", hk=9)],
        "CNTT",
        "chuyen_nganh",
        hoc_ky_id=9,
        **kw,
    )
    assert g.don_gia_th == D("60"), "GIA_TH học kỳ > GIA_TH mặc định"

    try:
        tra_bang_gia([row(P.NGANH, "KTPM", "120")], "CNTT", "chuyen_nganh", **kw)
    except ValueError:
        pass
    else:
        raise AssertionError("phải raise khi không có bảng giá nào khớp")
    print("pricing ok")
