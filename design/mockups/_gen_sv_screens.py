"""Sinh 10 mockup màn Sinh viên còn lại, tái dùng nguyên khung của 02_student_register.html
(cùng <style>, cùng sidebar/topbar). Chỉ khác: nav active, breadcrumb, khối .content.

Chạy:  python -I design/mockups/_gen_sv_screens.py
"""
import pathlib

HERE = pathlib.Path(__file__).parent
FULL = (HERE / "02_student_register.html").read_text(encoding="utf-8")
STYLE = FULL[FULL.index("<style>"): FULL.index("</style>") + len("</style>")]

BRAND = """    <div class="brand">
      <div class="brand-logo">ĐK</div>
      <div><div class="n">Đăng ký môn học</div><div class="r">Đại học Khoa học · 2026–2027</div></div>
    </div>"""

USER = """    <div class="side-user">
      <div class="av">NA</div>
      <div><div class="n">Nguyễn Văn An</div><div class="r">SV2251012345 · CNTT · K2025</div></div>
      <span class="msr out">logout</span>
    </div>"""

NAV = [
    ("sec", "Học kỳ 20263"),
    ("playlist_add_check", "Đăng ký môn học"),
    ("auto_awesome", "Tạo TKB tự động"),
    ("calendar_month", "Thời khóa biểu"),
    ("sec", "Học vụ"),
    ("menu_book", "Chương trình đào tạo"),
    ("grade", "Điểm"),
    ("fact_check", "Điểm danh"),
    ("account_balance_wallet", "Học phí"),
    ("repeat", "Học lại · Cải thiện"),
    ("sec", "Khác"),
    ("notifications", "Thông báo"),
    ("person", "Hồ sơ"),
    ("logout", "Đăng xuất"),
]

TPL = """<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Be+Vietnam+Pro:wght@400;500;600;700;800&display=swap" rel="stylesheet">
<link href="https://fonts.googleapis.com/css2?family=Material+Symbols+Rounded:opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200" rel="stylesheet">
__STYLE__
<style>__EXTRA__</style>
</head>
<body>
<div class="layout">
  <aside class="sidebar">
__BRAND__
    <nav>
__NAV__
    </nav>
__USER__
  </aside>
  <div class="main">
    <div class="topbar">
      <span class="crumb">Học kỳ 20263 / <b>__CRUMB__</b></span>
      <div class="search"><span class="msr">search</span><input placeholder="Tìm môn, mã lớp, giảng viên…"></div>
      <span class="countdown"><span class="msr" style="font-size:16px">schedule</span> Cửa sổ ĐK còn 4 ngày</span>
      <div class="bell"><span class="msr">notifications</span><span class="badge">3</span></div>
      <div class="avatar">A</div>
    </div>
    <div class="content">
__CONTENT__
    </div>
  </div>
</div>
</body>
</html>
"""


def nav_html(active: str) -> str:
    rows = []
    for icon, label in NAV:
        if icon == "sec":
            rows.append('      <div class="sec">%s</div>' % label)
            continue
        cls, fill = (' class="active"', " fill") if label == active else ("", "")
        bdg = '<span class="bdg">3</span>' if label == "Thông báo" else ""
        rows.append('      <a%s><span class="msr%s">%s</span> %s%s</a>'
                    % (cls, fill, icon, label, bdg))
    return "\n".join(rows)


def write(file, title, active, crumb, content, extra=""):
    html = (TPL.replace("__STYLE__", STYLE)
                .replace("__EXTRA__", extra)
                .replace("__BRAND__", BRAND)
                .replace("__NAV__", nav_html(active))
                .replace("__USER__", USER)
                .replace("__CRUMB__", crumb)
                .replace("__CONTENT__", content.strip("\n")))
    html = html.replace("<meta name", '<title>%s — Sinh viên · Academia ấm</title>\n<meta name' % title, 1)
    dest = HERE / file
    dest.write_text(html, encoding="utf-8")
    print("OK  %-34s %6.1f KB" % (file, dest.stat().st_size / 1024))


# Extra CSS dùng chung cho bảng / tab / lưới nhãn-giá-trị (base style không có)
X = """
.tbl{width:100%;border-collapse:collapse;font-size:13px}
.tbl th{text-align:left;font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--m3-on-surface-variant);font-weight:700;padding:10px 14px;border-bottom:1px solid var(--m3-outline)}
.tbl td{padding:12px 14px;border-bottom:1px solid var(--m3-outline);vertical-align:middle}
.tbl tbody tr:last-child td{border-bottom:0}
.tbl .r{text-align:right}
.tbl .num{font-variant-numeric:tabular-nums;font-weight:600}
.tbl .dim{color:var(--m3-on-surface-variant)}
.pad0{padding:0;overflow:hidden}
.tabs{display:flex;gap:4px;border-bottom:1px solid var(--m3-outline);margin-bottom:16px}
.tabs a{padding:9px 14px;font-size:13px;font-weight:600;color:var(--m3-on-surface-variant);border-bottom:2px solid transparent;cursor:pointer}
.tabs a.on{color:var(--m3-primary);border-bottom-color:var(--m3-primary)}
.kv{font-size:13px}
.kv .row{display:grid;grid-template-columns:190px 1fr;gap:14px;padding:11px 0;border-bottom:1px solid var(--m3-outline)}
.kv .row:last-child{border-bottom:0}
.kv .k{color:var(--m3-on-surface-variant)}
.kv .v{font-weight:500}
.lrow{display:flex;gap:12px;align-items:flex-start;padding:14px 16px;border-bottom:1px solid var(--m3-outline)}
.lrow:last-child{border-bottom:0}
.lrow .ic{width:34px;height:34px;border-radius:10px;display:grid;place-items:center;flex:0 0 34px;font-size:18px}
.lrow .bd{flex:1;min-width:0}
.lrow .bd .t{font-weight:600;font-size:13.5px}
.lrow .bd .m{font-size:12px;color:var(--m3-on-surface-variant);margin-top:3px}
.lrow.unread{background:var(--m3-surface-variant);box-shadow:inset 3px 0 0 var(--accent)}
.pick{display:flex;gap:10px;align-items:center;padding:10px 12px;border:1px solid var(--m3-outline);border-radius:10px;margin-bottom:8px;background:var(--m3-surface)}
.pick.on{border-color:var(--m3-primary);background:var(--m3-primary-container)}
.pick input{accent-color:var(--m3-primary);width:15px;height:15px}
.pick .n{flex:1;font-size:13px;font-weight:500}
.pick .m{font-size:12px;color:var(--m3-on-surface-variant)}
.opt{display:flex;gap:8px;flex-wrap:wrap}
.opt .o{padding:7px 12px;font-size:12.5px;border:1px solid var(--m3-outline);border-radius:20px;background:var(--m3-surface);color:var(--m3-on-surface-variant)}
.opt .o.on{border-color:var(--m3-primary);background:var(--m3-primary-container);color:var(--m3-primary);font-weight:600}
.opt .o.dis{opacity:.5;text-decoration:line-through}
.big{font-size:30px;font-weight:800;line-height:1.05;letter-spacing:-.02em}
.bar{height:9px;border-radius:6px;background:var(--m3-surface-variant);overflow:hidden;margin-top:7px}
.bar i{display:block;height:100%;background:var(--m3-primary)}
.bar i.a{background:var(--accent)}
.bar i.e{background:var(--m3-error)}
.bar i.g{background:var(--m3-primary)}
.bar i.b{background:#3B5B92}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:12px}
.stat{padding:14px;border:1px solid var(--m3-outline);border-radius:12px;background:var(--m3-surface)}
.stat .v{font-size:24px;font-weight:800;letter-spacing:-.02em}
.stat .l{font-size:11px;letter-spacing:.06em;text-transform:uppercase;color:var(--m3-on-surface-variant);margin-top:4px}
.why{font-size:12.5px;padding:10px 12px;border-radius:8px;background:var(--m3-surface-variant);color:var(--m3-on-surface-variant);margin-top:12px}
.form label{display:block;font-size:12px;font-weight:600;color:var(--m3-on-surface-variant);margin:14px 0 6px}
.form input{width:100%;height:42px;border:1px solid var(--m3-outline);border-radius:10px;background:var(--m3-surface);color:var(--m3-on-surface);padding:0 12px;font:inherit;font-size:13px}
.form textarea{width:100%;min-height:84px;padding:10px 12px;font:inherit;font-size:13px;border:1px solid var(--m3-outline);border-radius:10px;background:var(--m3-surface);color:var(--m3-on-surface);resize:vertical}
.s4{background:var(--tk4-bg);border-color:var(--tk4-fg);color:var(--tk4-fg)}
.dim{color:var(--m3-on-surface-variant)}
@keyframes blink{0%{background:#FEF3C7}100%{background:transparent}}
.fade-in{animation:blink 1.6s ease-out 1}
"""

