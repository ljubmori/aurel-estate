-- Verify seeded catalog and baseline public visibility.
do $$ begin
  if (select count(*) from public.properties where status='published') < 1 then
    raise exception 'Seed did not create published properties';
  end if;
  if not (select relrowsecurity from pg_class where oid='public.properties'::regclass) then
    raise exception 'RLS is not enabled on properties';
  end if;
end $$;

-- Create test identities and their memberships as the database owner.
insert into auth.users(id) values
 ('10000000-0000-4000-8000-000000000001'),
 ('10000000-0000-4000-8000-000000000002'),
 ('10000000-0000-4000-8000-000000000003'),
 ('10000000-0000-4000-8000-000000000004');
insert into public.agency_members(agency_id,user_id,role,data_scope,is_active)
values
 ('00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','owner','all',true),
 ('00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','agent','own',true),
 ('00000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004','collaborator','assigned',true);

do $$ begin
  if not exists(select 1 from public.audit_logs where entity_type='agency_members' and entity_id='10000000-0000-4000-8000-000000000002') then
    raise exception 'Agency membership changes are not recorded in audit history';
  end if;
end $$;

-- Owner creates a listing that belongs to the owner, not the agent.
set role authenticated;
set request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
insert into public.properties(agency_id,title,slug,type,transaction,status,country,city,price,currency,area)
values ('00000000-0000-4000-8000-000000000001','Owner-only property','owner-only-property',
 'Apartment','sale','draft','Serbia','Novi Sad',250000,'EUR',90);
reset role;

-- An anonymous visitor can see published properties, but not drafts.
set role anon;
do $$ begin
  if (select count(*) from public.properties where status='published') < 1 then
    raise exception 'Anonymous visitor cannot read published properties';
  end if;
  if (select count(*) from public.properties where status<>'published') <> 0 then
    raise exception 'Anonymous visitor can read unpublished properties';
  end if;
end $$;
reset role;

-- Public inquiry inserts must create a CRM client and, for viewings, a viewing request.
select id as seeded_property_id from public.properties where status='published' order by created_at limit 1 \gset
set role anon;
insert into public.inquiries(agency_id,property_id,kind,name,email,phone,message,status,preferred_date,preferred_time)
values ('00000000-0000-4000-8000-000000000001', :'seeded_property_id','viewing',
 'Test Visitor','db-smoke@example.test','+38160000000','Database smoke test','new','2099-05-01','12:00');
reset role;
do $$ begin
  if not exists(select 1 from public.clients where lower(email)='db-smoke@example.test') then
    raise exception 'Inquiry did not create CRM client';
  end if;
  if not exists(select 1 from public.viewing_requests v join public.inquiries i on i.id=v.inquiry_id where i.email='db-smoke@example.test') then
    raise exception 'Viewing inquiry did not create a viewing request';
  end if;
end $$;

-- An agent can create and edit their own listing, and sees the whole agency catalog.
set role authenticated;
set request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
insert into public.properties(agency_id,title,slug,type,transaction,status,country,city,price,currency,area)
values ('00000000-0000-4000-8000-000000000001','Agent test property','agent-test-property',
 'Apartment','sale','draft','Serbia','Novi Sad',100000,'EUR',50)
returning id as agent_property_id \gset
update public.properties set price=105000 where id=:'agent_property_id';
insert into public.properties(agency_id,title,slug,type,transaction,status,country,city,price,currency,area)
values ('00000000-0000-4000-8000-000000000001','Agent publication request','agent-publication-request',
 'Apartment','sale','published','Serbia','Belgrade',150000,'EUR',60);
do $$ begin
  if (select count(*) from public.properties) < 2 then
    raise exception 'Agent cannot see all agency properties';
  end if;
  if (select status from public.properties where slug='agent-publication-request') <> 'pending' then
    raise exception 'Agent bypassed the default publication approval rule';
  end if;
end $$;
reset role;

-- The agency owner can change the role-level publication rule.
update public.site_settings
set publication_rules='{"owner":true,"admin":true,"agent":true,"collaborator":false}'::jsonb
where agency_id='00000000-0000-4000-8000-000000000001';
set role authenticated;
set request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
insert into public.properties(agency_id,title,slug,type,transaction,status,country,city,price,currency,area)
values ('00000000-0000-4000-8000-000000000001','Agent approved publisher','agent-approved-publisher',
 'Apartment','sale','published','Serbia','Belgrade',175000,'EUR',65);
