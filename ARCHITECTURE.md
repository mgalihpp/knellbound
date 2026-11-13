# Arsitektur (rujukan untuk semua fase)

## Aturan inti
- Gameplay di bidang 2D `Vector2(x, z)`. Node 3D hanya untuk tampilan.
- Objek massal (musuh, proyektil, gem, angka damage) = packed array paralel
  + MultiMesh, satu `RenderingServer.multimesh_set_buffer` per frame.
- Urutan update hanya ada di `core/game.gd::_process`. Sistem tidak punya
  `_process` sendiri; mereka punya `tick(dt, ...)`.
- Collision = `SpatialHash` (rebuild tiap frame, counting sort).
- Data konten = Resource `.tres` di `data/`.
- Sprite: 16 px = 1 unit dunia, cell sheet 18x18 (16 + outline),
  `y_stretch` 1.55 ≈ 1/cos(pitch kamera 50°).

## Folder
```
art/        sprites/ tiles/ icons/ ui/  (digenerate oleh tools/gen_sprites.py)
audio/      sound_def.gd, sound_bank.gd; sfx/*.wav, bgm/*.wav (digenerate tools/gen_audio.py)
autoload/   save_data.gd (SaveData), audio.gd (Audio), settings.gd (Settings),
            scene_fader.gd (SceneFader); urutan di project.godot penting
characters/ character_data.gd
core/       game.gd, spatial_hash.gd, camera_rig.gd, stats.gd, stat_modifier.gd,
            leveling.gd, upgrade_offer.gd, upgrade_pool.gd
data/       characters/ enemies/ weapons/ passives/ evolutions/ waves/
            pickups/ drops/ breakables/ meta_upgrades/ upgrade_pool.tres
            meta.tres (MetaCatalog) sound_bank.tres (SoundBank)
enemies/    enemy_data.gd, boss_data.gd, enemy_swarm.gd, enemy_shot_field.gd,
            spawn_director.gd, boss_brain.gd, wave_table.gd, wave_entry.gd,
            wave_event.gd
meta/       meta_upgrade.gd, meta_catalog.gd, run_reward.gd
fx/         damage_number_field.gd, effect_field.gd (MultiMesh)
pickups/    gem_field.gd, pickup_field.gd, pickup_data.gd, drop_table.gd
passives/   passive_data.gd, evolution_data.gd
player/     player.gd, player.tscn
scenes/     title.tscn (main scene), character_select.tscn, shop.tscn, main.tscn (run)
shaders/    sprite_billboard, blob_shadow, aura, projectile, ground_decal,
            damage_number, world_bar
tools/      gen_sprites.py, gen_audio.py (.gdignore)
ui/         theme/game_theme.tres, hud, level_up_screen, chest_screen,
            pause_menu, options_panel, game_over_screen, title_screen.gd
            (.gd/.tscn), offer_view.gd, level_pips.gd, world_hp_bar.gd,
            shop_screen.gd, character_select.gd
weapons/    weapon_data.gd, weapon_level.gd, weapon.gd, projectile_field.gd,
            aura/ knives/ orbit/ vial/ cross/  (<senjata>_weapon.tscn+.gd,
            + .tscn varian evolusi yang memakai skrip yang sama)
world/      decor_field.gd, breakable_data.gd, breakable_spawner.gd
```

## INSTANCE_CUSTOM (sprite_billboard.gdshader)
x = phase animasi (atau index frame jika fps = 0), y = facing × (1 + tint)
(tanda = arah hadap ±1, |y| − 1 = tint elite 0..1: piksel outline
`OUTLINE` dari gen_sprites menyala merah + badan sedikit kemerahan; selain
EnemySwarm cukup kirim ±1), z = hit flash 0..1, w = baris sheet.

Sheet musuh: `art/sprites/enemies.png` (cell 18, vframes 11, baris 7-10 = objek pecahan): 0 ghoul,
1 kelelawar, 2 skeleton, 3 slime (belum dipakai), 4 Crypt Acolyte,
5 Grave Wisp, 6 Cinder Skull. `art/sprites/enemies_large.png` (cell 34 =
32 + outline, `EnemyData.large_sprite`): 0 Gravebound Brute, 1 Hollow Abbot,
2 Vesperine, 3 Knellwraith. Proyektil musuh `art/sprites/enemy_shots.png`
(shader proyektil, vframes 3): 0 orb darah, 1 serpihan tulang (berputar,
`EnemyShotField.spin_rows`), 2 bintang duri.

