"""Confere integridade das pranchas aprovadas; executar da raiz do repositório."""
import sys,json,hashlib
sys.dont_write_bytecode=True
from pathlib import Path
from PIL import Image
HERE=Path(__file__).resolve().parent
checks=json.loads((HERE/'checks.json').read_text())
rows=json.loads((HERE/'counts.json').read_text())
assert len({(r['page'],r['profile']) for r in rows})==216
for name,expected in checks['png_sha256'].items():
 p=HERE/name
 assert hashlib.sha256(p.read_bytes()).hexdigest()==expected,p
 with Image.open(p) as im:assert im.size==(1920,1080),p
assert not checks['issues'] and not checks['missing_font_glyphs']
print('216 PNG1920x1080: hashes e perfis conferidos; relatório de QA sem problemas pendentes.')
