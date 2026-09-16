class_name BestTimes
extends RefCounted
## Persisted fastest run times (seconds, fastest first). Kept in a small JSON file
## under logs/ (gitignored, local) to match the project's "keep writable state in
## the repo, not ~/Library" convention. The list maths are pure static helpers so
## they're unit-testable without touching disk.

const KEEP := 5
const PATH := "res://logs/best_times.json"

var times: Array = []


func _init(load_from_disk: bool = true) -> void:
	if load_from_disk:
		_load()


## Fastest time, or -1.0 if none recorded yet.
func best() -> float:
	return times[0] if not times.is_empty() else -1.0


func has_any() -> bool:
	return not times.is_empty()


## Would this time be a new outright best?
func is_new_best(t: float) -> bool:
	return times.is_empty() or t < times[0]


## Record a finished run; returns true if it's a new best. Persists to disk.
func record(t: float) -> bool:
	var new_best := is_new_best(t)
	times = BestTimes.merged(times, t, KEEP)
	_save()
	return new_best


## Pure: insert t into times, sort ascending, cap to `keep`. No disk.
static func merged(existing: Array, t: float, keep: int) -> Array:
	var out := existing.duplicate()
	out.append(t)
	out.sort()
	return out.slice(0, mini(keep, out.size()))


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Array:
		times = []
		for v in parsed:
			times.append(float(v))
		times.sort()


func _save() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(times))
