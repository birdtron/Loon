# Clocking and Production Labor

Clocking records completed work using a person, production, theater-local work date, start/end timestamps, unpaid break minutes, one department, one role, and optional notes. Net hours are calculated from elapsed time, including overnight and daylight-saving transitions. The start must match the work date; future completion, overlapping shifts, zero/negative net time, and shifts longer than 24 hours are rejected. Adjacent shifts are allowed. Each entry has an immutable person, a revision, and creator/updater audit fields. Corrections update the existing entry rather than adding duplicate hours.

Creative, staff/administrative, crew, and intern profiles qualify. Cast-only profiles are excluded unless marked as interns. Active non-cast/non-guest workspace roles can open clocking; a linked eligible profile is required to submit one's own time. An eligible linked Guest or Cast intern can also enter time within their assigned productions. Existing invitation/approval and suspension rules continue to apply. There is no new self-service role grant.

Administrators, Production, Production Manager, Company Manager, Stage Manager and Assistant Stage Manager can record eligible personnel's time. Other eligible personnel can see and edit their own entries only. Production Labor returns aggregate personnel/production/department/role totals to eligible workspace members within their accessible productions. Other people's individual shifts and notes are not included in that aggregate response. The demo remains read only.

The new table is in the private schema with RLS and no direct browser grants. Public functions are invoker wrappers around bounded private functions with explicit authenticated-user checks. RPCs verify theater membership, target-person eligibility, production scope, immutable ownership, stale revisions and overlaps on every save. Per-entry and per-person transaction locks serialize competing writes.

## Verification

- `node --experimental-strip-types --test tests/*.test.mjs`
- `pnpm typecheck`
- `pnpm build`
- Install `@electric-sql/pglite@0.3.14` in an isolated test directory, make it resolvable, then run `node docs/clocking/postgres-qa.mjs`. This exercises the actual schema in an in-memory PostgreSQL instance; no production test data is inserted.

Production Labor has inclusive date filters by work date, production/personnel/department filters, a grouping selector, an accessible pie-chart description and legend, and a totals table. Hours are counted once per entry, with no multiplication from a person's multiple directory departments or production credits. Overnight work is assigned entirely to the start/work date, not split across reporting days. These are labor-hour records; pay rates, overtime and payroll processing are outside this feature.
