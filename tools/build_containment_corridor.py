"""Monta o mapa do tutorial, o Corredor de Contenção (#147), em data/scenarios/ContainmentCorridor.json.

A base é o mapa da Awesomic (PR #173, docs/design/tutorial/map/ContainmentCorridor.json, gerado por
docs/design/tutorial/build_map.py e conferido contra o contrato de tools/sync_scenarios.py): as peças, os materiais, as
luzes, as zonas e os props, com a arte T_TU*/T_TUX* de art/scenarios. Este script só acrescenta a camada de jogo que
scenario_world.gd lê, sem mexer na planta ("Para integrar", docs/design/tutorial.md):
  - as lâmpadas de emergência piscam: cada card aceso (T_TU08_Lit) troca pelo apagado (T_TU08) e as luzes vermelhas dele
    caem junto, cada lâmpada na sua fase (blink);
  - o armário de manutenção é o único prop (a busca); o painel das portas e a porta de segurança da rota do Nick viram
    door_panel e security_doors (a porta baixa atrás da equipe; o painel fica acionado da sala das celas em diante);
  - o vagão e as luzes frias dele ficam num nó "Metro" (node), que o corredor esconde até o trem chegar e faz entrar no
    fosso (arrive_train); o embarque é na porta aberta da direita, no fim da plataforma (train.x).

As zonas, da esquerda para a direita (10 m cada, a cada 21,2 m, 8 m para o fundo; a câmera olha para -Z):
  0 Corredor             a partida e a primeira luta
  1 Celas                o Nick, a segunda luta e o armário de manutenção (a busca)
  2 Rota do Nick         a porta de segurança que baixa atrás da equipe, o duto, a escada e a terceira luta
  3 Plataforma           o vagão de luz fria no fosso: o embarque

  python tools/build_containment_corridor.py
"""
import json
from pathlib import Path

PROTO = Path(__file__).resolve().parents[1]
SOURCE = PROTO / 'docs/design/tutorial/map/ContainmentCorridor.json'
OUT = PROTO / 'data/scenarios/ContainmentCorridor.json'

LAMP_LIT = 'res://art/scenarios/T_TU08_Lit.webp'
LAMP_OFF = 'res://art/scenarios/T_TU08.webp'
TRAIN_ART = 'res://art/scenarios/T_TU10.webp'
## As luzes de uma lâmpada ficam no mesmo x do card dela (a da parede e a do chão).
LAMP_LIGHT_X = 0.05
RED = [1.0, 0.28, 0.2]
COLD = [0.75, 0.85, 1.0]
## O vagão: as luzes frias das portas e da plataforma da saída ficam a até 3 m do card, no fosso e na beira dele.
TRAIN_LIGHT_X = 3.0
TRAIN_LIGHT_Z = -9.0
## A porta aberta da direita do vagão, no fim da plataforma (x1 - 0,6 m, sob a luz fria): onde se embarca.
BOARD_MARGIN = 0.6


def material_of(data, part):
    return data['materials'][part['materials'][0]]


def build():
    data = json.loads(SOURCE.read_text(encoding='utf-8'))
    zones = data['zones']

    # As lâmpadas: o card aceso troca pelo apagado no mesmo ritmo das luzes vermelhas dele.
    lit = next(i for i, m in enumerate(data['materials']) if m.get('albedo') == LAMP_LIT)
    off_spec = dict(data['materials'][lit])
    off_spec['albedo'] = LAMP_OFF
    data['materials'].append(off_spec)
    off = len(data['materials']) - 1
    lamps = [i for i, p in enumerate(data['parts']) if p['materials'][0] == lit]
    for order, index in enumerate(sorted(lamps, key=lambda i: data['parts'][i]['origin'][0])):
        part = data['parts'][index]
        # Fora de fase entre vizinhas (a página: 0,6 s acesa e 0,4 s a 25%).
        phase = round((order * 0.37) % 1.0, 3)
        part['blink'] = {'phase': phase, 'off': off}
        x = part['origin'][0]
        for light in data['lights']:
            if light.get('type') == 'point' and light['color'] == RED and abs(light['origin'][0] - x) < LAMP_LIGHT_X:
                light['blink'] = {'phase': phase}

    # Os interativos: o armário é a busca; o painel e a porta da rota do Nick são da porta de segurança.
    props = data['props']
    by_code = {prop['code']: prop for prop in props}
    locker, panel, door = by_code['TUX02'], by_code['TUX03'], by_code['TUX01']

    def zone_of(x):
        return next(i for i, z in enumerate(zones) if z['x0'] - 0.01 <= x <= z['x1'] + 0.01)

    def closed_of(prop):
        return data['parts'][prop['parts'][0]]['materials'][0]

    data['props'] = [dict(locker, loot='1 curativo e 1 comida')]
    data['door_panel'] = {'x': panel['x'], 'zone': zone_of(panel['x']), 'parts': panel['parts'], 'closed': closed_of(panel),
                          'open': panel['open']}
    data['security_doors'] = [{'x': door['x'], 'zone': zone_of(door['x']), 'role': 'entry', 'parts': door['parts'],
                               'closed': closed_of(door), 'open': door['open']}]

    # O vagão e as luzes frias dele num nó só, que entra no fosso quando o trem chega.
    train_parts = [i for i, p in enumerate(data['parts']) if material_of(data, p).get('albedo') == TRAIN_ART]
    train_x = data['parts'][train_parts[0]]['origin'][0]
    for index in train_parts:
        data['parts'][index]['node'] = 'Metro'
    for light in data['lights']:
        if light.get('type') == 'point' and light['color'] == COLD and abs(light['origin'][0] - train_x) <= TRAIN_LIGHT_X \
                and light['origin'][2] < TRAIN_LIGHT_Z:
            light['node'] = 'Metro'
    platform = len(zones) - 1
    data['train'] = {'x': round(zones[platform]['x1'] - BOARD_MARGIN, 3), 'zone': platform}
    data['models'] = []
    return data


if __name__ == '__main__':
    data = build()
    OUT.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n', encoding='utf-8')
    blinking = sum(1 for p in data['parts'] if 'blink' in p)
    print(f"{OUT.relative_to(PROTO)}: {len(data['parts'])} peças, {len(data['lights'])} luzes, {len(data['zones'])} zonas, "
          f"{len(data['props'])} prop, {len(data['security_doors'])} porta, {blinking} lâmpadas que piscam")
