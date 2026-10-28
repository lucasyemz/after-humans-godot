"""A Enfermaria nova (os ajustes do Lucas de 26/10, PR #139) como protótipo para a captura: lê os scripts da Estação
que estão no repositório, aplica as mudanças que a integração vai fazer (é do Claude) e grava um pacote (zip) com as
cópias mudadas, que capture_infirmary.gd carrega por cima do projeto. Nada em scripts/ muda.

As mudanças (cada uma confere o trecho de hoje e falha se ele mudou):
- **o lugar:** a Enfermaria vai de x −1840 a −640 no subsolo 2 (12 m, a largura do Dormitório). Ela começa onde já
  está no jogo, embaixo do Dormitório, e avança 6 m na rocha da esquerda; a rocha das pontas passa a ir até −2400, e o
  fundo de rocha, as lajes entre os níveis e a rocha sob o subsolo 2 passam a começar em −1840 (hoje, em −1800);
- **a porta do fundo** em x −1400 (entre o primeiro e o segundo leito) e o caixote tombado do nível 0 em −1780;
- **os móveis em profundidade, nos planos do Dormitório:** os leitos da frente a y −665 (a linha dos beliches), os do
  fundo e o armário a y −780, com 120 cm até a parede do fundo (ROOM_BACK −900);
- **nível 1:** 2 leitos em uso, o soro entre eles, o armário, e 2 leitos que esperam a melhoria (o quebrado e o
  coberto com a lona); **nível 2:** os 4 em uso, com o biombo, o lavatório e o carrinho. A marca "infirmary@=1" é a
  peça que só aparece no nível 1 (a regra nova da visibilidade, em station.gd);
- **quem está deitado:** os lugares dos leitos (infirmary_slots), na altura do colchão do Infirmary_Bed (68 cm);
- **a faixa de passeio** do cômodo, de −17,2 a −7,6 m, e a ponta esquerda da Estação (LEFT_END) em −18,4 m: a Visão
  geral passa a enquadrar o subsolo 2 inteiro.

Uso (da raiz do repositório): python3 -B docs/design/hud-casa/infirmary_proto.py <pacote.zip>
"""
import sys
import zipfile
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
BUILD = "scripts/station/station_build.gd"
STATION = "scripts/station/station.gd"

# O x de cada peça (cm), a profundidade (y, cm), a largura (cm) e a marca de nível; a altura sai da proporção do card.
# Os leitos: os dois em uso à esquerda, os dois que esperam à direita (no nível 2, em uso também).
BED_W = 172.0
LAYOUT = [
    # card, x, y, largura, proporção (altura / largura), marca
    ("Infirmary_Cabinet", -1740.0, -780.0, 124.0, 398.0 / 328.0, "infirmary"),
    ("Infirmary_Bed", -1500.0, -665.0, BED_W, 220.0 / 477.0, "infirmary"),
    ("Infirmary_Drip", -1355.0, -720.0, 55.0, 402.0 / 129.0, "infirmary"),
    ("Infirmary_Bed", -1210.0, -665.0, BED_W, 220.0 / 477.0, "infirmary"),
    ("Infirmary_Bed_Broken", -960.0, -780.0, BED_W * 502.0 / 477.0, 242.0 / 502.0, "infirmary@=1"),
    ("Infirmary_Bed_Covered", -770.0, -665.0, BED_W * 505.0 / 477.0, 261.0 / 505.0, "infirmary@=1"),
    ("Infirmary_Bed", -960.0, -780.0, BED_W, 220.0 / 477.0, "infirmary@2"),
    ("Infirmary_Bed", -770.0, -665.0, BED_W, 220.0 / 477.0, "infirmary@2"),
    ("Infirmary_Drip", -865.0, -820.0, 55.0, 402.0 / 129.0, "infirmary@2"),
    ("Infirmary_Screen", -1085.0, -840.0, 150.0, 377.0 / 422.0, "infirmary@2"),
    ("Infirmary_Washstand", -1610.0, -820.0, 70.0, 339.0 / 265.0, "infirmary@2"),
    ("Infirmary_Trolley", -1085.0, -640.0, 80.0, 378.0 / 327.0, "infirmary@2"),
]
# Os leitos na ordem em que enchem: os dois em uso no nível 1, depois os do nível 2 (o x do leito e a profundidade).
BEDS = [(-1500.0, -665.0), (-1210.0, -665.0), (-770.0, -665.0), (-960.0, -780.0)]
MATTRESS = 68.0


