"""Bangun halaman panduan dari src/ + isi potongan kode + indeks pencarian.

Jalankan dari root repo:  python docs/tutorial/build.py

Halaman ditulis sebagai fragmen di src/ (baris pertama: <!-- title: … | desc: … -->)
lalu dibungkus TEMPLATE menjadi docs/tutorial/<nama>.html. Setiap blok kode ditulis sebagai
    <div class="code" data-src="core/game.gd" data-from="func _process"
         data-to="func _unhandled_input" data-ref="3f048ff"></div><!--/code-->
- data-src   : path file di repo
- data-ref   : commit (kosong = file di working tree sekarang)
- data-from  : regex baris pertama (inklusif), data-to: regex baris akhir (eksklusif)
- data-lines : "a-b" (alternatif from/to), data-hl: "12,15-17" baris yang disorot
Isi blok diganti dengan kode asli (di-escape + diwarnai), jadi kutipan selalu sama
dengan repo. Lalu assets/search-index.js dibangun dari h2/h3/dt tiap halaman.
"""
import hashlib
import html
import json
import os
import re
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))

KW = set("""if elif else for while match break continue pass return class class_name extends is in as self
signal func static const enum var onready export setget tool await yield and or not true false null super
preload breakpoint void uniform varying in out inout shader_type render_mode discard def import from
lambda with try except None True False""".split())
TYPES = set("""int float bool String StringName Vector2 Vector3 Vector4 Color Array Dictionary PackedFloat32Array
PackedInt32Array PackedVector2Array PackedByteArray PackedStringArray PackedInt64Array Node Node3D Resource
RefCounted Rect2 AABB Transform3D vec2 vec3 vec4 mat3 mat4 sampler2D Texture2D MultiMesh QuadMesh
PlaneMesh ShaderMaterial MultiMeshInstance3D RenderingServer Input Engine OS FileAccess DirAccess JSON
Camera3D Sprite3D CanvasLayer Control Button Label Tween SceneTree Callable Signal""".split())

TOKEN = re.compile(r"""
 (?P<com>\#[^\n]*|//[^\n]*|;[^\n]*)
|(?P<str>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')
|(?P<ann>@\w+|&"[^"]*")
|(?P<num>\b0x[0-9a-fA-F]+\b|\b\d+(?:\.\d+)?(?:e[-+]?\d+)?\b)
|(?P<word>[A-Za-z_]\w*)(?P<call>\s*\()?
""", re.X)


def highlight(line, ext):
    out = []
    pos = 0
    for m in TOKEN.finditer(line):
        kind = m.lastgroup
        text = m.group(0)
        if kind == "com":
            if ext in (".gd", ".py") and not text.startswith("#"):
                continue
            if ext in (".gdshader",) and not text.startswith("//"):
                continue
            if ext in (".tres", ".tscn", ".godot", ".cfg") and not text.startswith(";"):
                continue
        out.append(html.escape(line[pos:m.start()]))
        if kind == "word" or kind == "call":
            word = m.group("word")
            cls = "kw" if word in KW else "ty" if word in TYPES else ("fn" if m.group("call") else "")
            rest = text[len(word):]
            out.append(f'<span class="tk-{cls}">{html.escape(word)}</span>' if cls else html.escape(word))
            out.append(html.escape(rest))
        else:
            out.append(f'<span class="tk-{kind}">{html.escape(text)}</span>')
        pos = m.end()
    out.append(html.escape(line[pos:]))
    return "".join(out)


def read_source(path, ref):
    if ref:
        return subprocess.run(["git", "show", f"{ref}:{path}"], cwd=ROOT, capture_output=True,
                              check=True).stdout.decode("utf-8")
    with open(os.path.join(ROOT, path), encoding="utf-8") as f:
        return f.read()


def parse_ranges(spec):
    out = set()
    for part in filter(None, (spec or "").split(",")):
        if "-" in part:
            a, b = part.split("-")
            out.update(range(int(a), int(b) + 1))
        else:
            out.add(int(part))
    return out


ATTR = re.compile(r'([\w-]+)="([^"]*)"')
BLOCK = re.compile(r'(<div class="code"([^>]*)>)(.*?)(</div><!--/code-->)', re.S)


def fill(match, page):
    attrs = dict(ATTR.findall(match.group(2)))
    path = attrs["data-src"]
    ref = attrs.get("data-ref", "")
    lines = read_source(path, ref).split("\n")
    if "data-lines" in attrs:
        a, b = (int(x) for x in attrs["data-lines"].split("-"))
    else:
        a = b = None
        start = re.compile(attrs["data-from"]) if "data-from" in attrs else None
        for i, l in enumerate(lines, 1):
            if a is None and (start is None or start.search(l)):
                a = i
                continue
            if a is not None and "data-to" in attrs and re.search(attrs["data-to"], l):
                b = i - 1
                break
        if a is None:
            raise SystemExit(f"{page}: pola {attrs.get('data-from')!r} tidak ada di {path}@{ref or 'kerja'}")
        if b is None:
            b = len(lines) if "data-to" not in attrs or "data-from" not in attrs else len(lines)
            if "data-to" in attrs:
                raise SystemExit(f"{page}: pola akhir {attrs['data-to']!r} tidak ada di {path}")
    while b > a and lines[b - 1].strip() == "":
        b -= 1
    hl = parse_ranges(attrs.get("data-hl"))
    ext = os.path.splitext(path)[1]
    body = []
    width = len(str(b))
    for n in range(a, b + 1):
        code = highlight(lines[n - 1].replace("\t", "    "), ext)
        ln = f'<span class="ln">{str(n).rjust(width)}</span>'
        row = ln + code
        body.append(f'<span class="hl">{row}</span>' if n in hl else row)
    label = f"<b>{html.escape(path)}</b> · baris {a}–{b}" + (f" · @{ref}" if ref else "")
    inner = (f'<div class="file"><span>{label}</span><button class="copy-btn" type="button">Salin</button></div>'
             f'<pre><code>{chr(10).join(body)}</code></pre>')
    return match.group(1) + inner + match.group(4)


