-- Keep the existing comprehensive membership audit trigger; avoid duplicate rows.
drop trigger if exists audit_agency_membership_change on public.agency_members;
drop function if exists private.audit_agency_membership_change();

-- Direct client-side membership changes retain actor attribution. Service-role
-- operations are audited explicitly by the agency-user-management Edge Function.
create or replace function public.write_membership_audit_log()
returns trigger
language plpgsql
security definer
set search_path=pg_catalog,public,auth
as $$
declare
  a uuid;
  member_user uuid;
  oldj jsonb;
  newj jsonb;
begin
  if auth.uid() is null then
    if tg_op='DELETE' then return old; else return new; end if;
  end if;
  if tg_op='DELETE' then
    a=old.agency_id; member_user=old.user_id; oldj=to_jsonb(old); newj=null;
  elsif tg_op='UPDATE' then
    a=new.agency_id; member_user=new.user_id; oldj=to_jsonb(old); newj=to_jsonb(new);
  else
    a=new.agency_id; member_user=new.user_id; oldj=null; newj=to_jsonb(new);
  end if;
  insert into public.audit_logs(agency_id,actor_user_id,action,entity_type,entity_id,old_values,new_values)
  values(a,auth.uid(),lower(tg_op),'agency_members',member_user::text,oldj,newj);
  if tg_op='DELETE' then return old; else return new; end if;
end
$$;
