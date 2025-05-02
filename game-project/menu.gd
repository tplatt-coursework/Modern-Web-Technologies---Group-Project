extends Control




func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://game_box.tscn")




func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_driver_pressed() -> void:
	get_tree().change_scene_to_file("res://code_box.tscn")