Proyektil (`shaders/projectile.gdshader`, quad di-center, melayang di
`ProjectileField.height`): x = phase animasi, y = sudut layar (radian, CCW,
art menghadap kanan), z = brightness (>1 = glow), w = baris sheet.
Sheet `art/sprites/projectiles.png` (vframes 8): baris 0 pisau, 1 bead,
2 salib, 3 vial, 4 duri (Thornstorm), 5 manik garnet (Eternal Rosary),
6 salib emas (Radiant Crucifix), 7 vial emas (Font of Saints)
(= `sprite_row` di skrip senjata / .tscn evolusi).

Decal tanah (`shaders/ground_decal.gdshader`, PlaneMesh rebah): x = phase,
y = opacity, z = brightness, w = baris. Dipakai kolam air suci
(`art/sprites/holy_water.png`, 48 px, 4 frame) dan Font of Saints
(`art/sprites/saints_font.png`).

Gem sheet `art/sprites/gems.png`: baris = tier (biru, hijau, merah, ungu),
kolom = frame kilau. Tier dipilih dari `GemField.tier_min_value`.

Pickup sheet `art/sprites/pickups.png` (vframes 7): baris =
`PickupData.sprite_row`: 0 peti, 1 Communion Bread, 2 Roast Fowl,
3 Lodestone Magnet, 4 Blessed Bomb, 5 koin (4 frame berputar), 6 Coin Pouch;
kolom = frame kilau. Kilau putih tambahan lewat INSTANCE_CUSTOM.z (flash)
berkala di `PickupField.upload()`.

Objek pecahan = baris 7-10 di `enemies.png`: 7 Iron Lantern, 8 Brazier,
9 Supply Crate, 10 Grave Cross (frame hancur = baris debris di effects.png).

Efek sekali main (`EffectField`, `art/sprites/effects.png`, 6 frame,
vframes 10, shader sprite_billboard dengan `fps = 0`): x = index frame
(umur / life x 6), y = flip acak ±1, z = 0, w = baris. Baris
(`EffectField.Fx` = `EnemyData.death_effect` = `PickupData.collect_effect`):
0 asap, 1 darah, 2 ektoplasma, 3 ledakan, 4 kilau emas, 5 heal, 6 serpihan
kayu, 7 besi + bara, 8 batu, 9 tulang.

Angka damage (`DamageNumberField`, `shaders/damage_number.gdshader`, strip
digit `art/sprites/damage_digits.png` 10 sel 7x9): SATU instance per angka,
digit dipilih di fragment shader. Skala transform x = jumlah digit x lebar
sel, y = tinggi sel. INSTANCE_CUSTOM: x = nilai (bulat), y = alpha,
z = jenis (0 normal putih, 1 crit kuning glow, 2 heal hijau, 3 player kena
hit merah), w = jumlah digit. Tanpa depth test (selalu di atas dunia).

## Urutan frame
player → swarm.tick (gerak per perilaku, penembak menembak ke
EnemyShotField, grid + separasi) → kontak player (maks dari kontak musuh
dan `enemy_shots.tick`) → senjata (spawn proyektil / hit langsung) →
projectiles.tick (gerak + hit via `query_circle` + buang yang habis) →
(crit ke boss → hit-stop) → flush_dead (emit `enemy_died(pos, data, flags)` →
gems.drop + efek kill + roll `enemy_drops`; ELITE/BOSS → peti; PROP →
debris + roll `BreakableData.drops`) → gems.tick (magnet + koleksi → XP) →
pickups.tick (tarik koin magnetik + koleksi → `Game._on_pickup(data, pos)`)
→ director.tick (BossBrain, final phase, event, entry) → breakables.tick →
numbers.tick, effects.tick → upload GPU (swarm, gems, pickups, projectiles,
enemy_shots, effects, numbers) →
kamera/ground/decor → HUD → buka layar level up bila `pending_levels > 0`,
kalau tidak layar peti bila `pending_chests > 0` (level dulu, satu layar per
frame). BossBrain menulis kecepatan boss di director.tick, dipakai
swarm.tick frame berikutnya (latensi 1 frame, slot dicari ulang lewat uid).
Hit-stop (`Game.hit_stop(detik)`): selama aktif `_process` hanya menjalankan
kamera (shake jalan terus), simulasi berhenti. Dipakai bom, boss mati, crit
ke boss (cooldown).

## Musuh
- Semua musuh (termasuk elite, boss, Knellwraith) = slot EnemySwarm. Tidak
  ada node per musuh. Field per slot: `behavior`, `flags`
  (ELITE/BOSS/SILENT/LARGE), `dir`, `timer`. Parameter perilaku per tipe
  di array `_t_*` (diisi saat tipe pertama kali di-spawn).
- `EnemyData.Behavior` (int di .tres, tambah di akhir): CHASE, WEAVE (sinus
  menyamping), RANGED (jaga `preferred_range`, strafe, tembak), DRIFT (arah
  tetap dari spawner, hilang tanpa drop saat `timer` habis = SILENT),
  SCRIPTED (kecepatan = `dir`, ditulis BossBrain). Loop mengandalkan urutan
  CHASE/WEAVE/RANGED = 0..2 (`b <= RANGED` → kejar player + relokasi).
