## Altura visível de cada personagem, da cabeça aos pés, em metros (port do FAHCharacterHeights da Unreal, #79). A
## mesma na exploração e no combate. Heróis pela classe; inimigos pelo id da tabela. Mudar um tamanho é mudar só aqui.
class_name AHCharacterHeights

## Altura de origem do Bento (CHARACTER_SCALE da web): os fatores dos inimigos medem contra ela.
const REFERENCE := 1.64
const HEIGHTS := {
	# Heróis, pela classe. Mais contraste (decisão do Lucas, 18/10/2026).
	"cao": 1.72, "gato": 1.50, "sapo": 1.38, "coruja": 1.66,
	# O Guaxinim e o Tatu (#187), sem altura na Unreal: o guaxinim um pouco menor que a Íris, o tatu baixo e largo. A
	# arte deles é mais encorpada que a dos fundadores (cabeça grande, cauda e escudo), então a altura fica abaixo.
	"rato": 1.30, "tatu": 1.35,
	# Civis.
	"civil_dora": 1.56, "civil_otto": 1.62, "civil_cora": 1.70,
	# O Mercador (#182, a arte da #218): a altura do Bento, com o fedora.
	"merchant": 1.72,
	# Inimigos com arte aprovada.
	"cao_eco": REFERENCE * 0.62, "condutor_raiz": REFERENCE * 0.65, "sussurrador": REFERENCE * 0.82,
	"rastejante_raiz": REFERENCE * 0.48, "ninho_errante": REFERENCE * 0.60, "vigia_enferrujado": REFERENCE * 1.08,
	"carcaca_colonizada": REFERENCE * 0.90, "porteiro": 2.35, "robot": REFERENCE * 1.04, "robot_fungo": REFERENCE * 1.04,
	# Vilões do John (22/10/2026): o Carrasco pesado, o Recreador alto e magro; os ajudantes (Faísca, Pipoco, Broto) na
	# altura do joelho dos robôs principais, como pede o registro dele.
	"carrasco_industrial": REFERENCE * 1.10, "recreador": REFERENCE * 1.08, "enraizado": REFERENCE * 1.00,
	"faisca": REFERENCE * 0.34, "pipoco": REFERENCE * 0.32, "broto": REFERENCE * 0.30,
}


## Altura de um herói (hero_cao_bento: pela classe cao), inimigo ou civil; fallback se não estiver na tabela.
static func find(id: String, fallback: float = REFERENCE) -> float:
	if HEIGHTS.has(id):
		return HEIGHTS[id]
	var parts := id.split("_")
	if id.begins_with("hero_") and parts.size() > 1 and HEIGHTS.has(parts[1]):
		return HEIGHTS[parts[1]]
	return fallback