# ============================== SV-02 · HỒ SƠ CÁ NHÂN ==============================
PROFILE = """
<div class="page-head">
  <div>
    <h1>Hồ sơ cá nhân</h1>
    <div class="sub">Thông tin học vụ không tự sửa được — chỉ email và số điện thoại cập nhật tại đây.</div>
  </div>
</div>

<div class="cols">
  <div>
    <div class="card">
      <div class="course-top">
        <div class="avatar" style="width:52px;height:52px;font-size:20px;border-radius:14px">NA</div>
        <div class="course-name">
          <div class="t">Nguyễn Văn An</div>
          <div class="m">SV2251012345 · Nam · 12/04/2005</div>
        </div>
        <span class="chip mo"><span class="dot"></span>ĐANG HỌC</span>
      </div>
    </div>

    <div class="panel" style="margin-top:14px">
      <h3>Thông tin học vụ <span class="lnk">Nguồn: PĐT</span></h3>
      <div class="kv">
        <div class="row"><div class="k">Mã sinh viên</div><div class="v">SV2251012345</div></div>
        <div class="row"><div class="k">Ngành</div><div class="v">Công nghệ thông tin</div></div>
        <div class="row"><div class="k">Chuyên ngành</div><div class="v">Hệ thống thông tin</div></div>
        <div class="row"><div class="k">Khóa nhập học</div><div class="v">K2025 · Khoa CNTT</div></div>
        <div class="row"><div class="k">Hệ đào tạo</div><div class="v">Chính quy · Học phí</div></div>
        <div class="row"><div class="k">Trạng thái</div><div class="v">ĐANG HỌC · kỳ 3 (2026–2027)</div></div>
      </div>
    </div>

    <div class="panel">
      <h3>Liên hệ <span class="lnk">Sửa được</span></h3>
      <div class="form">
        <label>Email</label>
        <input value="an.nv2251012345@sv.daihoc.edu.vn">
        <label>Số điện thoại</label>
        <input value="0912 345 678">
      </div>
      <div class="course-actions"><button class="btn btn-filled"><span class="msr">save</span> Lưu liên hệ</button></div>
      <div class="foot-note"><span class="msr" style="font-size:16px">lock</span> Chỉ email / số điện thoại được sửa (PATCH /api/profiles/me/)</div>
    </div>
  </div>

  <div>
    <div class="panel">
      <h3>Kết quả học tập</h3>
      <div class="grid2">
        <div class="stat"><div class="v">3.42</div><div class="l">GPA học kỳ</div></div>
        <div class="stat"><div class="v">3.28</div><div class="l">GPA tích lũy</div></div>
      </div>
      <div style="margin-top:14px">
        <div class="tui-row"><span>Xếp loại học kỳ</span><span class="val">Khá</span></div>
        <div class="tui-row"><span>Xếp loại tích lũy</span><span class="val">Khá</span></div>
        <div class="tui-row total"><span>Tín chỉ tích lũy</span><span class="val due">74 / 120</span></div>
      </div>
      <div class="bar"><i class="g" style="width:62%"></i></div>
      <div class="foot-note"><span class="msr" style="font-size:16px">info</span> Tín chỉ tích lũy = tổng TC các môn điểm KHOA ≥ 5.0 (BR-25)</div>
    </div>

    <div class="panel">
      <h3>Đổi mật khẩu</h3>
      <div class="form">
        <label>Mật khẩu hiện tại</label>
        <input type="password" value="········">
        <label>Mật khẩu mới</label>
        <input type="password" value="········">
        <label>Nhập lại mật khẩu mới</label>
        <input type="password" value="········">
      </div>
      <div class="course-actions"><button class="btn btn-filled"><span class="msr">lock_reset</span> Đổi mật khẩu</button></div>
    </div>
  </div>
</div>
"""

