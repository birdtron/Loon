# Loon: first working slice

Loon uses React and standard Next.js App Router, prepared for Netlify's automatic Next.js runtime. Supabase provides PostgreSQL, Auth, and row-level security. The login page is public; database operations require the owner's verified Supabase login. The browser receives only a publishable key, never a service-role key. The earlier ChatGPT Sites deployment remains a separate fallback until the replacement is verified.

## Data relationships

Theaters own seasons, scripts, venues, productions and calendar events. Productions reference their season, script and venue. Performances and production activities are calendar events. Categories are Performance, Rehearsal, Tech, Load-in, Strike, Meeting, and Other. Compound foreign keys reject cross-theater links. Timestamps are stored as timestamptz and shown in America/New_York; production opening and closing values are calendar dates.

## Owner access

A private reservation binds once to a verified, non-anonymous Supabase Auth account. A trigger adds the global Thanos grant. private.has_thanos checks the authenticated user against that grant. All six business tables require this predicate for every read and write. Other logged-in users and anonymous visitors receive no business data. No department roles are active yet.

Thanos is unrestricted within Loon's application authorization. It does not turn a browser session into a PostgreSQL superuser or a Supabase organization owner. Core data-integrity checks still apply. Additional administrative actions can be implemented behind the same owner authorization.

## Import and editing

The initial import resolves sheet names to generated UUIDs. Demo seed statements are rerunnable. Source metadata is retained in import_metadata. Adobe artwork share links are not treated as directly loadable images; the UI uses typographic artwork. Performance end times include each production's entire supplied runtime. Database validation rejects starts outside the production run and overlapping non-canceled venue bookings. Optimistic concurrency checks updated_at before saving an event.

## First-build limits

No casting, reports, notifications, ticketing, payroll calculations or file uploads are implemented. AEA flag and tier can be saved, but applicable agreement-year rules are not active. Incomplete draft productions may leave is_aea unknown until the owner selects it. Production status is derived from dates at display time; the old imported In Rehearsal values are historical metadata. Import review state Draft does not grant access or publish a website.

The Supabase sign-up confirmation template and redirect settings must be verified against the final hosted origin. The interface supports returning to sign in after confirming an email even if the configured confirmation redirect points elsewhere. Auth email deliverability and real owner sign-in require the owner to complete the flow; they cannot be proven by a build.


## Master Calendar

The default calendar displays 30 consecutive Eastern calendar dates. Production opening and closing dates generate read-only performance-run bars, inclusive of both dates. Actual performances and activities appear as separate timed events. Bars continue across week boundaries, and activities ending exactly at midnight exclude the following day. Date navigation uses calendar arithmetic across daylight saving changes.

The View selector switches between the 30-day calendar and an all-dates list. Production and series filters combine in both views; changing series clears incompatible production selections. Selecting a run opens the production; selecting an event edits that event. Calendar filters and dates remain in place when returning from a production opened from the calendar.

Activities may be scheduled outside production opening/closing dates. Performance validation remains restricted to the production run. Choosing a venue books the entire activity interval, and the existing transaction lock prevents overlapping non-canceled bookings across all categories. Activities without a venue are planning entries, not venue bookings. Activity edits use updated_at optimistic concurrency. Thanos RLS remains required for all reads and writes.

Verification: date/layout unit tests, production build, and local browser checks cover filter combinations, list/calendar switching, creating multi-day activities, invalid end dates, and phone layouts. docs/calendar-security-checks.sql tests owner/nonowner permissions and activity constraints inside a rolled-back transaction. The separate Supabase Auth advisor warning for disabled leaked-password protection is an account setting, not part of this schema change: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.
