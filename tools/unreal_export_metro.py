"""Exporta o metrô Bombardier da Estação (o corpo e as quatro folhas de porta) da referência Unreal para a Godot (só
leitura: não salva nada na Unreal).

Roda dentro do editor da Unreal, sem interface, com o editor fechado:
  UnrealEditor-Cmd.exe <repo>/AfterHumans.uproject -run=pythonscript -script="<repo>/Godot/tools/unreal_export_metro.py" -unattended -nosplash -nullrhi

Grava em Godot/build/unreal-export/metro/: cada malha em .glb (o corpo no LOD2 da Unreal, 65 mil triângulos, leve para
o celular e o repositório; as portas no LOD0) e metro.json com os triângulos de cada LOD, os limites e os materiais de
cada seção (a cor e as texturas: a Godot monta os materiais com as texturas que já tem).
Modelo: Bombardier S Stock, de timblewee, CC BY 4.0 (créditos em Docs/Scenarios/RootStation/metro-door-animation.md).
"""
import json
from pathlib import Path
import unreal

ROOT = Path(unreal.Paths.project_dir()).resolve()
OUT = ROOT / 'Godot/build/unreal-export/metro'
FOLDER = '/Game/AfterHumans/Environments/RootStation/Terminal/'
## O LOD exportado de cada peça (o corpo tem 260 mil triângulos no LOD0).
LOD = {'SM_BombardierBody': 2}
PIECES = ['SM_BombardierBody', 'SM_BombardierPlatformLeft', 'SM_BombardierPlatformRight', 'SM_BombardierFrontLeft',
          'SM_BombardierFrontRight']
MEL = unreal.MaterialEditingLibrary


def export_texture(texture):
    if not isinstance(texture, unreal.Texture2D):
        return ''
    name = texture.get_name() + '.png'
    task = unreal.AssetExportTask()
    task.object = texture
    task.filename = str(OUT / 'textures' / name)
    task.automated = True
    task.prompt = False
    task.replace_identical = True
    return 'textures/' + name if unreal.Exporter.run_asset_export_task(task) else ''


def material_info(material):
    info = {'path': material.get_path_name().split('.')[0] if material else '', 'vector': {}, 'scalar': {}, 'texture': {}}
    if not material:
        return info
    base = material
    while isinstance(base, unreal.MaterialInstance):
        for value in base.get_editor_property('scalar_parameter_values') or []:
            info['scalar'].setdefault(str(value.parameter_info.name), round(value.parameter_value, 5))
        for value in base.get_editor_property('vector_parameter_values') or []:
            c = value.parameter_value
            info['vector'].setdefault(str(value.parameter_info.name), [round(c.r, 5), round(c.g, 5), round(c.b, 5), round(c.a, 5)])
        for value in base.get_editor_property('texture_parameter_values') or []:
            info['texture'].setdefault(str(value.parameter_info.name), export_texture(value.parameter_value))
        base = base.get_editor_property('parent')
    if base:
        info['base'] = base.get_path_name().split('.')[0]
        try:
            info['blend'] = str(base.get_editor_property('blend_mode')).split('.')[-1]
        except Exception:
            pass
        for name in MEL.get_texture_parameter_names(base) or []:
            info['texture'].setdefault(str(name), export_texture(MEL.get_material_default_texture_parameter_value(base, name)))
        for name in MEL.get_vector_parameter_names(base) or []:
            c = MEL.get_material_default_vector_parameter_value(base, name)
            info['vector'].setdefault(str(name), [round(c.r, 5), round(c.g, 5), round(c.b, 5), round(c.a, 5)])
        for name in MEL.get_scalar_parameter_names(base) or []:
            info['scalar'].setdefault(str(name), round(MEL.get_material_default_scalar_parameter_value(base, name), 5))
        try:
            info['used_textures'] = [export_texture(t) for t in MEL.get_used_textures(material) or []]
        except Exception:
            info['used_textures'] = []
    return info


OUT.mkdir(parents=True, exist_ok=True)
summary = {'pieces': {}}
for name in PIECES:
    mesh = unreal.load_asset(FOLDER + name)
    if not mesh:
        unreal.log_warning('AHMetro: falta %s' % name)
        continue
    task = unreal.AssetExportTask()
    task.object = mesh
    task.filename = str(OUT / (name + '.glb'))
    task.automated = True
    task.prompt = False
    task.replace_identical = True
    options = unreal.GLTFExportOptions()
    options.set_editor_property('default_level_of_detail', LOD.get(name, 0))
    options.set_editor_property('export_vertex_colors', False)
    task.options = options
    ok = unreal.Exporter.run_asset_export_task(task)
    bounds = mesh.get_bounding_box()
    summary['pieces'][name] = {
        'glb': (name + '.glb') if ok else '', 'lod': LOD.get(name, 0),
        'triangles': [mesh.get_num_triangles(lod) for lod in range(mesh.get_num_lods())],
        'min': [bounds.min.x, bounds.min.y, bounds.min.z], 'max': [bounds.max.x, bounds.max.y, bounds.max.z],
        'materials': [{'slot': str(m.material_slot_name), 'material': material_info(m.material_interface)}
                      for m in mesh.get_editor_property('static_materials')],
    }
    unreal.log('AHMetro %s: gltf=%s' % (name, ok))
(OUT / 'metro.json').write_text(json.dumps(summary, ensure_ascii=False, indent=1), encoding='utf-8')
unreal.log('AHMetro pronto: %d peças' % len(summary['pieces']))
