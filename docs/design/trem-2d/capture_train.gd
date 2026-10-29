## O trem 2D (#149) no motor: monta o vagão em camadas (art/train, no contrato de docs/design/trem-2d/contract.json) num
## palco 2.5D de prova e fotografa a sequência inteira, quadro a quadro: a chegada no túnel freando com faísca, a plataforma
## com as portas abrindo, a equipe embarcando e vista pelas janelas, as portas fechando e a partida com as rodas girando.
## Com --passage, fotografa a cena de passagem pintada (o interior do mesmo vagão, a equipe sentada, o túnel nas janelas).
##   xvfb-run -n 94 -s "-screen 0 1920x1080x24" "$GODOT" --path . --rendering-driver opengl3 --resolution 1920x1080 \
##     -s res://docs/design/trem-2d/capture_train.gd -- --out=<pasta> [--passage] [--stills]
## Sem --stills grava todos os quadros (frame_0000.png…, 30 por segundo) para o vídeo; com --stills, só as fotos da página.
##
## É uma prova do que a integração faz, não uma cena do jogo: o palco (a plataforma, a parede, os trilhos) é provisório,
## a equipe desliza com a pose de pé (o jogo usa a caminhada da exploração), e os números do contrato é que valem.
extends SceneTree

const CONTRACT := "res://docs/design/trem-2d/contract.json"
const FPS := 30.0
## A câmera da exploração: 19 m da faixa, 1,7 m acima do piso, o quadro com 11,2 m de largura.
const CAM_DIST := 19.0
const CAM_HEIGHT := 1.7
const FRAME_WIDTH := 11.2
## A equipe da prova (a da abertura com o Nick) e onde cada um espera na plataforma e fica dentro do vagão (x em m, no
## vagão). Sentido: quem vem da esquerda entra pela porta A, quem vem da direita, pela B.
const TEAM := [
	{"id": "hero_gato_nick", "wait": -4.4, "door": "A", "inside": -2.85},
	{"id": "hero_cao_bento", "wait": -3.5, "door": "A", "inside": -1.7},
	{"id": "hero_coruja_vespera", "wait": 3.4, "door": "B", "inside": 1.1},
	{"id": "hero_sapo_iris", "wait": 4.3, "door": "B", "inside": 2.3},
]
const HEIGHTS := {"hero_cao_bento": 1.72, "hero_gato_nick": 1.5, "hero_sapo_iris": 1.38, "hero_coruja_vespera": 1.66}

var out := ""
var stills := false
var passage := false
var c: Dictionary
var art: Dictionary
var px := 128.0
var train: Node3D
var leaves := {}
var wheels: Array[MeshInstance3D] = []
var sparks: Array[CPUParticles3D] = []
var interior_lit: MeshInstance3D
var heroes := []
var camera: Camera3D
var platform: Node3D
var _frame := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
		elif arg == "--stills":
			stills = true
		elif arg == "--passage":
			passage = true
	DirAccess.make_dir_recursive_absolute(out)
	c = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	art = JSON.parse_string(FileAccess.get_file_as_string("res://data/presentation/combat_art.json")).heroes
	# Sem a cena principal: só o palco da prova.
	if current_scene != null:
		current_scene.queue_free()
	await process_frame
	if passage:
		await _passage()
	else:
		_stage()
		await _sequence()
	quit(0)


# ---------------------------------------------------------------------------------------------------------- o palco 3D

