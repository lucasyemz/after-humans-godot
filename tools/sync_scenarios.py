"""Converte a exportação dos mapas de cenário da Unreal (tools/unreal_export_scenarios.py, em build/unreal-export) para
os dados e a arte da Godot:

  data/scenarios/meshes.json   as malhas (as formas básicas da Unreal, a grade da água, a arandela), já em metros e nos
                               eixos da Godot
  data/scenarios/<Mapa>.json   as peças (malha, transformação, material), as luzes, os textos, as zonas caminháveis, as
                               portas dos interiores laterais e os props vasculháveis
  art/scenarios/<arquivo>.webp as texturas, em WebP (até 2048 px nos fundos e 1024 nos cards e superfícies)

Rode depois da exportação:  python tools/sync_scenarios.py  (precisa do Pillow)

Eixos: a Unreal é X para a frente (a direita do corte), Y para a direita (o fundo negativo) e Z para cima, em cm; a Godot
é X, Y para cima e Z para a câmera, em m. Um ponto (x, y, z) da Unreal vira (x, z, y) / 100 (é um espelho: os triângulos
invertem a ordem). A rotação vira S·R·S, com S a troca de Y e Z.
"""
import json
import math
import re
from pathlib import Path

PROTO = Path(__file__).resolve().parents[1]
REPO = PROTO.parent
EXPORT = PROTO / 'build/unreal-export'
DATA = PROTO / 'data/scenarios'
ART = PROTO / 'art/scenarios'
MAPS = ['RiverDock', 'RootBridge', 'SealedShelter', 'TriageGate', 'FloodedDepot', 'SewerDucts']
# As portas dos interiores laterais (AHScenarioZones::SideDoors): X da porta na zona principal e a zona do interior.
SIDE_DOORS = {'RiverDock': [[1400.0, 2], [4300.0, 1]], 'FloodedDepot': [[350.0, 1], [700.0, 2], [1050.0, 3]]}
DISPLAY = {'RootBridge': 'Ponte das Raízes', 'RiverDock': 'Cais do Rio', 'FloodedDepot': 'Depósito Inundado',
           'SealedShelter': 'Abrigo Lacrado', 'SewerDucts': 'Dutos de Esgoto', 'TriageGate': 'Portão de Triagem'}
AREAS = {'RiverDock': ['Cais', 'Navio', 'Galpão'], 'FloodedDepot': ['Hall', 'Estoque', 'Manutenção', 'Arquivo'],
         'SealedShelter': ['Convivência', 'Arquivo', 'Sala técnica']}


def solid_collision(component: dict) -> bool:
    """A colisão do componente bloqueia (o export grava o enum como texto: "QUERY_AND_PHYSICS: 3>", "NO_COLLISION: 0>")."""
    text = str(component.get('collision', ''))
    return text != '' and 'NO_COLLISION' not in text and 'NoCollision' not in text and 'QUERY_ONLY' not in text


def godot_point(v):
    return [v[0] / 100.0, v[2] / 100.0, v[1] / 100.0]


def quat_matrix(q):
    x, y, z, w = q
    return [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]


def godot_basis(rotation, scale):
    """S·R·D·S como lista das colunas (x, y, z) da base da Godot."""
    r = quat_matrix(rotation)
    m = [[r[i][j] * scale[j] for j in range(3)] for i in range(3)]
    swap = [0, 2, 1]
    g = [[m[swap[i]][swap[j]] for j in range(3)] for i in range(3)]
    return [round(g[i][j], 6) for j in range(3) for i in range(3)]


def world_box(component, mesh):
    """Caixa no mundo (cm, Unreal) da malha transformada, como Mesh->Bounds.GetBox()."""
    r = quat_matrix(component['rotation'])
    s = component['scale']
    t = component['location']
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    for cx in (mesh['min'][0], mesh['max'][0]):
        for cy in (mesh['min'][1], mesh['max'][1]):
            for cz in (mesh['min'][2], mesh['max'][2]):
                p = [cx * s[0], cy * s[1], cz * s[2]]
                w = [sum(r[i][j] * p[j] for j in range(3)) + t[i] for i in range(3)]
                lo = [min(lo[i], w[i]) for i in range(3)]
                hi = [max(hi[i], w[i]) for i in range(3)]
    return lo, hi