reset role;
update public.site_settings
set publication_rules='{"owner":true,"admin":true,"agent":false,"collaborator":false}'::jsonb
where agency_id='00000000-0000-4000-8000-000000000001';
set role authenticated;
set request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
update public.properties set status='published',description='Agent edited an already-published listing'
where slug='agent-approved-publisher';
reset role;
do $$ begin
  if (select status from public.properties where slug='agent-approved-publisher') <> 'published' then
    raise exception 'Editing an already-published listing incorrectly removed publication';
  end if;
end $$;

do $$ begin
  if not exists(select 1 from public.properties where slug='agent-test-property' and created_by='10000000-0000-4000-8000-000000000002') then
    raise exception 'Agent-created listing creator attribution failed';
  end if;
  if (select count(*) from public.property_price_history where property_id=(select id from public.properties where slug='agent-test-property')) < 2 then
    raise exception 'Initial and changed prices were not both recorded';
  end if;
end $$;

-- Agents cannot modify or delete another user's listing, and cannot delete their own.
set role authenticated;
set request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
update public.properties set price=999999 where slug='owner-only-property';
delete from public.properties where slug='agent-test-property';
reset role;
do $ begin
  if (select price from public.properties where slug='owner-only-property') <> 250000 then
    raise exception 'Agent changed a listing owned by another user';
  end if;
  if not exists(select 1 from public.properties where slug='agent-test-property') then
    raise exception 'Agent unexpectedly deleted their own listing';
  end if;
end $;

-- A collaborator with explicit properties_write can edit assigned/own records, but not delete without properties_delete.
set role authenticated;
set request.jwt.claim.sub='10000000-0000-4000-8000-000000000004';
insert into public.properties(agency_id,title,slug,type,transaction,status,country,city,price,currency,area)
values ('00000000-0000-4000-8000-000000000001','Collaborator property','collaborator-property',
 'Apartment','sale','draft','Serbia','Novi Sad',125000,'EUR',55)
returning id as collaborator_property_id \gset
update public.properties set price=130000 where id=:'collaborator_property_id';
delete from public.properties where id=:'collaborator_property_id';
reset role;
do $ begin
  if (select price from public.properties where slug='collaborator-property') <> 130000 then
    raise exception 'Collaborator with write permission could not edit own listing';
  end if;
  if not exists(select 1 from public.properties where slug='collaborator-property') then
    raise exception 'Collaborator deleted a listing without delete permission';
  end if;
end $;

-- Owner can upload public listing media; agents cannot upload to Storage.
set role authenticated;
set request.jwt.claim.sub='10000000-0000-4000-8000-000000000001';
insert into storage.objects(bucket_id,name)
values('property-media','00000000-0000-4000-8000-000000000001/db-smoke-owner.jpg');
reset role;
do $$ begin
  if not exists(select 1 from storage.objects where name='00000000-0000-4000-8000-000000000001/db-smoke-owner.jpg') then
    raise exception 'Owner Storage upload was not saved';
  end if;
end $$;

set role authenticated;
set request.jwt.claim.sub='10000000-0000-4000-8000-000000000002';
do $$ begin
  begin
    insert into storage.objects(bucket_id,name)
    values('property-media','00000000-0000-4000-8000-000000000001/db-smoke-agent.jpg');
    raise exception 'Agent Storage upload unexpectedly succeeded';
  exception when insufficient_privilege then
    null;
  end;
end $$;
reset role;

-- A signed-in user without agency membership cannot see draft listings.
set role authenticated;
set request.jwt.claim.sub='10000000-0000-4000-8000-000000000003';
do $$ begin
  if (select count(*) from public.properties where slug='agent-test-property') <> 0 then
    raise exception 'Non-member can read private draft property';
  end if;
end $$;
reset role;

-- The last active owner cannot be removed.
do $$ begin
  begin
    update public.agency_members set is_active=false
    where user_id='10000000-0000-4000-8000-000000000001';
    raise exception 'Last owner protection did not block deactivation';
  exception when raise_exception then
    if sqlerrm='Last owner protection did not block deactivation' then raise; end if;
  end;
end $$;

select 'AUREL database smoke tests passed' as result;