- Separasi berbobot radius: musuh besar menggeser yang kecil.
- `EnemyShotField`: proyektil musuh, packed array + 1 MultiMesh, hanya cek
  lingkaran player (tanpa spatial hash, tanpa hit memory).
- Elite = `spawn(..., ELITE, scale_mult = WaveTable.elite_scale)`, HP ×
  `elite_hp_mult`, XP × `elite_xp_mult`, tint lewat INSTANCE_CUSTOM.y,
  kb resist ≥ 0.85, kontak ×1.5. Elite & boss selalu menjatuhkan peti
  (`chest_every_kills` = 0).
- Boss = `BossData` (extends EnemyData, behavior SCRIPTED) + `BossBrain`
  (RefCounted milik SpawnDirector, cari slot via `swarm.slot_of(uid)`).
  Pola: CHASE → TELEGRAPH (diam, berkedip) → serangan dari `pattern`
  (DASH / RADIAL / SUMMON) → CHASE. Hit flash boss dibatasi 0.3.
  HUD `%BossPanel` menampilkan `director.active_boss()`.

## Wave (`data/waves/night.tres`)
- `WaveTable.entries: Array[WaveEntry]` = aliran spawn kontinu
  [start_minute, end_minute), boleh tumpang tindih, akumulator sendiri,
  `rate_start → rate_end` linear, pool berbobot, berhenti saat
  `swarm.count >= max_alive`. Spawn = cluster di cincin `spawn_radius`.
- `events: Array[WaveEvent]` urut menurut `minute`, sekali jalan:
  RING (lingkaran DRIFT menuju posisi player saat spawn), LINE (kolom DRIFT
  melintas), BURST (gerombolan di satu sisi), ELITE, BOSS (BossData).
- HP = base × `hp_scale(menit)` (1 + `hp_growth_per_minute` × menit) ×
  hp_mult entry/event (× elite_hp_mult untuk elite).
- `final_minute` (30): semua musuh + proyektil musuh dihapus tanpa drop,
  `reaper` (Knellwraith, HP 1e9, kontak 99999, cepat) muncul lalu tiap
  `reaper_interval`; spawn lain berhenti. Kematian setelahnya = akhir run
  ("Dawn finds you at last."), timer HUD merah.
- Debug lompat waktu: `SpawnDirector.skip_to()` melewati event sebelum
  target (target -3 detik supaya event di menit itu tetap terjadi).
- Tidak ada generator wave: edit `night.tres` di inspector atau teks.

## Stat
- `Stats` (RefCounted, milik Player): nilai = `(base + flat) * (1 + percent)`.
  Base dari `Stats.DEFAULT_BASE` + CharacterData; semua bonus lain adalah
  `StatModifier` (Resource: stat, flat, percent) lewat `add_modifier()`.
- `Stats.Id` disimpan sebagai int di `.tres`: tambah di akhir, jangan diurutkan ulang.
- Senjata tidak membaca `data.damage` langsung, tapi helper `Weapon.damage()`,
  `area()`, `cooldown()`, `amount()`, `projectile_speed()`, `duration()`,
  `roll_damage()` (gabungan WeaponData + level senjata + Stats).
- `pierce()` dan `knockback()` juga lewat helper.
- Pasif = `PassiveData` berisi `modifiers`; tiap level menerapkannya sekali lagi.
  Teks kartu: level 1 = `description` (satu baris, kartu tingginya tetap),
  level 2+ = otomatis `PassiveData.level_up_text()` lewat
  `StatModifier.describe()` / `Stats.describe()` (`Stats.LABELS`; stat di
  `FLAT_AS_PERCENT` ditampilkan sebagai persen). Tambah stat baru = tambah
  juga label di `LABELS`.
- 13 pasif menutupi semua stat gameplay: might, area, cooldown, amount,
  projectile speed, duration, move speed, max HP, recovery, armor, luck,
  magnet, crit (chance + damage).

## Senjata
- `WeaponData` = base stat level 1 + `levels: Array[WeaponLevel]`
  (levels[0] = level 2). `max_level = levels.size() + 1`.
- `WeaponLevel` = delta per level: damage/amount/pierce flat; area,
  cooldown, projectile_speed, duration pecahan dari base (0.1 = +10%,
  cooldown -0.1 = 10% lebih cepat) + `description` untuk kartu level up
  (kosong = teks otomatis). `Weapon.level` setter menjumlah delta sekali.
- Senjata baru = skrip `extends Weapon` + `.tscn` + `.tres` di
  `data/weapons/` + entri di `data/upgrade_pool.tres`.

