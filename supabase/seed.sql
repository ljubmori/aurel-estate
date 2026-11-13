insert into public.agencies(id,settings) values('00000000-0000-4000-8000-000000000001','{"name":"AUREL","email":"hello@aurel.example","phone":"+00 000 000 000","address":"International · Demonstration agency"}') on conflict(id) do nothing;
insert into public.properties(agency_id,title,title_sr,slug,description,description_sr,type,transaction,status,country,city,price,currency,area,bedrooms,bathrooms,featured,images,features)
select '00000000-0000-4000-8000-000000000001'::uuid,title,title_sr,slug,'A fictional demonstration listing. Generous proportions, natural light and carefully considered interiors. Replace this content in the administration dashboard.','Izmišljeni demonstracioni oglas. Prostran enterijer i obilje prirodnog svetla. Sadržaj možete izmeniti kroz administraciju.',type,transaction,'published',country,city,price,currency,area,bedrooms,bathrooms,featured,jsonb_build_array(jsonb_build_object('url','https://images.unsplash.com/'||photo||'?auto=format&fit=crop&w=1800&q=85','alt',title)), '["Terrace","Air conditioning","Parking"]'::jsonb
from (values
('The Kensington Residence','Rezidencija Kensington','the-kensington-residence','Apartment','sale','United Kingdom','London',2850000,'GBP',218,3,3,true,'photo-1600210492486-724fe5c67fb0'),
('Villa Solstice','Vila Solstice','villa-solstice','Villa','sale','Australia','Sydney',4250000,'AUD',360,4,3,true,'photo-1613490493576-7fde63acd811'),
('The Riverside Apartment','Stan na obali','the-riverside-apartment','Apartment','sale','Serbia','Belgrade',485000,'EUR',124,2,2,true,'photo-1600607687920-4e2a09cf159d'),
('Oak House','Kuća Oak','oak-house','House','sale','United Kingdom','Manchester',925000,'GBP',246,4,3,false,'photo-1600047509807-ba8f99d2cdde'),
('The Mayfair Workspace','Poslovni prostor Mayfair','the-mayfair-workspace','Commercial','rent','United Kingdom','London',8500,'GBP',185,0,2,false,'photo-1497366754035-f200968a6e72')
) as samples(title,title_sr,slug,type,transaction,country,city,price,currency,area,bedrooms,bathrooms,featured,photo)
on conflict(agency_id,slug) do nothing;
