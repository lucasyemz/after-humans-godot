"""Monta o mapa do tutorial (#147) no contrato de tools/sync_scenarios.py: o mesmo data/scenarios/<Mapa>.json que o
AHScenarioWorld lê (as malhas básicas de meshes.json, os materiais, as peças, as luzes, as zonas e os props), para a
captura na Godot (capture_map.gd) e para o Claude partir dele na integração. Fica em docs/design/tutorial/map/, fora de
data/: a integração copia para data/scenarios/ (ou leva para a Unreal e exporta), com a entrada em MAPS e DISPLAY.

Medidas em metros, nos eixos da Godot (X para a direita, Y para cima, Z para a câmera). A câmera da exploração é a dos
outros cenários (19 m, 1,7 m acima do piso, 0,5°): as zonas têm 10 m de largura e 4,8 de fundo, como as do Abrigo
Lacrado; a parede do fundo fica 2,6 m atrás do meio da faixa e o piso vai até a frente da câmera (8 m à frente), em
perspectiva, numa peça só. O mapa inteiro está 8 m para o fundo (DZ): o piso usa a superfície projetada pelo mundo
(station_surface, a umidade que brilha com as lâmpadas), e assim cada zona cai numa amostra só da pintura, com a
sujeira do pé da parede em cima, encostada na parede (por isso também as zonas a cada 21,2 m, duas amostras).

Uso: python3 -B docs/design/tutorial/build_map.py
"""
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "docs/design/tutorial/map/ContainmentCorridor.json"
CUBE, PLANE, CYLINDER, WATER = 0, 1, 2, 3
ART = "res://art/scenarios/"

materials: list = []
parts: list = []
lights: list = []
props: list = []


def mat(spec: dict) -> int:
    if spec not in materials:
        materials.append(spec)
    return materials.index(spec)


def art(code: str, masked=True, two_sided=True) -> int:
    return mat({"kind": "art", "two_sided": two_sided, "masked": masked, "albedo": ART + code + ".webp"})


def card(code: str, emissive=0.6) -> int:
    return mat({"kind": "card", "two_sided": True, "masked": True, "albedo": ART + code + ".webp", "emissive": emissive,
                "haze": 0.0, "haze_color": [0.55, 0.52, 0.48, 1.0], "rect": [0.0, 0.0, 1.0, 1.0]})


# A zona de cada material de superfície: o mundo junta as peças fixas de mesmo material numa malha só, e uma malha que
# atravessa zonas soma as luzes de todas (o Compatibility usa até 8 por objeto e corta o resto: some a poça de luz).
ZONE = [0]


def concrete(tint: float, damp=0.6) -> int:
    """O concreto molhado do lugar (T_TU27, sem emenda, projetado pelo mundo em placas de 2,4 m): os recuos, os lados dos
    pilares, os blocos das pontas e o fosso. Era o concreto do Abrigo Lacrado (o acabamento de 28/10)."""
    return mat({"zone": ZONE[0], "kind": "surface", "two_sided": False, "masked": False, "albedo": ART + "T_TU27.webp",
                "normal": "", "tint": [tint, tint * 0.97, tint * 0.95, 1.0], "tile": 240.0,
                "desaturation": 0.0, "damp": damp, "roughness": 1.0})


def metal(tint: float) -> int:
    return mat({"kind": "surface", "two_sided": False, "masked": False, "albedo": ART + "T_SH_green_metal_rust_base_color.webp",
                "normal": ART + "T_SH_green_metal_rust_normal.webp", "tint": [tint, tint, tint * 0.95, 1.0], "tile": 150.0,
                "desaturation": 0.2, "damp": 0.3, "roughness": 1.0})


VOID = None
WATER_MAT = None
DZ = -8.0  # o mapa todo para o fundo (ver acima): as medidas abaixo são relativas ao meio da faixa
TILE = 10.6  # a amostra do piso (m): da parede (Z = -2,6) até a frente (Z = 8)
PITCH = 2 * TILE  # de uma zona para a outra


def floor_surface(code: str, damp=0.55) -> int:
    """O piso molhado: a pintura vista de cima, projetada pelo mundo (uma amostra por zona) e lisa onde é úmida, para as
    lâmpadas fazerem a poça de luz e o brilho na água."""
    return mat({"zone": ZONE[0], "kind": "surface", "two_sided": False, "masked": False, "albedo": ART + code + ".webp", "normal": "",
                "tint": [1.1, 1.08, 1.05, 1.0], "tile": TILE * 100.0, "desaturation": 0.0, "damp": damp, "roughness": 1.0})