def patch(text: str, old: str, new: str, path: str) -> str:
    if old not in text:
        raise SystemExit(f"{path}: o trecho mudou, confira o protótipo:\n{old[:200]}")
    return text.replace(old, new, 1)


def build_script() -> str:
    path = ROOT / BUILD
    s = path.read_text()
    s = patch(s, '{"id": "infirmary", "x0": -1240.0, "x1": -640.0, "floor": B2_FLOOR, "ceiling": B2_CEILING, "floor_art": "worn_tile_floor", "wall": "painted_plaster_wall", "wainscot": "long_white_tiles", "light": COOL, "door": -1150.0',
              '{"id": "infirmary", "x0": -1840.0, "x1": -640.0, "floor": B2_FLOOR, "ceiling": B2_CEILING, "floor_art": "worn_tile_floor", "wall": "painted_plaster_wall", "wainscot": "long_white_tiles", "light": COOL, "door": -1400.0', BUILD)
    s = patch(s, "box(Vector3(-4000, -1360, -1500), Vector3(-1800, 0, 1100), rock)",
              "box(Vector3(-4000, -1360, -1500), Vector3(-1840, 0, 1100), rock)", BUILD)
    s = patch(s, """	box(Vector3(-1800, CORRIDOR_BACK - 40, B2_CEILING), Vector3(3900, 0, B1_FLOOR - FINISH), slab)
	box(Vector3(-1800, CORRIDOR_BACK - 40, B1_CEILING), Vector3(STATION_END, 0, -140), slab)
	box(Vector3(-1800, CORRIDOR_BACK - 40, -1500), Vector3(3900, 0, FORGE_FLOOR - 30), rock)""",
              """	box(Vector3(-1840, CORRIDOR_BACK - 40, B2_CEILING), Vector3(3900, 0, B1_FLOOR - FINISH), slab)
	box(Vector3(-1840, CORRIDOR_BACK - 40, B1_CEILING), Vector3(STATION_END, 0, -140), slab)
	box(Vector3(-1840, CORRIDOR_BACK - 40, -1500), Vector3(3900, 0, FORGE_FLOOR - 30), rock)""", BUILD)
    s = patch(s, "box(Vector3(-1800, CORRIDOR_BACK - 40, FORGE_FLOOR - 30), Vector3(1160, 0, B2_FLOOR - FINISH), rock)",
              "box(Vector3(-2400, CORRIDOR_BACK - 40, FORGE_FLOOR - 30), Vector3(1160, 0, B2_FLOOR - FINISH), rock)", BUILD)
    s = patch(s, "box(Vector3(-1800, CORRIDOR_BACK - 40, B1_FLOOR), Vector3(-1240, 0, B1_CEILING), rock)\n\tbox(Vector3(-1800, CORRIDOR_BACK - 40, B2_FLOOR), Vector3(-1240, 0, B2_CEILING), rock)\n\tbox(Vector3(-1800, -1360, -140), Vector3(-40, 0, 1100), rock)",
              "box(Vector3(-2400, CORRIDOR_BACK - 40, B1_FLOOR), Vector3(-1240, 0, B1_CEILING), rock)\n\tbox(Vector3(-2400, CORRIDOR_BACK - 40, B2_FLOOR), Vector3(-1840, 0, B2_CEILING), rock)\n\tbox(Vector3(-2400, -1360, -140), Vector3(-40, 0, 1100), rock)", BUILD)
    start = s.index("## A Enfermaria provisória (#121)")
    end = s.index("func _preparation() -> void:")
    pieces = "\n".join(f'\t["{c}", {x}, {y}, {w}, {r:.6f}, "{tag}"],' for c, x, y, w, r, tag in LAYOUT)
    beds = ", ".join(f"Vector2({x}, {y})" for x, y in BEDS)
    body = f'''## A Enfermaria (os ajustes do Lucas de 26/10, PR #139): 12 m, de x −1840 a −640 no subsolo 2, os móveis nos planos do
## Dormitório. Nível 1: 2 leitos em uso, o soro e o armário, e 2 leitos esperando a melhoria (o quebrado e o coberto);
## nível 2: os 4 em uso, com o biombo, o lavatório e o carrinho. Cada peça: card, x, y (a profundidade), largura,
## altura / largura e a marca ("infirmary@=1": só no nível 1).
const INFIRMARY_FLOOR := -940.0
const INFIRMARY_PIECES := [
{pieces}
]
## Os leitos, na ordem em que enchem (x e profundidade), e a altura do colchão do Infirmary_Bed acima do piso.
const INFIRMARY_BEDS := [{beds}]
const INFIRMARY_MATTRESS := {MATTRESS}


func _infirmary() -> void:
	var f := INFIRMARY_FLOOR
	for piece in INFIRMARY_PIECES:
		var mark := b.mark()
		var width: float = piece[3]
		b.card(piece[0], Vector3(piece[1], piece[2], f), width, width * float(piece[4]))
		_tag_dressing(piece[5], mark)
	var mark := b.mark()
	# O cômodo tem a luz do meio (_room); o pendente da esquerda acende o armário e os dois leitos em uso.
	b.hang("caged_hanging_light", Vector3(-1550, -560, B2_CEILING))
	room_lights["infirmary"] = b.light(Vector3(-1550, -560, B2_CEILING - 90), 1100, 900, COOL, true)
	_tag_dressing("infirmary", mark)
	mark = b.mark()
	b.hang("caged_hanging_light", Vector3(-870, -560, B2_CEILING))
	b.light(Vector3(-870, -560, B2_CEILING - 90), 700, 700, COOL, false)
	_tag_dressing("infirmary@2", mark)
	b.card("Depot_Container", Vector3(-1780, -520, f), 60, 60.0 / 1.1509804)


'''
    return s[:start] + body + s[end:]