## Evolusi + peti
- `EvolutionData` (`data/evolutions/`): `base` (WeaponData, harus level maks)
  + `passive` (minimal `passive_level`) → `result`. Terdaftar di
  `UpgradePool.evolutions`.
- Senjata evolusi = `WeaponData` dengan `is_evolution = true`, tanpa `levels`
  (max_level 1), TIDAK masuk `UpgradePool.weapons`. Perilakunya = skrip senjata
  dasar dengan export tambahan (aura `heal_per_pulse`, knives `fan`, orbit
  `rings`/`continuous`, vial `splash_count`/`drift_speed`, cross
  `endless`/`burst_count`) di `.tscn` varian.
- `Player.evolve(evo)` mengganti node di slot yang sama dan emit
  `weapon_replaced(old, new)`; Game meneruskannya ke
  `ProjectileField.replace_source()` (proyektil hidup tidak memegang node
  yang sudah di-free). `UpgradePool.owns_line()` mencegah senjata dasar
  ditawarkan lagi setelah berevolusi.
- Peti: `pending_chests`; `Game._open_chest()` mengundi jumlah item
  (1, atau 3/5 dengan peluang × LUCK), tiap item = `UpgradePool.chest_reward()`
  (evolusi yang siap dulu, kalau tidak level acak item yang dimiliki, kalau
  habis heal), langsung di-`apply()`, lalu `ChestScreen` (view saja, emit
  `closed`) menampilkan hasilnya. Hadiah = `UpgradeOffer` (kind `EVOLUTION`).

## Pickup (selain gem)
- Tiap jenis = `PickupData` (`data/pickups/*.tres`): `effect` (CHEST, HEAL,
  MAGNET, BOMB, COIN; int di .tres, tambah di akhir), `amount` (HEAL =
  fraksi max HP, COIN = jumlah koin, BOMB = damage x `director.hp_scale()`),
  `sprite_row`, `scale`, `drop_weight`, `luck_weighted` (bobot x LUCK),
  `magnetic` (ditarik radius magnet player seperti gem), `collect_effect`.
- `PickupField.types` (main.tscn) = semua jenis; slot menyimpan index ke
  `types`. `drop(at, data)`, `tick(dt, player, magnet)` mengembalikan index
  yang diambil (+ posisi di `collected_at`), Game yang menerapkan efeknya di
  `_on_pickup(data, pos)`. `attract_all()` menarik semua pickup magnetik.
- `DropTable` (`data/drops/*.tres`): `chance` (x LUCK) lalu undian berbobot.
  `enemy_drops` (0.4% per kill biasa) di Game, `breakable_drops` (100%) di
  tiap BreakableData. Elite/boss tetap menjatuhkan `Game.chest_pickup`.
- Pickup baru = .tres + baris di `pickups.png` (gen_sprites `pickup_sheet`)
  + masuk `PickupField.types` dan DropTable; efek baru = tambah `Effect` di
  akhir + cabang di `Game._on_pickup`.
- Bom: semua slot di `bomb_radius` (18, menutupi layar) kena damage, boss
  hanya `bomb_boss_fraction`, proyektil musuh dihapus, ledakan + shake +
  hit-stop. Magnet: `gems.attract_all()` + `pickups.attract_all()`.
- Koin: `Game.add_coins(amount)` = amount × GREED (pecahan dibawa ke koin
  berikutnya) ke `Game.coins`; dibank ke SaveData di akhir run.

## Objek pecahan
- `BreakableData` (extends EnemyData, `data/breakables/*.tres`): behavior
  STATIC, slot EnemySwarm dengan flag `PROP`. Jadi semua jalur hit senjata
  (aura, proyektil, orbit, zona tanah, bom) memakai query yang sama dengan
  musuh, termasuk hit flash dan angka damage. PROP dilewati separasi (tidak
  terdorong; musuh meluncur di sekitarnya) dan `collide_player`; tidak
  dihitung kill, tanpa XP. Mati → `death_effect` (debris) + asap + 1 pickup
  dari `drops`. Pisau/salib bisa membidik objek pecahan (seperti lampu di
  genre ini).
- `BreakableSpawner` (node): tiap `interval` membuang (diam-diam,
  `swarm.despawn`) prop yang tertinggal > `despawn_distance` dan menaruh prop
  baru (maks `max_alive`) di cincin 9-15 unit, kebanyakan di depan arah
  jalan. Dilacak lewat uid. Berhenti di final phase.

## Game feel
- Satu jalur damage: `EnemySwarm.damage_enemy(i, amount, knockback, crit)`
  → hit flash (boss maks 0.3), knockback (dibatasi `max_knock`, meluruh
  `exp(-knock_decay*dt)`), angka damage (`swarm.numbers`). Senjata mengisi
  `crit` dari `Weapon.last_crit` yang di-set `roll_damage()`.