def box(center, size, material, solid=False, shadow=True) -> int:
    """Uma caixa (o cubo de 1 m da Unreal) no centro e no tamanho dados."""
    part = {"mesh": CUBE, "materials": [material], "origin": [round(center[0], 4), round(center[1], 4), round(center[2] + DZ, 4)],
            "basis": [round(size[0], 4), 0, 0, 0, round(size[1], 4), 0, 0, 0, round(size[2], 4)]}
    if solid:
        part["solid"] = True
    if not shadow:
        part["no_shadow"] = True
    parts.append(part)
    return len(parts) - 1


def plate(x, bottom, z, width, height, material, shadow=False) -> int:
    """Um card de frente para a câmera (o plano da Unreal em pé), com a base em `bottom`."""
    part = {"mesh": PLANE, "materials": [material], "origin": [round(x, 4), round(bottom + height * 0.5, 4), round(z + DZ, 4)],
            "basis": [round(width, 4), 0, 0, 0, 0, 1, 0, round(-height, 4), 0]}
    if not shadow:
        part["no_shadow"] = True
    parts.append(part)
    return len(parts) - 1


def water(x0, x1, z0, z1, y=0.012) -> int:
    parts.append({"mesh": WATER, "materials": [WATER_MAT], "origin": [round((x0 + x1) * 0.5, 4), y, round((z0 + z1) * 0.5 + DZ, 4)],
                  "basis": [round(x1 - x0, 4), 0, 0, 0, 1, 0, 0, 0, round(z1 - z0, 4)], "no_shadow": True})
    return len(parts) - 1


def light(origin, color, lumens, radius, shadows=False):
    lights.append({"type": "point", "origin": [round(origin[0], 3), round(origin[1], 3), round(origin[2] + DZ, 3)],
                   "lumens": lumens, "color": color, "radius": radius, "shadows": shadows, "visible": True})


RED = [1.0, 0.28, 0.2]
COLD = [0.75, 0.85, 1.0]


# O acabamento de 28/10: as lâmpadas 30% mais fortes que no #173 (as faces pintadas dos pilares são mais escuras que o
# concreto liso de antes). O que esquentava o jogo é a lanterna do líder, que é do código (tutorial-acabamento.md).
RED_BOOST = 1.3


def red_lamp(x, z=-2.5, y=2.95, lumens=210.0, radius=4.4):
    """A lâmpada de emergência: o card aceso e a luz vermelha logo à frente e abaixo dele, curta, para a poça de luz no
    chão e na parede (entre uma e outra, o escuro). O pisca é do código (#147)."""
    plate(x, y - 0.22, z + 0.04, 0.3, 0.45, card("T_TU08_Lit", 1.0))
    # A luz sai da própria lâmpada, rente à parede: o cone na parede começa nela e cai para baixo e para os lados.
    lumens *= RED_BOOST
    light([x, y - 0.3, z + 0.35], RED, lumens, radius, shadows=True)
    # A poça no chão, logo abaixo e à frente da lâmpada (no pé da parede, entrando na faixa): a mesma lâmpada, pisca junto.
    # Com sombra, ela projeta para a frente a sombra de contato dos objetos e de quem passa.
    light([x, 1.4, z + 1.3], RED, lumens * 0.5, 3.6, shadows=True)


def recess(x0, x1, bottom, top, depth=3.0, glow=0.0, wall_z=-2.6):
    """O escuro atrás de uma abertura da parede: uma caixa funda, de concreto bem escuro, e (opcional) uma luz vermelha fraca
    lá no fim, para a profundidade ler."""
    dark = concrete(0.3, 0.8)
    back = wall_z - depth
    box([(x0 + x1) * 0.5, (bottom + top) * 0.5, back - 0.1], [x1 - x0 + 0.6, top - bottom + 0.4, 0.2], dark)
    box([x0 - 0.1, (bottom + top) * 0.5, wall_z - depth * 0.5], [0.2, top - bottom + 0.4, depth], dark)
    box([x1 + 0.1, (bottom + top) * 0.5, wall_z - depth * 0.5], [0.2, top - bottom + 0.4, depth], dark)
    box([(x0 + x1) * 0.5, top + 0.1, wall_z - depth * 0.5], [x1 - x0 + 0.4, 0.2, depth], dark)
    box([(x0 + x1) * 0.5, bottom - 0.1, wall_z - depth * 0.5], [x1 - x0 + 0.4, 0.2, depth], concrete(0.1, 1.0))
    if glow > 0:
        # Um resto de luz lá dentro, perto da boca: as paredes do fundo somem no escuro.
        light([(x0 + x1) * 0.5, top - 0.6, wall_z - 0.9], RED, glow, 3.0)


