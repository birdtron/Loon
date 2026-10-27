# Rehearsal schedules

Stage Management now contains **Call Board Schedule** for next-day calls and **Rehearsal Schedules** for show-wide planning. New call forms default to tomorrow. Existing calls and their contents are preserved.

Select a show in Rehearsal Schedules, then enter an event or download and fill the CSV template. Required columns: date, start_time, end_time, venue, event_name. Optional: scene, cast_called. Dates use YYYY-MM-DD; times use HH:MM in the account timezone and end on the same day. Exact venue names or IDs are accepted. Separate exact cast display names or IDs with |. Every cast member must be credited to the selected show. Blank cast means unspecified, not full cast. Multiple child casts are supported as ordinary cast selections.

Imports preview every row, reject unknown or ambiguous references, and save up to 500 entries in one transaction. A failed row or venue conflict rolls back the entire batch. Repeated submissions with the same IDs return existing entries; repeated file uploads detect active duplicate events. Editing checks updated_at to prevent overwriting another user's changes. Cancellation retains history and releases the venue booking.

Entries appear on the master and venue calendars. Opening one from the calendar returns to Rehearsal Schedules. They never create rehearsal_calls or rehearsal_call_cast records, callboard entries, or actor check-in calls. The database rejects attempts to turn a planned schedule entry into a callboard call. Planned rehearsals and daily rehearsal calls for the same show may share a venue/time without copying any data. Conflicts within either layer and between shows remain blocked.

Stage-edit permission is required for writes. Existing account, show, calendar visibility, and read-only demo policies apply. No live migration, import, or deployment is performed by this PR. Apply the migration before deploying the UI after review. Source backup: loon-before-rehearsal-schedules.tar.gz in task outputs; excludes live database, Auth, and Storage.

Validation: node --experimental-strip-types --test tests/*.test.mjs; next typegen and tsc --noEmit; next build --webpack; scripts/test-rehearsal-schedules-db.mjs with PGLITE_MODULE pointing to an installed PGlite module. Database fixtures load the relevant real migrations with local Auth and Storage stubs. Browser checks use intercepted fixture responses, not live accounts.
