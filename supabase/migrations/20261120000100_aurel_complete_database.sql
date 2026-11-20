-- AUREL Estate: single-backend Supabase foundation
-- Apply after the existing supabase/schema.sql. Safe to re-run where practical.
begin;

-- Agency membership: owner/admin/agent/collaborator, with granular permissions.
alter table public.agency_members drop constraint if exists agency_members_role_check;
alter table public.agency_members add constraint agency_members_role_check
  check (role in ('owner','admin','agent','collaborator'));
alter table public.agency_members add column if not exists permissions jsonb not null default '{}'::jsonb;
alter table public.agency_members add column if not exists data_scope text not null default 'assigned'
  check (data_scope in ('own','assigned','all'));
alter table public.agency_members add column if not exists is_active boolean not null default true;
alter table public.agency_members add column if not exists invited_at timestamptz;
alter table public.agency_members add column if not exists joined_at timestamptz default now();

create or replace function public.has_agency_role(a uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists (
    select 1 from public.agency_members m
    where m.agency_id=a and m.user_id=auth.uid()
      and m.is_active and m.role = any(allowed_roles)
  )
$$;
create or replace function public.is_agency_admin(a uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select public.has_agency_role(a, array['owner','admin'])
$$;
create or replace function public.can_manage_property(a uuid, property_agent uuid)
returns boolean language sql stable security definer set search_path=public,auth as $$
  select exists (
    select 1 from public.agency_members m
    where m.agency_id=a and m.user_id=auth.uid() and m.is_active
      and (
        m.role in ('owner','admin')
        or (m.role='agent' and (
          m.data_scope='all'
          or (m.data_scope='assigned' and property_agent=auth.uid())
          or (m.data_scope='own' and property_agent=auth.uid())
        ))
        or (m.role='collaborator' and coalesce((m.permissions->>'properties_write')::boolean,false)
          and (m.data_scope='all' or property_agent=auth.uid()))
      )
  )
$$;
revoke all on function public.has_agency_role(uuid,text[]) from public;
revoke all on function public.can_manage_property(uuid,uuid) from public;
grant execute on function public.has_agency_role(uuid,text[]) to anon,authenticated;
grant execute on function public.can_manage_property(uuid,uuid) to authenticated;

insert into public.agencies(id,settings) values('00000000-0000-4000-8000-000000000001','{"name":"AUREL","email":"hello@aurel.example","phone":"+00 000 000 000","address":"International · Demonstration agency"}'::jsonb) on conflict(id) do nothing;

-- Reusable listing categories, separate from the commercial transaction type.
create table if not exists public.property_categories (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  code text not null,
  name text not null,
  name_sr text not null default '',
  description text not null default '',
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(agency_id,code), unique(id,agency_id)
);

insert into public.property_categories(agency_id,code,name,name_sr,sort_order)
values
 ('00000000-0000-4000-8000-000000000001','apartment','Apartment','Stan',10),
 ('00000000-0000-4000-8000-000000000001','house','House','Kuća',20),
 ('00000000-0000-4000-8000-000000000001','villa','Villa','Vila',30),
 ('00000000-0000-4000-8000-000000000001','office','Office','Kancelarija',40),
 ('00000000-0000-4000-8000-000000000001','retail','Retail space','Maloprodajni prostor',50),
 ('00000000-0000-4000-8000-000000000001','conference','Conference room','Konferencijska sala',60),
 ('00000000-0000-4000-8000-000000000001','exhibition','Exhibition hall','Izložbeni prostor',70),
 ('00000000-0000-4000-8000-000000000001','garage','Garage / parking','Garaža / parking',80),
 ('00000000-0000-4000-8000-000000000001','warehouse','Warehouse / industrial','Magacin / industrijski prostor',90),
 ('00000000-0000-4000-8000-000000000001','land','Land','Zemljište',100)
on conflict(agency_id,code) do nothing;

alter table public.properties add column if not exists category_id uuid;
alter table public.properties add column if not exists offer_type text not null default 'sale'
  check (offer_type in ('sale','long_term_rent','short_term_rent','commercial_lease','reservation'));
alter table public.properties add column if not exists assigned_to uuid references auth.users(id) on delete set null;
alter table public.properties add column if not exists created_by uuid references auth.users(id) on delete set null;
alter table public.properties add column if not exists updated_at timestamptz not null default now();
alter table public.properties add column if not exists published_at timestamptz;
alter table public.properties add column if not exists seo_title text not null default '';
alter table public.properties add column if not exists seo_description text not null default '';
alter table public.properties add column if not exists attributes jsonb not null default '{}'::jsonb;
alter table public.properties add column if not exists currency_original text;
update public.properties set currency_original=currency where currency_original is null;
alter table public.properties add constraint properties_category_agency_fk
  foreign key(category_id,agency_id) references public.property_categories(id,agency_id) on delete set null (category_id);

update public.properties set offer_type = case
  when transaction='rent' and lower(type)='commercial' then 'commercial_lease'
  when transaction='rent' then 'long_term_rent'
  else 'sale' end
where offer_type='sale';

-- New-build hierarchy: development project -> building -> unit.
create table if not exists public.development_projects (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  name text not null, slug text not null,
  description text not null default '', description_sr text not null default '',
  country text not null default '', city text not null default '', address text not null default '',
  status text not null default 'planning' check(status in ('planning','under_construction','completed','archived')),
  start_date date, completion_date date,
  cover_image_url text not null default '',
  seo_title text not null default '', seo_description text not null default '',
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(agency_id,slug), unique(id,agency_id)
);
create table if not exists public.development_buildings (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  project_id uuid not null,
  name text not null, code text not null default '',
  floors integer not null default 1 check(floors>0),
  description text not null default '',
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(id,agency_id),
  foreign key(project_id,agency_id) references public.development_projects(id,agency_id) on delete cascade
);
create table if not exists public.development_units (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  project_id uuid not null, building_id uuid,
  unit_number text not null,
  floor_number integer,
  unit_type text not null default 'apartment',
  area numeric not null default 0 check(area>=0),
  bedrooms integer not null default 0 check(bedrooms>=0),
  bathrooms integer not null default 0 check(bathrooms>=0),
  price numeric check(price is null or price>=0),
  currency text not null default 'EUR',
  availability text not null default 'available' check(availability in ('available','reserved','sold','rented','unavailable')),
  property_id uuid,
  attributes jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(project_id,building_id,unit_number),
  unique(id,agency_id),
  foreign key(project_id,agency_id) references public.development_projects(id,agency_id) on delete cascade,
  foreign key(building_id,agency_id) references public.development_buildings(id,agency_id) on delete set null (building_id)
);
alter table public.properties add column if not exists development_project_id uuid;
alter table public.properties add column if not exists building_id uuid;
alter table public.properties add column if not exists development_unit_id uuid;
alter table public.properties add constraint properties_project_fk foreign key(development_project_id,agency_id)
  references public.development_projects(id,agency_id) on delete set null (development_project_id);
alter table public.properties add constraint properties_building_fk foreign key(building_id,agency_id)
  references public.development_buildings(id,agency_id) on delete set null (building_id);
alter table public.properties add constraint properties_unit_fk foreign key(development_unit_id,agency_id)
  references public.development_units(id,agency_id) on delete set null (development_unit_id);
alter table public.development_units add constraint development_units_property_fk foreign key(property_id,agency_id)
  references public.properties(id,agency_id) on delete set null (property_id);

-- Immutable price history, including initial price and every price/currency change.
create table if not exists public.property_price_history (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  property_id uuid not null,
  price numeric not null check(price>=0),
  currency text not null,
  price_format text not null default 'total',
  price_on_request boolean not null default false,
  valid_from timestamptz not null default now(),
  changed_by uuid references auth.users(id) on delete set null,
  change_note text not null default '',
  foreign key(property_id,agency_id) references public.properties(id,agency_id) on delete cascade
);
create index if not exists property_price_history_property on public.property_price_history(property_id,valid_from desc);
create or replace function public.record_property_price_change()
returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
  if tg_op='INSERT' or new.price is distinct from old.price
    or new.currency is distinct from old.currency
    or new.price_format is distinct from old.price_format
    or new.price_on_request is distinct from old.price_on_request then
    insert into public.property_price_history(agency_id,property_id,price,currency,price_format,price_on_request,changed_by)
    values(new.agency_id,new.id,new.price,new.currency,new.price_format,coalesce(new.price_on_request,false),auth.uid());
  end if;
  new.updated_at=now();
  return new;
end $$;
drop trigger if exists properties_price_history on public.properties;
create trigger properties_price_history before insert or update on public.properties
for each row execute function public.record_property_price_change();

-- Central media library: photos, video, floor plans and 3D tours.
create table if not exists public.property_media (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  property_id uuid not null,
  media_type text not null check(media_type in ('image','video','floor_plan','tour_360','model_3d')),
  storage_path text not null default '',
  public_url text not null default '',
  provider text not null default '',
  mime_type text not null default '',
  file_size bigint check(file_size is null or file_size>=0),
  title text not null default '', alt_text text not null default '',
  sort_order integer not null default 0, is_cover boolean not null default false,
  is_ai_generated boolean not null default false,
  verification_note text not null default '',
  metadata jsonb not null default '{}'::jsonb,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  foreign key(property_id,agency_id) references public.properties(id,agency_id) on delete cascade
);
create index if not exists property_media_order on public.property_media(property_id,sort_order);
create unique index if not exists property_media_one_cover on public.property_media(property_id) where is_cover;
insert into public.property_media(agency_id,property_id,media_type,public_url,alt_text,sort_order,is_cover)
select p.agency_id,p.id,'image',x->>'url',coalesce(x->>'alt',p.title),ord-1,ord=1
from public.properties p
cross join lateral jsonb_array_elements(case when jsonb_typeof(p.images)='array' then p.images else '[]'::jsonb end)
with ordinality as imgs(x,ord)
where coalesce(x->>'url','')<>''
and not exists(select 1 from public.property_media m where m.property_id=p.id and m.public_url=x->>'url');

-- Multiple localized versions of property copy and SEO metadata.
create table if not exists public.property_translations (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  property_id uuid not null,
  language_code text not null check(language_code ~ '^[a-z]{2}(-[A-Z]{2})?$'),
  title text not null default '', slug text not null default '',
  description text not null default '',
  seo_title text not null default '', seo_description text not null default '',
  translation_status text not null default 'draft' check(translation_status in ('draft','review','published')),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(property_id,language_code), unique(agency_id,language_code,slug),
  foreign key(property_id,agency_id) references public.properties(id,agency_id) on delete cascade
);
insert into public.property_translations(agency_id,property_id,language_code,title,slug,description,translation_status)
select agency_id,id,'en',title,slug,description,'published' from public.properties
on conflict(property_id,language_code) do nothing;
insert into public.property_translations(agency_id,property_id,language_code,title,slug,description,translation_status)
select agency_id,id,'sr',coalesce(nullif(title_sr,''),title),slug,coalesce(nullif(description_sr,''),description),'published'
from public.properties
on conflict(property_id,language_code) do nothing;

-- Clients/CRM and dedicated viewing requests.
create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  first_name text not null default '', last_name text not null default '',
  email text not null default '', phone text not null default '',
  preferred_language text not null default 'en',
  client_type text not null default 'buyer' check(client_type in ('buyer','seller','tenant','landlord','investor','other')),
  notes text not null default '',
  assigned_to uuid references auth.users(id) on delete set null,
  source text not null default 'website',
  consent_marketing boolean not null default false,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists clients_agency_email on public.clients(agency_id,lower(email));
alter table public.inquiries add column if not exists client_id uuid references public.clients(id) on delete set null;
alter table public.inquiries add column if not exists assigned_to uuid references auth.users(id) on delete set null;
alter table public.inquiries add column if not exists source text not null default 'website';
alter table public.inquiries add column if not exists consent_at timestamptz;
create table if not exists public.viewing_requests (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  inquiry_id uuid references public.inquiries(id) on delete set null,
  client_id uuid references public.clients(id) on delete set null,
  property_id uuid,
  requested_start timestamptz not null,
  requested_end timestamptz,
  confirmed_start timestamptz,
  confirmed_end timestamptz,
  status text not null default 'new' check(status in ('new','contacted','confirmed_by_agency','rescheduled','declined','completed','cancelled')),
  visitor_timezone text not null default 'UTC',
  agency_notes text not null default '',
  assigned_to uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  foreign key(property_id,agency_id) references public.properties(id,agency_id) on delete set null (property_id),
  check(requested_end is null or requested_end>requested_start),
  check(confirmed_end is null or confirmed_start is null or confirmed_end>confirmed_start)
);
insert into public.viewing_requests(agency_id,inquiry_id,property_id,requested_start,status)
select agency_id,id,property_id,(preferred_date+coalesce(preferred_time,time '12:00')) at time zone 'UTC',
 case when status='confirmed_by_agency' then 'confirmed_by_agency' else status end
from public.inquiries where kind='viewing' and preferred_date is not null
and not exists(select 1 from public.viewing_requests v where v.inquiry_id=inquiries.id);

-- Site-level content, settings and SEO.
create table if not exists public.site_settings (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null unique references public.agencies(id) on delete cascade,
  default_language text not null default 'en',
  supported_languages text[] not null default array['en','sr'],
  base_currency text not null default 'EUR',
  display_currencies text[] not null default array['EUR','USD','GBP','RSD'],
  timezone text not null default 'Europe/Belgrade',
  measurement_system text not null default 'metric' check(measurement_system in ('metric','imperial')),
  contact_settings jsonb not null default '{}'::jsonb,
  design_settings jsonb not null default '{}'::jsonb,
  seo_settings jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
insert into public.site_settings(agency_id,contact_settings)
select id,settings from public.agencies on conflict(agency_id) do nothing;
create table if not exists public.site_pages (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  page_key text not null, is_published boolean not null default false,
  seo_title text not null default '', seo_description text not null default '',
  og_image_url text not null default '', updated_at timestamptz not null default now(),
  unique(agency_id,page_key), unique(id,agency_id)
);
create table if not exists public.site_page_translations (
  id uuid primary key default gen_random_uuid(),
  agency_id uuid not null references public.agencies(id) on delete cascade,
  page_id uuid not null, language_code text not null,
  title text not null default '', content jsonb not null default '{}'::jsonb,
  seo_title text not null default '', seo_description text not null default '',
  updated_at timestamptz not null default now(),
  unique(page_id,language_code),
  foreign key(page_id,agency_id) references public.site_pages(id,agency_id) on delete cascade
);

-- Append-only audit history for important business records.
create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  agency_id uuid not null references public.agencies(id) on delete cascade,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null,
  entity_type text not null,
  entity_id text not null,
  old_values jsonb,
  new_values jsonb,
  created_at timestamptz not null default now()
);
create index if not exists audit_logs_agency_time on public.audit_logs(agency_id,created_at desc);
create or replace function public.write_audit_log()
returns trigger language plpgsql security definer set search_path=public,auth as $$
declare a uuid; rid text; oldj jsonb; newj jsonb;
begin
  if tg_op='DELETE' then oldj=to_jsonb(old); newj=null; a=old.agency_id; rid=old.id::text;
  elsif tg_op='UPDATE' then oldj=to_jsonb(old); newj=to_jsonb(new); a=new.agency_id; rid=new.id::text;
  else oldj=null; newj=to_jsonb(new); a=new.agency_id; rid=new.id::text; end if;
  insert into public.audit_logs(agency_id,actor_user_id,action,entity_type,entity_id,old_values,new_values)
  values(a,auth.uid(),lower(tg_op),tg_table_name,rid,oldj,newj);
  if tg_op='DELETE' then return old; else return new; end if;
end $$;
drop trigger if exists audit_properties on public.properties;
create trigger audit_properties after insert or update or delete on public.properties for each row execute function public.write_audit_log();
drop trigger if exists audit_agents on public.agents;
create trigger audit_agents after insert or update or delete on public.agents for each row execute function public.write_audit_log();
drop trigger if exists audit_inquiries on public.inquiries;
create trigger audit_inquiries after insert or update or delete on public.inquiries for each row execute function public.write_audit_log();
drop trigger if exists audit_clients on public.clients;
create trigger audit_clients after insert or update or delete on public.clients for each row execute function public.write_audit_log();
drop trigger if exists audit_projects on public.development_projects;
create trigger audit_projects after insert or update or delete on public.development_projects for each row execute function public.write_audit_log();

-- RLS: agency-scoped data. Public access is limited to published catalog content and media.
do $$
declare t text;
begin
  foreach t in array array['property_categories','development_projects','development_buildings','development_units',
    'property_price_history','property_media','property_translations','clients','viewing_requests',
    'site_settings','site_pages','site_page_translations','audit_logs']
  loop
    execute format('alter table public.%I enable row level security',t);
  end loop;
end $$;

create policy categories_public_read on public.property_categories for select to anon,authenticated using(is_active or public.is_agency_admin(agency_id));
create policy categories_admin_write on public.property_categories for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy projects_public_read on public.development_projects for select to anon,authenticated using(status='completed' or public.is_agency_admin(agency_id));
create policy projects_admin_write on public.development_projects for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy buildings_public_read on public.development_buildings for select to anon,authenticated using(exists(select 1 from public.development_projects p where p.id=project_id and p.status='completed') or public.is_agency_admin(agency_id));
create policy buildings_admin_write on public.development_buildings for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy units_public_read on public.development_units for select to anon,authenticated using(availability='available' or public.is_agency_admin(agency_id));
create policy units_admin_write on public.development_units for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy price_history_admin_read on public.property_price_history for select to authenticated using(public.is_agency_admin(agency_id));
create policy media_public_read on public.property_media for select to anon,authenticated using(exists(select 1 from public.properties p where p.id=property_id and p.status='published'));
create policy media_admin_write on public.property_media for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy translations_public_read on public.property_translations for select to anon,authenticated using(translation_status='published' and exists(select 1 from public.properties p where p.id=property_id and p.status='published'));
create policy translations_admin_write on public.property_translations for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy clients_admin_all on public.clients for all to authenticated using(public.is_agency_admin(agency_id) or (assigned_to=auth.uid() and public.has_agency_role(agency_id,array['agent']))) with check(public.is_agency_admin(agency_id) or (assigned_to=auth.uid() and public.has_agency_role(agency_id,array['agent'])));
create policy viewing_public_insert on public.viewing_requests for insert to anon,authenticated with check(status='new' and exists(select 1 from public.properties p where p.id=property_id and p.agency_id=viewing_requests.agency_id and p.status='published'));
create policy viewing_staff_read on public.viewing_requests for select to authenticated using(public.is_agency_admin(agency_id) or assigned_to=auth.uid());
create policy viewing_staff_update on public.viewing_requests for update to authenticated using(public.is_agency_admin(agency_id) or assigned_to=auth.uid()) with check(public.is_agency_admin(agency_id) or assigned_to=auth.uid());
create policy site_settings_public_read on public.site_settings for select to anon,authenticated using(true);
create policy site_settings_admin_write on public.site_settings for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy site_pages_public_read on public.site_pages for select to anon,authenticated using(is_published or public.is_agency_admin(agency_id));
create policy site_pages_admin_write on public.site_pages for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy page_translations_public_read on public.site_page_translations for select to anon,authenticated using(exists(select 1 from public.site_pages p where p.id=page_id and p.is_published));
create policy page_translations_admin_write on public.site_page_translations for all to authenticated using(public.is_agency_admin(agency_id)) with check(public.is_agency_admin(agency_id));
create policy audit_admin_read on public.audit_logs for select to authenticated using(public.is_agency_admin(agency_id));
-- No direct client writes/deletes to audit logs.
revoke all on public.audit_logs from anon,authenticated;
grant select on public.audit_logs to authenticated;

-- Explicit table privileges complement RLS.
grant select on public.property_categories,public.development_projects,public.development_buildings,
  public.development_units,public.property_media,public.property_translations,
  public.site_settings,public.site_pages,public.site_page_translations to anon,authenticated;
grant select,insert,update,delete on public.property_categories,public.development_projects,
  public.development_buildings,public.development_units,public.property_media,
  public.property_translations,public.clients,public.viewing_requests,
  public.site_settings,public.site_pages,public.site_page_translations to authenticated;
grant select on public.property_price_history to authenticated;
grant usage,select on sequence public.audit_logs_id_seq to authenticated;

-- Storage is the sole file store. Public reads; only active agency admins can write.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('property-media','property-media',true,52428800,
 array['image/jpeg','image/png','image/webp','image/avif','video/mp4','video/webm','application/pdf'])
on conflict(id) do update set file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists media_read on storage.objects;
drop policy if exists media_insert on storage.objects;
drop policy if exists media_update on storage.objects;
drop policy if exists media_delete on storage.objects;
create policy media_read on storage.objects for select to anon,authenticated using(bucket_id='property-media');
create policy media_insert on storage.objects for insert to authenticated with check(bucket_id='property-media' and public.is_agency_admin(((storage.foldername(name))[1])::uuid));
create policy media_update on storage.objects for update to authenticated using(bucket_id='property-media' and public.is_agency_admin(((storage.foldername(name))[1])::uuid)) with check(bucket_id='property-media' and public.is_agency_admin(((storage.foldername(name))[1])::uuid));
create policy media_delete on storage.objects for delete to authenticated using(bucket_id='property-media' and public.is_agency_admin(((storage.foldername(name))[1])::uuid));

commit;
