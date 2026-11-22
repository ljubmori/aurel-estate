# Verification status

## Live AUREL Supabase project

Configured project reference: `pllvsfbxtymoyavcjcxx` (EU West, PostgreSQL 17). The repository's `.env.production` points to this same project. The separate personal Supabase project was not changed.

- Both database migrations were applied successfully and are recorded in Supabase migration history.
- The existing agency and two fictional published properties were preserved.
- The existing confirmed Auth user was retained and its sole active agency membership was safely promoted from admin to owner.
- Database now contains 10 property categories, 2 properties, 2 initial price-history rows, 6 media metadata records and 4 English/Serbian translations.
- Public-role checks returned 2 published properties, 6 published media records, 10 active categories and 4 published translations.
- A temporary draft listing was invisible to `anon` and visible to the authenticated owner; the test transaction was rolled back.
- A rollback-only public viewing inquiry successfully created one CRM client and one viewing request; test records were rolled back.
- Anonymous direct inserts into `viewing_requests` are blocked; public requests must enter through the inquiry workflow.
- The authenticated owner can pass the Storage upload policy; the SQL test object was rolled back.
- Every table in the AUREL `public` schema has RLS enabled; no permanent test clients, inquiries or viewing requests remain.
- Owner/admin authorization helpers returned true for the existing owner account.
- No permanent test records were left behind.

## Supabase advisors after hardening

- Security: no database function/RLS findings remain. One Auth setting still needs manual attention: leaked-password protection is disabled.
- Performance: no missing foreign-key-index, RLS init-plan, or multiple-permissive-policy findings remain. Remaining notices are unused-index INFO notices on a database with very little traffic; review them after real usage rather than deleting indexes prematurely.
- Health: no findings.

## GitHub automated checks

Latest branch commit verified: `f2cf4da457ac71939c9e8498d842cc200a26b3d5`. Both latest GitHub Actions runs passed, including application tests, TypeScript/Vite build, PostgreSQL bootstrap, both migrations applied twice, and SQL smoke tests:
- <https://github.com/ljubmori/aurel-estate/actions/runs/45017549659>
- <https://github.com/ljubmori/aurel-estate/actions/runs/45017544846>

## Still requires manual/live verification

- Enable leaked-password protection in Supabase Authentication password security settings.
- Sign in through the deployed `/admin` page with the owner's email and password. The existing Auth user is confirmed, and the code uses `signInWithPassword`, but the actual password was not tested or accessed here.
- Test an actual image upload from the admin UI; SQL policy checks and metadata synchronization do not prove browser upload works end-to-end.
- Configure and verify production Auth redirect URLs, email templates, backups and restore.
- The full CRM, development-project, staff-invitation, translation, SEO and audit-log admin screens are not all implemented yet; database tables alone do not make those user interfaces complete.

## Unrelated Supabase project

The separate project named `ljubomir993@gmail.com's Project` contains `public.n8n_chat_histories` with RLS disabled. It is not AUREL's configured database and was not modified. Review and secure that table separately before using it with client-facing keys.

AUREL is not marked production-ready until the remaining manual/live checks above are completed.
