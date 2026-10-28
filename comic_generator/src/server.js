import http from 'node:http';
import {readFile,readdir} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../',import.meta.url));
const types={'.html':'text/html; charset=utf-8','.js':'text/javascript','.mjs':'text/javascript','.json':'application/json','.css':'text/css','.png':'image/png','.webp':'image/webp','.woff2':'font/woff2'};
http.createServer(async(req,res)=>{
 try{
  const pathname=decodeURIComponent(new URL(req.url,'http://localhost').pathname);
  if(pathname==='/api/stories'){
   const defaultStory=JSON.parse(await readFile(path.join(root,'config/default_story.json'),'utf8')).story;
   const entries=await readdir(path.join(root,'stories'),{withFileTypes:true});const stories=[];
   for(const entry of entries){if(!entry.isDirectory()||entry.name.startsWith('.'))continue;try{const relative='stories/'+entry.name+'/story.json';const project=JSON.parse(await readFile(path.join(root,relative),'utf8'));if(project.format!=='motion-comic-project'||!project.scenes?.length)continue;const first=project.scenes[0],asset=project.assets[first.images?.full||first.images?.bg];let cover=null;if(asset?.path){const coverPath=path.posix.normalize('stories/'+entry.name+'/'+asset.path);if(coverPath.startsWith('stories/'+entry.name+'/'))cover=coverPath;}stories.push({id:relative,isDefault:relative===defaultStory,name:typeof project.name==='string'?project.name:entry.name,scenes:project.scenes.length,duration:project.scenes.reduce((n,s)=>n+(s.config?.timing?.loopEnd||0),0),cover});}catch{continue;}}
   res.writeHead(200,{'Content-Type':'application/json','Cache-Control':'no-store'});res.end(JSON.stringify(stories));return;
  }
  const file=path.resolve(root,'.'+(pathname==='/'?'/index.html':pathname));
  const relative=path.relative(root,file);
  if(relative.startsWith('..')||path.isAbsolute(relative)||relative.split(path.sep).some(s=>s.startsWith('.'))){res.writeHead(403).end();return;}
  const bytes=await readFile(file);res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store'});res.end(bytes);
 }catch{res.writeHead(404).end('Not found');}
}).listen(Number(process.env.PORT||8766),'127.0.0.1',()=>console.log('Comic generator: http://127.0.0.1:'+(process.env.PORT||8766)));