TAG = re.compile(r"<[^>]+>")
SECTION = re.compile(r'<(h[23]|dt) id="([^"]+)"[^>]*>(.*?)</\1>', re.S)


def text_of(fragment):
    fragment = re.sub(r'<div class="code".*?</div><!--/code-->', " ", fragment, flags=re.S)
    fragment = re.sub(r"<(script|style)[^>]*>.*?</\1>", " ", fragment, flags=re.S)
    return re.sub(r"\s+", " ", html.unescape(TAG.sub(" ", fragment))).strip()


TEMPLATE = """<!doctype html>
<html lang="id">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="claude:viewport-fit-sides" content="cover">
<title>{title}</title>
<meta name="description" content="{desc}">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Atkinson+Hyperlegible:ital,wght@0,400;0,700;1,400&family=JetBrains+Mono:wght@400;600&family=Pixelify+Sans:wght@500;600&display=swap">
<link rel="stylesheet" href="assets/style.css?v={v_style_css}">
<script>try{{var t=JSON.parse(localStorage.getItem("kb-theme"));if(t)document.documentElement.setAttribute("data-theme",t)}}catch(e){{}}</script>
</head>
<body data-page="{id}">
<header class="topbar">
<button id="menu-btn" class="icon-btn" type="button" aria-label="Buka daftar bab"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M4 6h16M4 12h16M4 18h16"/></svg>Bab</button>
<a class="brand" href="index.html">Knellbound <span>dari Nol</span></a>
<span class="spacer"></span>
<div class="search-wrap"><input id="search" type="search" placeholder="Cari… (tekan /)" aria-label="Cari di panduan" autocomplete="off"><div id="search-results" hidden></div></div>
<button id="theme-btn" class="icon-btn" type="button" aria-label="Ganti tema"></button>
<div class="progress-line"></div>
</header>
<div class="layout">
<nav class="sidebar" id="sidebar" aria-label="Daftar bab"></nav>
<main>
<article class="article">
{body}
<nav class="pager" id="pager" aria-label="Halaman sebelumnya dan berikutnya"></nav>
</article>
</main>
</div>
<script src="assets/search-index.js?v={v_search_index_js}"></script>
<script src="assets/site.js?v={v_site_js}"></script>
<script src="assets/demos.js?v={v_demos_js}"></script>
<script src="assets/demos-swarm.js?v={v_demos_swarm_js}"></script>
<script src="assets/demos-systems.js?v={v_demos_systems_js}"></script>
</body>
</html>
"""
META = re.compile(r"<!--\s*title:\s*(.*?)\s*\|\s*desc:\s*(.*?)\s*-->", re.S)


def asset_versions():
    """Short content hash per asset, appended as ?v= so browsers drop stale copies."""
    out = {}
    for name in ["style.css", "search-index.js", "site.js", "demos.js", "demos-swarm.js", "demos-systems.js"]:
        path = os.path.join(HERE, "assets", name)
        data = open(path, "rb").read() if os.path.exists(path) else b""
        out["v_" + name.replace(".", "_").replace("-", "_")] = hashlib.sha1(data).hexdigest()[:8]
    return out


def main():
    versions = asset_versions()
    src_dir = os.path.join(HERE, "src")
    pages = []
    for name in sorted(os.listdir(src_dir)):
        if not name.endswith(".html"):
            continue
        with open(os.path.join(src_dir, name), encoding="utf-8") as f:
            frag = f.read()
        meta = META.search(frag)
        title, desc = (meta.group(1), meta.group(2)) if meta else (name[:-5], "")
        body = BLOCK.sub(lambda m: fill(m, name), META.sub("", frag, count=1).strip())
        new = TEMPLATE.format(title=html.escape(title), desc=html.escape(desc), id=name[:-5], body=body,
                              **versions)
        with open(os.path.join(HERE, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(new)
        pages.append(name)
    index = []
    for name in pages:
        with open(os.path.join(HERE, name), encoding="utf-8") as f:
            new = f.read()
        page_id = name[:-5]
        title_m = re.search(r"<h1[^>]*>(.*?)</h1>", new, re.S)
        page_title = text_of(title_m.group(1)) if title_m else page_id
        main_m = re.search(r"<main[^>]*>(.*)</main>", new, re.S)
        body = main_m.group(1) if main_m else new
        marks = list(SECTION.finditer(body))
        head_text = text_of(body[: marks[0].start()] if marks else body)
        index.append({"p": page_id, "pt": page_title, "a": "", "h": page_title, "t": head_text[:600]})
        for i, m in enumerate(marks):
            end = marks[i + 1].start() if i + 1 < len(marks) else len(body)
            index.append({"p": page_id, "pt": page_title, "a": m.group(2), "h": text_of(m.group(3)),
                          "t": text_of(body[m.end():end])[:1400]})
    with open(os.path.join(HERE, "assets", "search-index.js"), "w", encoding="utf-8", newline="\n") as f:
        f.write("// Dibuat oleh build.py — jangan diedit manual.\nwindow.KB_SEARCH = ")
        json.dump(index, f, ensure_ascii=False, separators=(",", ":"))
        f.write(";\n")
    print(f"{len(pages)} halaman, {len(index)} entri indeks")


if __name__ == "__main__":
    main()