def station_script() -> str:
    path = ROOT / STATION
    s = path.read_text()
    s = patch(s, "const LEFT_END := -12.4", "const LEFT_END := -18.4", STATION)
    s = patch(s, '{"id": "infirmary", "x0": -12.4, "x1": -6.4, "floor": -9.4, "ceiling": -6.2, "lane": [-11.2, -7.6]}',
              '{"id": "infirmary", "x0": -18.4, "x1": -6.4, "floor": -9.4, "ceiling": -6.2, "lane": [-17.2, -7.6]}', STATION)
    s = patch(s, '''	for x in AHStationBuild.INFIRMARY_BUNK_X:
		for tier in 2:
			out.append(AHStationBuilder.vu(Vector3(x - 12.0, AHStationBuild.BUNK_Y + 30.0,
				AHStationBuild.INFIRMARY_FLOOR + tier * AHStationBuild.BUNK_UPPER + AHStationBuild.MATTRESS_TOP - SLEEP_DROP)))''',
              '''	for bed in AHStationBuild.INFIRMARY_BEDS:
		# Um pouco para a cabeceira (o travesseiro fica à esquerda) e à frente do leito pintado.
		out.append(AHStationBuilder.vu(Vector3(bed.x - 12.0, bed.y + 30.0,
			AHStationBuild.INFIRMARY_FLOOR + AHStationBuild.INFIRMARY_MATTRESS - SLEEP_DROP)))''', STATION)
    s = patch(s, '''		var parts: PackedStringArray = String(room_id).split("@")
		var furnished := S.room_level(campaign, parts[0]) >= (int(parts[1]) if parts.size() > 1 else 1)''',
              '''		# "infirmary@=1": a peça que só aparece no nível 1 (os leitos que esperam a melhoria).
		var parts: PackedStringArray = String(room_id).split("@")
		var level := S.room_level(campaign, parts[0])
		var furnished := level >= 1
		if parts.size() > 1:
			furnished = level == int(parts[1].trim_prefix("=")) if parts[1].begins_with("=") else level >= int(parts[1])''', STATION)
    return s


def main(out: str) -> None:
    with zipfile.ZipFile(out, "w") as z:
        z.writestr(BUILD, build_script())
        z.writestr(STATION, station_script())
    print("ok", out)


if __name__ == "__main__":
    main(sys.argv[1])
