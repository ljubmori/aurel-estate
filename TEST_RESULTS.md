# Verification status

## Current Supabase-only branch

Latest checked commit: `1f51afef288c2b0cb50710eb0b6890a2753f6115`

<https://github.com/ljubmori/aurel-estate/actions/runs/44741591533>

- GitHub Actions: **passed**.
- `npm ci`: passed.
- `npm test`: passed (10 tests).
- `npm run build`: passed (TypeScript, Vite and static asset Worker packaging).
- The Worker tests verify that the static asset host does not expose the old D1/API/media endpoints.

## Not yet verified against the live Supabase project

- The SQL migration has not been executed against the target Supabase database.
- Supabase RLS behavior has not yet been integration-tested as anonymous, agent, admin and owner users.
- The real email/password administrator login and account provisioning have not been exercised.
- Supabase Storage uploads and permissions have not been tested against the live project.
- No production deployment has been made from this branch.

Do not mark AUREL production-ready until the migration is applied to the intended Supabase project and the authentication, RLS, data CRUD, inquiry submission and media upload flows have been tested there.
