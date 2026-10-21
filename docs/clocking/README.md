# Clocking and Production Labor

Personnel select their production, department and role, optionally add notes, and tap **Clock in**. Supabase records the current date/time. **Clock out** records the finish date/time and finalizes the hours. There are no manual date/time or unpaid-break fields, and clients cannot submit timestamps or breaks to the punch API.

An active clock-in is stored in the database, survives refresh/sign-out, and is visible when the same person returns on another device. There can be only one active shift per person across productions. Repeated requests with the same clock-in ID or clock-out ID return the existing punch instead of double-counting. The history and Production Labor report include completed shifts; active shifts display their start timestamp and estimated elapsed hours separately. Server timestamps determine final totals. Overnight shifts use the theater-local clock-in date and can be finished even after more than 24 hours. This screen provides time tracking, not payroll or agreement-rule calculations.

Creative, staff/administrative, crew, and intern profiles qualify. Cast-only profiles are excluded unless marked as interns. Active non-cast/non-guest workspace roles can open clocking; a linked eligible profile is required for self clocking. An eligible linked Guest or Cast intern can also clock within their assigned productions. Existing invitation/approval and suspension rules continue to apply; there is no new self-service role grant.

Administrators, Production, Production Manager, Company Manager, Stage Manager and Assistant Stage Manager can clock eligible personnel in/out. Other eligible personnel can see their own shifts only. Production Labor returns aggregate personnel/production/department/role totals to eligible workspace members within accessible productions. Other people's individual shifts and notes are not included in the aggregate response. The demo remains read only.

The table is private with RLS, a deny-direct policy and no browser table grants. Public functions are invoker wrappers around bounded private functions with authenticated-user checks. The former manual time-entry RPC is revoked for browser roles. Per-entry and per-person locks, plus a unique index for active shifts, protect concurrent punches. Historical migration files preserve the original manual-entry schema; the follow-up migration switches it to automatic punches.

## Verification

- `node --experimental-strip-types --test tests/*.test.mjs`
- `pnpm typecheck`
- `pnpm build`
- Install `@electric-sql/pglite@0.3.14` in an isolated test directory, make it resolvable, then run `node docs/clocking/postgres-qa.mjs`. It tests the actual migrations in an in-memory PostgreSQL instance, with no production test data.

Production Labor has inclusive clock-in-date filters, production/personnel/department filters, chart grouping, an accessible chart description and legend, and a totals table. A person's multiple directory departments or production credits never multiply their hours.
