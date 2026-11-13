class_name SpatialHash
extends RefCounted
## Uniform grid hashed into a fixed bucket table, rebuilt from scratch every
## frame with a counting sort (no per-cell arrays, no allocations).
## Items of bucket h are items[cell_start[h] .. cell_start[h + 1]).
## Different cells may share a bucket, so callers must distance-check.

const BITS := 12
const SIZE := 1 << BITS
const MASK := SIZE - 1
const PRIME_X := 73856093
const PRIME_Y := 19349663

var cell_size := 1.0
var inv_cell := 1.0
var cell_start := PackedInt32Array()
var items := PackedInt32Array()
var _bucket := PackedInt32Array()


func _init(p_cell_size: float = 1.0) -> void:
	cell_size = p_cell_size
	inv_cell = 1.0 / p_cell_size
	cell_start.resize(SIZE + 1)


static func bucket_of(cx: int, cy: int) -> int:
	return ((cx * PRIME_X) ^ (cy * PRIME_Y)) & MASK


func build(positions: PackedVector2Array, count: int) -> void:
	if items.size() < count:
		items.resize(count)
		_bucket.resize(count)
	cell_start.fill(0)
	for i in count:
		var p := positions[i]
		var h := ((int(floorf(p.x * inv_cell)) * PRIME_X) ^ (int(floorf(p.y * inv_cell)) * PRIME_Y)) & MASK
		_bucket[i] = h
		cell_start[h + 1] += 1
	for h in range(1, SIZE + 1):
		cell_start[h] += cell_start[h - 1]
	var cursor := cell_start.slice(0, SIZE)
	for i in count:
		var h := _bucket[i]
		items[cursor[h]] = i
		cursor[h] += 1