WALL_H = 4.32  # a parede pintada (1024 × 434 px) em 10,2 m de largura
WALL_BOTTOM = -0.2  # a base da pintura (a sujeira e a água) entra um pouco abaixo do piso: encosta nele


def wall(x0, x1, code, holes=(), recess_glow=0.0, depth=3.0, wall_z=-2.6, width=None, bottom=WALL_BOTTOM):
    """A parede pintada da zona, um plano com as aberturas em alfa, e o escuro atrás de cada abertura. `holes` em frações
    da pintura (x0, x1, y_topo, y_base), medidas no alfa. Devolve as aberturas em metros (x0, x1, base, topo)."""
    w = width or (x1 - x0 + 0.2)
    h = w / (1024 / 434)
    left = (x0 + x1) * 0.5 - w * 0.5
    plate((x0 + x1) * 0.5, bottom, wall_z, w, h, art(code), shadow=True)
    out = []
    for hx0, hx1, hy0, hy1 in holes:
        hole = (left + hx0 * w, left + hx1 * w, bottom + (1 - hy1) * h, bottom + (1 - hy0) * h)
        recess(*hole, depth, recess_glow, wall_z)
        out.append(hole)
    return out


def shell(x0, x1, floor_code, back=-2.6, front=8.0, ceiling=4.3):
    """O piso em perspectiva, numa peça (da parede até a frente da câmera; a faixa das zonas é a parte sólida), o teto no
    escuro e a água parada no pé da parede (o brilho das lâmpadas nela)."""
    floor = floor_surface(floor_code)
    box([(x0 + x1) * 0.5, -0.2, 0.0], [x1 - x0, 0.4, 4.8], floor, solid=True)
    box([(x0 + x1) * 0.5, -0.2, back + 0.1], [x1 - x0 + 2.4, 0.4, 0.2], floor)
    box([x0 - 0.6, -0.2, (back + 0.2 + front) * 0.5], [1.2, 0.4, front - back - 0.2], floor)
    box([x1 + 0.6, -0.2, (back + 0.2 + front) * 0.5], [1.2, 0.4, front - back - 0.2], floor)
    box([(x0 + x1) * 0.5, -0.2, (2.4 + front) * 0.5], [x1 - x0, 0.4, front - 2.4], floor)
    box([(x0 + x1) * 0.5, ceiling + 0.15, back * 0.5], [x1 - x0 + 4, 0.3, 7.0], VOID, shadow=True)
    water(x0 - 0.8, x1 + 0.8, back + 0.02, back + 0.3)


# A face pintada de cada pilar (docs/design/tutorial-acabamento/cut_art.py) e a largura para a qual ela foi cortada.
PILLAR_FACE = {"T_TU25": 0.9, "T_TU26": 1.0}


def pillar(x, depth=0.8, wall_z=-2.6, height=4.4, tint=0.6, face="T_TU25"):
    """O pilar (o recuo da parede): o bloco de concreto na frente da parede, do piso até o escuro de cima, e a face
    pintada dele (T_TU25 ou T_TU26: a faixa de perigo, a linha d'água, o eletroduto), na altura inteira, indo para o
    preto no alto, como as paredes. A lâmpada fica nele."""
    width = PILLAR_FACE[face]
    box([x, height * 0.5 - 0.1, wall_z + depth * 0.5], [width, height + 0.2, depth], concrete(tint, 0.7))
    # Um material por zona (a chave zone, que o jogo ignora): as faces iguais de duas zonas virariam uma malha só, e o
    # Compatibility corta as luzes além de 8 por objeto (a face ficava apagada).
    face_mat = mat({"zone": ZONE[0], "kind": "art", "two_sided": True, "masked": False, "albedo": ART + face + ".webp"})
    plate(x, -0.04, wall_z + depth + 0.006, width, height + 0.04, face_mat, shadow=False)
    return wall_z + depth


