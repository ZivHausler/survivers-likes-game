extends GutTest
## Structural test: verifies that acquired asset packs and license note are present.

func test_enemies_dir_has_pngs() -> void:
	var dir := DirAccess.open("res://art/enemies")
	assert_not_null(dir, "art/enemies/ should exist")
	if dir == null:
		return
	var found := false
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".png"):
			found = true
			break
		fname = dir.get_next()
	dir.list_dir_end()
	# Recurse one level if top-level has no PNGs (files may be in sub-folders)
	if not found:
		dir.list_dir_begin()
		fname = dir.get_next()
		while fname != "" and not found:
			if dir.current_is_dir() and fname != "." and fname != "..":
				var sub := DirAccess.open("res://art/enemies/" + fname)
				if sub != null:
					sub.list_dir_begin()
					var f2 := sub.get_next()
					while f2 != "":
						if f2.ends_with(".png"):
							found = true
							break
						f2 = sub.get_next()
					sub.list_dir_end()
			fname = dir.get_next()
		dir.list_dir_end()
	assert_true(found, "art/enemies/ should contain at least one .png file")


func test_characters_dir_has_pngs() -> void:
	var dir := DirAccess.open("res://art/characters")
	assert_not_null(dir, "art/characters/ should exist")
	if dir == null:
		return
	var found := false
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".png"):
			found = true
			break
		fname = dir.get_next()
	dir.list_dir_end()
	if not found:
		dir.list_dir_begin()
		fname = dir.get_next()
		while fname != "" and not found:
			if dir.current_is_dir() and fname != "." and fname != "..":
				var sub := DirAccess.open("res://art/characters/" + fname)
				if sub != null:
					sub.list_dir_begin()
					var f2 := sub.get_next()
					while f2 != "":
						if f2.ends_with(".png"):
							found = true
							break
						f2 = sub.get_next()
					sub.list_dir_end()
			fname = dir.get_next()
		dir.list_dir_end()
	assert_true(found, "art/characters/ should contain at least one .png file")


func test_tiles_dir_has_pngs() -> void:
	var dir := DirAccess.open("res://art/tiles")
	assert_not_null(dir, "art/tiles/ should exist")
	if dir == null:
		return
	var found := false
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".png"):
			found = true
			break
		fname = dir.get_next()
	dir.list_dir_end()
	if not found:
		dir.list_dir_begin()
		fname = dir.get_next()
		while fname != "" and not found:
			if dir.current_is_dir() and fname != "." and fname != "..":
				var sub := DirAccess.open("res://art/tiles/" + fname)
				if sub != null:
					sub.list_dir_begin()
					var f2 := sub.get_next()
					while f2 != "":
						if f2.ends_with(".png"):
							found = true
							break
						f2 = sub.get_next()
					sub.list_dir_end()
			fname = dir.get_next()
		dir.list_dir_end()
	assert_true(found, "art/tiles/ should contain at least one .png file")


func test_vfx_license_exists() -> void:
	var fa := FileAccess.open("res://addons/godot_vfx/LICENSE", FileAccess.READ)
	assert_not_null(fa, "addons/godot_vfx/LICENSE should exist")
	if fa != null:
		fa.close()


func test_asset_licenses_doc_exists() -> void:
	var fa := FileAccess.open("res://docs/notes/asset-licenses.md", FileAccess.READ)
	assert_not_null(fa, "docs/notes/asset-licenses.md should exist")
	if fa != null:
		fa.close()
