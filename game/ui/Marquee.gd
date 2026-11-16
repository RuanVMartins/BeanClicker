class_name Marquee
extends Control
## Letreiro de lâmpadas de cassino: bolinhas ao redor de um retângulo com
## efeito de "perseguição". Em vitórias, pisca tudo junto (celebrate()).

@export var spacing: float = 22.0
@export var radius: float = 3.2
@export var inset: float = 6.0
@export var speed: float = 7.0

var color_on: Color = Color("#FFE08A")
var color_off: Color = Color("#5A4512")
var _phase: float = 0.0
var _party: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_phase += delta * speed
	_party = maxf(0.0, _party - delta)
	queue_redraw()


func celebrate(seconds: float = 1.5) -> void:
	_party = seconds


func _draw() -> void:
	var r := Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return
	var per := 2.0 * (r.size.x + r.size.y)
	var count := int(per / spacing)
	var step := per / float(count)
	var tick := int(_phase)
	for i in range(count):
		var d := i * step
		var p: Vector2
		if d < r.size.x:
			p = r.position + Vector2(d, 0)
		elif d < r.size.x + r.size.y:
			p = r.position + Vector2(r.size.x, d - r.size.x)
		elif d < 2.0 * r.size.x + r.size.y:
			p = r.position + Vector2(r.size.x - (d - r.size.x - r.size.y), r.size.y)
		else:
			p = r.position + Vector2(0, r.size.y - (d - 2.0 * r.size.x - r.size.y))
		var lit: bool
		if _party > 0.0:
			lit = tick % 2 == 0
		else:
			lit = (i + tick) % 3 == 0
		if lit:
			draw_circle(p, radius * 2.2, Color(color_on, 0.18))
		draw_circle(p, radius, color_on if lit else color_off)
