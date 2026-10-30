"""Monta um contrato proposto num destino explícito; nunca altera produção implicitamente."""
import argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];HERE=Path(__file__).resolve().parent
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--out',required=True,type=Path);a=p.parse_args()
 if a.out.resolve()==(ROOT/'docs/design/camp/contract.json').resolve():raise SystemExit('Use um arquivo temporário e aplique junto do manifesto na integração.')
 c=json.loads((ROOT/'docs/design/camp/contract.json').read_text());proposal=json.loads((HERE/'contract.json').read_text());keys={(v['recruit_id'],v['state']) for v in proposal['poses']};c['poses']=[v for v in c['poses'] if (v.get('recruit_id'),v.get('state')) not in keys]+proposal['poses'];a.out.write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n');print(f'Proposta: {len(c["poses"])} entradas em {a.out}; produção intacta.')
