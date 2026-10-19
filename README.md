# Loon — Production Workspace

A private, Supabase-backed theater production workspace. First release: owner sign-in, two production dashboards, a 45-performance schedule, venue directory, performance editing, and per-production AEA tier selection.

## Development

Use Node 22+ and pnpm. Run `pnpm install --frozen-lockfile`, `pnpm exec tsc --noEmit`, then `pnpm build`. The source uses Next.js App Router conventions and Vinext to build for Cloudflare Workers. Sites hosting preserves its native ChatGPT sign-in boundary. Supabase Auth additionally establishes the database identity.

The URL and publishable key in `lib/supabase-config.ts` are intentionally browser-visible. They do not grant access: all application tables require verified global Thanos access through RLS. No service-role key is included.

## Database and demo

- `supabase/migrations/`: schema and authorization baseline.
- `supabase/seed-demo.sql`: rerunnable synthetic demo records and public venue information; account records excluded.
- `docs/security-checks.sql`: rollback-only authorization tests. Requires a trusted SQL administrator and an unbound owner reservation. No test accounts persist.
- `docs/architecture.md`: relationships, authorization, and current limits.
- `docs/recovery.md`: rebuild procedure and database-backup work still required.

Only the owner role is enabled. Other users cannot read or edit application records. Notifications, casting, reports, file uploads, ticketing, and Equity calculations are future work.

## Verification for the first release

TypeScript and production build pass. Database tests confirm a verified reserved owner can read and edit, an unverified owner is denied, user-metadata spoofing cannot grant Thanos, nonowners cannot see production rows, and out-of-run performance edits are rejected. The entire test transaction rolls back.

Owner email delivery and the first real login must be completed by the owner. Supabase Auth confirmation origins should match the deployed private Site; after confirming, return to Loon and sign in. GitHub retains code and migrations, not live database backups or uploaded files.
