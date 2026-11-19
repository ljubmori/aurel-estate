import {createClient} from '@supabase/supabase-js';
import {sitesDb} from './sites-client';
import {AGENCY} from './domain.mjs';
const env = (import.meta as ImportMeta & {env: Record<string, string | undefined>}).env;
const projectUrl = env.VITE_SUPABASE_URL?.trim();
const publicKey = env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() || env.VITE_SUPABASE_ANON_KEY?.trim();
if (Boolean(projectUrl) !== Boolean(publicKey)) {
  throw new Error('Set both the Supabase project URL and its public key.');
}
export const supabase = projectUrl && publicKey ? createClient(projectUrl, publicKey) : null;
export const db = supabase ?? sitesDb;
export type Property={id:string;agency_id:string;title:string;title_sr:string;slug:string;description:string;description_sr:string;type:string;transaction:string;status:string;country:string;city:string;neighborhood:string;address:string;postal_code:string;latitude:number|null;longitude:number|null;price:number;currency:string;price_format:string;price_on_request:boolean;area:number;land_area:number;bedrooms:number;bathrooms:number;floors:number;condition:string;year_built:number;features:string[];images:{url:string;alt:string}[];tour_url:string;tour_provider:string;agent_id:string|null;featured:boolean;created_at:string};
export const emptyProperty:Property={id:'',agency_id:AGENCY,title:'',title_sr:'',slug:'',description:'',description_sr:'',type:'Apartment',transaction:'sale',status:'draft',country:'',city:'',neighborhood:'',address:'',postal_code:'',latitude:null,longitude:null,price:0,currency:'EUR',price_format:'total',price_on_request:false,area:0,land_area:0,bedrooms:0,bathrooms:0,floors:1,condition:'Excellent',year_built:2024,features:[],images:[],tour_url:'',tour_provider:'',agent_id:null,featured:false,created_at:new Date().toISOString()};
const photo=(id:string)=>`https://images.unsplash.com/${id}?auto=format&fit=crop&w=1800&q=85`;
export const demo:Property[]=[
 ['the-kensington-residence','The Kensington Residence','Rezidencija Kensington','London','United Kingdom',2850000,'GBP',3,3,218,'Apartment','photo-1600210492486-724fe5c67fb0'],
 ['villa-solstice','Villa Solstice','Vila Solstice','Sydney','Australia',4250000,'AUD',4,3,360,'Villa','photo-1613490493576-7fde63acd811'],
 ['the-riverside-apartment','The Riverside Apartment','Stan na obali','Belgrade','Serbia',485000,'EUR',2,2,124,'Apartment','photo-1600607687920-4e2a09cf159d'],
 ['oak-house','Oak House','Kuća Oak','Manchester','United Kingdom',925000,'GBP',4,3,246,'House','photo-1600047509807-ba8f99d2cdde'],
 ['the-mayfair-workspace','The Mayfair Workspace','Poslovni prostor Mayfair','London','United Kingdom',8500,'GBP',0,2,185,'Commercial','photo-1497366754035-f200968a6e72']
].map((x,i)=>({...emptyProperty,id:`00000000-0000-4000-8000-00000000001${i}`,slug:String(x[0]),title:String(x[1]),title_sr:String(x[2]),city:String(x[3]),country:String(x[4]),price:Number(x[5]),currency:String(x[6]),bedrooms:Number(x[7]),bathrooms:Number(x[8]),area:Number(x[9]),type:String(x[10]),transaction:i===4?'rent':'sale',status:'published',featured:i<3,description:'A thoughtfully composed home, where generous proportions meet natural light. Beautifully detailed interiors open onto welcoming spaces for everyday living and entertaining. This fictional listing is part of the AUREL Estate demonstration collection.',description_sr:'Pažljivo osmišljen prostor sa obiljem prirodnog svetla. Prostrane sobe i kvalitetni detalji stvaraju prijatan ambijent za život. Ovaj izmišljeni oglas pripada demonstracionoj kolekciji AUREL Estate.',features:['Terrace','Air conditioning','Parking'],images:[{url:photo(String(x[11])),alt:String(x[1])},{url:photo('photo-1600607687939-ce8a6c25118c'),alt:'Interior detail'},{url:photo('photo-1600566753086-00f18fb6b3ea'),alt:'Living space'}]}));
export async function getProperties(admin=false){if(!db)return demo;let q=db.from('properties').select('*').eq('agency_id',AGENCY).order('created_at',{ascending:false});if(!admin)q=q.eq('status','published');const {data,error}=await q;if(error)throw error;return data as Property[];}
export async function submitInquiry(payload:Record<string,unknown>){if(!db)throw Error('Database is not connected. Your request has not been sent.');const {error}=await db.from('inquiries').insert({...payload,agency_id:AGENCY,status:'new'});if(error)throw error;}

