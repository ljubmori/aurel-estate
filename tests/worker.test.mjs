import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const source='const ASSETS={"/index.html":{body:'+JSON.stringify(Buffer.from('<main>AUREL</main>').toString('base64'))+',type:"text/html"}};'+fs.readFileSync('worker/index.js','utf8');
const {default:worker}=await import('data:text/javascript;base64,'+Buffer.from(source).toString('base64'));
test('static worker serves the application shell for client routes',async()=>{
  const r=await worker.fetch(new Request('https://aurel.test/en/properties/example'));
  assert.equal(r.status,200);assert.match(await r.text(),/AUREL/);
});
test('static worker does not expose a second API or database backend',async()=>{
  for(const path of ['/api/session','/api/data','/api/media']){
    const r=await worker.fetch(new Request('https://aurel.test'+path));
    assert.equal(r.status,404);
  }
});
test('static worker rejects write methods',async()=>{
  const r=await worker.fetch(new Request('https://aurel.test/api/data',{method:'POST'}));
  assert.equal(r.status,405);
});