def end_block(x, side, wall_z=-2.6):
    """O fim da zona: um bloco largo de concreto que fecha a vista para o lado (o que a câmera vê além das pontas)."""
    box([x + side * 0.9, 2.1, (wall_z + 2.6) * 0.5], [1.8, 4.6, 5.2 - wall_z], concrete(0.2, 0.5))


def prop_card(code, x, width, height, z=-1.95, bottom=0.0):
    return plate(x, bottom, z, width, height, art(code), shadow=True)


def interactive(code, name, loot, x, width, height, z=-2.05, bottom=0.0):
    """O interativo (a porta, o armário, o painel): iluminado pela cena, como a parede (um card sem luz própria ficava
    preto ou cinza contra o vermelho); o _Open troca o material, como nos outros mapas."""
    index = plate(x, bottom, z, width, height, art(code), shadow=True)
    props.append({"code": code.split("_")[1], "name": name, "loot": loot, "x": round(x, 3), "parts": [index],
                  "open": art(code + "_Open")})


FRONT_Z = 11.0  # o primeiro plano: 8 m da câmera (a faixa fica a 19 m), passa rápido na frente dela


def front_light(x, color=None, lumens=150.0):
    """A luz que recorta o primeiro plano: uma lâmpada fora do quadro, entre a câmera e as peças (no vermelho das
    outras; na plataforma, fria). Clareia também a frente do piso."""
    light([x, 3.0, FRONT_Z + 1.4], color or RED, lumens, 3.0)


def foreground(x, code, width, height, bottom, z=FRONT_Z):
    """A peça do primeiro plano (canos, cabos, cano quebrado): perto da câmera, iluminada pela cena (as lâmpadas a
    recortam), com o desfoque e o alfa macio na própria pintura (o card em alpha blend é do código)."""
    plate(x, bottom, z, width, height, art(code))


