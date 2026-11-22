# AUREL technical operator access (per independent client project)

This is **infrastructure access**, separate from agency Owner/Admin/Agent/Collaborator sign-in.
There is no hidden account, shared password, impersonation, or backdoor in the agency application.

## Operational model
- Each independently deployed agency website has a dedicated GitHub repository / deployment and Supabase project.
- The site-maintenance company retains separately named operator accounts with required access to GitHub, hosting and Supabase. The initial project owner grants access once as part of the website maintenance agreement; further routine maintenance does not need per-visit approval.
- No agency membership or app dashboard role is granted to operators by default. The app's normal RLS rules do not provide an operator bypass.
- Enable MFA for operator accounts, use least-privilege IAM roles, and prohibit shared credentials. Remove operator access immediately when employment/maintenance ends.
- Supabase service_role credentials must stay in trusted infrastructure only. Never embed them in a browser, distribute them by email, or commit them to source control.
- Logging: GitHub audit/activity logs, Supabase/hosting audit and deployment logs. Record incident reason, operator, scope and change. Keep audit data separate from normal listing content. Owners can receive maintenance summaries without approval prompts on each fix.
- Document in the service agreement who has ongoing infrastructure access and which records can be accessed during maintenance. Agency customer personal data should be accessed only when necessary for an agreed troubleshooting purpose.
- Back up the project before major schema operations; use reviewed migrations and CI before deploying.

## Provisioning checklist (requires real operator identities)
1. Add named team members to the GitHub repository / organization with appropriate permissions.
2. Invite the same people as separate members of the client's Supabase project, with MFA.
3. Configure hosting project access and a suitable deployment environment.
4. Configure audit retention, secrets rotation and backup/restore testing.
5. Verify one operator can diagnose a test fault without using an agency Owner account; verify revoked access is actually denied.

## Limits of current implementation
This runbook defines **the separate technical access model**. It does not automatically create infrastructure identities, connect services or grant permissions; those steps must be completed when the intended operator accounts are known.
Do not present it as an implemented, tested emergency-support login route.
