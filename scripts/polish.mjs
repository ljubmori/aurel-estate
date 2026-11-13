import fs from 'node:fs';
let s=fs.readFileSync('src/main.tsx','utf8');
s=s.replace("document.title=`${loc.pathname.includes('properties')?", "const matched=properties.find((p:Property)=>loc.pathname.endsWith('/properties/'+p.slug));document.title=matched?`${lang==='sr'&&matched.title_sr?matched.title_sr:matched.title} | ${settings.name} Estate`:`${loc.pathname.includes('properties')?");
s=s.replace('[loc.pathname,loading]);const value=','[loc.pathname,loading,properties]);const value=');
s=s.replace('const[busy,setBusy]=useState(false);const submit=','const[busy,setBusy]=useState(false);useEffect(()=>setStatus(""),[lang]);const submit=');
fs.writeFileSync('src/main.tsx',s);
