"""Xuất Excel (openpyxl) — plan.md mục 8.2. Pha 3 dùng cho `registrations/export/`; Pha 9 mở rộng."""

from io import BytesIO

from django.http import HttpResponse
from openpyxl import Workbook

XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"


def xlsx_response(filename, headers, rows, sheet="Dữ liệu"):
    wb = Workbook()
    ws = wb.active
    ws.title = sheet
    ws.append(list(headers))
    for row in rows:
        ws.append(list(row))
    buf = BytesIO()
    wb.save(buf)
    res = HttpResponse(buf.getvalue(), content_type=XLSX)
    res["Content-Disposition"] = f'attachment; filename="{filename}"'
    return res
