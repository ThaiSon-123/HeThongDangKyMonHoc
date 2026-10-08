import re, pathlib, sys

OUT = pathlib.Path(__file__).parent
BVP = (OUT / "bvp-inline.css").read_text(encoding="utf-8")
MSR = (OUT / "msr-inline.css").read_text(encoding="utf-8")
INLINE = "/* === INLINE FONTS (Be Vietnam Pro + Material Symbols Rounded) === */\n" + BVP + "\n" + MSR + "\n"

MOCKUPS = OUT.parent / "mockups"
FILES = [
    "01_login.html",
    "02_student_register.html",
    "03_teacher_attendance.html",
    "04_pdt_class_sections.html",
    "05_accountant_tuition.html",
    "mobile/00_student_app.html",
]

LINK_RE = re.compile(r'<link[^>]*fonts\.googleapis\.com[^>]*>\s*\n?|<link[^>]*fonts\.gstatic\.com[^>]*>\s*\n?', re.I)

for rel in FILES:
    src = MOCKUPS / rel
    html = src.read_text(encoding="utf-8")
    # strip Google Fonts <link> tags
    html2, n = LINK_RE.subn("", html)
    # inject inline @font-face right after first <style> or <style type=...>
    m = re.search(r"<style[^>]*>", html2, re.I)
    if not m:
        print("SKIP (no <style>): %s" % rel)
        continue
    html3 = html2[:m.end()] + "\n" + INLINE + html2[m.end():]
    dest = OUT / (pathlib.Path(rel).stem + ".import.html")
    dest.write_text(html3, encoding="utf-8")
    print("OK  %-32s links removed=%d  %.1f MB -> %s" % (rel, n, dest.stat().st_size / 1048576, dest.name))
