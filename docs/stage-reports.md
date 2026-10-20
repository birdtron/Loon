# Rehearsal and performance reports

Production → Stage Management contains Cast Scheduling, Rehearsal Reports, and Performance Reports. Stage Managers, Assistant Stage Managers, and Company Managers may save reports directly; existing explicit access overrides still apply. Department viewers and assigned guests/directors can read reports. Cast-only membership does not grant report access.

A rehearsal report covers one production's daily callboard. A performance report belongs to a specific calendar performance, allowing separate matinee and evening reports. Report dates use the theater timezone. Actual start/end times can cross midnight, up to 24 hours. Performance run time includes intermission.

Fields follow Roles and Rules_Loon: actual timings, general summary, union breaks for rehearsals, cancellation reasons and details, performance penalties/overtime, and a conditional fight-call answer when the production credits include a fight choreographer. Department note fields come from Stage Management Settings when a report is created. No report emails or notifications are sent. These are recorded answers, not automatic union compliance calculations.

The server pulls the deduplicated called cast from published rehearsal calls matching the production and date. Additional cast must have a cast credit on that production. Names and source are saved with the report; later callboard edits do not change them. “Refresh called cast from callboard” explicitly replaces that snapshot at the next save. The cast list records calls, not attendance.

Saving is atomic and idempotent on retry. Revision checks prevent overwriting another editor. A report retains its date when its linked performance is rescheduled. The report itself does not cancel or reschedule calendar events.

Validation: `tests/reports.test.mjs` covers date boundaries, deduplication, canceled calls, timing order, fight calls, cancellation and penalty details. `docs/reports-security-checks.sql` runs transactional rollback checks for authorized saving, cast privacy, read-only staff, assigned scope, explicit denies, duplicate reports, stale edits, invalid cast, snapshot preservation, historical dates and anonymous/direct-write restrictions. No test records are retained.
