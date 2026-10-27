"""Monta o mapa do tutorial, o Corredor de Contenção (#147), em data/scenarios/ContainmentCorridor.json, no mesmo contrato
dos cenários que vêm da Unreal (tools/sync_scenarios.py): as peças com as malhas de data/scenarios/meshes.json (o cubo e
o plano), os materiais, as luzes, as zonas caminháveis e os props vasculháveis. A cena é do jogo, não da Unreal: o mapa
nasce aqui, com as medidas da página docs/design/tutorial.md (o PR #152 da Awesomic).

A arte: a de lá tem o prefixo TU (T_TU01 a T_TU10 e os interativos T_TUX*). Enquanto ela não está em art/scenarios, cada
peça usa uma provisória de outro cenário com o mesmo papel (a parede de concreto, a porta de aço, o armário de
ferramentas, o painel, a escada) e o vagão é o metrô da Estação. Quando a arte chegar, é só rodar de novo: cada peça
troca sozinha pela TU que existir.

As zonas, da esquerda para a direita (o corte da câmera, que olha para -Z):
  0 Corredor de contenção  a partida e a primeira luta, as lâmpadas vermelhas e a porta de segurança no fim
  1 Sala das celas         o Nick, o armário de manutenção (a busca), o painel das portas e a segunda luta
  2 Rota do Nick           o duto e a escada até o alçapão, e a terceira luta
  3 Plataforma             a plataforma esquecida e o vagão de luz fria no fosso: o embarque
Entre uma zona e outra, a porta de segurança: no fim de cada zona, aberta só com a zona vencida; no começo da seguinte,
fechada (baixou atrás da equipe).

  python tools/build_containment_corridor.py
"""
import json
from pathlib import Path

PROTO = Path(__file__).resolve().parents[1]
ART = PROTO / 'art/scenarios'
OUT = PROTO / 'data/scenarios/ContainmentCorridor.json'

CUBE, PLANE = 0, 1
## O pé-direito (do piso ao teto), a face da parede do fundo e a faixa de cada zona (de z0 a z1).
HEIGHT = 3.6
BACK_Z = -2.3
LANE = (-2.0, 2.0)
## A plataforma: a faixa de andar fica na frente; atrás dela, o fosso com o vagão e a parede de azulejo.
PIT_Z = (-5.6, -2.0)
PLATFORM_WALL_Z = -6.0
ZONES = [
    {'x0': 0.0, 'x1': 16.0, 'name': 'Corredor de contenção'},
    {'x0': 20.0, 'x1': 38.0, 'name': 'Sala das celas'},
    {'x0': 42.0, 'x1': 54.0, 'name': 'Rota do Nick'},
    {'x0': 58.0, 'x1': 78.0, 'name': 'Plataforma'},
]
## A luz de emergência (a proposta da página: vermelha, 900 lm, 6 m) e a fria do vagão (azulada, 1200 lm, 8 m).
RED = [1.0, 0.28, 0.2]
COLD = [0.75, 0.85, 1.0]
LAMPS = [3.0, 8.5, 13.5, 23.0, 30.5, 36.0, 45.5, 51.5, 61.0]


def art(name):
    return f'res://art/scenarios/{name}.webp'


def has(name):
    return (ART / f'{name}.webp').exists()


class Map:
    def __init__(self):
        self.materials = []
        self.keys = {}
        self.parts = []
        self.lights = []
        self.props = []
        self.doors = []

    def material(self, key, spec):
        if key not in self.keys:
            self.keys[key] = len(self.materials)
            self.materials.append(spec)
        return self.keys[key]

    def box(self, material, center, size, solid=True, shadow=True):
        part = {'mesh': CUBE, 'materials': [material], 'origin': [round(v, 4) for v in center],
                'basis': [size[0], 0.0, 0.0, 0.0, size[1], 0.0, 0.0, 0.0, size[2]]}
        if solid:
            part['solid'] = True
        if not shadow:
            part['no_shadow'] = True
        self.parts.append(part)
        return len(self.parts) - 1

    def card(self, material, center, width, height, solid=False):
        """Um card de frente para a câmera (o plano em pé, a imagem inteira), com o meio em center."""
        part = {'mesh': PLANE, 'materials': [material], 'origin': [round(v, 4) for v in center],
                'basis': [width, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, -height, 0.0], 'no_shadow': True}
        if solid:
            part['solid'] = True
        self.parts.append(part)
        return len(self.parts) - 1

    def light(self, origin, color, lumens, radius, shadows=False, blink=None):
        light = {'type': 'point', 'origin': [round(v, 4) for v in origin], 'lumens': lumens, 'color': color,
                 'radius': radius, 'shadows': shadows, 'visible': True}
        if blink is not None:
            light['blink'] = blink
        self.lights.append(light)


