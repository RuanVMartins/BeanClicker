class_name Sparkline
extends Control
## Mini-gráfico de cotação: registra uma amostra por segundo e desenha a curva
## verde (subindo) ou vermelha (caindo), como no canto de um terminal de bolsa.

const SAMPLES: int = 60

var samples: PackedFloat32Array = PackedFloat32Array()
var source: Callable
var _accum: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_accum += delta
	if _accum < 1.0 or not source.is_valid():
		return
	_accum = 0.0
	samples.append(float(source.call()))
	if samples.size() > SAMPLES:
		samples.remove_at(0)
	queue_redraw()


## Variação percentual entre a primeira e a última amostra da janela.
func change_ratio() -> float:
	if samples.size() < 2 or samples[0] <= 0.0:
		return 0.0
	return samples[samples.size() - 1] / samples[0] - 1.0


func reset() -> void:
	samples.clear()
	queue_redraw()


func _draw() -> void:
	# Grade fininha de fundo
	for i in range(1, 4):
		var y := size.y * i / 4.0
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.05), 1.0)
	if samples.size() < 2:
		return
	var lo := samples[0]
	var hi := samples[0]
	for v in samples:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	var span := maxf(hi - lo, absf(hi) * 0.001 + 0.0001)
	var pts := PackedVector2Array()
	var step := size.x / float(SAMPLES - 1)
	var x0 := size.x - step * (samples.size() - 1)
	for i in range(samples.size()):
		var y := size.y - 2.0 - (samples[i] - lo) / span * (size.y - 4.0)
		pts.append(Vector2(x0 + i * step, y))
	var up := samples[samples.size() - 1] >= samples[0]
	var col := UIKit.PROFIT if up else UIKit.RISK
	var area := pts.duplicate()
	area.append(Vector2(pts[pts.size() - 1].x, size.y))
	area.append(Vector2(pts[0].x, size.y))
	draw_colored_polygon(area, Color(col, 0.15))
	draw_polyline(pts, col, 1.6, true)
	draw_circle(pts[pts.size() - 1], 2.5, col)