# ---------------------------------------------------------------- malhas

def convert_meshes(raw):
    out = {}
    for path, mesh in raw.items():
        sections = []
        for section in mesh['sections']:
            v = section['vertices']
            n = section['normals']
            tris = section['triangles']
            sections.append({
                'vertices': [round(c, 5) for i in range(0, len(v), 3) for c in (v[i] / 100.0, v[i + 2] / 100.0, v[i + 1] / 100.0)],
                'normals': [round(c, 4) for i in range(0, len(n), 3) for c in (n[i], n[i + 2], n[i + 1])],
                'uvs': section['uvs'],
                # O espelho dos eixos inverte a ordem dos triângulos.
                'triangles': [i for k in range(0, len(tris), 3) for i in (tris[k], tris[k + 2], tris[k + 1])],
            })
        out[path] = {'sections': sections}
    return out


# ---------------------------------------------------------------- texturas

texture_files = {}


def texture(info, kind='color'):
    if not info or not info.get('file'):
        return ''
    path = info['path']
    if path in texture_files:
        return texture_files[path]
    from PIL import Image, ImageOps
    src = EXPORT / info['file']
    name = path.split('/')[-1]
    dst = ART / (name + '.webp')
    dst.parent.mkdir(parents=True, exist_ok=True)
    if not dst.exists() or dst.stat().st_mtime < src.stat().st_mtime:
        image = Image.open(src)
        has_alpha = image.mode in ('RGBA', 'LA') or (image.mode == 'P' and 'transparency' in image.info)
        image = image.convert('RGBA' if has_alpha else 'RGB')
        # Fundos e panorâmicas guardam mais detalhe; o resto vai a 1024 no lado maior.
        limit = 2048 if any(k in name.lower() for k in ('panorama', 'sky', 'island', 'ocean', 'backdrop', 'skyline', 'city')) else 1024
        if max(image.size) > limit:
            scale = limit / max(image.size)
            image = image.resize((max(1, round(image.width * scale)), max(1, round(image.height * scale))), Image.LANCZOS)
        if kind == 'normal' and name.lower().endswith(('_normal', '_n')):
            r, g, b = image.convert('RGB').split()
            image = Image.merge('RGB', (r, ImageOps.invert(g), b))
        image.save(dst, 'WEBP', quality=88, method=4)
    texture_files[path] = 'res://art/scenarios/' + name + '.webp'
    return texture_files[path]


# ---------------------------------------------------------------- materiais

def material_kind(material):
    base = material['base'].split('/')[-1]
    if base == 'M_AHBlockout':
        return 'blockout'
    if base == 'M_ShelterSurface':
        return 'surface'
    if base == 'M_ShelterProp':
        return 'prop'
    if base == 'M_DressingCard':
        return 'card'
    if base == 'M_DressingFacade':
        return 'facade'
    if base == 'M_AHWaterWaves':
        return 'water'
    if base == 'M_StationGlow':
        return 'glow'
    if base.startswith('M_DockClimate') or material.get('shading', '').startswith('MSM_UNLIT'):
        return 'unlit'
    if base in ('WorldGridMaterial', 'DefaultMaterial'):
        return 'grid'
    return 'art'


