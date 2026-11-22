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
- Owner/admin authorization helpers returned true for the existing owner account.
- No permanent test records were left behind.

## Supabase advisors after hardening

- Security: no database function/RLS findings remain. One Auth setting still needs manual attention: leaked-password protection is disabled.
- Performance: no missing foreign-key-index, RLS init-plan, or multiple-permissive-policy findings remain. Remaining notices are unused-index INFO notices on a database with very little traffic; review them after real usage rather than deleting indexes prematurely.
- Health: no findings.

## GitHub automated checks

The original application checks passed at commit `7ecfe28ef3b3e6bc9ab5d2c214b49e3d67232e54`. The CI workflow has now been updated to apply the security/performance migration twice as well; wait for the newest run on this branch before treating the updated test suite as green.

## Still requires manual/live verification

- Enable leaked-password protection in Supabase Authentication password security settings.
- Sign in through the deployed `/admin` page with the owner's email and password. The existing Auth user is confirmed, and the code uses `signInWithPassword`, but the actual password was not tested or accessed here.
- Test an actual image upload from the admin UI; SQL policy checks and metadata synchronization do not prove browser upload works end-to-end.
- Configure and verify production Auth redirect URLs, email templates, backups and restore.
- The full CRM, development-project, staff-invitation, translation, SEO and audit-log admin screens are not all implemented yet; database tables alone do not make those user interfaces complete.

## Unrelated Supabase project

The separate project named `ljubomir993@gmail.com's Project` contains `public.n8n_chat_histories` with RLS disabled. It is not AUREL's configured database and was not modified. Review and secure that table separately before using it with client-facing keys.

AUREL is not marked production-ready until the remaining manual/live checks above are completed.
