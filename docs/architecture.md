# Loon: first working slice

Loon uses React and Next.js conventions, built with Vinext for Cloudflare Workers hosting. Supabase provides PostgreSQL, Auth, and row-level security. The private hosting boundary uses ChatGPT sign-in; database operations additionally require the owner's verified Supabase login. These are separate identities, and the browser never receives a service-role key.

## Data relationships

Theaters own seasons, scripts, venues, productions and calendar events. Productions reference their season, script and venue. Each performance is a calendar event with category Performance. Compound foreign keys reject cross-theater links. Timestamps are stored as timestamptz and shown in America/New_York; production opening and closing values are calendar dates.

## Owner access

A private reservation binds once to a verified, non-anonymous Supabase Auth account. A trigger adds the global Thanos grant. private.has_thanos checks the authenticated user against that grant. All six business tables require this predicate for every read and write. Other logged-in users and anonymous visitors receive no business data. No department roles are active yet.

Thanos is unrestricted within Loon's application authorization. It does not turn a browser session into a PostgreSQL superuser or a Supabase organization owner. Core data-integrity checks still apply. Additional administrative actions can be implemented behind the same owner authorization.

## Import and editing

The initial import resolves sheet names to generated UUIDs. Demo seed statements are rerunnable. Source metadata is retained in import_metadata. Adobe artwork share links are not treated as directly loadable images; the UI uses typographic artwork. Performance end times include each production's entire supplied runtime. Database validation rejects starts outside the production run and overlapping non-canceled venue bookings. Optimistic concurrency checks updated_at before saving an event.

## First-build limits

No casting, reports, notifications, ticketing, payroll calculations or file uploads are implemented. AEA flag and tier can be saved, but applicable agreement-year rules are not active. Incomplete draft productions may leave is_aea unknown until the owner selects it. Production status is derived from dates at display time; the old imported In Rehearsal values are historical metadata. Import review state Draft does not grant access or publish a website.

The Supabase sign-up confirmation template and redirect settings must be verified against the final hosted origin. The interface supports returning to sign in after confirming an email even if the configured confirmation redirect points elsewhere. Auth email deliverability and real owner sign-in require the owner to complete the flow; they cannot be proven by a build.
