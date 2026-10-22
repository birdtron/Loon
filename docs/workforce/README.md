# Workforce workspace

Three navigation screens share one set of tasks, people, production schedules and clock entries:

- **Clocking:** server-recorded in/out times, optional assigned task.
- **Labor Planning:** Monday–Sunday capacity and schedule, with Actual hours retaining the production labor report.
- **Task Tracking:** five status columns, task editing, per-assignee estimates, planned dates, attachments and validated CSV imports.

Standard capacity is 40 hours per person per week. Managers can save an override for a selected person/week. Company and show/rehearsal schedules reserve capacity; estimates and actuals remain separate. Estimates are divided evenly across planned dates for each assignee. Unplanned tasks are counted separately. Overlapping schedules cannot be saved. Linked calendar event edits are reflected on refresh; if calendar edits introduce overlaps, totals use interval unions and display a warning.

Eligible creative/staff/crew and interns retain clocking access. Personnel see their tasks and own weekly schedules/hours; production managers manage assignments, schedules and capacity. Assignees can advance work to In Review; managers mark Complete. Cast-only, suspended and anonymous users cannot use the labor workspace. Read-only demo login cannot write. Private attachment policies follow task visibility; files are limited to PDFs, images and text up to 10 MB.

Edits carry revision numbers. Stale saves fail with a refresh message. Import is transactional; a SHA-256 file key and deterministic row IDs prevent duplicates on retry. Archiving preserves clock history. Task status changes are recorded privately for audit.

## Demo

`supabase/seeds/workforce-demo.sql` creates 15 labeled fictional tasks across all five statuses, 42 scheduled blocks and 2 capacity overrides for **October 19–25, 2026**. Alex Morgan has 46 scheduled hours against the default 40, demonstrating overload. Twenty-four existing demo shifts can link to tasks; the existing 137.5 demo clocked hours are preserved. The seed uses existing fictional demo personnel and productions only, with deterministic IDs and repeat-safe inserts. It never modifies real clocked hours. Hide demo tasks/schedules using Include demo data; the actual labor report has its own demo-hours filter.

## Validation

- `node docs/workforce/postgres-qa.mjs` (requires `@electric-sql/pglite` in the test environment): runs existing clocking regression checks, workforce permission and mutation tests, calendar linkage, attachments, CSV retry/atomicity, and seed repeatability.
- `node --experimental-strip-types docs/workforce/unit-qa.ts`: week boundaries, per-assignee allocation, DST duration, union totals, CSV escaping and invalid data.
- `pnpm typecheck` and `pnpm build`.

Production migration: `20261022140752_workforce_planning.sql`. Private tables are inaccessible directly to browser roles; authenticated invoker RPCs call bounded private functions. No privileged browser keys are used.