- Angka damage murah: hit dekat angka baru (< 0.15 dtk, < 0.7 unit, 8
  terakhir) jenisnya sama digabung (nilai dijumlah, pop lagi); di atas
  `soft_cap` (220) angka normal dibuang; `capacity` 300.
- Shake: player kena hit, bom, boss muncul (`SpawnDirector.boss_shake`),
  boss mati. Efek kill: `EnemyData.death_effect` (skala x2 sprite besar,
  x1.6 elite, x3 boss + ledakan). Efek ambil pickup: `collect_effect`.

## UI (fase 7)
Semua layar = view: membaca Game / Player dan emit sinyal; Game yang
bertindak (unpause, restart, pindah scene). Urutan update tetap hanya di
`Game._process` (HUD = `hud.refresh(game)` di akhir frame).

Alur scene: `scenes/title.tscn` (main scene, `TitleScreen`) → Start →
`scenes/character_select.tscn` → pilih hunter → `scenes/main.tscn` (Game).
Title → Reliquary → `scenes/shop.tscn` → Back. Pause → Quit to Title /
Restart, Game over → Retry / Title (semua akhir run membank koin, lihat Meta).
Semua pindah scene lewat autoload `SceneFader.change_scene(path)` /
`reload()`: fade ke hitam, unpause tree, ganti scene, fade masuk; input
ditelan selama fade (`SceneFader.busy`).

Tema: `ui/theme/game_theme.tres` dipasang di project (`gui/theme/custom`),
jadi semua Control memakainya tanpa override. Warna: tinta gelap, merah
darah (tombol), emas (judul, fokus, evolusi), biru suci (XP, NEW, options).
- Font: `art/ui/font.fnt` + `font.png` (BMFont, digenerate
  `gen_sprites.font_sheet()`), desain sendiri 5x7 (huruf besar/kecil, angka,
  tanda baca, `· — × →`), outline gelap 1 px sudah di-bake, jadi tidak ada
  lisensi pihak ketiga. Ukuran dasar 12; importer `scaling_mode=1`
  (integer only): pakai kelipatan 12 (12 kecil, 24 normal, 48 judul, 72 logo).
  Warna font = modulasi isi putih; outline tetap gelap. Bayangan lewat
  `font_shadow_color` (outline font tidak jalan untuk bitmap font).
- Art UI (`art/ui/`, 1 piksel art = 2 px layar di 720p): panel 9-slice
  (`panel`, `panel_blood`, `panel_holy`, `inset`), `card*`, `button*`
  (normal/hover/pressed/disabled/focus/toggled), `slot*`, `badge_*`,
  `bar_frame*` + isi `bar_hp/xp/boss/gold`, `pip_off/on/next/max` (5x5, 1x),
  `check_on/off`, `grabber*`, ikon 12px (`icon_coin/skull/clock/heart/
  arrow/level`, `icon_chest`), `title_bg.png` (320x180, langit + bulan darah
  + kuburan). Tambah gaya = gambar di `gen_sprites.ui_panels()` + sub_resource
  StyleBoxTexture di tema (texture_margin = margin art x2).
- Variasi tema (`theme_type_variation`): Label `TitleLabel` `HeaderLabel`
  `TimerLabel` `GoldLabel` `MutedLabel` `SmallLabel`; Button `Card`;
  PanelContainer `BloodPanel` `HolyPanel` `InsetPanel` `BadgeNew`
  `BadgeEvo` `BadgeLevel`; Panel `SlotPanel` `SlotMax` `SlotEvo`;
  ProgressBar `XpBar` `HpBar` `BossBar`.
- Layout skala lewat stretch `canvas_items` + `expand` (1280x720 dasar);
  semua layar memakai anchor / CenterContainer.

Layar (CanvasLayer `process_mode = ALWAYS`, tween jalan saat tree pause):
- `Hud` (layer 1): `%XpBar` penuh di atas + `%LevelLabel`, HP (ikon,
  `%HpBar`, `%HpLabel`), `%Loadout` (6 senjata + 6 pasif: frame `SlotPanel`
  / `SlotMax` / `SlotEvo` + ikon + `LevelPips`), `%TimeLabel` (merah di final
  phase), `%BossPanel`, kill + koin kanan atas, `%Arrows` (panah tepi layar ke
  boss (`BossBrain.pos`) dan peti di `PickupField`, maks 4),
  `%DebugPanel`. Teks hanya diformat ulang saat nilai int berubah, variasi
  slot / pips hanya saat berubah: biaya ~1% FPS di 1100 musuh.
- HP bar di dunia: `Player.hp_bar` (`WorldHpBar`, quad billboard
  `shaders/world_bar.gdshader`, tanpa depth test), `Hud.refresh` memanggil
  `set_fraction()`; parameter shader ditulis hanya saat jumlah piksel berubah.
