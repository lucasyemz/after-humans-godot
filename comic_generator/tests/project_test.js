import test from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir,stat} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import path from 'node:path';
const root=new URL('../',import.meta.url);
const json=async p=>JSON.parse(await readFile(new URL(p,root),'utf8'));
test('example resolves all scene assets, with no historical or unused assets',async()=>{
 const config=await json('config/default_story.json');const story=await json(config.story);
 assert.equal(createHash('sha256').update(JSON.stringify(story.scenes.map(s=>s.config))).digest('hex'),'bc50d89480ce8a8132d0bcbd2e1182f300680783ad015a649d4e594037f0483c');
 assert.equal(story.scenes.length,8);assert.equal(story.scenes.reduce((n,s)=>n+s.config.timing.loopEnd,0),44.3);
 const used=new Set(story.scenes.flatMap(s=>Object.values(s.images)));
 assert.deepEqual([...used].sort(),Object.keys(story.assets).sort());
 for(const scene of story.scenes){assert.deepEqual(scene.assetHistory,[]);for(const [slot,plate] of Object.entries(scene.config.plates)){if(plate.visible!==false)assert.ok(scene.images[slot],slot);}}
 const inventory=await json('docs/asset_inventory.json');
 for(const [id,asset] of Object.entries(story.assets)){
  assert.match(asset.path,/^assets\/[a-z0-9_]+\.(png|webp)$/);
  const bytes=await readFile(new URL(asset.path,new URL(config.story,root)));
  const entry=inventory.find(a=>a.id===id);assert.equal(bytes.length,entry.bytes);
  assert.equal(createHash('sha256').update(bytes).digest('hex'),entry.sha256);
 }
 assert.equal(story.scenes[0].config.speech.text,'Última caixa. Depois, casa, maninho.');
 assert.equal(story.scenes[7].config.caption.text,'Eu fui embora. E meu irmão ficou.');
});
test('runtime uses local pinned dependencies and no embedded story',async()=>{
 const code=await readFile(new URL('src/comic_editor.js',root),'utf8');
 assert.ok(!code.includes('const STORY='));assert.ok(!code.includes('base64,'+ 'iVBOR'));
 const manifest=await json('package.json'),lock=await json('package-lock.json');
 assert.deepEqual(lock.packages[''].dependencies,manifest.dependencies);
 for(const version of Object.values(manifest.dependencies))assert.match(version,/^\d+\.\d+\.\d+$/);
});
