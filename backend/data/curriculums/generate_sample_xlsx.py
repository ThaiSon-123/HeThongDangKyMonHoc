"""Generate xlsx file từ data mẫu đã paste để test import command.

Run từ thư mục backend:
  docker compose exec backend python data/curriculums/generate_sample_xlsx.py
"""
from openpyxl import Workbook

HEADER = [
    "STT", "Mã MH", "Tên môn học", "Số tín chỉ", "Môn bắt buộc",
    "Đã học", "Môn học đã học và đạt", "lý thuyết", "thực hành",
]

SECTIONS = [
    ("Học kỳ 1 - Năm học 2023 - 2024", [
        ("LING022", "Cơ sở lập trình (3+0)",                                3, "x", 45, 0),
        ("LING175", "Nhập môn nhóm ngành Công nghệ thông tin (2+0)",         2, "x", 30, 0),
        ("LING266", "Thực hành Cơ sở lập trình (0+1)",                        1, "x",  0, 30),
        ("LING295", "Thực hành Nhập môn nhóm ngành Công nghệ thông tin (0+1)", 1, "x",  0, 30),
        ("LING344", "Toán cao cấp A1 (2+0)",                                  2, "x", 30, 0),
    ]),
    ("Học kỳ 2 - Năm học 2023 - 2024", [
        ("KTCH002", "Giáo dục thể chất (Lý thuyết) (2+0)",                    2, "x", 30, 0),
        ("KTPM036", "Phương pháp nghiên cứu khoa học (3+0)",                  3, "x", 45, 0),
        ("LING020", "Cơ sở dữ liệu (2+0)",                                    2, "x", 30, 0),
        ("LING093", "Kiến trúc máy tính (2+0)",                               2, "x", 30, 0),
        ("LING105", "Kỹ thuật lập trình (2+0)",                                2, "x", 30, 0),
        ("LING256", "Thiết kế Web (2+0)",                                     2, "x", 30, 0),
        ("LING265", "Thực hành Cơ sở dữ liệu (0+1)",                          1, "x",  0, 30),
        ("LING283", "Thực hành Kỹ thuật lập trình (0+1)",                     1, "x",  0, 30),
        ("LING310", "Thực hành thiết kế Web (0+1)",                           1, "x",  0, 30),
        ("LING345", "Toán cao cấp A2 (2+0)",                                  2, "x", 30, 0),
    ]),
    ("Học kỳ 1 - Năm học 2024 - 2025", [
        ("KTCH003", "Giáo dục quốc phòng an ninh (5+0)",                      5, "x", 75, 0),
        ("KTCH004", "Thực hành Giáo dục quốc phòng an ninh (0+3)",            3, "x",  0, 90),
        ("KTCH006", "Triết học Mác - Lênin (3+0)",                            3, "x", 45, 0),
        ("KTCH014", "Pháp luật đại cương (2+0)",                              2, "x", 30, 0),
        ("LING010", "Cấu trúc dữ liệu và giải thuật (3+0)",                   3, "x", 45, 0),
        ("LING068", "Hệ Quản trị cơ sở dữ liệu (2+0)",                        2, "x", 30, 0),
        ("LING261", "Thực hành Cấu trúc dữ liệu và giải thuật (0+1)",         1, "x",  0, 30),
        ("LING276", "Thực hành Hệ Quản trị cơ sở dữ liệu (0+1)",              1, "x",  0, 30),
        ("LING396", "Xác suất thống kê (3+0)",                                3, "x", 45, 0),
    ]),
]


def main():
    wb = Workbook()
    ws = wb.active
    ws.title = "CTĐT"
    ws.append(HEADER)
    for section_title, courses in SECTIONS:
        # section row: tên trong cột "Tên môn học"
        ws.append(["", "", section_title, "", "", "", "", "", ""])
        for stt, (code, name, credits, required, theory, practice) in enumerate(courses, 1):
            ws.append([stt, code, name, credits, required, "", "", theory, practice])
    out = "data/curriculums/sample_CNTT-2023.xlsx"
    wb.save(out)
    print(f"✓ Wrote {out}")


if __name__ == "__main__":
    main()
