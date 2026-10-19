# Source and database recovery

GitHub repository: birdtron/Loon. Save source changes, migration SQL, synthetic fixtures and documentation there at every completed milestone. GitHub code history is not a live database backup. Never commit production database exports, passwords, access tokens, service-role keys, owner-account records or private uploads to this public repository.

## Rebuild the demo

1. Create a Supabase project and apply SQL under supabase/migrations in filename order, using the Supabase migration tooling or SQL editor. This initial repository reproduces the current schema; timestamps document the baseline rather than the remote migration history IDs.
2. Use a trusted administrator to insert the intended lowercase owner email into private.platform_owner_reservations with security_level Thanos. The email must be independently verified by Supabase Auth before the one-time trigger grants access. Account records are deliberately omitted from migration source.
3. Run supabase/seed-demo.sql to restore the public venue information and fictional demo productions/performances. The seed does not restore user accounts or uploads.
4. Configure the project's publishable browser URL/key in lib/supabase-config.ts. Set Auth Site URL and allowed confirmation redirect origins to the actual deployed origin. Use your own password and verify your email.
5. Install locked dependencies with pnpm install --frozen-lockfile, type-check, and run the build. Deploy privately through the Sites workflow or adapt the Vinext deployment to your own infrastructure.

## Production backup work still needed

Confirm the Supabase plan's automated backup retention and point-in-time recovery availability before live production use. Establish encrypted off-site database backups and a separate Storage-object backup policy. Perform a restore drill. This first build does not configure scheduled database backups or claim that GitHub backs up live records.
