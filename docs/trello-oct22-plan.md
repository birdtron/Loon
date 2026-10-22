# October 22 Trello batch

Base: origin/main a3ef0cd. Review all four To do cards before edits; preserve existing labor, intake, navigation work. Target one production deploy after shared verification; no intermediate preview deploys.

- Overall notes: AFM/UMAW/AGMA options; production Overview/Message board/Callboard tabs; stage tools remain in department menu; messages with author/time and per-user thumbs-up; private signed-contract uploads for Company Manager/Super Admin; emergency contact restriction; portfolio URL; outlined transparent menu scrollbar; amber show-critical task block; venue detail with document placeholders and venue-only calendar; locked menu icon.
- Actor Check In: tablet-friendly daily roster from published rehearsal calls, check-in submission, stage roster feed, theater-local midnight rollover via dated records. Staff may check in selected actors; linked cast may check in themselves. Poll only while visible, every 15 seconds.
- Alignment: invitation button bottom-align with approval access select.
- Labor Planning: larger numbers, daily >8h red text, zero yellow, 0<h<=8 green, >40h row red; weekday-only columns and date range in weekly header.

Verify schema privileges and role boundaries, date rollover, duplicate-safe submissions/reactions, frontend tests/typecheck/build, browser UI at tablet/desktop, and live deployment. Mark Trello complete only after verification. Do not send messages or invitations.

## Verification

- Production build and TypeScript pass; new components pass focused lint. Existing shared calendar retains its pre-existing effect lint finding.
- 39 existing/updated unit tests pass. Transaction-only database tests verify role boundaries, same-day roster, duplicate safety, prior-day reset, message reactions, production scope, and demo/anonymous denial; all fixtures roll back.
- Browser checked production tabs, scoped callboard, messages, venue calendar, labor table and exact button-bottom alignment. Actor check-in verified at 820 × 1180.
- New private tables have explicit deny policies, and contracts use a private 10 MB bucket. Security advisor has no new findings; pre-existing leaked-password-protection setting remains unchanged.
