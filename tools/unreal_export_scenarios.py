"""Exporta os mapas de cenário da referência Unreal para a Godot (só leitura: não salva nada na Unreal).

Roda dentro do editor da Unreal, sem interface, com o editor fechado:
  UnrealEditor-Cmd.exe <repo>/AfterHumans.uproject -run=pythonscript -script="<repo>/Godot/tools/unreal_export_scenarios.py" -unattended -nosplash -nullrhi

Para cada mapa grava Godot/build/unreal-export/<Mapa>/scene.json com cada componente visível: o tipo (malha, luz, texto),
a transformação no mundo (cm, eixos da Unreal), as tags do ator, a malha, os materiais (pai, parâmetros e as texturas
com o arquivo de origem) e as luzes. As malhas que não são as formas básicas da engine saem em FBX ao lado. Depois,
tools/sync_scenarios.py converte isso para data/ e art/ da Godot.
"""
import json
from pathlib import Path
import unreal

ROOT = Path(unreal.Paths.project_dir()).resolve()
OUT = ROOT / 'Godot/build/unreal-export'
MAPS = ['RiverDock', 'RootBridge', 'SealedShelter', 'TriageGate', 'FloodedDepot', 'SewerDucts']
BASIC = {'/Engine/BasicShapes/Cube', '/Engine/BasicShapes/Plane', '/Engine/BasicShapes/Cylinder', '/Engine/BasicShapes/Sphere',
         '/Engine/BasicShapes/Cone', '/Engine/EngineMeshes/Cube', '/Engine/EditorMeshes/EditorCube'}
MEL = unreal.MaterialEditingLibrary
exported_meshes = {}
material_cache = {}


def vec(v):
    return [round(v.x, 3), round(v.y, 3), round(v.z, 3)]


def color(c):
    # FColor (0-255) ou FLinearColor (0-1).
    if hasattr(c, 'r') and isinstance(c.r, int):
        return [round(c.r / 255.0, 4), round(c.g / 255.0, 4), round(c.b / 255.0, 4)]
    return [round(c.r, 4), round(c.g, 4), round(c.b, 4)]


def transform(component):
    t = component.get_world_transform()
    q = t.rotation
    return {'location': vec(t.translation), 'rotation': [round(q.x, 6), round(q.y, 6), round(q.z, 6), round(q.w, 6)],
            'scale': vec(t.scale3d)}


def source_file(texture):
    try:
        data = texture.get_editor_property('asset_import_data')
        if data:
            name = data.get_first_filename()
            if name:
                return name
    except Exception:
        pass
    return ''


exported_textures = {}


def texture_info(texture):
    """A textura e o arquivo dela exportado em PNG (a imagem de origem guardada no .uasset)."""
    if not texture:
        return None
    path = texture.get_path_name().split('.')[0]
    if path not in exported_textures:
        target = OUT / 'textures' / (path.replace('/Game/', '').replace('/Engine/', 'Engine/') + '.png')
        target.parent.mkdir(parents=True, exist_ok=True)
        ok = False
        if isinstance(texture, unreal.Texture2D):
            task = unreal.AssetExportTask()
            task.object = texture
            task.filename = str(target)
            task.automated = True
            task.prompt = False
            task.replace_identical = True
            ok = unreal.Exporter.run_asset_export_task(task)
        exported_textures[path] = target.relative_to(OUT).as_posix() if ok else ''
    return {'path': path, 'file': exported_textures[path], 'source': source_file(texture),
            'size': [texture.blueprint_get_size_x(), texture.blueprint_get_size_y()],
            'srgb': bool(texture.get_editor_property('srgb')) if isinstance(texture, unreal.Texture2D) else True}


