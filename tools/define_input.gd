## Grava as ações de input no project.godot (teclado e gamepad). Rode depois de mudar a tabela abaixo:
##   Godot --headless --path . --script res://tools/define_input.gd
## O editor da Godot mostra as mesmas ações em Projeto > Configurações > Mapa de Entrada.
extends SceneTree

# Ação: teclas físicas, botões do gamepad (JOY_BUTTON_*) e eixos do gamepad ([eixo, direção]).
const ACTIONS := {
	"move_left": {"keys": [KEY_A, KEY_LEFT], "buttons": [JOY_BUTTON_DPAD_LEFT], "axes": [[JOY_AXIS_LEFT_X, -1.0]]},
	"move_right": {"keys": [KEY_D, KEY_RIGHT], "buttons": [JOY_BUTTON_DPAD_RIGHT], "axes": [[JOY_AXIS_LEFT_X, 1.0]]},
	# Para o fundo do cenário (longe da câmera) e para a frente.
	"move_back": {"keys": [KEY_W, KEY_UP], "buttons": [JOY_BUTTON_DPAD_UP], "axes": [[JOY_AXIS_LEFT_Y, -1.0]]},
	"move_front": {"keys": [KEY_S, KEY_DOWN], "buttons": [JOY_BUTTON_DPAD_DOWN], "axes": [[JOY_AXIS_LEFT_Y, 1.0]]},
	"run": {"keys": [KEY_SHIFT], "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	"interact": {"keys": [KEY_E, KEY_ENTER], "buttons": [JOY_BUTTON_A]},
	"cancel": {"keys": [KEY_BACKSPACE], "buttons": [JOY_BUTTON_B]},
	"menu": {"keys": [KEY_ESCAPE], "buttons": [JOY_BUTTON_START]},
	"inventory": {"keys": [KEY_I], "buttons": [JOY_BUTTON_Y]},
	# Estação: esconde a interface para olhar o corte limpo (o Ocultar HUD da Unreal).
	"hide_hud": {"keys": [KEY_F2], "buttons": [JOY_BUTTON_BACK]},
	# Estação (#60): os detalhes do relatório da volta e Preparar expedição (só nas telas da Estação).
	"report_details": {"keys": [KEY_V], "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	"station_prepare": {"keys": [KEY_G], "buttons": [JOY_BUTTON_X]},
	# A Estação (#131): a vista geral anda para os lados (o analógico direito; o mouse na borda ou arrastando) e, com um
	# cômodo aberto, o vizinho do mesmo andar.
	"station_pan_left": {"axes": [[JOY_AXIS_RIGHT_X, -1.0]]},
	"station_pan_right": {"axes": [[JOY_AXIS_RIGHT_X, 1.0]]},
	"station_room_prev": {"keys": [KEY_PAGEUP], "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	"station_room_next": {"keys": [KEY_PAGEDOWN], "buttons": [JOY_BUTTON_RIGHT_SHOULDER]},
	# Combate: as quatro habilidades e as ações (Mochila é a mesma tecla da exploração).
	"combat_ability_1": {"keys": [KEY_1]},
	"combat_ability_2": {"keys": [KEY_2]},
	"combat_ability_3": {"keys": [KEY_3]},
	"combat_ability_4": {"keys": [KEY_4]},
	"combat_move": {"keys": [KEY_Q], "buttons": [JOY_BUTTON_LEFT_SHOULDER]},
	"combat_defend": {"keys": [KEY_W], "buttons": [JOY_BUTTON_X]},
	"combat_flee": {"keys": [KEY_F]},
	# Examinar (#89): o foco passa pelos personagens da luta e a ficha de cada um abre (o mouse e o toque apontam direto).
	"combat_examine": {"keys": [KEY_X], "buttons": [JOY_BUTTON_LEFT_STICK]},
	# O registro da luta, escondido por padrão (#56): abre e fecha.
	"combat_log": {"keys": [KEY_L], "buttons": [JOY_BUTTON_RIGHT_STICK]},
	# A barra de Admin para testes (#130): só na build de teste ou com --admin.
	"admin_toggle": {"keys": [KEY_F1]},
	# As teclas de teste antigas da rua (a barra de Admin as liga em Ajustes).
	"debug_rain": {"keys": [KEY_R]},
	"debug_time": {"keys": [KEY_T]},
	"debug_post": {"keys": [KEY_P]},
	"debug_colliders": {"keys": [KEY_C]},
	"debug_combat": {"keys": [KEY_K]},
}


func _initialize() -> void:
	for action in ACTIONS:
		var spec: Dictionary = ACTIONS[action]
		var events: Array = []
		for keycode in spec.get("keys", []):
			var key := InputEventKey.new()
			key.physical_keycode = keycode
			events.append(key)
		for button in spec.get("buttons", []):
			var joy := InputEventJoypadButton.new()
			joy.button_index = button
			events.append(joy)
		for axis in spec.get("axes", []):
			var motion := InputEventJoypadMotion.new()
			motion.axis = axis[0]
			motion.axis_value = axis[1]
			events.append(motion)
		for event in events:
			# Qualquer teclado ou gamepad, como as ações criadas pelo editor.
			event.device = -1
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.25, "events": events})
	var error := ProjectSettings.save()
	print("%d ações gravadas no project.godot (%s)." % [ACTIONS.size(), error_string(error)])
	quit(0 if error == OK else 1)
