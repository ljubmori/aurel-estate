import {createClient} from '@supabase/supabase-js';
import {AGENCY} from './domain.mjs';
const env = (import.meta as ImportMeta & {env: Record<string, string | undefined>}).env;
const projectUrl = env.VITE_SUPABASE_URL?.trim();
const publicKey = env.VITE_SUPABASE_PUBLISHABLE_KEY?.trim() || env.VITE_SUPABASE_ANON_KEY?.trim();
if (!projectUrl || !publicKey) {
  throw new Error('AUREL requires VITE_SUPABASE_URL and VITE_SUPABASE_PUBLISHABLE_KEY. Configure Supabase before building.');
}
export const supabase = createClient(projectUrl, publicKey);
export const db = supabase;
export type Property={id:string;agency_id:string;title:string;title_sr:string;slug:string;description:string;description_sr:string;type:string;transaction:string;status:string;country:string;city:string;neighborhood:string;address:string;postal_code:string;latitude:number|null;longitude:number|null;price:number;currency:string;price_format:string;price_on_request:boolean;area:number;land_area:number;bedrooms:number;bathrooms:number;floors:number;condition:string;year_built:number;features:string[];images:{url:string;alt:string;path?:string}[];tour_url:string;tour_provider:string;agent_id:string|null;featured:boolean;created_at:string};
export const emptyProperty:Property={id:'',agency_id:AGENCY,title:'',title_sr:'',slug:'',description:'',description_sr:'',type:'Apartment',transaction:'sale',status:'draft',country:'',city:'',neighborhood:'',address:'',postal_code:'',latitude:null,longitude:null,price:0,currency:'EUR',price_format:'total',price_on_request:false,area:0,land_area:0,bedrooms:0,bathrooms:0,floors:1,condition:'Excellent',year_built:2024,features:[],images:[],tour_url:'',tour_provider:'',agent_id:null,featured:false,created_at:new Date().toISOString()};
export async function getProperties(admin=false){let q=db.from('properties').select('*').eq('agency_id',AGENCY).order('created_at',{ascending:false});if(!admin)q=q.eq('status','published');const {data,error}=await q;if(error)throw error;return data as Property[];}
export async function submitInquiry(payload:Record<string,unknown>){const {error}=await db.from('inquiries').insert({...payload,agency_id:AGENCY,status:'new'});if(error)throw error;}
