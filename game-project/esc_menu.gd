extends Control

signal volume
signal netToggle
var local_volume

@onready var code_box = $"../../"

func _ready() -> void:
	$MarginContainer/VBoxContainer/Control/HSlider.value = global.musicVolume
	local_volume= global.musicVolume
	$ColorRect/AnimatedSprite2D.play()
	$ColorRect/AnimatedSprite2D2.play()
	
func _process(delta: float) -> void:
	if local_volume != $MarginContainer/VBoxContainer/Control/HSlider.value:
		global.musicVolume = $MarginContainer/VBoxContainer/Control/HSlider.value
		local_volume = $MarginContainer/VBoxContainer/Control/HSlider.value
		volume.emit()

func _on_resume_pressed() -> void:
	get_parent().get_parent().pauseMenu()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://menu.tscn")


func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on: global.showNet = true
	elif !toggled_on: global.showNet = false
	netToggle.emit()
