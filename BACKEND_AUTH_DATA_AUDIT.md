# Backend, authentication and data audit

Date: 2026-11-20
Repository: `ljubmori/aurel-estate`
Base reviewed: `main`

## Executive summary

The repository contains two competing backend implementations:

1. **Supabase** — selected by the frontend whenever both `VITE_SUPABASE_URL` and a publishable/anon key are present.
2. **Cloudflare Sites Worker + D1 + R2** — a second implementation with its own authentication adapter and JSON-record storage.

The checked-in `.env.production` contains both Supabase frontend variables. Under a normal Vite production build, `.env.production` is loaded automatically. Therefore, the frontend is expected to select Supabase and bypass `src/sites-client.ts`, while `.openai/hosting.json` and `scripts/build-worker.mjs` also describe/package the Worker backend. This is an architectural conflict, not proof of which backend the currently deployed instance is using; deployment runtime must still be checked.

**Do not switch or remove either backend until the live data store and admin login have been verified.** A careless switch could make existing listings, inquiries, images or administrator access appear to disappear.

## Findings

### P0 — Resolve the active-backend ambiguity before migration

- `src/data.ts` creates a Supabase client when the URL and public key exist, then sets `db = supabase ?? sitesDb`.
- `.env.production` currently supplies the Supabase URL and publishable key.
- `src/admin.tsx` consequently uses Supabase Auth email/password when the Supabase client exists; the ChatGPT sign-in button is the alternative path.
- `src/sites-client.ts` and `worker/index.js` implement a separate Sites/Worker API, but the frontend will not use them when Supabase is configured.
- `.openai/hosting.json` declares D1 and R2 bindings. The build script packages the Worker.

Action: verify the live build's resolved backend and inspect the live Supabase data before changing configuration or migrating records.

### P1 — Authentication and authorization

**Supabase path**
- The schema enables RLS on agencies, members, agents, properties and inquiries.
- Public property reads are limited to published listings; agency admins can read/manage all listings.
- Inquiry insertion is allowed to anonymous visitors, while inquiry reads/updates require agency-admin membership.
- Admin membership is provisioned manually by the project owner, not public signup.
- The application currently implements the admin login flow; advanced agent/collaborator permissions are not implemented in the current UI.
- The SQL schema has no automated integration tests proving RLS behavior for anonymous, ordinary authenticated and admin users.

**Worker path**
- The Worker checks the `oai-authenticated-user-id` and `oai-authenticated-user-email` request headers and stores the first approved owner's user ID in D1.
- The owner email is hard-coded in `worker/index.js`; this is not suitable as a reusable per-client configuration.
- Authorization depends on the hosting platform injecting trustworthy identity headers. The Worker itself does not cryptographically verify those headers. Confirm that the public Worker origin cannot be called with attacker-supplied identity headers before relying on this path.
- Worker tests simulate those headers locally; that does not prove production header provenance.

### P1 — Data integrity and storage

**Supabase**
- Relational tables, foreign keys, status checks, indexes and RLS are present.
- Property images are stored as JSON URLs in the property row; media objects are in a public Supabase Storage bucket.
- The schema includes basic file size/MIME restrictions and admin-only upload/update/delete policies.
- Anonymous inquiry insertion has validation constraints and requires a published property when a property ID is supplied. There is no database-backed rate limit in the SQL schema.
- The schema/seed files describe setup, but this repository does not contain an automated migration proving that the live database matches them.

**Worker**
- D1 stores each entity as a JSON payload in one generic `records` table. This is simple for a prototype but weaker for relational integrity, indexed querying, reporting and future schema evolution.
- R2 stores image files. The Worker validates declared MIME type and basic file signatures and limits each file to 10 MB.
- Public inquiry insertion has a simple per-email rate check in application code; it is not a durable database rate-limit mechanism and can be bypassed by varying email addresses.
- The Worker test suite covers owner access, CRUD, public visibility, inquiry status and media persistence, but not production identity-header trust or real D1/R2 deployment behavior.

### P2 — Operational gaps

- `SETUP.md` describes manual migration between Supabase and Worker storage; there is no automated, verified migration tool.
- No automated CI workflow was found under `.github/workflows`.
- Current test documentation reports 13 tests; tests in the repository cover domain behavior and the Worker adapter. Supabase RLS and hosted authentication are not covered by automated integration tests.
- Backup/restore and production monitoring are not established by the checked-in setup instructions.

## Recommended implementation order

1. Verify the actual production backend, active Supabase project and D1/R2 bindings without changing production data.
2. Select one backend for this AUREL deployment. Given the checked-in production variables and relational schema, keep Supabase if it is confirmed to contain the live data; retire the unused Worker path only after a verified backup and deployment test. If the live site is actually using Worker/D1/R2, choose that path instead and remove Supabase only after data migration.
3. Add a repeatable migration/backup process and schema-version tracking.
4. Add automated Supabase RLS tests for anonymous, authenticated non-admin and admin users (or production-equivalent Worker authorization tests).
5. Move all owner-specific identity configuration out of source code; use platform-managed, per-site configuration.
6. Add durable inquiry abuse protection, server-side validation and operational logging.
7. Only then expand staff roles and permissions.

## Verification limits

This is a source-code and configuration review. It does not claim that the live Supabase project, Cloudflare D1/R2 bindings, deployed Worker identity headers, production login, or production backup/restore were exercised. The public publishable Supabase key is not a service-role secret; never place a service-role key in frontend code or a public repository.
