extends Sprite2D


func _on_item_rect_changed() -> void:
	material.set_shader_parameter("tile_times", Vector2(3 * get_viewport().size / 282.0, get_viewport().size / 282.0))
