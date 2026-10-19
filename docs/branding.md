# Loon visual identity

The interface follows the images in the Google Drive Loon / Mockups folder and Loon / Logo & Branding folder, reviewed October 19, 2026. The reference set includes the season and show dashboards, menu, callboard, scripts, cast, scheduling, measurements, media submission, reports, clocking and labor mockups, plus the baseline/theme and supplied logo.

## Palette and treatments

- Navy canvas: #20263e
- Aqua headings: #d0f4f4
- Body text: #b9d8dc
- Slate accent: #627ca6
- Panels and sidebar: gradients from #24365c to #597198
- Lavender actions: #62578e
- Pale yellow links and accents: #e0e1ac

Bold sans-serif headings, monospaced action/status text, rounded gradient panels, and colored status dots carry the reference system through all current screens. Small text uses lighter shades where needed for legibility. Responsive layouts retain the same identity on phones.

## Assets

- `public/brand/loon-logo.png`: supplied transparent Loon logo. Its original square canvas is preserved; CSS frames the artwork without changing the file.
- `public/posters/titus-andronicus.png`: supplied Titus Andronicus poster.
- `public/posters/romeo-and-juliet.png`: supplied Romeo and Juliet poster.

The posters appear on season cards and individual production pages in their full proportions. Next.js Image provides responsive delivery. Unrecognized future production titles use a neutral fallback instead of another show's poster.

This change styles the existing app. The additional departments and functions pictured in the mockups remain future work. Authentication, database authorization, performance validation, concurrency checks and AEA saves retain their existing behavior.