def convert_material(material):
    if not material:
        return {'kind': 'grid'}
    kind = material_kind(material)
    p = material['params']
    out = {'kind': kind, 'two_sided': material.get('two_sided', False),
           'masked': 'MASKED' in material.get('blend', '') or 'TRANSLUCENT' in material.get('blend', '')}
    tex = p['texture']
    if kind == 'blockout':
        out.update(albedo=texture(tex.get('Albedo')), color=p['vector'].get('Color', [1, 1, 1, 1]), tile=p['scalar'].get('TileSize', 100.0),
                   roughness=p['scalar'].get('Roughness', 0.8))
    elif kind in ('surface', 'prop'):
        out.update(albedo=texture(tex.get('BaseColorTex')), normal=texture(tex.get('NormalTex'), 'normal'),
                   tint=p['vector'].get('Tint', [1, 1, 1, 1]), tile=p['scalar'].get('TileSize', 200.0),
                   desaturation=p['scalar'].get('Desaturation', 0.0), damp=p['scalar'].get('DampAmount', 0.0),
                   roughness=p['scalar'].get('RoughnessScale', 1.0))
    elif kind == 'card':
        out.update(albedo=texture(tex.get('Albedo')), emissive=p['scalar'].get('Emissive', 0.5), haze=p['scalar'].get('Haze', 0.0),
                   haze_color=p['vector'].get('HazeColor', [0.55, 0.52, 0.48, 1]), rect=p['vector'].get('Rect', [0, 0, 1, 1]))
    elif kind == 'facade':
        out.update(albedo=texture(tex.get('Albedo')), rect=p['vector'].get('Rect', [0, 0, 1, 1]))
    elif kind == 'water':
        out.update({k: p['scalar'].get(k) for k in ('Amplitude', 'Wavelength', 'Speed', 'Foam', 'Roughness', 'Opacity', 'RippleStrength', 'Specular')})
        out.update(tint=p['vector'].get('WaterTint'), foam_tint=p['vector'].get('FoamTint'))
    elif kind == 'glow':
        out.update(tint=p['vector'].get('Tint', [1, 0.62, 0.22, 1]))
    elif kind == 'unlit':
        out.update(albedo=texture(tex.get('Albedo')), gain=p['scalar'].get('WeatherGain', 1.0),
                   sky='Sky' in material['base'])
    elif kind == 'art':
        out.update(albedo=texture(tex.get('Albedo')))
    return out


# ---------------------------------------------------------------- mapas

def interactive_names():
    """Os nomes e o saque com acento certo, da ferramenta que criou os props (as tags na Unreal saíram sem acento)."""
    text = (REPO / 'Tools/Unreal/Scenarios/interactives.py').read_text(encoding='utf-8')
    names = {}
    for code, name, loot in re.findall(r"\('([A-Z]{2}X\d\d)_[A-Za-z_]+', '([^']+)', '([^']+)'", text):
        names[code] = (name, loot)
    return names


