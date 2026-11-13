"""Pixel-art generator for the project.

Run:  python tools/gen_sprites.py
Writes PNGs into res://art/. Every sprite is ASCII art (one char = one palette
colour); the script adds automatic top-light / bottom-shade and a 1px dark
outline, so every sprite shares the same look.
"""
import math
import os
import random

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ART = os.path.join(ROOT, "art")

OUTLINE = (24, 16, 30, 255)
CELL = 18  # 16px art + 1px outline margin on every side


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def shade(c, f):
    return tuple(max(0, min(255, int(v * f))) for v in c[:3]) + (255,)


# Palette shared by every sprite. Upper case = shaded automatically,
# lower case / digits = flat (eyes, details).
PAL = {
    # player – vampire hunter
    "H": hexc("#5a3a2e"),  # hat
    "h": hexc("#3b2420"),  # hat brim
    "S": hexc("#f2c29b"),  # skin
    "e": hexc("#1b1b2e"),  # eye
    "R": hexc("#c8283c"),  # scarf
    "C": hexc("#2f4f8f"),  # coat
    "Y": hexc("#e8b84a"),  # belt buckle
    "P": hexc("#3a3048"),  # pants
    "B": hexc("#6b4430"),  # boots
    "W": hexc("#c9ccd6"),  # steel
    # ghoul
    "G": hexc("#7fae5a"),  # rotten skin
    "r": hexc("#ff4040"),  # glowing eye
    "m": hexc("#2a1a1a"),  # mouth
    "T": hexc("#7b6a52"),  # rags
    "t": hexc("#5a4c3a"),  # rags dark
    # bat
    "V": hexc("#4b3466"),  # bat body
    "N": hexc("#6c4f8f"),  # wing membrane
    "w": hexc("#f4f4f4"),  # fangs / bone white
    # skeleton
    "K": hexc("#e8e2cf"),  # bone
    "k": hexc("#a59e8a"),  # bone shadow
    # slime
    "L": hexc("#4fc7c0"),  # slime
    "l": hexc("#b8fff6"),  # slime highlight
    # decor
    "g": hexc("#4f8a3c"),  # grass blade
    "F": hexc("#e85d8a"),  # flower pink
    "f": hexc("#ffe066"),  # flower centre
    "O": hexc("#8a8a96"),  # rock
    "M": hexc("#c0453a"),  # mushroom cap
    "s": hexc("#efe6d0"),  # mushroom stem / spots
    "D": hexc("#6e6e7c"),  # tombstone
    "d": hexc("#4a4a56"),  # engraving
    "Q": hexc("#5bd2ff"),  # holy blue
    "q": hexc("#e8fbff"),  # holy core / sparkle
    # gem body + facet, recoloured per tier in gem_sheet()
    "J": hexc("#4aa3ff"),
    "j": hexc("#c8e8ff"),
    # weapons
    "i": hexc("#ffffff"),  # blade glint
    "U": hexc("#f0b43c"),  # vesper bead gold
    "u": hexc("#fff3c4"),  # bead highlight
    "A": hexc("#9fc4e8"),  # vial glass
    "X": hexc("#a8acbc"),  # cross silver
    # phase 4: relics, evolutions, chest
    "E": hexc("#e9b949"),  # relic gold
    "Z": hexc("#8a5a32"),  # chest wood
    "I": hexc("#b3243a"),  # crimson steel
    "c": hexc("#efe3c2"),  # wax / ivory (shaded)
    "a": hexc("#ff9a3c"),  # flame
    "n": hexc("#b9b5c9"),  # incense smoke
    "1": hexc("#3b3a5e"),  # raven feather
    "2": hexc("#c39662"),  # mandrake root
    "3": hexc("#5fae4a"),  # leaf
}
FLAT = set("eYrmwlfsdqkjiuan")


def render(rows, w=16, h=16, pal=None, flat=""):
    """ASCII rows -> RGBA image ((w+2) x (h+2)) with shading + outline.
    `pal` adds/overrides palette entries for this sprite only; `flat` lists
    extra characters that are not auto-shaded."""
    colors = PAL if pal is None else {**PAL, **pal}
    flats = FLAT | set(flat)
    cw, ch_ = w + 2, h + 2
    img = Image.new("RGBA", (cw, ch_), (0, 0, 0, 0))
    px = img.load()
    grid = [[None] * w for _ in range(h)]
    pad_top = h - len(rows)  # bottom-align so feet sit on the cell bottom
    assert pad_top >= 0, "sprite taller than %d rows" % h
    for y, row in enumerate(rows):
        for x, ch in enumerate(row[:w]):
            if ch != "." and ch != " ":
                grid[y + pad_top][x] = ch

    def solid(x, y):
        return 0 <= x < w and 0 <= y < h and grid[y][x] is not None

    for y in range(h):
        for x in range(w):
            ch = grid[y][x]
            if ch is None:
                continue
            c = colors[ch]
            if ch not in flats:
                up = solid(x, y - 1) and grid[y - 1][x] == ch
                down = solid(x, y + 1) and grid[y + 1][x] == ch
                left = solid(x - 1, y) and grid[y][x - 1] == ch
                if not up or not left:
                    c = shade(c, 1.22)
                elif not down:
                    c = shade(c, 0.72)
            px[x + 1, y + 1] = c
    # outline
    for y in range(ch_):
        for x in range(cw):
            if px[x, y][3] != 0:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < cw and 0 <= ny < ch_ and px[nx, ny][3] != 0 and px[nx, ny] != OUTLINE:
                    px[x, y] = OUTLINE
                    break
    return img


def sheet(frames_by_row, cols, cell=CELL):
    """Frames are ASCII rows (16x16 art) or already rendered images."""
    out = Image.new("RGBA", (cell * cols, cell * len(frames_by_row)), (0, 0, 0, 0))
    for r, frames in enumerate(frames_by_row):
        for c, fr in enumerate(frames):
            img = fr if isinstance(fr, Image.Image) else render(fr)
            out.paste(img, (c * cell, r * cell))
    return out


# ---------------------------------------------------------------- player
P_TOP = [
    ".....HHHHH......",
    "....HHHHHHH.....",
    "....HHHHHHH.....",
    "..hhhhhhhhhhh...",
    ".....SSSSSS.....",
    ".....SSSeSe.....",
    ".....SSSSSS.....",
    "....RRRRRRRR....",
    "...CCRRCCCCCC...",
    "...CCCRCCCCCCWW.",
    "...SCCCYCCCCS...",
    "....CCCCCCCC....",
]
P_LEGS = [
    ["....PP...PP.....", "....PP...PP.....", "....BB...BB....."],
    ["...PP.....PP....", "..PP.......PP...", "..BB.......BB..."],
    ["....PP...PP.....", "....PP...PP.....", "....BB...BB....."],
    [".....PP.PP......", ".....PP.PP......", ".....BB.BB......"],
]


def player_frames():
    frames = []
    for i, legs in enumerate(P_LEGS):
        top = list(P_TOP)
        rows = top + legs
        if i % 2 == 1:  # bob up one pixel on stride frames
            rows = rows + ["................"]
        frames.append(rows)
    return frames


# ---------------------------------------------------------------- ghoul
G_TOP = [
    "......GGGG......",
    ".....GGGGGG.....",
    ".....GGrGGr.....",
    ".....GGGGGG.....",
    "......GmmmG.....",
    "....TTTTTT......",
]
G_ARMS = [
    ["...TTTTTTTGGGG..", "...TTTTTTT......"],
    ["...TTTTTTT......", "...TTTTTTTGGGG.."],
]
G_LEGS = [
    ["....tttttt......", "....GG..GG......", "....GG..GG......"],
    ["....tttttt......", "...GG....GG.....", "...GG.....GG...."],
    ["....tttttt......", "....GG..GG......", "....GG..GG......"],
    ["....tttttt......", ".....GGGG.......", ".....GG.GG......"],
]