# ============================== SV-03 · CHƯƠNG TRÌNH ĐÀO TẠO ==============================
CURRICULUM = """
<div class="page-head">
  <div>
    <h1>Chương trình đào tạo</h1>
    <div class="sub">CTĐT CNTT · hệ chính quy · khóa K2025 · 120 tín chỉ (98 bắt buộc + 22 tự chọn)</div>
  </div>
  <div class="kpi">
    <div class="k g"><div class="v">18/30</div><div class="l">MÔN ĐÃ ĐẠT</div></div>
    <div class="k a"><div class="v">12</div><div class="l">MÔN ĐANG HỌC</div></div>
  </div>
</div>

<div class="warn-banner">
  <span class="msr fill">warning</span>
  <span>Thiếu <b>3 môn bắt buộc</b> của khối chuyên ngành và <b>1 môn tự chọn bắt buộc</b> để đủ 120 tín chỉ.</span>
  <span class="lnk">Xem gợi ý học kỳ tới →</span>
</div>

<div class="cols">
  <div>
    <div class="tabs">
      <a class="on">Tất cả (48)</a><a>Khối chung (12)</a><a>Khối cơ sở ngành (14)</a><a>Chuyên ngành (10)</a><a>Tự chọn (12)</a>
    </div>

    <div class="filterbar">
      <div class="f"><label>Loại môn</label><select>Bắt buộc</select></div>
      <div class="f"><label>Trạng thái</label><select>Đã đạt</select></div>
      <div class="f f-search"><label>Tìm nhanh</label><input placeholder="VD: CNTT203, Cơ sở dữ liệu…"></div>
      <button class="btn btn-outline"><span class="msr">filter_list</span> Lọc</button>
    </div>

    <div class="card pad0">
      <table class="tbl">
        <thead><tr><th>Mã môn</th><th>Tên môn</th><th class="r">TC</th><th>Khối kiến thức</th><th>Kỳ gợi ý</th><th>Trạng thái</th></tr></thead>
        <tbody>
          <tr><td class="num">MAT101</td><td>Toán cao cấp 1</td><td class="r num">3</td><td class="dim">chung</td><td class="dim">Kỳ 1</td><td><span class="chip mo"><span class="dot"></span>ĐÃ ĐẠT 7.5</span></td></tr>
          <tr><td class="num">MAT102</td><td>Giải tích 2</td><td class="r num">4</td><td class="dim">chung</td><td class="dim">Kỳ 2</td><td><span class="chip dh"><span class="dot"></span>ĐANG HỌC 8.0</span></td></tr>
          <tr><td class="num">CNTT102</td><td>Cấu trúc dữ liệu &amp; giải thuật</td><td class="r num">4</td><td class="dim">co_so_nganh</td><td class="dim">Kỳ 3</td><td><span class="chip mo"><span class="dot"></span>ĐÃ ĐẠT 6.5</span></td></tr>
          <tr><td class="num">CNTT203</td><td>Cơ sở dữ liệu</td><td class="r num">4</td><td class="dim">co_so_nganh</td><td class="dim">Kỳ 4</td><td><span class="chip red"><span class="dot"></span>ĐÃ ĐẠT 4.5 — RỚT</span></td></tr>
          <tr><td class="num">CNTT301</td><td>Mạng máy tính</td><td class="r num">3</td><td class="dim">chuyen_nganh</td><td class="dim">Kỳ 5</td><td><span class="chip kh"><span class="dot"></span>CHƯA HỌC</span></td></tr>
          <tr><td class="num">CNTT401</td><td>Trí tuệ nhân tạo</td><td class="r num">3</td><td class="dim">tu_chon</td><td class="dim">Kỳ 6–8</td><td><span class="chip kh"><span class="dot"></span>CHƯA HỌC</span></td></tr>
          <tr><td class="num">CNTT409</td><td>Thực tập tốt nghiệp</td><td class="r num">10</td><td class="dim">tot_nghiep</td><td class="dim">Kỳ 9</td><td><span class="chip dd"><span class="dot"></span>CHƯA MỞ ĐK</span></td></tr>
        </tbody>
      </table>
    </div>
    <div class="foot-note"><span class="msr" style="font-size:16px">info</span> Môn <b>ĐÃ ĐẠT &lt; 5.0</b> cần đơn học lại được duyệt mới đăng ký lại được (BR-04)</div>
  </div>

  <div>
    <div class="panel">
      <h3>Tiến độ CTĐT</h3>
      <div class="tui-row"><span>Khối chung · 12 môn</span><span class="val">12/12</span></div>
      <div class="bar" style="margin-bottom:6px"><i class="g" style="width:100%"></i></div>
      <div class="tui-row"><span>Khối cơ sở ngành · 14 môn</span><span class="val">13/14</span></div>
      <div class="bar" style="margin-bottom:6px"><i class="b" style="width:93%"></i></div>
      <div class="tui-row"><span>Chuyên ngành · 10 môn</span><span class="val">6/10</span></div>
      <div class="bar" style="margin-bottom:6px"><i class="a" style="width:60%"></i></div>
      <div class="tui-row"><span>Tự chọn · 12 môn</span><span class="val">3/12</span></div>
      <div class="bar"><i class="e" style="width:25%"></i></div>
    </div>

    <div class="panel">
      <h3>Gợi ý học kỳ tới (kỳ 4)</h3>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk2-bg);color:var(--tk2-fg)"><span class="c" style="font-size:12px">CS</span></div>
        <div class="in"><div class="t">Cơ sở dữ liệu</div><div class="m">4 TC · tiên quyết CNTT102 ✓</div></div>
        <span class="chip red"><span class="dot"></span>Cần đơn</span>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk1-bg);color:var(--tk1-fg)"><span class="c" style="font-size:12px">MM</span></div>
        <div class="in"><div class="t">Mạng máy tính</div><div class="m">3 TC · tiên quyết CNTT202 ✓</div></div>
        <span class="chip mo"><span class="dot"></span>Sẵn sàng</span>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk4-bg);color:var(--tk4-fg)"><span class="c" style="font-size:11px">PTPM</span></div>
        <div class="in"><div class="t">Phát triển phần mềm</div><div class="m">3 TC · tự chọn bắt buộc</div></div>
        <span class="chip mo"><span class="dot"></span>Sẵn sàng</span>
      </div>
      <div class="foot-note"><span class="msr" style="font-size:16px">info</span> Đề xuất theo CTĐT + điều kiện tiên quyết (BR-04)</div>
    </div>
  </div>
</div>
"""

