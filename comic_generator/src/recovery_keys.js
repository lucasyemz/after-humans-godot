export function canonicalStoryKey(requested,base){const url=new URL(requested,base),root=new URL(base);if(url.origin!==root.origin)throw new Error('A história deve estar no mesmo servidor.');const pathname=decodeURIComponent(url.pathname),prefix=decodeURIComponent(root.pathname);return (pathname.startsWith(prefix)?pathname.slice(prefix.length):pathname)+url.search;}
export function legacyNames(rootPath,aliases,current){return [...new Set(aliases.flatMap(key=>[rootPath,rootPath+'index.html',rootPath+'editor.html'].map(path=>'comic_generator:'+path+':'+key)))].filter(name=>name!==current);}
export function matchesStory(snapshot,story){const ids=new Set(story.scenes.map(scene=>scene.id));return snapshot?.format==='motion-comic-project'&&snapshot.version===1&&Array.isArray(snapshot.scenes)&&snapshot.scenes.some(scene=>ids.has(scene.id));}
export async function findLegacyRecovery(names){
 if(typeof indexedDB.databases!=='function')return null;
 const existing=new Set((await indexedDB.databases()).map(info=>info.name));
 for(const name of names){if(!existing.has(name))continue;const db=await new Promise((resolve,reject)=>{const request=indexedDB.open(name);request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);});
  try{if(!db.objectStoreNames.contains('recovery'))continue;const record=await new Promise((resolve,reject)=>{const tx=db.transaction('recovery','readonly'),store=tx.objectStore('recovery'),current=store.get('current'),previous=store.get('previous');tx.oncomplete=()=>resolve({name,current:current.result,previous:previous.result});tx.onerror=()=>reject(tx.error);});if(record.current)return record;}finally{db.close();}
 }
 return null;
}
export function copyRecovery(db,record){return new Promise((resolve,reject)=>{const tx=db.transaction('recovery','readwrite'),store=tx.objectStore('recovery');store.put(record.current,'current');if(record.previous)store.put(record.previous,'previous');tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);tx.onabort=()=>reject(tx.error);});}

export function declaredLegacyKeys(project,key,base){const legacy=project?.legacyRecovery;if(typeof legacy?.story!=='string'||!Array.isArray(legacy.keys))return [];try{if(canonicalStoryKey(legacy.story,base)!==key)return [];}catch{return [];}return legacy.keys.filter(alias=>typeof alias==='string');}