func _stage() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.015, 0.015, 0.018)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.42, 0.45)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = env
	root.add_child(world)
	# A parede do fundo (o concreto do túnel) e os trilhos.
	var wall: MeshInstance3D = _box(Vector3(0, 3.0, -3.2), Vector3(80, 8, 0.2), _flat(Color(0.11, 0.11, 0.12), 1.0))
	root.add_child(wall)
	for z in [-0.06, -1.45]:
		root.add_child(_box(Vector3(0, 0.04, z), Vector3(60, 0.08, 0.08), _flat(Color(0.32, 0.3, 0.28), 0.4)))
	root.add_child(_box(Vector3(0, -0.05, 1.0), Vector3(80, 0.1, 9.0), _flat(Color(0.16, 0.15, 0.14), 1.0)))
	# A plataforma: o piso na altura do chão do vagão, na frente dele (cobre as rodas, como no Tutorial), com a faixa.
	var floor_h: float = (c.train.rail_y - c.train.floor_y) / px
	platform = Node3D.new()
	root.add_child(platform)
	platform.add_child(_box(Vector3(0, floor_h * 0.5, 3.6), Vector3(60, floor_h, 6.2), _surface("res://art/scenarios/T_TU27.webp", Color(0.42, 0.41, 0.4))))
	platform.add_child(_box(Vector3(0, floor_h + 0.005, 0.68), Vector3(60, 0.01, 0.16), _flat(Color(0.75, 0.58, 0.12), 0.8)))
	_train()
	_team()
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = rad_to_deg(2.0 * atan(FRAME_WIDTH * 0.5 / CAM_DIST))
	camera.far = 200.0
	root.add_child(camera)
	camera.current = true
	# A luz de cima da plataforma, fraca e quente; a fria vem de dentro do vagão.
	var key := OmniLight3D.new()
	key.position = Vector3(0, 6.5, 4.0)
	key.light_color = Color(1.0, 0.86, 0.7)
	key.light_energy = 1.2
	key.omni_range = 16.0
	root.add_child(key)