def main() -> None:
    global VOID, WATER_MAT
    VOID = mat({"kind": "blockout", "two_sided": False, "masked": False, "albedo": ART + "T_AHPlaster.webp",
                "color": [0.03, 0.028, 0.03, 1.0], "tile": 170.0, "roughness": 0.95})
    WATER_MAT = mat({"kind": "water", "two_sided": False, "masked": False, "Amplitude": 0.15, "Wavelength": 260.0, "Speed": 0.5,
                     "Foam": 0.0, "Roughness": 0.04, "Opacity": 1.0, "RippleStrength": 0.012, "Specular": 0.95,
                     "tint": [0.03, 0.03, 0.032, 1.0], "foam_tint": [0.2, 0.2, 0.2, 1.0]})
    zones = []

    # ---- 1. O corredor de contenção: a parede com a passagem para o escuro do lado, a faixa de perigo, os pilares com as
    # lâmpadas, caixas, tambores e raízes no pé da parede, a grade solta e o cano no primeiro plano.
    ZONE[0] = 0
    x0, x1 = 0.0, 10.0
    shell(x0, x1, "T_TU02")
    (sx0, sx1, sb, st), = wall(x0, x1, "T_TU01", holes=[(0.771, 0.892, 0.318, 0.952)], recess_glow=220.0, depth=4.5)
    # A passagem do lado, fechada pela contenção: a porta de enrolar baixada (a segunda porta de segurança; o batente
    # dela cobre a abertura inteira). Fica parada no jogo até o código decidir se ela também baixa na frente da equipe.
    interactive("T_TUX04_Security_Shutter", "Porta de segurança", "", (sx0 + sx1) * 0.5, (st - sb + 0.5) * 756 / 1024,
                st - sb + 0.5, z=-2.52, bottom=sb - 0.14)
    end_block(x0, -1)
    end_block(x1, 1)
    # As lâmpadas do corredor ficam mais perto umas das outras: o raio menor deixa o escuro entre as poças.
    for px, face in ((2.45, "T_TU25"), (6.05, "T_TU26")):
        red_lamp(px, z=pillar(px, face=face), y=2.85, radius=3.4)
    # Acima do batente da porta de enrolar (a lâmpada não tapa o sinal dela).
    red_lamp(8.38, y=3.55, lumens=150.0, radius=3.2)
    prop_card("T_TU15", 0.8, 0.95, 0.86, z=-2.15)
    prop_card("T_TU14", 3.7, 1.45, 1.1, z=-2.05)
    prop_card("T_TU19", 5.2, 0.8, 0.56, z=-1.75)
    prop_card("T_TU05", 7.0, 1.9, 1.24, z=-1.7)
    prop_card("T_TU17", 1.2, 1.5, 0.98, z=3.4)
    # O primeiro plano, na frente de onde a câmera fica no meio da zona (x0 + 5,6): os canos no alto e o cano quebrado.
    foreground(5.9, "T_TU20", 3.3, 0.6, 2.38)
    foreground(3.9, "T_TU22", 0.3, 1.62, 0.9)
    front_light(4.6)
    zones.append({"x0": x0, "x1": x1, "z0": -2.4 + DZ, "z1": 2.4 + DZ, "y": 0.0, "name": "Corredor"})

    # ---- 2. A sala das celas: as duas celas fundas atrás das grades, o armário de manutenção (a busca), o painel das
    # portas, o carrinho e os tambores; os cabos no primeiro plano.
    ZONE[0] = 1
    x0 = PITCH
    x1 = x0 + 10.0
    shell(x0, x1, "T_TU13")
    cells = wall(x0, x1, "T_TU11", holes=[(0.087, 0.237, 0.362, 0.892), (0.384, 0.534, 0.362, 0.892)], depth=2.6, recess_glow=110.0)
    end_block(x0, -1)
    end_block(x1, 1)
    for hx0, hx1, hb, ht in cells:
        plate((hx0 + hx1) * 0.5, hb - 0.05, -2.52, hx1 - hx0 + 0.2, ht - hb + 0.1, art("T_TU04"), shadow=True)
    red_lamp(x0 + 0.55, y=3.05)
    red_lamp(x0 + 5.55, y=3.05)
    red_lamp(x0 + 8.4, z=pillar(x0 + 9.3) - 0.55, y=3.0, lumens=180.0)
    interactive("T_TUX02_Maintenance_Locker", "Armário de manutenção", "Curativos", x0 + 7.0, 1.25, 1.62)
    interactive("T_TUX03_Door_Panel", "Painel das portas", "", x0 + 8.4, 0.55, 0.87, z=-2.52, bottom=0.95)
    prop_card("T_TU16", x0 + 9.5, 0.95, 0.95, z=-1.75)
    prop_card("T_TU15", x0 + 5.7, 0.9, 0.82, z=-2.1)
    prop_card("T_TU05", x0 + 3.0, 1.6, 1.04, z=3.3)
    foreground(x0 + 5.2, "T_TU21", 2.9, 1.02, 2.15)
    foreground(x0 + 7.4, "T_TU22", 0.3, 1.62, 1.2)
    front_light(x0 + 6.4)
    zones.append({"x0": x0, "x1": x1, "z0": -2.4 + DZ, "z1": 2.4 + DZ, "y": 0.0, "name": "Celas"})

    # ---- 3. A rota do Nick: a porta de segurança baixada atrás da equipe (na abertura da esquerda), o buraco com as
    # raízes e a água, o duto com a grade arrancada e a escada até o alçapão aberto no teto.
    ZONE[0] = 2
    x0 = 2 * PITCH
    x1 = x0 + 10.0
    shell(x0, x1, "T_TU24")
    (dx0, dx1, db, dt), = wall(x0, x1, "T_TU12", holes=[(0.065, 0.234, 0.346, 0.942)], depth=2.0)
    end_block(x0, -1)
    end_block(x1, 1)
    # A porta baixada: o batente dela cobre a abertura inteira.
    interactive("T_TUX01_Security_Door", "Porta de segurança", "", (dx0 + dx1) * 0.5, (dt - db + 0.45) * 834 / 1024,
                dt - db + 0.45, z=-2.52, bottom=db - 0.12)
    red_lamp(x0 + 3.4, y=3.1)
    red_lamp(x0 + 9.45, z=pillar(x0 + 9.45, face="T_TU26"), y=2.9)
    plate(x0 + 7.6, 1.05, -2.45, 1.15, 1.27, art("T_TU07"), shadow=True)
    plate(x0 + 5.6, -0.05, -2.2, 3.32, 4.32, art("T_TU06"), shadow=True)
    prop_card("T_TU17", x0 + 8.6, 1.3, 0.86, z=-1.9)
    prop_card("T_TU05", x0 + 0.9, 1.6, 1.04, z=3.3)
    foreground(x0 + 5.3, "T_TU20", 3.3, 0.6, 2.42)
    foreground(x0 + 3.8, "T_TU22", 0.3, 1.62, 0.7)
    front_light(x0 + 4.6)
    zones.append({"x0": x0, "x1": x1, "z0": -2.4 + DZ, "z1": 2.4 + DZ, "y": 0.0, "name": "Rota do Nick"})

    # ---- 4. A plataforma: a equipe anda na plataforma; atrás dela, o fosso dos trilhos com o vagão parado e aceso por
    # dentro, e a parede de azulejo com a boca do túnel no escuro. O fim da zona é a porta aberta do vagão: a saída do
    # mapa é o embarque. A luz fria do vagão cai na plataforma e puxa o olho para lá.
    ZONE[0] = 3
    x0 = 3 * PITCH
    x1 = x0 + 12.0
    platform = art("T_TU09", masked=False, two_sided=False)
    box([(x0 + x1) * 0.5, -0.2, 0.0], [x1 - x0, 0.4, 4.8], platform, solid=True)
    # A plataforma continua depois do fim da zona, até o bloco que fecha a vista, além do fim do vagão.
    box([x1 + 1.1, -0.2, 0.0], [2.2, 0.4, 4.8], platform)
    box([(x0 + x1) * 0.5 + 0.9, -0.2, 5.2], [x1 - x0 + 4.2, 0.4, 5.6], floor_surface("T_TU02"))
    box([(x0 + x1) * 0.5 + 0.9, -0.75, -2.45], [x1 - x0 + 4.2, 1.1, 0.1], concrete(0.12, 0.8))  # a beira da plataforma
    box([(x0 + x1) * 0.5, -1.35, -4.6], [x1 - x0 + 6, 0.2, 4.2], concrete(0.06, 1.0))  # o fundo do fosso
    water(x0 - 2, x1 + 2, -6.6, -2.6, y=-1.22)
    box([(x0 + x1) * 0.5, 5.1, -3.0], [x1 - x0 + 6, 0.3, 8.0], VOID)
    wall(x0, x1, "T_TU03", holes=[(0.022, 0.117, 0.226, 0.776)], wall_z=-6.4, width=14.6, bottom=-1.45, depth=3.0)
    end_block(x0, -1, wall_z=-6.4)
    end_block(x1 + 2.2, 1, wall_z=-6.4)
    # O vagão no fosso, com o chão na altura da plataforma (o piso tapa as rodas). A porta aberta da direita (de 64% a
    # 81% da pintura) fica no fim da zona (x1 - 0,6): é ali o embarque; o fim do vagão entra no escuro do túnel.
    train = x1 - 0.6 - (0.725 - 0.5) * 10.0
    plate(train, -1.0, -3.9, 10.0, 4.03, card("T_TU10", 0.75))
    # A luz das portas (a da porta aberta do embarque com sombra, que encosta no chão quem passa) e a do embarque.
    for f in (0.27, 0.5, 0.725):
        light([train + (f - 0.5) * 10.0, 1.2, -3.1], COLD, 420.0, 6.5, shadows=f == 0.5)
    light([x1 - 0.6, 1.4, -1.6], COLD, 340.0, 5.0, shadows=True)
    red_lamp(x0 + 0.9, z=-6.3, y=2.6)
    light([x0 + 0.9, 1.7, -2.2], RED, 200.0, 4.5)
    prop_card("T_TU14", x0 + 1.4, 1.3, 1.0, z=-2.15)
    foreground(x0 + 5.6, "T_TU21", 2.9, 1.02, 2.2)
    foreground(x0 + 3.9, "T_TU22", 0.3, 1.62, 0.9)
    front_light(x0 + 4.8, COLD, 260.0)
    zones.append({"x0": x0, "x1": x1, "z0": -2.4 + DZ, "z1": 2.4 + DZ, "y": 0.0, "name": "Plataforma"})

    # O resto no escuro: o fundo atrás de tudo (o que aparece pelas frestas).
    box([x1 * 0.5, 2.0, -10.0], [x1 + 30.0, 16.0, 0.4], VOID)
    out = {"map": "ContainmentCorridor", "display": "Corredor de Contenção", "materials": materials, "parts": parts,
           "lights": lights, "texts": [], "zones": zones, "side_doors": [], "props": sorted(props, key=lambda p: p["x"])}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print(f"{OUT.name}: {len(parts)} peças, {len(lights)} luzes, {len(zones)} zonas, {len(props)} props, {len(materials)} materiais")


if __name__ == "__main__":
    main()