def convert_map(name, raw_meshes, mesh_ids, names):
    scene = json.loads((EXPORT / name / 'scene.json').read_text(encoding='utf-8'))
    materials = {}
    parts, lights, texts, floors, props = [], [], [], [], []

    def material_id(material):
        key = material['path'] if material else ''
        if key not in materials:
            materials[key] = convert_material(material)
        return list(materials).index(key)

    for actor in scene['actors']:
        tags = actor['tags']
        front_shell = any(t.startswith('AHScenario:') and t.endswith('_front_shell') for t in tags)
        floor_tag = any(t.startswith('AHScenario:') and (t.endswith('_floor') or ':deck_' in t or t.endswith(':walkway') or t.endswith(':ground')) for t in tags)
        interactive = 'AHInteractive' in tags
        first_part = len(parts)
        for c in actor['components']:
            kind = c['type']
            if kind in ('mesh', 'instances'):
                mesh = raw_meshes[c['mesh']]
                mats = [material_id(m) for m in c['materials']] or [material_id(None)]
                instances = c['instances'] if kind == 'instances' else [c]
                for inst in instances:
                    entry = {'mesh': mesh_ids[c['mesh']], 'materials': mats, 'origin': [round(v, 4) for v in godot_point(inst['location'])],
                             'basis': godot_basis(inst['rotation'], inst['scale'])}
                    visible = c['visible'] and not front_shell
                    if not visible:
                        entry['hidden'] = True
                    if not c.get('shadow', True):
                        entry['no_shadow'] = True
                    if solid_collision(c):
                        entry['solid'] = True
                    parts.append(entry)
                if floor_tag and kind == 'mesh' and solid_collision(c):
                    lo, hi = world_box(c, raw_meshes[c['mesh']])
                    if hi[0] - lo[0] >= 600 and hi[1] - lo[1] >= 380 and hi[2] - lo[2] <= 100:
                        floors.append([lo, hi])
            elif kind == 'PointLightComponent':
                lights.append({'type': 'point', 'origin': godot_point(c['location']), 'lumens': c['intensity'], 'color': c['color'],
                               'radius': c.get('attenuation_radius', 1000.0) / 100.0, 'shadows': c['shadows'], 'visible': c['visible']})
            elif kind == 'DirectionalLightComponent':
                lights.append({'type': 'sun', 'basis': godot_basis(c['rotation'], [1, 1, 1]), 'lux': c['intensity'], 'color': c['color'],
                               'shadows': c['shadows']})
            elif kind == 'text':
                texts.append({'text': c['text'], 'size': c['size'] / 100.0, 'color': c['color'], 'origin': godot_point(c['location']),
                              'basis': godot_basis(c['rotation'], [1, 1, 1])})
        if interactive and len(parts) > first_part:
            code = next((m.group(1) for t in tags for m in [re.search(r'([A-Z]{2}X\d\d)', t)] if m), '')
            x = next((float(t.split(':', 1)[1]) for t in tags if t.startswith('AHInteractiveX:')), 0.0)
            name_loot = names.get(code, ('Objeto', ''))
            props.append({'code': code, 'name': name_loot[0], 'loot': name_loot[1], 'x': x / 100.0,
                          'parts': list(range(first_part, len(parts))),
                          'open': material_id(actor['open_material']) if actor.get('open_material') else -1})
    # Zonas: os pisos juntos quando se encostam na mesma altura, em X (AHScenarioZones::Find).
    floors.sort(key=lambda b: b[0][0])
    merged = []
    for lo, hi in floors:
        if merged and lo[0] <= merged[-1][1][0] + 2 and abs(hi[2] - merged[-1][1][2]) < 2:
            merged[-1] = [[min(a, b) for a, b in zip(merged[-1][0], lo)], [max(a, b) for a, b in zip(merged[-1][1], hi)]]
        else:
            merged.append([lo, hi])
    zones = [{'x0': lo[0] / 100.0, 'x1': hi[0] / 100.0, 'z0': lo[1] / 100.0,
              'z1': hi[1] / 100.0, 'y': hi[2] / 100.0, 'name': (AREAS.get(name, []) + ['passagem'] * 9)[i] if name in AREAS else 'passagem'}
             for i, (lo, hi) in enumerate(merged)]
    out = {'map': name, 'display': DISPLAY[name], 'materials': list(materials.values()), 'parts': parts, 'lights': lights,
           'texts': texts, 'zones': zones, 'side_doors': [{'x': d[0] / 100.0, 'zone': d[1]} for d in SIDE_DOORS.get(name, [])],
           'props': sorted(props, key=lambda p: p['x'])}
    (DATA / (name + '.json')).write_text(json.dumps(out, ensure_ascii=False, separators=(',', ':')), encoding='utf-8')
    return out


def main():
    raw = json.loads((EXPORT / 'meshes.json').read_text(encoding='utf-8'))
    DATA.mkdir(parents=True, exist_ok=True)
    mesh_ids = {path: index for index, path in enumerate(raw)}
    converted = convert_meshes(raw)
    (DATA / 'meshes.json').write_text(json.dumps({'meshes': [converted[p] for p in raw], 'names': list(raw)}, separators=(',', ':')),
                                      encoding='utf-8')
    names = interactive_names()
    for name in MAPS:
        out = convert_map(name, raw, mesh_ids, names)
        print(f"{name}: {len(out['parts'])} peças, {len(out['lights'])} luzes, {len(out['zones'])} zonas "
              f"({', '.join('%.1f-%.1f' % (z['x0'], z['x1']) for z in out['zones'])}), {len(out['props'])} props, "
              f"{len(out['materials'])} materiais")
    print(f'texturas: {len(texture_files)}')


if __name__ == '__main__':
    main()