- `LevelUpScreen` (layer 10): kartu = Button `Card` berisi `OfferView`
  (ikon, nama, badge NEW / LV n / EVOLVED, pips level sekarang + yang
  didapat, deskripsi). `UpgradeOffer.title` = nama saja, `badge`,
  `max_level`. Animasi: panel pop + kartu slide berurutan. Tetangga fokus
  eksplisit (kartu lebar tidak "mencuri" kiri/kanan dari baris tombol).
- `ChestScreen` (layer 11): baris `OfferView` dalam `InsetPanel`.
- `PauseMenu` (layer 20): Resume / Options / Restart / Quit to Title, stat
  player (`PauseMenu.format_stat`) + loadout. `OptionsPanel` menggantikan
  menu (dan panel info) saat dibuka.
- `OptionsPanel` (dipakai title + pause): volume Master/SFX/Music,
  screen shake, angka damage, fullscreen (disabled di window editor).
- `GameOverScreen` (layer 20): "FALLEN" (panel darah) atau "THE NIGHT IS
  OVER" bila mati di final phase (Knellwraith); waktu, level, kill, koin,
  musuh paling banyak dibunuh (frame pertama sheet musuh via AtlasTexture),
  damage per senjata (+ per detik), Retry / Title (R = retry).
- `TitleScreen`: Start (→ pilih hunter) / Reliquary / Options / Quit, koin
  permanen kanan atas, rekor seumur hidup di bawah (`records_text()`).
- `ShopScreen` (Reliquary): grid 6x3 kartu `Card` (ikon, nama, `LevelPips`,
  harga; merah bila tak terbeli) + panel detail (level, efek sekarang /
  berikutnya lewat `MetaUpgrade.effect_text`, Buy). Tekan kartu = beli.
  Refund All minta tekan dua kali (3 dtk). ui_cancel = kembali.
- `CharacterSelect`: daftar kartu hunter dengan potret berjalan
  (AtlasTexture, region digeser 8 fps) + detail (potret besar, deskripsi,
  senjata awal, traits dari `StatModifier.describe`). Terkunci = siluet +
  syarat + progress bar; tipe BUY bisa direkrut. Tekan hunter terbuka =
  pilih + mulai run.
- `GameOverScreen` panel Reward: "+N coins banked · M in the purse",
  "New longest night!", potret + nama hunter yang baru terbuka
  (`Game.run_reward`).

Settings (autoload `Settings`, disimpan di dalam save sebagai
`SaveData.options`; `user://settings.cfg` Fase 7 hanya dibaca sekali oleh
migrasi v1→v2): `volumes[3]` (bus Master / SFX / BGM dari
`default_bus_layout.tres`), `screen_shake`, `damage_numbers`, `fullscreen`;
emit `changed`, simpan lewat `SaveData.queue_save()` (geser slider = 1
tulis). Game menerapkan dua opsi gameplay ke `CameraRig.shake_enabled` dan
`DamageNumberField.enabled`.

Input: keyboard (panah + Enter/Space, Esc), mouse (hover = fokus), gamepad
(d-pad, A = ui_accept, B = ui_cancel, Start = pause). `ui_accept` + Joypad A
dan `ui_cancel` + Joypad B ditambahkan di project.godot (default Godot tidak
punya). `ui_cancel`: keluar dari options / mode banish / menutup peti /
resume dari pause. Tombol disabled placeholder `focus_mode = NONE`.

Statistik run: `EnemySwarm.damage_enemy(..., source: Weapon)` menambah
`Weapon.damage_dealt` (tanpa overkill; aura, ProjectileField, vial mengirim
source; bom tidak dihitung). `Player.evolve()` meneruskan total ke senjata
evolusi. `Game.kills_by_type[EnemyData]` dihitung di `_on_enemy_died`.

## HUD (loadout)
- Slot loadout dibangun di `hud.gd`, isi di-refresh tiap frame (variasi
  tema / pips hanya saat berubah). Game memanggil `hud.refresh()` sebelum
  menampilkan layar peti / game over karena tree sedang pause.
- `ProjectileField` (node di main.tscn): semua proyektil sebagai packed
  array + 1 MultiMesh. Senjata mengisi `ProjectileField.Shot` (dipakai
  ulang) lalu `spawn()`. Flag: ORBIT, FACE_VELOCITY, BOUNCE_ENEMY,
  BOUNCE_SCREEN (pantul di `view_rect` = `CameraRig.ground_view_rect()`),
  NO_HIT, ARC. `hits` = sisa musuh yang boleh dikenai (-1 = tak terbatas,
  pierce + 1, untuk BOUNCE_ENEMY tiap hit = satu pantulan).
