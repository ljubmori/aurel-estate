# Verification status

## Latest verified branch

Branch: `feature/supabase-single-backend`

Commit: `7ecfe28ef3b3e6bc9ab5d2c214b49e3d67232e54`

GitHub Actions: <https://github.com/ljubmori/aurel-estate/actions/runs/44796616290>

<badge>All automated checks passed</badge>

- `npm ci`: passed.
- `npm test`: passed (10 Node tests).
- `npm run build`: passed (TypeScript, Vite and static Worker packaging).
- PostgreSQL 16 test database bootstrapped with Supabase-compatible `auth` and `storage` schemas.
- Base schema and demo seed applied.
- Complete AUREL migration applied twice successfully to verify rerun safety.
- SQL smoke tests passed for:
  - anonymous visitors can read published properties but not drafts
  - agent membership, creator attribution, agency-wide listing read and own-listing edit
  - non-members cannot read draft properties
  - price history records the initial price and later price changes
  - public inquiry creates/links a CRM client
  - viewing inquiry creates a dedicated viewing request
  - owner can upload media and an agent without upload rights is blocked
  - publication approval defaults and role-level publishing override
  - an agent can edit an already-published listing without accidentally unpublishing it
  - agency membership changes are written to the audit log
  - the last active owner cannot be deactivated or removed

## Still requires the real Supabase project

These checks ran against a clean PostgreSQL 16 test database that mimics the Supabase Auth and Storage schemas. They do **not** prove that the configured Supabase project has been migrated or that its live services work.

- The migration has not been applied to the actual Supabase project.
- Real Supabase Auth email/password sign-in and administrator provisioning have not been exercised.
- Real Storage object uploads/downloads have not been tested against Supabase.
- Production deployment and domain redirect settings have not been verified.

Do not mark AUREL production-ready until the actual Supabase project is connected, the migration is applied to the intended project, and live authentication, RLS, CRUD, inquiry, viewing-request and media-upload flows are verified.
