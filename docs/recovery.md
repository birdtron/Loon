# Source and database recovery

GitHub repository: birdtron/Loon. Save source changes, migration SQL, synthetic fixtures and documentation there at every completed milestone. GitHub code history is not a live database backup. Never commit production database exports, passwords, access tokens, service-role keys, owner-account records or private uploads to this public repository.

## Existing installation

Use the existing Supabase project `somsipbtsjmusghfwbdu` for the Netlify migration. Do not recreate or reseed it. The old Sites source is retained in GitHub at `4e21810c0b377fd2ee9b305024d1d801cb9184be`. Leave its deployment in place until real owner login and saves are verified on Netlify.

## Rebuild the demo

1. For disaster recovery only, create a Supabase project and apply SQL under supabase/migrations in filename order, using the Supabase migration tooling or SQL editor. This initial repository reproduces the current schema; timestamps document the baseline rather than the remote migration history IDs.
2. Use a trusted administrator to insert the intended lowercase owner email into private.platform_owner_reservations with security_level Thanos. The email must be independently verified by Supabase Auth before the one-time trigger grants access. Account records are deliberately omitted from migration source.
3. Run supabase/seed-demo.sql to restore the public venue information and fictional demo productions/performances. The seed does not restore user accounts or uploads.
4. Configure the project's publishable browser URL/key in lib/supabase-config.ts. Set Auth Site URL and allowed confirmation redirect origins to the actual deployed origin. Use your own password and verify your email.
5. Install locked dependencies with pnpm install --frozen-lockfile, run pnpm typecheck, and run pnpm build. Connect the GitHub repository to Netlify, with main as the production branch, pnpm build as the build command, and .next as the publish directory. Netlify automatically installs its Next.js adapter. Set Supabase Auth Site URL and redirect allowlist to the resulting HTTPS origin.

## Production backup work still needed

Confirm the Supabase plan's automated backup retention and point-in-time recovery availability before live production use. Establish encrypted off-site database backups and a separate Storage-object backup policy. Perform a restore drill. This first build does not configure scheduled database backups or claim that GitHub backs up live records.

Personnel schema: `20261019182146_personnel_directory.sql`. Synthetic source import: `supabase/seeds/personnel-demo.sql` (idempotent, preserves existing profiles). Demo portraits and attribution are versioned under `public/headshots`; uploaded headshots live separately in the private Supabase bucket and require storage backup. Profile changes use updated_at to reject stale edits. The directory cannot create login accounts or grant roles.

Cast scheduling schema: `20261019191421_cast_scheduling.sql`. Calendar events remain the canonical time/status source; `rehearsal_calls` and `rehearsal_call_cast` depend on those event IDs. Back up all three tables together. Calls are submitted via `save_rehearsal_call` in one transaction. No rehearsal test seed is applied to production. Security integration checks are in docs/cast-scheduling-security-checks.sql and roll back their fixtures.

`20261019192435_parallel_rehearsal_calls.sql` replaces the duplicate-start constraint with a partial unique index for non-rehearsals. The performance seed uses that index's predicate.

## October 20 Trello batch

Before this batch, a verified Git bundle and source archive preserved commit `c734ed9cc9fd444dba290630335509de7456033b`; the published Netlify deploy was `6ad6db165115afdfdc914748`. A private local snapshot captured stage report records and their save function/policies before the critical-note migration. These backups are outside the repository. They do not constitute a full Supabase/Auth/Storage backup.

The batch adds `show_critical_notes`, its restricted resolution RPC, and a trigger on reports. Existing report fields and records are retained. Email delivery is deliberately deferred; future recipients are the production’s Creative credits. Source history preserves the prior application; any recovery involving new critical notes must preserve their current records before changing the schema.

Verification: 19 existing unit tests, TypeScript and production build passed; database report/call and critical-note security suites passed in rolled-back transactions. Browser checks use synthetic data and cover month/list views, editing, persistent cast selection, critical-note resolution, and 390px layout. Supabase security review found an existing account setting warning: leaked-password protection is disabled; no table/RLS findings.
