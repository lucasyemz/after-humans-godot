## O que cada teste recebe em run(t): conta as verificações e guarda as falhas com uma mensagem clara.
extends RefCounted

var checks := 0
var failures := PackedStringArray()
## Informações para o resumo (ex.: "48 de 48 lutas").
var notes := PackedStringArray()


func check(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
	return condition


func equal(actual, expected, message: String) -> bool:
	return check(actual == expected, "%s (esperado: %s; veio: %s)" % [message, str(expected).left(300), str(actual).left(300)])


func note(text: String) -> void:
	notes.append(text)
