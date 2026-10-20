# Loon design standard

Reviewed October 19, 2026. Use this document for every new screen and design change. The direction is a theater production desk: show artwork, schedules, credits, and venue information. Preserve the supplied logo, posters, navy/aqua palette, and compact personnel tile/list options.

These are review constraints, not an AI detector. Familiar patterns can be useful. Never break a usable convention merely to look unusual.

## What to avoid

| Avoid | Required choice for Loon | Basis |
| --- | --- | --- |
| Interchangeable startup layouts with no theater context. | Organize around productions, calls, people, and venues. | A, C |
| Unmodified component-library styling presented as a finished identity. | Use Loon's own colors, type roles, artwork, and spacing. | B |
| Purple gradients, glow, or glass applied as a universal treatment. | Use solid work surfaces; reserve the supplied slate gradient for the navigation rail. | B; Loon judgment |
| Every section boxed into the same rounded card. | Posters get tiles, venue facts get rows, schedules get grids/tables, biographies get sections. | A, B; Loon judgment |
| Every label, icon, and secondary fact competing at equal weight. | Give names and tasks priority; group their supporting facts nearby. | A |
| Spacing based on visual symmetry rather than relationships. | Keep a label with its value and an action with the thing it changes. | A |
| Arbitrary type choices, decorative monospace, or a new font per screen. | Geist for controls, data, and page titles (user-requested October 20 update). Use local licensed fonts. | B; Loon judgment |
| Hero slogans, repeated welcome headings, backend badges, or fake progress statistics. | Use task names, real counts, short instructions, and honest states. | C; playbook; Loon judgment |
| Generic illustrations or invented people used to fill space. | Use supplied show posters and verified attributed portraits; mark missing photos. Keep test data clearly labeled. | Loon judgment |
| Tiny pale labels, color-only status, invisible focus, and cramped controls. | Check contrast, keyboard focus, readable labels, text status, and target spacing. | D |
| Hover lifts, glowing status dots, decorative rings, or motion without a purpose. | Use border/background feedback and clear saving/error states. Respect reduced motion. | Loon judgment |
| Desktop screenshots accepted as evidence that the product works. | Check narrow layouts, long content, empty results, filters, profile edits, and navigation. | A, D |
| Replacing the generic SaaS look with an equally generic beige/serif or terminal theme. | Justify each choice against Loon's content and user-approved references. | B, C; Loon judgment |
| Treating novelty as a usability goal. | Keep recognizable search, labeled forms, calendar navigation, and view controls. | A, D; Loon judgment |

## Source notes

A. [NN/g: AI Prototyping in Real Design Contexts](https://www.nngroup.com/articles/ai-prototyping/), October 2025, reviewed August 2026. Its evaluation found weak hierarchy, grouping, contrast, and spacing alongside generic visual defaults. This is a contextual evaluation, not proof that a particular style identifies AI authorship.

B. [Anthropic: Improving frontend design through Skills](https://claude.com/es/resources/articles/improving-frontend-design-through-skills), November 2025, and [Harness design for long-running application development](https://www.anthropic.com/engineering/harness-design-long-running-apps), March 2026. These primary accounts describe predictable generation defaults and explicit design criteria. They are vendor observations, not independent population studies. Their suggested decorative alternatives are not automatically appropriate for a working theater app.

C. [NN/g: UX-Context Design](https://www.nngroup.com/articles/ux-context-design/), July 2026. Product-specific research, constraints, and standards supply direction missing from broad prompts. Loon's own content and established references therefore take precedence over trend lists.

D. [W3C: Contrast (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [Target Size (Minimum)](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html). Normal text generally needs 4.5:1 contrast; large text needs 3:1. The AA target criterion uses 24 CSS pixels with specified exceptions, including spacing. Accessibility is a requirement independent of how a design was produced.

The user's Anti_AI_Isms_Playbook.md remains the companion writing reference: use concrete language; omit hype, forced metaphors, and boilerplate summaries. It does not prescribe a visual palette or layout.

## Release review

Confirm the page has a specific theater task and a clear primary action. Check the real artwork, data, source attribution, and test labels. Review hierarchy, contrast, focus, target spacing, and a 390-pixel viewport. Exercise existing filters and edits; retain tile/list preferences. Document any deliberate exception here. A screenshot and a successful build support the review; neither is a complete accessibility audit.

## Applied review, October 19, 2026

Reviewed sign-in, season, production details, calendar/list, venues, personnel tiles/list, and profiles. Removed repeated gradient cards, glow, decorative rings, hover lifts, backend badges, and promotional filler. Added local fonts, quieter surfaces, venue rows, readable supporting type, correct page labels, and scroll-to-top when navigating. Kept artwork, brand colors, calendar semantics, attribution, test labels, and private upload behavior.

Browser checks covered calendar/list switching, production filtering, profile navigation, personnel view switching, and phone widths for sign-in, venues, and personnel. Static foreground/background contrast was checked for the main palette. Typecheck, existing tests, and the production build passed. This review does not establish full WCAG conformance or guarantee how any individual will judge authorship.
