@tool
extends EditorScript

func _run() -> void:
	var output_file = FileAccess.open("res://all_project_code.txt", FileAccess.WRITE)
	if output_file:
		_combine_directory("res://", output_file)
		output_file.close()
		print("SUCCESS: Created all_project_code.txt with scripts AND scenes!")

func _combine_directory(path: String, output_file: FileAccess) -> void:
	var dir = DirAccess.open(path)
	if not dir:
		return
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		# Ignore hidden folders like .godot, .import, and addons
		if dir.current_is_dir():
			if not file_name.begins_with(".") and file_name != "addons":
				_combine_directory(path + file_name + "/", output_file)
		else:
			# Includes both .gd scripts and .tscn scene text files
			if file_name.ends_with(".gd") or file_name.ends_with(".tscn"):
				var file_path = path + file_name
				var script_file = FileAccess.open(file_path, FileAccess.READ)
				if script_file:
					output_file.store_string("\n\n" + "=".repeat(80) + "\n")
					output_file.store_string("FILE: " + file_path + "\n")
					output_file.store_string("=".repeat(80) + "\n\n")
					output_file.store_string(script_file.get_as_text())
					script_file.close()
					
		file_name = dir.get_next()
