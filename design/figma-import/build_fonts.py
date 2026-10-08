import re, base64, urllib.request, pathlib, sys

UA = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36"}
OUT = pathlib.Path(__file__).parent
FONTS = OUT / "fonts"
FONTS.mkdir(exist_ok=True)

def fetch(url):
    req = urllib.request.Request(url, headers=UA)
    return urllib.request.urlopen(req, timeout=60).read()

def parse(css_path):
    css = css_path.read_text(encoding="utf-8")
    blocks = []
    # split on comment markers /* subset */
    parts = re.split(r"/\*\s*([a-z-]+)\s*\*/", css)
    # parts: [pre, subset1, block1, subset2, block2, ...]
    for i in range(1, len(parts) - 1, 2):
        subset = parts[i]
        block = parts[i + 1]
        m = re.search(r"font-family:\s*'([^']+)'", block)
        w = re.search(r"font-weight:\s*(\d+)", block)
        u = re.search(r"url\((https://[^)]+\.woff2)\)", block)
        if m and w and u:
            blocks.append((m.group(1), int(w.group(1)), subset, u.group(1)))
    return blocks

def build(css_path, family_filter, out_css, wanted_weights=None, wanted_subsets=None):
    lines = []
    n = 0
    for fam, weight, subset, url in parse(css_path):
        if fam != family_filter:
            continue
        if wanted_weights and weight not in wanted_weights:
            continue
        if wanted_subsets and subset not in wanted_subsets:
            continue
        data = fetch(url)
        b64 = base64.b64encode(data).decode()
        lines.append(
            "@font-face{font-family:'%s';font-style:normal;font-weight:%d;font-display:swap;"
            "src:url(data:font/woff2;base64,%s) format('woff2');}" % (fam, weight, b64)
        )
        n += 1
        print("  %s %d %s  %d KB" % (fam, weight, subset, len(data) // 1024))
    (OUT / out_css).write_text("\n".join(lines), encoding="utf-8")
    print("-> %s : %d faces, %.1f MB" % (out_css, n, (OUT / out_css).stat().st_size / 1048576))

print("Be Vietnam Pro (vietnamese + latin, 400/500/600/700/800):")
build(FONTS / "bvp.css", "Be Vietnam Pro", "bvp-inline.css",
      wanted_weights={400, 500, 600, 700, 800}, wanted_subsets={"vietnamese", "latin"})

print("Material Symbols Rounded (full variable font):")
build(FONTS / "msr.css", "Material Symbols Rounded", "msr-inline.css")