- Proyektil mengingat `HIT_MEMORY` uid musuh terakhir (`EnemySwarm.uid`
  stabil walau slot berpindah); `rehit` > 0 menghapus ingatan tiap interval
  (orbit bisa kena musuh yang sama lagi).
- Zona tanah (Hallowed Vial) = packed array + MultiMesh milik senjata
  (`top_level`), bukan node per zona.

## Level up
- `Leveling` (kurva XP) dan antrian `Game.pending_levels`. Game memegang
  aturan (sisa reroll/skip/banish dari stat REROLL/SKIP/BANISH, daftar banish);
  `LevelUpScreen` hanya view yang emit `picked/reroll_requested/
  skip_requested/banish_requested`.
- Pilihan = `UpgradeOffer` (kind + item + next_level, `apply(player)`),
  diundi oleh `UpgradePool.roll()` dari `data/upgrade_pool.tres`.
- Slot: `Player.MAX_WEAPONS = 6`, `Player.MAX_PASSIVES = 6`.
- Tree di-pause selama layar terbuka; layar `process_mode = ALWAYS`.
  `ui_accept` di project.godot ditambah Joypad A (default Godot tidak punya).

## Meta progression (fase 8)
- Autoload urut: `_mcp_game_helper`, `SaveData`, `Audio`, `Settings`
  (membaca `SaveData.options` di `_ready`), `SceneFader`.
- `SaveData` (`autoload/save_data.gd`) = state permanen + aturan meta
  (UI hanya view): `coins`, `upgrade_levels` (id → level), `unlocked`,
  `selected`, `options`, rekor (`best_time`, `total_kills`, `runs`,
  `nights_survived`, `lifetime_coins`). API: `buy_upgrade`, `refund_all`,
  `apply_upgrades(stats)`, `is_unlocked`, `buy_character`,
  `select_character`, `unlock_progress`, `bank_run(...) -> RunReward`.
- Format `user://save.json` (JSON, id string, bukan index):
  `{version: 2, coins, upgrades: {id: lv}, unlocked: [id], selected,
  options: {volume_master, volume_sfx, volume_bgm, screen_shake,
  damage_numbers, fullscreen}, records: {best_time, total_kills, runs,
  nights_survived, lifetime_coins}}`. Migrasi `_migrate()` langkah demi
  langkah (v1 = tanpa `version`: options diambil dari settings.cfg).
  Tambah field = default di `_reset()` + baca di `_from_dict()`; ubah
  bentuk = naikkan `VERSION` + satu langkah di `_migrate()`.
- Tulis atomik: `save.json.tmp` → `save.json` lama jadi `.bak` → rename
  tmp. Muat: `save.json`, lalu `.bak`, lalu default. File rusak disalin ke
  `.corrupt` (push_warning); byte non-JSON ditolak sebelum decode UTF-8.
  Semua field dicek tipe + di-clamp (level ≤ max_level, id tak dikenal
  dibuang). `load_status` = ok / backup / new / corrupt.
- `MetaCatalog` (`data/meta.tres`): `characters` (urutan layar pilih),
  `upgrades` (urutan toko), `default_character`.
- `MetaUpgrade` (`data/meta_upgrades/*.tres`): `modifiers: Array[StatModifier]`
  diterapkan `level` kali saat run mulai, `max_level`,
  `cost(lv) = base_cost × cost_growth^lv` (dibulatkan ke 5), refund =
  `spent(lv)`. 18 upgrade: might, armor, max HP, recovery, cooldown, area,
  projectile speed, duration, amount, move speed, magnet, luck, growth,
  greed, revival, reroll, skip, banish. Upgrade baru = .tres + masuk
  `meta.tres`.
- `Stats.Id` baru (di akhir): `GREED` (pengali koin), `REVIVAL` (nyawa
  ekstra: `Game._revive()` → `Player.revive()` 50% HP, musuh di
  `revive_radius` didorong, proyektil musuh dihapus).