# ============================== SV-06 · TẠO TKB TỰ ĐỘNG ==============================
AUTO_SCHEDULE = """
<div class="page-head">
  <div>
    <h1>Tạo TKB tự động</h1>
    <div class="sub">Chọn môn + ưu tiên → hệ thống gợi ý tối đa 3 tổ hợp lịch không trùng. Gợi ý KHÔNG tự đăng ký.</div>
  </div>
</div>
<div class="cols">
  <div>
    <div class="panel">
      <h3>Bước 1 · Chọn môn muốn xếp</h3>
      <div class="pick on">
        <input type="checkbox" checked>
        <div class="n">Cơ sở dữ liệu <span class="dim">· CNTT203 · 4 TC</span></div>
        <span class="chip mo"><span class="dot"></span>Tiên quyết ✓</span>
      </div>
      <div class="pick on">
        <input type="checkbox" checked>
        <div class="n">Mạng máy tính <span class="dim">· CNTT301 · 3 TC</span></div>
        <span class="chip mo"><span class="dot"></span>Tiên quyết ✓</span>
      </div>
      <div class="pick">
        <input type="checkbox">
        <div class="n">Phát triển phần mềm <span class="dim">· CNTT305 · 3 TC</span></div>
        <span class="chip kh"><span class="dot"></span>Tự chọn</span>
      </div>
      <div class="pick">
        <input type="checkbox">
        <div class="n">Nhập môn lập trình <span class="dim">· CNTT101 · 3 TC · học lại</span></div>
        <span class="chip red"><span class="dot"></span>Học lại</span>
      </div>
      <div class="pick" style="opacity:.55">
        <input type="checkbox" disabled>
        <div class="n">Trí tuệ nhân tạo <span class="dim">· CNTT401 · 3 TC</span></div>
        <span class="chip red"><span class="dot"></span>Thiếu tiên quyết</span>
      </div>
      <div class="why">BR-04: môn có tiên quyết phải đạt KHOA ≥ 5.00 và không bị cấm thi. Môn học lại cần đơn được duyệt.</div>
    </div>
    <div class="panel">
      <h3>Bước 2 · Ưu tiên xếp lịch</h3>
      <div class="f" style="margin-bottom:12px">
        <div class="f" style="flex:1"><label>Buổi học</label>
          <div class="opt"><span class="o on">Sáng</span><span class="o">Chiều</span><span class="o">Tối</span><span class="o">Không kén</span></div>
        </div>
        <div class="f" style="flex:1"><label>Giảng viên</label>
          <div class="opt"><span class="o on">Ưu tiên GV A</span><span class="o">Không kén</span></div>
        </div>
      </div>
      <div class="f" style="margin-bottom:12px">
        <div class="f" style="flex:1"><label>Thời gian</label>
          <div class="opt"><span class="o">Sáng sớm</span><span class="o on">Tránh T7</span><span class="o">Tránh tiết 1</span></div>
        </div>
        <div class="f" style="flex:1"><label>Giãn cách</label>
          <div class="opt"><span class="o on">0 tiết</span><span class="o">1 tiết</span><span class="o">2 tiết</span></div>
        </div>
      </div>
      <div class="course-actions"><button class="btn btn-filled"><span class="msr fill">auto_awesome</span>Tạo gợi ý</button></div>
    </div>
  </div>
  <div>
    <div class="panel">
      <h3>3 tổ hợp gợi ý</h3>
      <div class="reg-item">
        <div class="in"><div class="t">Tổ hợp A · 0 xung đột</div><div class="m">Phù hợp 100% ưu tiên</div></div>
        <span class="chip mo"><span class="dot"></span>100%</span>
      </div>
      <div class="sched" style="margin:10px 0 6px">
        <div class="hd"></div><div class="hd">T2</div><div class="hd">T3</div><div class="hd">T4</div><div class="hd">T5</div><div class="hd">T6</div><div class="hd">T7</div>
        <div class="t">1</div><div class="cell"><div class="blk s1" style="height:56px">CSDL·.201</div></div><div class="cell"></div><div class="cell"><div class="blk s1" style="height:56px">CSDL·.201</div></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
        <div class="t">6</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"><div class="blk s3" style="height:56px">PTPM·.1</div></div><div class="cell"></div>
        <div class="t">8</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"><div class="blk s2" style="height:56px">MMT·.1</div></div><div class="cell"></div>
      </div>
      <div class="legend">
        <span class="lg"><i style="background:var(--tk1-bg)"></i>CSDL</span>
        <span class="lg"><i style="background:var(--tk2-bg)"></i>MMT</span>
        <span class="lg"><i style="background:var(--tk3-bg)"></i>PTPM</span>
      </div>
      <div class="course-actions"><button class="btn btn-filled"><span class="msr fill">check_circle</span>Chọn tổ hợp A</button></div>
    </div>
    <div class="panel">
      <h3>Các tổ hợp khác</h3>
      <div class="reg-item">
        <div class="in"><div class="t">Tổ hợp B</div><div class="m">Phù hợp 80% · 1 lớp PTPM chiều</div></div>
        <span class="chip dh"><span class="dot"></span>80%</span>
      </div>
      <div class="reg-item">
        <div class="in"><div class="t">Tổ hợp C</div><div class="m">Phù hợp 60% · tránh T7 thất bại</div></div>
        <span class="chip amber"><span class="dot"></span>60%</span>
      </div>
      <div class="foot-note"><span class="msr" style="font-size:16px">info</span> Thuật toán chạy hoàn toàn trên máy (Dart) — không gửi lịch hiện tại lên máy chủ.</div>
    </div>
  </div>
</div>
"""

# ============================== SV-08 · THỜI KHÓA BIỂU ==============================
TIMETABLE = """
<div class="page-head">
  <div>
    <h1>Thời khóa biểu</h1>
    <div class="sub">Học kỳ 20263 · tuần 3 (05/10 – 11/10/2026) · 6 lớp · 18 tín chỉ</div>
  </div>
  <div class="kpi">
    <div class="k"><div class="v">15</div><div class="l">Tiết/tuần</div></div>
    <div class="k g"><div class="v">0</div><div class="l">Xung đột</div></div>
  </div>
</div>
<div class="tabs">
  <a class="on">Tuần này</a><a>Cả học kỳ</a><a>Tổng hợp theo môn</a>
</div>
<div class="cols" style="grid-template-columns:1fr 360px">
  <div>
    <div class="filterbar">
      <div class="f" style="min-width:140px"><label>Tuần</label>
        <select><option>Tuần 3 · 05–11/10</option><option>Tuần 2 · 28/09–04/10</option><option>Tuần 4 · 12–18/10</option></select></div>
      <div class="f" style="min-width:150px"><label>Lọc môn</label>
        <select><option>Tất cả môn</option><option>Cơ sở dữ liệu</option><option>Mạng máy tính</option><option>Phát triển phần mềm</option></select></div>
      <div class="f" style="min-width:130px"><label>Tìm phòng</label>
        <input placeholder="VD: C302"></div>
      <div class="f" style="min-width:150px"><label>Giảng viên</label>
        <input placeholder="VD: Trần Văn B"></div>
    </div>
    <div class="sched">
      <div class="hd"></div><div class="hd">T2</div><div class="hd">T3</div><div class="hd">T4</div><div class="hd">T5</div><div class="hd">T6</div><div class="hd">T7</div>
      <div class="t">1</div><div class="cell"><div class="blk s1" style="height:56px">LTNC·201</div></div><div class="cell"></div><div class="cell"><div class="blk s1" style="height:56px">LTNC·201</div></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">2</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">3</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">4</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">5</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">6</div><div class="cell"></div><div class="cell"></div><div class="cell"><div class="blk s3" style="height:56px">PTPM·C302</div></div><div class="cell"></div><div class="cell"><div class="blk s2" style="height:56px">MMT·D105</div></div><div class="cell"></div>
      <div class="t">7</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">8</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">9</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">10</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">11</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"><div class="blk s4" style="height:56px">AI·D201</div></div><div class="cell"></div><div class="cell"></div>
      <div class="t">12</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">13</div><div class="cell"></div><div class="cell"></div><div class="cell"><div class="blk s2" style="height:56px">GT2·102</div></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
      <div class="t">14</div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div><div class="cell"></div>
    </div>
    <div class="legend">
      <span class="lg"><i style="background:var(--tk1-bg)"></i>LTNC</span>
      <span class="lg"><i style="background:var(--tk2-bg)"></i>MMT · GT2</span>
      <span class="lg"><i style="background:var(--tk3-bg)"></i>PTPM</span>
      <span class="lg"><i style="background:var(--tk4-bg)"></i>AI</span>
    </div>
  </div>
  <div>
    <div class="panel">
      <h3>Chi tiết lớp trong tuần</h3>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk1-bg);color:var(--tk1-fg)"><span class="c" style="font-size:11px">LTNC</span></div>
        <div class="in"><div class="t">Lập trình nâng cao · LTNC201</div><div class="m">T2, T4 · tiết 1–2 · Phòng 201 · Trần Văn B</div></div>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk3-bg);color:var(--tk3-fg)"><span class="c" style="font-size:11px">PTPM</span></div>
        <div class="in"><div class="t">Phát triển phần mềm · PTPM305</div><div class="m">T3, T5 · tiết 6–8 · Phòng C302 · Nguyễn Thị C</div></div>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk2-bg);color:var(--tk2-fg)"><span class="c" style="font-size:11px">MMT</span></div>
        <div class="in"><div class="t">Mạng máy tính · MMT301</div><div class="m">T3, T5 · tiết 6–7 · Phòng D105 · Trần Văn B</div></div>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk4-bg);color:var(--tk4-fg)"><span class="c" style="font-size:11px">AI</span></div>
        <div class="in"><div class="t">Trí tuệ nhân tạo · AI401</div><div class="m">T4 · tiết 11–12 · Phòng D201 · Lê Văn D</div></div>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk2-bg);color:var(--tk2-fg)"><span class="c" style="font-size:11px">GT2</span></div>
        <div class="in"><div class="t">Giải tích 2 · GT2101</div><div class="m">T3 · tiết 13–14 · Phòng 102 · Phạm Thị E</div></div>
      </div>
    </div>
    <div class="panel">
      <h3>Tóm tắt</h3>
      <div class="tui-row"><span>Buổi sáng</span><span class="val">6 tiết</span></div>
      <div class="tui-row"><span>Buổi chiều</span><span class="val">9 tiết</span></div>
      <div class="tui-row"><span>Ngày có học</span><span class="val">5/6</span></div>
      <div class="tui-row total"><span>Xung đột lịch</span><span class="val" style="color:var(--m3-primary)">0</span></div>
    </div>
  </div>
</div>
"""

