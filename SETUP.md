# AUREL Estate — Supabase edition

AUREL uses **one application backend: Supabase**.
- PostgreSQL is the only database.
- Supabase Auth is the only authentication system (email + password).
- Supabase Storage is the only file store.
- The edge Worker serves the built static frontend only. It has no API, database or media-storage endpoints.

## Required configuration

Set these variables in the frontend build environment:
- `VITE_SUPABASE_URL`
- `VITE_SUPABASE_PUBLISHABLE_KEY` (or legacy `VITE_SUPABASE_ANON_KEY`)

The public/publishable key is intended for browser use and is protected by RLS. **Never put a Supabase service-role key in frontend code, a Vite variable, or Git.**

The build intentionally fails if either required Supabase setting is missing. There is no mock-data or alternate-backend fallback.

## Database setup

For a new Supabase project:

1. Open the Supabase SQL Editor as the project owner.
2. Apply `supabase/schema.sql`.
3. Apply `supabase/seed.sql` to create the AUREL demo agency and fictional listings.
4. Apply all five files in `supabase/migrations/` in timestamp order (`20261120000100` through `20261122000400`).
5. In Supabase Authentication, create the first administrator using the intended email and a strong password. Disable public sign-ups after the first owner account is created.
6. In SQL Editor, grant that Auth user owner access:

```sql
insert into public.agency_members(agency_id,user_id,role,data_scope,is_active)
values (
  '00000000-0000-4000-8000-000000000001',
  'AUTH_USER_UUID_HERE',
  'owner',
  'all',
  true
)
on conflict(agency_id,user_id) do update
set role='owner', data_scope='all', is_active=true;
```

Find the Auth user UUID in Supabase Authentication → Users. Do not use the email address as the user ID.

For an existing AUREL installation, first confirm that `supabase/schema.sql` and `supabase/seed.sql` have already been applied to that same Supabase project. These migrations are not a standalone bootstrap for an empty or unrelated database. Take a verified backup, review the target project reference, then apply both migrations in timestamp order. The first adds tables and columns and migrates existing property images and English/Serbian listing copy into normalized media and translation records. The second moves privileged authorization helpers into a non-exposed schema, consolidates RLS policies and adds missing foreign-key indexes. Do not apply the demo seed to a production agency without reviewing its sample content.

## Database model included in the migration

- Properties, categories and separate offer types (sale, long-term rent, short-term rent, commercial lease and reservation)
- New-build projects, buildings and individual units
- Original prices, currencies and automatic price-change history
- Media metadata for images, video, floor plans, 360 tours and 3D models
- AI-generated media identification and verification notes
- Agents, agency members, roles, permission metadata and data scopes
- Publication approval defaults by role in `site_settings.publication_rules`; `agency_members.can_publish` optionally overrides the default for one staff member. Owners and admins can always publish. Staff without permission can save a listing as draft, but a requested publish is moved to `pending` until an authorized user publishes it.
- Clients, inquiries and separate viewing requests
- English/Serbian property translations and extensible language records
- Site settings, design settings, SEO settings and translated page content
- Audit history for property, agent, inquiry, client and development-project changes
- Agency-scoped Row Level Security (RLS), database constraints and indexes

The database migrations lay down the data model and harden its access rules. The staff-management migration adds email/name metadata and membership audit history. The admin workspace includes team invitations, role/scope editing, collaborator permission toggles, activation/deactivation, password recovery and password setup for invited users. The Edge Function performs privileged invitations and membership changes server-side; the service-role key is never sent to the browser. The UI is not yet a complete production permissions console: audit-log browsing, comprehensive module-level collaborator enforcement, technical support access, and full CRM/development/translation screens still require completion and end-to-end testing.

## Login and team access

Open `/admin` and sign in with the Supabase Auth email and password. There is no ChatGPT sign-in path and no public registration. An account must have an active agency membership. Owners can invite admins, agents and limited collaborators from Team & permissions. Deploy the Edge Function with `supabase functions deploy agency-user-management`, then set `APP_URL` to the deployed site origin using `supabase secrets set APP_URL=https://your-domain.example`. In Authentication → URL Configuration, allowlist the deployed `/account/recovery` URL. Configure the invite and reset-password email templates to send verified users to that route. Use a production SMTP provider before relying on email delivery.

## Storage

The `property-media` bucket is public because the current listing gallery uses public image URLs. Anyone who obtains an object URL can read that file, including a file uploaded for a draft listing. Only authorized agency administrators can upload, update or delete objects through the configured Storage policies. Use this bucket only for public-facing listing photos, videos and floor plans. Never upload identity documents, contracts, private client files, unpublished marketing material that must remain confidential, or any other sensitive content. A separate private bucket with signed URLs and stricter policies is required before confidential media is supported.

## Build and tests

```sh
npm install
npm run build
npm test
```

GitHub Actions additionally starts a clean PostgreSQL 16 instance, applies the base schema and demo seed, applies both migrations twice to check rerun safety, then exercises public RLS, owner/agent access, inquiry-to-CRM linking, viewing-request creation, price history, publication approval, Storage write permissions and last-owner protection.

The edge Worker is only a static asset handler for the frontend. It does not accept API writes and has no D1 or R2 dependency. All application data requests go directly to Supabase under RLS.

## Important operational work still required

- Verify invitation acceptance and password reset end-to-end using the production SMTP provider and allowlisted redirect URL.
- Enable leaked-password protection in Supabase Authentication password security settings; the current Auth advisor reports it is disabled.
- Verify the real email/password sign-in flow from `/admin`.
- Set up automated database backups and test a restore.
- Configure production monitoring and error reporting.
- Add database integration tests for anonymous, non-admin and owner/admin RLS behavior.
- Complete the separate technical-support access workflow; developers must not be agency members or owners.
- Finish full CRM, development-project, translation, SEO and audit-log admin screens, plus end-to-end tests for all collaborator permissions.
- Add server-side abuse controls for public inquiry submission.
- Add a private storage bucket and separate policies before storing confidential documents.
- Confirm the agency timezone and visitor timezone handling before using viewing requests operationally.

All AUREL sample properties are fictional demonstration content.
