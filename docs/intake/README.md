# Personnel intake and Company Management

Deployed October 20, 2026 after the user explicitly approved all pending changes. Imports, personnel contacts and personnel intake migrations are applied to production. Corrected app release 6ad7fddfc569e0deb297e729 is live. No real invitations, submissions or personnel records were created by verification.

## Workflow

Company Management appears in the workspace navigation for verified theater administrators/platform owners and active Company Managers with effective Stage edit and Personnel view access. Other stage management roles can continue using contact details, but cannot review intake submissions or access résumés.

The manager creates an individual, single-use invitation for the theater’s configured current season. The recipient name is required; an optional email restriction requires that address at submission. The link expires after 14 days and can be revoked before use. The dashboard provides a copyable link, but sends no email. The token is returned once and stored only as a SHA-256 digest in the database. It travels in the URL fragment, which is excluded from HTTP requests and referrers. The form route is `/intake`, with noindex/nofollow and no-referrer metadata. Recipients do not need a Loon account.

The form follows the supplied navy/aqua mockup, including full and known-as names, headshot or bird avatar, Cast/Creative/Admin branches, multiple production roles, email/phone/address, bio, favorite Shakespeare work, union affiliations, intern status, emergency contact and optional résumé. Full name, email, area and relevant work details are required; address/emergency details and attachments are optional. Consent to store and review the data is required. Admin maps to the Staff personnel type; it never grants an administrative login role. The mockup’s name/search control is implemented as a text field: the public form does not expose or search personnel records. Production choices are limited to the invitation’s theater and season.

Submissions go only into the private holding area. They do not become directory records, credits, contacts or memberships until approved. Company Management can review all fields and attachments, reject with an internal reason, approve as a new person, or explicitly match an existing person. Possible matches are highlighted by name/email; creating a separate same-name/email person requires explicit confirmation. Replacing an existing profile/contact/photo requires an affirmative checkbox and version checks. Existing personnel types, production credits and a previously saved résumé are retained; supplied profile/contact fields and the photo/avatar are replaced after that confirmation.

Approval atomically creates/updates personnel, restricted contact details, production credits, a season membership and private media, then marks the submission approved. Repeated approval does not duplicate records. Failed validation or a late insert failure rolls everything back. A changed current season pauses approval and invalidates unused older-season links; it never silently moves people into a different season. Restore the original season or issue a fresh invitation for the new current season.

## Data boundaries

- `private.personnel_intake_links`, `private.personnel_intake_submissions` and `private.personnel_intake_media` have RLS and no direct anonymous/authenticated table access.
- Anonymous form methods live in the narrow, non-exposed `intake_api` schema and are reached through invoker wrappers. Only token-based form metadata and submission methods are granted to anonymous clients. The migration does not grant anonymous usage on the existing private schema.
- Manager operations use authenticated invoker wrappers and private definer implementations with explicit verified-user/theater/role checks and empty search paths.
- Pending metadata lists exclude the token digest, raw token, attachments and full contact payload. Full submissions require a manager’s separate authorized detail read.
- Approved headshots require personnel visibility; résumés require Company Management access. Media are not placed in public storage. The 14 generic profile icons are public artwork, with no association to an identifiable person until chosen and approved.
- Headshots accept JPG/PNG/WebP up to 4 MB, are decoded and normalized to JPEG in the browser, resized to at most 1200px and bounded to 512 KB in storage. Résumés accept PDF up to 2 MB. The database rechecks data URLs, base64, sizes and signatures. It does not perform malware scanning or certify PDF contents. Attachments are downloaded rather than rendered as HTML.
- Payload keys, email, lengths, enum values, consent, assignments and every theater/season relationship are validated in the database. Postal codes and phone numbers remain text. Anonymous requests cannot choose identities, grant login roles or read submission payloads.
- No draft contact data is saved to browser storage. Retries with the same request ID and identical payload return the same receipt; reusing a consumed link for another payload/request is rejected.

Approved personnel participate in season filtering through `public.personnel_seasons`. Existing credits still qualify people for a season; legacy non-cast profiles without an explicit season membership preserve their previous directory behavior. The regular personnel-contact editor also gains the personal phone number shown in the mockup.

## Artwork

Mockup: https://drive.google.com/file/d/1YYtSf-Y7knKcIUymTn8NyJTVNOjy1Y1e/view

Supplied icons: https://drive.google.com/drive/folders/1ro-X1c8AY4GSFqeHx2ypi8iYbMjHtC8S

All 14 original PNGs were downloaded without altering their bytes and are included under `public/profile-icons`. `profile-icon-sources.json` records the source names/IDs. Selection IDs are `bird-00` through `bird-13`; descriptive display labels do not change the artwork. No generated replacement artwork is used.

## Verification and release status

- 31 unit tests passed, including intake validation, Company Management role gating, contact normalization and explicit season membership/legacy filtering.
- Local PostgreSQL/PGlite ran the actual migrations and existing authorization helper definitions. Tests cover token-scoped anonymous metadata/submission, no public holding-area reads, idempotent submit/approve, optional PDF/JPEG attachments, new and matched people, preserved types/credits, stale profile/contact denial, duplicate rejection, rejection, revocation, expiration, recipient email binding, season changes, role denial, suspended/explicit-deny access, media scope and complete rollback after a deliberately failed late credit insert. All data are isolated local fixtures.
- Browser fixtures verified the full form, Cast/Creative/Admin conditionals, add/remove production roles, headshot processing, switching to an original bird icon, résumé selection, consent, submit/receipt, pending queue, detail review, approval/approved history and link creation. Form and review both fit 390px without horizontal page overflow. Desktop and phone screenshots are in the project outputs folder.
- New modules pass targeted lint. TypeScript and the production build pass using Webpack; the temporary fixture route was removed before the build.
- Live migration, security advisors and production publication completed. Trusted rollback verification exercised existing-owner dashboard access, invitation creation and token resolution; anonymous callers cannot access private schema or create invitations. Browser verified production sign-in and incomplete intake-link handling. No signed-in manager browser session was available, so authenticated browser workflow verification remains covered by the local fixtures and live rollback checks. No shareable live invitation has been issued.

The local test source is `postgres-qa.mjs`; run with `@electric-sql/pglite` available from a temporary dependency installation. It creates its own isolated database and never connects to Supabase. The production migrations were applied in order: production imports, personnel contacts, personnel intake. The first published build exposed a missing Next.js server dependency from symlinked modules; the fix-forward release includes real local dependencies. Future manual deploys must package actual local modules. The demo-login chat is coordinating a subsequent combined release.