# ============================== SV-09 · LỊCH SỬ ĐĂNG KÝ ==============================
REG_HISTORY = """
<div class="page-head">
  <div>
    <h1>Lịch sử đăng ký</h1>
    <div class="sub">Tất cả đăng ký, hủy và đang học — kèm lý do hủy khi có.</div>
  </div>
  <div class="kpi">
    <div class="k g"><div class="v">6</div><div class="l">Đang học</div></div>
    <div class="k a"><div class="v">2</div><div class="l">Đã hủy</div></div>
  </div>
</div>
<div class="filterbar">
  <div class="f" style="min-width:140px"><label>Học kỳ</label>
    <select><option>20263</option><option>20262</option><option>20261</option></select></div>
  <div class="f" style="min-width:130px"><label>Trạng thái</label>
    <select><option>Tất cả</option><option>Đang học</option><option>Đã hủy</option><option>Đã kết thúc</option></select></div>
  <div class="f" style="min-width:150px"><label>Loại đăng ký</label>
    <select><option>Tất cả</option><option>Bình thường</option><option>Học lại</option><option>Cải thiện</option></select></div>
  <div class="f-search"><input placeholder="Tìm môn, mã lớp…"></div>
  <button class="btn btn-outline"><span class="msr">download</span>Xuất CSV</button>
</div>
<div class="card pad0">
  <table class="tbl">
    <thead><tr>
      <th>Ngày đăng ký</th><th>Môn học</th><th>Lớp</th><th>Học kỳ</th>
      <th class="r">TC</th><th class="r">Học phí</th><th>Trạng thái</th><th>Lý do hủy</th>
    </tr></thead>
    <tbody>
      <tr>
        <td class="num">03/10/2026</td>
        <td><b>Cơ sở dữ liệu</b></td>
        <td class="dim">CNTT203.1</td>
        <td class="dim">20263</td>
        <td class="r num">4</td>
        <td class="r num">6.400.000</td>
        <td><span class="chip mo"><span class="dot"></span>Đang học</span></td>
        <td class="dim">—</td>
      </tr>
      <tr>
        <td class="num">03/10/2026</td>
        <td><b>Mạng máy tính</b></td>
        <td class="dim">CNTT301.1</td>
        <td class="dim">20263</td>
        <td class="r num">3</td>
        <td class="r num">4.800.000</td>
        <td><span class="chip mo"><span class="dot"></span>Đang học</span></td>
        <td class="dim">—</td>
      </tr>
      <tr>
        <td class="num">03/10/2026</td>
        <td><b>Phát triển phần mềm</b></td>
        <td class="dim">CNTT305.1</td>
        <td class="dim">20263</td>
        <td class="r num">3</td>
        <td class="r num">4.800.000</td>
        <td><span class="chip mo"><span class="dot"></span>Đang học</span></td>
        <td class="dim">—</td>
      </tr>
      <tr>
        <td class="num">03/10/2026</td>
        <td><b>Trí tuệ nhân tạo</b></td>
        <td class="dim">CNTT401.1</td>
        <td class="dim">20263</td>
        <td class="r num">3</td>
        <td class="r num">4.800.000</td>
        <td><span class="chip mo"><span class="dot"></span>Đang học</span></td>
        <td class="dim">—</td>
      </tr>
      <tr>
        <td class="num">02/10/2026</td>
        <td><b>Nhập môn lập trình</b></td>
        <td class="dim">CNTT101.1</td>
        <td class="dim">20263</td>
        <td class="r num">3</td>
        <td class="r num">4.800.000</td>
        <td><span class="chip red"><span class="dot"></span>Đã hủy</span></td>
        <td class="neg">Trùng lịch với PTPM.1</td>
      </tr>
      <tr>
        <td class="num">02/10/2026</td>
        <td><b>Cơ sở dữ liệu</b></td>
        <td class="dim">CNTT203.1</td>
        <td class="dim">20263</td>
        <td class="r num">4</td>
        <td class="r num">6.400.000</td>
        <td><span class="chip red"><span class="dot"></span>Đã hủy</span></td>
        <td class="neg">Đơn học lại bị từ chối</td>
      </tr>
      <tr>
        <td class="num">15/09/2026</td>
        <td><b>Giải tích 2</b></td>
        <td class="dim">GT2101.1</td>
        <td class="dim">20262</td>
        <td class="r num">3</td>
        <td class="r num">4.800.000</td>
        <td><span class="chip kh"><span class="dot"></span>Đã kết thúc</span></td>
        <td class="dim">—</td>
      </tr>
      <tr>
        <td class="num">15/09/2026</td>
        <td><b>Xác suất thống kê</b></td>
        <td class="dim">CNTT202.1</td>
        <td class="dim">20262</td>
        <td class="r num">3</td>
        <td class="r num">4.800.000</td>
        <td><span class="chip kh"><span class="dot"></span>Đã kết thúc</span></td>
        <td class="dim">—</td>
      </tr>
    </tbody>
  </table>
</div>
<div class="foot-note"><span class="msr" style="font-size:16px">info</span> BR-05: hủy trong 4 ngày đầu học kỳ được hoàn 100% học phí; sau đó hoàn 50%.</div>
"""