def material_info(material):
    if not material:
        return None
    key = material.get_path_name()
    if key in material_cache:
        return material_cache[key]
    info = {'path': key.split('.')[0], 'class': material.get_class().get_name()}
    base = material
    chain = []
    params = {'scalar': {}, 'vector': {}, 'texture': {}}
    while isinstance(base, unreal.MaterialInstance):
        chain.append(base.get_path_name().split('.')[0])
        for value in base.get_editor_property('scalar_parameter_values') or []:
            name = str(value.parameter_info.name)
            params['scalar'].setdefault(name, round(value.parameter_value, 5))
        for value in base.get_editor_property('vector_parameter_values') or []:
            name = str(value.parameter_info.name)
            c = value.parameter_value
            params['vector'].setdefault(name, [round(c.r, 5), round(c.g, 5), round(c.b, 5), round(c.a, 5)])
        for value in base.get_editor_property('texture_parameter_values') or []:
            name = str(value.parameter_info.name)
            if name not in params['texture']:
                params['texture'][name] = texture_info(value.parameter_value)
        base = base.get_editor_property('parent')
    info['chain'] = chain
    info['base'] = base.get_path_name().split('.')[0] if base else ''
    info['params'] = params
    if base:
        try:
            info['blend'] = str(base.get_editor_property('blend_mode')).split('.')[-1]
            info['two_sided'] = bool(base.get_editor_property('two_sided'))
            info['shading'] = str(base.get_editor_property('shading_model')).split('.')[-1]
        except Exception:
            pass
        # Defaults of the base material for the parameters the instances did not override.
        for name in MEL.get_scalar_parameter_names(base) or []:
            params['scalar'].setdefault(str(name), round(MEL.get_material_default_scalar_parameter_value(base, name), 5))
        for name in MEL.get_vector_parameter_names(base) or []:
            c = MEL.get_material_default_vector_parameter_value(base, name)
            params['vector'].setdefault(str(name), [round(c.r, 5), round(c.g, 5), round(c.b, 5), round(c.a, 5)])
        for name in MEL.get_texture_parameter_names(base) or []:
            if str(name) not in params['texture']:
                params['texture'][str(name)] = texture_info(MEL.get_material_default_texture_parameter_value(base, name))
        try:
            info['used_textures'] = [texture_info(t) for t in MEL.get_used_textures(material) or []]
        except Exception:
            info['used_textures'] = []
    material_cache[key] = info
    return info


def export_mesh(mesh, folder):
    """A malha como a Unreal a desenha: vértices (cm), normais, UV e triângulos de cada seção (um material por seção),
    pela ProceduralMeshLibrary. A Godot monta a ArrayMesh igual, sem passar por FBX."""
    path = mesh.get_path_name().split('.')[0]
    if path in exported_meshes:
        return path
    sections = []
    for index in range(mesh.get_num_sections(0)):
        result = unreal.ProceduralMeshLibrary.get_section_from_static_mesh(mesh, 0, index)
        vertices, triangles, normals, uvs = result[0], result[1], result[2], result[3]
        sections.append({'vertices': [round(c, 3) for v in vertices for c in (v.x, v.y, v.z)],
                         'normals': [round(c, 4) for n in normals for c in (n.x, n.y, n.z)],
                         'uvs': [round(c, 5) for uv in uvs for c in (uv.x, uv.y)], 'triangles': list(triangles)})
    bounds = mesh.get_bounding_box()
    exported_meshes[path] = {'min': vec(bounds.min), 'max': vec(bounds.max), 'sections': sections,
                             'materials': [material_info(m.material_interface) for m in mesh.get_editor_property('static_materials')]}
    return path


