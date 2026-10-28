## O herói ferido (#194): com a vida baixa ou Caído em recuperação, ele anda mais devagar, manca e mostra a pose de
## ferido (art/combat/heroes/<nome>/wounded.webp, a do Codex, no canvas e na âncora do idle), e a HUD avisa que ele
## precisa se recuperar. A regra é esta, para a exploração, a Estação e a HUD; os números ficam em data/wounded.json.
class_name AHWounded
extends RefCounted

const POSE_FILE := "wounded.webp"

## O arquivo da pose que a rua procura (os testes trocam por um que já existe, enquanto a arte do #209 não entra).
static var pose_file := POSE_FILE


## Os números da regra (data/wounded.json).
static func rules() -> Dictionary:
	var row = GameData.row("wounded", "wounded")
	return row if row != null else {"Threshold": 0.5, "SpeedFactor": 0.7, "LimpTilt": 3.5, "LimpDip": 0.55, "BreathDepth": 2.0}


## Se o herói está ferido: vivo, com a vida abaixo do limite, ou Caído em recuperação (#118/#121).
static func is_wounded(hero) -> bool:
	if hero == null or not hero.get("alive", true):
		return false
	if int(hero.get("recovery_days", 0)) > 0:
		return true
	# O mesmo limite do "Ferimento grave" do kit (o coração rachado da Sala dos Personagens): AHKit.heavy_below.
	return AHKit.health_state(int(hero.get("hp", 1)), int(hero.get("max_hp", 1))).id == "heavy"


## Quanto da velocidade sobra para quem está ferido (1 para quem não está).
static func speed_factor(hero) -> float:
	return float(rules().SpeedFactor) if is_wounded(hero) else 1.0


## A pose de ferido a partir do idle: o mesmo canvas e a mesma âncora, com o arquivo wounded.webp da mesma pasta (sem as
## folhas da respiração do idle). Sem o arquivo (a arte ainda não chegou), o próprio idle.
static func pose(idle: Dictionary, file_name: String = "") -> Dictionary:
	var file := String(idle.get("file", ""))
	if file == "":
		return idle
	var wounded := file.get_base_dir().path_join(file_name if file_name != "" else pose_file)
	if not ResourceLoader.exists(wounded):
		return idle
	var art := idle.duplicate()
	art.file = wounded
	art.erase("frames")
	art.erase("fps")
	return art
