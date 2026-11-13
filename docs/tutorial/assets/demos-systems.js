// Demo Bab 2-8: magnet gem, kurva XP, kalkulator Stats, alur pause, proyektil, orbit,
// wave director, perilaku musuh, shake + hit-stop, save atomik, pool suara.
(function () {
  "use strict";
  var KB = window.KB, C = KB.C, D = KB.demos;

  // ------------------------------------------------------------------ magnet gem (GemField.tick)
  D.gems = function (root) {
    var gems = [], p = { x: 360, y: 200, face: 1 }, magnet = 60, accel = 900, pop = 90, maxPull = 520, maxGems = 60, xp = 0, time = 0, bank = -1;
    var tierMin = [0, 5, 20, 100], tierCol = ["#4aa3ff", "#6bd08a", "#ff4a5e", "#b06bff"];
    function tier(v) { var t = 0; for (var k = 0; k < 4; k++) if (v >= tierMin[k]) t = k; return t; }
    function drop(x, y, v) {
      if (gems.length >= maxGems) {
        if (bank < 0 || bank >= gems.length) bank = Math.floor(Math.random() * gems.length);
        gems[bank].v += v; return;
      }
      gems.push({ x: x, y: y, vx: 0, vy: 0, v: v, pulled: false, ph: Math.random() * 6 });
    }
    function burst(n) { for (var k = 0; k < n; k++) drop(KB.rand(20, 700), KB.rand(20, 380), Math.random() < 0.1 ? 6 : 1); }
    var api = KB.frame(root, {
      title: "Gem XP: magnet, lompatan kecil, lalu tertarik", w: 720, h: 400,
      step: function (dt, a) {
        time += dt;
        KB.steer(a, p, 110, dt, time);
        var m2 = magnet * magnet, i = 0;
        while (i < gems.length) {
          var gm = gems[i], dx = p.x - gm.x, dy = p.y - gm.y, l2 = dx * dx + dy * dy;
          if (!gm.pulled) {
            if (l2 >= m2) { i++; continue; }
            gm.pulled = true; var l0 = Math.sqrt(l2) || 1; gm.vx = -dx / l0 * pop; gm.vy = -dy / l0 * pop;
          }
          var dist = Math.sqrt(l2);
          if (dist <= 9) { xp += gm.v; if (bank === i) bank = -1; else if (bank === gems.length - 1) bank = i; gems[i] = gems[gems.length - 1]; gems.pop(); continue; }
          var vx = gm.vx + dx * (accel * dt / dist), vy = gm.vy + dy * (accel * dt / dist), vl = KB.len(vx, vy);
          if (vl > maxPull) { vx *= maxPull / vl; vy *= maxPull / vl; }
          gm.vx = vx; gm.vy = vy; gm.x += vx * dt; gm.y += vy * dt; i++;
        }
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        KB.ring(g, p.x, p.y, magnet, "rgba(91,210,255,.6)", 1.5, [5, 5]);
        gems.forEach(function (gm, k) {
          var t = tier(gm.v), y = gm.y - 3 - Math.sin(time * 4 + gm.ph) * 2;
          g.fillStyle = tierCol[t]; g.beginPath(); g.moveTo(gm.x, y - 6); g.lineTo(gm.x + 4, y); g.lineTo(gm.x, y + 6); g.lineTo(gm.x - 4, y); g.fill();
          if (k === bank) KB.ring(g, gm.x, y, 9, C.gold, 1);
        });
        KB.sprite(g, "hunter", p.x, p.y + 2, 2.6, p.face < 0);
        a.text("gem " + gems.length + "/" + maxGems + "   XP terkumpul " + xp + "   gem bank: " + (bank >= 0 && gems[bank] ? gems[bank].v + " XP" : "-"));
      }
    });
    api.button("Jatuhkan 40 gem", function () { burst(40); api.kick(); });
    api.range("magnet", 20, 200, 5, 60, function (v) { magnet = v; });
    api.range("pull_accel", 200, 2000, 50, 900, function (v) { accel = v; });
    api.range("pop_speed", 0, 250, 10, 90, function (v) { pop = v; });
    api.range("max_gems", 10, 200, 10, 60, function (v) { maxGems = v; });
    burst(30);
    api.note("Gem diam sampai masuk radius magnet. Saat itu ia diberi kecepatan <b>menjauh</b> (<code>pop_speed</code>), lalu tiap frame dipercepat ke pemain (<code>pull_accel</code>), jadi terlihat melompat dulu baru tersedot. Di atas <code>max_gems</code>, gem baru digabung ke satu gem bank yang naik tier (warna).");
  };

  // ------------------------------------------------------------------ kurva XP (Leveling)
  function xpReq(lv) { if (lv < 20) return 5 + 10 * (lv - 1); if (lv < 40) return 195 + 13 * (lv - 20); return 455 + 16 * (lv - 40); }
  D.xp = function (root) {
    var level = 1, xp = 0, pending = 0, log = "", growth = 1;
    var api = KB.frame(root, {
      title: "Kurva XP dan antrian level", w: 720, h: 320, noLoop: true,
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        var x0 = 54, y0 = 260, w = 620, h = 220, maxLv = 60, maxXp = 800;
        g.strokeStyle = C.grid; g.lineWidth = 1;
        for (var v = 0; v <= maxXp; v += 200) { var yy = y0 - v / maxXp * h; g.beginPath(); g.moveTo(x0, yy); g.lineTo(x0 + w, yy); g.stroke(); KB.label(g, String(v), x0 - 8, yy, C.muted, 10, "right"); }
        for (var l = 0; l <= maxLv; l += 10) { var xx = x0 + l / maxLv * w; KB.label(g, "lv " + l, xx, y0 + 14, C.muted, 10, "center"); }
        [20, 40].forEach(function (b) { var xx = x0 + b / maxLv * w; g.strokeStyle = C.grid2; g.setLineDash([3, 3]); g.beginPath(); g.moveTo(xx, y0); g.lineTo(xx, y0 - h); g.stroke(); g.setLineDash([]); });
        g.strokeStyle = C.gold; g.lineWidth = 2; g.beginPath();
        for (var lv = 1; lv <= maxLv; lv++) { var px = x0 + lv / maxLv * w, py = y0 - xpReq(lv) / maxXp * h; if (lv === 1) g.moveTo(px, py); else g.lineTo(px, py); }
        g.stroke();
        var mx = a.mouse.inside ? a.mouse.x : x0 + level / maxLv * w;
        var hl = KB.clamp(Math.round((mx - x0) / w * maxLv), 1, maxLv);
        var hx = x0 + hl / maxLv * w, hy = y0 - xpReq(hl) / maxXp * h;
        KB.dot(g, hx, hy, 4, C.text);
        KB.label(g, "lv " + hl + " → " + (hl + 1) + ": " + xpReq(hl) + " XP", Math.min(hx + 8, a.W - 170), hy - 12, C.text, 11);
        KB.label(g, "+10/level", x0 + 6, 30, C.gold, 11); KB.label(g, "+13/level", x0 + 20 / maxLv * w + 6, 30, C.gold, 11); KB.label(g, "+16/level", x0 + 40 / maxLv * w + 6, 30, C.gold, 11);
        a.text("level " + level + "   xp " + xp.toFixed(0) + " / " + xpReq(level) + "   pending_levels " + pending + "   " + log);
      }
    });
    function add(v) {
      var amount = v * growth, gained = 0;
      xp += amount;
      while (xp >= xpReq(level)) { xp -= xpReq(level); level++; gained++; }
      pending += gained;
      log = "add(" + amount + ") → " + gained + " level";
      api.redraw();
    }
    api.button("+5 XP", function () { add(5); });
    api.button("+100 XP", function () { add(100); });
    api.button("+2000 XP (gem bank)", function () { add(2000); });
    api.button("Layar level: pilih 1", function () { if (pending > 0) { pending--; log = "_finish_level(): sisa " + pending; api.redraw(); } }, true);
    api.range("GROWTH", 0.5, 2, 0.1, 1, function (v) { growth = v; }, function (v) { return v.toFixed(1) + "×"; });
    api.button("Reset", function () { level = 1; xp = 0; pending = 0; log = ""; api.redraw(); }, true);
    api.canvas.addEventListener("pointermove", function () { api.redraw(); });
  };

  // ------------------------------------------------------------------ kalkulator Stats
  D.stats = function (root) {
    var api = KB.frame(root, { title: "Stats: (base + flat) × (1 + percent)", noCanvas: true, noLoop: true });
    var mods = [
      { name: "Bloodied Blade lv 1", stat: "MIGHT", flat: 0, pct: 0.10, on: true },
      { name: "Bloodied Blade lv 2", stat: "MIGHT", flat: 0, pct: 0.10, on: false },
      { name: "Shop: Might lv 3", stat: "MIGHT", flat: 0, pct: 0.15, on: false },
      { name: "Hunter's Eye", stat: "CRIT_CHANCE", flat: 0.05, pct: 0, on: false },
      { name: "Sand Clock lv 1", stat: "COOLDOWN", flat: 0, pct: -0.08, on: true },
      { name: "Sand Clock lv 2", stat: "COOLDOWN", flat: 0, pct: -0.08, on: false },
      { name: "Heart Locket", stat: "MAX_HP", flat: 0, pct: 0.20, on: false },
      { name: "Hunter: +10 max HP (contoh)", stat: "MAX_HP", flat: 10, pct: 0, on: false }
    ];
    var base = { MIGHT: 1, COOLDOWN: 1, MAX_HP: 100, CRIT_CHANCE: 0 };
    var box = api.body;
    box.style.padding = "12px 14px";
    var list = KB.el("div", { style: "display:grid;grid-template-columns:repeat(auto-fill,minmax(230px,1fr));gap:6px 14px" });
    var table = KB.el("div", { "class": "table-wrap" });
    box.appendChild(list); box.appendChild(table);
    mods.forEach(function (m, i) {
      var id = "statm" + i + Math.random().toString(36).slice(2, 6);
      var lab = KB.el("label", { "for": id, style: "display:flex;gap:8px;align-items:center;font-size:14.5px" });
      var c = KB.el("input", { type: "checkbox", id: id }); c.checked = m.on;
      c.addEventListener("change", function () { m.on = c.checked; render(); });
      lab.appendChild(c);
      lab.appendChild(document.createTextNode(m.name + " (" + m.stat + " " + (m.flat ? (m.flat > 0 ? "+" : "") + m.flat + " flat" : (m.pct > 0 ? "+" : "") + Math.round(m.pct * 100) + "%") + ")"));
      list.appendChild(lab);
    });
    function render() {
      var rows = Object.keys(base).map(function (s) {
        var flat = 0, pct = 0;
        mods.forEach(function (m) { if (m.on && m.stat === s) { flat += m.flat; pct += m.pct; } });
        var v = (base[s] + flat) * (1 + pct);
        if (s === "COOLDOWN") v = Math.max(v, 0.1); else v = Math.max(v, 0);
        return "<tr><td><code>" + s + "</code></td><td>" + base[s] + "</td><td>" + flat + "</td><td>" + (pct >= 0 ? "+" : "") + Math.round(pct * 100) + "%</td><td><b>" + (+v.toFixed(3)) + "</b></td></tr>";
      }).join("");
      table.innerHTML = "<table><thead><tr><th>Stat</th><th>base</th><th>flat (jumlah)</th><th>percent (jumlah)</th><th>nilai</th></tr></thead><tbody>" + rows + "</tbody></table>";
    }
    render();
    api.note("Semua persen pada satu stat <b>dijumlah dulu</b> baru dikalikan, jadi dua kali +10% = +20%, bukan +21%. Cooldown punya batas bawah <code>MIN_COOLDOWN = 0.1</code>. Nilai dihitung ulang hanya saat modifier berubah (<code>_recompute</code>), lalu dibaca murah tiap frame lewat <code>value(id)</code>.");
  };

  // ------------------------------------------------------------------ alur pause / level up / peti
  D.pause = function (root) {
    var s = { paused: false, levels: 0, chests: 0, screen: "—", menu: false, log: "Game berjalan." };
    var nodes = [
      ["Game", "ALWAYS"], ["Player, EnemySwarm, …", "INHERIT"], ["HUD", "ALWAYS"],
      ["LevelUpScreen", "ALWAYS"], ["ChestScreen", "ALWAYS"], ["PauseMenu", "ALWAYS"], ["SceneFader (autoload)", "ALWAYS"]
    ];
    var api = KB.frame(root, {
      title: "Pause, antrian level up dan peti", w: 720, h: 300, noLoop: true,
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        KB.label(g, "get_tree().paused = " + s.paused, 14, 22, s.paused ? C.gold : C.green, 13);
        KB.label(g, "pending_levels = " + s.levels + "    pending_chests = " + s.chests, 14, 44, C.text, 12);
        KB.label(g, "layar terbuka: " + s.screen, 14, 66, C.text, 12);
        nodes.forEach(function (n, i) {
          var y = 96 + i * 26, runs = !s.paused || n[1] === "ALWAYS";
          KB.box(g, 14, y, 300, 22, runs ? "#1f3324" : "#2e1d25", runs ? "#3d6a48" : "#5a2a36");
          KB.label(g, n[0], 22, y + 11, C.text, 11);
          KB.label(g, n[1], 230, y + 11, C.muted, 10);
          KB.label(g, runs ? "jalan" : "berhenti", 322, y + 11, runs ? C.green : C.red, 11);
        });
        var lines = s.log.split("\n");
        lines.forEach(function (l, i) { KB.label(g, l, 400, 110 + i * 20, C.gold, 11.5); });
        KB.label(g, "Game._process: if get_tree().paused: return", 400, 270, C.muted, 11);
      }
    });
    function step() {
      if (s.paused) return;
      if (s.levels > 0) { s.paused = true; s.screen = "LevelUpScreen"; s.log = "Akhir frame: pending_levels > 0\n→ paused = true, _offer_choices()"; }
      else if (s.chests > 0) { s.paused = true; s.screen = "ChestScreen"; s.log = "Akhir frame: pending_chests > 0\n→ paused = true, _open_chest()"; }
    }
    api.button("Gem besar (+3 level)", function () { if (s.paused) return; s.levels += 3; s.log = "leveling.add() mengembalikan 3"; step(); api.redraw(); });
    api.button("Ambil peti", function () { if (s.paused) return; s.chests += 1; s.log = "_on_pickup(CHEST): pending_chests += 1"; step(); api.redraw(); });
    api.button("Pilih kartu", function () {
      if (s.screen !== "LevelUpScreen") return;
      s.levels--;
      if (s.levels > 0) s.log = "picked → _finish_level()\nmasih ada " + s.levels + ": tawarkan kartu baru";
      else { s.paused = false; s.screen = "—"; s.log = "picked → _finish_level()\nantrian habis: level_up.close(), paused = false"; step(); }
      api.redraw();
    }, true);
    api.button("Tutup peti", function () {
      if (s.screen !== "ChestScreen") return;
      s.chests--;
      if (s.chests > 0) s.log = "closed → _on_chest_closed()\npeti berikutnya";
      else { s.paused = false; s.screen = "—"; s.log = "closed → antrian peti habis\npaused = false"; }
      api.redraw();
    }, true);
    api.button("Esc (pause)", function () {
      if (s.screen !== "—" && s.screen !== "PauseMenu") return;
      if (s.screen === "PauseMenu") { s.paused = false; s.screen = "—"; s.log = "_set_paused(false)"; step(); }
      else { s.paused = true; s.screen = "PauseMenu"; s.log = "_unhandled_input: pause → _set_paused(true)"; }
      api.redraw();
    }, true);
  };

  // ------------------------------------------------------------------ proyektil (ProjectileField)
  D.projectiles = function (root) {
    var mode = "pierce", pierce = 1, en = [], shots = [], uid = 0, time = 0, fireT = 0, rate = 0.5, hits = 0;
    var view = { x: 30, y: 20, w: 660, h: 340 }, P = { x: 120, y: 190 };
    function fillEnemies() { while (en.length < 26) en.push({ x: KB.rand(260, 680), y: KB.rand(40, 350), uid: ++uid, flash: 0, hp: 3 }); }
    fillEnemies();
    function nearest(x, y, mem, rad) {
      var best = null, bd = rad * rad;
      en.forEach(function (e) { if (mem.indexOf(e.uid) >= 0) return; var d = (e.x - x) * (e.x - x) + (e.y - y) * (e.y - y); if (d < bd) { bd = d; best = e; } });
      return best;
    }
    function fire() {
      var t = nearest(P.x, P.y, [], 1000) || { x: 600, y: 190 };
      var dx = t.x - P.x, dy = t.y - P.y, l = KB.len(dx, dy) || 1, sp = 260;
      var s = { x: P.x, y: P.y, vx: dx / l * sp, vy: dy / l * sp, life: mode === "screen" ? 6 : 2.2, mem: [], hits: pierce + 1, arc: 0, trail: [] };
      if (mode === "bounce") s.hits = pierce + 3;
      if (mode === "screen") s.hits = -1;
      if (mode === "arc") { s.life = 0.9; s.life0 = 0.9; s.vx = dx / 0.9; s.vy = dy / 0.9; s.tx = t.x; s.ty = t.y; }
      shots.push(s);
    }
    var api = KB.frame(root, {
      title: "Proyektil: pierce, pantul ke musuh, pantul tepi layar, lob", w: 720, h: 380,
      step: function (dt) {
        time += dt; fireT -= dt;
        if (fireT <= 0) { fireT += rate; fire(); }
        en.forEach(function (e) { e.flash = Math.max(0, e.flash - dt * 6); });
        for (var i = shots.length - 1; i >= 0; i--) {
          var s = shots[i];
          s.life -= dt;
          if (s.life <= 0) {
            if (mode === "arc") { en.forEach(function (e) { if (KB.len(e.x - s.tx, e.y - s.ty) < 45) { e.flash = 1; e.hp--; hits++; } }); }
            shots.splice(i, 1); continue;
          }
          s.x += s.vx * dt; s.y += s.vy * dt;
          s.trail.push(s.x, s.y); if (s.trail.length > 16) s.trail.splice(0, 2);
          if (mode === "screen") {
            if ((s.x < view.x && s.vx < 0) || (s.x > view.x + view.w && s.vx > 0)) s.vx = -s.vx;
            if ((s.y < view.y && s.vy < 0) || (s.y > view.y + view.h && s.vy > 0)) s.vy = -s.vy;
          }
          if (mode === "arc") continue;
          var spent = false;
          for (var k = 0; k < en.length && !spent; k++) {
            var e = en[k];
            if (KB.len(e.x - s.x, e.y - s.y) > 12) continue;
            if (s.mem.indexOf(e.uid) >= 0) continue;
            s.mem.push(e.uid); if (s.mem.length > 4) s.mem.shift();
            e.flash = 1; e.hp--; hits++;
            if (s.hits > 0) { s.hits--; if (s.hits === 0) spent = true; }
            if (mode === "bounce" && !spent) {
              var nx = nearest(s.x, s.y, s.mem, 160);
              if (nx) { var sp = KB.len(s.vx, s.vy), ddx = nx.x - s.x, ddy = nx.y - s.y, ll = KB.len(ddx, ddy) || 1; s.vx = ddx / ll * sp; s.vy = ddy / ll * sp; }
              break;
            }
          }
          if (spent) shots.splice(i, 1);
        }
        for (var j = en.length - 1; j >= 0; j--) if (en[j].hp <= 0) en.splice(j, 1);
        fillEnemies();
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        if (mode === "screen") { g.strokeStyle = C.grid2; g.setLineDash([6, 4]); g.strokeRect(view.x, view.y, view.w, view.h); g.setLineDash([]); KB.label(g, "view_rect (CameraRig.ground_view_rect)", view.x + 6, view.y + 12, C.muted, 10); }
        en.forEach(function (e) { KB.sprite(g, "ghoul", e.x, e.y + 6, 1.8, e.x > P.x, e.flash); KB.label(g, String(e.uid), e.x, e.y + 14, "#5a5068", 9, "center"); });
        KB.sprite(g, "hunter", P.x, P.y + 8, 2.6, false);
        shots.forEach(function (s) {
          g.strokeStyle = "rgba(232,184,74,.35)"; g.lineWidth = 2; g.beginPath();
          for (var k = 0; k < s.trail.length; k += 2) { if (k === 0) g.moveTo(s.trail[k], s.trail[k + 1]); else g.lineTo(s.trail[k], s.trail[k + 1]); }
          g.stroke();
          var y = s.y;
          if (mode === "arc") { var t = 1 - s.life / s.life0; y -= 4 * 60 * t * (1 - t); KB.ring(g, s.tx, s.ty, 45 * (0.3 + t * 0.7), "rgba(91,210,255,.5)", 1); }
          KB.dot(g, s.x, y, 4, mode === "arc" ? C.player : C.gold);
          if (mode !== "arc" && s.mem.length) KB.label(g, "[" + s.mem.join(",") + "]", s.x + 6, y - 8, C.muted, 9);
        });
        a.text("proyektil hidup " + shots.length + "   total hit " + hits + "   hits awal = " + (mode === "screen" ? "-1 (tak terbatas)" : mode === "bounce" ? "pierce + 3 pantulan" : mode === "arc" ? "NO_HIT di udara, kolam saat mendarat" : "pierce + 1"));
      }
    });
    api.select("mode", [["pierce", "Lurus + pierce (pisau)"], ["bounce", "BOUNCE_ENEMY (salib, evolusi)"], ["screen", "BOUNCE_SCREEN (salib)"], ["arc", "ARC (vial)"]], "pierce", function (v) { mode = v; shots.length = 0; });
    api.range("pierce", 0, 5, 1, 1, function (v) { pierce = v; });
    api.range("interval tembak", 0.1, 1.5, 0.05, 0.5, function (v) { rate = v; }, function (v) { return v.toFixed(2) + " s"; });
    api.note("Angka kecil di atas proyektil = <b>hit memory</b>: uid 4 musuh terakhir yang sudah dikenai (<code>HIT_MEMORY = 4</code>). Proyektil menembus musuh selama beberapa frame; tanpa memori ini ia akan mengenai musuh yang sama tiap frame.");
  };

  // ------------------------------------------------------------------ orbit (Vesper Beads)
  D.orbit = function (root) {
    var amount = 3, speed = 3, radius = 90, rings = 1, rehit = 0.5, en = [], uid = 0, phase = 0, time = 0, hits = 0, mem = [];
    var P = { x: 360, y: 200 };
    function fill() { while (en.length < 30) { var a = Math.random() * 6.28; en.push({ x: P.x + Math.cos(a) * 320, y: P.y + Math.sin(a) * 200, uid: ++uid, flash: 0, f: 1 }); } }
    fill();
    var rehitT = 0;
    var api = KB.frame(root, {
      title: "Orbit: manik mengitari pemain, rehit interval", w: 720, h: 400,
      step: function (dt) {
        time += dt; phase = (phase + speed * dt) % 6.2832;
        rehitT -= dt; if (rehitT <= 0) { rehitT += rehit; mem = []; }
        en.forEach(function (e) {
          var dx = P.x - e.x, dy = P.y - e.y, l = KB.len(dx, dy) || 1;
          if (l > 40) { e.x += dx / l * 35 * dt; e.y += dy / l * 35 * dt; }
          e.flash = Math.max(0, e.flash - dt * 6); e.f = dx > 0 ? 1 : -1;
        });
        beads().forEach(function (b) {
          en.forEach(function (e) {
            if (KB.len(e.x - b.x, e.y - b.y) > 14) return;
            var key = b.id + ":" + e.uid;
            if (mem.indexOf(key) >= 0) return;
            mem.push(key); e.flash = 1; hits++;
            var dx = e.x - P.x, dy = e.y - P.y, l = KB.len(dx, dy) || 1; e.x += dx / l * 10; e.y += dy / l * 10;
          });
        });
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        for (var r = 0; r < rings; r++) g.strokeStyle = C.grid2, g.setLineDash([3, 5]), g.beginPath(), g.ellipse(P.x, P.y, radius * Math.pow(0.55, r), radius * Math.pow(0.55, r) * 0.766, 0, 0, 6.283), g.stroke();
        g.setLineDash([]);
        en.forEach(function (e) { KB.sprite(g, "ghoul", e.x, e.y + 6, 1.8, e.f < 0, e.flash); });
        KB.sprite(g, "hunter", P.x, P.y + 8, 2.6, false);
        beads().forEach(function (b) { KB.dot(g, b.x, b.y, 6, C.gold); KB.dot(g, b.x - 2, b.y - 2, 2, "#fff3c4"); });
        a.text("manik " + beads().length + "   rehit tiap " + rehit.toFixed(2) + " s (memori dihapus)   total hit " + hits);
      }
    });
    function beads() {
      var out = [];
      for (var ring = 0; ring < rings; ring++) {
        var dir = ring % 2 === 0 ? 1 : -1, n = ring === 0 ? amount : Math.max(2, Math.ceil(amount * 0.5)), rr = radius * Math.pow(0.55, ring);
        for (var k = 0; k < n; k++) {
          var ang = dir * phase + 6.2832 * k / n;
          out.push({ id: ring * 100 + k, x: P.x + Math.cos(ang) * rr, y: P.y + Math.sin(ang) * rr * 0.766 });
        }
      }
      return out;
    }
    api.range("amount", 1, 8, 1, 3, function (v) { amount = v; });
    api.range("kecepatan (rad/s)", 0.5, 8, 0.1, 3, function (v) { speed = v; }, function (v) { return v.toFixed(1); });
    api.range("area (radius)", 40, 160, 5, 90, function (v) { radius = v; });
    api.range("rings", 1, 3, 1, 1, function (v) { rings = v; });
    api.range("rehit", 0.1, 2, 0.05, 0.5, function (v) { rehit = v; }, function (v) { return v.toFixed(2) + " s"; });
    api.note("Posisi manik tidak diintegrasikan dari kecepatan, tapi dihitung ulang dari sudut: <code>p = center + (cos θ, sin θ) · orbit_r</code>, dengan <code>vel.x = θ</code> dan <code>vel.y = rad/s</code>. Jadi lingkarannya selalu rapi walau pemain bergerak. Ring dalam (evolusi Eternal Rosary) berputar berlawanan.");
  };

  // ------------------------------------------------------------------ wave director (night.tres)
  var ENTRIES = [
    [0, 6, "ghoul, bat", 2, 5, 250], [3, 12, "bat", 1, 3, 400], [5, 15, "ghoul, skeleton, acolyte", 4, 8, 500],
    [8, 30, "brute", 0.15, 0.5, 900], [12, 22, "skeleton, acolyte, bat", 7, 12, 800], [15, 30, "ghoul", 8, 14, 1000],
    [22, 30, "skeleton, acolyte", 12, 18, 1200], [25, 30, "bat", 4, 8, 1300]
  ];
  var KIND = ["RING", "LINE", "BURST", "ELITE", "BOSS"];
  var EVENTS = [[1, 0, "wisp", 20], [2, 2, "bat", 40], [3, 1, "skull", 14], [4, 3, "ghoul", 1], [5, 0, "wisp", 28], [6, 2, "bat", 60], [7, 3, "skeleton", 1],
    [7.5, 1, "skull", 18], [8.5, 0, "wisp", 32], [10, 4, "Hollow Abbot", 1], [11, 2, "bat", 80], [12, 3, "brute", 1], [13, 0, "wisp", 40], [14, 1, "skull", 24],
    [15, 3, "acolyte", 2], [16, 0, "wisp", 48], [17, 2, "bat", 100], [18, 3, "skeleton", 2], [19, 1, "skull", 30], [20, 4, "Vesperine", 1], [21, 0, "wisp", 56],
    [22, 3, "brute", 2], [23, 2, "bat", 120], [24, 1, "skull", 36], [25, 4, "Hollow Abbot", 1], [26, 0, "wisp", 64], [27, 3, "acolyte", 3], [28, 2, "bat", 150], [29, 0, "wisp", 72]];
  D.wave = function (root) {
    var minute = 0, playing = 1;
    function rateAt(e, m) { var t = KB.clamp((m - e[0]) / (e[1] - e[0]), 0, 1); return e[3] + (e[4] - e[3]) * t; }
    var api = KB.frame(root, {
      title: "WaveTable night.tres: 8 entry + 29 event + final menit 30", w: 720, h: 420, paused: true,
      step: function (dt) { minute += dt * 1.2; if (minute > 31) minute = 0; slider.value = minute; },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        var x0 = 200, w = 500, row = 22, top = 30;
        function X(m) { return x0 + m / 30 * w; }
        for (var m = 0; m <= 30; m += 5) { g.strokeStyle = C.grid; g.beginPath(); g.moveTo(X(m), top - 8); g.lineTo(X(m), 330); g.stroke(); KB.label(g, m + "'", X(m), top - 16, C.muted, 10, "center"); }
        ENTRIES.forEach(function (e, i) {
          var y = top + i * row, active = minute >= e[0] && minute < e[1];
          KB.label(g, e[2], 192, y + 8, active ? C.text : C.muted, 10.5, "right");
          var grad = g.createLinearGradient(X(e[0]), 0, X(e[1]), 0);
          grad.addColorStop(0, active ? "rgba(127,174,90,.45)" : "rgba(127,174,90,.18)");
          grad.addColorStop(1, active ? "rgba(127,174,90,.95)" : "rgba(127,174,90,.4)");
          g.fillStyle = grad; g.fillRect(X(e[0]), y, X(e[1]) - X(e[0]), row - 6);
          if (active) KB.label(g, rateAt(e, minute).toFixed(1) + "/s", Math.min(X(minute) + 4, 670), y + 8, C.text, 10);
        });
        var ey = top + ENTRIES.length * row + 14;
        KB.label(g, "event", 192, ey + 8, C.muted, 10.5, "right");
        var cols = [C.player, C.orange, C.enemy2, C.gold, C.red];
        EVENTS.forEach(function (ev) {
          var past = ev[0] <= minute;
          g.fillStyle = cols[ev[1]]; g.globalAlpha = past ? 1 : 0.45;
          var x = X(ev[0]);
          if (ev[1] === 4) { g.beginPath(); g.moveTo(x, ey - 2); g.lineTo(x + 6, ey + 8); g.lineTo(x, ey + 18); g.lineTo(x - 6, ey + 8); g.fill(); }
          else g.fillRect(x - 2, ey + ev[1] * 3, 4, 10);
          g.globalAlpha = 1;
        });
        KB.box(g, X(30), top - 8, 4, 322, C.red);
        KB.label(g, "final_minute: Knellwraith", X(30) - 4, 342, C.red, 10, "right");
        // kurva total laju
        var cy0 = 410, ch = 50;
        g.strokeStyle = C.gold; g.lineWidth = 1.5; g.beginPath();
        for (var mm = 0; mm <= 30; mm += 0.25) {
          var tot = 0; ENTRIES.forEach(function (e) { if (mm >= e[0] && mm < e[1]) tot += rateAt(e, mm); });
          var y2 = cy0 - tot / 45 * ch; if (mm === 0) g.moveTo(X(mm), y2); else g.lineTo(X(mm), y2);
        }
        g.stroke();
        KB.label(g, "total spawn/s", 192, cy0 - 20, C.gold, 10.5, "right");
        g.strokeStyle = C.text; g.lineWidth = 2; g.beginPath(); g.moveTo(X(Math.min(minute, 30)), top - 8); g.lineTo(X(Math.min(minute, 30)), cy0); g.stroke();
        var tot2 = 0; ENTRIES.forEach(function (e) { if (minute >= e[0] && minute < e[1]) tot2 += rateAt(e, minute); });
        var lastEv = EVENTS.filter(function (ev) { return ev[0] <= minute; }).pop();
        a.text("menit " + minute.toFixed(1) + "   total laju " + tot2.toFixed(1) + " spawn/s   hp_scale = 1 + 0.12 × menit = " + (1 + 0.12 * Math.min(minute, 30)).toFixed(2) +
          "   event terakhir: " + (lastEv ? KIND[lastEv[1]] + " " + lastEv[2] + " ×" + lastEv[3] + " @" + lastEv[0] + "'" : "-"));
      }
    });
    var slider = api.range("menit", 0, 31, 0.1, 0, function (v) { minute = v; api.redraw(); }, function (v) { return v.toFixed(1); });
    api.note("Bar hijau = <code>WaveEntry</code> (aliran spawn kontinu, boleh tumpang tindih, laju naik linear dari <code>rate_start</code> ke <code>rate_end</code>). Penanda: biru RING, oranye LINE, ungu BURST, emas ELITE, merah (belah ketupat) BOSS. Tekan Putar untuk memajukan waktu, atau geser slider.");
  };

  // ------------------------------------------------------------------ perilaku musuh
  D.behaviors = function (root) {
    var en = [], shots = [], P = { x: 360, y: 210, face: 1 }, time = 0, sel = "WEAVE";
    var api = KB.frame(root, {
      title: "Perilaku: CHASE, WEAVE, RANGED, DRIFT", w: 720, h: 420,
      step: function (dt, a) {
        time += dt;
        KB.steer(a, P, 70, dt, time * 0.6);
        for (var i = en.length - 1; i >= 0; i--) {
          var e = en[i], dx = P.x - e.x, dy = P.y - e.y, l = KB.len(dx, dy) || 1, vx = 0, vy = 0;
          if (e.b === "DRIFT") { vx = e.dx * e.sp; vy = e.dy * e.sp; e.t -= dt; if (e.t <= 0) { en.splice(i, 1); continue; } }
          else {
            vx = dx / l * e.sp; vy = dy / l * e.sp;
            if (e.b === "WEAVE") { e.t += dt; var s = 0.8 * Math.sin(e.t * 1.5 * 6.283); var ox = -vy, oy = vx; vx += ox * s; vy += oy * s; }
            if (e.b === "RANGED") {
              var want = 140;
              if (l > want + 15) { } else if (l < want - 30) { vx *= -0.6; vy *= -0.6; } else { var px = -vy, py = vx; vx = px * 0.35 * e.side; vy = py * 0.35 * e.side; }
              e.t -= dt;
              if (e.t <= 0) { e.t += 2.5; if (l < want + 80) { shots.push({ x: e.x, y: e.y, vx: dx / l * 120, vy: dy / l * 120, life: (want + 120) / 120 }); e.flash = 0.6; } }
            }
          }
          e.x += vx * dt; e.y += vy * dt; e.f = (e.b === "DRIFT" ? vx : dx) > 0 ? 1 : -1; e.flash = Math.max(0, (e.flash || 0) - dt * 4);
        }
        for (var j = shots.length - 1; j >= 0; j--) { var s2 = shots[j]; s2.x += s2.vx * dt; s2.y += s2.vy * dt; s2.life -= dt; if (s2.life <= 0 || KB.len(s2.x - P.x, s2.y - P.y) < 10) shots.splice(j, 1); }
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        en.forEach(function (e) {
          if (e.b === "RANGED") KB.sprite(g, "ghoul", e.x, e.y + 6, 1.8, e.f < 0, e.flash, 0.6);
          else if (e.b === "DRIFT") { KB.dot(g, e.x, e.y, 6, "#b8e8ff"); KB.dot(g, e.x, e.y, 3, "#fff"); }
          else if (e.b === "WEAVE") { g.fillStyle = C.enemy2; g.beginPath(); g.moveTo(e.x - 9, e.y - 3); g.lineTo(e.x, e.y + 3); g.lineTo(e.x + 9, e.y - 3); g.lineTo(e.x, e.y - 8); g.fill(); }
          else KB.sprite(g, "ghoul", e.x, e.y + 6, 1.8, e.f < 0, e.flash);
        });
        shots.forEach(function (s) { KB.dot(g, s.x, s.y, 4, C.red); });
        KB.sprite(g, "hunter", P.x, P.y + 8, 2.6, P.face < 0);
        var c = { CHASE: 0, WEAVE: 0, RANGED: 0, DRIFT: 0 }; en.forEach(function (e) { c[e.b]++; });
        a.text("CHASE " + c.CHASE + "   WEAVE " + c.WEAVE + "   RANGED " + c.RANGED + "   DRIFT " + c.DRIFT + "   tembakan musuh " + shots.length);
      }
    });
    function spawn(b, n) {
      for (var k = 0; k < n; k++) {
        var a = Math.random() * 6.283;
        en.push({ b: b, x: P.x + Math.cos(a) * 330, y: P.y + Math.sin(a) * 230, sp: b === "WEAVE" ? 75 : b === "RANGED" ? 45 : 50, t: Math.random() * 2.5, side: Math.random() < 0.5 ? 1 : -1 });
      }
      api.kick();
    }
    api.select("perilaku", [["CHASE", "CHASE (ghoul)"], ["WEAVE", "WEAVE (kelelawar)"], ["RANGED", "RANGED (acolyte)"]], "WEAVE", function (v) { sel = v; });
    api.button("Spawn 8", function () { spawn(sel, 8); });
    api.button("Event RING", function () {
      var n = 24, r = 190, life = 2 * r / 60;
      for (var k = 0; k < n; k++) { var a = 6.2832 * k / n, ox = Math.cos(a) * r, oy = Math.sin(a) * r; en.push({ b: "DRIFT", x: P.x + ox, y: P.y + oy, dx: -ox / r, dy: -oy / r, sp: 60, t: life }); }
      api.kick();
    }, true);
    api.button("Event LINE", function () {
      var a = Math.random() * 6.283, hx = Math.cos(a), hy = Math.sin(a), sx = -hy, sy = hx, r = 300;
      for (var k = 0; k < 14; k++) { var lat = (k - 6.5) * 18; en.push({ b: "DRIFT", x: P.x - hx * r + sx * lat, y: P.y - hy * r + sy * lat, dx: hx, dy: hy, sp: 90, t: 2 * r / 90 }); }
      api.kick();
    }, true);
    api.button("Bersihkan", function () { en.length = 0; shots.length = 0; }, true);
    spawn("CHASE", 6); spawn("WEAVE", 6); spawn("RANGED", 3);
    api.note("Satu loop, satu cabang per slot: <code>b &lt;= RANGED</code> berarti mengejar pemain (CHASE/WEAVE/RANGED), selain itu bergerak menurut <code>dir</code>. WEAVE menambah komponen tegak lurus × sin; RANGED menjaga jarak, strafe, dan menembak; DRIFT (ring/line) bergerak lurus lalu hilang diam-diam (<code>SILENT</code>).");
  };

  // ------------------------------------------------------------------ shake + hit-stop
  D.feel = function (root) {
    var trauma = 0, stop = 0, decay = 2.5, maxOff = 18, shakeOn = true, hist = [], time = 0, en = [], sim = 0;
    for (var i = 0; i < 24; i++) en.push({ a: Math.random() * 6.28, r: KB.rand(60, 150), s: KB.rand(0.4, 1) });
    var api = KB.frame(root, {
      title: "Camera shake (trauma²) dan hit-stop", w: 720, h: 330,
      step: function (dt) {
        time += dt;
        if (stop > 0) stop -= dt; else { sim += dt; en.forEach(function (e) { e.a += e.s * dt; }); }
        trauma = Math.max(0, trauma - dt * decay);
        hist.push([trauma, stop > 0]); if (hist.length > 300) hist.shift();
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        var s = shakeOn ? trauma * trauma * maxOff : 0, ox = KB.rand(-s, s), oy = KB.rand(-s, s);
        g.save(); g.translate(ox, oy);
        en.forEach(function (e) { KB.sprite(g, "ghoul", 230 + Math.cos(e.a) * e.r, 140 + Math.sin(e.a) * e.r * 0.6, 1.8, Math.sin(e.a) > 0); });
        KB.sprite(g, "hunter", 230, 150, 2.6, false);
        g.restore();
        KB.box(g, 440, 20, 260, 140, "#221b2b", C.grid2);
        KB.label(g, "trauma (garis) · hit-stop (merah)", 446, 32, C.muted, 10);
        hist.forEach(function (h, i) {
          var x = 440 + i * 260 / 300;
          if (h[1]) { g.fillStyle = "rgba(255,74,94,.35)"; g.fillRect(x, 40, 1, 120); }
          g.fillStyle = C.gold; g.fillRect(x, 158 - h[0] * 110, 1.2, 1.2);
          g.fillStyle = C.player; g.fillRect(x, 158 - h[0] * h[0] * 110, 1.2, 1.2);
        });
        KB.label(g, "emas = trauma, biru = trauma² (offset)", 446, 176, C.muted, 10);
        KB.label(g, stop > 0 ? "HIT-STOP: simulasi berhenti, kamera tetap bergetar" : "simulasi jalan", 446, 210, stop > 0 ? C.red : C.green, 11);
        a.text("trauma " + trauma.toFixed(2) + "   offset maks " + s.toFixed(1) + " px   waktu simulasi " + sim.toFixed(2) + " s");
      }
    });
    api.button("Pemain kena (0.35)", function () { trauma = Math.min(1, trauma + 0.35); api.kick(); });
    api.button("Bom (0.75 + stop 0.08 s)", function () { trauma = Math.min(1, trauma + 0.75); stop = Math.max(stop, 0.08); api.kick(); });
    api.button("Boss mati (0.8 + stop 0.16 s)", function () { trauma = Math.min(1, trauma + 0.8); stop = Math.max(stop, 0.16); api.kick(); });
    api.range("peluruhan /s", 0.5, 6, 0.1, 2.5, function (v) { decay = v; });
    api.check("screen shake (Options)", true, function (v) { shakeOn = v; });
    api.note("Getaran memakai trauma yang dikuadratkan: pukulan kecil (0,35 → 0,12) nyaris tak terasa, bom terasa keras. Hit-stop membuat <code>Game._process</code> hanya memanggil <code>camera_rig.tick</code> beberapa frame, jadi dunia membeku tapi kamera tetap hidup.");
  };

  // ------------------------------------------------------------------ save atomik
  D.save = function (root) {
    var api = KB.frame(root, { title: "save_game(): tmp → bak → rename", noCanvas: true, noLoop: true });
    var files, step, log;
    var STEPS = [
      "1. tulis JSON baru ke save.json.tmp",
      "2. hapus save.json.bak lama",
      "3. rename save.json → save.json.bak",
      "4. rename save.json.tmp → save.json"
    ];
    function reset() { files = { "save.json": "v1 (data lama)", "save.json.bak": "v0 (lebih lama)", "save.json.tmp": null }; step = 0; log = "Siap menyimpan v2."; }
    reset();
    var view = KB.el("div", { style: "padding:12px 14px;display:grid;gap:10px" });
    api.body.appendChild(view);
    function render() {
      var cards = Object.keys(files).map(function (f) {
        var v = files[f];
        return '<div style="border:1px solid var(--line);border-radius:6px;padding:8px 10px;min-width:0;background:' + (v ? "var(--panel-2)" : "transparent") + '"><code>' + f + "</code><br><span style=\"color:" + (v ? "var(--fg)" : "var(--muted)") + '">' + (v || "tidak ada") + "</span></div>";
      }).join("");
      var st = STEPS.map(function (s, i) { return '<li style="color:' + (i < step ? "var(--ok)" : i === step ? "var(--fg)" : "var(--muted)") + '">' + (i < step ? "✓ " : "") + s + "</li>"; }).join("");
      view.innerHTML = '<div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(170px,1fr));gap:8px">' + cards + '</div><ol style="margin:0;padding-left:1.2em">' + st + '</ol><div style="font-family:var(--font-mono);font-size:13px;color:var(--gold)">' + log + "</div>";
    }
    function doStep() {
      if (step === 0) files["save.json.tmp"] = "v2 (baru)";
      else if (step === 1) files["save.json.bak"] = null;
      else if (step === 2) { files["save.json.bak"] = files["save.json"]; files["save.json"] = null; }
      else if (step === 3) { files["save.json"] = files["save.json.tmp"]; files["save.json.tmp"] = null; }
      else return;
      step++; log = step === 4 ? "Selesai: save.json = v2, .bak = v1." : "Langkah " + step + " selesai.";
      render();
    }
    function crash() {
      var got = files["save.json"] ? ["save.json", files["save.json"]] : files["save.json.bak"] ? ["save.json.bak", files["save.json.bak"]] : null;
      log = "CRASH setelah langkah " + step + ". Saat game dibuka lagi, load_game() membaca " +
        (got ? got[0] + " → " + got[1] + (got[0] === "save.json.bak" ? ' (load_status = "backup")' : ' (load_status = "ok")') : 'tidak ada file → default (load_status = "new")') + ".";
      render();
    }
    api.button("Langkah berikutnya", doStep);
    api.button("Crash di sini", crash, true);
    api.button("Reset", function () { reset(); render(); }, true);
    render();
    api.note("Di titik mana pun crash terjadi, selalu ada satu file JSON utuh yang bisa dibaca: versi lama atau versi baru. Yang tidak mungkin terjadi adalah file setengah tertulis menggantikan save satu-satunya.");
  };

  // ------------------------------------------------------------------ pool suara
  D.audio = function (root) {
    var VOICES = 24, voices = [], rate = 300, minInt = 0.04, maxConc = 4, played = 0, dropped = 0, req = 0, nextOk = 0, time = 0, acc = 0, hist = [];
    for (var i = 0; i < VOICES; i++) voices.push({ id: null, left: 0, start: 0, pr: 0 });
    // [id, durasi klip (perkiraan demo), priority, warna]; min_interval/max_concurrent dari data/sound_bank.tres
    var ids = [["kill", 0.32, 1, "#ff4a5e"], ["hit", 0.12, 0, "#e8b84a"], ["gem", 0.18, 1, "#4aa3ff"], ["level_up", 1.2, 5, "#6bd08a"]];
    var LIM = { hit: [0.045, 4], gem: [0.05, 3], level_up: [0.2, 1] };
    var cool = {};
    function play(id) {
      req++;
      var def = ids.filter(function (d) { return d[0] === id; })[0];
      if (time < (cool[id] || 0)) { dropped++; return; }
      var same = 0, free = -1, steal = -1;
      voices.forEach(function (v, k) {
        if (v.left > 0) { if (v.id === id) same++; else if (v.pr <= def[2] && (steal < 0 || v.start < voices[steal].start)) steal = k; }
        else if (free < 0) free = k;
      });
      var k = free >= 0 ? free : steal;
      var lim = id === "kill" ? maxConc : LIM[id][1];
      if (same >= lim || k < 0) { dropped++; return; }
      cool[id] = time + (id === "kill" ? minInt : LIM[id][0]);
      voices[k] = { id: id, left: def[1], start: time, pr: def[2] };
      played++;
    }
    var api = KB.frame(root, {
      title: "Audio.play_sfx: cooldown per id, batas per id, pool 24 voice", w: 720, h: 260,
      step: function (dt) {
        time += dt; acc += rate * dt;
        while (acc >= 1) { acc -= 1; play("kill"); if (Math.random() < 0.6) play("gem"); }
        play("hit");
        voices.forEach(function (v) { v.left = Math.max(0, v.left - dt); });
        var act = voices.filter(function (v) { return v.left > 0; }).length;
        hist.push(act); if (hist.length > 240) hist.shift();
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        voices.forEach(function (v, k) {
          var x = 14 + k * 28, on = v.left > 0, col = on ? ids.filter(function (d) { return d[0] === v.id; })[0][3] : "#2a2236";
          KB.box(g, x, 20, 24, 60, "#221b2b", C.grid2);
          if (on) KB.box(g, x + 2, 78 - 56 * Math.min(1, v.left / 1.2), 20, 56 * Math.min(1, v.left / 1.2), col);
        });
        ids.forEach(function (d, i) { KB.box(g, 14 + i * 110, 96, 10, 10, d[3]); KB.label(g, d[0], 30 + i * 110, 101, C.muted, 11); });
        g.strokeStyle = C.green; g.beginPath();
        hist.forEach(function (h, i) { var x = 14 + i * 2.8, y = 240 - h / 24 * 110; if (i === 0) g.moveTo(x, y); else g.lineTo(x, y); });
        g.stroke();
        KB.label(g, "voice aktif (maks 24)", 14, 124, C.muted, 10);
        a.text("permintaan " + req + "   diputar " + played + "   dibuang " + dropped + "   rasio diputar " + (req ? (100 * played / req).toFixed(1) : 0) + "%");
      }
    });
    api.range("kill per detik", 0, 700, 10, 300, function (v) { rate = v; });
    api.range("kill: min_interval", 0, 0.2, 0.005, 0.04, function (v) { minInt = v; }, function (v) { return v.toFixed(2) + " s"; });
    api.range("kill: max_concurrent", 1, 24, 1, 4, function (v) { maxConc = v; });
    api.button("Level up (priority 5)", function () { play("level_up"); });
    api.note("Di game terukur ~670 kill/s menghasilkan ~3500 permintaan suara, tapi hanya 168 yang benar-benar diputar, dengan puncak 5 voice. Cooldown per id dicek lebih dulu karena paling murah (O(1)), baru pencarian slot di pool.");
  };
})();
