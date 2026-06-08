extends Control
class_name HUD

@export var gold_coin_label : Label
@export var portal_label : Label

func _ready() -> void:
	gold_coin_label.text = "x 0"
	portal_label.text = "Closed"

func _update_gold_coin_count(number : int):
	gold_coin_label.text = "x " + str(number)
	

func _update_portal_open():
	portal_label.text = "Open"

func _update_portal_close():
	portal_label.text = "Closed"
