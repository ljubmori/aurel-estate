const reply=(body,status=200,type='text/plain; charset=utf-8')=>new Response(body,{status,headers:{'content-type':type,'x-content-type-options':'nosniff','referrer-policy':'strict-origin-when-cross-origin'}});
export default {async fetch(request){
  const url=new URL(request.url);
  if(request.method!=='GET'&&request.method!=='HEAD')return reply('Method not allowed',405);
  const path=url.pathname;
  const file=ASSETS[path]||(!path.includes('.')?ASSETS['/index.html']:null);
  if(!file)return reply('Not found',404);
  const bytes=Uint8Array.from(atob(file.body),c=>c.charCodeAt(0));
  return new Response(request.method==='HEAD'?null:bytes,{headers:{
    'content-type':file.type,
    'cache-control':path.startsWith('/assets/')?'public,max-age=31536000,immutable':'no-cache',
    'x-content-type-options':'nosniff',
    'referrer-policy':'strict-origin-when-cross-origin'
  }});
}};