def surface(albedo, normal, tint, tile, damp=0.0):
    return {'kind': 'surface', 'two_sided': False, 'masked': False, 'albedo': art(albedo), 'normal': art(normal) if normal else '',
            'tint': tint + [1.0], 'tile': tile, 'desaturation': 0.12, 'damp': damp, 'roughness': 1.0}


def cutout(albedo, kind='art'):
    spec = {'kind': kind, 'two_sided': True, 'masked': True, 'albedo': art(albedo)}
    if kind == 'card':
        spec.update({'emissive': 1.0, 'haze': 0.0, 'haze_color': [0.55, 0.52, 0.48, 1.0], 'rect': [0.0, 0.0, 1.0, 1.0]})
    return spec


def pick(final, fallback):
    """A peça TU da Awesomic, se já está em art/scenarios; senão a provisória."""
    return final if has(final) else fallback


def build():
    m = Map()
    final_walls = has('T_TU01')
    wall = m.material('wall', {'kind': 'art', 'two_sided': True, 'masked': False, 'albedo': art('T_TU01')} if final_walls
                      else surface('T_SH_rough_concrete_base_color', 'T_SH_rough_concrete_normal', [0.34, 0.32, 0.3], 160.0))
    concrete = m.material('concrete', surface('T_SH_rough_concrete_base_color', 'T_SH_rough_concrete_normal', [0.16, 0.15, 0.15], 160.0))
    floor = m.material('floor', surface('T_TU02', '', [0.42, 0.42, 0.42], 200.0, 0.8) if has('T_TU02')
                       else surface('T_SH_rough_concrete_base_color', 'T_SH_rough_concrete_normal', [0.28, 0.27, 0.25], 123.0, 0.8))
    platform_floor = m.material('platform_floor', {'kind': 'art', 'two_sided': True, 'masked': False, 'albedo': art('T_TU09')} if has('T_TU09')
                                else surface('T_SH_metal_plate_base_color', 'T_SH_metal_plate_normal', [0.32, 0.31, 0.28], 150.0))
    tile_wall = m.material('tile_wall', {'kind': 'art', 'two_sided': True, 'masked': False, 'albedo': art('T_TU03')} if has('T_TU03')
                           else surface('T_SH_green_metal_rust_base_color', 'T_SH_green_metal_rust_normal', [0.36, 0.42, 0.38], 200.0))
    door = m.material('door', cutout(pick('T_TUX01_Security_Door', 'T_DI20'), 'card'))
    door_open = m.material('door_open', cutout(pick('T_TUX01_Security_Door_Open', 'T_PT02'), 'card'))
    locker = m.material('locker', cutout(pick('T_TUX02_Maintenance_Locker', 'T_DEX01_Tool_Locker'), 'card'))
    locker_open = m.material('locker_open', cutout(pick('T_TUX02_Maintenance_Locker_Open', 'T_DEX01_Tool_Locker_Open'), 'card'))
    panel = m.material('panel', cutout(pick('T_TUX03_Door_Panel', 'T_PT12_Control_Panel'), 'card'))
    panel_down = m.material('panel_down', cutout(pick('T_TUX03_Door_Panel_Open', 'T_PT12_Control_Panel_Open'), 'card'))
    bars = m.material('bars', cutout(pick('T_TU04', 'T_PT03')))
    roots = m.material('roots', cutout(pick('T_TU05', 'T_DE11')))
    ladder = m.material('ladder', cutout(pick('T_TU06', 'T_DE10')))
    duct = m.material('duct', cutout(pick('T_TU07', 'T_DE05')))
    lamp_off = m.material('lamp_off', cutout('T_TU08') if has('T_TU08') else {'kind': 'blockout', 'two_sided': False, 'masked': False,
                          'albedo': art('T_AHPlaster'), 'color': [0.22, 0.08, 0.07, 1.0], 'tile': 40.0, 'roughness': 0.4})
    lamp_lit = m.material('lamp_lit', cutout('T_TU08_Lit') if has('T_TU08_Lit') else {'kind': 'glow', 'two_sided': False, 'masked': False,
                          'tint': RED + [1.0]})
    barrier = m.material('barrier', cutout('T_PT09'))

    def own(material, zone):
        """O material só desta zona: a junção das peças (scenario_world._merge) fica por zona, e cada malha junta recebe
        as luzes da zona dela (no Compatibility, cada objeto pega no máximo 8 luzes; o mapa inteiro numa malha ficava
        escuro longe das primeiras)."""
        return m.material('%d-%d' % (material, ZONES.index(zone)), dict(m.materials[material]))

    def room(zone, back_material, depth_back=BACK_Z, with_floor=True):
        floor_here, concrete_here, back_here = own(floor, zone), own(concrete, zone), own(back_material, zone)
        x0, x1 = zone['x0'], zone['x1']
        length = x1 - x0
        middle = (x0 + x1) * 0.5
        back = depth_back - 0.2
        front = LANE[1] + 0.4
        deep = front - back
        center_z = (front + back) * 0.5
        if with_floor:
            m.box(floor_here, [middle, -0.2, center_z], [length + 0.8, 0.4, deep])
        m.box(concrete_here, [middle, HEIGHT + 0.2, center_z], [length + 0.8, 0.4, deep], solid=False)
        m.box(concrete_here, [x0 - 0.2, HEIGHT * 0.5, center_z], [0.4, HEIGHT, deep])
        m.box(concrete_here, [x1 + 0.2, HEIGHT * 0.5, center_z], [0.4, HEIGHT, deep])
        if final_walls and back_material == wall:
            # A parede pintada (8,2 x 4,58 m) se repete na horizontal, cortada pelo pé-direito.
            x = x0
            while x < x1:
                width = min(8.2, x1 - x)
                m.box(back_here, [x + width * 0.5, 2.29, depth_back - 0.2], [width, 4.58, 0.4])
                x += 8.2
        else:
            m.box(back_here, [middle, HEIGHT * 0.5, depth_back - 0.2], [length + 0.4, HEIGHT, 0.4])

    # As paredes grossas entre as zonas (o que a câmera vê além das pontas).
    for left, right in zip(ZONES, ZONES[1:]):
        gap = right['x0'] - left['x1']
        m.box(concrete, [(left['x1'] + right['x0']) * 0.5, HEIGHT * 0.5, 0.0], [gap - 0.8, HEIGHT, LANE[1] * 2 + 0.8])

    for zone in ZONES[:3]:
        room(zone, wall)

    # A caixa fechada do subsolo: além das pontas, acima do teto e atrás de tudo, só concreto (a câmera nunca vê céu).
    span = (ZONES[0]['x0'] - 30.0, ZONES[-1]['x1'] + 30.0)
    m.box(concrete, [(span[0] + span[1]) * 0.5, HEIGHT + 6.0, (PLATFORM_WALL_Z + LANE[1]) * 0.5 - 0.2],
          [span[1] - span[0], 11.6, LANE[1] - PLATFORM_WALL_Z + 0.4], solid=False, shadow=False)
    m.box(concrete, [(span[0] + span[1]) * 0.5, 2.0, PLATFORM_WALL_Z - 0.6], [span[1] - span[0], 24.0, 0.8], solid=False, shadow=False)
    m.box(concrete, [(span[0] + ZONES[0]['x0'] - 0.4) * 0.5, 2.0, (PLATFORM_WALL_Z + LANE[1]) * 0.5],
          [ZONES[0]['x0'] - 0.4 - span[0], 24.0, LANE[1] - PLATFORM_WALL_Z + 0.8], solid=False, shadow=False)
    m.box(concrete, [(ZONES[-1]['x1'] + 0.4 + span[1]) * 0.5, 2.0, (PLATFORM_WALL_Z + LANE[1]) * 0.5],
          [span[1] - ZONES[-1]['x1'] - 0.4, 24.0, LANE[1] - PLATFORM_WALL_Z + 0.8], solid=False, shadow=False)

    # A plataforma: o piso de andar na frente, o fosso (mais baixo) e a parede de azulejo no fundo.
    p = ZONES[3]
    room(p, tile_wall, PLATFORM_WALL_Z, with_floor=False)
    length = p['x1'] - p['x0']
    middle = (p['x0'] + p['x1']) * 0.5
    m.box(own(platform_floor, p), [middle, -0.2, (LANE[0] + LANE[1] + 0.8) * 0.5], [length + 0.8, 0.4, LANE[1] - LANE[0] + 0.8])
    m.box(own(concrete, p), [middle, -1.4, (PIT_Z[0] + PIT_Z[1]) * 0.5], [length + 0.8, 0.4, PIT_Z[1] - PIT_Z[0]], solid=False)

    def door_at(x, zone_index, role):
        part = m.card(door, [x, 1.475 + 0.02, BACK_Z + 0.04], 2.4, 2.95)
        m.doors.append({'x': x, 'zone': zone_index, 'role': role, 'parts': [part], 'closed': door, 'open': door_open})

    for i, zone in enumerate(ZONES):
        if i > 0:
            door_at(zone['x0'] + 1.5, i, 'entry')
        if i < len(ZONES) - 1:
            door_at(zone['x1'] - 1.5, i, 'exit')

    # As lâmpadas de emergência na parede do fundo, cada uma com a luz vermelha que pisca fora de fase da vizinha.
    for index, x in enumerate(LAMPS):
        part = m.card(lamp_lit, [x, 3.0, BACK_Z + 0.05], 0.3, 0.45) if has('T_TU08_Lit') \
            else m.box(lamp_lit, [x, 3.0, BACK_Z + 0.05], [0.3, 0.45, 0.12], solid=False, shadow=False)
        phase = round((index * 0.37) % 1.0, 3)
        m.parts[part]['blink'] = {'phase': phase, 'off': lamp_off}
        m.light([x, 2.7, BACK_Z + 0.9], RED, 900.0, 6.0, shadows=index % 3 == 0, blink={'phase': phase})

    # A luz de serviço que sobrou: fraca e fria, no teto de cada zona, para o piso e as paredes lerem entre as lâmpadas
    # vermelhas (o "ambiente baixo" da página: a contenção é escura, mas o caminho se vê).
    for zone in ZONES:
        x = zone['x0'] + 3.0
        while x < zone['x1'] - 1.0:
            m.light([x, HEIGHT - 0.4, 0.2], [0.78, 0.82, 0.9], 420.0, 9.0)
            x += 6.0

    # Zona 0: as raízes entrando pelas frestas e a barreira de perigo.
    m.card(roots, [6.0, 0.4, BACK_Z + 0.35], 2.4, 0.8)
    m.card(barrier, [10.8, 0.5, BACK_Z + 0.3], 2.0, 1.0)
    # Zona 1: as duas celas de grade, o armário de manutenção (a busca, no trecho antes da luta) e o painel das portas.
    m.card(bars, [23.2, 1.15, BACK_Z + 0.05], 3.2, 2.3)
    m.card(bars, [26.6, 1.15, BACK_Z + 0.05], 3.2, 2.3)
    locker_part = m.card(locker, [29.6, 0.94, BACK_Z + 0.25], 1.45, 1.88)
    m.props.append({'code': 'TUX02', 'name': 'Armário de manutenção', 'loot': '1 curativo e 1 comida', 'x': 29.6, 'parts': [locker_part], 'open': locker_open})
    panel_part = m.card(panel, [34.6, 1.45, BACK_Z + 0.05], 0.62, 0.98)
    m.doors_panel = {'x': 34.6, 'zone': 1, 'parts': [panel_part], 'closed': panel, 'open': panel_down}
    m.card(roots, [31.4, 0.35, BACK_Z + 0.35], 2.0, 0.7)
    # Zona 2: a rota do Nick, o duto com a grade arrancada e a escada até o alçapão no teto.
    m.card(duct, [46.0, 0.85, BACK_Z + 0.05], 1.4, 1.55)
    m.card(ladder, [49.8, 1.8, BACK_Z + 0.1], 2.4, 3.6)
    m.card(roots, [52.0, 0.35, BACK_Z + 0.35], 1.8, 0.6)
    # Zona 3: o vagão no fosso, de lado, com as portas para a plataforma; as luzes frias nas portas.
    train_x = 68.0
    model = []
    if has('T_TU10'):
        m.card(m.material('train', cutout('T_TU10')), [train_x, 1.6, (PIT_Z[0] + PIT_Z[1]) * 0.5], 10.0, 4.03)
    else:
        model.append({'kind': 'metro', 'origin': [train_x, -1.2, -3.9], 'yaw': 0.0})
    for x in (train_x - 3.0, train_x + 3.0):
        m.light([x, 2.2, -2.4], COLD, 1200.0, 8.0, shadows=x < train_x)
    m.light([62.0, 3.0, -2.0], RED, 600.0, 6.0, blink={'phase': 0.5})

    zones = [{'x0': z['x0'], 'x1': z['x1'], 'z0': LANE[0], 'z1': LANE[1], 'y': 0.0, 'name': z['name']} for z in ZONES]
    return {'map': 'ContainmentCorridor', 'display': 'Corredor de Contenção', 'materials': m.materials, 'parts': m.parts,
            'lights': [{'type': 'sun', 'basis': [-0.241845, -0.707107, -0.664464, -0.241845, 0.707107, -0.664463, 0.939693, 1e-06, -0.342021],
                        'lux': 0.1, 'color': [0.702, 0.7725, 0.8196], 'shadows': False}] + m.lights,
            'texts': [], 'zones': zones, 'side_doors': [], 'props': m.props,
            # O que só este mapa tem (scenario_world.gd): as portas de segurança e o painel, o vagão e onde se embarca.
            'security_doors': m.doors, 'door_panel': m.doors_panel, 'models': model,
            'train': {'x': train_x, 'zone': 3}}


if __name__ == '__main__':
    data = build()
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    final = sum(1 for spec in data['materials'] if 'T_TU' in spec.get('albedo', ''))
    print(f"{OUT.relative_to(PROTO)}: {len(data['parts'])} peças, {len(data['lights'])} luzes, {len(data['zones'])} zonas, "
          f"{len(data['props'])} prop, {len(data['security_doors'])} portas; {final} materiais com a arte TU")
