import fs from 'node:fs';
import path from 'node:path';
const files={};
function walk(dir){
  for(const e of fs.readdirSync(dir,{withFileTypes:true})){
    const p=path.join(dir,e.name);
    if(e.isDirectory())walk(p);
    else files['/'+path.relative('dist/client',p).replaceAll('\\','/')]={body:fs.readFileSync(p).toString('base64'),type:({'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.xml':'application/xml','.txt':'text/plain'})[path.extname(p)]||'application/octet-stream'};
  }
}
walk('dist/client');
fs.mkdirSync('dist/server',{recursive:true});
fs.writeFileSync('dist/server/index.js','const ASSETS='+JSON.stringify(files)+';\n'+fs.readFileSync('worker/index.js','utf8'));
console.log('Static asset Worker packaged with '+Object.keys(files).length+' assets; all application data uses Supabase.');
