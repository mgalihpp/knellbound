// Navigasi situs: daftar bab, isi halaman, progres, prev/next, pencarian, tema, lightbox.
(function () {
  "use strict";

  var CHAPTERS = [
    { id: "index", num: "◆", title: "Beranda & peta proyek", blurb: "Apa yang akan kamu bangun, cara membaca panduan ini, alur data game." },
    { id: "bab-0", num: "0", title: "Persiapan", blurb: "Godot 4.7, proyek kosong, folder, Input Map, filter nearest, Python + Pillow." },
    { id: "bab-1", num: "1", title: "Dunia 2.5D & EnemySwarm", blurb: "Kamera miring, sprite billboard, MultiMesh, spatial hash, Holy Aura." },
    { id: "bab-2", num: "2", title: "XP, Stats & Level Up", blurb: "GemField, Stats + StatModifier, kurva XP, pause, layar level up." },
    { id: "bab-3", num: "3", title: "Senjata & ProjectileField", blurb: "Tabel level, proyektil packed array, pierce, pantul, orbit, zona." },
    { id: "bab-4", num: "4", title: "Pasif, Evolusi & Peti", blurb: "13 relik, resep evolusi, peti, loadout HUD." },
    { id: "bab-5", num: "5", title: "Perilaku Musuh, Wave & Boss", blurb: "CHASE/WEAVE/RANGED/DRIFT, WaveTable 30 menit, elite, BossBrain." },
    { id: "bab-6", num: "6", title: "Pickup, Pecahan & Game Feel", blurb: "PickupData .tres, DropTable, angka damage, efek, shake, hit-stop." },
    { id: "bab-7", num: "7", title: "UI, Tema & Alur Layar", blurb: "Theme + font pixel, HUD, pause/options, ringkasan run, SceneFader." },
    { id: "bab-8", num: "8", title: "Save, Toko, Hunter & Audio", blurb: "save.json atomik, Reliquary, 5 hunter, pool suara 24 voice." },
    { id: "bab-9", num: "9", title: "Performa & Langkah Lanjut", blurb: "Profiling, angka FPS, kapan pindah ke C#/GDExtension, ide pengembangan." },
    { id: "glosarium", num: "Aa", title: "Glosarium", blurb: "Istilah game dev dan Godot yang dipakai di panduan ini." }
  ];
  window.KB_CHAPTERS = CHAPTERS;

  var page = document.body.getAttribute("data-page") || "index";
  var idx = CHAPTERS.findIndex(function (c) { return c.id === page; });

  function store(key, val) {
    try {
      if (val === undefined) return JSON.parse(localStorage.getItem("kb-" + key));
      localStorage.setItem("kb-" + key, JSON.stringify(val));
    } catch (e) { return null; }
  }

  // ---------------------------------------------------------------- theme
  var themeBtn = document.getElementById("theme-btn");
  var SVG = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">';
  var THEME_ICONS = {
    light: SVG + '<circle cx="12" cy="12" r="4.5"/><path d="M12 2v2.5M12 19.5V22M2 12h2.5M19.5 12H22M4.9 4.9l1.8 1.8M17.3 17.3l1.8 1.8M4.9 19.1l1.8-1.8M17.3 6.7l1.8-1.8"/></svg>',
    dark: SVG + '<path d="M20.5 14.5A8.5 8.5 0 0 1 9.5 3.5a8.5 8.5 0 1 0 11 11z"/></svg>',
    system: SVG + '<circle cx="12" cy="12" r="9"/><path d="M12 3a9 9 0 0 1 0 18z" fill="currentColor"/></svg>'
  };
  function applyTheme(t) {
    if (t) document.documentElement.setAttribute("data-theme", t);
    else document.documentElement.removeAttribute("data-theme");
    if (themeBtn) {
      themeBtn.innerHTML = THEME_ICONS[t || "system"];
      var name = t === "dark" ? "gelap" : t === "light" ? "terang" : "ikut sistem";
      themeBtn.setAttribute("aria-label", "Ganti tema (sekarang: " + name + ")");
      themeBtn.title = "Tema: " + name + " · klik untuk ganti";
    }
    document.dispatchEvent(new CustomEvent("kb-theme"));
  }
  applyTheme(store("theme"));
  if (themeBtn) themeBtn.addEventListener("click", function () {
    var cur = store("theme");
    var next = cur === null ? "dark" : cur === "dark" ? "light" : null;
    store("theme", next);
    applyTheme(next);
  });

  // ---------------------------------------------------------------- sidebar
  var seen = store("seen") || {};
  seen[page] = true;
  store("seen", seen);
  var side = document.getElementById("sidebar");
  var headings = Array.prototype.slice.call(document.querySelectorAll("main h2[id]"));
  if (side) {
    var done = CHAPTERS.filter(function (c) { return seen[c.id]; }).length;
    // Progres digambar seperti LevelPips di HUD game: satu pip per halaman.
    var pips = CHAPTERS.map(function (c) {
      return '<i class="pip' + (seen[c.id] ? ' on' : '') + (c.id === page ? ' here' : '') + '" title="' + c.title + '"></i>';
    }).join("");
    var html = '<div class="side-progress"><div class="side-progress-head"><span>Progres</span><b>' + done + '/' + CHAPTERS.length + '</b></div>' +
      '<div class="pips" aria-label="' + done + ' dari ' + CHAPTERS.length + ' halaman sudah dibuka">' + pips + '</div></div>';
    var GROUPS = [["Mulai", ["index", "bab-0"]], ["Delapan fase", ["bab-1", "bab-2", "bab-3", "bab-4", "bab-5", "bab-6", "bab-7", "bab-8"]], ["Penutup", ["bab-9", "glosarium"]]];
    GROUPS.forEach(function (grp) {
      html += '<h4>' + grp[0] + '</h4><ol>';
      CHAPTERS.forEach(function (c) {
        if (grp[1].indexOf(c.id) < 0) return;
        var cur = c.id === page;
        html += '<li class="ch' + (cur ? ' current' : '') + (seen[c.id] ? ' seen' : '') + '"><a href="' + c.id + '.html"' + (cur ? ' aria-current="page"' : '') + '>' +
          '<span class="slot" aria-hidden="true">' + c.num + '</span><span class="ch-title">' + c.title + '</span>' +
          (seen[c.id] && !cur ? '<span class="sr-only">(sudah dibuka)</span>' : '') + '</a>';
        if (cur && headings.length) {
          html += '<div class="sub">';
          headings.forEach(function (h) { html += '<a href="#' + h.id + '">' + h.textContent + '</a>'; });
          html += '</div>';
        }
        html += '</li>';
      });
      html += '</ol>';
    });
    side.innerHTML = html;
    var curLink = side.querySelector(".ch.current");
    if (curLink && curLink.offsetTop > side.clientHeight * 0.6) side.scrollTop = curLink.offsetTop - 120;
    side.addEventListener("click", function (e) { if (e.target.closest("a")) document.body.classList.remove("nav-open"); });
  }
  var menuBtn = document.getElementById("menu-btn");
  if (menuBtn) menuBtn.addEventListener("click", function () { document.body.classList.toggle("nav-open"); });
  document.addEventListener("click", function (e) {
    if (document.body.classList.contains("nav-open") && !e.target.closest(".sidebar") && !e.target.closest("#menu-btn"))
      document.body.classList.remove("nav-open");
  });

  // active section + reading progress
  var subLinks = side ? side.querySelectorAll(".sub a") : [];
  var bar = document.querySelector(".progress-line");
  function onScroll() {
    var doc = document.documentElement;
    var max = doc.scrollHeight - innerHeight;
    if (bar) bar.style.width = (max > 0 ? Math.min(100, 100 * scrollY / max) : 100) + "%";
    var active = -1;
    headings.forEach(function (h, i) { if (h.getBoundingClientRect().top < 120) active = i; });
    for (var i = 0; i < subLinks.length; i++) subLinks[i].classList.toggle("active", i === active);
  }
  addEventListener("scroll", onScroll, { passive: true });
  onScroll();

  // ---------------------------------------------------------------- pager
  var pager = document.getElementById("pager");
  if (pager && idx >= 0) {
    var p = "";
    if (idx > 0) p += '<a class="prev" href="' + CHAPTERS[idx - 1].id + '.html"><span class="dir">← Sebelumnya</span>' + CHAPTERS[idx - 1].title + '</a>';
    if (idx < CHAPTERS.length - 1) p += '<a class="next" href="' + CHAPTERS[idx + 1].id + '.html"><span class="dir">Berikutnya →</span>' + CHAPTERS[idx + 1].title + '</a>';
    pager.innerHTML = p;
  }
  var grid = document.getElementById("chapter-grid");
  if (grid) {
    grid.innerHTML = CHAPTERS.slice(1).map(function (c) {
      return '<a class="chapter-card" href="' + c.id + '.html"><span class="num">' + (/^\d$/.test(c.num) ? "Bab " + c.num : c.num) + (seen[c.id] && c.id !== page ? " · ✓" : "") +
        '</span><b>' + c.title + '</b><span>' + c.blurb + '</span></a>';
    }).join("");
  }

  // ---------------------------------------------------------------- code copy
  document.querySelectorAll(".code").forEach(function (box) {
    var btn = box.querySelector(".copy-btn");
    if (!btn) return;
    var ICON_COPY = SVG.replace('width="18" height="18"', 'width="15" height="15"') + '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V5a2 2 0 0 1 2-2h8"/></svg>';
    var ICON_DONE = SVG.replace('width="18" height="18"', 'width="15" height="15"') + '<path d="M5 12.5l4.5 4.5L19 7.5"/></svg>';
    btn.innerHTML = ICON_COPY;
    btn.setAttribute("aria-label", "Salin kode");
    btn.title = "Salin kode";
    btn.addEventListener("click", function () {
      var code = box.querySelector("pre").cloneNode(true);
      code.querySelectorAll(".ln").forEach(function (n) { n.remove(); });
      var text = code.textContent;
      var ok = function () {
        btn.innerHTML = ICON_DONE; btn.classList.add("done"); btn.title = "Tersalin";
        setTimeout(function () { btn.innerHTML = ICON_COPY; btn.classList.remove("done"); btn.title = "Salin kode"; }, 1400);
      };
      if (navigator.clipboard) navigator.clipboard.writeText(text).then(ok, function () { selectPre(box); });
      else selectPre(box);
    });
  });
  function selectPre(box) {
    var r = document.createRange();
    r.selectNodeContents(box.querySelector("pre"));
    var s = getSelection(); s.removeAllRanges(); s.addRange(r);
  }

  // ---------------------------------------------------------------- lightbox
  document.addEventListener("click", function (e) {
    var img = e.target.closest("figure img");
    if (!img) return;
    var lb = document.createElement("div");
    lb.className = "lightbox";
    lb.innerHTML = '<img alt="">';
    lb.firstChild.src = img.src;
    lb.firstChild.alt = img.alt;
    lb.addEventListener("click", function () { lb.remove(); });
    document.body.appendChild(lb);
  });
  addEventListener("keydown", function (e) {
    if (e.key === "Escape") { var lb = document.querySelector(".lightbox"); if (lb) lb.remove(); document.body.classList.remove("nav-open"); }
  });

  // ---------------------------------------------------------------- search
  var input = document.getElementById("search");
  var box = document.getElementById("search-results");
  var INDEX = window.KB_SEARCH || [];
  var sel = -1;
  function norm(s) { return s.toLowerCase(); }
  function esc(s) { return s.replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; }); }
  function mark(s, terms) {
    var out = esc(s);
    terms.forEach(function (t) {
      if (t.length < 2) return;
      out = out.replace(new RegExp("(" + t.replace(/[.*+?^${}()|[\]\\]/g, "\\$&") + ")", "ig"), "<mark>$1</mark>");
    });
    return out;
  }
  function search(q) {
    var terms = norm(q).split(/\s+/).filter(Boolean);
    if (!terms.length) return [];
    var res = [];
    INDEX.forEach(function (e) {
      var title = norm(e.h), body = norm(e.t);
      var score = 0;
      for (var i = 0; i < terms.length; i++) {
        var t = terms[i];
        var inT = title.indexOf(t) >= 0, inB = body.indexOf(t) >= 0;
        if (!inT && !inB) return;
        score += (inT ? 5 : 0) + (inB ? 1 : 0);
      }
      var pos = body.indexOf(terms[0]);
      var snip = pos >= 0 ? e.t.slice(Math.max(0, pos - 50), pos + 110) : e.t.slice(0, 140);
      res.push({ e: e, score: score, snip: (pos > 50 ? "…" : "") + snip + "…" });
    });
    res.sort(function (a, b) { return b.score - a.score; });
    return res.slice(0, 12).map(function (r) { r.terms = terms; return r; });
  }
  function render() {
    var q = input.value.trim();
    var r = search(q);
    sel = -1;
    if (!q) { box.hidden = true; return; }
    box.hidden = false;
    if (!r.length) { box.innerHTML = '<div style="padding:10px;color:var(--muted)">Tidak ada hasil untuk “' + esc(q) + '”.</div>'; return; }
    box.innerHTML = r.map(function (x) {
      return '<a href="' + x.e.p + '.html#' + x.e.a + '"><div class="r-page">' + esc(x.e.pt) + '</div><div>' + mark(x.e.h, x.terms) +
        '</div><div class="r-snip">' + mark(x.snip, x.terms) + '</div></a>';
    }).join("");
  }
  if (input && box) {
    input.addEventListener("input", render);
    input.addEventListener("focus", render);
    input.addEventListener("keydown", function (e) {
      var links = box.querySelectorAll("a");
      if (e.key === "ArrowDown" || e.key === "ArrowUp") {
        e.preventDefault();
        if (!links.length) return;
        sel = (sel + (e.key === "ArrowDown" ? 1 : -1) + links.length) % links.length;
        links.forEach(function (l, i) { l.classList.toggle("active", i === sel); });
        links[sel].scrollIntoView({ block: "nearest" });
      } else if (e.key === "Enter" && links.length) {
        location.href = links[Math.max(0, sel)].getAttribute("href");
      } else if (e.key === "Escape") { box.hidden = true; input.blur(); }
    });
    document.addEventListener("click", function (e) { if (!e.target.closest(".search-wrap")) box.hidden = true; });
    addEventListener("keydown", function (e) {
      if (e.key === "/" && document.activeElement !== input && !/INPUT|TEXTAREA|SELECT/.test(document.activeElement.tagName)) { e.preventDefault(); input.focus(); }
    });
  }
})();