# ============================== SV-10 · ĐIỂM DANH ==============================
ATTENDANCE = """
<div class="page-head">
  <div>
    <h1>Điểm danh</h1>
    <div class="sub">Theo dõi tỷ lệ vắng và gửi yêu cầu sửa trạng thái điểm danh.</div>
  </div>
  <div class="kpi">
    <div class="k g"><div class="v">85%</div><div class="l">Có mặt</div></div>
    <div class="k a"><div class="v">15%</div><div class="l">Vắng</div></div>
    <div class="k"><div class="v">20%</div><div class="l">Ngưỡng cấm thi</div></div>
  </div>
</div>
<div class="warn-banner">
  <span class="msr">warning</span>
  <div>Bạn đã vắng <b>15%</b> tổng số buổi. Vượt ngưỡng 20% sẽ bị <b>cấm thi</b> (BR-24).</div>
  <span class="lnk">Xem chi tiết →</span>
</div>
<div class="cols" style="grid-template-columns:1fr 380px">
  <div>
    <div class="panel">
      <h3>Điểm danh theo buổi</h3>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk1-bg);color:var(--tk1-fg)"><span class="c" style="font-size:11px">CSDL</span></div>
        <div class="in"><div class="t">Cơ sở dữ liệu · Buổi 1</div><div class="m">T2 · tiết 1–2 · 05/10/2026</div></div>
        <span class="chip mo"><span class="dot"></span>Có mặt</span>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk1-bg);color:var(--tk1-fg)"><span class="c" style="font-size:11px">CSDL</span></div>
        <div class="in"><div class="t">Cơ sở dữ liệu · Buổi 2</div><div class="m">T4 · tiết 1–2 · 07/10/2026</div></div>
        <span class="chip mo"><span class="dot"></span>Có mặt</span>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk3-bg);color:var(--tk3-fg)"><span class="c" style="font-size:11px">PTPM</span></div>
        <div class="in"><div class="t">Phát triển phần mềm · Buổi 1</div><div class="m">T3 · tiết 6–8 · 06/10/2026</div></div>
        <span class="chip dh"><span class="dot"></span>Vắng có phép</span>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk3-bg);color:var(--tk3-fg)"><span class="c" style="font-size:11px">PTPM</span></div>
        <div class="in"><div class="t">Phát triển phần mềm · Buổi 2</div><div class="m">T5 · tiết 6–8 · 08/10/2026</div></div>
        <span class="chip red"><span class="dot"></span>Vắng không phép</span>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk2-bg);color:var(--tk2-fg)"><span class="c" style="font-size:11px">MMT</span></div>
        <div class="in"><div class="t">Mạng máy tính · Buổi 1</div><div class="m">T3 · tiết 6–7 · 06/10/2026</div></div>
        <span class="chip mo"><span class="dot"></span>Có mặt</span>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk2-bg);color:var(--tk2-fg)"><span class="c" style="font-size:11px">MMT</span></div>
        <div class="in"><div class="t">Mạng máy tính · Buổi 2</div><div class="m">T5 · tiết 6–7 · 08/10/2026</div></div>
        <span class="chip red"><span class="dot"></span>Vắng không phép</span>
      </div>
    </div>
  </div>
  <div>
    <div class="panel">
      <h3>Đơn của tôi</h3>
      <div class="reg-item">
        <div class="in"><div class="t">PTPM305 · Buổi 2</div><div class="m">Vắng có phép · 08/10/2026</div></div>
        <span class="chip amber"><span class="dot"></span>Chờ duyệt</span>
      </div>
      <div class="reg-item">
        <div class="in"><div class="t">MMT301 · Buổi 2</div><div class="m">Vắng không phép · 08/10/2026</div></div>
        <span class="chip red"><span class="dot"></span>Từ chối</span>
      </div>
      <div class="reg-item">
        <div class="in"><div class="t">CSDL203 · Buổi 1</div><div class="m">Có mặt · 05/10/2026</div></div>
        <span class="chip mo"><span class="dot"></span>Đã duyệt</span>
      </div>
    </div>
    <div class="panel">
      <h3>Gửi yêu cầu sửa</h3>
      <div class="form">
        <label>Môn học</label>
        <select style="width:100%;height:42px;border:1px solid var(--m3-outline);border-radius:10px;background:var(--m3-surface);padding:0 12px;font:inherit;font-size:13px">
          <option>Phát triển phần mềm · Buổi 2</option>
          <option>Mạng máy tính · Buổi 2</option>
        </select>
        <label>Trạng thái mong muốn</label>
        <div class="opt"><span class="o on">Có mặt</span><span class="o">Vắng có phép</span><span class="o">Vắng không phép</span></div>
        <label>Lý do</label>
        <textarea placeholder="VD: Có việc gia đình cần xử lý…"></textarea>
      </div>
      <div class="course-actions"><button class="btn btn-filled"><span class="msr fill">send</span>Gửi yêu cầu</button></div>
    </div>
  </div>
</div>
"""

# ============================== SV-11 · ĐIỂM ==============================
GRADES = """
<div class="page-head">
  <div>
    <h1>Điểm</h1>
    <div class="sub">Chỉ điểm <b>KHOA</b> mới hiển thị chính thức (BR-14). Điểm nháp/chính thức chỉ để tham khảo.</div>
  </div>
  <div class="kpi">
    <div class="k g"><div class="v">3.42</div><div class="l">GPA kỳ</div></div>
    <div class="k"><div class="v">3.20</div><div class="l">GPA tích lũy</div></div>
    <div class="k a"><div class="v">Khá</div><div class="l">Xếp loại</div></div>
  </div>
</div>
<div class="filterbar">
  <div class="f" style="min-width:140px"><label>Học kỳ</label>
    <select><option>20263</option><option>20262</option><option>20261</option></select></div>
  <div class="f" style="min-width:130px"><label>Trạng thái</label>
    <select><option>Tất cả</option><option>Khóa</option><option>Chính thức</option><option>Nháp</option></select></div>
  <div class="f-search"><input placeholder="Tìm môn…"></div>
</div>
<div class="card pad0">
  <table class="tbl">
    <thead><tr>
      <th>Môn học</th><th class="r">TC</th><th class="r">QT (10%)</th><th class="r">GK (40%)</th>
      <th class="r">CK (50%)</th><th class="r">Tổng kết</th><th class="r">Điểm chữ</th>
      <th class="r">GPA 4</th><th>Trạng thái</th>
    </tr></thead>
    <tbody>
      <tr>
        <td><b>Cơ sở dữ liệu</b></td>
        <td class="r num">4</td>
        <td class="r num">8.0</td>
        <td class="r num">7.5</td>
        <td class="r num">8.0</td>
        <td class="r num"><b>7.85</b></td>
        <td class="r num">A</td>
        <td class="r num">4.0</td>
        <td><span class="chip kh"><span class="dot"></span>Khóa</span></td>
      </tr>
      <tr>
        <td><b>Mạng máy tính</b></td>
        <td class="r num">3</td>
        <td class="r num">7.0</td>
        <td class="r num">6.5</td>
        <td class="r num">7.0</td>
        <td class="r num"><b>6.85</b></td>
        <td class="r num">B</td>
        <td class="r num">3.0</td>
        <td><span class="chip kh"><span class="dot"></span>Khóa</span></td>
      </tr>
      <tr>
        <td><b>Phát triển phần mềm</b></td>
        <td class="r num">3</td>
        <td class="r num">6.0</td>
        <td class="r num">—</td>
        <td class="r num">—</td>
        <td class="r num dim">—</td>
        <td class="r num dim">—</td>
        <td class="r num dim">—</td>
        <td><span class="chip dh"><span class="dot"></span>Chính thức</span></td>
      </tr>
      <tr>
        <td><b>Trí tuệ nhân tạo</b></td>
        <td class="r num">3</td>
        <td class="r num">5.0</td>
        <td class="r num">—</td>
        <td class="r num">—</td>
        <td class="r num dim">—</td>
        <td class="r num dim">—</td>
        <td class="r num dim">—</td>
        <td><span class="chip dh"><span class="dot"></span>Chính thức</span></td>
      </tr>
      <tr>
        <td><b>Giải tích 2</b></td>
        <td class="r num">3</td>
        <td class="r num">4.0</td>
        <td class="r num">3.5</td>
        <td class="r num">4.0</td>
        <td class="r num"><b>3.85</b></td>
        <td class="r num">D</td>
        <td class="r num">1.0</td>
        <td><span class="chip kh"><span class="dot"></span>Khóa</span></td>
      </tr>
      <tr>
        <td><b>Xác suất thống kê</b></td>
        <td class="r num">3</td>
        <td class="r num">9.0</td>
        <td class="r num">8.5</td>
        <td class="r num">9.0</td>
        <td class="r num"><b>8.85</b></td>
        <td class="r num">A</td>
        <td class="r num">4.0</td>
        <td><span class="chip kh"><span class="dot"></span>Khóa</span></td>
      </tr>
    </tbody>
  </table>
</div>
<div class="foot-note"><span class="msr" style="font-size:16px">info</span> BR-10: Tổng kết = QT×0.1 + GK×0.4 + CK×0.5. Thiếu GK → QT/CK = 20%/80%. BR-11: ≥8.50→A, ≥7.00→B, ≥5.50→C, ≥4.00→D, &lt;4.00→F.</div>
"""

