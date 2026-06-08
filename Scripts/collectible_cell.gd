extends Area2D

#signal collected

func _on_body_entered(body: Node2D) -> void:
	if body is PlayerController:
		queue_free()
		GameManager._collectible_cell_picked()
		#collected.emit()
