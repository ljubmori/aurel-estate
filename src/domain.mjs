export const AGENCY='00000000-0000-4000-8000-000000000001';
export const statuses=['draft','pending','published','unpublished','sold','rented'];
export const amenities=['Balcony','Terrace','Garden','Garage','Swimming pool','Elevator','Air conditioning','Heating','Furnished','Sea view','Parking','Security system'];
export function filterProperties(rows, f={}) {return rows.filter(p=>p.status==='published'&&(!f.transaction||p.transaction===f.transaction)&&(!f.type||p.type===f.type)&&(!f.country||p.country===f.country)&&(!f.city||p.city.toLowerCase().includes(f.city.toLowerCase()))&&(!f.minPrice||p.price>=Number(f.minPrice))&&(!f.maxPrice||p.price<=Number(f.maxPrice))&&(!f.beds||p.bedrooms>=Number(f.beds))&&(!f.minArea||p.area>=Number(f.minArea))&&(!f.maxArea||p.area<=Number(f.maxArea))).sort((a,b)=>f.sort==='price-asc'?a.price-b.price:f.sort==='price-desc'?b.price-a.price:new Date(b.created_at)-new Date(a.created_at));}
export function safeTour(url){try{const u=new URL(url);return u.protocol==='https:'?u.href:null}catch{return null}}
export function validateImage(file){if(!['image/jpeg','image/png','image/webp'].includes(file.type))return 'Use JPEG, PNG or WebP images.';if(file.size>10*1024*1024)return 'Maximum image size is 10 MB.';return null}
export function money(p,lang='en'){return p.price_on_request?(lang==='sr'?'Cena na upit':'Price on request'):new Intl.NumberFormat(lang==='sr'?'sr-RS':'en-GB',{style:'currency',currency:p.currency,maximumFractionDigits:0}).format(p.price)}
export function viewingPayload(input){return {...input,kind:'viewing',status:'new'}}
