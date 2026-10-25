"""Tính lại điểm hệ 4 (`Grade.gpa_thang_4`) của mọi dòng điểm đã có theo công thức hiện hành (BR-11:
tổng kết × 4 / 10, F = 0, P không có), rồi đồng bộ lại GPA / tín chỉ tích lũy của từng sinh viên (BR-25).

Chạy một lần sau khi đổi công thức hệ 4; chạy lại an toàn (không đổi gì nếu đã đúng).
"""

from django.core.management.base import BaseCommand
from django.db import transaction

from apps.grades.models import Grade
from apps.grades.services import cap_nhat_ho_so, xep_loai_diem


class Command(BaseCommand):
    help = "Tính lại điểm hệ 4 của các dòng điểm đã có và cập nhật GPA sinh viên."

    @transaction.atomic
    def handle(self, *args, **options):
        doi = []
        sv_ids = set()
        for g in Grade.objects.filter(diem_tong_ket__isnull=False).select_related(
            "lop_hoc_phan__mon_hoc", "sinh_vien"
        ):
            chu, gpa = xep_loai_diem(g.diem_tong_ket, g.lop_hoc_phan.mon_hoc.loai_danh_gia)
            if g.gpa_thang_4 != gpa or g.diem_chu != chu:
                g.gpa_thang_4, g.diem_chu = gpa, chu
                doi.append(g)
                sv_ids.add(g.sinh_vien_id)
        Grade.objects.bulk_update(doi, ["gpa_thang_4", "diem_chu"], batch_size=2000)
        for g in {g.sinh_vien_id: g.sinh_vien for g in doi}.values():
            cap_nhat_ho_so(g)
        self.stdout.write(f"Đã tính lại {len(doi)} dòng điểm của {len(sv_ids)} sinh viên.")
