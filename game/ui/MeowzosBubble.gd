class_name MeowzosBubble
extends HBoxContainer
## Retrato do Jeff Meowzos + balão de fala com efeito máquina de escrever.
## O humor dele aparece no corpo: "smug" balança, "angry" treme e avermelha,
## "shock" dá um pulo, "sad" murcha.

const PORTRAIT: Texture2D = preload("res://images/jeff_meowzos.svg")

var portrait: TextureRect
var bubble: PanelContainer
var text_label: Label
var name_label: Label
var _typewriter: Tween
var _mood_tween: Tween
var _portrait_base_y: float = 0.0


func _init(portrait_size: Vector2 = Vector2(96, 120), font_size: int = 14, listen: bool = true) -> void:
	add_theme_constant_override("separation", 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = portrait_size
	portrait_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait_holder)

	portrait = UIKit.texture_rect(PORTRAIT, portrait_size)
	portrait.size = portrait_size
	portrait.pivot_offset = Vector2(portrait_size.x * 0.5, portrait_size.y)
	portrait_holder.add_child(portrait)

	bubble = UIKit.panel(UIKit.box(UIKit.FELT, UIKit.GOLD_DARK, 12, 1, 12))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)

	var v := UIKit.vbox(3)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(v)
	name_label = UIKit.title("JEFF MEOWZOS", 12, UIKit.ORANGE)
	v.add_child(name_label)
	text_label = UIKit.wrap_label("", font_size, UIKit.INK)
	text_label.custom_minimum_size = Vector2(120, 0)
	v.add_child(text_label)

	if listen:
		Meowzos.said.connect(speak)


func speak(text: String, mood: String = "neutral") -> void:
	if not is_inside_tree():
		text_label.text = text
		return
	if _typewriter and _typewriter.is_valid():
		_typewriter.kill()
	text_label.text = text
	text_label.visible_ratio = 0.0
	_typewriter = create_tween()
	_typewriter.tween_property(text_label, "visible_ratio", 1.0, clampf(text.length() * 0.018, 0.4, 1.8))
	_play_mood(mood)


func _play_mood(mood: String) -> void:
	if _mood_tween and _mood_tween.is_valid():
		_mood_tween.kill()
	portrait.rotation = 0.0
	portrait.scale = Vector2.ONE
	portrait.modulate = Color.WHITE
	_mood_tween = create_tween()
	match mood:
		"smug":
			_mood_tween.tween_property(portrait, "rotation", 0.08, 0.15)
			_mood_tween.tween_property(portrait, "rotation", -0.06, 0.2)
			_mood_tween.tween_property(portrait, "rotation", 0.0, 0.15)
		"angry":
			portrait.modulate = Color(1.0, 0.55, 0.5)
			for i in range(5):
				_mood_tween.tween_property(portrait, "rotation", 0.07 * (1 if i % 2 == 0 else -1), 0.05)
			_mood_tween.tween_property(portrait, "rotation", 0.0, 0.05)
			_mood_tween.tween_property(portrait, "modulate", Color.WHITE, 0.6)
		"shock":
			_mood_tween.tween_property(portrait, "scale", Vector2(1.12, 0.88), 0.08)
			_mood_tween.tween_property(portrait, "scale", Vector2(0.92, 1.12), 0.1)
			_mood_tween.tween_property(portrait, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
		"sad":
			_mood_tween.tween_property(portrait, "scale", Vector2(1.04, 0.9), 0.4)
			_mood_tween.tween_property(portrait, "modulate", Color(0.7, 0.75, 0.9), 0.3)
			_mood_tween.tween_interval(0.8)
			_mood_tween.tween_property(portrait, "scale", Vector2.ONE, 0.3)
			_mood_tween.parallel().tween_property(portrait, "modulate", Color.WHITE, 0.3)
		_:
			_mood_tween.tween_property(portrait, "scale", Vector2(1.03, 1.03), 0.12)
			_mood_tween.tween_property(portrait, "scale", Vector2.ONE, 0.12)