- `CharacterData`: `epithet`, `unlock` (`FREE`, `SURVIVE_SECONDS`,
  `TOTAL_KILLS`, `NIGHTS_SURVIVED`, `BUY`; int di .tres, tambah di akhir),
  `unlock_value`. Syarat rekor dicek di `bank_run`. Hunter: Hunter (Holy
  Aura, bebas), Sister Maud (Vesper Beads, bebas), Vesna Thorn (Silverthorn
  Knives, bertahan 10:00), Brother Odo (Hallowed Vial, 3000 kill total),
  Dame Ysolde (Pilgrim's Cross, rekrut 750 koin). Sheet
  `art/sprites/player_<id>.png` dari `gen_sprites.HUNTER_SHEETS` (import
  lossless, tanpa mipmap, `detect_3d` mati supaya potret UI tajam).
- Run: `Game._ready` memakai `SaveData.selected_character()` lalu
  `SaveData.apply_upgrades(player.stats)` (setelah bonus karakter).
  `Game._end_run()` (mati, Restart, Quit to Title) membank sekali
  (`run_reward`).

## Audio (fase 8)
- `Audio` (`autoload/audio.gd`) + `SoundBank` (`data/sound_bank.tres`):
  `SoundDef` per id = `streams` (acak per play), `volume_db`,
  `max_concurrent`, `min_interval`, `pitch_jitter`, `priority`.
- `Audio.play_sfx(id, at = Vector2.INF, pitch_jitter = -1)`: cek cooldown
  id dulu (O(1)), lalu pool 24 `AudioStreamPlayer` di bus SFX: drop bila
  id sudah `max_concurrent`; pool penuh → curi voice tertua dengan
  prioritas ≤. `at` = posisi dunia (x, z): redam linear sampai -10 dB di
  `HEAR_RADIUS` (24), di luarnya tidak diputar. `Audio.listener` diisi
  Game tiap frame. Penghitung `played` / `dropped` / `active_voices(id)`.
- `Audio.play_music(id, fade)` / `stop_music(fade)`: dua player di bus BGM,
  crossfade linear. Title / select / shop = `title`, run = `night`.
- Hook: hit (`EnemySwarm.hits_this_frame` → maks 1 per frame), kill,
  gem, coin, heal, pickup (peti / magnet), level_up, chest_open, bomb,
  player_hurt, boss_spawn (`SpawnDirector.spawn_boss`), game_over, revive,
  buy / deny / unlock (toko, pilih hunter). UI global lewat
  `SceneTree.node_added`: tiap BaseButton `pressed` → `ui_select` (kecuali
  meta `no_press_sound`), fokus tombol / slider → `ui_move` (diam 250 ms
  setelah ganti scene), ui_cancel saat ada fokus → `ui_back`.
- Placeholder: `python tools/gen_audio.py` (stdlib saja, seeded) menulis WAV
  16-bit mono 22.05 kHz. Ganti dengan aset asli: timpa file dengan nama
  sama (atau arahkan `streams` SoundDef ke file baru, .ogg juga boleh);
  musik butuh loop (`edit/loop_mode=2` di .import WAV, atau `loop = true`
  di import OGG).
- Terukur: ~670 kill/s → 168 suara diputar dari ~3500 permintaan, puncak 5
  voice. FPS (vsync off, 5 evolusi, ~1067 hidup, 283 kill/s, audio aktif):
  125 (Fase 7: 127 pada 225 kill/s).

## Saran C# / GDExtension (bila butuh skala > ~1500 musuh)
Hot path sekarang GDScript atas packed array. Urutan pindah (paling untung
dulu), API publik dipertahankan supaya Game tidak berubah:
1. `EnemySwarm.tick` (gerak per perilaku + separasi berbobot radius) dan
   `SpatialHash` rebuild/query: loop ketat per slot, ideal untuk
   GDExtension C++ (atau C# dengan `Span<T>` atas array struct). Query
   menulis indeks ke buffer yang dipakai ulang, bukan Array baru.
2. `ProjectileField.tick` (gerak + `query_circle` + hit memory): bisa
   memakai hash yang sama tanpa melewati batas bahasa per proyektil.
3. Upload buffer (`swarm.upload`, gems, proyektil, angka): isi
   `PackedFloat32Array` transform + custom di native lalu satu
   `multimesh_set_buffer`; di GDScript ini biaya per-instance terbesar.
4. C# cocok bila tim lebih nyaman; GDExtension bila butuh SIMD /
   multithread (`WorkerThreadPool` per sel grid). Sebelum pindah, ukur
   dulu dengan profiler mana yang dominan.
Yang tidak perlu dipindah: Game (urutan), director, UI, SaveData, Audio.

## Debug (build debug)
F1 +500 musuh, F2 hapus musuh, F3 tarik semua gem, F4 +1 level,
F5 semua senjata di pool ke level maks, F6 jatuhkan peti di depan player,
F7 beri pasif pasangan evolusi untuk senjata yang dimiliki,
PgUp +1 menit, 1/2/3 lompat ke 9:57 / 19:57 / 29:57, E elite di dekat
player, 4-9 jatuhkan tiap pickup selain peti (urutan `PickupField.types`,
nama tampil di panel), B satu dari tiap objek pecahan di depan player,
H sembunyikan/tampilkan bantuan tombol (`%DebugPanel` HUD: 2 baris
statistik + 4 baris tombol, hanya di build debug). Pause sekarang membuka
`PauseMenu`; R = restart dari pause / retry di game over. F8–F10 sengaja tidak dipakai: di editor F8 = stop, F9 = suspend,
F10 = next frame game yang di-embed.
