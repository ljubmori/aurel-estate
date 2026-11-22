-- Correct agent edit scope and enforce collaborator permissions consistently.
create or replace function private.can_manage_property(a uuid, property_assignee uuid, property_creator uuid)
returns boolean
language sql stable security definer
set search_path=pg_catalog,public,auth
as $$
 select exists(
  select 1 from public.agency_members m
  where m.agency_id=a and m.user_id=(select auth.uid()) and m.is_active and (
   m.role in ('owner','admin')
   or (m.role='agent' and (
     property_assignee=(select auth.uid()) or property_creator=(select auth.uid())
   ))
   or (m.role='collaborator'
     and coalesce((m.permissions->>'properties_write')::boolean,false)
     and (
       m.data_scope='all'
       or (m.data_scope='assigned' and (property_assignee=(select auth.uid()) or property_creator=(select auth.uid())))
       or (m.data_scope='own' and property_creator=(select auth.uid()))
     ))
  )
 )
$$;

create or replace function private.can_delete_property(a uuid, property_assignee uuid, property_creator uuid)
returns boolean
language sql stable security definer
set search_path=pg_catalog,public,auth
as $$
 select exists(
  select 1 from public.agency_members m
  where m.agency_id=a and m.user_id=(select auth.uid()) and m.is_active and (
   m.role in ('owner','admin')
   or (m.role='collaborator'
     and coalesce((m.permissions->>'properties_delete')::boolean,false)
     and (
       m.data_scope='all'
       or (m.data_scope='assigned' and (property_assignee=(select auth.uid()) or property_creator=(select auth.uid())))
       or (m.data_scope='own' and property_creator=(select auth.uid()))
     ))
  )
 )
$$;
revoke all on function private.can_delete_property(uuid,uuid,uuid) from public,anon,authenticated;
grant execute on function private.can_delete_property(uuid,uuid,uuid) to authenticated;

drop policy if exists properties_staff_delete on public.properties;
create policy properties_staff_delete on public.properties
for delete to authenticated
using(private.can_delete_property(agency_id,assigned_to,created_by));

drop policy if exists inquiries_staff_read on public.inquiries;
create policy inquiries_staff_read on public.inquiries
for select to authenticated
using(
 private.is_agency_admin(agency_id)
 or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
 or exists(
   select 1 from public.agency_members m
   where m.agency_id=inquiries.agency_id and m.user_id=(select auth.uid())
     and m.is_active and m.role='collaborator'
     and coalesce((m.permissions->>'inquiries_read')::boolean,false)
     and (
       m.data_scope='all'
       or (m.data_scope='assigned' and inquiries.assigned_to=(select auth.uid()))
       or (m.data_scope='own' and inquiries.assigned_to=(select auth.uid()))
     )
 )
);

drop policy if exists inquiries_staff_update on public.inquiries;
create policy inquiries_staff_update on public.inquiries
for update to authenticated
using(
 private.is_agency_admin(agency_id)
 or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
 or exists(
   select 1 from public.agency_members m
   where m.agency_id=inquiries.agency_id and m.user_id=(select auth.uid())
     and m.is_active and m.role='collaborator'
     and coalesce((m.permissions->>'inquiries_write')::boolean,false)
     and (
       m.data_scope='all'
       or (m.data_scope='assigned' and inquiries.assigned_to=(select auth.uid()))
       or (m.data_scope='own' and inquiries.assigned_to=(select auth.uid()))
     )
 )
)
with check(
 private.is_agency_admin(agency_id)
 or (assigned_to=(select auth.uid()) and private.has_agency_role(agency_id,array['agent']::text[]))
 or exists(
   select 1 from public.agency_members m
   where m.agency_id=inquiries.agency_id and m.user_id=(select auth.uid())
     and m.is_active and m.role='collaborator'
     and coalesce((m.permissions->>'inquiries_write')::boolean,false)
     and (
       m.data_scope='all'
       or (m.data_scope='assigned' and inquiries.assigned_to=(select auth.uid()))
       or (m.data_scope='own' and inquiries.assigned_to=(select auth.uid()))
     )
 )
);