def ghoul_frames():
    out = []
    for i in range(4):
        rows = G_TOP + G_ARMS[i // 2] + ["....TTTTTT......"] + G_LEGS[i]
        out.append(rows)
    return out


# ---------------------------------------------------------------- bat
BAT_UP = [
    ".N............N.",
    ".NN..........NN.",
    ".NNN...VV...NNN.",
    "..NNN.VVVV.NNN..",
    "...NNVVVVVVNN...",
    "....NVrVVrVN....",
    ".....VVVVVV.....",
    "......VwwV......",
    ".......VV.......",
    "................",
    "................",
    "................",
]
BAT_MID = [
    "................",
    "................",
    ".......VV.......",
    "......VVVV......",
    ".NNNNVVVVVVNNNN.",
    "NNNNNVrVVrVNNNNN",
    "N..NNVVVVVVNN..N",
    "......VwwV......",
    ".......VV.......",
    "................",
    "................",
    "................",
]
BAT_DOWN = [
    "................",
    "................",
    ".......VV.......",
    "......VVVV......",
    ".....VVVVVV.....",
    "....NVrVVrVN....",
    "...NNVVVVVVNN...",
    "..NNN.VwwV.NNN..",
    ".NNN...VV...NNN.",
    ".NN..........NN.",
    ".N............N.",
    "................",
]


def bat_frames():
    # bats hover: lift whole sprite 3px above ground
    lift = ["................"] * 3
    return [f + lift for f in (BAT_UP, BAT_MID, BAT_DOWN, BAT_MID)]


# ---------------------------------------------------------------- skeleton
S_TOP = [
    "......KKKK......",
    ".....KKKKKK.....",
    ".....KeKKeK.....",
    ".....KKKKKK.....",
    "......KwkK......",
    ".......KK.......",
    ".....KKKKKK.....",
    "....K.kKKk.K....",
    "....K.KKKK.K....",
    "......kKKk......",
    ".......KK.......",
    "......KKKK......",
]
S_LEGS = [
    ["......K..K......", "......K..K......", ".....KK..KK....."],
    [".....K....K.....", "....K......K....", "...KK......KK..."],
    ["......K..K......", "......K..K......", ".....KK..KK....."],
    [".......KK.......", ".......KK.......", "......KKKK......"],
]


def skeleton_frames():
    return [S_TOP + legs for legs in S_LEGS]


# ---------------------------------------------------------------- slime
def slime_frames():
    base = [
        [
            "......LLLL......",
            "....LLLLLLLL....",
            "...LLlLLLLLLL...",
            "..LLlLLLLLLLLL..",
            "..LLLLeLLLeLLL..",
            "..LLLLLLLLLLLL..",
            "..LLLLLmmLLLLL..",
            "...LLLLLLLLLL...",
        ],
        [
            ".....LLLLLL.....",
            "...LLLLLLLLLL...",
            "..LLlLLLLLLLLL..",
            ".LLlLLeLLLeLLLL.",
            ".LLLLLLLLLLLLLL.",
            ".LLLLLLmmLLLLLL.",
            "LLLLLLLLLLLLLLLL",
        ],
        [
            "......LLLL......",
            ".....LLLLLL.....",
            "....LlLLLLLL....",
            "....LlLLLLLL....",
            "...LLLeLLeLLL...",
            "...LLLLLLLLLL...",
            "...LLLLmmLLLL...",
            "...LLLLLLLLLL...",
            "....LLLLLLLL....",
        ],
    ]
    return [base[0], base[1], base[0], base[2]]


# ---------------------------------------------------------------- decor
DECOR = [
    [  # grass tuft
        "..g....g....g...",
        "..g...gg...gg...",
        "...g..g...g.....",
        "...gg.g..gg.....",
        "....ggggg.......",
    ],
    [  # flowers
        "...F.......F....",
        "..FfF.....FfF...",
        "...F...F...F....",
        "...g..FfF..g....",
        "...g...F...g....",
        "...gg..g..gg....",
        "....gggggg......",
    ],
    [  # rock
        ".....OOOO.......",
        "...OOOOOOOO.....",
        "..OOOOOOOOOO....",
        "..OOOOOOOOOOO...",
    ],
    [  # mushroom
        "....MMMMM.......",
        "...MMsMMMM......",
        "..MMMMMMsMM.....",
        "......ss........",
        "......ss........",
    ],
    [  # bones
        "..w..........w..",
        "...kwwwwwwwwk...",
        "..w..........w..",
    ],
    [  # tombstone
        ".....DDDDD......",
        "....DDDDDDD.....",
        "....DDDdDDD.....",
        "....DDdddDD.....",
        "....DDDdDDD.....",
        "....DDDdDDD.....",
        "....DDDDDDD.....",
        "....DDDDDDD.....",
        "...ggDDDDDDDg...",
    ],
]

# ---------------------------------------------------------------- icons
ICON_AURA = [
    "................",
    ".....qQQQQq.....",
    "...QQq.....qQ...",
    "..Qq.........Q..",
    "..Q....qq....Q..",
    ".Q....qQQq....Q.",
    ".Q...qQqqQq...Q.",
    ".Q...qQqqQq...Q.",
    ".Q....qQQq....Q.",
    "..Q....qq....Q..",
    "..Qq.........Q..",
    "...QQq.....qQ...",
    ".....qQQQQq.....",
    "................",
]


# ---------------------------------------------------------------- projectiles
def centered(rows, h=16):
    """Pad rows to h lines, centred vertically (projectile quads are centred)."""
    top = (h - len(rows)) // 2
    return ["." * 16] * top + list(rows) + ["." * 16] * (h - len(rows) - top)


KNIFE = [  # points right; ProjectileField rotates it along its flight
    "...Y............",
    "BBBYWWWWWWWWWW..",
    "BBBYWWWWWWWWWWWW",
    "...Y............",
]
# blade pixels that catch the light, per frame (row, col)
KNIFE_GLINT = [[(1, 5)], [(1, 8)], [(1, 11)], []]

BEAD = [
    "......UUUU......",
    ".....UuuUUU.....",
    "....UuuUUUUU....",
    "....UuUUUUUU....",
    "....UUUUUUUU....",
    "....UUUUUUUU....",
    ".....UUUUUU.....",
    "......UUUU......",
]
# halo sparkles orbiting the bead, per frame
BEAD_SPARKS = [
    [(0, 3), (9, 12)],
    [(2, 13), (7, 2)],
    [(9, 4), (0, 11)],
    [(7, 13), (2, 2)],
]

CROSS = [
    "......XXX.......",
    "......XYX.......",
    "......XXX.......",
    "......XXX.......",
    ".XXXXXXXXXXXXX..",
    ".YXXXXXrXXXXXY..",
    ".XXXXXXXXXXXXX..",
    "......XXX.......",
    "......XXX.......",
    "......XXX.......",
    "......XYX.......",
    "......XXX.......",
]

VIAL = [
    "......BB........",
    "......BB........",
    ".....AAAA.......",
    "......AA........",
    ".....AQQA.......",
    "....AQqQQA......",
    "....AQQQQA......",
    "....AQQQQA......",
    ".....AAAA.......",
]


def with_pixels(rows, pixels, ch):
    fr = [list(r) for r in rows]
    for y, x in pixels:
        fr[y][x] = ch
    return ["".join(r) for r in fr]


def recolor(rows, mapping):
    return ["".join(mapping.get(ch, ch) for ch in r) for r in rows]


THORN = recolor(KNIFE, {"W": "I", "B": "Z", "Y": "E"})
ROSARY_BEAD = recolor(BEAD, {"U": "I", "u": "i"})
RADIANT_CROSS = recolor(CROSS, {"X": "E", "Y": "i", "r": "R"})
# rays flickering around the radiant cross, per frame (row, col) in a 16x16 cell
RADIANT_RAYS = [
    [(1, 3), (1, 12), (14, 3), (14, 12)],
    [(0, 7), (7, 0), (15, 8), (8, 15)],
    [(2, 4), (2, 11), (13, 4), (13, 11)],
    [(0, 8), (8, 0), (15, 7), (7, 15)],
]
GOLD_VIAL = recolor(VIAL, {"Q": "U", "q": "u", "B": "E"})


def projectile_sheet():
    """Row = ProjectileField sheet row used by each weapon (sprite_row export).
    0 knife, 1 bead, 2 cross, 3 vial, 4 thorn (Thornstorm), 5 garnet bead
    (Eternal Rosary), 6 radiant cross (Radiant Crucifix), 7 golden vial
    (Font of Saints)."""
    knife = [centered(with_pixels(KNIFE, g, "i")) for g in KNIFE_GLINT]
    bead = [with_pixels(centered(BEAD, 10), sp, "u") for sp in BEAD_SPARKS]
    bead = [centered(b) for b in bead]
    cross = [centered(CROSS)] * 4
    vial = [centered(VIAL)] * 4
    thorn = [centered(with_pixels(THORN, g, "i")) for g in KNIFE_GLINT]
    rosary = [centered(with_pixels(centered(ROSARY_BEAD, 10), sp, "E")) for sp in BEAD_SPARKS]
    radiant = [with_pixels(centered(RADIANT_CROSS), rays, "q") for rays in RADIANT_RAYS]
    gold_vial = [centered(GOLD_VIAL)] * 4
    return sheet([knife, bead, cross, vial, thorn, rosary, radiant, gold_vial], 4)


HOLY_WATER = ((40, 110, 200), (70, 150, 235), (150, 215, 255), (200, 240, 255), (20, 40, 90))
SAINTS_FONT = ((120, 70, 20), (176, 122, 40), (230, 186, 92), (246, 222, 150), (70, 40, 10))


def holy_water_sheet(size=48, frames=4, colors=HOLY_WATER):
    """Top-down holy water pool, 4 shimmer frames, drawn flat on the ground.
    colors = deep, body, light, rim, edge."""
    out = Image.new("RGBA", (size * frames, size), (0, 0, 0, 0))
    c = (size - 1) / 2.0
    R = size / 2.0 - 1.5
    rnd = random.Random(11)
    wobble = [rnd.uniform(-1.2, 1.2) for _ in range(12)]
    deep, body, light, rim, edge = colors
    for f in range(frames):
        px = out.load()
        sparks = random.Random(100 + f)
        for y in range(size):
            for x in range(size):
                dx, dy = x - c, y - c
                d = math.hypot(dx, dy)
                a = (math.atan2(dy, dx) + math.pi) / (2 * math.pi) * 12
                k = int(a) % 12
                t = a - int(a)
                r = R + wobble[k] * (1 - t) + wobble[(k + 1) % 12] * t
                if d > r + 1:
                    continue
                if d > r:
                    col, al = edge, 200
                elif d > r - 2:
                    col, al = rim, 190
                else:
                    # ripples moving outward, quantised to pixel rings
                    ring = (d - f * 3.0) % 9.0
                    if ring < 1.0:
                        col, al = light, 150
                    elif d < r * 0.45:
                        col, al = deep, 120
                    else:
                        col, al = body, 95
                    # faint holy cross in the middle
                    if (abs(dx) < 1.0 and abs(dy) < 8) or (abs(dy + 2) < 1.0 and abs(dx) < 5):
                        col, al = rim, 160
                px[x + f * size, y] = col + (al,)
        for _ in range(7):
            ang = sparks.uniform(0, 2 * math.pi)
            dist = sparks.uniform(0, R - 4)
            x, y = int(c + math.cos(ang) * dist), int(c + math.sin(ang) * dist)
            px[x + f * size, y] = (255, 255, 255, 255)
    return out


# ---------------------------------------------------------------- weapon icons
def stamp(canvas, pattern, x0, y0):
    for y, row in enumerate(pattern):
        for x, ch in enumerate(row):
            if ch != ".":
                canvas[y0 + y][x0 + x] = ch


def blank(w=16, h=16):
    return [["."] * w for _ in range(h)]


def join(canvas):
    return ["".join(r) for r in canvas]


def icon_beads():
    orb = [".UUU.", "UuuUU", "UuUUU", "UUUUU", ".UUU."]
    cv = blank(16, 15)
    # dotted orbit ring
    for k in range(28):
        a = k / 28 * 2 * math.pi
        x, y = int(round(7.5 + math.cos(a) * 6.5)), int(round(7.5 + math.sin(a) * 6.5))
        if k % 2 == 0 and 0 <= x < 16 and 0 <= y < 15:
            cv[y][x] = "q"
    cv[7][7] = cv[7][8] = cv[8][7] = cv[8][8] = "Q"  # player spark in the middle
    stamp(cv, orb, 5, 0)
    stamp(cv, orb, 0, 9)
    stamp(cv, orb, 11, 9)
    return join(cv)


WEAPON_ICONS = {
    "silverthorn_knives": [
        "WW............WW",
        "WWW..........WWW",
        ".WWW........WWW.",
        "..WWW......WWW..",
        "...WiW....WiW...",
        "....WWW..WWW....",
        ".....WWWWWW.....",
        "......WWWW......",
        ".....YYWWYY.....",
        "....YYY..YYY....",
        "...BBY....YBB...",
        "..BBB......BBB..",
        ".BBB........BBB.",
        ".BB..........BB.",
    ],
    "hallowed_vial": [
        "......BBBB......",
        "......BBBB......",
        ".......AA.......",
        ".......AA.......",
        "......AAAA......",
        ".....AQQQQA.....",
        "....AQqQQQQA....",
        "...AQqQQiQQQA...",
        "...AQQQiiiQQA...",
        "...AQQQQiQQQA...",
        "...AQQQQiQQQA...",
        "....AQQQQQQA....",
        ".....AAAAAA.....",
    ],
    "pilgrims_cross": [
        ".......XX.......",
        "......XYYX......",
        "......XXXX......",
        "......XXXX......",
        ".XX...XXXX...XX.",
        "XYXXXXXXXXXXXXYX",
        "XYXXXXXrrXXXXXYX",
        ".XX...XXXX...XX.",
        "......XXXX......",
        "......XXXX......",
        "......XXXX......",
        "......XXXX......",
        "......XYYX......",
        ".......XX.......",
    ],
}


# ---------------------------------------------------------------- gems
GEM = [
    "................",
    "................",
    "................",
    ".......jJ.......",
    "......jJJJ......",
    ".....jJJJJJ.....",
    "....jJJJJJJJ....",
    ".....JJJJJJ.....",
    "......JJJJ......",
    ".......JJ.......",
]
# (row, col) of sparkle pixels per animation frame
GEM_SPARKLE = [[], [(5, 7)], [(0, 11), (1, 10), (1, 11), (1, 12), (2, 11)], []]
# body, facet per tier (sheet row) -- GemField.tier_min_value picks the row
GEM_TIERS = [
    ("#4aa3ff", "#c8e8ff"),  # blue
    ("#4fd36b", "#d0ffd8"),  # green
    ("#ff4a5a", "#ffd0d4"),  # red
    ("#c070ff", "#f0d8ff"),  # purple
]


def gem_sheet():
    out = Image.new("RGBA", (CELL * len(GEM_SPARKLE), CELL * len(GEM_TIERS)), (0, 0, 0, 0))
    for r, (body, facet) in enumerate(GEM_TIERS):
        PAL["J"], PAL["j"] = hexc(body), hexc(facet)  # render() reads PAL now
        for c, sparkle in enumerate(GEM_SPARKLE):
            fr = [list(row) for row in GEM]
            for y, x in sparkle:
                fr[y][x] = "q"
            out.paste(render(["".join(row) for row in fr]), (c * CELL, r * CELL))
    return out


# ---------------------------------------------------------------- passive icons
ICONS = {
    "bloodied_blade": [  # might
        "............WW..",
        "...........WWW..",
        "..........WWW...",
        ".........WWW....",
        "........WWW.....",
        ".......WWW......",
        "..Y...WWW.......",
        "...YYWWW........",
        "....YYW.........",
        "....BYY.........",
        "...BB..Y........",
        "..BB............",
        ".YB.............",
    ],
    "iron_ward": [  # armor
        "....WWWWWWWW....",
        "...WWRRRRRRWW...",
        "...WRRRYYRRRW...",
        "...WRRRYYRRRW...",
        "...WRYYYYYYRW...",
        "...WRRRYYRRRW...",
        "...WRRRYYRRRW...",
        "....WRRYYRRW....",
        ".....WRRRRW.....",
        "......WRRW......",
        ".......WW.......",
    ],
    "winged_boots": [  # move speed
        "..w.............",
        ".ww..BBBB.......",
        "www..BBBB.......",
        ".ww..BBBB.......",
        "..w..BBBB.......",
        ".....BBBB.......",
        ".....BBBBBBBB...",
        ".....BBBBBBBBB..",
        ".....hhhhhhhhh..",
    ],
    "lodestone": [  # magnet
        "...WWW....WWW...",
        "...WWW....WWW...",
        "...RRR....RRR...",
        "...RRR....RRR...",
        "...RRR....RRR...",
        "...RRRR..RRRR...",
        "....RRRRRRRR....",
        ".....RRRRRR.....",
    ],
    "sand_clock": [  # cooldown
        "...BBBBBBBBBB...",
        "....llllllll....",
        "....lffffffl....",
        ".....lffffl.....",
        "......lffl......",
        ".......ll.......",
        "......l..l......",
        ".....l.ff.l.....",
        "....lffffffl....",
        "....llllllll....",
        "...BBBBBBBBBB...",
    ],
    "heart_locket": [  # max hp (also the heal fallback icon)
        "...RRR....RRR...",
        "..RRRRR..RRRRR..",
        "..RwRRRRRRRRRR..",
        "..RRRRRRRRRRRR..",
        "...RRRRRRRRRR...",
        "....RRRRRRRR....",
        ".....RRRRRR.....",
        "......RRRR......",
        ".......RR.......",
    ],
}


# ---------------------------------------------------------------- phase 4 passive icons
ICONS.update({
    "smoking_censer": [  # area
        "..n........n....",
        ".nnn......nnn...",
        "..n...nn...n..n.",
        "......nnn....nnn",
        ".......n......n.",
        ".......W........",
        "......W.W.......",
        ".....W...W......",
        "....W.....W.....",
        "...EEEEEEEEE....",
        "...EaEEaEEaE....",
        "...EEEEEEEEE....",
        "....EEEEEEE.....",
        ".....EEEEE......",
        "......EEE.......",
        ".....EEEEE......",
    ],
    "silvered_mirror": [  # amount
        ".....EEEEEE.....",
        "....EAAAAAAE....",
        "...EAiAAAAAAE...",
        "...EAiAAAAAAE...",
        "...EAAAAAAAAE...",
        "...EAAAAAAAAE...",
        "...EAAAAAAiAE...",
        "....EAAAAAiE....",
        ".....EEEEEE.....",
        ".......EE.......",
        ".......ZZ.......",
        ".......ZZ.......",
        ".......ZZ.......",
        ".......EE.......",
    ],
    "raven_feather": [  # projectile speed
        ".............11.",
        "...........1111.",
        "..........11111.",
        ".........111i11.",
        "........111i111.",
        ".......111i111..",
        "......111i111...",
        ".....111i111....",
        "....111i111.....",
        "...111i111......",
        "...11i111.......",
        "....i11.........",
        "...i............",
        "..i.............",
    ],
    "votive_candle": [  # duration
        ".......a........",
        "......aaa.......",
        "......aqa.......",
        "......aqa.......",
        ".......d........",
        ".....cccccc.....",
        ".....cccccc.....",
        ".....cccccc.....",
        ".....cccccc.....",
        ".....cccccc.....",
        ".....cccccc.....",
        "....EEEEEEEE....",
        "...EEEEEEEEEE...",
        "....EEEEEEEE....",
    ],
    "mandrake_root": [  # recovery
        "......3...3.....",
        ".....333.333....",
        "......33333.....",
        ".......333......",
        "........2.......",
        "......222222....",
        ".....22222222...",
        ".....22e22e22...",
        ".....222mm222...",
        "......222222....",
        ".....2.2222.2...",
        "....2..2..2..2..",
        ".......2..2.....",
        "......2....2....",
    ],
    "lucky_horseshoe": [  # luck
        ".......q........",
        "......qiq.......",
        "..EEE..q...EEE..",
        "..EeE......EeE..",
        "..EEE......EEE..",
        "..EEE......EEE..",
        "..EeE......EeE..",
        "..EEE......EEE..",
        "..EEEE....EEEE..",
        "...EeEE..EEeE...",
        "....EEEEEEEE....",
        ".....EEEEEE.....",
    ],
    "hunters_eye": [  # crit
        ".......q........",
        "......qiq.......",
        ".......q........",
        ".....kkkkkk.....",
        "...kkwwwwwwkk...",
        "..kwwwRRRRwwwk..",
        ".kwwwRRmmRRwwwk.",
        ".kwwwRRmmRRwwwk.",
        "..kwwwRRRRwwwk..",
        "...kkwwwwwwkk...",
        ".....kkkkkk.....",
    ],
})


# ---------------------------------------------------------------- evolution icons
def icon_seraphs_halo():
    cv = [list(r) for r in recolor(ICON_AURA, {"Q": "E", "q": "u"})]
    for y in range(4, 10):
        for x in range(4, 12):
            cv[y][x] = "."
    stamp(cv, [".RR.RR.", "RRRRRRR", "RwRRRRR", ".RRRRR.", "..RRR..", "...R..."], 4, 4)
    return join(cv)


def icon_thornstorm():
    cv = [list(r) for r in recolor(WEAPON_ICONS["silverthorn_knives"], {"W": "I", "B": "Z", "Y": "E"})]
    for y in range(0, 6):
        cv[y][7] = cv[y][8] = "I"
    cv[1][7] = "i"
    return join(cv)


def icon_eternal_rosary():
    orb = [".EEE.", "EuuEE", "EuEEE", "EEEEE", ".EEE."]
    cv = blank(16, 16)
    for k in range(32):
        a = k / 32 * 2 * math.pi
        x, y = int(round(7.5 + math.cos(a) * 7)), int(round(7.5 + math.sin(a) * 7))
        if k % 2 == 0 and 0 <= x < 16 and 0 <= y < 16:
            cv[y][x] = "c"
    for k in range(5):
        a = -math.pi / 2 + k / 5 * 2 * math.pi
        x, y = int(round(7.5 + math.cos(a) * 5.5)) - 2, int(round(7.5 + math.sin(a) * 5.5)) - 2
        stamp(cv, orb, max(0, min(11, x)), max(0, min(11, y)))
    stamp(cv, [".q.", "qiq", ".q."], 6, 6)
    return join(cv)


def icon_font_of_saints():
    return recolor(WEAPON_ICONS["hallowed_vial"], {"Q": "U", "q": "u", "B": "E"})


def icon_radiant_crucifix():
    cv = [list(r) for r in recolor(WEAPON_ICONS["pilgrims_cross"], {"X": "E", "Y": "i", "r": "R"})]
    for y, x in [(0, 2), (1, 3), (0, 13), (1, 12), (12, 3), (13, 2), (12, 12), (13, 13), (8, 1), (8, 14)]:
        if cv[y][x] == ".":
            cv[y][x] = "q"
    return join(cv)


# ---------------------------------------------------------------- chest
CHEST = [
    "..EZZZZZZZZZZE..",
    ".EZZZZZZZZZZZZE.",
    ".EZZZZZZZZZZZZE.",
    ".EEEEEEEEEEEEEE.",
    ".EZZZZZEEZZZZZE.",
    ".EZZZZZEeZZZZZE.",
    ".EZZZZZEEZZZZZE.",
    ".EZZZZZZZZZZZZE.",
    ".EZZZZZZZZZZZZE.",
    ".EEEEEEEEEEEEEE.",
]
CHEST_OPEN = [
    "...q....q....q..",
    "....q...q...q...",
    ".....q..q..q....",
    ".EEEEEEEEEEEEEE.",
    ".EZZZZZZZZZZZZE.",
    ".EEEEEEEEEEEEEE.",
    "..quuuuuuuuuuq..",
    ".EuuuuuuuuuuuuE.",
    ".EEEEEEEEEEEEEE.",
    ".EZZZZZEEZZZZZE.",
    ".EZZZZZEeZZZZZE.",
    ".EZZZZZZZZZZZZE.",
    ".EZZZZZZZZZZZZE.",
    ".EEEEEEEEEEEEEE.",
]
# per frame: glint column on the gold band (row 9 of the 16-row cell) + sparkle centres
CHEST_SHINE = [
    (3, []),
    (7, [(2, 3)]),
    (11, [(1, 12)]),
    (None, [(3, 8)]),
]


def chest_frames():
    frames = []
    for glint, sparks in CHEST_SHINE:
        cv = blank(16, 16)
        stamp(cv, CHEST, 0, 6)
        if glint is not None:
            cv[9][glint] = "i"
        for y, x in sparks:
            cv[y][x] = "i"
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                cv[y + dy][x + dx] = "q"
        frames.append(join(cv))
    return frames


def save_icon(rows, name):
    render(rows).resize((CELL * 2, CELL * 2), Image.NEAREST).save(os.path.join(ART, "icons", name + ".png"))


# ---------------------------------------------------------------- ground
def tile_noise(size, cells, seed):
    """Tileable value noise in [0,1]."""
    rnd = random.Random(seed)
    lattice = [[rnd.random() for _ in range(cells)] for _ in range(cells)]
    out = [[0.0] * size for _ in range(size)]
    for y in range(size):
        for x in range(size):
            fx, fy = x * cells / size, y * cells / size
            x0, y0 = int(fx), int(fy)
            tx, ty = fx - x0, fy - y0
            tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
            a = lattice[y0 % cells][x0 % cells]
            b = lattice[y0 % cells][(x0 + 1) % cells]
            c = lattice[(y0 + 1) % cells][x0 % cells]
            d = lattice[(y0 + 1) % cells][(x0 + 1) % cells]
            out[y][x] = (a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty
    return out


def ground_tile(size=128):
    rnd = random.Random(7)
    big = tile_noise(size, 6, 1)
    small = tile_noise(size, 24, 2)
    greens = [hexc("#2b4a2e"), hexc("#325634"), hexc("#3a623a"), hexc("#436e41")]
    dirt = [hexc("#4a3d31"), hexc("#574836")]
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            n = big[y][x] * 0.7 + small[y][x] * 0.3
            if n < 0.22:
                c = dirt[0] if small[y][x] < 0.5 else dirt[1]
            else:
                idx = max(0, min(3, int((n - 0.22) / 0.78 * 4 + rnd.random() * 0.9 - 0.2)))
                c = greens[idx]
            px[x, y] = c
    # blades of grass and pebbles, wrap-safe
    for _ in range(260):
        x, y = rnd.randrange(size), rnd.randrange(size)
        if big[y][x] > 0.35:
            px[x, y] = hexc("#4f8048")
            px[x, (y - 1) % size] = hexc("#5f9455")
    for _ in range(40):
        x, y = rnd.randrange(size), rnd.randrange(size)
        px[x, y] = hexc("#8d8a80")
        px[(x + 1) % size, y] = hexc("#6f6c64")
    return img


# ---------------------------------------------------------------- phase 5 enemies
def swap_rows(rows, changes):
    """Copy of `rows` with {row_index: new_row} replaced."""
    out = list(rows)
    for y, r in changes.items():
        out[y] = r
    return out


def mirror(left):
    """Symmetric sprite from its left half (each row + its reverse)."""
    return [r + r[::-1] for r in left]


def check(rows, w, name):
    for y, r in enumerate(rows):
        assert len(r) == w, "%s row %d is %d wide, expected %d" % (name, y, len(r), w)
    return rows


# Crypt Acolyte: ranged cultist, hurls blood orbs (EnemyData RANGED).
ACOLYTE_PAL = {
    "H": hexc("#5e1a33"),  # hood
    "h": hexc("#1e0b16"),  # hood shadow
    "e": hexc("#ffcf4a"),  # glowing eyes
    "C": hexc("#7d2342"),  # robe
    "S": hexc("#c9b8a6"),  # bony hand
    "O": hexc("#e8213f"),  # blood orb
    "o": hexc("#ffd3dc"),  # orb core
}
ACOLYTE = check([
    "............OO..",
    "......HHH..OooO.",
    ".....HHHHH.OooO.",
    "....HHHHHHH.OO..",
    "....HHhhhhH..S..",
    "...HHhehheH..S..",
    "...HHhhhhhH.CC..",
    "...HHHhhhHHCCC..",
    "..CCHHHHHHCCC...",
    "..CCCCCYYCCCC...",
    ".SCCCCCYYCCCC...",
    "..CCCCCYYCCCC...",
    "..CCCCCYYCCCC...",
    "..CCCCCYYCCCCC..",
    ".CCCCCCYYCCCCC..",
    ".CCCCCCCCCCCCCC.",
], 16, "acolyte")
ACOLYTE_HEM = [
    {},
    {13: "..CCCCCYYCCCC...", 14: "..CCCCCYYCCCCC..", 15: "..CCCCCCCCCCCCC."},
    {},
    {13: "...CCCCYYCCCCC..", 14: "..CCCCCYYCCCCCC.", 15: ".CCCCCCCCCCCCC.."},
]
ACOLYTE_ORB = [
    {},
    {1: "......HHH..OoOO.", 2: ".....HHHHH.OOoO."},
    {0: "...........oOOo.", 3: "....HHHHHHHoOOo."},
    {1: "......HHH..OOoO.", 2: ".....HHHHH.OoOO."},
]


def acolyte_frames():
    return [render(check(swap_rows(swap_rows(ACOLYTE, ACOLYTE_HEM[i]), ACOLYTE_ORB[i]), 16, "acolyte"),
                   pal=ACOLYTE_PAL, flat="hoe") for i in range(4)]


# Grave Wisp: drifts in rings and lines (EnemyData DRIFT).
WISP_PAL = {"G": hexc("#5fb8a8"), "g": hexc("#c8f7ec")}
WISP_HEAD = [
    "......GGGG......",
    "....GGggggGG....",
    "...GggggggggG...",
    "..GggggggggggG..",
    "..GggeeggeeggG..",
    "..GggeeggeeggG..",
    "..GggeeggeeggG..",
    "..GgggggmmgggG..",
    "...GggggmmgggG..",
    "...GGgggggggG...",
]
WISP_TAILS = [
    ["....GGggggGG....", ".....GGGGG......", "......GGG.......", ".......G........"],
    ["....GGggggGG....", "....GGGGG.......", "...GGG..........", "..GG............"],
    ["....GGggggGG....", "......GGGGG.....", ".......GGG......", "........G......."],
    ["....GGggggGG....", "......GGGGG.....", "........GGG.....", "..........GG...."],
]


def wisp_frames():
    out = []
    for i, tail in enumerate(WISP_TAILS):
        lift = ["." * 16] * (2 if i % 2 == 0 else 1)
        out.append(render(check(WISP_HEAD + tail, 16, "wisp") + lift, pal=WISP_PAL, flat="g"))
    return out


# Cinder Skull: crosses the field in straight lines (EnemyData DRIFT).
SKULL_PAL = {"A": hexc("#e8582a"), "a": hexc("#ffc845"), "x": hexc("#fff1a0")}
SKULL_FLAMES = [
    ["..a...", ".aAa..", "aAAAa.", ".aAAA", "aAAAA", ".aAAA", "aaAAA", ".aAAAA", "..aaAA", "....aa"],
    [".a....", "aAa...", ".aAAa.", "aAAAA", ".aAAA", "aAAAA", ".aAAA", "aaAAAA", "...aAA", "...aa."],
    ["...a..", "..aAa.", ".aAAa.", "aAAAA", "aAAAA", ".aAAA", "aAAAA", ".aAAAA", "..aaAA", "...aa."],
]
SKULL_BONE = [
    "................",
    "........KKKKK...",
    "......KKKKKKKKK.",
    ".....KKKKKKKKKK.",
    ".....KKeeKKKeeK.",
    ".....KKexKKKexK.",
    ".....KKKKKkKKKK.",
    "......KKKkkkKK..",
    "......KKKKKKKK..",
    "......KwKwKwK...",
    "......KKwKwKK...",
]


def skull_frames():
    out = []
    for flames in (SKULL_FLAMES[0], SKULL_FLAMES[1], SKULL_FLAMES[0], SKULL_FLAMES[2]):
        rows = [list(r) for r in SKULL_BONE]
        for y, f in enumerate(flames):
            for x, ch in enumerate(f):
                if ch != "." and rows[y + 1][x] == ".":
                    rows[y + 1][x] = ch
        out.append(render(["".join(r) for r in rows] + ["." * 16] * 4, pal=SKULL_PAL, flat="ax"))
    return out


# ---------------------------------------------------------------- large enemies (32 px)
BIG = 32
BIG_CELL = BIG + 2

# Gravebound Brute: slow tank hauling a tombstone (large sheet row 0).
BRUTE_PAL = {
    "G": hexc("#7d8f63"),  # dead skin
    "X": hexc("#6c7180"),  # iron collar / shackles
    "T": hexc("#6b5640"),  # rags
    "t": hexc("#3f3226"),  # belt
    "O": hexc("#8a8994"),  # tombstone
    "v": hexc("#557f3c"),  # moss
}
BRUTE = check([
    "............GGGGGG..............",
    "..........GGGGGGGGGG............",
    ".........GGGGGGGGGGGG...........",
    ".........GGGGGrrGGGrrG..........",
    ".........GGGGGGGGGGGGG..........",
    "..........GGGmwmwmwmGG..........",
    "..........GGGGmmmmmmG...........",
    "......XXXXXXXGGGGGGXXXXX........",
    "....GGGGXXXXXXXXXXXXXXXXGGG.....",
    "...GGGGGGGGGGXGGGGGGGGGGGGGG....",
    "..GGGGGGGGGGGXGGGGGGGGGGGGGGG...",
    "..GGGGGGGGGGGXGGGGGGGGGGGGGGGG..",
    ".GGGGG.GGGGGGXGGGGGGGGGG.GGGGG..",
    ".GGGG..GGGGGGGGGGGGGGGGG..GGGG..",
    ".GGGG..TTTTTTTTTTTTTTTTT..GGGG..",
    ".GGGG..tttttttXXtttttttt.OOOOOO.",
    ".GGGG..TTTTTTTXXTTTTTTTTOOOOOOOO",
    "GGGGG..TTTTTTTTTTTTTTTTTOOOdOOOO",
    "GGGG...TTTT.TTTTTT.TTTTTOOdddOOO",
    "GGG....TTT..TTTTT...TTTTOOOdOOOO",
    ".......GGGG......GGGG..vOOOdOOOO",
    "......GGGGG......GGGGG.vOOOOOOOO",
    "......GGGGG......GGGGG.vvOOOOOOO",
    "......XXXXX......XXXXX..vvOOOOOO",
    ".....GGGGGG......GGGGGG.........",
    "....GGGGGGG......GGGGGGG........",
], BIG, "brute")
BRUTE_LEGS = [
    {},
    {20: "........GGGG.....GGGG..vOOOdOOOO", 21: ".......GGGG.......GGGGvOOOOOOOOO",
     22: "......GGGG.........GGGvvOOOOOOO.", 23: "......XXXX.........XXXXvvOOOOOO.",
     24: ".....GGGGGG........GGGGGG.......", 25: "....GGGGGGG........GGGGGGG......"},
    {},
    {20: ".......GGGG.....GGGG...vOOOdOOOO", 21: "........GGGG...GGGG....vOOOOOOOO",
     22: ".........GGGG.GGGG.....vvOOOOOOO", 23: ".........XXXX.XXXX......vvOOOOOO",
     24: "........GGGGGGGGGGG.............", 25: ".......GGGGGG.GGGGGG............"},
]


def brute_frames():
    return [render(check(swap_rows(BRUTE, legs), BIG, "brute"), BIG, BIG, BRUTE_PAL, "v")
            for legs in BRUTE_LEGS]


# The Hollow Abbot: first boss (large row 1). Mitre, skull, crozier.
ABBOT_PAL = {
    "P": hexc("#4a2f6b"),  # robe
    "p": hexc("#211331"),  # robe shadow / hood
    "x": hexc("#9dff7a"),  # grave-light eyes
    "Z": hexc("#6b4a2a"),  # crozier shaft
}
ABBOT = check([
    "..............cc...........EEE..",
    ".............cEEc.........E...E.",
    "............cccEcc........E...E.",
    "............ccEEEc........E..E..",
    "...........ccccEccc.......E.....",
    "...........ccccEccc.......E.....",
    "...........EEEEEEEE.......E.....",
    "...........pKKKKKKp.......E.....",
    "...........pKxKKxKp.......Z.....",
    "...........pKKKKKKp.......Z.....",
    "...........ppKwwKpp.......Z.....",
    "........PPPPpKKKKpPPPP....Z.....",
    "......PPPPPPPpppppPPPPPP..Z.....",
    ".....PPPPPPPPEEEEPPPPPPPKKKK....",
    "....PPPPPPPPPEuEEPPPPPPPKKK.....",
    "....PPPPPPPPPEEEEPPPPPPPP.Z.....",
    "...PPPPPPPPPPEEEEPPPPPPPP.Z.....",
    "...PPPPPPPPPPEEEEPPPPPPP..Z.....",
    "...PPKKKPPPPPEuEEPPPPPPP..Z.....",
    "...PPKKKPPPPPEEEEPPPPPPP..Z.....",
    "...PPPPPPPPPPEEEEPPPPPPPP.Z.....",
    "..PPPPPPPPPPPEEEEPPPPPPPP.Z.....",
    "..PPPPPPPPPPPEEEEPPPPPPPPPZ.....",
    "..PPPPPPPPPPPEuEEPPPPPPPPPZ.....",
    ".PPPPPPPPPPPPEEEEPPPPPPPPPZ.....",
    ".PPPPPPPPPPPPEEEEPPPPPPPPPZP....",
    ".PPPPPPPPPPPPEEEEPPPPPPPPPZPP...",
    "PPPPPPPPPPPPPEEEEPPPPPPPPPZPPP..",
    "PPPPPPPPPPPPPEEEEPPPPPPPPPZPPPP.",
    "PpPPpPPPpPPPPEEEEPPPpPPPpPZPpPP.",
    ".p..p...p....pp....p...p..Z.p...",
], BIG, "abbot")
ABBOT_HEM = [
    {},
    {29: "pPPpPPPpPPPPPEEEEPPpPPPpPPZPPpP.", 30: "p..p...p....p..p...p...p..Zp...."},
    {8: "...........pKKKKKKp.......Z....."},
    {29: "PPpPPpPPPpPPPEEEEPPPPpPPPpZpPPP.", 30: "..p..p...p...pp.....p...p.Z..p.."},
]


def abbot_frames():
    return [render(check(swap_rows(ABBOT, hem), BIG, "abbot"), BIG, BIG, ABBOT_PAL, "px")
            for hem in ABBOT_HEM]


# Vesperine, Bride of Thorns: second boss (large row 2). Cape spread like wings.
VESP_PAL = {
    "h": hexc("#2a1430"),  # hair
    "S": hexc("#ecd9d4"),  # pale skin
    "V": hexc("#241226"),  # cape outside
    "R": hexc("#a3142f"),  # cape lining
    "D": hexc("#6e0f24"),  # gown
    "l": hexc("#d61f3f"),  # lips
}
VESP_LEFT = [
    "..............hh",
    ".............hhh",
    "............hhhh",
    "...........hhhEh",
    ".V.........hSSSS",
    ".VV.......RhSrSS",
    ".VRV......RRSSSS",
    ".VRRV.....RRhSSl",
    ".VRRRV....RRRSSS",
    ".VRRRRV...RRRRSS",
    ".VRRRRRV..RRRREE",
    ".VRRRRRRVVVRRRDD",
    "..VRRRRRRRRVSDDD",
    "..VRRRRRRRRVSDDD",
    "..VRRRRRRRRVDDDD",
    "...VRRRRRRRVDDDE",
    "...VRRRRRRVDDDDD",
    "...VRRRRRRVDDDDD",
    "....VRRRRRVDDDDD",
    "....VRRRRVDDDDDD",
    "....VRVRRVDDDDDD",
    ".....V.VRVDDDDDD",
    ".......VVVDDDDDD",
    "........VDDDDDDD",
    ".........DDDDDDD",
    "........DDDDDDDD",
    "........DDDDDDDD",
    ".......DDDDDDDDD",
    ".......DDDDDDDDD",
    "......DDDDDDDDDD",
    "......D.DD.DDDDD",
]
VESP_FLAP = {
    4: "...........hSSSS",
    5: "V.........RhSrSS",
    6: "VV........RRSSSS",
    7: "VRV.......RRhSSl",
    8: "VRRV......RRRSSS",
    9: "VRRRV.....RRRRSS",
    10: "VRRRRV....RRRREE",
    11: "VRRRRRVVVVVRRRDD",
}
VESP_HEM = {
    29: "......DDDDDDDDDDDDDDDDDDDD......",
    30: ".....D.DDD.DDDD..DDDD.DDD.D.....",
}


def vesperine_frames():
    base = check(mirror(VESP_LEFT), BIG, "vesperine")
    flap = check(mirror(swap_rows(VESP_LEFT, VESP_FLAP)), BIG, "vesperine flap")
    hem = check(swap_rows(base, VESP_HEM), BIG, "vesperine hem")
    return [render(r, BIG, BIG, VESP_PAL, "l") for r in (base, flap, hem, flap)]


# Knellwraith: the end-of-night hunter (large row 3). Hooded shroud, cracked bell.
KNELL_PAL = {
    "V": hexc("#2b2335"),  # shroud
    "v": hexc("#4a3d5c"),  # shroud wisps
    "h": hexc("#07050b"),  # hood void
    "x": hexc("#7ff6ff"),  # eyes
    "B": hexc("#b07a2e"),  # bronze bell
    "b": hexc("#2a1a0c"),  # crack / mouth of the bell
}
KNELL = check([
    "..............VVVV..............",
    "............VVVVVVVV............",
    "...........VVVVVVVVVV...........",
    "..........VVVVVVVVVVVV..........",
    "..........VVVhhhhhhVVV..........",
    ".........VVVhhhhhhhhVVV.........",
    ".........VVVhhxhhxhhVVV.........",
    ".........VVVhhhhhhhhVVV.........",
    ".........VVVVhhhhhhVVVV.........",
    "........VVVVVVhhhhVVVVVV........",
    ".......VVVVVVVVVVVVVVVVVV.......",
    "......VVVVVVVVVVVVVVVVVVVV......",
    ".....VVVVVVVVVVVVVVVVVVVVVVKK...",
    ".....VVVVVVVVVVVVVVVVVVVV..KKK..",
    "....VVVVVVVVVVVVVVVVVVVVV...X...",
    "....VVKKVVVVVVVVVVVVVVVVV...X...",
    "....VVKKVVVVVVVVVVVVVVVVV..BBB..",
    "...VVVVVVVVVVVVVVVVVVVVV..BBBBB.",
    "...VVVVVVVVVVVVVVVVVVVVV..BBbBB.",
    "...VVVVVVVVVVVVVVVVVVVVV.BBBBbBB",
    "...VVVVVVVVVVVVVVVVVVVVV.BBBbBBB",
    "..VVVVVVVVVVVVVVVVVVVVVV.BBBBbBB",
    "..VVVVVVVVVVVVVVVVVVVVVVBBBBBBBB",
    "..VVVVVVVVVVVVVVVVVVVVV.BbbbbbbB",
    "..VVVVVVVVVVVVVVVVVVVVV.........",
    "..VVVVVVVVVVVVVVVVVVVVV.........",
    "..VVVvVVVVVVvVVVVVVvVVV.........",
    "...VvVVvVVVvvVVvVVVvVV..........",
    "...v.Vv.vVv..vVv.vVv.v..........",
    "....v..v..v..v...v...v..........",
], BIG, "knellwraith")
KNELL_WISPS = [
    {},
    {28: "....vVv.vVv.vVv.vVv.v...........", 29: "...v...v...v...v...v............"},
    {6: ".........VVVhhhhhhhhVVV........."},
    {28: "..v.vVv.Vv..vVv..vVv.v..........", 29: ".....v...v...v...v...v.........."},
]


def knell_frames():
    out = []
    for i, w in enumerate(KNELL_WISPS):
        rows = [list(r) for r in check(swap_rows(KNELL, w), BIG, "knellwraith")]
        for x, y0 in ((9, 18), (15, 17), (20, 19)):  # shroud folds
            for y in range(y0, 26):
                if rows[y][x] == "V":
                    rows[y][x] = "v"
        rows = ["".join(r) for r in rows]
        rows = rows + ["." * BIG] * (2 if i % 2 == 0 else 1)  # hovers and bobs
        out.append(render(rows, BIG, BIG, KNELL_PAL, "vhxb"))
    return out


# ---------------------------------------------------------------- enemy shots
SHOT_PAL = {
    "O": hexc("#e8213f"), "o": hexc("#ffd3dc"), "p": hexc("#ff7a9a"),
    "y": hexc("#ffe6ee"),
}
BLOOD_ORB = [  # flies right (FACE_VELOCITY); tail trails left
    "........OOOO....",
    "...pp..OooOOO...",
    ".pppppOooOOOOO..",
    "pppppOOoOOOOOO..",
    ".pppppOOOOOOOO..",
    "...pp..OOOOOO...",
    "........OOOO....",
]
BONE_SHARD = [  # spins
    ".KK..........KK.",
    "KKKK........KKKK",
    ".KKKKKKKKKKKKKK.",
    ".KKKKKKKKKKKKKK.",
    "KKKK........KKKK",
    ".KK..........KK.",
]
THORN_STAR = [
    ".......y........",
    ".......I........",
    "......III.......",
    "......III.......",
    ".....IIoII......",
    "yIIIIIoooIIIIIy.",
    ".....IIoII......",
    "......III.......",
    "......III.......",
    ".......I........",
    ".......y........",
]


def enemy_shot_sheet():
    """Row = EnemyData.shot_row: 0 blood orb (Crypt Acolyte), 1 bone shard
    (Hollow Abbot), 2 thorn star (Vesperine)."""
    orb = [render(centered(with_pixels(BLOOD_ORB, px, "o")), pal=SHOT_PAL, flat="op")
           for px in ([], [(3, 10)], [(2, 11), (4, 10)], [(3, 9)])]
    bone = [render(centered(BONE_SHARD), pal=SHOT_PAL)] * 4
    star = [render(centered(with_pixels(THORN_STAR, px, "y")), pal=SHOT_PAL, flat="oy")
            for px in ([], [(2, 4), (8, 10)], [], [(2, 10), (8, 4)])]
    return sheet([orb, bone, star], 4)


# ---------------------------------------------------------------- phase 6 pickups
# Row = PickupData.sprite_row in art/sprites/pickups.png (row 0 = chest).
FOOD_PAL = {
    "B": hexc("#c4843c"),  # bread crust
    "o": hexc("#f3dca0"),  # scored crumb
    "M": hexc("#9c4128"),  # roast meat
    "m": hexc("#e88a4a"),  # roast glaze
    "y": hexc("#a8741c"),  # coin engraving
    "Z": hexc("#86552f"),  # leather
    "K": hexc("#3e3b55"),  # bomb iron
    "g": hexc("#7cff8a"),  # magnet field crackle (flat)
}
BREAD = [  # communion loaf, cross scored on the crust
    ".....BBBBBB.....",
    "...BBBBBBBBBB...",
    "..BBBBBBoBBBBB..",
    "..BBBBBBoBBBBB..",
    ".BBBBoooooooBBB.",
    ".BBBBBBBoBBBBBB.",
    ".BBBBBBBoBBBBBB.",
    ".BBBBBBBBBBBBBB.",
    "..BBBBBBBBBBBB..",
    "...BBBBBBBBBB...",
]
ROAST = [  # roast fowl leg, bone to the right
    "............ww..",
    "...........wwww.",
    "....MMMM...wwww.",
    "..MMMMMMMM..ww..",
    ".MMmmMMMMMMww...",
    ".MmmMMMMMMMw....",
    ".MMmMMMMMMMM....",
    ".MMMMMMMMMMM....",
    "..MMMMMMMMM.....",
    "...MMMMMMM......",
]
MAGNET = [  # horseshoe lodestone magnet, steel tips
    "....RRRRRRRR....",
    "...RRRRRRRRRR...",
    "..RRRRRRRRRRRR..",
    "..RRRR....RRRR..",
    "..RRR......RRR..",
    "..RRR......RRR..",
    "..RRR......RRR..",
    "..WWW......WWW..",
    "..WWW......WWW..",
    "..WWW......WWW..",
]
# crackle between the tips per frame (row, col), drawn in "g"
MAGNET_ARCS = [
    [(9, 6), (8, 7), (9, 8), (8, 9)],
    [],
    [(8, 6), (9, 7), (8, 8), (9, 9)],
    [(1, 1), (0, 14)],
]
BOMB = [  # blessed powder bomb: iron shell, gold cross, lit fuse
    ".........nn.....",
    "........n.......",
    ".....XXXX.......",
    "...KKKKKKKK.....",
    "..KKKKKKKKKK....",
    ".KKKKKEKKKKKK...",
    ".KKKKEEEKKKKK...",
    ".KKKKKEKKKKKK...",
    ".KKKKKEKKKKKK...",
    "..KKKKKKKKKK....",
    "...KKKKKKKK.....",
]
# fuse spark per frame: (row, col) of the core + whether it flares
BOMB_SPARKS = [((0, 11), True), ((0, 11), False), ((0, 11), True), ((1, 12), False)]
POUCH = [
    "......E.E.......",
    ".....EEEEE......",
    "......ZZZ.......",
    ".....hYYYh......",
    "....ZZZZZZZ.....",
    "...ZZZZZZZZZ....",
    "..ZZZZZZZZZZZ...",
    "..ZZZZZEEZZZZ...",
    "..ZZZZZEyZZZZ...",
    "..ZZZZZZZZZZZ...",
    "...ZZZZZZZZZ....",
]


def sparkle_frames(base, sparks, pal, flat=""):
    """4 frames of `base` with white glints (list of (row, col) per frame)."""
    out = []
    for pts in sparks:
        cv = [list(r) for r in base]
        for y, x in pts:
            if 0 <= y < len(cv) and 0 <= x < 16:
                cv[y][x] = "i"
        out.append(render(join(cv), pal=pal, flat="io" + flat))
    return out


def magnet_frames():
    out = []
    for k, arcs in enumerate(MAGNET_ARCS):
        cv = [list(r) for r in MAGNET]
        for y, x in arcs:
            cv[y][x] = "g"
        if k == 1:
            cv[7][3] = "i"
        out.append(render(join(cv), pal=FOOD_PAL, flat="gi"))
    return out


def bomb_frames():
    out = []
    for (y, x), flare in BOMB_SPARKS:
        cv = [["."] * 16 for _ in range(3)] + [list(r) for r in BOMB]
        y += 2
        cv[y][x] = "i"
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            cv[y + dy][x + dx] = "f" if flare else "a"
        if flare:
            cv[y - 2][x + 2] = "a"
        cv[9][4] = "i"  # glint on the shell
        out.append(render(join(cv), pal=FOOD_PAL, flat="nfai"))
    return out


def coin_frames():
    """Spinning gold coin: face, three-quarter, edge, three-quarter."""
    out = []
    for half in (4, 3, 1, 3):
        cv = blank(16, 9)
        for y in range(9):
            dy = (y - 4) / 4.5
            w = half * math.sqrt(max(0.0, 1.0 - dy * dy))
            for x in range(16):
                if abs(x - 7.5) <= w + 0.25:
                    cv[y][x] = "E"
        if half >= 3:  # engraved cross on the face
            for y in range(2, 7):
                cv[y][7] = "y"
            cv[3][6] = cv[3][8] = "y"
        if half == 4:
            cv[2][5] = "i"
        out.append(render(join(cv), pal=FOOD_PAL, flat="yi"))
    return out


def pickup_sheet():
    """Row = PickupData.sprite_row: 0 chest, 1 communion bread, 2 roast fowl,
    3 magnet, 4 blessed bomb, 5 coin (spins), 6 coin pouch."""
    bread = sparkle_frames(BREAD, [[], [(2, 4)], [], [(5, 12)]], FOOD_PAL)
    roast = sparkle_frames(ROAST, [[], [(4, 3)], [(5, 2)], []], FOOD_PAL)
    pouch = sparkle_frames(POUCH, [[], [(0, 6)], [(1, 8)], []], FOOD_PAL)
    return sheet([chest_frames(), bread, roast, magnet_frames(), bomb_frames(),
                  coin_frames(), pouch], 4)


# ---------------------------------------------------------------- phase 6 breakables
# Extra rows in art/sprites/enemies.png (BreakableData.sprite_row):
# 7 iron lantern, 8 brazier, 9 supply crate, 10 grave cross with candle.
PROP_PAL = {
    "X": hexc("#7b7f92"),  # wrought iron
    "P": hexc("#2f2a3c"),  # dark iron post
    "Z": hexc("#8a5a32"),  # crate wood
    "h": hexc("#4d2f1b"),  # crate brace (flat)
    "D": hexc("#7a7886"),  # grave stone
    "d": hexc("#4a4856"),  # engraving / moss shadow
    "g": hexc("#4f8a3c"),
}
LANTERN = [
    "......XXXX......",
    ".....XXXXXX.....",
    "......X..X......",
    "......X..X......",
    "......X..X......",
    ".....XXXXXX.....",
    ".......PP.......",
    ".......PP.......",
    ".......PP.......",
    ".......PP.......",
    ".......PP.......",
    ".......PP.......",
    "......PPPP......",
    ".....PPPPPP.....",
]
# flame inside the glass per frame
LANTERN_FLAME = [
    ["aa", "ff", "aa"],
    ["fa", "ff", "aa"],
    ["aa", "fi", "aa"],
    ["af", "ff", "aa"],
]
BRAZIER = [
    "...XXXXXXXXXX...",
    "...XXXXXXXXXX...",
    "....XXXXXXXX....",
    ".....XXXXXX.....",
    "......PPPP......",
    ".......PP.......",
    ".......PP.......",
    "......P..P......",
    ".....P....P.....",
    "....PP....PP....",
]
BRAZIER_FIRE = [
    [".....a..a.......", "....aafaaa.a....", "...aaffffaa....."],
    ["......a...a.....", "....aaafaaa.....", "...aafffffa....."],
    ["....a....a......", ".....aafaaa.....", "...aaffifaa....."],
    [".......a..a.....", "...a.aafaaa.....", "...aaffffaaa...."],
]
CRATE = [
    "..ZZZZZZZZZZZZ..",
    "..hhhhhhhhhhhh..",
    "..hZZZZZZZZZhh..",
    "..hhZZZZZZZhZh..",
    "..hZhZZZZZhZZh..",
    "..hZZhZZZhZZZh..",
    "..hZZZhZhZZZZh..",
    "..hZZZZhZZZZZh..",
    "..hZZZhZhZZZZh..",
    "..hZZhZZZhZZZh..",
    "..hZhZZZZZhZZh..",
    "..hhhhhhhhhhhh..",
]
GRAVE_CROSS = [
    "......DDDD......",
    "......DddD......",
    "..DDDDDddDDDDD..",
    "..DddddddddddD..",
    "..DDDDDddDDDDD..",
    "......DddD......",
    "......DddD......",
    "......DDDD......",
    "......DDDD......",
    "....DDDDDDDD....",
    "...gDDDDDDDDg...",
]


def lantern_frames():
    out = []
    for flame in LANTERN_FLAME:
        cv = [list(r) for r in LANTERN]
        for y, row in enumerate(flame):
            cv[2 + y][7] = row[0]
            cv[2 + y][8] = row[1]
        out.append(render(["." * 16] * 2 + join(cv), pal=PROP_PAL, flat="afih"))
    return out


def brazier_frames():
    out = []
    for fire in BRAZIER_FIRE:
        out.append(render(["." * 16] * 3 + fire + BRAZIER, pal=PROP_PAL, flat="afih"))
    return out


def crate_frames():
    return [render(CRATE, pal=PROP_PAL, flat="h")] * 4


def grave_frames():
    out = []
    for k, flame in enumerate(("a", "f", "a", "i")):
        cv = blank(16, 16)
        stamp(cv, GRAVE_CROSS, 0, 5)
        # votive candle at the foot of the cross
        cv[12][12] = "c"
        cv[13][12] = "c"
        cv[11][12] = flame
        if k == 2:
            cv[10][12] = "a"
        out.append(render(join(cv), pal=PROP_PAL, flat="afidh"))
    return out


# ---------------------------------------------------------------- phase 6 effects
# art/sprites/effects.png, 6 frames per row, played once (EffectField):
FX_FRAMES = 6
FX_PAL = {
    "O": hexc("#8c8a9a"),  # smoke
    "n": hexc("#c9c5d6"),  # smoke light
    "R": hexc("#b81e30"),  # blood
    "r": hexc("#ff5468"),  # blood light
    "Q": hexc("#5fd8c8"),  # ectoplasm
    "q": hexc("#d9fff7"),
    "M": hexc("#d8452a"),  # explosion red
    "a": hexc("#ff9a3c"),
    "f": hexc("#ffe066"),
    "Z": hexc("#9a6236"),  # splinters
    "D": hexc("#858391"),  # stone chips
    "X": hexc("#8a8ea2"),  # iron bits
    "K": hexc("#e8e2cf"),  # bone bits
    "3": hexc("#6cff7a"),  # heal green
    "u": hexc("#fff3c4"),
}


def particle_frames(seed, n, chars, speed=(3.0, 6.5), gravity=0.0, sizes=(1, 2),
                    center=(7.5, 9.0), up_bias=0.0, core=None, fade_from=3):
    """Burst of n square particles flying out from `center`. Each frame the
    particles move on, shrink, and from frame `fade_from` start to vanish."""
    rnd = random.Random(seed)
    parts = []
    for _ in range(n):
        a = rnd.uniform(0, math.tau)
        v = rnd.uniform(*speed)
        parts.append((math.cos(a) * v, math.sin(a) * v * 0.8 - up_bias,
                      rnd.choice(chars), rnd.randint(*sizes), rnd.random()))
    frames = []
    for f in range(FX_FRAMES):
        t = (f + 0.6) / FX_FRAMES * 2.1
        cv = blank()
        if core is not None:
            core(cv, f)
        for vx, vy, ch, s, die in parts:
            if f >= fade_from and die < (f - fade_from + 1) / (FX_FRAMES - fade_from + 1):
                continue
            x = center[0] + vx * t
            y = center[1] + vy * t + gravity * t * t
            s2 = max(1, s - (1 if f >= 4 else 0))
            for dy in range(s2):
                for dx in range(s2):
                    xi, yi = int(round(x)) + dx, int(round(y)) + dy
                    if 0 <= xi < 16 and 0 <= yi < 16:
                        cv[yi][xi] = ch
        frames.append(render(join(cv), pal=FX_PAL, flat="nrqafu3"))
    return frames


def disc(cv, cx, cy, r, ch, hollow=0.0):
    for y in range(16):
        for x in range(16):
            d = math.hypot(x - cx, (y - cy) * 1.1)
            if hollow <= d <= r:
                cv[y][x] = ch


def smoke_frames():
    def core(cv, f):
        r = [2.5, 4.0, 5.0, 5.5, 5.5, 4.5][f]
        hollow = [0, 0, 1.5, 3.0, 4.0, 4.0][f]
        disc(cv, 7.5, 9, r, "O", hollow)
        if f < 3:
            disc(cv, 6.5, 8, r * 0.5, "n")
    return particle_frames(11, 7, "On", speed=(4.0, 6.0), up_bias=1.5, core=core, sizes=(1, 2))


def explosion_frames():
    def core(cv, f):
        if f == 0:
            disc(cv, 7.5, 9, 3.0, "f")
            disc(cv, 7.5, 9, 1.5, "i")
        elif f == 1:
            disc(cv, 7.5, 9, 6.0, "a")
            disc(cv, 7.5, 9, 4.0, "f")
            disc(cv, 7.5, 9, 2.0, "i")
        elif f == 2:
            disc(cv, 7.5, 8.5, 7.0, "M")
            disc(cv, 7.5, 8.5, 5.0, "a")
            disc(cv, 7.5, 8.5, 2.5, "f")
        elif f == 3:
            disc(cv, 7.5, 8, 7.0, "O", 2.0)
            disc(cv, 7.5, 8, 4.5, "M", 2.5)
        elif f == 4:
            disc(cv, 7.5, 7.5, 7.0, "O", 4.0)
        else:
            disc(cv, 7.5, 7, 7.0, "n", 5.5)
    return particle_frames(23, 10, "afM", speed=(5.0, 8.0), up_bias=1.0, core=core, fade_from=2)


def sparkle_burst_frames(seed, main, light):
    def core(cv, f):
        r = [2, 4, 3, 1, 0, 0][f]
        for k in range(-r, r + 1):
            ch = "i" if abs(k) < 2 else light
            cv[9][7 + k] = ch
            cv[9 + k][7] = ch
    return particle_frames(seed, 8, main + light, speed=(3.0, 6.0), up_bias=2.0, core=core,
                           sizes=(1, 1))


def heal_frames():
    rnd = random.Random(5)
    crosses = [(rnd.randint(2, 12), rnd.randint(8, 14), rnd.uniform(0, 1)) for _ in range(5)]
    frames = []
    for f in range(FX_FRAMES):
        cv = blank()
        for x, y, delay in crosses:
            yy = int(y - f * 2.0 - delay * 2)
            if f >= 4 and delay > 0.5:
                continue
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                if 0 <= yy + dy < 16 and 0 <= x + dx < 16:
                    cv[yy + dy][x + dx] = "3" if (dx, dy) != (0, 0) else "i"
        frames.append(render(join(cv), pal=FX_PAL, flat="3i"))
    return frames


def effect_sheet():
    """Row = effect id (EffectField / EnemyData.death_effect / PickupData /
    BreakableData): 0 smoke, 1 blood, 2 ectoplasm, 3 explosion, 4 gold sparkle,
    5 heal, 6 wood splinters, 7 iron + embers, 8 stone chips, 9 bone bits."""
    rows = [
        smoke_frames(),
        particle_frames(3, 14, "RRr", speed=(3.0, 7.0), gravity=4.0, up_bias=3.0),
        particle_frames(7, 10, "QQq", speed=(2.0, 4.0), gravity=-2.5, up_bias=1.0,
                        core=lambda cv, f: disc(cv, 7.5, 9 - f, max(0.0, 3.5 - f), "q")),
        explosion_frames(),
        sparkle_burst_frames(13, "f", "u"),
        heal_frames(),
        particle_frames(17, 9, "ZZh", speed=(3.0, 7.0), gravity=5.0, up_bias=4.0, sizes=(1, 3)),
        particle_frames(19, 10, "XXaf", speed=(3.0, 7.0), gravity=4.0, up_bias=4.0, sizes=(1, 2)),
        particle_frames(29, 9, "DDd", speed=(2.5, 6.0), gravity=5.0, up_bias=3.0, sizes=(1, 3)),
        particle_frames(31, 9, "KKw", speed=(3.0, 7.0), gravity=5.0, up_bias=3.5, sizes=(1, 2)),
    ]
    return sheet(rows, FX_FRAMES)


# ---------------------------------------------------------------- phase 6 damage digits
DIGITS = [
    [".###.", "##.##", "##.##", "##.##", "##.##", "##.##", ".###."],
    [".##..", "###..", ".##..", ".##..", ".##..", ".##..", "####."],
    [".###.", "##.##", "...##", "..##.", ".##..", "##...", "#####"],
    ["####.", "...##", "...##", ".###.", "...##", "...##", "####."],
    ["##.##", "##.##", "##.##", "#####", "...##", "...##", "...##"],
    ["#####", "##...", "####.", "...##", "...##", "##.##", ".###."],
    [".###.", "##...", "##...", "####.", "##.##", "##.##", ".###."],
    ["#####", "...##", "..##.", "..##.", ".##..", ".##..", ".##.."],
    [".###.", "##.##", "##.##", ".###.", "##.##", "##.##", ".###."],
    [".###.", "##.##", "##.##", ".####", "...##", "...##", ".###."],
]
DIGIT_W, DIGIT_H = 5, 7


def digit_sheet():
    """0-9 in one row, 7x9 cells (5x7 glyph + outline). White: the damage
    number shader tints it per kind (normal / crit / heal / hurt)."""
    cw, chh = DIGIT_W + 2, DIGIT_H + 2
    out = Image.new("RGBA", (cw * 10, chh), (0, 0, 0, 0))
    for k, rows in enumerate(DIGITS):
        glyph = [r.replace("#", "i") for r in rows]
        out.paste(render(glyph, DIGIT_W, DIGIT_H), (k * cw, 0))
    return out


# ---------------------------------------------------------------- phase 7 UI
# Everything under art/ui/ is drawn at 1x here and saved at UI_SCALE (2x),
# so one art pixel = 2 screen pixels at 1280x720, matching the 36 px icons.
UI = os.path.join(ART, "ui")
UI_SCALE = 2

# Theme colours (ui/theme/game_theme.tres uses the same values).
UI_INK = hexc("#0d0a14")        # deepest background
UI_PANEL = hexc("#161021")      # panel fill
UI_CARD = hexc("#1d1529")       # card fill
UI_CARD_HI = hexc("#2b1f3d")    # card hover fill
UI_MUTED = hexc("#4b3a63")      # neutral border
UI_MUTED_HI = hexc("#6e5a8c")
UI_MUTED_LO = hexc("#2a1f3a")
UI_BLOOD = hexc("#8e1a2a")      # blood red
UI_BLOOD_HI = hexc("#d23a48")
UI_BLOOD_LO = hexc("#4a0c16")
UI_GOLD = hexc("#e9b949")
UI_GOLD_HI = hexc("#ffe08a")
UI_GOLD_LO = hexc("#8a6420")
UI_HOLY = hexc("#4aa8e0")       # holy blue
UI_HOLY_HI = hexc("#b8ecff")
UI_HOLY_LO = hexc("#1f4f84")
UI_GREY = hexc("#2e2a36")
UI_GREY_HI = hexc("#4a4456")
UI_GREY_LO = hexc("#1a1720")
CLEAR = (0, 0, 0, 0)


def ui_save(img, name, scale=UI_SCALE):
    os.makedirs(UI, exist_ok=True)
    if scale != 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    img.save(os.path.join(UI, name + ".png"))


def bevel_frame(w, h, rings, fill, corners=None, outline=OUTLINE):
    """9-slice source: 1 px `outline`, then `rings` from outside in, each
    (top-left colour, bottom-right colour) -> bevelled border; `fill` in the
    middle (None = transparent). `corners` = (colour, highlight) draws a small
    rivet on each corner over the rings."""
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    for y in range(h):
        for x in range(w):
            d = min(x, y, w - 1 - x, h - 1 - y)
            if d == 0:
                c = outline
            elif d - 1 < len(rings):
                tl, br = rings[d - 1]
                # top/left edges lit, bottom/right in shade
                c = tl if (y == d or x == d) and not (y == h - 1 - d or x == w - 1 - d) else br
                if (y == d and x == w - 1 - d) or (x == d and y == h - 1 - d):
                    c = br if y == h - 1 - d or x == w - 1 - d else tl
            else:
                c = fill
            if c is not None and c != CLEAR:
                px[x, y] = c
    if corners:
        col, hi = corners
        for cx, cy in ((1, 1), (w - 4, 1), (1, h - 4), (w - 4, h - 4)):
            for dx, dy in ((1, 0), (0, 1), (1, 1), (2, 1), (1, 2)):
                px[cx + dx, cy + dy] = col
            px[cx + 1, cy + 1] = hi
    return img


def ui_panels():
    # panels: 18x18, margins 5 (10 at 2x)
    ui_save(bevel_frame(18, 18, [(UI_GOLD_HI, UI_GOLD_LO), (UI_GOLD_LO, UI_INK)], UI_PANEL,
                        corners=(UI_GOLD, UI_GOLD_HI)), "panel")
    ui_save(bevel_frame(18, 18, [(UI_BLOOD_HI, UI_BLOOD_LO), (UI_BLOOD_LO, UI_INK)], UI_PANEL,
                        corners=(UI_GOLD, UI_GOLD_HI)), "panel_blood")
    ui_save(bevel_frame(18, 18, [(UI_HOLY_HI, UI_HOLY_LO), (UI_HOLY_LO, UI_INK)], UI_PANEL,
                        corners=(UI_HOLY_HI, hexc("#ffffff"))), "panel_holy")
    # inset sub-panel (stat lists, tables): 10x10, margins 3
    ui_save(bevel_frame(10, 10, [(UI_INK, UI_MUTED_LO)], UI_INK), "inset")
    # cards (level up): 16x16, margins 4
    ui_save(bevel_frame(16, 16, [(UI_MUTED_HI, UI_MUTED_LO)], UI_CARD), "card")
    ui_save(bevel_frame(16, 16, [(UI_GOLD_HI, UI_GOLD_LO)], UI_CARD_HI), "card_hover")
    ui_save(bevel_frame(16, 16, [(UI_GOLD_LO, UI_GOLD_HI)], UI_INK), "card_pressed")
    ui_save(bevel_frame(16, 16, [(UI_GOLD_HI, UI_GOLD), (UI_GOLD, UI_GOLD_LO)], None,
                        corners=(UI_GOLD_HI, hexc("#ffffff")), outline=UI_GOLD_LO), "card_focus")
    # buttons: 12x12, margins 3
    ui_save(bevel_frame(12, 12, [(UI_BLOOD_HI, UI_BLOOD_LO)], UI_BLOOD), "button")
    ui_save(bevel_frame(12, 12, [(hexc("#f07078"), UI_BLOOD)], hexc("#b0283a")), "button_hover")
    ui_save(bevel_frame(12, 12, [(UI_BLOOD_LO, UI_BLOOD)], hexc("#5e1220")), "button_pressed")
    ui_save(bevel_frame(12, 12, [(UI_GREY_HI, UI_GREY_LO)], UI_GREY), "button_disabled")
    ui_save(bevel_frame(12, 12, [(UI_GOLD_HI, UI_GOLD)], None, outline=UI_GOLD_LO), "button_focus")
    # toggled-on button (banish mode)
    ui_save(bevel_frame(12, 12, [(UI_HOLY_HI, UI_HOLY_LO)], UI_HOLY_LO), "button_toggled")
    # loadout slots: 22x22, margins 3 -> 36 px icon inside at 2x
    ui_save(bevel_frame(22, 22, [(UI_MUTED_LO, UI_MUTED)], (15, 11, 23, 215)), "slot")
    ui_save(bevel_frame(22, 22, [(UI_GOLD_HI, UI_GOLD_LO)], (40, 26, 12, 225),
                        corners=(UI_GOLD_HI, hexc("#ffffff"))), "slot_evo")
    ui_save(bevel_frame(22, 22, [(UI_GOLD, UI_GOLD_LO)], (15, 11, 23, 215)), "slot_max")
    # badges ("NEW", "EVOLVED", "LV 3"): 8x8, margins 2
    ui_save(bevel_frame(8, 8, [(UI_HOLY_HI, UI_HOLY_LO)], UI_HOLY), "badge_new")
    ui_save(bevel_frame(8, 8, [(UI_GOLD_HI, UI_GOLD_LO)], UI_GOLD), "badge_evo")
    ui_save(bevel_frame(8, 8, [(UI_MUTED_HI, UI_MUTED_LO)], UI_MUTED), "badge_level")


def bar_fill(w, h, hi, mid, lo):
    """ProgressBar fill: transparent 1 px where the frame's outline is, then a
    lit top row, body, shaded bottom row."""
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    for y in range(1, h - 1):
        for x in range(1, w - 1):
            c = hi if y == 1 else lo if y == h - 2 else mid
            if x == w - 2 and 1 < y < h - 2:
                c = hi  # bright leading edge
            px[x, y] = c
    return img


def ui_bars():
    # bar frame 8x8, margins 2; fills 6x6, margins 2 (left/top/bottom), 2 right
    ui_save(bevel_frame(8, 8, [(UI_INK, UI_MUTED_LO)], (8, 6, 12, 230)), "bar_frame")
    ui_save(bevel_frame(8, 8, [(UI_GOLD_HI, UI_GOLD_LO)], (8, 6, 12, 230)), "bar_frame_gold")
    ui_save(bar_fill(6, 6, hexc("#ff7a84"), hexc("#d02a3a"), hexc("#7a1020")), "bar_hp")
    ui_save(bar_fill(6, 6, UI_HOLY_HI, UI_HOLY, UI_HOLY_LO), "bar_xp")
    ui_save(bar_fill(6, 6, hexc("#e070a0"), hexc("#8e1a4a"), hexc("#4a0a26")), "bar_boss")
    ui_save(bar_fill(6, 6, UI_GOLD_HI, UI_GOLD, UI_GOLD_LO), "bar_gold")


def ui_pips():
    """Level pips, saved at 1x (5x5: 3x3 body + outline): off, on, next (the
    level an offer grants), max (gold)."""
    def pip(fill, hi):
        img = Image.new("RGBA", (5, 5), CLEAR)
        px = img.load()
        for y in range(5):
            for x in range(5):
                edge = x in (0, 4) or y in (0, 4)
                corner = x in (0, 4) and y in (0, 4)
                if corner:
                    continue
                px[x, y] = OUTLINE if edge else fill
        px[1, 1] = hi
        return img
    ui_save(pip(UI_MUTED_LO, UI_MUTED), "pip_off", 1)
    ui_save(pip(hexc("#d8d0ea"), hexc("#ffffff")), "pip_on", 1)
    ui_save(pip(UI_HOLY, UI_HOLY_HI), "pip_next", 1)
    ui_save(pip(UI_GOLD, UI_GOLD_HI), "pip_max", 1)


UI_ICON_PAL = {"o": UI_GOLD, "O": UI_GOLD_HI, "p": UI_GOLD_LO, "b": hexc("#e8e2cf"),
               "x": UI_BLOOD_LO, "h": hexc("#d8323f"), "H": hexc("#ff8a90"),
               "g": hexc("#c8b8e0"), "s": hexc("#e8c070"), "w": hexc("#ffffff")}
UI_ICONS = {
    "icon_coin": [
        "....oooo....",
        "..oOOOooop..",
        ".oOooooooop.",
        ".oOoopppoop.",
        "oOoopOOOpoop",
        "oOoopOoooop.",
        "oOoopOoooop.",
        "oOoopOoopoop",
        ".oooopppoop.",
        ".ooooooooop.",
        "..ppooooop..",
        "....pppp....",
    ],
    "icon_skull": [
        "...bbbbbb...",
        "..bbbbbbbb..",
        ".bbbbbbbbbb.",
        ".bbbbbbbbbb.",
        ".bxxbbbbxxb.",
        ".bxxxbbxxxb.",
        ".bbxbbbbxbb.",
        "..bbbxxbbb..",
        "...bbbbbb...",
        "...b.bb.b...",
        "...bbbbbb...",
        "....b..b....",
    ],
    "icon_clock": [
        ".pppppppppp.",
        "..oooooooo..",
        "..gsssssgg..",
        "...gssssg...",
        "....gssg....",
        ".....sg.....",
        ".....gs.....",
        "....g..g....",
        "...g..s.g...",
        "..g.ssss.g..",
        "..oooooooo..",
        ".pppppppppp.",
    ],
    "icon_heart": [
        "............",
        ".hhh....hhh.",
        "hHHhh..hhhhh",
        "hHhhhhhhhhhh",
        "hhhhhhhhhhhh",
        "hhhhhhhhhhhh",
        ".hhhhhhhhhh.",
        "..hhhhhhhh..",
        "...hhhhhh...",
        "....hhhh....",
        ".....hh.....",
        "............",
    ],
    # white, tinted by modulate: off-screen pointer, points right
    "icon_arrow": [
        "............",
        "...ww.......",
        "...www......",
        "....www.....",
        ".....www....",
        "......www...",
        "......www...",
        ".....www....",
        "....www.....",
        "...www......",
        "...ww.......",
        "............",
    ],
    "icon_level": [
        ".....w......",
        "....www.....",
        "...wwwww....",
        "..wwwwwww...",
        ".wwwwwwwww..",
        "....www.....",
        "....www.....",
        "....www.....",
        "....www.....",
        "....www.....",
        "............",
        "............",
    ],
}
UI_FLAT = "bxpgsw"


def ui_icon(rows, pal=UI_ICON_PAL):
    return render(rows, 12, 12, pal=pal, flat=UI_FLAT)


def ui_widgets():
    for name, rows in UI_ICONS.items():
        ui_save(ui_icon(rows), name)
    ui_save(render(CHEST, 16, 16), "icon_chest")
    # check box: 10x10 art (+ outline)
    box = ["oooooooooo"] + ["o........o"] * 8 + ["oooooooooo"]
    tick = ["oooooooooo", "o........o", "o......OOo", "o.....OO.o", "oO...OO..o",
            "o.OOOO...o", "o..OO....o", "o........o", "o........o", "oooooooooo"]
    ui_save(render(box, 10, 10, pal={"o": UI_MUTED_HI}, flat="o"), "check_off")
    ui_save(render(tick, 10, 10, pal={"o": UI_GOLD, "O": UI_GOLD_HI}, flat="oO"), "check_on")
    # slider grabber 6x10
    knob = [".oooo.", "oOOOOo", "oOooOo", "oOooOo", "oOooOo", "oOooOo", "oOooOo",
            "oOooOo", "opppo.", ".pppp."]
    ui_save(render(knob, 6, 10, pal=UI_ICON_PAL, flat="oOp"), "grabber")
    ui_save(render(knob, 6, 10, pal={**UI_ICON_PAL, "o": UI_GOLD_HI, "O": hexc("#ffffff")},
                   flat="oOp"), "grabber_hover")


# ------------------------------------------------ bitmap font (BMFont .fnt)
# Own 5x7 design (cap height 7, x-height 5, descenders 2 rows), so the font is
# this project's art: no third-party licence. White fill + baked 1 px dark
# outline (8-neighbour); Label font_color tints the fill, outline stays dark.
FONT_GLYPHS = {
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
    "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
    "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
    "J": ["..###", "...#.", "...#.", "...#.", "#..#.", "#..#.", ".##.."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "L": ["#...", "#...", "#...", "#...", "#...", "#...", "####"],
    "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
    "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"],
    "a": [".....", ".....", ".###.", "....#", ".####", "#...#", ".####"],
    "b": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "####."],
    "c": ["....", "....", ".###", "#...", "#...", "#...", ".###"],
    "d": ["....#", "....#", ".####", "#...#", "#...#", "#...#", ".####"],
    "e": [".....", ".....", ".###.", "#...#", "#####", "#....", ".###."],
    "f": ["..##", ".#..", ".#..", "###.", ".#..", ".#..", ".#.."],
    "g": [".....", ".....", ".####", "#...#", "#...#", "#...#", ".####", "....#", ".###."],
    "h": ["#....", "#....", "####.", "#...#", "#...#", "#...#", "#...#"],
    "i": ["#", ".", "#", "#", "#", "#", "#"],
    "j": ["..#", "...", "..#", "..#", "..#", "..#", "..#", "#.#", ".#."],
    "k": ["#...", "#...", "#..#", "#.#.", "##..", "#.#.", "#..#"],
    "l": ["#.", "#.", "#.", "#.", "#.", "#.", ".#"],
    "m": [".....", ".....", "##.#.", "#.#.#", "#.#.#", "#.#.#", "#...#"],
    "n": [".....", ".....", "####.", "#...#", "#...#", "#...#", "#...#"],
    "o": [".....", ".....", ".###.", "#...#", "#...#", "#...#", ".###."],
    "p": [".....", ".....", "####.", "#...#", "#...#", "#...#", "####.", "#....", "#...."],
    "q": [".....", ".....", ".####", "#...#", "#...#", "#...#", ".####", "....#", "....#"],
    "r": ["....", "....", "#.##", "##..", "#...", "#...", "#..."],
    "s": [".....", ".....", ".####", "#....", ".###.", "....#", "####."],
    "t": [".#.", ".#.", "###", ".#.", ".#.", ".#.", "..#"],
    "u": [".....", ".....", "#...#", "#...#", "#...#", "#...#", ".####"],
    "v": [".....", ".....", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
    "w": [".....", ".....", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
    "x": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
    "y": [".....", ".....", "#...#", "#...#", "#...#", "#...#", ".####", "....#", ".###."],
    "z": [".....", ".....", "#####", "...#.", "..#..", ".#...", "#####"],
    "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
    "1": [".#.", "##.", ".#.", ".#.", ".#.", ".#.", "###"],
    "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
    "3": ["####.", "....#", "....#", ".###.", "....#", "....#", "####."],
    "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
    "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
    "6": [".###.", "#....", "#....", "####.", "#...#", "#...#", ".###."],
    "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
    "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
    "9": [".###.", "#...#", "#...#", ".####", "....#", "....#", ".###."],
    "!": ["#", "#", "#", "#", "#", ".", "#"],
    '"': ["#.#", "#.#", "...", "...", "...", "...", "..."],
    "#": [".#.#.", "#####", ".#.#.", ".#.#.", "#####", ".#.#.", "....."],
    "$": ["..#..", ".####", "#.#..", ".###.", "..#.#", "####.", "..#.."],
    "%": ["##..#", "##.#.", "...#.", "..#..", ".#...", ".#.##", "#..##"],
    "&": [".##..", "#..#.", "#.#..", ".#...", "#.#.#", "#..#.", ".##.#"],
    "'": ["#", "#", ".", ".", ".", ".", "."],
    "(": [".#", "#.", "#.", "#.", "#.", "#.", ".#"],
    ")": ["#.", ".#", ".#", ".#", ".#", ".#", "#."],
    "*": [".....", "#.#.#", ".###.", "#####", ".###.", "#.#.#", "....."],
    "+": [".....", "..#..", "..#..", "#####", "..#..", "..#..", "....."],
    ",": ["..", "..", "..", "..", "..", ".#", ".#", "#."],
    "-": ["....", "....", "....", "####", "....", "....", "...."],
    ".": [".", ".", ".", ".", ".", ".", "#"],
    "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
    ":": [".", ".", "#", ".", ".", "#", "."],
    ";": ["..", "..", ".#", "..", "..", ".#", ".#", "#."],
    "<": ["...#", "..#.", ".#..", "#...", ".#..", "..#.", "...#"],
    "=": ["....", "....", "####", "....", "####", "....", "...."],
    ">": ["#...", ".#..", "..#.", "...#", "..#.", ".#..", "#..."],
    "?": [".###.", "#...#", "....#", "...#.", "..#..", ".....", "..#.."],
    "@": [".###.", "#...#", "#.###", "#.#.#", "#.###", "#....", ".###."],
    "[": ["##", "#.", "#.", "#.", "#.", "#.", "##"],
    "\\": ["#....", "#....", ".#...", "..#..", "...#.", "....#", "....#"],
    "]": ["##", ".#", ".#", ".#", ".#", ".#", "##"],
    "^": ["..#..", ".#.#.", "#...#", ".....", ".....", ".....", "....."],
    "_": [".....", ".....", ".....", ".....", ".....", ".....", "#####"],
    "`": ["#.", ".#", "..", "..", "..", "..", ".."],
    "{": ["..#", ".#.", ".#.", "#..", ".#.", ".#.", "..#"],
    "|": ["#", "#", "#", "#", "#", "#", "#"],
    "}": ["#..", ".#.", ".#.", "..#", ".#.", ".#.", "#.."],
    "~": [".....", ".....", ".#...", "#.#.#", "...#.", ".....", "....."],
    "·": [".", ".", ".", "#", ".", ".", "."],            # middle dot
    "—": ["......", "......", "......", "######", "......", "......", "......"],  # em dash
    "×": [".....", ".....", "#...#", ".#.#.", "..#..", ".#.#.", "#...#"],      # times
    "→": [".....", "...#.", "....#", "#####", "....#", "...#.", "....."],      # arrow
}
FONT_CAP = 7          # cap height (rows above the baseline)
FONT_ROWS = 9         # + 2 descender rows
FONT_CELL_H = FONT_ROWS + 2  # + outline above and below
FONT_LINE_H = 12      # = the font's base size; use multiples (12, 24, 36, 48...)
FONT_SPACE = 4
FONT_FILL = (255, 255, 255, 255)


def font_sheet():
    """Writes art/ui/font.png + art/ui/font.fnt (BMFont text format, imported
    by Godot as a FontFile). Each glyph cell = glyph + 1 px outline; advance =
    width + 2, so neighbouring outlines touch and fills stay 2 px apart."""
    chars = sorted(FONT_GLYPHS.keys(), key=ord)
    cols = 16
    cell_w = max(len(r) for g in FONT_GLYPHS.values() for r in g) + 2
    rows_n = (len(chars) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell_w, rows_n * FONT_CELL_H), CLEAR)
    px = img.load()
    lines = []
    for k, ch in enumerate(chars):
        rows = FONT_GLYPHS[ch]
        w = max(len(r) for r in rows)
        assert len(rows) <= FONT_ROWS, ch
        gx, gy = (k % cols) * cell_w, (k // cols) * FONT_CELL_H
        fill = set()
        for y, r in enumerate(rows):
            for x, c in enumerate(r):
                if c == "#":
                    fill.add((x + 1, y + 1))
        for (x, y) in fill:
            px[gx + x, gy + y] = FONT_FILL
        for y in range(FONT_CELL_H):
            for x in range(w + 2):
                if (x, y) in fill:
                    continue
                if any((x + dx, y + dy) in fill for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                    px[gx + x, gy + y] = OUTLINE
        lines.append("char id=%d x=%d y=%d width=%d height=%d xoffset=0 yoffset=0 "
                     "xadvance=%d page=0 chnl=15" % (ord(ch), gx, gy, w + 2, FONT_CELL_H, w + 2))
    lines.append("char id=32 x=0 y=0 width=0 height=0 xoffset=0 yoffset=0 xadvance=%d page=0 chnl=15"
                 % FONT_SPACE)
    os.makedirs(UI, exist_ok=True)
    img.save(os.path.join(UI, "font.png"))
    head = [
        'info face="Knell" size=%d bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 '
        'aa=1 padding=0,0,0,0 spacing=0,0 outline=0' % FONT_LINE_H,
        "common lineHeight=%d base=%d scaleW=%d scaleH=%d pages=1 packed=0 alphaChnl=0 "
        "redChnl=0 greenChnl=0 blueChnl=0" % (FONT_LINE_H, FONT_CAP + 1, img.width, img.height),
        'page id=0 file="font.png"',
        "chars count=%d" % len(lines),
    ]
    with open(os.path.join(UI, "font.fnt"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(head + lines) + "\n")


# ------------------------------------------------ title background (320x180)
def title_background(w=320, h=180, seed=7):
    """Night sky over a graveyard: gradient, stars, blood moon, two silhouette
    layers (hills, then crosses / tombstones / dead tree / chapel)."""
    rnd = random.Random(seed)
    img = Image.new("RGBA", (w, h), CLEAR)
    px = img.load()
    stops = [(0.0, (7, 5, 13)), (0.55, (26, 13, 36)), (0.85, (58, 18, 32)), (1.0, (70, 22, 34))]

    def sky(t):
        for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
            if t <= t1:
                f = (t - t0) / (t1 - t0)
                # 6-step banding: posterized like hand-placed pixel bands
                f = round(f * 6) / 6
                return tuple(int(a + (b - a) * f) for a, b in zip(c0, c1)) + (255,)
        return stops[-1][1] + (255,)

    for y in range(h):
        for x in range(w):
            px[x, y] = sky(y / (h - 1))
    for _ in range(140):
        x, y = rnd.randrange(w), rnd.randrange(int(h * 0.6))
        b = rnd.choice((90, 130, 180, 230))
        px[x, y] = (b, b, min(255, b + 30), 255)
    for _ in range(8):  # a few cross-shaped bright stars
        x, y = rnd.randrange(4, w - 4), rnd.randrange(4, int(h * 0.45))
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            px[x + dx, y + dy] = (240, 236, 255, 255) if (dx, dy) == (0, 0) else (150, 140, 190, 255)
    # blood moon with halo
    mx, my, mr = 266, 54, 24
    for y in range(h):
        for x in range(w):
            d = math.hypot(x - mx, y - my)
            if d <= mr:
                lit = (x - mx) * -0.5 + (y - my) * -0.6
                c = (200, 40, 60) if lit < 4 else (232, 82, 90)
                if d > mr - 1.5:
                    c = (150, 26, 46)
                px[x, y] = c + (255,)
            elif d <= mr + 7 and (int(d) % 3 == 0):
                r, g, b, _ = px[x, y]
                px[x, y] = (min(255, r + 26), g + 4, b + 8, 255)
    for cx, cy, cr in ((258, 48, 4), (274, 62, 3), (262, 66, 2), (278, 44, 2)):  # craters
        for y in range(cy - cr, cy + cr + 1):
            for x in range(cx - cr, cx + cr + 1):
                if math.hypot(x - cx, y - cy) <= cr:
                    r, g, b, _ = px[x, y]
                    px[x, y] = (int(r * 0.8), int(g * 0.8), int(b * 0.85), 255)

    def silhouette(height_at, col):
        for x in range(w):
            top = int(height_at(x))
            for y in range(max(0, top), h):
                px[x, y] = col

    far = (20, 10, 24, 255)
    near = (9, 6, 13, 255)
    silhouette(lambda x: h * 0.70 + 7 * math.sin(x * 0.03) + 4 * math.sin(x * 0.081 + 1.0), far)
    # chapel on the far hill
    cx0 = 70
    base = int(h * 0.70 + 7 * math.sin(cx0 * 0.03) + 4 * math.sin(cx0 * 0.081 + 1.0))
    for y in range(base - 22, base + 1):
        for x in range(cx0, cx0 + 18):
            px[x, y] = far
    for y in range(base - 40, base - 21):  # spire
        half = (y - (base - 40)) // 4
        for x in range(cx0 + 4 - half + 4, cx0 + 5 + half + 4):
            px[x, y] = far
    for y in range(base - 47, base - 39):
        px[cx0 + 9, y] = far
    for x in range(cx0 + 7, cx0 + 12):
        px[x, base - 44] = far
    for y in range(base - 16, base - 9):  # lit window
        px[cx0 + 8, y] = (232, 160, 70, 255)
        px[cx0 + 9, y] = (255, 200, 110, 255)
    silhouette(lambda x: h * 0.84 + 3 * math.sin(x * 0.05 + 2.0), near)
    # graves and crosses on the near ground
    gx = 6
    while gx < w - 8:
        ground = int(h * 0.84 + 3 * math.sin(gx * 0.05 + 2.0))
        kind = rnd.random()
        if kind < 0.4:      # cross
            hgt = rnd.randint(9, 14)
            for y in range(ground - hgt, ground):
                px[gx + 2, y] = near
            for x in range(gx, gx + 5):
                px[x, ground - hgt + 3] = near
        elif kind < 0.8:    # tombstone
            hgt = rnd.randint(6, 10)
            for y in range(ground - hgt, ground):
                for x in range(gx, gx + 6):
                    if y == ground - hgt and x in (gx, gx + 5):
                        continue
                    px[x, y] = near
        gx += rnd.randint(10, 22)
    # dead tree, right side
    tx = 290
    ground = int(h * 0.84 + 3 * math.sin(tx * 0.05 + 2.0))
    for y in range(ground - 46, ground):
        for x in range(tx - (1 if y > ground - 30 else 0), tx + 2):
            px[x, y] = near
    for (sx, sy, dx, n) in ((tx, ground - 30, -1, 14), (tx + 1, ground - 38, 1, 12),
                            (tx, ground - 44, -1, 8), (tx - 8, ground - 37, -1, 6)):
        for k in range(n):
            px[sx + dx * k, sy - k // 2] = near
    # low mist
    for y in range(int(h * 0.80), h):
        for x in range(w):
            if (x // 3 + y) % 7 == 0 and rnd.random() < 0.5:
                r, g, b, _ = px[x, y]
                px[x, y] = (r + 14, g + 10, b + 20, 255)
    return img


def ui_art():
    ui_panels()
    ui_bars()
    ui_pips()
    ui_widgets()
    font_sheet()
    ui_save(title_background(), "title_bg", 1)



# ---------------------------------------------------------------- phase 8: hunters
# Every hunter is a 4-frame walk sheet (18x18 cells, facing right) like the
# Hunter: CharacterData.sprite_sheet. Robed hunters sway their hem instead of
# stepping (feet peek out on alternate frames).

MAUD_PAL = {  # Sister Maud: night-blue habit, ivory wimple, gold rosary
    "K": hexc("#2c2a4a"),
    "c": hexc("#efe6d2"),
    "U": hexc("#f0b43c"),
    "E": hexc("#ffe28a"),
}
MAUD_TOP = check([
    "......KKKK......",
    ".....KKKKKK.....",
    "....KKKccccc....",
    "....KKcSSSSc....",
    "....KKcSSeSe....",
    "....KKcSSSSc....",
    "....KKKcccc.....",
    "...KKKKKKKKKK...",
    "...KKKKKKUKKK...",
    "..KKKKKKKKUKK...",
    "..SKKKKKKUKKS...",
    "...KKKKKKKUK....",
    "...KKKKKKKEK....",
], 16, "maud")
ROBE_HEMS = [
    ["...KKKKKKKKKK...", "...KKKKKKKKKK...", "....BB....BB...."],
    ["...KKKKKKKKKKK..", "..KKKKKKKKKKK...", "...BB......BB..."],
    ["...KKKKKKKKKK...", "...KKKKKKKKKK...", "....BB....BB...."],
    ["..KKKKKKKKKKK...", "...KKKKKKKKKKK..", ".....BB..BB....."],
]


def robe_frames(top, swaps, pal, robe, flat=""):
    out = []
    for i in range(4):
        hem = [r.replace("K", robe) for r in ROBE_HEMS[i]]
        rows = swap_rows(top, swaps[i]) + hem
        if i % 2 == 1:  # bob like the Hunter
            rows = rows + ["................"]
        out.append(render(check(rows[-16:], 16, "robe"), pal=pal, flat=flat))
    return out


def maud_frames():
    # the rosary's cross swings with the step
    swing = [{}, {12: "...KKKKKKKKE...."}, {}, {12: "...KKKKKKE.K...."}]
    return robe_frames(MAUD_TOP, swing, MAUD_PAL, "K")


VESNA_PAL = {  # Vesna Thorn: crimson hood and cloak, leather jerkin, steel knives
    "R": hexc("#a8203a"),
    "C": hexc("#7a5236"),
    "P": hexc("#3d3346"),
    "B": hexc("#4a3020"),
    "o": hexc("#ffd36b"),  # brooch
}
VESNA_TOP = check([
    "......RRRR......",
    ".....RRRRRR.....",
    "....RRRRRRRR....",
    "....RRRSSSSR....",
    "....RRSSSeSe....",
    "....RRRSSSS.....",
    "...RRRRoCCC.....",
    "...RRRCCCCCC.WW.",
    "..RRRRCYCCCSWW..",
    "..RRRRCCCCCC....",
    "..RRR.CWCWCC....",
    "..RR...CCCC.....",
], 16, "vesna")


def vesna_frames():
    # the cloak tail flutters behind her
    flutter = [{}, {10: ".RRRR.CWCWCC....", 11: ".RRR...CCCC....."}, {},
               {10: "..RRRRCWCWCC....", 11: "..RRR..CCCC....."}]
    frames = []
    for i, legs in enumerate(P_LEGS):
        rows = swap_rows(VESNA_TOP, flutter[i]) + legs
        if i % 2 == 1:
            rows = rows + ["................"]
        frames.append(render(check(rows, 16, "vesna"), pal=VESNA_PAL, flat="o"))
    return frames


ODO_PAL = {  # Brother Odo: alchemist friar, umber robe, rope belt, blue vial
    "T": hexc("#7a5532"),
    "h": hexc("#4a3424"),  # tonsure
    "Y": hexc("#d9c08a"),  # rope
    "A": hexc("#6fd0ff"),
    "q": hexc("#e8fbff"),
}
ODO_TOP = check([
    "................",
    "......hhhh......",
    ".....hSSSSh.....",
    ".....SSSSSS.....",
    ".....SSSeSe.....",
    "....hSSSSSS.....",
    "....TTTSSSTT....",
    "...TTTTTTTTTT.q.",
    "...TTTTTTTTTSAA.",
    "...TTYYYYYYT.AA.",
    "...TTTTTTYTT....",
    "...TTTTTTYTT....",
    "..TTTTTTTTTTT...",
], 16, "odo")


def odo_frames():
    bubbles = [{}, {7: "...TTTTTTTTTT..q"}, {7: "...TTTTTTTTTTq.."}, {7: "...TTTTTTTTTT.q."}]
    return robe_frames(ODO_TOP, bubbles, ODO_PAL, "T", flat="hq")


YSOLDE_PAL = {  # Dame Ysolde: templar, steel helm and mail, ivory tabard, red cross
    "X": hexc("#a8b0c4"),
    "R": hexc("#b8283c"),
    "c": hexc("#ece4d0"),
    "P": hexc("#8a90a4"),  # greaves
    "B": hexc("#4c5064"),  # sabatons
    "E": hexc("#e9b949"),
}
YSOLDE_TOP = check([
    ".....XXXXXX.....",
    "....XXXXXXXX....",
    "....XXXXEXXX....",
    "....XXSSSSSX....",
    "....XXSSSeSe....",
    "....XXXSSSS.....",
    "...RRXXXXXX.....",
    "..RRXcccRcccX...",
    "..RRXcRRRRRcS...",
    "..RRXcccRccc....",
    "..RRRcccRccc....",
    "..RR.XXXXXXX....",
], 16, "ysolde")


def ysolde_frames():
    frames = []
    for i, legs in enumerate(P_LEGS):
        rows = YSOLDE_TOP + legs
        if i % 2 == 1:
            rows = rows + ["................"]
        frames.append(render(check(rows, 16, "ysolde"), pal=YSOLDE_PAL))
    return frames


HUNTER_SHEETS = {
    "player_maud": maud_frames,
    "player_vesna": vesna_frames,
    "player_odo": odo_frames,
    "player_ysolde": ysolde_frames,
}

# Reliquary (meta shop) icons for the stats no passive covers.
META_ICONS = {
    "growth": [  # open tome
        "................",
        "..cccc....cccc..",
        ".cccccc..cccccc.",
        ".ceeecc..ceeecc.",
        ".cccccc..cccccc.",
        ".ceeeec..ceeecc.",
        ".cccccc..cccccc.",
        ".ceeecc..ceeeec.",
        ".cccccc..cccccc.",
        ".ZZZZZZZZZZZZZZ.",
        "..ZZZZZZZZZZZZ..",
    ],
    "greed": [  # coin stack
        "................",
        "......EEEE......",
        ".....EYYYYE.....",
        "......EEEE......",
        "...EEEE.........",
        "..EYYYYE..EEEE..",
        "...EEEE..EYYYYE.",
        "...EEEE...EEEE..",
        "...EEEE...EEEE..",
        "...EEEE...EEEE..",
        "...EEEE...EEEE..",
    ],
    "revival": [  # ankh-like hallowed cross with a halo
        ".....qqqqqq.....",
        "....q......q....",
        "......EEEE......",
        ".....EE..EE.....",
        ".....EE..EE.....",
        "......EEEE......",
        "..EEEEEEEEEEEE..",
        "..EEEEEEEEEEEE..",
        ".......EE.......",
        ".......EE.......",
        ".......EE.......",
        ".......EE.......",
        ".......EE.......",
    ],
    "reroll": [  # bone die
        "....cccccccc....",
        "...cccccccccc...",
        "...cceccccecc...",
        "...cccccccccc...",
        "...cccccccccc...",
        "...ccccecccc....",
        "...cccccccccc...",
        "...cccccccccc...",
        "...cceccccecc...",
        "...cccccccccc...",
        "....cccccccc....",
    ],
    "skip": [  # double arrow
        "................",
        "..QQ.....QQ.....",
        "..QQQ....QQQ....",
        "..QQQQ...QQQQ...",
        "..QQQQQ..QQQQQ..",
        "..QQQQQQ.QQQQQQ.",
        "..QQQQQ..QQQQQ..",
        "..QQQQ...QQQQ...",
        "..QQQ....QQQ....",
        "..QQ.....QQ.....",
    ],
    "banish": [  # broken seal
        "....RRRRRRR.....",
        "...RRRRRRRRR....",
        "..RRRwRRRRRRR...",
        "..RRRRwRRRRRR...",
        "..RRRRRw..RRR...",
        "..RRRRR..wRRR...",
        "..RRRRRRRRwRR...",
        "...RRRRRRRRR....",
        "....RRRRRRR.....",
        "......YY........",
        ".....YYYY.......",
    ],
}

def main():
    os.makedirs(os.path.join(ART, "sprites"), exist_ok=True)
    os.makedirs(os.path.join(ART, "tiles"), exist_ok=True)
    os.makedirs(os.path.join(ART, "icons"), exist_ok=True)

    sheet([player_frames()], 4).save(os.path.join(ART, "sprites", "player_hunter.png"))
    # phase 8: the other hunters (CharacterData.sprite_sheet)
    for name, frames in HUNTER_SHEETS.items():
        sheet([frames()], 4).save(os.path.join(ART, "sprites", name + ".png"))
    for name, rows in META_ICONS.items():
        save_icon(rows, "meta_" + name)
    # enemy sheet: row = EnemyData.sprite_row, 4 animation frames per row
    # rows 4-6 (phase 5): crypt acolyte, grave wisp, cinder skull
    # rows 7-10 (phase 6): breakables -- iron lantern, brazier, crate, grave cross
    sheet([ghoul_frames(), bat_frames(), skeleton_frames(), slime_frames(),
           acolyte_frames(), wisp_frames(), skull_frames(), lantern_frames(),
           brazier_frames(), crate_frames(), grave_frames()], 4).save(
        os.path.join(ART, "sprites", "enemies.png"))
    # large enemies, 34 px cells (32 + outline): row = EnemyData.sprite_row when
    # large_sprite is on. 0 brute, 1 Hollow Abbot, 2 Vesperine, 3 Knellwraith
    sheet([brute_frames(), abbot_frames(), vesperine_frames(), knell_frames()], 4,
          BIG_CELL).save(os.path.join(ART, "sprites", "enemies_large.png"))
    # enemy projectiles: row = EnemyData.shot_row
    enemy_shot_sheet().save(os.path.join(ART, "sprites", "enemy_shots.png"))
    sheet([DECOR], len(DECOR)).save(os.path.join(ART, "sprites", "decor.png"))
    ground_tile().save(os.path.join(ART, "tiles", "grass.png"))
    # gems: row = tier, 4 sparkle frames per row
    gem_sheet().save(os.path.join(ART, "sprites", "gems.png"))
    # projectiles: row = weapon sprite_row (knife, bead, cross, vial)
    projectile_sheet().save(os.path.join(ART, "sprites", "projectiles.png"))
    holy_water_sheet().save(os.path.join(ART, "sprites", "holy_water.png"))
    holy_water_sheet(colors=SAINTS_FONT).save(os.path.join(ART, "sprites", "saints_font.png"))
    # pickups: row = PickupData.sprite_row, 4 frames per row
    pickup_sheet().save(os.path.join(ART, "sprites", "pickups.png"))
    # one-shot effects (kill bursts, explosions, debris): row = effect id
    effect_sheet().save(os.path.join(ART, "sprites", "effects.png"))
    digit_sheet().save(os.path.join(ART, "sprites", "damage_digits.png"))
    save_icon(CHEST_OPEN, "chest_open")
    save_icon(icon_seraphs_halo(), "seraphs_halo")
    save_icon(icon_thornstorm(), "thornstorm")
    save_icon(icon_eternal_rosary(), "eternal_rosary")
    save_icon(icon_font_of_saints(), "font_of_saints")
    save_icon(icon_radiant_crucifix(), "radiant_crucifix")
    save_icon(ICON_AURA, "holy_aura")
    save_icon(icon_beads(), "vesper_beads")
    for name, rows in WEAPON_ICONS.items():
        save_icon(rows, name)
    for name, rows in ICONS.items():
        save_icon(rows, name)
    # phase 7: UI theme art (panels, buttons, bars, pips, icons), bitmap font,
    # title background -> art/ui/
    ui_art()
    print("sprites written to", ART)


if __name__ == "__main__":
    main()
