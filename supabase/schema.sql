-- AUREL Estate. Apply in the Supabase SQL editor as project owner.
create table public.agencies(id uuid primary key,settings jsonb not null default '{}');
create table public.agency_members(agency_id uuid references public.agencies on delete cascade,user_id uuid references auth.users on delete cascade,role text not null check(role in ('admin','agent','collaborator')),primary key(agency_id,user_id));
create function public.is_agency_admin(a uuid) returns boolean language sql stable security definer set search_path=public as $$select exists(select 1 from agency_members where agency_id=a and user_id=auth.uid() and role='admin')$$;
revoke all on function public.is_agency_admin(uuid) from public;
grant execute on function public.is_agency_admin(uuid) to anon,authenticated;
create table public.agents(id uuid primary key default gen_random_uuid(),agency_id uuid not null references public.agencies,name text not null,email text default '',phone text default '',bio text default '',languages text default '',photo_url text default '',unique(id,agency_id));
create table public.properties(
 id uuid primary key default gen_random_uuid(),agency_id uuid not null references public.agencies,
 title text not null,title_sr text default '',slug text not null check(slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),description text default '',description_sr text default '',type text not null,transaction text not null check(transaction in ('sale','rent')),status text not null default 'draft' check(status in ('draft','pending','published','unpublished','sold','rented')),
 country text not null,city text not null,neighborhood text default '',address text default '',postal_code text default '',latitude numeric check(latitude between -90 and 90),longitude numeric check(longitude between -180 and 180),price numeric not null check(price>=0),currency text not null check(currency in ('EUR','USD','GBP','RSD','CAD','AUD')),price_format text default 'total',price_on_request boolean default false,
 area numeric not null check(area>=0),land_area numeric default 0 check(land_area>=0),bedrooms integer default 0 check(bedrooms>=0),bathrooms integer default 0 check(bathrooms>=0),floors integer default 1,condition text default '',year_built integer,features jsonb not null default '[]',images jsonb not null default '[]',tour_url text default '' check(tour_url='' or tour_url ~ '^https://'),tour_provider text default '',agent_id uuid,featured boolean default false,created_at timestamptz default now(),
 unique(agency_id,slug),unique(id,agency_id),foreign key(agent_id,agency_id) references public.agents(id,agency_id) on delete set null (agent_id)
);
create index properties_catalog on public.properties(agency_id,status,created_at desc);
create table public.inquiries(id uuid primary key default gen_random_uuid(),agency_id uuid not null references public.agencies,property_id uuid,kind text not null check(kind in ('inquiry','viewing')),name text not null check(length(name) between 1 and 120),email text not null check(length(email) between 3 and 200 and position('@' in email)>1),phone text default '' check(length(phone)<=50),message text not null check(length(message) between 1 and 5000),preferred_date date,preferred_time time,status text not null default 'new' check(status in ('new','contacted','confirmed_by_agency','rescheduled','declined','completed')),created_at timestamptz default now(),foreign key(property_id,agency_id) references public.properties(id,agency_id) on delete set null (property_id),check(kind<>'viewing' or (preferred_date is not null and preferred_time is not null)));
create index inquiries_agency on public.inquiries(agency_id,created_at desc);
alter table public.agencies enable row level security;
alter table public.agency_members enable row level security;
alter table public.agents enable row level security;
alter table public.properties enable row level security;
alter table public.inquiries enable row level security;
create policy agencies_read on public.agencies for select to anon,authenticated using(true);
create policy agencies_update on public.agencies for update to authenticated using(public.is_agency_admin(id)) with check(public.is_agency_admin(id));
create policy membership_read on public.agency_members for select to authenticated using(user_id=auth.uid());
create policy agents_read on public.agents for select to anon,authenticated using(true);
create policy agents_manage on public.agents for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy properties_read on public.properties for select to anon,authenticated using(status='published' or public.is_agency_admin(agency_id));
create policy properties_manage on public.properties for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy inquiries_submit on public.inquiries for insert to anon,authenticated with check(status='new' and (kind<>'viewing' or (property_id is not null and preferred_date>=current_date)) and exists(select 1 from public.agencies a where a.id=agency_id) and (property_id is null or exists(select 1 from public.properties p where p.id=property_id and p.agency_id=inquiries.agency_id and p.status='published')));
create policy inquiries_read on public.inquiries for select to authenticated using(public.is_agency_admin(agency_id));
create policy inquiries_update on public.inquiries for update to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values('property-media','property-media',true,10485760,array['image/jpeg','image/png','image/webp']) on conflict(id) do nothing;
create policy media_read on storage.objects for select to anon,authenticated using(bucket_id='property-media');
create policy media_insert on storage.objects for insert to authenticated with check(bucket_id='property-media' and public.is_agency_admin(((storage.foldername(name))[1])::uuid));
create policy media_update on storage.objects for update to authenticated using(bucket_id='property-media' and public.is_agency_admin(((storage.foldername(name))[1])::uuid)) with check(bucket_id='property-media' and public.is_agency_admin(((storage.foldername(name))[1])::uuid));
create policy media_delete on storage.objects for delete to authenticated using(bucket_id='property-media' and public.is_agency_admin(((storage.foldername(name))[1])::uuid));
-- Administrators are granted ONLY by project owner via SQL; never by public signup.


revoke all on public.agencies, public.agency_members, public.properties, public.agents, public.inquiries from anon, authenticated;
grant select on public.agencies, public.agents, public.properties to anon, authenticated;
grant insert on public.inquiries to anon, authenticated;
grant select on public.agency_members, public.inquiries to authenticated;
grant update on public.agencies, public.inquiries to authenticated;
grant insert, update, delete on public.agents, public.properties to authenticated;
