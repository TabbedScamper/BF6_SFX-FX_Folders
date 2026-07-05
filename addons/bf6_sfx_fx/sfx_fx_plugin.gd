@tool
extends EditorPlugin
# BF6 SFX & FX Folders.
#
# No buttons, no extra dock: enabling the plugin installs the folder view,
# disabling it puts the stock view back. All driven by the engine's
# enable/disable callbacks (which fire ONLY on the user's action in the
# Plugins tab — not on editor start or shutdown), so the toggle is the switch.
#
# On ENABLE:
#   1. extract the placeable FX/SFX wrapper scenes/scripts into the project
#      (objects/fx, objects/audio, scripts/fx, scripts/audio) if not already
#      present — one-time; each wrapper follows the SDK's spawnable-object
#      pattern so validation + export treat them like any stock object;
#   2. swap the Scene Library addon's script for the folder-view build (stock
#      backed up), so FX/SFX show as two tidy folders per map;
#   3. merge the per-map FX/SFX collections into scene_library.json (backed up).
#
# On DISABLE: restore the stock Scene Library script and remove our collections.
# The extracted wrapper files are LEFT in place so effects already placed in
# your levels keep working; re-enable to bring the folders back.

const SCENE_LIB_SCRIPT := "res://addons/scene-library/scripts/scene_library.gd"
const SCENE_LIB_JSON := "res://addons/scene-library/scene_library.json"

# this addon's folder, derived from the script path so any install location works
func _addon_dir() -> String:
	return (get_script() as Script).resource_path.get_base_dir()

# ---------- enable = install ----------
func _enable_plugin() -> void:
	var files := _extract_content()          # one-time; skips if already present
	var lib := _apply_folder_view()
	var colls := _merge_collections()
	EditorInterface.get_resource_filesystem().scan()
	print("[SFX & FX] Enabled — %s; %s; %s. Restart the editor if the Object Library doesn't refresh." % [
		("content ready" if files < 0 else "%d files installed" % files), lib, colls])

# ---------- disable = revert (keep the wrapper files) ----------
func _disable_plugin() -> void:
	var lib := _restore_folder_view()
	var colls := _remove_collections()
	EditorInterface.get_resource_filesystem().scan()
	print("[SFX & FX] Disabled — %s; %s. Wrapper files kept (placed effects keep working)." % [lib, colls])

# ---------- content ----------
# Returns files written, 0 if already installed, -1 if the archive is missing.
func _extract_content() -> int:
	if DirAccess.dir_exists_absolute("res://objects/fx"):
		return 0
	var zp := _addon_dir() + "/content.zip"
	if not FileAccess.file_exists(zp): return -1
	var zr := ZIPReader.new()
	if zr.open(ProjectSettings.globalize_path(zp)) != OK: return -1
	var n := 0
	for path in zr.get_files():
		if path.ends_with("/"): continue
		var dest := "res://" + path
		DirAccess.make_dir_recursive_absolute(dest.get_base_dir())
		var out := FileAccess.open(dest, FileAccess.WRITE)
		if out:
			out.store_buffer(zr.read_file(path)); out.close(); n += 1
	zr.close()
	return n

# ---------- folder view (the toggle) ----------
func _apply_folder_view() -> String:
	if not FileAccess.file_exists(SCENE_LIB_SCRIPT):
		return "Scene Library addon not found (folder view skipped)"
	var patched := _addon_dir() + "/scene_library_patch/scene_library.gd.patched"
	if not FileAccess.file_exists(patched):
		return "patch file missing (folder view skipped)"
	# preserve the first-seen stock script as the restore point
	if not FileAccess.file_exists(SCENE_LIB_SCRIPT + ".stock"):
		_copy_file(SCENE_LIB_SCRIPT, SCENE_LIB_SCRIPT + ".stock")
	_copy_file(patched, SCENE_LIB_SCRIPT)
	return "folder view enabled"

func _restore_folder_view() -> String:
	if not FileAccess.file_exists(SCENE_LIB_SCRIPT + ".stock"):
		return "no stock backup (folder view unchanged)"
	_copy_file(SCENE_LIB_SCRIPT + ".stock", SCENE_LIB_SCRIPT)
	DirAccess.remove_absolute(SCENE_LIB_SCRIPT + ".stock")
	return "stock library view restored"

# ---------- collections ----------
func _our_collection_names() -> Dictionary:
	var names := {}
	var ours: Variant = JSON.parse_string(FileAccess.get_file_as_string(_addon_dir() + "/collections.json"))
	if ours is Array:
		for c in ours:
			if c is Dictionary: names[c.get("name", "")] = c
	return names

func _merge_collections() -> String:
	var ours := _our_collection_names()
	if ours.is_empty(): return "collections file unreadable"
	var current: Array = _read_json_array(SCENE_LIB_JSON)
	# one-time backup before first change
	if FileAccess.file_exists(SCENE_LIB_JSON) and not FileAccess.file_exists(SCENE_LIB_JSON + ".pre_sfx_fx"):
		_copy_file(SCENE_LIB_JSON, SCENE_LIB_JSON + ".pre_sfx_fx")
	var have := {}
	for c in current:
		if c is Dictionary: have[c.get("name", "")] = true
	var added := 0
	for name in ours:
		if not have.has(name):
			current.append(ours[name]); added += 1
	_write_json_array(SCENE_LIB_JSON, current)
	return "%d collections registered" % added

func _remove_collections() -> String:
	var ours := _our_collection_names()
	var current: Array = _read_json_array(SCENE_LIB_JSON)
	var kept: Array = []
	for c in current:
		if not (c is Dictionary and ours.has(c.get("name", ""))):
			kept.append(c)
	_write_json_array(SCENE_LIB_JSON, kept)
	return "%d collections removed" % (current.size() - kept.size())

# ---------- small fs helpers ----------
func _copy_file(src: String, dst: String) -> void:
	var data := FileAccess.get_file_as_bytes(src)
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f: f.store_buffer(data); f.close()

func _read_json_array(path: String) -> Array:
	if not FileAccess.file_exists(path): return []
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return v if v is Array else []

func _write_json_array(path: String, arr: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(arr, "\t")); f.close()
