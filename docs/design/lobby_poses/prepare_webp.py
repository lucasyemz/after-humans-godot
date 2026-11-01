"""Valida fontes aprovadas e prepara 52 WebP fora do jogo, sem modificar produção."""
import argparse,hashlib,json,shutil,tempfile
from pathlib import Path
from PIL import Image

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--sources',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--contract',type=Path,default=Path(__file__).with_name('contract.json'));a=p.parse_args();repo=Path(__file__).resolve().parents[3];sources=a.sources.resolve();output=a.output.resolve()
 if output.exists():raise ValueError('A saída já existe; escolha pasta nova.')
 if output.is_relative_to(repo) or output.is_relative_to(sources):raise ValueError('A saída precisa ficar fora do repositório e das fontes.')
 c=json.loads(a.contract.read_text());assert len(c['actors'])==16,'Esperados 16 modelos';jobs=[]
 for actor,row in c['actors'].items():
  expected={'idle','seat','sleep','work'} if row['founder'] else {'idle','seat','sleep'}
  assert set(row['assets'])==expected,(actor,'cobertura incompleta')
  for state,asset in row['assets'].items():
   src=(sources/asset['source_file']).resolve();assert src.is_relative_to(sources),'Fonte fora da pasta';assert hashlib.sha256(src.read_bytes()).hexdigest()==asset['source_sha256'],str(src)
   with Image.open(src) as im:
    assert im.mode=='RGBA' and list(im.size)==asset['canvas'],str(src)
    assert im.getchannel('A').getextrema()==(0,255) or im.getchannel('A').getextrema()[0]==0,str(src)
    assert im.getchannel('A').getbbox(),str(src)
   dest=Path(asset['prototype_file']);assert not dest.is_absolute() and '..' not in dest.parts,'Destino inválido';jobs.append((src,dest,asset))
 assert len(jobs)==52,'Esperados 52 sprites'
 output.parent.mkdir(parents=True,exist_ok=True);tmp=Path(tempfile.mkdtemp(prefix='.lobby-webp-',dir=output.parent))
 try:
  for src,dest,asset in jobs:
   path=tmp/dest;path.parent.mkdir(parents=True,exist_ok=True)
   with Image.open(src) as im:im.resize(tuple(asset['texture_canvas']),Image.Resampling.LANCZOS).save(path,lossless=True,method=6)
  (tmp/'registration.json').write_text(json.dumps(c,ensure_ascii=False,indent=2)+'\n');tmp.rename(output)
 finally:
  if tmp.exists():shutil.rmtree(tmp)
 print(json.dumps({'webp_files':len(jobs),'output':str(output),'production_changed':False}))
if __name__=='__main__':main()
