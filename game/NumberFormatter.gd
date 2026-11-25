extends Node
## Formatação de números no padrão brasileiro (1.234.567 / 1,23 Mi).
## Registrado como autoload "NumberFormatter".

const SUFFIXES: Array[String] = [
	"", "mil", "Mi", "Bi", "Tri", "Quatri", "Quinti", "Sexti", "Septi", "Octi", "Noni", "Deci"
]


## Abaixo de 1 milhão usa separador de milhar; acima, sufixo com 3 dígitos significativos.
func format_number(n: float) -> String:
	if n < 0.0:
		return "-" + format_number(-n)
	n = floor(n + 0.001)
	if n < 1000.0:
		return str(int(n))
	if n < 1_000_000.0:
		return _thousands(int(n))

	var magnitude := 0
	var display := n
	while display >= 1000.0 and magnitude < SUFFIXES.size() - 1:
		display /= 1000.0
		magnitude += 1

	var formatted: String
	if display >= 100.0:
		formatted = str(int(display))
	elif display >= 10.0:
		formatted = "%.1f" % (floor(display * 10.0) / 10.0)
	else:
		formatted = "%.2f" % (floor(display * 100.0) / 100.0)
	if "." in formatted:
		formatted = formatted.rstrip("0").rstrip(".")
	return formatted.replace(".", ",") + " " + SUFFIXES[magnitude]


## CPS pode ser fracionário no início do jogo.
func format_cps(n: float) -> String:
	if n <= 0.0:
		return "0"
	if n < 10.0:
		return ("%.1f" % n).replace(".", ",")
	return format_number(n)


## Duração legível: 1h 05m, 4m 12s, 9s.
func format_time(seconds: float) -> String:
	var s := int(maxf(seconds, 0.0))
	var h := s / 3600
	var m := (s % 3600) / 60
	var sec := s % 60
	if h > 0:
		return "%dh %02dm" % [h, m]
	if m > 0:
		return "%dm %02ds" % [m, sec]
	return "%ds" % sec


func format_percent(ratio: float) -> String:
	return ("%.0f%%" % (ratio * 100.0))


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			out = "." + out
		out = s[i] + out
		count += 1
	return out
