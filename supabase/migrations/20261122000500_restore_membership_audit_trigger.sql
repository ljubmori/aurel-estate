-- Restore a single membership audit trigger, after the function was replaced
-- by the actor-attribution migration. Edge Function service_role writes remain
-- manually attributed; direct authenticated writes must be audited by the trigger.
begin;
drop trigger if exists audit_agency_membership_change on public.agency_members;
drop trigger if exists aurel_membership_audit_log on public.agency_members;
create trigger aurel_membership_audit_log
after insert or update or delete on public.agency_members
for each row execute function public.write_membership_audit_log();
commit;