# ============================== SV-12 · HỌC PHÍ ==============================
TUITION = """
<div class="page-head">
  <div>
    <h1>Học phí</h1>
    <div class="sub">Học kỳ 20263 · 18 tín chỉ · đơn giá theo khối kiến thức và ngành (BR-15/16/17/18).</div>
  </div>
  <div class="kpi">
    <div class="k a"><div class="v">28.8tr</div><div class="l">Tổng tiền</div></div>
    <div class="k g"><div class="v">14.4tr</div><div class="l">Đã thu</div></div>
    <div class="k"><div class="v" style="color:var(--c-red-fg)">14.4tr</div><div class="l">Còn nợ</div></div>
  </div>
</div>
<div class="cols" style="grid-template-columns:1fr 380px">
  <div>
    <div class="panel">
      <h3>Chi tiết theo môn · Học kỳ 20263</h3>
      <div class="card pad0" style="margin-bottom:0">
        <table class="tbl">
          <thead><tr>
            <th>Môn học</th><th class="r">TC</th><th class="r">Đơn giá</th><th class="r">Thành tiền</th>
          </tr></thead>
          <tbody>
            <tr><td><b>Cơ sở dữ liệu</b></td><td class="r num">4</td><td class="r num">1.600.000</td><td class="r num">6.400.000</td></tr>
            <tr><td><b>Mạng máy tính</b></td><td class="r num">3</td><td class="r num">1.600.000</td><td class="r num">4.800.000</td></tr>
            <tr><td><b>Phát triển phần mềm</b></td><td class="r num">3</td><td class="r num">1.600.000</td><td class="r num">4.800.000</td></tr>
            <tr><td><b>Trí tuệ nhân tạo</b></td><td class="r num">3</td><td class="r num">1.600.000</td><td class="r num">4.800.000</td></tr>
            <tr><td><b>Giải tích 2</b></td><td class="r num">3</td><td class="r num">1.600.000</td><td class="r num">4.800.000</td></tr>
            <tr><td><b>Xác suất thống kê</b></td><td class="r num">3</td><td class="r num">1.600.000</td><td class="r num">4.800.000</td></tr>
          </tbody>
        </table>
      </div>
    </div>
    <div class="panel">
      <h3>Lịch sử thu</h3>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk1-bg);color:var(--tk1-fg)"><span class="c" style="font-size:11px">BL</span></div>
        <div class="in"><div class="t">Biên lai BL-2026-0042</div><div class="m">Chuyển khoản · 05/10/2026</div></div>
        <span class="num" style="font-weight:600">14.400.000 ₫</span>
      </div>
      <div class="reg-item">
        <div class="mono" style="width:34px;height:34px;border-radius:10px;background:var(--tk2-bg);color:var(--tk2-fg)"><span class="c" style="font-size:11px">BL</span></div>
        <div class="in"><div class="t">Biên lai BL-2026-0018</div><div class="m">Chuyển khoản · 15/09/2026</div></div>
        <span class="num" style="font-weight:600">14.400.000 ₫</span>
      </div>
    </div>
  </div>
  <div>
    <div class="panel">
      <h3>Tổng hợp</h3>
      <div class="tui-row"><span>Tổng tín chỉ</span><span class="val">18</span></div>
      <div class="tui-row"><span>Tổng tiền</span><span class="val">28.800.000 ₫</span></div>
      <div class="tui-row"><span>Đã thu</span><span class="val" style="color:var(--m3-primary)">14.400.000 ₫</span></div>
      <div class="tui-row"><span>Miễn giảm</span><span class="val">0 ₫</span></div>
      <div class="tui-row total"><span>Còn nợ</span><span class="due">14.400.000 ₫</span></div>
      <div class="course-actions"><button class="btn btn-filled"><span class="msr fill">payment</span>Thanh toán</button></div>
    </div>
    <div class="panel">
      <h3>Miễn giảm / Học bổng</h3>
      <div class="reg-item">
        <div class="in"><div class="t">Học bổng khuyến khích</div><div class="m">Loại: HỌC_BONG · 20262</div></div>
        <span class="chip mo"><span class="dot"></span>Đã áp dụng</span>
      </div>
      <div class="reg-item">
        <div class="in"><div class="t">Miễn giảm gia đình</div><div class="m">Loại: MIEN_GIAM · 20261</div></div>
        <span class="chip kh"><span class="dot"></span>Đã áp dụng</span>
      </div>
    </div>
    <div class="foot-note"><span class="msr" style="font-size:16px">info</span> BR-15: Học phí = Σ(TC × đơn giá). BR-16/17/18: tra cứu theo học kỳ + phạm vi, ưu tiên KHỐI_KIẾN_THỨC → NGÀNH → MẶC ĐỊNH.</div>
  </div>
</div>
"""

