## Cena inicial: os autoloads já carregaram os dados e a campanha; daqui o GameFlow abre a primeira cena.
extends Node


func _ready() -> void:
	GameFlow.start.call_deferred()
