# Production imports

Deployed October 20, 2026 after explicit user authorization. The production_imports migration is applied to live Supabase; app release 6ad7fddfc569e0deb297e729 is published.

Settings → Imports & Data Configurations is available to theater administrators. Download a blank CSV or copy the existing Drive production workbook. Replace its two demo rows, export the Data tab as CSV, upload, review and import. The target is always the selected theater. Accepted files: UTF-8 CSV, up to 1 MB and 100 productions.

Required: title, season_name, opening_date and closing_date. A new script also requires script_playwright. Existing seasons and optional venues must match exactly within the theater. Script title follows production title. Existing script metadata conflicts are rejected rather than silently changing the script. Dates accept YYYY-MM-DD and MM/DD/YYYY, must be real dates between 1900 and 2200, and closing must not precede opening. Optional runtime_minutes is an integer from 1 to 1440, including intermissions; runtime is independent display text.

The database validates every field and every row before inserting anything. The upload cannot select record IDs or theater IDs per row. Preview returns a fingerprint of the file and current lookup/production records; commit rejects a stale fingerprint. Duplicate production title/season pairs are rejected, including case-insensitive duplicates. A retry after a successful import cannot overwrite or duplicate that production. The private implementation requires a verified administrator and is exposed by an invoker wrapper, following the existing settings authorization pattern. All changes are transactional, audited, non-demo and unpublished. Source Draft/Publish and production_status are metadata, not authorization or publication controls.

This importer creates productions and any missing scripts. It creates no performances, milestones, venue records, season records, personnel, credits or sponsors. Image/program URLs and sponsor names remain source metadata only; no remote assets are fetched or uploaded. Series and rating are text; content warnings become a text array. Displayed production status is derived from dates. AEA remains unset until separately selected.

## Validation

- Typecheck, targeted lint and production build with Webpack passed. The default Turbopack build could not start its CSS worker in this environment (port binding denied).
- 23 unit tests, including strict CSV quoting, BOM/CRLF, multiline values, invalid headers, empty/oversized files and row limits.
- Local PGlite PostgreSQL exercised the actual migration against core schema with isolated authorization fixtures: preview makes no writes; verified administrator required; missing/cross-theater lookup denial; malformed dates/ranges; duplicate and script conflict denial; stale preview rejection; real-data flags; script reuse; and complete rollback after a deliberately induced late insert failure. Fixture authorization predicates do not substitute for live RLS validation after deployment.
- Browser fixture checked Settings navigation, upload → preview → import success, configuration links and 390px layout without horizontal page overflow. Fictional fixtures were local only and removed before final build.
- No real production was imported. Live migration and authorization checks passed. No real production was imported.

## Google Drive template review

Folder: https://drive.google.com/drive/folders/1sbUgh0DH4eoJUbeUY30YB23LMWi-k_3Q

All 14 workbooks were inspected and updated in place. Existing rows, source headers, sharing and folder placement were preserved, except for the additional optional runtime_minutes production column. The production guide now matches implemented validation, required run dates, date formatting and source-only media/sponsor fields. Demo runtimes were populated (135 and 115 minutes). The remaining guides explicitly say they are reference templates without upload workflows; obsolete WordPress import directions and automatic-publication claims were corrected. Reference term examples are no longer presented as live database inventory. Instruction rows were wrapped and resized to fit. Native readback verified content/formatting; production guide additionally inspected in Google Sheets. Full visual review of every unchanged reference tab was not performed.
