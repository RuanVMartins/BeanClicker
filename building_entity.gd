extends Area2D
## BuildingEntity — representação cosmética de uma estrutura comprada.
## Anima conforme o tipo e pode ser arrastada livremente pelo cenário.

@onready var sprite: Sprite2D = $Sprite
@onready var collision: CollisionShape2D = $Collision

var building_id: String = "mini_bean"
var icon_path: String = ""
var target_size: float = 90.0

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var rainbow_tween: Tween
var movement_tween: Tween

const TEX_IDLE: Texture2D = preload("res://images/BeansIdle.png")
const TEX_MINING: Texture2D = preload("res://images/BeansMining.png")


func _ready() -> void:
	scale = Vector2.ONE
	_setup_visuals()
	var shape := RectangleShape2D.new()
	shape.size = _visual_size()
	collision.shape = shape
	GameManager.rainbow_activated.connect(_start_rainbow_effect)

	# Entrada com "pop"; as animações de loop só começam depois, para não brigarem
	sprite.modulate.a = 0.0
	var base_scale := sprite.scale
	sprite.scale = base_scale * 0.2
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", base_scale, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "modulate:a", 1.0, 0.2)
	tw.chain().tween_callback(_start_loops)


func _start_loops() -> void:
	if building_id == "mini_bean":
		_start_mining_animation()
	else:
		_start_gentle_movement()
	if GameManager.rainbow_active:
		_start_rainbow_effect()


func _setup_visuals() -> void:
	if building_id == "mini_bean":
		sprite.texture = TEX_IDLE
	elif icon_path != "" and ResourceLoader.exists(icon_path):
		sprite.texture = load(icon_path)
	else:
		sprite.texture = TEX_IDLE
	# Ícones pixel-art (128px) ficam nítidos com filtro nearest
	if sprite.texture and sprite.texture.get_width() <= 128:
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tex_size: Vector2 = sprite.texture.get_size()
	var max_dim: float = maxf(tex_size.x, tex_size.y)
	if max_dim > 0.0:
		sprite.scale = Vector2.ONE * (target_size / max_dim)


func _visual_size() -> Vector2:
	return sprite.texture.get_size() * sprite.scale if sprite.texture else Vector2(target_size, target_size)


func _start_mining_animation() -> void:
	var anim_timer := Timer.new()
	anim_timer.wait_time = randf_range(0.8, 1.5)
	anim_timer.timeout.connect(_animate_mining)
	add_child(anim_timer)
	anim_timer.start()


func _animate_mining() -> void:
	sprite.texture = TEX_MINING
	var tween := create_tween()
	tween.tween_property(sprite, "position:y", -10.0, 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): sprite.texture = TEX_IDLE)
	tween.tween_property(sprite, "position:y", 0.0, 0.12).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _start_gentle_movement() -> void:
	if movement_tween:
		movement_tween.kill()
	movement_tween = create_tween().set_loops()
	var t := randf_range(1.3, 1.8)
	match building_id:
		"fazendeiro":
			movement_tween.tween_property(sprite, "rotation", 0.08, t).set_trans(Tween.TRANS_SINE)
			movement_tween.tween_property(sprite, "rotation", -0.08, t).set_trans(Tween.TRANS_SINE)
		"plantacao", "racao":
			movement_tween.tween_property(sprite, "skew", 0.06, t).set_trans(Tween.TRANS_SINE)
			movement_tween.tween_property(sprite, "skew", -0.06, t).set_trans(Tween.TRANS_SINE)
		"mina", "banco":
			var base_scale: Vector2 = sprite.scale
			movement_tween.tween_property(sprite, "scale", Vector2(base_scale.x * 1.05, base_scale.y * 0.95), t).set_trans(Tween.TRANS_SINE)
			movement_tween.tween_property(sprite, "scale", base_scale, t).set_trans(Tween.TRANS_SINE)
		_:
			movement_tween.tween_property(sprite, "position:y", -8.0, t).set_trans(Tween.TRANS_SINE)
			movement_tween.tween_property(sprite, "position:y", 8.0, t).set_trans(Tween.TRANS_SINE)


func _start_rainbow_effect() -> void:
	if rainbow_tween:
		rainbow_tween.kill()
	rainbow_tween = create_tween().set_loops()
	for c in [Color(1, 0.5, 0.5), Color(1, 1, 0.5), Color(0.5, 1, 0.5), Color(0.5, 1, 1), Color(0.5, 0.5, 1), Color(1, 0.5, 1)]:
		rainbow_tween.tween_property(sprite, "modulate", c, 0.35)


# ══════════════════════════════════════
# DRAG AND DROP
# ══════════════════════════════════════
func _is_mouse_over() -> bool:
	var local_mouse: Vector2 = to_local(get_global_mouse_position())
	var half := _visual_size() * 0.5
	return absf(local_mouse.x) <= half.x and absf(local_mouse.y) <= half.y


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not is_dragging:
		if _is_mouse_over():
			is_dragging = true
			drag_offset = global_position - get_global_mouse_position()
			z_index = 100
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if is_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_dragging = false
		z_index = 0


func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() + drag_offset


## Saída com "puf" (penhora, falência).
func vanish() -> void:
	set_process(false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(sprite, "scale", sprite.scale * 0.1, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(sprite, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
