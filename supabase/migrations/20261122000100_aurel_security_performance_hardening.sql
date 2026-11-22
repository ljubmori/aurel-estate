-- AUREL: RLS policy consolidation, private authorization helpers and FK indexes.
begin;
-- Drop every policy this migration recreates so the migration is safe to re-run.
do $
declare item record;
begin
  for item in
    select * from (values
    ('agency_members','membership_read'),
    ('agency_members','membership_owner_insert'),
    ('agency_members','membership_owner_update'),
    ('agency_members','membership_owner_delete'),
    ('agents','agents_admin_insert'),
    ('agents','agents_admin_update'),
    ('agents','agents_admin_delete'),
    ('properties','properties_public_read'),
    ('properties','properties_staff_read'),
    ('properties','properties_staff_insert'),
    ('properties','properties_staff_update'),
    ('properties','properties_staff_delete'),
    ('inquiries','inquiries_staff_read'),
    ('inquiries','inquiries_staff_update'),
    ('property_categories','categories_public_read'),
    ('property_categories','categories_staff_read'),
    ('property_categories','categories_admin_insert'),
    ('property_categories','categories_admin_update'),
    ('property_categories','categories_admin_delete'),
    ('development_projects','projects_public_read'),
    ('development_projects','projects_staff_read'),
    ('development_projects','projects_admin_insert'),
    ('development_projects','projects_admin_update'),
    ('development_projects','projects_admin_delete'),
    ('development_buildings','buildings_public_read'),
    ('development_buildings','buildings_staff_read'),
    ('development_buildings','buildings_admin_insert'),
    ('development_buildings','buildings_admin_update'),
    ('development_buildings','buildings_admin_delete'),
    ('development_units','units_public_read'),
    ('development_units','units_staff_read'),
    ('development_units','units_admin_insert'),
    ('development_units','units_admin_update'),
    ('development_units','units_admin_delete'),
    ('property_media','media_public_read'),
    ('property_media','media_staff_read'),
    ('property_media','media_admin_insert'),
    ('property_media','media_admin_update'),
    ('property_media','media_admin_delete'),
    ('property_translations','translations_public_read'),
    ('property_translations','translations_staff_read'),
    ('property_translations','translations_admin_insert'),
    ('property_translations','translations_admin_update'),
    ('property_translations','translations_admin_delete'),
    ('viewing_requests','viewing_staff_read'),
    ('viewing_requests','viewing_staff_update'),
    ('site_settings','site_settings_admin_insert'),
    ('site_settings','site_settings_admin_update'),
    ('site_settings','site_settings_admin_delete'),
    ('site_pages','site_pages_public_read'),
    ('site_pages','site_pages_staff_read'),
    ('site_pages','site_pages_admin_insert'),
    ('site_pages','site_pages_admin_update'),
    ('site_pages','site_pages_admin_delete'),
    ('site_page_translations','page_translations_public_read'),
    ('site_page_translations','page_translations_staff_read'),
    ('site_page_translations','page_translations_admin_insert'),
    ('site_page_translations','page_translations_admin_update'),
    ('site_page_translations','page_translations_admin_delete'),
    ('audit_logs','audit_admin_read'),
    ('clients','clients_admin_all')
    ) as policies(table_name,policy_name)
  loop
    execute format('drop policy if exists %I on public.%I',item.policy_name,item.table_name);
  end loop;
end $;

create schema if not exists private;
revoke all on schema private from public,anon,authenticated;
grant usage on schema private to authenticated;

