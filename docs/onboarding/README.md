# Company-issued login and personnel onboarding

Deployed October 20, 2026 (America/New_York); login_required_intake is applied to production. This batch covers all eight items read from the two Loon To Do cards: Personnel intake form and Production Page.

## Workflow

1. Company Management issues an invitation with a required email and the workspace role to activate after approval. Choices are Cast, Guest, Director and Production. Additional or editing roles remain administrator-managed in Users & Access.
2. The recipient opens the invitation, creates a login with their own password or signs in, and verifies their email. Signup is allowed only for active, current-season invitations or existing administrator-issued memberships/owner reservation. The database enforces this even if the UI is bypassed.
3. A new account has no theater membership. It can only see its own onboarding status and complete its own email-bound intake. Anonymous calls cannot read the form or submit it. A forwarded link cannot be used by a different verified account. Read-only demo accounts cannot submit intake.
4. Company Management reviews the submission. Approval, profile/contact/media/credits/season membership and initial workspace access occur in one transaction. Rejection grants no membership. Existing access—including inactive membership, explicit denies, delegations and roles—is preserved. An identity mismatch rolls back approval. Legacy pre-login submissions remain reviewable without account activation.
5. Recipients can sign in at the main page to resume intake or see pending/rejected status. Approval enables their assigned workspace access. There are no shared passwords and Loon does not send manager invitations automatically.

Invitations expire after 14 days. Unused expired/revoked or wrong-season invitations cannot create accounts or submit intake. Duplicate submission and approval retries remain idempotent. Private details and resumes retain the existing authorization model.

## UI batch

- Large Loon logo on its own line; theater branding on intake and invitation screens.
- Profile options have hidden native radio inputs for accessibility, with no visible radio dots or selection rectangles; selection uses the bird glow/name underline and a keyboard focus outline.
- Union text highlights when selected; hidden native checkboxes preserve keyboard and screen-reader access.
- Show- and area-specific role suggestions use existing credit labels only, with no personnel identities exposed. Typed exact matches normalize capitalization; new typed roles remain available for Company Management review. Changing show clears its old role.
- Larger responsive production title.
- Callboard groups each production's notes and daily schedule in a distinct labeled section. Existing date/show filters, resolved notes and editing permissions are preserved.

## Branding source

The Trello attachment was identified as logo-orlando-shakes.png, but its download required a Trello browser login unavailable in this session. The bundled Orlando Shakes logo is the official artwork from https://orlandoshakes.org/about-us/press-room/ , downloaded from https://orlandoshakes.org/wp-content/uploads/2025/12/Orlando-Shakes_CMYK_FullColor.png . The server returned WebP bytes; stored as public/brand/orlando-shakes.webp without alteration. A theater-configured logo takes priority; the fallback applies only to Orlando Shakespeare Theater / Orlando Shakes.

## Validation

- 33 unit tests, TypeScript and targeted lint checks.
- Isolated PGlite PostgreSQL exercises actual migration functions and workspace permission rules: issued-only signup, verified identity binding, anonymous denial, limited intake, scoped activation, retries, existing permissions, rejection, revocation, read-only demo denial and complete rollback after a late membership/profile identity conflict.
- Local fictional browser fixtures verify show-specific suggestions, typed-match normalization, avatar/union selection, successful submission, manager invitation controls and show-separated Callboard. Phone layout has no horizontal overflow. Fixtures are removed from production source.
- Email delivery and a real recipient's signup/verification are not exercised by local fixtures; no real invitations or recipients are created for QA.

The PostgreSQL test source is postgres-qa.mjs. Run from the repository with @electric-sql/pglite available in a temporary dependency installation; it does not connect to Supabase.

Live rollback verification passed: issued invitation, restricted signup, own authenticated intake, pending account without membership, approval to Production view access with no edit/admin permission, and anonymous form access denial. The transaction left no test records behind. Security advisors report no new database issue; the existing Auth leaked-password warning remains.