# ============================== SV-13 · THÔNG BÁO ==============================
NOTIFICATIONS = """
<div class="page-head">
  <div>
    <h1>Thông báo</h1>
    <div class="sub">Nhận thông báo từ PĐT, giảng viên, kế toán và hệ thống.</div>
  </div>
  <div class="kpi">
    <div class="k a"><div class="v">3</div><div class="l">Chưa đọc</div></div>
  </div>
</div>
<div class="filterbar">
  <div class="f" style="min-width:130px"><label>Nguồn</label>
    <select><option>Tất cả</option><option>PĐT</option><option>Giảng viên</option><option>Kế toán</option><option>Hệ thống</option></select></div>
  <div class="f" style="min-width:130px"><label>Trạng thái</label>
    <select><option>Tất cả</option><option>Chưa đọc</option><option>Đã đọc</option></select></div>
  <div class="f-search"><input placeholder="Tìm thông báo…"></div>
  <button class="btn btn-outline"><span class="msr">done_all</span>Đánh dấu tất cả đã đọc</button>
</div>
<div class="card pad0">
  <div class="lrow unread">
    <div class="ic" style="background:var(--c-amber-bg);color:var(--c-amber-fg)"><span class="msr">campaign</span></div>
    <div class="bd">
      <div class="t">Cửa sổ đăng ký môn học 20263 sắp đóng</div>
      <div class="m">PĐT · 08/10/2026 09:30 · Còn 4 ngày để đăng ký. Vui lòng hoàn tất trước 23:59 ngày 12/10/2026.</div>
    </div>
    <span class="chip amber"><span class="dot"></span>Chưa đọc</span>
  </div>
  <div class="lrow unread">
    <div class="ic" style="background:var(--c-dh-bg);color:var(--c-dh-fg)"><span class="msr">grade</span></div>
    <div class="bd">
      <div class="t">Điểm Cơ sở dữ liệu đã được khóa</div>
      <div class="m">PĐT · 07/10/2026 14:15 · Điểm KHOA đã công bố. Bạn có thể xem trong mục Điểm.</div>
    </div>
    <span class="chip amber"><span class="dot"></span>Chưa đọc</span>
  </div>
  <div class="lrow unread">
    <div class="ic" style="background:var(--c-teal-bg);color:var(--c-teal-fg)"><span class="msr">request_page</span></div>
    <div class="bd">
      <div class="t">Đơn học lại CNTT101 đã được duyệt</div>
      <div class="m">PĐT · 06/10/2026 10:00 · Bạn có thể đăng ký lớp học lại trong cửa sổ đăng ký.</div>
    </div>
    <span class="chip amber"><span class="dot"></span>Chưa đọc</span>
  </div>
  <div class="lrow">
    <div class="ic" style="background:var(--c-kh-bg);color:var(--c-kh-fg)"><span class="msr">receipt_long</span></div>
    <div class="bd">
      <div class="t">Biên lai học phí BL-2026-0042</div>
      <div class="m">Kế toán · 05/10/2026 16:45 · Đã thu 14.400.000 ₫ qua chuyển khoản.</div>
    </div>
    <span class="chip kh"><span class="dot"></span>Đã đọc</span>
  </div>
  <div class="lrow">
    <div class="ic" style="background:var(--c-kh-bg);color:var(--c-kh-fg)"><span class="msr">how_to_reg</span></div>
    <div class="bd">
      <div class="t">Kết quả điểm danh tuần 2</div>
      <div class="m">Giảng viên · 04/10/2026 11:20 · Bạn có 2 buổi vắng không phép. Vui lòng xem chi tiết.</div>
    </div>
    <span class="chip kh"><span class="dot"></span>Đã đọc</span>
  </div>
  <div class="lrow">
    <div class="ic" style="background:var(--c-kh-bg);color:var(--c-kh-fg)"><span class="msr">info</span></div>
    <div class="bd">
      <div class="t">Hệ thống bảo trì định kỳ</div>
      <div class="m">Hệ thống · 01/10/2026 02:00 · Bảo trì từ 02:00–04:00 ngày 02/10/2026.</div>
    </div>
    <span class="chip kh"><span class="dot"></span>Đã đọc</span>
  </div>
</div>
"""

# ============================== SV-14 · HỌC LẠI / CẢI THIỆN ==============================
RETAKE = """
<div class="page-head">
  <div>
    <h1>Học lại · Cải thiện</h1>
    <div class="sub">Nộp đơn học lại hoặc cải thiện điểm cho môn đã có điểm KHOA.</div>
  </div>
</div>
<div class="warn-banner">
  <span class="msr">info</span>
  <div>BR-04: đơn được duyệt sẽ <b>tạm miễn tiên quyết</b> cho môn đang học lại. BR-25(c): GPA chỉ tính lần học mới nhất mỗi môn.</div>
</div>
<div class="cols" style="grid-template-columns:1fr 380px">
  <div>
    <div class="panel">
      <h3>Nộp đơn mới</h3>
      <div class="form">
        <label>Môn học (chỉ môn đã có điểm KHOA)</label>
        <select style="width:100%;height:42px;border:1px solid var(--m3-outline);border-radius:10px;background:var(--m3-surface);padding:0 12px;font:inherit;font-size:13px">
          <option>Nhập môn lập trình · CNTT101 · Điểm KHOA: 3.85 (D)</option>
          <option>Giải tích 2 · GT2101 · Điểm KHOA: 3.85 (D)</option>
        </select>
        <label>Loại đơn</label>
        <div class="opt"><span class="o on">Học lại</span><span class="o">Cải thiện</span></div>
        <label>Học kỳ muốn học</label>
        <select style="width:100%;height:42px;border:1px solid var(--m3-outline);border-radius:10px;background:var(--m3-surface);padding:0 12px;font:inherit;font-size:13px">
          <option>20264</option><option>20271</option>
        </select>
        <label>Lý do</label>
        <textarea placeholder="VD: Muốn cải thiện GPA ngành…"></textarea>
      </div>
      <div class="course-actions"><button class="btn btn-filled"><span class="msr fill">send</span>Nộp đơn</button></div>
    </div>
  </div>
  <div>
    <div class="panel">
      <h3>Đơn của tôi</h3>
      <div class="card pad0" style="margin-bottom:0">
        <table class="tbl">
          <thead><tr>
            <th>Môn</th><th>Loại</th><th>Học kỳ</th><th>Trạng thái</th><th>Người duyệt</th>
          </tr></thead>
          <tbody>
            <tr>
              <td><b>Nhập môn lập trình</b></td>
              <td><span class="chip red"><span class="dot"></span>Học lại</span></td>
              <td class="dim">20263</td>
              <td><span class="chip mo"><span class="dot"></span>Đã duyệt</span></td>
              <td class="dim">PĐT Trần Văn F</td>
            </tr>
            <tr>
              <td><b>Giải tích 2</b></td>
              <td><span class="chip dh"><span class="dot"></span>Cải thiện</span></td>
              <td class="dim">20262</td>
              <td><span class="chip amber"><span class="dot"></span>Chờ duyệt</span></td>
              <td class="dim">—</td>
            </tr>
            <tr>
              <td><b>Xác suất thống kê</b></td>
              <td><span class="chip red"><span class="dot"></span>Học lại</span></td>
              <td class="dim">20261</td>
              <td><span class="chip red"><span class="dot"></span>Từ chối</span></td>
              <td class="dim">PĐT Trần Văn F</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    <div class="foot-note"><span class="msr" style="font-size:16px">info</span> Luồng 8: SV nộp đơn → PĐT duyệt → SV đăng ký lớp mới → Grade mới KHOA, Grade cũ giữ nguyên.</div>
  </div>
</div>
"""

# ============================== WRITE ==============================
write("06_sv_profile.html", "Hồ sơ cá nhân", "Hồ sơ", "Hồ sơ cá nhân", PROFILE)
write("07_sv_curriculum.html", "Chương trình đào tạo", "Chương trình đào tạo", "Chương trình đào tạo", CURRICULUM)
write("08_sv_auto_schedule.html", "Tạo TKB tự động", "Tạo TKB tự động", "Tạo TKB tự động", AUTO_SCHEDULE)
write("09_sv_timetable.html", "Thời khóa biểu", "Thời khóa biểu", "Thời khóa biểu", TIMETABLE)
write("10_sv_registration_history.html", "Lịch sử đăng ký", "Đăng ký môn học", "Lịch sử đăng ký", REG_HISTORY)
write("11_sv_attendance.html", "Điểm danh", "Điểm danh", "Điểm danh", ATTENDANCE)
write("12_sv_grades.html", "Điểm", "Điểm", "Điểm", GRADES)
write("13_sv_tuition.html", "Học phí", "Học phí", "Học phí", TUITION)
write("14_sv_notifications.html", "Thông báo", "Thông báo", "Thông báo", NOTIFICATIONS)
write("15_sv_retake.html", "Học lại · Cải thiện", "Học lại · Cải thiện", "Học lại · Cải thiện", RETAKE)
