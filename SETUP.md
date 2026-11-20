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
4. Apply `supabase/migrations/20261120000100_aurel_complete_database.sql`.
5. In Supabase Authentication, create the administrator using the intended email and a strong password. Disable public sign-ups after the administrator account is created.
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

For an existing Supabase project, take a database backup first, then apply the new migration. It adds tables and columns and migrates current property images and English/Serbian listing copy into the new media and translation tables. Review the SQL and confirm the target project before applying it.

## Database model included in the migration

- Properties, categories and separate offer types (sale, long-term rent, short-term rent, commercial lease and reservation)
- New-build projects, buildings and individual units
- Original prices, currencies and automatic price-change history
- Media metadata for images, video, floor plans, 360 tours and 3D models
- AI-generated media identification and verification notes
- Agents, agency members, roles, permission metadata and data scopes
- Clients, inquiries and separate viewing requests
- English/Serbian property translations and extensible language records
- Site settings, design settings, SEO settings and translated page content
- Audit history for property, agent, inquiry, client and development-project changes
- Agency-scoped Row Level Security (RLS), database constraints and indexes

The migration lays down the data model. Not every new table has a finished admin screen yet. Advanced role workflows, full CRM screens, development-project management, translation editing, and media-library UI are subsequent implementation work.

## Login

Open `/admin` and sign in with the Supabase Auth email and password. There is no ChatGPT sign-in path and no public administrator registration. The account must have an active `owner` or `admin` membership for this agency.

## Storage

The `property-media` bucket is used for listing media. The first path segment must be the agency UUID. Public visitors can read published property media; only authorized agency administrators can upload, update or delete files. Never upload confidential identity documents or private client files to the public property-media bucket.

## Build and tests

```sh
npm install
npm run build
npm test
```

The edge Worker is only a static asset handler for the frontend. It does not accept API writes and has no D1 or R2 dependency. All application data requests go directly to Supabase under RLS.

## Important operational work still required

- Configure Supabase Auth email templates and redirect URLs for the deployed domain.
- Set up automated database backups and test a restore.
- Configure production monitoring and error reporting.
- Add database integration tests for anonymous, non-admin and owner/admin RLS behavior.
- Implement the admin UI for staff invitations, granular permissions, clients/CRM, developments/units, translation management, SEO and audit-log review.
- Add server-side abuse controls for public inquiry submission.
- Add a private storage bucket and separate policies before storing confidential documents.
- Confirm the agency timezone and visitor timezone handling before using viewing requests operationally.

All AUREL sample properties are fictional demonstration content.
