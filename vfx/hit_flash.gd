# See docs/notes/vfx-system.md
class_name HitFlash extends Node
## Static utility — call HitFlash.flash() anywhere; no instance needed.
## Visual only: tweens modulate to white and back. No logic change.

## Flash `ci` white then restore its original modulate over `dur` seconds.
## ci is Variant (not CanvasItem) so GDScript won't reject a freed object
## before is_instance_valid() can guard it.
static func flash(ci: Variant, dur: float) -> void:
	if not is_instance_valid(ci):
		return
	var canvas_item := ci as CanvasItem
	if canvas_item == null:
		return
	var original: Color = canvas_item.modulate
	var tween: Tween = canvas_item.create_tween()
	tween.tween_property(canvas_item, "modulate", Color.WHITE, dur * 0.4)
	tween.tween_property(canvas_item, "modulate", original, dur * 0.6)
