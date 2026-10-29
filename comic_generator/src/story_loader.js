import {canonicalStoryKey,declaredLegacyKeys} from './recovery_keys.js';
import {getLocalProject} from './project_library.js';
async function readJson(url){const response=await fetch(url);if(!response.ok)throw new Error('Não foi possível carregar '+url);return response.json();}
export let activeStoryPath=null;
export let recoveryKey=null;
export let recoveryAliases=[];
export async function loadStory(){
 const localId=new URL(location.href).searchParams.get('project');
 if(localId){recoveryKey=localId;const entry=await getLocalProject(localId);if(!entry)throw new Error('Projeto local não encontrado neste navegador. Volte às histórias e importe o arquivo salvo.');return entry.project;}
 const config=await readJson(new URL('../config/default_story.json',import.meta.url));
 const requested=new URL(location.href).searchParams.get('story')||config.story;
 const url=new URL(requested,new URL('../',import.meta.url));
 if(url.origin!==location.origin)throw new Error('A história deve estar no mesmo servidor.');
 recoveryKey=canonicalStoryKey(url.href,new URL('../',import.meta.url));
 activeStoryPath=recoveryKey;
 const project=await readJson(url);
 recoveryAliases=[requested,...declaredLegacyKeys(project,recoveryKey,new URL('../',import.meta.url))];
 await Promise.all(Object.values(project.assets).map(async asset=>{
  if(asset.data)return;
  const response=await fetch(new URL(asset.path,url));
  if(!response.ok)throw new Error('Recurso ausente: '+asset.path);
  asset.data=await new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result);reader.onerror=reject;response.blob().then(blob=>reader.readAsDataURL(blob),reject);});
  delete asset.path;
 }));
 return project;
}
