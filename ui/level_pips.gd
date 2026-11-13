class_name LevelPips
extends Control
## A row of level pips (art/ui/pip_*.png, 5x5): filled up to `level`, the
## pips in (level, preview] highlighted as "next" (level-up cards), the rest
## empty. A maxed or evolved item shows every pip gold.
## Redraws only when set_levels() changes something, so a HUD full of these
## costs nothing per frame.

const PIP_OFF := preload("res://art/ui/pip_off.png")
const PIP_ON := preload("res://art/ui/pip_on.png")
const PIP_NEXT := preload("res://art/ui/pip_next.png")
const PIP_MAX := preload("res://art/ui/pip_max.png")
const PIP := 5
const STEP := 6

@export var centered := true
## 2 = pips drawn at the 2x UI pixel scale (cards, pause loadout).
@export_range(1, 3) var pip_scale := 1

var level := 0
var max_level := 0
var preview := 0
var gold := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = PIP * pip_scale


func set_levels(lv: int, max_lv: int, preview_lv: int = 0, all_gold: bool = false) -> void:
	if lv == level and max_lv == max_level and preview_lv == preview and all_gold == gold:
		return
	level = lv
	max_level = max_lv
	preview = preview_lv
	gold = all_gold
	queue_redraw()


func _draw() -> void:
	var n := max_level
	if n <= 0:
		return
	# Squeeze the step (pips overlap their outlines) if the row would not fit.
	var pip := PIP * pip_scale
	var step := mini(STEP * pip_scale, maxi(3, int((size.x - pip) / maxf(1.0, n - 1))))
	var width := (n - 1) * step + pip
	var x0 := floorf((size.x - width) * 0.5) if centered else 0.0
	var y0 := floorf((size.y - pip) * 0.5)
	for k in n:
		var tex := PIP_OFF
		if gold:
			tex = PIP_MAX
		elif k < level:
			tex = PIP_MAX if level >= max_level else PIP_ON
		elif k < preview:
			tex = PIP_NEXT
		draw_texture_rect(tex, Rect2(x0 + k * step, y0, pip, pip), false)
