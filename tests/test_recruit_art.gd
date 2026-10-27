## A arte própria dos recrutas (#32, as entregas #14 e #26): o recruta ganha uma variação da classe, guardada no save
## (art_variant), e aparece diferente do fundador na luta, na Estação e no retrato; com mais de uma variação, dois
## recrutas da mesma classe ficam diferentes entre si; save e load mantêm; saves antigos ganham a variação na migração.
extends RefCounted

const S := preload("res://scripts/flow/station_rules.gd")


func run(t) -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(AHCombatArena.ART_MANIFEST))
	for class_id in ["cao", "gato", "sapo", "coruja"]:
		var variants := S.art_variants(class_id)
		t.check(not variants.is_empty(), "a classe %s tem recruta desenhado" % class_id)
		for variant in variants:
			var idle: Dictionary = manifest.recruits[variant].idle
			t.check(ResourceLoader.exists(idle.file) and ResourceLoader.exists(idle.portrait), "%s: o parado e o retrato existem" % variant)
			t.check(float(idle.body_reference_pixels) > 0 and idle.anchor.size() == 2, "%s: âncora e altura medidas" % variant)

	# O Guaxinim e o Tatu (#187): sem fundador, a arte é a do recruta, com um golpe por habilidade, as reações e os
	# ícones; e o trem passa a trazê-los quando a classe está liberada.
	for class_id in ["rato", "tatu"]:
		var variants := S.art_variants(class_id)
		if not t.check(variants.size() == 1, "%s: um recruta desenhado" % class_id):
			continue
		var entry := AHCombatArena.art_entry(manifest.heroes, "hero_%s_5" % class_id, variants[0])
		t.equal(entry.get("variant", ""), variants[0], "%s: a arte do recruta, sem fundador" % class_id)
		t.equal(AHCombatArena.art_entry(manifest.heroes, "hero_%s_0" % class_id, "").get("variant", ""), variants[0],
			"%s: sem variação guardada, a da classe" % class_id)
		var abilities: Array = GameData.row("classes", class_id).AbilityIds
		var poses_ok := ResourceLoader.exists(entry.idle.file) and float(entry.idle.body_reference_pixels) > 0
		for ability_id in abilities:
			var execute: Dictionary = entry.actions.get(ability_id, {}).get("execucao", {})
			poses_ok = poses_ok and ResourceLoader.exists(execute.get("file", "")) and execute.anchor == entry.idle.anchor
			t.check(ResourceLoader.exists(manifest.icons.get(ability_id, "")), "%s: o ícone de %s" % [class_id, ability_id])
		for pose in ["hurt", "death", "dodge", "defense"]:
			var reaction: Dictionary = entry.reactions.get(pose, {})
			poses_ok = poses_ok and ResourceLoader.exists(reaction.get("file", "")) and reaction.body_reference_pixels == entry.idle.body_reference_pixels
		t.check(poses_ok, "%s: o golpe de cada habilidade e as reações, com o pé e a altura do parado" % class_id)
		t.check(AHCharacterHeights.HEIGHTS.has(class_id), "%s: altura própria" % class_id)
		# A escala (o Lucas, no #196): o Guaxinim e o Tatu menores que a Íris e o Nick, e a largura medida para a fila.
		t.check(AHCharacterHeights.HEIGHTS[class_id] < AHCharacterHeights.HEIGHTS.sapo, "%s: menor que a Íris" % class_id)
		t.check(float(entry.idle.get("body_width_pixels", 0)) > 0, "%s: largura do corpo medida" % class_id)
		t.check(S.train_classes({"unlocked_classes": ["cao", class_id]}).has(class_id), "%s: o trem pode trazê-lo" % class_id)

	var real_dir: String = Campaign.save_dir
	var real_state: Dictionary = Campaign.state
	Campaign.save_dir = "user://test-recruit-art-%d" % Time.get_ticks_usec()
	Campaign.state = Campaign.create_initial(21)
	# O Alojamento ampliado (#119): cabem os recrutas.
	Campaign.state.station.rooms[S.CHARACTERS] = 4
	var c: Dictionary = Campaign.state
	c.inventory.seeds = 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var first: Dictionary = S.recruit(c, "cao", rng)
	var second: Dictionary = S.recruit(c, "cao", rng)
	t.equal([first.error, second.error], ["", ""], "dois recrutas cão")
	var a = S.hero(c, first.hero_id)
	var b = S.hero(c, second.hero_id)
	t.equal(a.art_variant, "dog_recruit_01", "o recruta ganha a variação da classe")
	t.equal(S.hero(c, "hero_cao_bento").art_variant, "", "o fundador continua com a arte dele")

	# Na arte do jogo: o recruta não é cópia do fundador.
	var heroes: Dictionary = manifest.heroes
	var bento := AHCombatArena.art_entry(heroes, "hero_cao_bento")
	var recruit := AHCombatArena.art_entry(heroes, a.id)
	t.check(recruit.idle.file != bento.idle.file, "o recruta não usa o parado do Bento")
	t.check(recruit.get("reactions", {}).is_empty(), "nem as reações do Bento")
	var leaked := false
	for ability_id in recruit.actions:
		leaked = leaked or recruit.actions[ability_id].keys() != ["vfx"]
	t.check(not recruit.actions.is_empty() and not leaked, "das ações do fundador fica só o efeito visual (as poses são do Bento)")
	var face := AHUiStyle.face_texture(recruit.idle)
	t.check(face != null and face.get_width() == 256 and face.resource_path == recruit.idle.portrait, "o retrato do HUD é o recortado da entrega #26")
	t.check(AHUiStyle.face_texture(bento.idle).resource_path.ends_with("bento.png"), "e o do Bento também")

	# Com duas variações da classe, dois recrutas ficam diferentes entre si (a menos usada vai para o novo).
	var saved_art: Dictionary = S._recruit_art.duplicate(true)
	S._recruit_art["dog_recruit_02"] = {"class_id": "cao", "idle": saved_art.dog_recruit_01.idle}
	var third: Dictionary = S.recruit(c, "cao", rng)
	t.equal(S.hero(c, third.hero_id).art_variant, "dog_recruit_02", "com duas variações, o terceiro cão ganha a outra")
	t.equal(S.pick_art_variant(c, "cao"), "dog_recruit_02", "e a escolha segue a menos usada")
	S._recruit_art = saved_art
	t.equal(b.art_variant, "dog_recruit_01", "hoje há uma variação por classe: os dois primeiros cães dividem a arte")

	# Save e load mantêm a variação.
	t.check(Campaign.save(), "grava")
	Campaign.load_or_new()
	t.equal(Campaign.hero(first.hero_id).art_variant, "dog_recruit_01", "o load mantém a variação")

	# Save antigo (sem o campo): o fundador fica sem variação e o recruta ganha a da classe.
	var old: Dictionary = Campaign.state.duplicate(true)
	for entry in old.roster:
		entry.erase("art_variant")
	S.migrate(old)
	t.equal(S.hero(old, "hero_gato_nick").art_variant, "", "migração: o fundador continua com a arte dele")
	t.equal(S.hero(old, first.hero_id).art_variant, "dog_recruit_01", "migração: o recruta ganha a variação")
	t.check(S.is_recruit(first.hero_id) and not S.is_recruit("hero_cao_bento"), "recruta pelo número no fim do id")

	for file in DirAccess.get_files_at(Campaign.save_dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Campaign.save_dir))
	Campaign.save_dir = real_dir
	Campaign.state = real_state
