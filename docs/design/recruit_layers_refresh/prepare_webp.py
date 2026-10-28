"""Prepare the #239 approved layer sources in an external staging directory.

Requires Pillow. Reads PNG files; never edits source art or the game repository.
The emitted registration keeps the original canonical units used by sprite_card.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PureWindowsPath
import tempfile

from PIL import Image

KEYS = {
    'base_a', 'base_b', 'clothes', 'scarf', 'bag', 'cap',
    'badge_protection', 'badge_healing', 'badge_ranged', 'badge_chemistry',
}
TINTABLE = {'clothes', 'scarf', 'cap'}
ACTORS = {'raccoon': ('rato', 'raccoon_recruit_01'),
          'armadillo': ('tatu', 'armadillo_recruit_01')}
REPO = Path(__file__).resolve().parents[3]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inside(path: Path, root: Path) -> bool:
    return path == root or root in path.parents


def source_path(root: Path, value: str) -> Path:
    if not isinstance(value, str) or not value or '\\' in value:
        raise ValueError(f'Invalid source path: {value!r}')
    relative = Path(value)
    if relative.is_absolute() or PureWindowsPath(value).drive or '..' in relative.parts:
        raise ValueError(f'Source path must be relative: {value}')
    path = (root / relative).resolve()
    if not inside(path, root):
        raise ValueError(f'Source path escapes source folder: {value}')
    return path


def grayscale(image: Image.Image) -> bool:
    r, g, b, _ = image.split()
    return r.tobytes() == g.tobytes() == b.tobytes()


def prepare(sources: Path, output: Path, manifest: Path) -> dict:
    sources, output = sources.resolve(), output.resolve()
    if not sources.is_dir():
        raise ValueError(f'Source folder does not exist: {sources}')
    if inside(output, REPO) or inside(output, sources) or inside(sources, output):
        raise ValueError('Output must be outside the game repository and source tree.')
    if output.exists():
        raise ValueError('Output already exists; choose a new directory. Nothing was overwritten.')
    contract = json.loads(manifest.read_text(encoding='utf-8'))
    if contract.get('issue') != 239 or set(contract.get('actors', {})) != set(ACTORS):
        raise ValueError('Expected the two-actor #239 contract.')
    jobs = []
    paths = set()
    for actor, (class_id, actor_id) in ACTORS.items():
        row = contract['actors'][actor]
        if row.get('class_id') != class_id or row.get('id') != actor_id:
            raise ValueError(f'Unexpected ids for {actor}.')
        if row.get('canvas') != [1178, 1335] or row.get('body_reference_pixels') != 1240:
            raise ValueError(f'Unexpected canonical registration for {actor}.')
        expected_anchor = [588.5, 1305] if actor == 'raccoon' else [589, 1305]
        if row.get('anchor') != expected_anchor or set(row.get('assets', {})) != KEYS:
            raise ValueError(f'Unexpected anchor or layers for {actor}.')
        for key, asset in row['assets'].items():
            path = source_path(sources, asset['source_file'])
            if path in paths or not path.is_file() or path.suffix.lower() != '.png':
                raise ValueError(f'Missing or duplicate source: {path}')
            paths.add(path)
            if sha(path) != asset['source_sha256']:
                raise ValueError(f'SHA256 mismatch: {asset["source_file"]}')
            with Image.open(path) as image:
                if image.format != 'PNG' or image.mode != 'RGBA' or image.size != (1178, 1335):
                    raise ValueError(f'Expected RGBA PNG1178x1335: {asset["source_file"]}')
                if key in TINTABLE and not grayscale(image):
                    raise ValueError(f'Tintable layer is not grayscale: {asset["source_file"]}')
                if key.startswith('base_') and image.getbbox()[3] != 1305:
                    raise ValueError(f'Unexpected body contact: {asset["source_file"]}')
            jobs.append((actor, key, path))
    report = {
        'issue': 239, 'source_tag': contract['source_tag'],
        'source_manifest_sha256': sha(manifest),
        'note': 'Staging only. Canonical registration retains source units. No game files updated.',
        'order': contract['order'], 'actors': {},
    }
    # All inputs validated before opening an output file. A failed conversion leaves no package.
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='layers239-', dir=output.parent) as tmp:
        package = Path(tmp) / 'package'
        package.mkdir()
        for actor, key, path in jobs:
            target = package / actor / (key + '.webp')
            target.parent.mkdir(exist_ok=True)
            with Image.open(path) as image:
                image.resize((589, 668), Image.Resampling.LANCZOS).save(target, lossless=True, method=6)
            with Image.open(target) as result:
                if result.mode != 'RGBA' or result.size != (589, 668):
                    raise ValueError(f'Invalid WebP conversion: {actor}/{key}')
                if key in TINTABLE and not grayscale(result):
                    raise ValueError(f'Grayscale changed in conversion: {actor}/{key}')
            row = contract['actors'][actor]
            registration = report['actors'].setdefault(actor, {
                'id': row['id'], 'class_id': row['class_id'],
                'canvas': row['canvas'], 'anchor': row['anchor'],
                'body_reference_pixels': row['body_reference_pixels'],
                'height_m': row['height_m'], 'texture_canvas': [589, 668], 'assets': {},
            })
            registration['assets'][key] = {
                'file': f'{actor}/{key}.webp', 'sha256': sha(target),
                'source_sha256': sha(path), 'tintable': key in TINTABLE,
            }
        report['files'] = len(jobs)
        (package / 'registration.json').write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        # Recheck immediately before publishing; never replace an existing package.
        if output.exists():
            raise ValueError('Output appeared during conversion; nothing was overwritten.')
        os.rename(package, output)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', required=True, type=Path, help='Extracted layer source folder containing raccoon/armadillo/.')
    parser.add_argument('--output', required=True, type=Path, help='New directory outside the repository and sources.')
    parser.add_argument('--manifest', type=Path, default=Path(__file__).with_name('contract.json'))
    args = parser.parse_args()
    try:
        report = prepare(args.sources, args.output, args.manifest)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(2, f'Cannot prepare layer package: {error}\n')
    print(f'Prepared {report["files"]} verified WebP files in {args.output.resolve()}')


if __name__ == '__main__':
    main()
