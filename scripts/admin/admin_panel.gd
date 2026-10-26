## O painel da barra de Admin (#130): à direita, por cima de tudo; as abas no alto, as ações da aba numa lista com
## rolagem e o aviso do que cada uma fez no pé. A ação que muda o save avisa antes ("Isso altera o save"): o primeiro
## aperto arma, o segundo faz. As que não valem na tela de agora ficam apagadas, com o motivo ao lado.
class_name AHAdminPanel
extends Control

const RECT := Rect2(1288, 24, 608, 1032)
## Quanto o aviso fica no pé (s).
const NOTICE_SECONDS := 4.0

var tab := "Mapas"
## A ação armada (a que muda o save, esperando o segundo aperto).
var armed := ""
## Quando a ação foi armada (ms): o segundo aperto vale só por ARM_MS.
var _armed_at := 0
const ARM_MS := 5000
var _box: PanelContainer
var _tabs: HFlowContainer
var _list: VBoxContainer
var _notice: Label
var _notice_left := 0.0
## O foco de quem estava antes (volta ao fechar).
var _focus_before: Control


func _init() -> void:
	name = "AdminPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	_box = AHKit.panel_box("large")
	_box.name = "Box"
	_box.position = RECT.position
	_box.custom_minimum_size = RECT.size
	_box.size = RECT.size
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_box.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	var title := AHKit.label(tr("Admin"), "panel_title", AHKit.AMBER, true, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(AHKitKey.make("admin_toggle", tr("%s fecha") % AHUiStyle.key_name("admin_toggle")))
	column.add_child(AHKit.label(tr("Build de teste: o que muda o save pede um segundo aperto."), "small", AHKit.MUTED))
	_tabs = HFlowContainer.new()
	_tabs.name = "Tabs"
	_tabs.add_theme_constant_override("h_separation", 6)
	_tabs.add_theme_constant_override("v_separation", 6)
	column.add_child(_tabs)
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.name = "Actions"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	_notice = AHKit.label("", "text", AHKit.AMBER, true)
	_notice.name = "Notice"
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.custom_minimum_size = Vector2(RECT.size.x - 64, 0)
	column.add_child(_notice)


func open() -> void:
	_focus_before = get_viewport().gui_get_focus_owner()
	visible = true
	armed = ""
	_fill()


## Fecha e devolve o foco a quem tinha (a tela de baixo volta a receber o controle).
func close() -> void:
	visible = false
	armed = ""
	if is_instance_valid(_focus_before) and _focus_before.is_inside_tree() and _focus_before.is_visible_in_tree():
		_focus_before.grab_focus()
	_focus_before = null


func show_tab(name_of_tab: String) -> void:
	tab = name_of_tab
	armed = ""
	_fill()


func _fill() -> void:
	for child in _tabs.get_children() + _list.get_children():
		child.get_parent().remove_child(child)
		child.queue_free()
	for name_of_tab in AHAdminActions.TABS:
		var button := AHKit.button(tr(name_of_tab), "chip")
		AHKit.style_as(button, "nav_active" if name_of_tab == tab else "nav")
		button.name = "Tab_" + name_of_tab
		button.pressed.connect(show_tab.bind(name_of_tab))
		_tabs.add_child(button)
	var first: Button = null
	for action in AHAdminActions.all():
		if action.tab != tab:
			continue
		var reason := AHAdminActions.blocked(action)
		# O texto inteiro na linha de cima e o motivo (ou "altera o save") embaixo: no Maior, nada corta o nome da ação.
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		_list.add_child(row)
		# A linha de lista do kit, sem caixa alta: os nomes longos (os inimigos, os eventos) cabem.
		var button := AHKit.button(tr(action.label), "chip")
		AHKit.style_as(button, "list")
		button.name = "Action_" + action.id
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = reason != ""
		button.pressed.connect(press.bind(action.id))
		row.add_child(button)
		if reason != "":
			row.add_child(AHKit.label(reason, "small", AHKit.MUTED))
		elif action.save:
			row.add_child(AHKit.label(tr("altera o save"), "small", AHKit.alert_text()))
		if first == null and reason == "":
			first = button
	if first != null and AHUiStyle.using_keys:
		# Depois do quadro: a lista pode ter sido refeita de novo nele (o botão já saiu).
		(func(): if is_instance_valid(first) and first.is_inside_tree(): first.grab_focus()).call_deferred()


## Aperta uma ação: a que muda o save arma no primeiro aperto e faz no segundo.
func press(id: String) -> String:
	var action: Dictionary = {}
	for entry in AHAdminActions.all():
		if entry.id == id:
			action = entry
	if action.is_empty():
		return ""
	var reason := AHAdminActions.blocked(action)
	if reason != "":
		notice(reason)
		return ""
	if action.save and (armed != id or Time.get_ticks_msec() - _armed_at > ARM_MS):
		armed = id
		_armed_at = Time.get_ticks_msec()
		notice(tr("Isso altera o save. Aperte de novo para confirmar."))
		return ""
	armed = ""
	var said := AHAdminActions.run(id)
	notice(said if said != "" else tr("Nada mudou: não dá agora (fora do lugar, ocupado ou sem o que fazer)."))
	# O que vale onde pode ter mudado (a luta acabou, a cena trocou).
	_fill.call_deferred()
	return said


func notice(text: String) -> void:
	_notice.text = text
	_notice_left = NOTICE_SECONDS


func _process(delta: float) -> void:
	if _notice_left > 0.0:
		_notice_left -= delta
		if _notice_left <= 0.0:
			_notice.text = ""


## Com a barra aberta, as teclas ficam nela (Voltar fecha); o mouse fora dela segue para a tela.
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and AHUiStyle.is_back(event):
		Admin.close()
		get_viewport().set_input_as_handled()