create or replace function private.has_agency_role(a uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth as $$
 select exists(select 1 from public.agency_members m where m.agency_id=a and m.user_id=(select auth.uid()) and m.is_active and m.role=any(allowed_roles))
$$;
create or replace function private.is_agency_admin(a uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth as $$
 select private.has_agency_role(a,array['owner','admin']::text[])
$$;
create or replace function private.is_agency_owner(a uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth as $$
 select private.has_agency_role(a,array['owner']::text[])
$$;
create or replace function private.can_manage_property(a uuid, property_assignee uuid, property_creator uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth as $$
 select exists(select 1 from public.agency_members m
 where m.agency_id=a and m.user_id=(select auth.uid()) and m.is_active and (
  m.role in ('owner','admin')
  or (m.role='agent' and (m.data_scope='all'
    or (m.data_scope='assigned' and (property_assignee=(select auth.uid()) or property_creator=(select auth.uid())))
    or (m.data_scope='own' and property_creator=(select auth.uid()))))
  or (m.role='collaborator' and coalesce((m.permissions->>'properties_write')::boolean,false)
    and (m.data_scope='all'
      or (m.data_scope='assigned' and (property_assignee=(select auth.uid()) or property_creator=(select auth.uid())))
      or (m.data_scope='own' and property_creator=(select auth.uid()))))
 ))
$$;
create or replace function private.can_publish_property(a uuid)
returns boolean language sql stable security definer set search_path=pg_catalog,public,auth as $$
 select exists(select 1 from public.agency_members m
 left join public.site_settings s on s.agency_id=m.agency_id
 where m.agency_id=a and m.user_id=(select auth.uid()) and m.is_active
 and (m.role in ('owner','admin') or coalesce(m.can_publish,(s.publication_rules->>m.role)::boolean,false)))
$$;
revoke all on all functions in schema private from public,anon;
grant execute on function private.has_agency_role(uuid,text[]) to authenticated;
grant execute on function private.is_agency_admin(uuid) to authenticated;
grant execute on function private.is_agency_owner(uuid) to authenticated;
grant execute on function private.can_manage_property(uuid,uuid,uuid) to authenticated;
grant execute on function private.can_publish_property(uuid) to authenticated;

-- Public RPC names remain compatible but no longer run with definer privileges.
create or replace function public.has_agency_role(a uuid,allowed_roles text[])
returns boolean language sql stable security invoker set search_path=pg_catalog,private as $$ select private.has_agency_role(a,allowed_roles) $$;
create or replace function public.is_agency_admin(a uuid)
returns boolean language sql stable security invoker set search_path=pg_catalog,private as $$ select private.is_agency_admin(a) $$;
create or replace function public.is_agency_owner(a uuid)
returns boolean language sql stable security invoker set search_path=pg_catalog,private as $$ select private.is_agency_owner(a) $$;
create or replace function public.can_manage_property(a uuid,property_assignee uuid,property_creator uuid)
returns boolean language sql stable security invoker set search_path=pg_catalog,private as $$ select private.can_manage_property(a,property_assignee,property_creator) $$;
create or replace function public.can_publish_property(a uuid)
returns boolean language sql stable security invoker set search_path=pg_catalog,private as $$ select private.can_publish_property(a) $$;
revoke all on function public.has_agency_role(uuid,text[]) from public,anon;
revoke all on function public.is_agency_admin(uuid) from public,anon;
revoke all on function public.is_agency_owner(uuid) from public,anon;
revoke all on function public.can_manage_property(uuid,uuid,uuid) from public,anon;
revoke all on function public.can_publish_property(uuid) from public,anon;
grant execute on function public.has_agency_role(uuid,text[]) to authenticated;
grant execute on function public.is_agency_admin(uuid) to authenticated;
grant execute on function public.is_agency_owner(uuid) to authenticated;
grant execute on function public.can_manage_property(uuid,uuid,uuid) to authenticated;
grant execute on function public.can_publish_property(uuid) to authenticated;

-- Membership reads are combined; only an owner can manage membership rows.
drop policy if exists membership_read on public.agency_members;
drop policy if exists membership_admin_read on public.agency_members;
drop policy if exists membership_owner_manage on public.agency_members;
create policy membership_read on public.agency_members for select to authenticated using(user_id=(select auth.uid()) or private.is_agency_admin(agency_id));
create policy membership_owner_insert on public.agency_members for insert to authenticated with check(private.is_agency_owner(agency_id));
create policy membership_owner_update on public.agency_members for update to authenticated using(private.is_agency_owner(agency_id)) with check(private.is_agency_owner(agency_id));
create policy membership_owner_delete on public.agency_members for delete to authenticated using(private.is_agency_owner(agency_id));

-- Public agent cards; admin-only writes.
drop policy if exists agents_manage on public.agents;
create policy agents_admin_insert on public.agents for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy agents_admin_update on public.agents for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy agents_admin_delete on public.agents for delete to authenticated using(private.is_agency_admin(agency_id));

-- Listings: public sees published only; authenticated staff can see the agency catalogue.
drop policy if exists properties_read on public.properties;
drop policy if exists properties_manage on public.properties;
drop policy if exists properties_staff_read on public.properties;
drop policy if exists properties_staff_write on public.properties;
create policy properties_public_read on public.properties for select to anon using(status='published');
create policy properties_staff_read on public.properties for select to authenticated using(
 status='published'
 or private.has_agency_role(agency_id,array['owner','admin','agent']::text[])
 or (private.has_agency_role(agency_id,array['collaborator']::text[]) and
 coalesce((select m.permissions->>'properties_read' from public.agency_members m
 where m.agency_id=properties.agency_id and m.user_id=(select auth.uid()) and m.is_active),'false')::boolean)
);
create policy properties_staff_insert on public.properties for insert to authenticated with check(private.can_manage_property(agency_id,assigned_to,created_by));
create policy properties_staff_update on public.properties for update to authenticated using(private.can_manage_property(agency_id,assigned_to,created_by)) with check(private.can_manage_property(agency_id,assigned_to,created_by));
create policy properties_staff_delete on public.properties for delete to authenticated using(private.can_manage_property(agency_id,assigned_to,created_by));

-- Inquiries: one read/update policy per role; agents only see assigned leads.
drop policy if exists inquiries_read on public.inquiries;
drop policy if exists inquiries_staff_read on public.inquiries;
drop policy if exists inquiries_update on public.inquiries;
drop policy if exists inquiries_staff_update on public.inquiries;
create policy inquiries_staff_read on public.inquiries for select to authenticated using(
 private.is_agency_admin(agency_id) or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
);
create policy inquiries_staff_update on public.inquiries for update to authenticated using(
 private.is_agency_admin(agency_id) or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
) with check(
 private.is_agency_admin(agency_id) or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
);

-- Categories.
drop policy if exists categories_public_read on public.property_categories;
drop policy if exists categories_admin_write on public.property_categories;
create policy categories_public_read on public.property_categories for select to anon using(is_active);
create policy categories_staff_read on public.property_categories for select to authenticated using(is_active or private.is_agency_admin(agency_id));
create policy categories_admin_insert on public.property_categories for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy categories_admin_update on public.property_categories for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy categories_admin_delete on public.property_categories for delete to authenticated using(private.is_agency_admin(agency_id));

-- Development projects.
drop policy if exists projects_public_read on public.development_projects;
drop policy if exists projects_admin_write on public.development_projects;
create policy projects_public_read on public.development_projects for select to anon using(status in ('under_construction','completed'));
create policy projects_staff_read on public.development_projects for select to authenticated using(status in ('under_construction','completed') or private.is_agency_admin(agency_id));
create policy projects_admin_insert on public.development_projects for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy projects_admin_update on public.development_projects for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy projects_admin_delete on public.development_projects for delete to authenticated using(private.is_agency_admin(agency_id));

-- Development buildings.
drop policy if exists buildings_public_read on public.development_buildings;
drop policy if exists buildings_admin_write on public.development_buildings;
create policy buildings_public_read on public.development_buildings for select to anon using(
 exists(select 1 from public.development_projects p where p.id=project_id and p.status in ('under_construction','completed'))
);
create policy buildings_staff_read on public.development_buildings for select to authenticated using(
 exists(select 1 from public.development_projects p where p.id=project_id and p.status in ('under_construction','completed')) or private.is_agency_admin(agency_id)
);
create policy buildings_admin_insert on public.development_buildings for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy buildings_admin_update on public.development_buildings for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy buildings_admin_delete on public.development_buildings for delete to authenticated using(private.is_agency_admin(agency_id));

-- Development units.
drop policy if exists units_public_read on public.development_units;
drop policy if exists units_admin_write on public.development_units;
create policy units_public_read on public.development_units for select to anon using(
 availability='available' and exists(select 1 from public.development_projects p where p.id=project_id and p.status in ('under_construction','completed'))
);
create policy units_staff_read on public.development_units for select to authenticated using(
 (availability='available' and exists(select 1 from public.development_projects p where p.id=project_id and p.status in ('under_construction','completed')))
 or private.is_agency_admin(agency_id)
);
create policy units_admin_insert on public.development_units for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy units_admin_update on public.development_units for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy units_admin_delete on public.development_units for delete to authenticated using(private.is_agency_admin(agency_id));

-- Media.
drop policy if exists media_public_read on public.property_media;
drop policy if exists media_admin_write on public.property_media;
create policy media_public_read on public.property_media for select to anon using(
 exists(select 1 from public.properties p where p.id=property_id and p.status='published')
);
create policy media_staff_read on public.property_media for select to authenticated using(
 exists(select 1 from public.properties p where p.id=property_id and p.status='published') or private.is_agency_admin(agency_id)
);
create policy media_admin_insert on public.property_media for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy media_admin_update on public.property_media for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy media_admin_delete on public.property_media for delete to authenticated using(private.is_agency_admin(agency_id));

-- Property translations.
drop policy if exists translations_public_read on public.property_translations;
drop policy if exists translations_admin_write on public.property_translations;
create policy translations_public_read on public.property_translations for select to anon using(
 translation_status='published' and exists(select 1 from public.properties p where p.id=property_id and p.status='published')
);
create policy translations_staff_read on public.property_translations for select to authenticated using(
 (translation_status='published' and exists(select 1 from public.properties p where p.id=property_id and p.status='published')) or private.is_agency_admin(agency_id)
);
create policy translations_admin_insert on public.property_translations for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy translations_admin_update on public.property_translations for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy translations_admin_delete on public.property_translations for delete to authenticated using(private.is_agency_admin(agency_id));

-- Viewing requests are generated by the public inquiry trigger, not direct anonymous inserts.
drop policy if exists viewing_public_insert on public.viewing_requests;
revoke insert on public.viewing_requests from anon;
drop policy if exists viewing_staff_read on public.viewing_requests;
drop policy if exists viewing_staff_update on public.viewing_requests;
create policy viewing_staff_read on public.viewing_requests for select to authenticated using(
 private.is_agency_admin(agency_id) or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
);
create policy viewing_staff_update on public.viewing_requests for update to authenticated using(
 private.is_agency_admin(agency_id) or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
) with check(
 private.is_agency_admin(agency_id) or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
);

-- Site settings are public presentation configuration; only administrators write them.
drop policy if exists site_settings_admin_write on public.site_settings;
create policy site_settings_admin_insert on public.site_settings for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy site_settings_admin_update on public.site_settings for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy site_settings_admin_delete on public.site_settings for delete to authenticated using(private.is_agency_admin(agency_id));

-- Public pages and private drafts.
drop policy if exists site_pages_public_read on public.site_pages;
drop policy if exists site_pages_admin_write on public.site_pages;
create policy site_pages_public_read on public.site_pages for select to anon using(is_published);
create policy site_pages_staff_read on public.site_pages for select to authenticated using(is_published or private.is_agency_admin(agency_id));
create policy site_pages_admin_insert on public.site_pages for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy site_pages_admin_update on public.site_pages for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy site_pages_admin_delete on public.site_pages for delete to authenticated using(private.is_agency_admin(agency_id));

drop policy if exists page_translations_public_read on public.site_page_translations;
drop policy if exists page_translations_admin_write on public.site_page_translations;
create policy page_translations_public_read on public.site_page_translations for select to anon using(
 exists(select 1 from public.site_pages p where p.id=page_id and p.is_published)
);
create policy page_translations_staff_read on public.site_page_translations for select to authenticated using(
 exists(select 1 from public.site_pages p where p.id=page_id and p.is_published) or private.is_agency_admin(agency_id)
);
create policy page_translations_admin_insert on public.site_page_translations for insert to authenticated with check(private.is_agency_admin(agency_id));
create policy page_translations_admin_update on public.site_page_translations for update to authenticated using(private.is_agency_admin(agency_id)) with check(private.is_agency_admin(agency_id));
create policy page_translations_admin_delete on public.site_page_translations for delete to authenticated using(private.is_agency_admin(agency_id));

drop policy if exists audit_admin_read on public.audit_logs;
create policy audit_admin_read on public.audit_logs for select to authenticated using(private.is_agency_admin(agency_id));

drop policy if exists clients_admin_all on public.clients;
create policy clients_admin_all on public.clients for all to authenticated using(
 private.is_agency_admin(agency_id) or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
) with check(
 private.is_agency_admin(agency_id) or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
);

-- Index all foreign keys reported by Supabase's performance advisor.
create index if not exists audit_logs_actor_user_idx on public.audit_logs(actor_user_id);
create index if not exists clients_assigned_to_idx on public.clients(assigned_to);
create index if not exists development_buildings_agency_idx on public.development_buildings(agency_id);
create index if not exists development_buildings_project_agency_idx on public.development_buildings(project_id,agency_id);
create index if not exists development_projects_created_by_idx on public.development_projects(created_by);
create index if not exists development_units_agency_idx on public.development_units(agency_id);
create index if not exists development_units_building_agency_idx on public.development_units(building_id,agency_id);
create index if not exists development_units_project_agency_idx on public.development_units(project_id,agency_id);
create index if not exists development_units_property_agency_idx on public.development_units(property_id,agency_id);
create index if not exists inquiries_assigned_to_idx on public.inquiries(assigned_to);
create index if not exists inquiries_client_id_idx on public.inquiries(client_id);
create index if not exists properties_assigned_to_idx on public.properties(assigned_to);
create index if not exists properties_building_agency_idx on public.properties(building_id,agency_id);
create index if not exists properties_category_agency_idx on public.properties(category_id,agency_id);
create index if not exists properties_created_by_idx on public.properties(created_by);
create index if not exists properties_project_agency_idx on public.properties(development_project_id,agency_id);
create index if not exists properties_unit_agency_idx on public.properties(development_unit_id,agency_id);
create index if not exists property_media_agency_idx on public.property_media(agency_id);
create index if not exists property_media_created_by_idx on public.property_media(created_by);
create index if not exists property_media_property_agency_idx on public.property_media(property_id,agency_id);
create index if not exists property_price_history_agency_idx on public.property_price_history(agency_id);
create index if not exists property_price_history_changed_by_idx on public.property_price_history(changed_by);
create index if not exists property_price_history_property_agency_idx on public.property_price_history(property_id,agency_id);
create index if not exists property_translations_property_agency_idx on public.property_translations(property_id,agency_id);
create index if not exists property_translations_updated_by_idx on public.property_translations(updated_by);
create index if not exists site_page_translations_agency_idx on public.site_page_translations(agency_id);
create index if not exists site_page_translations_page_agency_idx on public.site_page_translations(page_id,agency_id);
create index if not exists viewing_requests_agency_idx on public.viewing_requests(agency_id);
create index if not exists viewing_requests_assigned_to_idx on public.viewing_requests(assigned_to);
create index if not exists viewing_requests_client_id_idx on public.viewing_requests(client_id);
create index if not exists viewing_requests_property_agency_idx on public.viewing_requests(property_id,agency_id);
commit;
