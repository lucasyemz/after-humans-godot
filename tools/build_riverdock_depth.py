"""O Armazém e o Navio do Cais do Rio em camadas (#141), da mesma arte de hoje (T_CD15 e T_CD14).

Cada card chapado vira pedaços da pintura ([u0, v0, u1, v1] e o z de cada um) numa malha só (layered_cards), como as
fachadas da Rua das Vitrines: no Armazém, os pilares na frente, a viga e a soleira um pouco atrás e o vão recuado, com
os batentes, o teto e o piso do recuo em volumes escuros; no Navio, a pintura inteira e a silhueta escura atrás (a
espessura). Os pedaços
não se sobrepõem na pintura (sem nada dobrado na emenda).
Também grava as portas de dentro dos dois interiores (doorways). A espuma em volta do casco já vem da água pintada (#140).

Rodar de novo refaz tudo: as partes geradas levam "layer": "141" e saem antes.
    python tools/build_riverdock_depth.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAP = ROOT / "data/scenarios/RiverDock.json"
LAYER = "141"
# Os cards de hoje: o Armazém (a porta do Galpão, x 14) e o Navio (a porta do Navio, x 43).
WAREHOUSE_PART = 1
SHIP_PART = 2
# Os volumes do recuo: o metal enferrujado do mapa.
RUST_MATERIAL = 5
PLATE_MATERIAL = 8
SKY = "res://art/scenarios/T_OceanSky.webp"
WATER = {"surface_color": [0.22, 0.38, 0.40], "mid_color": [0.10, 0.22, 0.25], "deep_color": [0.035, 0.10, 0.12],
         "ripple_color": [0.46, 0.60, 0.60], "foam_color": [0.76, 0.82, 0.79]}

# O Armazém: o vão (o interior pintado) e a moldura em volta.
WAREHOUSE = [
    # rect, z (a profundidade da peça)
    ([0.0, 0.0, 0.283, 1.0], -2.45),     # o pilar da esquerda
    ([0.733, 0.0, 1.0, 1.0], -2.45),     # o pilar da direita
    ([0.283, 0.0, 0.733, 0.41], -2.62),  # a viga e o telhado
    ([0.283, 0.925, 0.733, 1.0], -2.62), # a soleira
    ([0.283, 0.41, 0.733, 0.925], -4.2), # o vão, recuado
]
OPENING = [0.283, 0.41, 0.733, 0.925]
# O Navio: o casco em três (a proa e a popa recuadas: a curva), o convés com o guindaste e a cabine com o mastro.
# O Navio fica inteiro (cortar a pintura em linha reta abre emendas: o deslocamento e o desfoque de profundidade mudam de
# um lado para o outro). O volume vem de uma cópia escura da silhueta atrás dele (shade), que aparece como a borda do
# casco e da cabine quando a câmera passa ao lado; as camadas de verdade esperam a arte com máscaras (o pedido ao
# design está na página da QA).
SHIP = [
    ([0.0, 0.0, 1.0, 1.0], -2.45, 1.0),   # a pintura inteira
    ([0.0, 0.0, 1.0, 1.0], -2.95, 0.22),  # a silhueta escura atrás: a espessura
]
# A distância da câmera da exploração até o plano do card (m, EXPLORE_CAMERA.scenario mais a faixa): cada pedaço mais
# para o fundo cresce na mesma razão, e as emendas batem vistas de frente.
VIEW_DISTANCE = 18.3
DOORWAYS = [{"x": 70.9, "y": 0.0, "z": -2.27, "w": 1.5, "h": 2.4, "zone": 1},
            {"x": 95.9, "y": 0.0, "z": -2.27, "w": 1.5, "h": 2.4, "zone": 2}]


def card_size(part):
    b = part["basis"]
    return abs(b[0]), abs(b[7])


def piece(part, rect, z, shade=1.0):
    width, height = card_size(part)
    cx, cy, cz = part["origin"]
    u0, v0, u1, v1 = rect
    # A correção da perspectiva: mais fundo, um pouco maior e mais afastado do centro do card.
    k = (VIEW_DISTANCE + (cz - z)) / VIEW_DISTANCE
    w = (u1 - u0) * width * k
    h = (v1 - v0) * height * k
    x = cx + ((u0 + u1) * 0.5 - 0.5) * width * k
    y = cy - ((v0 + v1) * 0.5 - 0.5) * height * k
    out = {"rect": rect, "x": round(x, 4), "y": round(y, 4), "z": z, "w": round(w, 4), "h": round(h, 4)}
    if shade != 1.0:
        out["shade"] = shade
    return out


def box(center, size, material):
    return {"mesh": 0, "materials": [material], "origin": [round(v, 4) for v in center],
            "basis": [size[0], 0.0, 0.0, 0.0, size[1], 0.0, 0.0, 0.0, size[2]], "solid": True, "no_shadow": True,
            "layer": LAYER}


def main():
    data = json.loads(MAP.read_text(encoding="utf-8"))
    # Tira o que uma rodada anterior gerou (os materiais gerados ficam no fim da lista).
    data["parts"] = [p for p in data["parts"] if p.get("layer") != LAYER]
    first_generated = next((i for i, m in enumerate(data["materials"]) if m.get("layer") == LAYER), len(data["materials"]))
    data["materials"] = data["materials"][:first_generated]
    for part_index in (WAREHOUSE_PART, SHIP_PART):
        data["parts"][part_index]["hidden"] = True

    # Cada fachada numa malha só (scenario_world._layered_card): as mesmas luzes na fachada inteira.
    data["layered_cards"] = []
    for name, base_part, layers in (("warehouse", WAREHOUSE_PART, WAREHOUSE), ("ship", SHIP_PART, SHIP)):
        part = data["parts"][base_part]
        albedo = data["materials"][part["materials"][0]]["albedo"]
        data["layered_cards"].append({"name": name, "albedo": albedo, "pieces": [piece(part, *layer) for layer in layers]})

    # O recuo do vão do Armazém: os dois batentes, o teto e o piso, do plano da viga até o vão.
    part = data["parts"][WAREHOUSE_PART]
    width, height = card_size(part)
    cx, cy, _ = part["origin"]
    u0, v0, u1, v1 = OPENING
    left = cx + (u0 - 0.5) * width
    right = cx + (u1 - 0.5) * width
    top = cy - (v0 - 0.5) * height
    bottom = cy - (v1 - 0.5) * height
    front, back = -2.62, -4.2
    depth = front - back
    mid_z = (front + back) * 0.5
    mid_y = (top + bottom) * 0.5
    data["parts"].append(box([left - 0.06, mid_y, mid_z], [0.12, top - bottom, depth], RUST_MATERIAL))
    data["parts"].append(box([right + 0.06, mid_y, mid_z], [0.12, top - bottom, depth], RUST_MATERIAL))
    data["parts"].append(box([(left + right) * 0.5, top + 0.06, mid_z], [right - left + 0.24, 0.12, depth], RUST_MATERIAL))
    data["parts"].append(box([(left + right) * 0.5, max(bottom, 0.0) - 0.06, mid_z], [right - left, 0.12, depth], PLATE_MATERIAL))

    # As portas de dentro dos interiores, com o Cais lá fora.
    data["doorways"] = [dict(d, sky=SKY, **WATER) for d in DOORWAYS]

    MAP.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print("RiverDock: %d partes, %d materiais" % (len(data["parts"]), len(data["materials"])))


if __name__ == "__main__":
    main()
