const databaseName='comic_generator_library';
function openLibrary(){return new Promise((resolve,reject)=>{const request=indexedDB.open(databaseName,1);request.onupgradeneeded=()=>request.result.createObjectStore('projects',{keyPath:'id'});request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);});}
async function transaction(mode,action){const db=await openLibrary();try{return await new Promise((resolve,reject)=>{const tx=db.transaction('projects',mode);const request=action(tx.objectStore('projects'));let result;request.onsuccess=()=>{result=request.result;};tx.oncomplete=()=>resolve(result);tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);});}finally{db.close();}}
export const listLocalProjects=()=>transaction('readonly',store=>store.getAll());
export const getLocalProject=id=>transaction('readonly',store=>store.get(id));
export async function saveLocalProject(id,project){const entry={id,project,updatedAt:Date.now()};await transaction('readwrite',store=>store.put(entry));return entry;}
export function validateImport(project){
 if(project?.name!==undefined&&typeof project.name!=='string')throw new Error('O nome do projeto precisa ser um texto.');
 if(project?.format!=='motion-comic-project'||project.version!==1||!Array.isArray(project.scenes)||!project.scenes.length||project.scenes.length>40||!project.assets||typeof project.assets!=='object')throw new Error('Escolha um projeto .comic.json válido salvo pelo editor.');
 if(!project.scenes.every(validScene))throw new Error('O projeto contém uma cena inválida.');
 for(const scene of project.scenes)for(const id of Object.values(scene.images||{})){if(!/^data:image\/(png|jpeg|webp);base64,/.test(project.assets[id]?.data||''))throw new Error('Importe o arquivo completo, com as imagens incorporadas, usando Salvar projeto no editor.');}
 return project;
}
export function projectSummary(project){const first=project.scenes[0];const cover=project.assets[first.images?.full||first.images?.bg];return {name:String(project.name||'Minha tirinha'),scenes:project.scenes.length,duration:project.scenes.reduce((n,s)=>n+s.config.timing.loopEnd,0),cover:cover?.data||null};}

function validScene(scene){
 const config=scene?.config;
 if(!scene?.id||!config||!config.effects||!config.plates)return false;
 const numbers={camera:['fov','shake','alarmShake'],lights:['ambient','sky','ground','lamp','lampPower','flash','flashPower','beamLength','alarm'],fog:['color','density'],floor:['y','color'],speech:['start','end'],particles:['rainBack','rainFront','drips','dust','seed'],post:['bloom','bloomAlarm','threshold','radius','grain','halftone','vignette','cold'],timing:['alarm','shakeEnd','cutBlack','loopEnd','fadeIn']};
 for(const [section,fields] of Object.entries(numbers)){if(!config[section]||fields.some(key=>!Number.isFinite(config[section][key])))return false;}
 const vector=value=>Array.isArray(value)&&value.length===3&&value.every(Number.isFinite);
 if(config.timing.loopEnd<=0||!vector(config.speech.anchor)||!vector(config.lights.lampPosition)||!vector(config.lights.hand))return false;
 if(!Array.isArray(config.camera.keys)||!config.camera.keys.length||config.camera.keys.some(key=>!Number.isFinite(key.t)||!vector(key.p)||!vector(key.a)))return false;
 for(const slot of ['bg','theo','bento']){const plate=config.plates[slot];if(!plate||!vector(plate.position)||!Number.isFinite(plate.height)||!Number.isFinite(plate.scale))return false;}
 return true;
}

export async function savePublishedSummary(id,project){const summary=projectSummary(project);delete summary.cover;await transaction('readwrite',store=>store.put({id,kind:'published',summary,updatedAt:Date.now()}));}
