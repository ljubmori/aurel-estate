-- AUREL: staff directory metadata and auditable membership changes.
begin;

alter table public.agency_members
  add column if not exists email text not null default '',
  add column if not exists display_name text not null default '';

update public.agency_members m
set email = coalesce(u.email, ''),
    display_name = coalesce(nullif(u.raw_user_meta_data->>'display_name',''), nullif(u.raw_user_meta_data->>'full_name',''), '')
from auth.users u
where u.id = m.user_id
  and (m.email = '' or m.display_name = '');

create or replace function private.audit_agency_membership_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  target_user uuid;
  target_agency uuid;
  event_name text;
begin
  if tg_op = 'DELETE' then
    target_user := old.user_id;
    target_agency := old.agency_id;
    event_name := 'agency_member.removed';
    insert into public.audit_logs(agency_id, actor_user_id, action, entity_type, entity_id, old_values)
    values (target_agency, auth.uid(), event_name, 'agency_member', target_user::text,
      jsonb_build_object('role',old.role,'is_active',old.is_active,'email',old.email));
    return old;
  end if;

  target_user := new.user_id;
  target_agency := new.agency_id;
  if tg_op = 'INSERT' then
    event_name := 'agency_member.added';
    insert into public.audit_logs(agency_id, actor_user_id, action, entity_type, entity_id, new_values)
    values (target_agency, auth.uid(), event_name, 'agency_member', target_user::text,
      jsonb_build_object('role',new.role,'is_active',new.is_active,'email',new.email,'data_scope',new.data_scope));
  elsif old.role is distinct from new.role
     or old.permissions is distinct from new.permissions
     or old.data_scope is distinct from new.data_scope
     or old.is_active is distinct from new.is_active
     or old.can_publish is distinct from new.can_publish then
    event_name := case when old.is_active and not new.is_active
      then 'agency_member.deactivated'
      when not old.is_active and new.is_active
      then 'agency_member.reactivated'
      else 'agency_member.permissions_changed' end;
    insert into public.audit_logs(agency_id, actor_user_id, action, entity_type, entity_id, old_values, new_values)
    values (target_agency, auth.uid(), event_name, 'agency_member', target_user::text,
      jsonb_build_object('role',old.role,'is_active',old.is_active,'permissions',old.permissions,'data_scope',old.data_scope,'can_publish',old.can_publish),
      jsonb_build_object('role',new.role,'is_active',new.is_active,'permissions',new.permissions,'data_scope',new.data_scope,'can_publish',new.can_publish));
  end if;
  return new;
end;
$$;

drop trigger if exists audit_agency_membership_change on public.agency_members;
create trigger audit_agency_membership_change
after insert or update or delete on public.agency_members
for each row execute function private.audit_agency_membership_change();

commit;