func _box(center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material
	node.position = center
	return node


func _flat(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


## O concreto do lugar, projetado pelo mundo em placas de 2,4 m.
func _surface(file: String, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(file)
	material.albedo_color = tint
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE / 2.4
	material.roughness = 1.0
	return material


func _train() -> void:
	var t: Dictionary = c.train
	train = Node3D.new()
	root.add_child(train)
	var size := Vector2(t.canvas[0], t.canvas[1])
	# O interior fica atrás da carroceria (o fundo do vagão), maior na mesma proporção da distância, para casar com as
	# janelas vistas de frente; a equipe dentro fica entre os dois.
	var depth: float = t.depth.interior_z
	var k := (CAM_DIST - depth) / CAM_DIST
	interior_lit = _layer(t.layers.interior, size, Vector2.ZERO, depth, k)
	(interior_lit.material_override as StandardMaterial3D).emission_enabled = true
	(interior_lit.material_override as StandardMaterial3D).emission_texture = load(t.layers.interior)
	(interior_lit.material_override as StandardMaterial3D).emission_energy_multiplier = t.interior_emission
	for name in t.leaves:
		var leaf: Dictionary = t.leaves[name]
		var node := _layer(leaf.file, Vector2(leaf.size[0], leaf.size[1]), Vector2(leaf.closed_top_left[0], leaf.closed_top_left[1]), t.depth.leaves, 1.0, leaf.blend == "alpha")
		leaves[name] = {"node": node, "home": node.position.x, "offset": leaf.open_offset_x / px}
	_layer(t.layers.body, size, Vector2.ZERO, 0.0)
	_layer(t.layers.glass, size, Vector2.ZERO, t.depth.glass, 1.0, true)
	var r: float = t.wheel_radius
	for center in t.wheel_centers:
		wheels.append(_layer(t.layers.wheel, Vector2(2 * r, 2 * r), Vector2(center[0] - r, center[1] - r), t.depth.wheels))
		sparks.append(_sparks(Vector3((center[0] - size.x * 0.5) / px - 0.12, 0.02, t.depth.wheels + 0.02)))
	_layer(t.layers.bogie, size, Vector2.ZERO, t.depth.bogie)
	# A luz fria do vagão: acesa por dentro, ela sai pelas portas e janelas e pinta a plataforma de azul.
	for x in [-2.8, 0.0, 2.8]:
		var light := OmniLight3D.new()
		light.position = Vector3(x, 3.0, -0.6)
		light.light_color = Color(0.62, 0.8, 1.0)
		light.light_energy = 3.0
		light.omni_range = 6.5
		train.add_child(light)


## Uma camada do vagão: a textura num quad, com o canto de cima à esquerda em `top_left` (px, no quadro do vagão), o chão
## do vagão nos trilhos (y = 0 no trilho) e o meio do vagão em x = 0.
func _layer(file: String, size: Vector2, top_left: Vector2, z: float, scale := 1.0, blend := false) -> MeshInstance3D:
	var t: Dictionary = c.train
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = size / px * scale
	quad.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(file)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if blend else BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	quad.material_override = material
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var center := top_left + size * 0.5
	var cam := Vector2(0, (t.rail_y - t.floor_y) / px + CAM_HEIGHT)
	var p := Vector2((center.x - t.canvas[0] * 0.5) / px, (t.rail_y - center.y) / px)
	p = cam + (p - cam) * scale
	quad.position = Vector3(p.x, p.y, z)
	train.add_child(quad)
	return quad


func _sparks(at: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = at
	p.amount = 46
	p.lifetime = 0.32
	p.emitting = false
	p.local_coords = false
	p.direction = Vector3(-1.0, 0.55, 0.15)
	p.spread = 28.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -9.8, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	p.particle_flag_align_y = true
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.035, 0.16)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(c.train.layers.spark)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.billboard_keep_scale = true
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	p.mesh = mesh
	train.add_child(p)
	# O brilho no trilho onde a roda raspa.
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.25)
	glow.light_energy = 0.0
	glow.omni_range = 1.6
	p.add_child(glow)
	return p


func _team() -> void:
	for member in TEAM:
		var idle: Dictionary = art[member.id].idle
		var texture: Texture2D = load(idle.file)
		# A pintura está na metade do canvas do manifesto.
		var half: float = texture.get_width() / float(idle.canvas[0])
		var ps: float = HEIGHTS[member.id] / (idle.body_reference_pixels * half)
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(texture.get_width(), texture.get_height()) * ps
		quad.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.alpha_scissor_threshold = 0.5
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		quad.material_override = material
		var feet := Node3D.new()
		feet.add_child(quad)
		var ax: float = idle.anchor[0] * half
		var ay: float = idle.anchor[1] * half
		quad.position = Vector3((texture.get_width() * 0.5 - ax) * ps, (ay - texture.get_height() * 0.5) * ps, 0)
		root.add_child(feet)
		heroes.append({"feet": feet, "quad": quad, "material": material, "m": member})


# ------------------------------------------------------------------------------------------------------------ a sequência

func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _doors(open: float) -> void:
	for name in leaves:
		var leaf: Dictionary = leaves[name]
		leaf.node.position.x = leaf.home + leaf.offset * _ease(open)


## O vagão em x, com as rodas girando pela distância andada.
var _last_x := 0.0
var _angle := 0.0
func _move(x: float) -> void:
	_angle -= (x - _last_x) / (c.train.wheel_radius / px)
	_last_x = x
	train.position.x = x
	for wheel in wheels:
		wheel.rotation.z = _angle


func _brake(on: bool, strength := 1.0) -> void:
	for p in sparks:
		p.emitting = on
		p.get_child(0).light_energy = 2.2 * strength if on else 0.0


func _shot_camera(tunnel: bool) -> void:
	var floor_h: float = (c.train.rail_y - c.train.floor_y) / px
	platform.visible = not tunnel
	# No túnel a câmera desce para a altura dos trilhos, sem a plataforma: é ali que as rodas aparecem.
	var y := floor_h + CAM_HEIGHT if not tunnel else 2.9
	camera.position = Vector3(0, y, CAM_DIST)
	camera.look_at(Vector3(0, y - CAM_DIST * tan(deg_to_rad(0.5)), 0))


func _place_team(state: String, f := 0.0) -> void:
	var floor_h: float = (c.train.rail_y - c.train.floor_y) / px
	var inside_z: float = c.train.depth.team_inside
	for hero in heroes:
		var m: Dictionary = hero.m
		var door: Array = c.train.doors[0 if m.door == "A" else 1]
		var door_x: float = ((door[0] + door[2]) * 0.5 - c.train.canvas[0] * 0.5) / px + (0.22 if m.wait > 0 else -0.22)
		var wait := Vector3(m.wait, floor_h, 1.35)
		var at_door := Vector3(door_x, floor_h, 0.55)
		var in_door := Vector3(door_x, floor_h, inside_z)
		var inside := Vector3(m.inside, floor_h, inside_z)
		var left: bool = m.wait > 0
		var p := wait
		match state:
			"wait":
				p = wait
			"board":
				# Cada um sai num tempo (a fila), anda até a porta, entra e vai para o seu lugar.
				var order: int = TEAM.find(m) % 2
				var s := clampf(f * 1.25 - order * 0.25, 0.0, 1.0)
				if s < 0.5:
					p = wait.lerp(at_door, _ease(s / 0.5))
				elif s < 0.72:
					p = at_door.lerp(in_door, _ease((s - 0.5) / 0.22))
				else:
					p = in_door.lerp(inside, _ease((s - 0.72) / 0.28))
					left = m.inside < door_x
				hero.feet.position = p + Vector3(0, absf(sin(f * 40.0 + order)) * 0.025 * (1.0 if s > 0.0 and s < 1.0 else 0.0), 0)
				_flip(hero, left)
				continue
			"inside":
				p = inside
				left = m.inside < door_x
		hero.feet.position = p
		_flip(hero, left)
		# Quem está dentro anda com o vagão.
		if state == "inside":
			hero.feet.position.x += train.position.x


func _flip(hero: Dictionary, left: bool) -> void:
	hero.material.uv1_scale = Vector3(-1 if left else 1, 1, 1)
	hero.material.uv1_offset = Vector3(1 if left else 0, 0, 0)


func _sequence() -> void:
	var total := 0
	# 1. A chegada no túnel: o vagão entra pela esquerda freando, com faísca nas rodas, e para no meio.
	_shot_camera(true)
	_doors(0.0)
	for h in heroes:
		h.feet.visible = false
	var n := int(3.4 * FPS)
	for i in n:
		var t := i / float(n - 1)
		var x := -22.0 * pow(1.0 - _ease(minf(t / 0.86, 1.0)) , 1.0)
		_move(x)
		_brake(t > 0.18 and t < 0.86, 1.0 - t)
		await _out(i == int(n * 0.55), "tunnel_brake")
	_brake(false)
	# 2. A plataforma: as portas abrem, a equipe embarca, as portas fecham.
	_shot_camera(false)
	for h in heroes:
		h.feet.visible = true
	_place_team("wait")
	for i in int(0.8 * FPS):
		await _out(i == 10, "platform_waiting")
	n = int(0.8 * FPS)
	for i in n:
		_doors(i / float(n - 1))
		await _out(i == n - 1, "platform_open")
	n = int(3.2 * FPS)
	for i in n:
		_place_team("board", i / float(n - 1))
		await _out(i == int(n * 0.42), "platform_boarding")
	_place_team("inside")
	n = int(0.8 * FPS)
	for i in n:
		_doors(1.0 - i / float(n - 1))
		await _out(false, "")
	for i in int(1.0 * FPS):
		await _out(i == 15, "platform_inside")
	# 3. A partida: o vagão sai para a direita, primeiro na plataforma, depois no túnel com as rodas à vista.
	n = int(1.6 * FPS)
	for i in n:
		var t := i / float(n - 1)
		_move(9.0 * t * t)
		_place_team("inside")
		await _out(false, "")
	_shot_camera(true)
	n = int(2.6 * FPS)
	for i in n:
		var t := i / float(n - 1)
		_move(-14.0 + 34.0 * pow(t, 1.6))
		_place_team("inside")
		await _out(i == int(n * 0.4), "tunnel_departure")


func _out(take: bool, name: String) -> void:
	await RenderingServer.frame_post_draw
	if stills:
		if take:
			root.get_texture().get_image().save_png(out.path_join(name + ".png"))
			print("foto: ", name)
	else:
		root.get_texture().get_image().save_png(out.path_join("frame_%04d.png" % _frame))
	_frame += 1


# -------------------------------------------------------------------------------------------------------- a passagem 2D

func _passage() -> void:
	var p: Dictionary = c.passage
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var stage := Node2D.new()
	layer.add_child(stage)
	var back := ColorRect.new()
	back.color = Color(0.02, 0.02, 0.025)
	back.size = Vector2(1920, 1080)
	stage.add_child(back)
	# O túnel: a faixa repetida em X, atrás dos vãos das janelas, correndo para trás.
	var tunnel := Sprite2D.new()
	tunnel.texture = load(p.tunnel.file)
	tunnel.centered = false
	tunnel.region_enabled = true
	tunnel.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	tunnel.region_rect = Rect2(0, 0, 1920.0 / p.tunnel.scale, tunnel.texture.get_height())
	tunnel.scale = Vector2(p.tunnel.scale, p.tunnel.scale)
	tunnel.position = Vector2(p.tunnel.position[0], p.tunnel.position[1])
	tunnel.modulate = Color(p.tunnel.modulate[0], p.tunnel.modulate[1], p.tunnel.modulate[2])
	stage.add_child(tunnel)
	var background := Sprite2D.new()
	background.texture = load(p.background.file)
	background.centered = false
	stage.add_child(background)
	var soft := GradientTexture2D.new()
	soft.fill = GradientTexture2D.FILL_RADIAL
	soft.fill_from = Vector2(0.5, 0.5)
	soft.fill_to = Vector2(1.0, 0.5)
	soft.gradient = Gradient.new()
	soft.gradient.set_color(0, Color(0, 0, 0, 0.55))
	soft.gradient.set_color(1, Color(0, 0, 0, 0))
	for seat in p.seats:
		# A sombra de contato: no assento, sob o quadril, e no chão, sob o pé (quando o pé alcança o chão).
		var width: float = p.shadow_width_px * seat.preview_scale
		for spot in [[seat.seat_support[0], seat.seat_support[1] + 8, 1.0], [seat.projected_foot_anchor[0], seat.projected_foot_anchor[1], 0.8]]:
			if spot == null or (spot[1] < p.floor_y - 30 and spot[2] < 1.0):
				continue
			var shadow := Sprite2D.new()
			shadow.texture = soft
			shadow.position = Vector2(spot[0], spot[1])
			shadow.scale = Vector2(width / 64.0, width * 0.16 / 64.0) * spot[2]
			stage.add_child(shadow)
	for seat in p.seats:
		var hero := Sprite2D.new()
		hero.texture = load(seat.file)
		hero.centered = false
		hero.scale = Vector2(seat.preview_scale, seat.preview_scale)
		hero.position = Vector2(seat.sprite_top_left[0], seat.sprite_top_left[1])
		hero.modulate = Color(p.hero_modulate[0], p.hero_modulate[1], p.hero_modulate[2])
		stage.add_child(hero)
	var poles := Sprite2D.new()
	poles.texture = load(p.poles.file)
	poles.centered = false
	stage.add_child(poles)
	var n := int((1.0 if stills else 4.0) * FPS)
	for i in n:
		tunnel.region_rect.position.x = i / FPS * p.tunnel.scroll_px_per_second / p.tunnel.scale
		await _out(i == n - 1, "passage")
