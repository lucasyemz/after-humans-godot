"""Stage the seven #221 poses, optionally with the two reused #225 recruit idles.

Requires Pillow. Never edits PNG sources, production files or an existing package.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PureWindowsPath
import tempfile

from PIL import Image

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
ACTORS = {'bento', 'nick', 'iris', 'vespera', 'raccoon', 'armadillo', 'watch'}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inside(path: Path, root: Path) -> bool:
    return path == root or root in path.parents


def source_path(root: Path, value: str) -> Path:
    if not isinstance(value, str) or not value or '\\' in value:
        raise ValueError(f'Invalid source path: {value!r}')
    p = Path(value)
    if p.is_absolute() or PureWindowsPath(value).drive or '..' in p.parts:
        raise ValueError(f'Source path must be relative: {value}')
    path = (root / p).resolve()
    if not inside(path, root):
        raise ValueError(f'Source path escapes source folder: {value}')
    return path


def validate(path: Path, expected_hash: str, meta: dict) -> None:
    if not path.is_file() or sha(path) != expected_hash:
        raise ValueError(f'Missing source or SHA256 mismatch: {path.name}')
    with Image.open(path) as im:
        if im.format != 'PNG' or im.mode != 'RGBA' or list(im.size) != meta['canvas']:
            raise ValueError(f'Invalid PNG mode or canvas: {path.name}')
        bounds = im.getbbox()
        if bounds is None or abs(bounds[3] - meta['anchor'][1]) > 1:
            raise ValueError(f'Unexpected foot contact: {path.name}')
    if meta['body_reference_pixels'] <= 0:
        raise ValueError('Invalid body reference.')


def prepare(sources: Path, output: Path, redraw_sources: Path | None = None,
            manifest: Path = HERE / 'contract.json', audit_path: Path = HERE / 'audit.json') -> dict:
    sources, output = sources.resolve(), output.resolve()
    roots = [sources]
    if redraw_sources is not None:
        redraw_sources = redraw_sources.resolve()
        roots.append(redraw_sources)
    if not all(p.is_dir() for p in roots):
        raise ValueError('Every source folder must exist.')
    if inside(output, REPO) or any(inside(output, p) or inside(p, output) for p in roots):
        raise ValueError('Output must be outside the repository and source trees.')
    if output.exists():
        raise ValueError('Output already exists; nothing was overwritten.')
    contract = json.loads(manifest.read_text(encoding='utf-8'))
    audit = json.loads(audit_path.read_text(encoding='utf-8'))
    if contract.get('issue') != 221 or set(contract.get('actors', {})) != ACTORS:
        raise ValueError('Expected the seven-actor #221 contract.')
    jobs = []
    for actor, row in contract['actors'].items():
        mode = 'idle' if actor == 'armadillo' else 'combat_idle'
        if row.get('new_pose') != mode:
            raise ValueError(f'Unexpected pose for {actor}.')
        state = 'exploration' if mode == 'idle' else 'combat'
        meta = row['states'][state]
        relative = meta['source_file']
        path = source_path(sources, relative)
        if relative != f'{actor}/{mode}.png':
            raise ValueError('Unexpected source filename.')
        checked = audit['assets'][relative]
        if checked['canvas'] != meta['canvas'] or checked['anchor'] != meta['anchor']:
            raise ValueError('Contract and audited registration disagree.')
        validate(path, checked['sha256'], meta)
        jobs.append((actor, mode, path, meta, contract['source_tag']))
    if redraw_sources is not None:
        redraw = json.loads((HERE.parent / 'recruits_redraw/contract.json').read_text(encoding='utf-8'))
        for actor, mode in [('raccoon', 'idle'), ('armadillo', 'combat_idle')]:
            meta = redraw['actors'][actor]['assets']['idle']
            path = source_path(redraw_sources, meta['source_file'])
            validate(path, meta['source_sha256'], meta)
            baseline = contract['actors'][actor]['baseline']
            if any(meta[k] != baseline[k] for k in ('canvas', 'anchor', 'body_reference_pixels')):
                raise ValueError('Recruit dependency registration disagrees with #221.')
            jobs.append((actor, mode, path, meta, redraw['source_tag']))
    report = {
        'issue': 221, 'note': 'Staging only; canonical source units retained. No game file changed.',
        'files': len(jobs), 'recruit_baselines_included': redraw_sources is not None,
        'source_manifest_sha256': sha(manifest), 'source_audit_sha256': sha(audit_path),
        'dependencies': contract['dependency'],
        'reused_main_exploration': {
            actor: row['baseline']['file'] for actor, row in contract['actors'].items()
            if actor not in ('raccoon', 'armadillo')},
        'assets': {},
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='stances221-', dir=output.parent) as tmp:
        package = Path(tmp) / 'package'
        package.mkdir()
        for actor, mode, path, meta, tag in jobs:
            size = tuple(round(v * .5) for v in meta['canvas'])
            target = package / actor / (mode + '.webp')
            target.parent.mkdir(exist_ok=True)
            with Image.open(path) as im:
                im.resize(size, Image.Resampling.LANCZOS).save(target, lossless=True, method=6)
            with Image.open(target) as im:
                if im.mode != 'RGBA' or im.size != size:
                    raise ValueError(f'Invalid conversion: {actor}/{mode}')
            report['assets'][f'{actor}/{mode}'] = {
                'file': f'{actor}/{mode}.webp', 'canvas': meta['canvas'],
                'texture_canvas': list(size), 'anchor': meta['anchor'],
                'body_reference_pixels': meta['body_reference_pixels'],
                'source_tag': tag, 'source_sha256': sha(path), 'sha256': sha(target),
                'actor_id': contract['actors'][actor]['id'],
                'skin_id': contract['actors'][actor].get('skin_id'),
                'suggested_destination': (f'art/skins/bento/watch/{mode}.webp' if actor == 'watch'
                    else f'art/combat/heroes/{actor}/{mode}.webp' if actor not in ('raccoon', 'armadillo')
                    else f'art/combat/recruits/{contract["actors"][actor]["id"]}/{mode}.webp'),
            }
        (package / 'registration.json').write_text(
            json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
        if output.exists():
            raise ValueError('Output appeared during conversion; nothing was overwritten.')
        os.rename(package, output)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sources', required=True, type=Path, help='Extracted stances_20261028 folder.')
    parser.add_argument('--output', required=True, type=Path, help='New directory outside the repository and sources.')
    parser.add_argument('--redraw-sources', type=Path, help='Optional recruits_redraw_20261028 folder from #229.')
    args = parser.parse_args()
    try:
        report = prepare(args.sources, args.output, args.redraw_sources)
    except (ValueError, KeyError, TypeError, OSError) as error:
        parser.exit(2, f'Cannot prepare pose package: {error}\n')
    print(f'Prepared {report["files"]} verified WebP files in {args.output.resolve()}')


if __name__ == '__main__':
    main()
