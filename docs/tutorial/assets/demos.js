// Demo interaktif (canvas, tanpa library). Setiap <div class="demo" data-demo="nama">
// diisi oleh fungsi KB.demos[nama]. Kerangka: kanvas logis W x H, kontrol di bawah,
// play/pause, berhenti otomatis saat tidak terlihat.
(function () {
  "use strict";
  var KB = window.KB = window.KB || {};
  KB.demos = KB.demos || {};

  KB.C = {
    bg: "#1c1726", grid: "#2c2438", grid2: "#3a3048", text: "#ebe5f1", muted: "#9d93ab",
    player: "#5bd2ff", holy: "#5bd2ff", enemy: "#7fae5a", enemy2: "#6c4f8f", bone: "#e8e2cf",
    red: "#ff4a5e", gold: "#e8b84a", gem: "#4aa3ff", green: "#6bd08a", orange: "#f0a640", ink: "#18101e"
  };
  var C = KB.C;
  var reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;

  KB.clamp = function (v, a, b) { return v < a ? a : v > b ? b : v; };
  KB.rand = function (a, b) { return a + Math.random() * (b - a); };
  KB.len = function (x, y) { return Math.sqrt(x * x + y * y); };

  function el(tag, attrs, html) {
    var e = document.createElement(tag);
    for (var k in attrs || {}) e.setAttribute(k, attrs[k]);
    if (html !== undefined) e.innerHTML = html;
    return e;
  }
  KB.el = el;
  var uidc = 0;

  // Kerangka satu demo.
  KB.frame = function (root, opts) {
    var W = opts.w || 720, H = opts.h || 380;
    root.innerHTML = "";
    var head = el("div", { "class": "demo-head" },
      '<span class="eyebrow">Demo interaktif</span><strong>' + (opts.title || "") + "</strong>");
    root.appendChild(head);
    var canvas = null, g = null;
    if (!opts.noCanvas) {
      canvas = el("canvas", { width: W, height: H, role: "img", "aria-label": opts.title || "demo", tabindex: "0" });
      root.appendChild(canvas);
      g = canvas.getContext("2d");
    }
    var body = null;
    if (opts.noCanvas) { body = el("div", { "class": "demo-body" }); root.appendChild(body); }
    var controls = el("div", { "class": "demo-controls" });
    root.appendChild(controls);
    var readout = el("div", { "class": "demo-readout" });
    var note = null;
    var api = {
      W: W, H: H, canvas: canvas, g: g, body: body, controls: controls, playing: !reduced && !opts.paused && !opts.noLoop,
      mouse: { x: W / 2, y: H / 2, down: false, inside: false }, keys: {},
      range: function (label, min, max, step, val, cb, fmt) {
        var id = "kb" + (++uidc);
        var lab = el("label", { "for": id });
        lab.appendChild(document.createTextNode(label));
        var inp = el("input", { type: "range", id: id, min: min, max: max, step: step, value: val });
        var out = el("output", { "for": id });
        var f = fmt || function (v) { return v; };
        out.textContent = f(+val);
        inp.addEventListener("input", function () { out.textContent = f(+inp.value); cb(+inp.value); });
        lab.appendChild(inp); lab.appendChild(out);
        controls.appendChild(lab);
        cb(+val);
        return inp;
      },
      check: function (label, val, cb) {
        var id = "kb" + (++uidc);
        var lab = el("label", { "for": id });
        var inp = el("input", { type: "checkbox", id: id });
        inp.checked = !!val;
        inp.addEventListener("change", function () { cb(inp.checked); });
        lab.appendChild(inp); lab.appendChild(document.createTextNode(label));
        controls.appendChild(lab);
        cb(!!val);
        return inp;
      },
      select: function (label, options, val, cb) {
        var id = "kb" + (++uidc);
        var lab = el("label", { "for": id }, label + " ");
        var s = el("select", { id: id });
        options.forEach(function (o) { var op = el("option", { value: o[0] }, o[1]); if (o[0] === val) op.selected = true; s.appendChild(op); });
        s.addEventListener("change", function () { cb(s.value); });
        lab.appendChild(s); controls.appendChild(lab);
        cb(val);
        return s;
      },
      button: function (label, cb, ghost) {
        var b = el("button", { type: "button" }, label);
        if (ghost) b.className = "ghost";
        b.addEventListener("click", cb);
        controls.appendChild(b);
        return b;
      },
      text: function (s) {
        if (!readout.parentNode) root.appendChild(readout);
        readout.textContent = s;
      },
      note: function (h) {
        if (!note) { note = el("div", { "class": "demo-note" }); root.appendChild(note); }
        note.innerHTML = h;
      }
    };
    if (!opts.noLoop) {
      var pb = el("button", { type: "button", "class": "ghost" }, api.playing ? "Jeda" : "Putar");
      pb.addEventListener("click", function () { api.playing = !api.playing; pb.textContent = api.playing ? "Jeda" : "Putar"; if (api.playing) kick(); });
      controls.appendChild(pb);
      api.playButton = pb;
    }
    if (canvas) {
      var toLocal = function (e) {
        var r = canvas.getBoundingClientRect();
        api.mouse.x = (e.clientX - r.left) * W / r.width;
        api.mouse.y = (e.clientY - r.top) * H / r.height;
      };
      canvas.addEventListener("pointermove", function (e) { toLocal(e); api.mouse.inside = true; });
      canvas.addEventListener("pointerdown", function (e) { toLocal(e); api.mouse.down = true; api.mouse.inside = true; if (opts.onDown) opts.onDown(api.mouse.x, api.mouse.y); if (!api.playing) draw(); });
      addEventListener("pointerup", function () { api.mouse.down = false; });
      canvas.addEventListener("pointerleave", function () { api.mouse.inside = false; });
      canvas.addEventListener("keydown", function (e) { api.keys[e.key.toLowerCase()] = true; if (/^(arrow|w$|a$|s$|d$)/.test(e.key.toLowerCase())) e.preventDefault(); });
      canvas.addEventListener("keyup", function (e) { api.keys[e.key.toLowerCase()] = false; });
      canvas.addEventListener("blur", function () { api.keys = {}; });
    }
    var visible = true, last = 0, raf = 0;
    function draw() { if (opts.draw) opts.draw(api); }
    function loop(t) {
      raf = 0;
      var dt = last ? Math.min((t - last) / 1000, 1 / 20) : 1 / 60;
      last = t;
      if (api.playing && opts.step) opts.step(dt, api);
      draw();
      if (api.playing && visible) raf = requestAnimationFrame(loop);
      else last = 0;
    }
    function kick() { if (!raf) raf = requestAnimationFrame(loop); }
    api.kick = kick;
    api.redraw = function () { if (!api.playing) draw(); };
    if ("IntersectionObserver" in window) {
      new IntersectionObserver(function (es) { visible = es[0].isIntersecting; if (visible) kick(); }).observe(root);
    }
    setTimeout(function () { draw(); kick(); }, 0);
    return api;
  };

  // --- gambar bantu ------------------------------------------------------------
  KB.clear = function (g, W, H) { g.fillStyle = C.bg; g.fillRect(0, 0, W, H); };
  KB.dot = function (g, x, y, r, col) { g.fillStyle = col; g.beginPath(); g.arc(x, y, r, 0, 6.2832); g.fill(); };
  KB.ring = function (g, x, y, r, col, w, dash) {
    g.strokeStyle = col; g.lineWidth = w || 1; if (dash) g.setLineDash(dash);
    g.beginPath(); g.arc(x, y, r, 0, 6.2832); g.stroke(); g.setLineDash([]);
  };
  KB.label = function (g, s, x, y, col, size, align) {
    g.fillStyle = col || C.text; g.font = (size || 13) + 'px "JetBrains Mono", Consolas, monospace';
    g.textAlign = align || "left"; g.textBaseline = "middle"; g.fillText(s, x, y);
  };
  KB.arrow = function (g, x1, y1, x2, y2, col, w) {
    g.strokeStyle = col; g.fillStyle = col; g.lineWidth = w || 1.5;
    g.beginPath(); g.moveTo(x1, y1); g.lineTo(x2, y2); g.stroke();
    var a = Math.atan2(y2 - y1, x2 - x1), s = 6;
    g.beginPath(); g.moveTo(x2, y2);
    g.lineTo(x2 - s * Math.cos(a - .45), y2 - s * Math.sin(a - .45));
    g.lineTo(x2 - s * Math.cos(a + .45), y2 - s * Math.sin(a + .45)); g.fill();
  };
  KB.box = function (g, x, y, w, h, fill, stroke) {
    g.fillStyle = fill; g.fillRect(x, y, w, h);
    if (stroke) { g.strokeStyle = stroke; g.lineWidth = 1; g.strokeRect(x + .5, y + .5, w - 1, h - 1); }
  };

  // Sprite piksel kecil (8x8) untuk "pemain" dan "musuh" di demo.
  var SPR = {
    hunter: ["..hhhh..", ".hhhhhh.", "..SSSS..", "..SeSe..", "..RRRR..", ".CCYCCC.", "..PPPP..", "..B..B.."],
    ghoul: ["..GGGG..", ".GrGGrG.", ".GGmmGG.", "..GGGG..", ".TTTTTT.", "G.TTTT.G", "..T..T..", ".GG..GG."]
  };
  var SPAL = { h: "#5a3a2e", S: "#f2c29b", e: "#1b1b2e", R: "#c8283c", C: "#2f4f8f", Y: "#e8b84a", P: "#3a3048", B: "#6b4430",
    G: "#7fae5a", r: "#ff4040", m: "#2a1a1a", T: "#7b6a52" };
  KB.sprite = function (g, name, x, y, px, flip, flash, tint) {
    var rows = SPR[name];
    for (var j = 0; j < 8; j++) for (var i = 0; i < 8; i++) {
      var ch = rows[j][flip ? 7 - i : i];
      if (ch === ".") continue;
      var col = SPAL[ch];
      if (tint) col = mix(col, "#ff5a6e", tint * 0.5);
      if (flash) col = mix(col, "#ffffff", flash);
      g.fillStyle = col;
      g.fillRect(Math.round(x + (i - 4) * px), Math.round(y + (j - 8) * px), Math.ceil(px), Math.ceil(px));
    }
  };
  function mix(a, b, t) {
    var pa = parseInt(a.slice(1), 16), pb = parseInt(b.slice(1), 16);
    var r = ((pa >> 16) & 255) * (1 - t) + ((pb >> 16) & 255) * t;
    var gg = ((pa >> 8) & 255) * (1 - t) + ((pb >> 8) & 255) * t;
    var bl = (pa & 255) * (1 - t) + (pb & 255) * t;
    return "rgb(" + (r | 0) + "," + (gg | 0) + "," + (bl | 0) + ")";
  }
  KB.mix = mix;

  // Grid hash sederhana untuk demo (pola sama dengan core/spatial_hash.gd).
  KB.Grid = function (cell) {
    this.cell = cell; this.map = new Map();
  };
  KB.Grid.prototype.build = function (xs, ys, n) {
    this.map.clear();
    for (var i = 0; i < n; i++) {
      var k = Math.floor(xs[i] / this.cell) + "," + Math.floor(ys[i] / this.cell);
      var a = this.map.get(k); if (!a) { a = []; this.map.set(k, a); } a.push(i);
    }
  };
  KB.Grid.prototype.near = function (x, y, r, out) {
    out.length = 0;
    var x0 = Math.floor((x - r) / this.cell), x1 = Math.floor((x + r) / this.cell);
    var y0 = Math.floor((y - r) / this.cell), y1 = Math.floor((y + r) / this.cell);
    for (var cy = y0; cy <= y1; cy++) for (var cx = x0; cx <= x1; cx++) {
      var a = this.map.get(cx + "," + cy);
      if (a) for (var k = 0; k < a.length; k++) out.push(a[k]);
    }
    return out;
  };

  // Gerak pemain di demo: tombol panah/WASD saat kanvas fokus, tahan klik untuk menuju kursor,
  // kalau tidak ada input: jalan memutar otomatis.
  KB.steer = function (api, p, speed, dt, t) {
    var k = api.keys, vx = 0, vy = 0;
    if (k.arrowleft || k.a) vx -= 1; if (k.arrowright || k.d) vx += 1;
    if (k.arrowup || k.w) vy -= 1; if (k.arrowdown || k.s) vy += 1;
    if (!vx && !vy && api.mouse.down) { vx = api.mouse.x - p.x; vy = api.mouse.y - p.y; if (KB.len(vx, vy) < 6) vx = vy = 0; }
    var manual = vx || vy;
    if (!manual && p.auto !== false) { vx = Math.cos(t * 0.6) ; vy = Math.sin(t * 0.9) * 0.8; }
    var l = KB.len(vx, vy);
    if (l > 0) { p.x += vx / l * speed * dt; p.y += vy / l * speed * dt; if (vx) p.face = vx > 0 ? 1 : -1; }
    p.x = KB.clamp(p.x, 20, api.W - 20); p.y = KB.clamp(p.y, 26, api.H - 12);
  };

  function boot() {
    document.querySelectorAll(".demo[data-demo]").forEach(function (root) {
      var name = root.getAttribute("data-demo");
      var fn = KB.demos[name];
      if (!fn) { root.innerHTML = '<div class="demo-note">Demo “' + name + '” tidak ditemukan.</div>'; return; }
      try { fn(root); } catch (e) { root.innerHTML = '<div class="demo-note">Demo gagal dimuat: ' + e.message + "</div>"; console.error(e); }
    });
  }
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", function () { setTimeout(boot, 0); });
  else setTimeout(boot, 0);
})();
