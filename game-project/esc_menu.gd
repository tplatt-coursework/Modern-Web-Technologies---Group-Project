extends Control


@onready var code_box = $"../../"

func _on_resume_pressed() -> void:
	get_parent().pauseMenu()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")
