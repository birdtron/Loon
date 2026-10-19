# Loon — Production Workspace

A private, Supabase-backed theater production workspace. First release: owner sign-in, two production dashboards, a 30-day Master Calendar with production/series filters and activity scheduling, a 45-performance demo schedule, venue directory, performance editing, and per-production AEA tier selection.

## Development

Use Node 22.13+ and pnpm 11.25.0. Run `pnpm install --frozen-lockfile`, `pnpm typecheck`, then `pnpm build`. Start locally with `pnpm dev`, or serve the production build with `pnpm start`. The app uses standard Next.js App Router; Netlify automatically supplies its Next.js runtime.

The default URL and publishable key in `lib/supabase-config.ts` are intentionally browser-visible. Override them at build time with `NEXT_PUBLIC_SUPABASE_URL` and `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` if needed. They do not grant access: all application tables require verified global Thanos access through RLS. No service-role key is included.

## Database and demo

- `supabase/migrations/`: schema and authorization baseline.
- `supabase/seed-demo.sql`: rerunnable synthetic demo records and public venue information; account records excluded.
- `docs/security-checks.sql`: rollback-only authorization tests. Requires a trusted SQL administrator and an unbound owner reservation. No test accounts persist.
- `docs/architecture.md`: relationships, authorization, and current limits.
- `docs/recovery.md`: rebuild procedure and database-backup work still required.

Only the owner role is enabled. Other users cannot read or edit application records. Notifications, casting, reports, file uploads, ticketing, and Equity calculations are future work.

## Verification for the first release

TypeScript and production build pass. Database tests confirm a verified reserved owner can read and edit, an unverified owner is denied, user-metadata spoofing cannot grant Thanos, nonowners cannot see production rows, and out-of-run performance edits are rejected. The entire test transaction rolls back.

Owner email delivery and the first real login must be completed by the owner. Supabase Auth confirmation origins should match the deployed Netlify origin; after confirming, return to Loon and sign in. GitHub retains code and migrations, not live database backups or uploaded files.

## Netlify migration

`netlify.toml` configures `pnpm build` and `.next`. Connect this repository’s `main` branch to Netlify for automatic builds; never upload `.next` as a plain static site. No ChatGPT login is required on this version. Supabase login and database authorization still protect business records. See `docs/migration-status.md` for verified progress and remaining account setup.

Calendar date tests: `node --experimental-strip-types --test tests/calendar.test.mjs`. See `docs/calendar-security-checks.sql` for rollback-only database checks on an installation with a verified owner.

Personnel: 56 fictional demo profiles, 63 production credits, 47 attributed portraits, production/type/department filters, profile editing, and private headshot upload/replacement. See docs/headshot-sources.md for sources and the nine profiles awaiting an authorized upload.

Design changes must follow [DESIGN.md](DESIGN.md), the researched Loon design standard and release checklist.

Cast Scheduling: open a production → Stage Management → Cast Scheduling. Set the date/time, act/scene and work, location, and called cast; Submit to callboard publishes the rehearsal to that date and the master calendar. Edit or cancel calls from the production's Callboard or Scheduled calls. The main Callboard supports date and show filters.

Settings are available from the gear beside the lower-left profile icon. Includes personal preferences, theater identity/current season/timezone, email access reservations and role/delegation controls, rehearsal defaults, and reusable calendar templates. Reservations send no emails. Calendar templates preview dates and create draft activities without changing existing schedules. See `docs/architecture.md` and the rollback-only `docs/settings-security-checks.sql`.
