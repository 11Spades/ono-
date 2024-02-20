# This file handles the visual effects I put on the buttons.

extends TextureButton


func _on_mouse_entered():
	var up_tween = create_tween()
	up_tween.set_ease(Tween.EASE_OUT)
	up_tween.set_trans(Tween.TRANS_QUART)
	up_tween.tween_property($ColorClip/FillColor, "position", Vector2(0, 0), 1)
	return


func _on_mouse_exited():
	var down_tween = create_tween()
	down_tween.set_ease(Tween.EASE_OUT)
	down_tween.set_trans(Tween.TRANS_QUART)
	down_tween.tween_property($ColorClip/FillColor, "position", Vector2(0, self.size.y), 1)
