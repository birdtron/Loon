# Netlify migration status

Migration prepared on October 19, 2026 from main commit `4e21810c0b377fd2ee9b305024d1d801cb9184be`.

## Completed

- Standard Next.js scripts and Netlify build configuration; Sites, Vinext, Cloudflare, connector-preview and unused D1 scaffold removed.
- Existing Supabase Auth, Thanos authorization, business data, performance editing and AEA selection preserved.
- Locked dependency installation and TypeScript checks passed.
- Production build passed with `pnpm exec next build --webpack`. The default Turbopack build was blocked by this local environment's port-binding restriction; the Netlify build is a separate verification.
- Supabase reports healthy; security advisors returned no findings. Rollback-only tests verified unverified-owner denial, verified-owner access and editing, nonowner denial, metadata-spoofing denial and out-of-run date validation. Anonymous access was denied on all six business tables.
- No actual reserved owner account exists as of this check. No user credentials or live data were exported.
- Netlify project created in Bird & Co: `loon-production-workspace`, ID `2fbb500e-c396-42b0-8f01-5cbb3551c5d8`.
- `.netlify/` is ignored so machine-specific linking state is not committed.

## Deployment verification

- Published at https://loon-production-workspace.netlify.app on October 19, 2026. Successful deploy: `6ad654562286832410d5c7f2`; application source commit: `8522cf96a0084b08d138625a488056271af3456f`.
- The initial source upload omitted the Next.js adapter and served 404. Explicitly adding the unversioned `@netlify/plugin-nextjs` fixed it; the follow-up deploy includes the Next.js function and routing rules.
- HTTPS homepage returned 200 with the Loon title and application shell, and all seven referenced JavaScript bundles returned 200. No ChatGPT login redirect remains.
- Anonymous HTTPS requests using the publishable key returned 401 for all six business tables.
- These are build, database and HTTP checks, not a completed browser/login test.

## Remaining account actions
- Connect the existing Netlify project to GitHub `birdtron/Loon`, production branch `main`, for automatic builds. The connector's source-upload deployment does not itself establish Git continuous deployment.
- In Supabase Authentication > URL Configuration, set Site URL to https://loon-production-workspace.netlify.app and allow https://loon-production-workspace.netlify.app/ as a redirect. Preserve the old Sites redirect while it is a fallback.
- Owner creates their own password, confirms their reserved email, then signs in. Verify Thanos, production loading, logout, performance edits, AEA tier saves and persistence in a real browser.
- Keep the existing Sites deployment until the owner flow and edits pass. Database backups are still separate unfinished work.
