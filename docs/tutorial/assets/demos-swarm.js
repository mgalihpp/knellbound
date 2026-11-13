// Demo Bab 1: urutan frame, kejar + separasi, spatial hash, counting sort, swap-remove,
// buffer MultiMesh, billboard vs kamera miring, aura + knockback.
(function () {
  "use strict";
  var KB = window.KB, C = KB.C, D = KB.demos;

  // ------------------------------------------------------------------ urutan frame Game._process
  D.frame = function (root) {
    var steps = [
      ["player.tick", "baca input, gerak pos2"],
      ["swarm.tick", "gerak musuh, grid, separasi"],
      ["kontak", "collide_player + enemy_shots.tick"],
      ["weapons", "w.tick(dt, self) tiap senjata"],
      ["projectiles.tick", "gerak + query_circle"],
      ["flush_dead", "emit enemy_died → gem, efek"],
      ["gems.tick", "magnet + XP"],
      ["pickups.tick", "koleksi → _on_pickup"],
      ["director.tick", "wave, event, boss"],
      ["breakables / fx", "spawner, angka, efek"],
      ["upload()", "1 multimesh_set_buffer / sistem"],
      ["kamera + HUD", "camera_rig.tick, hud.refresh"],
      ["cek antrian", "pending_levels / pending_chests"]
    ];
    var t = 0, cur = 0, speed = 1, pend = false, paused = false, hit = 0, frameNo = 0, msg = "";
    var api = KB.frame(root, {
      title: "Satu frame di Game._process", w: 720, h: 330,
      step: function (dt) {
        if (paused) return;
        if (hit > 0) { hit -= dt * speed; msg = "hit-stop: hanya kamera yang jalan"; return; }
        t += dt * speed * 3;
        if (t >= 1) {
          t = 0; cur++;
          if (cur >= steps.length) {
            cur = 0; frameNo++;
            if (pend) { paused = true; msg = "get_tree().paused = true → LevelUpScreen (process_mode ALWAYS) menunggu pilihan"; }
          }
        }
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        var cols = 5, bw = 132, bh = 54, gx = 10, gy = 26;
        for (var i = 0; i < steps.length; i++) {
          var c = i % cols, r = Math.floor(i / cols);
          var x = 14 + c * (bw + gx), y = 18 + r * (bh + gy);
          var on = i === cur && !paused && hit <= 0;
          var donePass = i < cur;
          KB.box(g, x, y, bw, bh, on ? "#4a1d2a" : donePass ? "#232a2a" : "#261f30", on ? C.red : donePass ? "#3d5a48" : C.grid2);
          KB.label(g, (i + 1) + ". " + steps[i][0], x + 8, y + 18, on ? C.gold : C.text, 12.5);
          KB.label(g, steps[i][1], x + 8, y + 38, C.muted, 10.5);
          if (i < steps.length - 1) {
            if (c < cols - 1) KB.arrow(g, x + bw + 1, y + bh / 2, x + bw + gx - 1, y + bh / 2, C.muted, 1);
          }
        }
        KB.label(g, "frame #" + frameNo + "   dt dibatasi 1/20 dtk", 14, a.H - 34, C.muted, 12);
        KB.label(g, msg, 14, a.H - 14, paused ? C.gold : hit > 0 ? C.orange : C.muted, 12);
      }
    });
    api.range("kecepatan", 0.2, 3, 0.1, 1, function (v) { speed = v; }, function (v) { return v.toFixed(1) + "×"; });
    api.button("Ambil gem (level up)", function () { pend = true; msg = "pending_levels = 1 → dibuka di akhir frame"; api.kick(); });
    api.button("Pilih kartu", function () { if (paused) { paused = false; pend = false; msg = "pending_levels = 0 → tree jalan lagi"; } }, true);
    api.button("Bom (hit-stop 0,08 dtk)", function () { hit = 0.6; api.kick(); }, true);
    api.note("Langkah yang menyala sedang berjalan. Semua sistem dipanggil dari <code>Game._process</code>, tidak ada sistem yang punya <code>_process</code> sendiri, jadi urutannya selalu sama. Level up tidak membuka layar di tengah frame: <code>pending_levels</code> dicek di langkah terakhir.");
  };

  // ------------------------------------------------------------------ musuh mengejar + separasi
  D.chase = function (root) {
    var N = 0, xs = [], ys = [], vx = [], vy = [], sp = [], face = [], r = 7;
    var p = { x: 360, y: 190, face: 1 }, time = 0, sepOn = true, showVec = false, speedMul = 1, sepStr = 1;
    var grid = new KB.Grid(16), near = [], contact = 0, relocations = 0;
    function spawn(n) {
      for (var k = 0; k < n; k++) {
        var a = Math.random() * 6.283, d = KB.rand(260, 340);
        xs.push(p.x + Math.cos(a) * d); ys.push(p.y + Math.sin(a) * d * 0.6);
        vx.push(0); vy.push(0); sp.push(KB.rand(0.9, 1.1)); face.push(1);
      }
      N = xs.length;
    }
    function setCount(n) {
      if (n > N) spawn(n - N);
      else { xs.length = ys.length = vx.length = vy.length = sp.length = face.length = n; N = n; }
    }
    var api = KB.frame(root, {
      title: "Musuh mengejar pemain (seek) + separasi", w: 720, h: 400,
      step: function (dt, a) {
        time += dt;
        KB.steer(a, p, 120, dt, time);
        var far = 420;
        contact = 0;
        for (var i = 0; i < N; i++) {
          var dx = p.x - xs[i], dy = p.y - ys[i], l2 = dx * dx + dy * dy;
          if (l2 > far * far) { var l0 = Math.sqrt(l2); xs[i] = p.x - dx / l0 * 330; ys[i] = p.y - dy / l0 * 330; relocations++; continue; }
          var v = 0, l = Math.sqrt(l2) || 1;
          var s = 55 * speedMul * sp[i];
          vx[i] = dx / l * s; vy[i] = dy / l * s;
          xs[i] += vx[i] * dt; ys[i] += vy[i] * dt;
          if (Math.abs(dx) > 1) face[i] = dx > 0 ? 1 : -1;
          if (l < r + 9) { contact++; xs[i] = p.x - dx / l * (r + 9); ys[i] = p.y - dy / l * (r + 9); }
        }
        if (sepOn) {
          grid.build(xs, ys, N);
          for (var j = 0; j < N; j++) {
            var px = 0, py = 0;
            grid.near(xs[j], ys[j], r * 2, near);
            for (var q = 0; q < near.length && q < 12; q++) {
              var o = near[q]; if (o === j) continue;
              var ex = xs[j] - xs[o], ey = ys[j] - ys[o], d2 = ex * ex + ey * ey, rr = r * 2;
              if (d2 < rr * rr) {
                if (d2 > 0.0001) { var d = Math.sqrt(d2); px += ex * (rr - d) / d; py += ey * (rr - d) / d; }
                else px += Math.random() - 0.5;
              }
            }
            var pl = KB.len(px, py) * 0.5 * sepStr, lim = 3;
            if (pl > 0) { var k = pl > lim ? lim / pl : 1; xs[j] += px * 0.5 * sepStr * k; ys[j] += py * 0.5 * sepStr * k; }
          }
        }
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        g.strokeStyle = C.grid; g.lineWidth = 1;
        for (var x = 0; x < a.W; x += 40) { g.beginPath(); g.moveTo(x, 0); g.lineTo(x, a.H); g.stroke(); }
        for (var y = 0; y < a.H; y += 40) { g.beginPath(); g.moveTo(0, y); g.lineTo(a.W, y); g.stroke(); }
        var order = [];
        for (var i = 0; i < N; i++) order.push(i);
        order.push(-1);
        order.sort(function (i, j) { return (i < 0 ? p.y : ys[i]) - (j < 0 ? p.y : ys[j]); });
        order.forEach(function (i) {
          if (i < 0) { g.globalAlpha = .45; KB.dot(g, p.x, p.y, 9, "#000"); g.globalAlpha = 1; KB.sprite(g, "hunter", p.x, p.y + 2, 2.6, p.face < 0); return; }
          g.globalAlpha = .35; KB.dot(g, xs[i], ys[i], 6, "#000"); g.globalAlpha = 1;
          KB.sprite(g, "ghoul", xs[i], ys[i] + 2, 2, face[i] < 0);
          if (showVec) KB.arrow(g, xs[i], ys[i] - 8, xs[i] + vx[i] * .35, ys[i] - 8 + vy[i] * .35, C.gold, 1);
        });
        a.text("musuh " + N + "   menyentuh pemain " + contact + "   relokasi " + relocations + "   separasi " + (sepOn ? "aktif" : "mati"));
      }
    });
    api.range("jumlah musuh", 0, 400, 10, 80, setCount);
    api.range("kecepatan", 0.3, 2, 0.1, 1, function (v) { speedMul = v; }, function (v) { return v.toFixed(1) + "×"; });
    api.range("kekuatan separasi", 0, 2, 0.1, 1, function (v) { sepStr = v; }, function (v) { return v.toFixed(1); });
    api.check("separasi", true, function (v) { sepOn = v; });
    api.check("vektor kecepatan", false, function (v) { showVec = v; });
    api.note("Klik kanvas lalu gerakkan pemain dengan <kbd>WASD</kbd>/panah, atau tahan klik untuk berjalan ke kursor. Tanpa input, pemain berjalan memutar. Matikan separasi dan semua musuh menumpuk jadi satu titik, karena tiap musuh hanya tahu arah ke pemain (<code>v = d * (speed / |d|)</code>).");
  };

  // ------------------------------------------------------------------ spatial hash + query
  D.hash = function (root) {
    var N = 140, xs = [], ys = [], dx = [], dy = [], cell = 48, bits = 4, R = 60, showBucket = true;
    for (var i = 0; i < 400; i++) { xs.push(KB.rand(10, 710)); ys.push(KB.rand(10, 370)); dx.push(KB.rand(-12, 12)); dy.push(KB.rand(-12, 12)); }
    var PX = 73856093, PY = 19349663;
    function bucket(cx, cy) { return (Math.imul(cx, PX) ^ Math.imul(cy, PY)) & ((1 << bits) - 1); }
    var api = KB.frame(root, {
      title: "SpatialHash: sel, bucket, dan query_circle", w: 720, h: 380,
      step: function (dt) {
        for (var i = 0; i < N; i++) {
          xs[i] += dx[i] * dt; ys[i] += dy[i] * dt;
          if (xs[i] < 5 || xs[i] > 715) dx[i] = -dx[i];
          if (ys[i] < 5 || ys[i] > 375) dy[i] = -dy[i];
        }
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        var qx = a.mouse.inside ? a.mouse.x : 360, qy = a.mouse.inside ? a.mouse.y : 190;
        var x0 = Math.floor((qx - R) / cell), x1 = Math.floor((qx + R) / cell);
        var y0 = Math.floor((qy - R) / cell), y1 = Math.floor((qy + R) / cell);
        var want = {};
        for (var cy = y0; cy <= y1; cy++) for (var cx = x0; cx <= x1; cx++) want[bucket(cx, cy)] = true;
        var colsN = Math.ceil(a.W / cell), rowsN = Math.ceil(a.H / cell);
        for (var cy2 = 0; cy2 < rowsN; cy2++) for (var cx2 = 0; cx2 < colsN; cx2++) {
          var b = bucket(cx2, cy2);
          var inRect = cx2 >= x0 && cx2 <= x1 && cy2 >= y0 && cy2 <= y1;
          var shared = !inRect && want[b];
          g.fillStyle = inRect ? "rgba(91,210,255,.18)" : shared && showBucket ? "rgba(232,184,74,.13)" : "transparent";
          g.fillRect(cx2 * cell, cy2 * cell, cell, cell);
          g.strokeStyle = C.grid; g.strokeRect(cx2 * cell + .5, cy2 * cell + .5, cell, cell);
          if (showBucket) KB.label(g, String(b), cx2 * cell + 4, cy2 * cell + 9, shared ? C.gold : "#4a405a", 9);
        }
        var cand = 0, hits = 0;
        for (var i = 0; i < N; i++) {
          var b2 = bucket(Math.floor(xs[i] / cell), Math.floor(ys[i] / cell));
          var isCand = want[b2];
          var inC = isCand && (xs[i] - qx) * (xs[i] - qx) + (ys[i] - qy) * (ys[i] - qy) <= R * R;
          if (isCand) cand++; if (inC) hits++;
          KB.dot(g, xs[i], ys[i], inC ? 5 : 3.5, inC ? C.red : isCand ? C.gold : C.enemy);
        }
        KB.ring(g, qx, qy, R, C.player, 2);
        a.text("query_circle r=" + R + "   sel " + (x1 - x0 + 1) + "×" + (y1 - y0 + 1) + "   kandidat dicek " + cand + "   kena " + hits +
          "   (tanpa grid: " + N + " cek)   tabel bucket = 2^" + bits + " = " + (1 << bits));
      }
    });
    api.range("jumlah titik", 20, 400, 10, 140, function (v) { N = v; });
    api.range("ukuran sel", 24, 120, 4, 48, function (v) { cell = v; });
    api.range("radius query", 10, 160, 5, 60, function (v) { R = v; });
    api.range("BITS tabel", 2, 8, 1, 4, function (v) { bits = v; }, function (v) { return "2^" + v; });
    api.check("tampilkan bucket", true, function (v) { showBucket = v; });
    api.note("Gerakkan kursor di kanvas. Sel biru = sel yang disentuh lingkaran query. Sel <b style=\"color:var(--gold)\">emas</b> = sel lain yang kebetulan jatuh ke bucket yang sama (tabrakan hash), jadi titik di sana ikut jadi kandidat. Karena itu <code>query_circle</code> tetap menghitung jarak. Di game, <code>BITS = 12</code> (4096 bucket), jadi tabrakan jarang.");
  };

  // ------------------------------------------------------------------ counting sort (SpatialHash.build)
  D.countsort = function (root) {
    var SIZE = 6, items, stage, k, counts, starts, cursor, out, msg;
    function reset() {
      items = []; for (var i = 0; i < 9; i++) items.push(Math.floor(Math.random() * SIZE));
      stage = 0; k = 0; counts = new Array(SIZE + 1).fill(0); starts = null; cursor = null; out = new Array(items.length).fill(-1);
      msg = "Tiap musuh i sudah punya bucket h (dari posisinya). Tekan Langkah.";
    }
    function step() {
      if (stage === 0) { // hitung
        var h = items[k]; counts[h + 1]++; msg = "Hitung: musuh " + k + " ada di bucket " + h + " → cell_start[" + (h + 1) + "] += 1";
        if (++k >= items.length) { stage = 1; k = 1; }
      } else if (stage === 1) { // prefix sum
        counts[k] += counts[k - 1]; msg = "Prefix sum: cell_start[" + k + "] += cell_start[" + (k - 1) + "] = " + counts[k];
        if (++k > SIZE) { stage = 2; k = 0; cursor = counts.slice(0, SIZE); msg += ". Sekarang cell_start[h] = indeks awal bucket h."; }
      } else if (stage === 2) { // taruh
        var h2 = items[k]; out[cursor[h2]] = k;
        msg = "Taruh: musuh " + k + " (bucket " + h2 + ") → items[" + cursor[h2] + "], cursor[" + h2 + "]++"; cursor[h2]++;
        if (++k >= items.length) { stage = 3; msg = "Selesai. Isi bucket h = items[cell_start[h] .. cell_start[h+1]). Tanpa Array per sel, tanpa alokasi."; }
      }
      api.redraw();
    }
    reset();
    var api = KB.frame(root, {
      title: "Counting sort di SpatialHash.build()", w: 720, h: 300, noLoop: true,
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        var cw = 50;
        KB.label(g, "_bucket[i]", 14, 30, C.muted, 12);
        for (var i = 0; i < items.length; i++) {
          var hot = (stage === 0 || stage === 2) && i === k;
          KB.box(g, 130 + i * (cw + 6), 12, cw, 36, hot ? "#4a1d2a" : "#261f30", hot ? C.red : C.grid2);
          KB.label(g, "i" + i, 130 + i * (cw + 6) + 6, 22, C.muted, 10);
          KB.label(g, "h=" + items[i], 130 + i * (cw + 6) + 6, 38, C.text, 12);
        }
        KB.label(g, "cell_start", 14, 110, C.muted, 12);
        for (var h = 0; h <= SIZE; h++) {
          var hot2 = stage === 1 && h === k;
          KB.box(g, 130 + h * (cw + 6), 92, cw, 36, hot2 ? "#1d3a4a" : "#261f30", hot2 ? C.player : C.grid2);
          KB.label(g, "[" + h + "]", 130 + h * (cw + 6) + 6, 102, C.muted, 10);
          KB.label(g, String(counts[h]), 130 + h * (cw + 6) + 6, 118, C.text, 13);
        }
        KB.label(g, "items", 14, 190, C.muted, 12);
        for (var s = 0; s < out.length; s++) {
          var who = out[s];
          var col = who >= 0 ? "hsl(" + (items[who] * 60) + " 45% 30%)" : "#261f30";
          KB.box(g, 130 + s * (cw + 6), 172, cw, 36, col, C.grid2);
          KB.label(g, "[" + s + "]", 130 + s * (cw + 6) + 6, 182, C.muted, 10);
          if (who >= 0) KB.label(g, "i" + who, 130 + s * (cw + 6) + 6, 198, C.text, 13);
        }
        KB.label(g, msg, 14, 250, C.gold, 12);
        KB.label(g, "SIZE = " + SIZE + " (di game 4096)", 14, 276, C.muted, 11);
      }
    });
    api.button("Langkah", step);
    api.button("Selesaikan", function () { while (stage < 3) step(); }, true);
    api.button("Acak ulang", function () { reset(); api.redraw(); }, true);
  };

  // ------------------------------------------------------------------ swap-remove
  D.swap = function (root) {
    var slots, count, nextUid, anim = null, log = "Klik slot hidup untuk membunuh musuh di slot itu.";
    function reset() { slots = []; for (var i = 0; i < 12; i++) slots.push({ uid: i + 1, hue: (i * 37) % 360 }); count = 10; nextUid = 13; }
    reset();
    function removeAt(i) {
      var last = count - 1;
      if (i !== last) { anim = { from: last, to: i, t: 0 }; slots[i] = Object.assign({}, slots[last]); log = "_remove_at(" + i + "): slot " + last + " (uid " + slots[last].uid + ") disalin ke slot " + i + ", count = " + last; }
      else log = "_remove_at(" + i + "): sudah slot terakhir, cukup count -= 1";
      count = last;
    }
    var api = KB.frame(root, {
      title: "Hapus dengan swap-with-last", w: 720, h: 220,
      onDown: function (x, y) {
        var i = Math.floor((x - 14) / 57);
        if (y > 60 && y < 120 && i >= 0 && i < count) removeAt(i);
      },
      step: function (dt) { if (anim) { anim.t += dt * 2; if (anim.t >= 1) anim = null; } },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        KB.label(g, "count = " + count + "   (slot 0..count-1 hidup, sisanya sampah lama yang diabaikan)", 14, 30, C.text, 12);
        for (var i = 0; i < slots.length; i++) {
          var alive = i < count, s = slots[i], x = 14 + i * 57;
          KB.box(g, x, 64, 51, 52, alive ? "hsl(" + s.hue + " 40% 26%)" : "#1f1a27", alive ? C.grid2 : "#2a2433");
          KB.label(g, "slot " + i, x + 5, 76, alive ? C.muted : "#4a405a", 10);
          KB.label(g, "uid " + s.uid, x + 5, 98, alive ? C.text : "#4a405a", 12);
        }
        if (anim) {
          var fx = 14 + anim.from * 57 + 25, tx = 14 + anim.to * 57 + 25, e = anim.t, mx = fx + (tx - fx) * e;
          g.strokeStyle = C.gold; g.lineWidth = 2; g.beginPath(); g.moveTo(fx, 128); g.quadraticCurveTo((fx + tx) / 2, 170, tx, 128); g.stroke();
          KB.dot(g, mx, 128 + Math.sin(e * Math.PI) * 30, 5, C.gold);
        }
        KB.label(g, log, 14, 190, C.gold, 12);
      }
    });
    api.button("Spawn (count += 1)", function () {
      if (count < slots.length) { slots[count] = { uid: nextUid++, hue: (nextUid * 37) % 360 }; log = "spawn(): tulis ke slot " + count + ", count = " + (count + 1); count++; }
    });
    api.button("flush_dead: bunuh 3 acak", function () {
      var dead = [];
      while (dead.length < Math.min(3, count)) { var r = Math.floor(Math.random() * count); if (dead.indexOf(r) < 0) dead.push(r); }
      dead.sort(function (x, y) { return x - y; });
      var txt = "_dead = [" + dead.join(", ") + "] diurutkan, dihapus dari belakang: ";
      for (var k = dead.length - 1; k >= 0; k--) removeAt(dead[k]);
      log = txt + "slot terbesar dulu, supaya indeks yang belum diproses tidak bergeser.";
    }, true);
    api.button("Reset", function () { reset(); log = "Reset."; }, true);
    api.note("Urutan musuh di array tidak penting, jadi menghapus cukup O(1): salin elemen terakhir ke lubang. Akibatnya indeks slot <b>tidak stabil</b>; itu sebabnya ada <code>uid</code> (dipakai hit memory proyektil dan BossBrain).");
  };

  // ------------------------------------------------------------------ buffer MultiMesh 16 float
  D.buffer = function (root) {
    var st = { x: 2.5, z: -1.0, size: 1.125, phase: 0, facing: 1, tint: 0, flash: 0, row: 0 };
    var time = 0;
    var api = KB.frame(root, {
      title: "Satu instance = 16 float di buffer MultiMesh", w: 720, h: 300,
      step: function (dt) { time += dt; },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        var cy = st.facing * (1 + st.tint);
        var buf = [st.size, 0, 0, st.x, 0, st.size, 0, 0, 0, 0, st.size, st.z, st.phase, cy, st.flash, st.row];
        var names = ["Xx", "Xy", "Xz", "origin.x", "Yx", "Yy", "Yz", "origin.y", "Zx", "Zy", "Zz", "origin.z", "CUSTOM.x", "CUSTOM.y", "CUSTOM.z", "CUSTOM.w"];
        var bw = 42;
        for (var i = 0; i < 16; i++) {
          var x = 14 + i * bw, isCustom = i >= 12, isPos = i === 3 || i === 11, isSize = i === 0 || i === 5 || i === 10;
          KB.box(g, x, 18, bw - 3, 50, isCustom ? "#3b2a12" : isPos ? "#123044" : isSize ? "#1f3324" : "#231d2b", C.grid2);
          KB.label(g, "[" + i + "]", x + 4, 28, C.muted, 9);
          KB.label(g, (+buf[i]).toFixed(2), x + 4, 50, buf[i] ? C.text : "#4f4560", 10);
        }
        KB.label(g, "baris 3x4 transform (skala + posisi)", 14, 84, C.player, 11);
        KB.label(g, "INSTANCE_CUSTOM", 14 + 12 * bw, 84, C.gold, 11);
        // pratinjau dunia (x,z) dan sprite
        var ox = 180, oy = 200, s = 24;
        g.strokeStyle = C.grid; for (var gx = -6; gx <= 6; gx++) { g.beginPath(); g.moveTo(ox + gx * s, oy - 80); g.lineTo(ox + gx * s, oy + 80); g.stroke(); }
        for (var gz = -3; gz <= 3; gz++) { g.beginPath(); g.moveTo(ox - 150, oy + gz * s); g.lineTo(ox + 150, oy + gz * s); g.stroke(); }
        KB.label(g, "bidang gameplay (x, z)", ox - 150, oy - 92, C.muted, 11);
        var sx = ox + st.x * s, sz = oy + st.z * s;
        KB.dot(g, sx, sz, 4, C.player);
        var frame = Math.floor((time * 8 + st.phase) % 4);
        // sprite: pakai baris = 0 ghoul / 1 kelelawar-warna
        var px = 3 * st.size / 1.125;
        KB.sprite(g, "ghoul", 520, 250, px * 3, st.facing < 0, st.flash, st.tint);
        KB.label(g, "frame = floor(TIME*fps + CUSTOM.x) % 4 = " + frame, 380, 120, C.muted, 11);
        KB.label(g, "CUSTOM.y < 0 → uv.x dibalik (hadap kiri)", 380, 138, C.muted, 11);
        KB.label(g, "|CUSTOM.y| - 1 = tint elite " + st.tint.toFixed(2), 380, 156, C.muted, 11);
        KB.label(g, "CUSTOM.z = hit flash (mix ke putih)", 380, 174, C.muted, 11);
        a.text("RenderingServer.multimesh_set_buffer(rid, _buf)   # _buf.size() = capacity * 16");
      }
    });
    api.range("x", -6, 6, 0.1, 2.5, function (v) { st.x = v; api.redraw(); });
    api.range("z", -3, 3, 0.1, -1, function (v) { st.z = v; api.redraw(); });
    api.range("size", 0.5, 2.5, 0.05, 1.125, function (v) { st.size = v; api.redraw(); }, function (v) { return v.toFixed(2); });
    api.range("phase", 0, 3, 1, 0, function (v) { st.phase = v; api.redraw(); });
    api.select("facing", [["1", "+1 kanan"], ["-1", "-1 kiri"]], "1", function (v) { st.facing = +v; api.redraw(); });
    api.range("tint elite", 0, 1, 0.05, 0, function (v) { st.tint = v; api.redraw(); }, function (v) { return v.toFixed(2); });
    api.range("flash", 0, 1, 0.05, 0, function (v) { st.flash = v; api.redraw(); }, function (v) { return v.toFixed(2); });
  };

  // ------------------------------------------------------------------ billboard vs kamera miring
  D.billboard = function (root) {
    var pitch = 50, mode = "auto";
    var api = KB.frame(root, {
      title: "Kenapa sprite ditarik ke atas (y_stretch)", w: 720, h: 340, noLoop: true,
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        var p = pitch * Math.PI / 180, ys = mode === "auto" ? 1 / Math.cos(p) : mode === "fixed" ? 1.55 : 1;
        // tampak samping
        var gx = 40, gy = 270, H0 = 70;
        KB.label(g, "TAMPAK SAMPING", gx, 22, C.muted, 11);
        g.strokeStyle = "#5a7a4a"; g.lineWidth = 2; g.beginPath(); g.moveTo(gx, gy); g.lineTo(gx + 300, gy); g.stroke();
        var sx = gx + 140, h = H0 * ys;
        KB.box(g, sx - 3, gy - h, 6, h, "#7fae5a");
        KB.label(g, "quad tegak, tinggi " + ys.toFixed(2), sx + 10, gy - h + 8, C.text, 11);
        // sinar kamera ortho sejajar
        var dx = Math.cos(p), dy = -Math.sin(p);
        for (var k = 0; k < 2; k++) {
          var ox = sx, oy = k === 0 ? gy : gy - h;
          g.strokeStyle = "rgba(91,210,255,.55)"; g.setLineDash([4, 4]); g.beginPath(); g.moveTo(ox, oy); g.lineTo(ox + dx * 260, oy + dy * 260); g.stroke(); g.setLineDash([]);
        }
        var camx = sx + dx * 230, camy = gy + dy * 230;
        KB.dot(g, camx, camy, 6, C.player);
        KB.label(g, "kamera (pitch " + pitch + "°)", camx - 40, camy - 14, C.player, 11);
        // lantai sepanjang 1 unit ke arah kamera
        KB.box(g, sx - 70, gy - 2, 70, 4, C.gold);
        KB.label(g, "1 unit lantai", sx - 76, gy + 16, C.gold, 11);
        // tampilan layar
        var vx = 430, vy = 60;
        KB.label(g, "DI LAYAR", vx, 22, C.muted, 11);
        var screenH = H0 * ys * Math.cos(p), floorH = 70 * Math.sin(p);
        KB.box(g, vx, vy, 250, 230, "#241d2e", C.grid2);
        var bx = vx + 70, by = vy + 190;
        KB.box(g, bx - 35, by - screenH, 70, screenH, "rgba(127,174,90,.35)", "#7fae5a");
        KB.sprite(g, "ghoul", bx, by, Math.max(1, screenH / 8), false);
        KB.box(g, vx + 160, by - floorH, 60, floorH, "rgba(232,184,74,.25)", C.gold);
        KB.label(g, "sprite: " + (screenH / H0).toFixed(2), bx - 34, vy + 210, C.text, 11);
        KB.label(g, "lantai: " + (floorH / 70).toFixed(2), vx + 152, vy + 210, C.gold, 11);
        var ok = Math.abs(screenH / H0 - 1) < 0.03;
        a.text("tinggi di layar = tinggi quad × cos(pitch) = " + ys.toFixed(3) + " × " + Math.cos(p).toFixed(3) + " = " + (ys * Math.cos(p)).toFixed(3) +
          (ok ? "   → piksel sprite tetap persegi" : "   → sprite gepeng/molor"));
      }
    });
    api.range("pitch kamera", 20, 80, 1, 50, function (v) { pitch = v; api.redraw(); }, function (v) { return v + "°"; });
    api.select("y_stretch", [["auto", "1/cos(pitch)"], ["fixed", "1.55 (nilai di game)"], ["off", "1.0 (tanpa)"]], "auto", function (v) { mode = v; api.redraw(); });
    api.note("Kamera orthographic menunduk 50°. Quad yang berdiri tegak terlihat lebih pendek (dikali cos 50° ≈ 0,643), lantai juga terlihat lebih pendek (dikali sin 50° ≈ 0,766). Shader <code>sprite_billboard</code> mengalikan <code>VERTEX.y</code> dengan <code>y_stretch = 1.55 ≈ 1/cos 50°</code> supaya satu piksel art tetap persegi di layar.");
  };

  // ------------------------------------------------------------------ aura + knockback
  D.aura = function (root) {
    var N = 0, en = [], p = { x: 360, y: 200, face: 1, auto: false }, R = 70, cd = 0.6, timer = 0, dmg = 6, kb = 220, decay = 9, maxKnock = 260, resist = 0;
    var nums = [], pulse = 0, time = 0, kills = 0;
    function spawn() {
      var a = Math.random() * 6.283;
      en.push({ x: p.x + Math.cos(a) * 330, y: p.y + Math.sin(a) * 210, kx: 0, ky: 0, hp: 20, flash: 0, f: 1 });
    }
    var api = KB.frame(root, {
      title: "Holy Aura: damage per tick + knockback", w: 720, h: 400,
      step: function (dt, a) {
        time += dt;
        KB.steer(a, p, 90, dt, time);
        while (en.length < N) spawn();
        var d = Math.exp(-decay * dt);
        en.forEach(function (e) {
          var dx = p.x - e.x, dy = p.y - e.y, l = KB.len(dx, dy) || 1;
          e.x += (dx / l * 40 + e.kx) * dt; e.y += (dy / l * 40 + e.ky) * dt;
          e.kx *= d; e.ky *= d; e.flash = Math.max(0, e.flash - dt * 8); e.f = dx > 0 ? 1 : -1;
        });
        pulse = Math.max(0, pulse - dt * 4);
        timer -= dt;
        if (timer <= 0) {
          timer += cd;
          var any = false;
          en.forEach(function (e) {
            var dx = e.x - p.x, dy = e.y - p.y, l = KB.len(dx, dy);
            if (l <= R + 6) {
              any = true; e.hp -= dmg; e.flash = 1;
              var nx = dx / (l || 1), ny = dy / (l || 1);
              e.kx += nx * kb * (1 - resist); e.ky += ny * kb * (1 - resist);
              var kl = KB.len(e.kx, e.ky); if (kl > maxKnock) { e.kx *= maxKnock / kl; e.ky *= maxKnock / kl; }
              nums.push({ x: e.x, y: e.y - 18, v: dmg, t: 0 });
            }
          });
          if (any) pulse = 1;
        }
        for (var i = en.length - 1; i >= 0; i--) if (en[i].hp <= 0) { en.splice(i, 1); kills++; }
        nums.forEach(function (n) { n.t += dt; n.y -= 30 * dt; });
        nums = nums.filter(function (n) { return n.t < 0.7; });
      },
      draw: function (a) {
        var g = a.g; KB.clear(g, a.W, a.H);
        g.fillStyle = "rgba(91,210,255," + (0.12 + pulse * 0.2) + ")"; g.beginPath(); g.ellipse(p.x, p.y, R, R * 0.766, 0, 0, 6.283); g.fill();
        g.strokeStyle = C.player; g.lineWidth = 2; g.beginPath(); g.ellipse(p.x, p.y, R, R * 0.766, 0, 0, 6.283); g.stroke();
        en.slice().sort(function (u, v) { return u.y - v.y; }).forEach(function (e) {
          KB.sprite(g, "ghoul", e.x, e.y, 2, e.f < 0, e.flash);
          var kl = KB.len(e.kx, e.ky);
          if (kl > 5) KB.arrow(g, e.x, e.y - 6, e.x + e.kx * .12, e.y - 6 + e.ky * .12, C.orange, 1.2);
        });
        KB.sprite(g, "hunter", p.x, p.y + 2, 2.6, false);
        nums.forEach(function (n) { g.globalAlpha = 1 - n.t / 0.7; KB.label(g, String(n.v), n.x, n.y, "#fff", 12, "center"); g.globalAlpha = 1; });
        // timer bar
        KB.box(g, 14, a.H - 22, 160, 8, "#2a2236");
        KB.box(g, 14, a.H - 22, 160 * (1 - Math.max(0, timer) / cd), 8, C.player);
        KB.label(g, "_timer → cooldown()", 182, a.H - 18, C.muted, 11);
        a.text("musuh " + en.length + "   kill " + kills + "   knock *= exp(-" + decay + "·dt) per frame   |knock| ≤ " + maxKnock);
      }
    });
    api.range("musuh", 0, 60, 1, 24, function (v) { N = v; if (en.length > v) en.length = v; });
    api.range("radius (area)", 30, 140, 2, 70, function (v) { R = v; });
    api.range("cooldown", 0.15, 1.5, 0.05, 0.6, function (v) { cd = v; }, function (v) { return v.toFixed(2) + " s"; });
    api.range("knockback", 0, 500, 10, 220, function (v) { kb = v; });
    api.range("knock_decay", 1, 20, 0.5, 9, function (v) { decay = v; });
    api.range("kb_resist", 0, 1, 0.05, 0, function (v) { resist = v; }, function (v) { return v.toFixed(2); });
    api.note("Aura tidak mengecek tabrakan tiap frame. Ia menunggu <code>_timer</code> habis, lalu satu <code>query_circle</code> mengambil semua musuh di radius, memberi damage, dan mendorong keluar. Dorongan disimpan di array <code>knock</code> dan meluruh secara eksponensial, jadi tidak tergantung FPS. Klik kanvas dan pakai <kbd>WASD</kbd> untuk menggerakkan pemain.");
  };
})();
