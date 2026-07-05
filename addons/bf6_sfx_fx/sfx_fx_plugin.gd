@tool
extends EditorPlugin
# BF6 SFX & FX Folders — one-click installer.
#
# What "Install" does (all reversible, backups kept):
#   1. Extracts content.zip into the project: placeable wrapper scenes for the
#      game's FX (objects/fx + scripts/fx) and SFX (objects/audio +
#      scripts/audio). Each wrapper follows the SDK's own spawnable-object
#      pattern, so the level validator and exporter treat them like any other
#      placed object.
#   2. Swaps the Scene Library addon's script for the folder-view build
#      (original backed up as scene_library.gd.stock) so FX/SFX appear as two
#      tidy folder items per map instead of flooding the tab bar.
#   3. Merges the per-map FX/SFX collections into scene_library.json
#      (backed up first; existing collections are never touched).
#
# A restart of the editor finishes the install (the Scene Library script and
# the new scenes load on startup).

const SCENE_LIB_SCRIPT := "res://addons/scene-library/scripts/scene_library.gd"
const SCENE_LIB_JSON := "res://addons/scene-library/scene_library.json"

var dock: VBoxContainer
var status: Label

# addon folder derived from this script's own path, so any install location works
func _addon_dir() -> String:
	return (get_script() as Script).resource_path.get_base_dir()

func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "SFX & FX"

	var title := Label.new()
	title.text = "SFX & FX Folders"
	dock.add_child(title)

	var install := Button.new()
	install.text = "Install / Repair"
	install.tooltip_text = "Extract the FX/SFX library into the project, enable the folder view, and register the Object Library collections. Backups are kept; restart the editor afterwards."
	install.pressed.connect(_install)
	dock.add_child(install)

	var restore := Button.new()
	restore.text = "Restore stock library view"
	restore.tooltip_text = "Put back the original Scene Library script and remove the FX/SFX collections. Placed FX/SFX in your levels keep working; the wrapper files stay."
	restore.pressed.connect(_restore)
	dock.add_child(restore)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.text = _current_state()
	dock.add_child(status)

	var ver := Label.new()
	var cf := ConfigFile.new()
	if cf.load(_addon_dir() + "/plugin.cfg") == OK:
		ver.text = "v%s" % cf.get_value("plugin", "version", "?")
		ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
		dock.add_child(ver)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)

func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()

func _current_state() -> String:
	var have_content := DirAccess.dir_exists_absolute("res://objects/fx")
	var patched := FileAccess.file_exists(SCENE_LIB_SCRIPT + ".stock")
	if have_content and patched:
		return "Installed. FX/SFX folders appear in each map's Object Library."
	if have_content:
		return "Library files present; folder view not installed — hit Install / Repair."
	return "Not installed yet — hit Install / Repair."

# ---------- install ----------
func _install() -> void:
	var n_files := _extract_content()
	if n_files < 0:
		status.text = "content.zip missing or unreadable — reinstall the addon."
		return
	var lib := _patch_scene_library()
	var colls := _merge_collections()
	EditorInterface.get_resource_filesystem().scan()
	status.text = "Installed %d files, %s, %s.\nRestart the editor to finish." % [n_files, lib, colls]

func _extract_content() -> int:
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

func _patch_scene_library() -> String:
	if not FileAccess.file_exists(SCENE_LIB_SCRIPT):
		return "Scene Library addon not found (folder view skipped)"
	var patched := _addon_dir() + "/scene_library_patch/scene_library.gd.patched"
	if not FileAccess.file_exists(patched):
		return "patch file missing (folder view skipped)"
	# keep the very first stock copy as the restore point
	if not FileAccess.file_exists(SCENE_LIB_SCRIPT + ".stock"):
		var stock := FileAccess.get_file_as_bytes(SCENE_LIB_SCRIPT)
		var b := FileAccess.open(SCENE_LIB_SCRIPT + ".stock", FileAccess.WRITE)
		if b: b.store_buffer(stock); b.close()
	var data := FileAccess.get_file_as_bytes(patched)
	var f := FileAccess.open(SCENE_LIB_SCRIPT, FileAccess.WRITE)
	if f == null: return "could not write Scene Library script"
	f.store_buffer(data); f.close()
	return "folder view enabled"

func _merge_collections() -> String:
	var ours: Variant = JSON.parse_string(FileAccess.get_file_as_string(_addon_dir() + "/collections.json"))
	if not (ours is Array): return "collections file unreadable"
	var current: Array = []
	if FileAccess.file_exists(SCENE_LIB_JSON):
		var cur: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENE_LIB_JSON))
		if cur is Array: current = cur
		# one-time backup before we ever touch it
		if not FileAccess.file_exists(SCENE_LIB_JSON + ".pre_sfx_fx"):
			var b := FileAccess.open(SCENE_LIB_JSON + ".pre_sfx_fx", FileAccess.WRITE)
			if b: b.store_string(FileAccess.get_file_as_string(SCENE_LIB_JSON)); b.close()
	var have := {}
	for c in current:
		if c is Dictionary: have[c.get("name", "")] = true
	var added := 0
	for c in ours:
		if c is Dictionary and not have.has(c.get("name", "")):
			current.append(c); added += 1
	var f := FileAccess.open(SCENE_LIB_JSON, FileAccess.WRITE)
	if f == null: return "could not write scene_library.json"
	f.store_string(JSON.stringify(current, "\t"))
	f.close()
	return "%d collections registered" % added

# ---------- restore ----------
func _restore() -> void:
	var msgs: Array = []
	# stock scene-library script back
	if FileAccess.file_exists(SCENE_LIB_SCRIPT + ".stock"):
		var stock := FileAccess.get_file_as_bytes(SCENE_LIB_SCRIPT + ".stock")
		var f := FileAccess.open(SCENE_LIB_SCRIPT, FileAccess.WRITE)
		if f:
			f.store_buffer(stock); f.close()
			DirAccess.remove_absolute(SCENE_LIB_SCRIPT + ".stock")
			msgs.append("stock library view restored")
	# drop only OUR collections
	var ours: Variant = JSON.parse_string(FileAccess.get_file_as_string(_addon_dir() + "/collections.json"))
	if ours is Array and FileAccess.file_exists(SCENE_LIB_JSON):
		var names := {}
		for c in ours:
			if c is Dictionary: names[c.get("name", "")] = true
		var cur: Variant = JSON.parse_string(FileAccess.get_file_as_string(SCENE_LIB_JSON))
		if cur is Array:
			var kept: Array = []
			for c in cur:
				if not (c is Dictionary and names.has(c.get("name", ""))):
					kept.append(c)
			var f2 := FileAccess.open(SCENE_LIB_JSON, FileAccess.WRITE)
			if f2:
				f2.store_string(JSON.stringify(kept, "\t")); f2.close()
				msgs.append("collections removed")
	msgs.append("wrapper files kept (placed FX/SFX keep working)")
	EditorInterface.get_resource_filesystem().scan()
	status.text = "Restored: %s.\nRestart the editor to finish." % ", ".join(msgs)
