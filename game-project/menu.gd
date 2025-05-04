extends Control




func _on_play_pressed() -> void:
	global.isNavigator=true
	global.isDriver=false
	get_tree().change_scene_to_file("res://main.tscn")

func _on_driver_pressed() -> void:
	global.isDriver=true
	global.isNavigator=false
	get_tree().change_scene_to_file("res://main.tscn")
	#get_tree().change_scene_to_file("res://code_box.tscn")

func _ready() -> void:
	$AudioStreamPlayer.volume_db = global.musicVolume


#func _on_quit_pressed() -> void:
	#get_tree().quit()
