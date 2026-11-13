export const AGENCY:string;
export const statuses:string[];
export const amenities:string[];
export function filterProperties<T>(rows:T[],f?:Record<string,string>):T[];
export function safeTour(url:string):string|null;
export function validateImage(file:{type:string;size:number}):string|null;
export function money(p:{price:number;currency:string;price_on_request?:boolean},lang?:string):string;
export function viewingPayload(input:Record<string,unknown>):Record<string,unknown>;