def components(actor):
    out = []
    tags = [str(t) for t in actor.tags]
    hidden_game = bool(actor.get_editor_property('hidden'))
    for component in actor.get_components_by_class(unreal.SceneComponent):
        entry = None
        visible = component.is_visible() and not hidden_game and not component.get_editor_property('hidden_in_game')
        if isinstance(component, unreal.InstancedStaticMeshComponent):
            mesh = component.get_editor_property('static_mesh')
            if not mesh:
                continue
            instances = []
            for index in range(component.get_instance_count()):
                t = component.get_instance_transform(index, True)
                q = t.rotation
                instances.append({'location': vec(t.translation), 'rotation': [q.x, q.y, q.z, q.w], 'scale': vec(t.scale3d)})
            entry = {'type': 'instances', 'mesh': export_mesh(mesh, actor), 'instances': instances,
                     'materials': [material_info(component.get_material(i)) for i in range(component.get_num_materials())]}
        elif isinstance(component, unreal.StaticMeshComponent):
            mesh = component.get_editor_property('static_mesh')
            if not mesh:
                continue
            entry = {'type': 'mesh', 'mesh': export_mesh(mesh, actor),
                     'materials': [material_info(component.get_material(i)) for i in range(component.get_num_materials())]}
        elif isinstance(component, unreal.LightComponent):
            entry = {'type': component.get_class().get_name(), 'intensity': component.get_editor_property('intensity'),
                     'color': color(component.get_editor_property('light_color')),
                     'shadows': bool(component.get_editor_property('cast_shadows'))}
            for prop in ['attenuation_radius', 'source_radius', 'outer_cone_angle', 'inner_cone_angle', 'source_width', 'source_height']:
                try:
                    entry[prop] = component.get_editor_property(prop)
                except Exception:
                    pass
            try:
                entry['units'] = str(component.get_editor_property('intensity_units')).split('.')[-1]
            except Exception:
                pass
        elif isinstance(component, unreal.TextRenderComponent):
            entry = {'type': 'text', 'text': str(component.get_editor_property('text')), 'size': component.get_editor_property('world_size'),
                     'color': color(component.get_editor_property('text_render_color'))}
        elif isinstance(component, unreal.BoxComponent):
            entry = {'type': 'box', 'extent': vec(component.get_editor_property('box_extent')),
                     'collision': str(component.get_collision_enabled()).split('.')[-1]}
        if entry is None:
            continue
        entry.update(transform(component))
        entry['visible'] = visible
        entry['shadow'] = bool(getattr(component, 'cast_shadow', True)) if hasattr(component, 'cast_shadow') else True
        try:
            entry['collision'] = entry.get('collision') or str(component.get_collision_enabled()).split('.')[-1]
        except Exception:
            pass
        entry['component_tags'] = [str(t) for t in component.component_tags]
        out.append(entry)
    entry = {'name': actor.get_actor_label(), 'class': actor.get_class().get_name(), 'tags': tags, 'components': out}
    # Prop vasculhável: o material da versão aberta (troca depois da busca), com a textura dele.
    for tag in tags:
        if tag.startswith('AHInteractiveOpen:'):
            material = unreal.load_asset(tag[len('AHInteractiveOpen:'):])
            entry['open_material'] = material_info(material)
    return entry


OUT.mkdir(parents=True, exist_ok=True)
for map_name in MAPS:
    unreal.EditorLoadingAndSavingUtils.load_map('/Game/AfterHumans/Maps/L_' + map_name)
    actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors()
    scene = {'map': map_name, 'actors': []}
    for actor in actors:
        try:
            entry = components(actor)
        except Exception as error:
            unreal.log_warning('export %s: %s' % (actor.get_name(), error))
            continue
        if entry['components'] or entry['tags']:
            scene['actors'].append(entry)
    folder = OUT / map_name
    folder.mkdir(parents=True, exist_ok=True)
    (folder / 'scene.json').write_text(json.dumps(scene, ensure_ascii=False, indent=1), encoding='utf-8')
    unreal.log('AHExport %s: %d atores' % (map_name, len(scene['actors'])))
(OUT / 'meshes.json').write_text(json.dumps(exported_meshes, ensure_ascii=False, indent=1), encoding='utf-8')
unreal.log('AHExport malhas: %d' % len(exported_meshes))
