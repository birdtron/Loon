# Les Misérables — review before deployment

Prepared on branch `test/les-miserables-musical`, based on GitHub `main` (`a9a3114`). This is a fictional test production, not an announcement or a claim about real engagements. Existing celebrity demo profiles are reused as fictional test assignments.

- **Theater:** Orlando Shakespeare Theater
- **Venue:** Margeson Theater; parallel ensemble rehearsal in Santos Dantin Studio Theater
- **Season:** 26–27 Season
- **Run:** May 7–30, 2027; rehearsals begin April 6
- **Runtime:** 180 minutes, including a 20-minute intermission
- **Format:** Musical, sung-through; music by Claude-Michel Schönberg
- **Test agreement:** AEA Tier 2 (sample value; no labor-rule validation)
- **Advisory:** Ages 12+; violence, gunshot effects, death, suicide themes, sexual references, haze
- **Company:** 35 cast and 38 creative, production, and orchestra personnel; 20 existing demo profiles reused, 53 new fictional profiles
- **Performances:** 22; Wednesday–Friday at 7:30 p.m., Saturday at 2 and 7:30 p.m., Sunday at 2 p.m. All times America/New_York.
- **Access performances:** ASL May 16; audio description May 23
- **Publication:** unpublished test data (`publish=false`, `is_demo=true`)

![Supplied show poster](../../public/posters/les-miserables.png)

## Review scope

The branch contains the supplied poster, a canonical JSON roster and schedule, a generated transactional SQL seed, integration checks, and a small workspace change to display musical/composer information and this test poster. No schema, auth, RLS, permissions, invitation, or email changes are required.

The GitHub main branch predates the separately deployed onboarding release. This branch intentionally contains only the musical work. Apply it on top of the latest reviewed release when preparing deployment; do not deploy an older main snapshot over the current login/onboarding features.

## Full company

| Person | Assignment | Department | Existing profile | Test voice | Understudy coverage |
| --- | --- | --- | --- | --- | --- |
| Oscar Isaac | Jean Valjean | Cast / Principal | Reused | Tenor |  |
| Idris Elba | Javert | Cast / Principal | Reused | Baritone |  |
| Florence Pugh | Fantine | Cast / Principal | Reused | Mezzo-soprano |  |
| Timothée Chalamet | Marius | Cast / Principal | Reused | Tenor |  |
| Zendaya | Éponine | Cast / Principal | Reused | Mezzo-soprano |  |
| Jonathan Bailey | Enjolras | Cast / Principal | Reused | Baritone |  |
| Jack Black | Thénardier | Cast / Principal | Reused | Baritone |  |
| Meryl Streep | Madame Thénardier | Cast / Principal | Reused | Mezzo-soprano |  |
| Morgan Freeman | Bishop of Digne | Cast / Principal | Reused | Bass-baritone |  |
| Clara Bennett | Cosette | Cast / Principal | New fictional | Soprano |  |
| Eli Rivera | Gavroche | Cast / Youth principal | New fictional |  |  |
| Maya Chen | Young Cosette | Cast / Youth principal | New fictional |  |  |
| Sophie Brooks | Young Éponine | Cast / Youth principal | New fictional |  |  |
| Tom Holland | Courfeyrac / Ensemble | Cast / Ensemble | Reused | Tenor |  |
| Paul Mescal | Combeferre / Ensemble | Cast / Ensemble | Reused | Baritone |  |
| Dev Patel | Feuilly / Ensemble | Cast / Ensemble | Reused | Tenor |  |
| Daniel Kaluuya | Grantaire / Ensemble | Cast / Ensemble | Reused | Baritone |  |
| Theo Mercer | Babet / Factory Foreman / Ensemble | Cast / Ensemble | New fictional | Baritone | Thénardier; Bishop of Digne |
| Luca Santos | Brujon / Constable / Ensemble | Cast / Ensemble | New fictional | Bass |  |
| Noah Ellis | Montparnasse / Army Officer / Ensemble | Cast / Ensemble | New fictional | Tenor |  |
| Jamie Cole | Joly / Ensemble | Cast / Ensemble | New fictional | Tenor |  |
| Avery Lane | Lesgles / Ensemble | Cast / Ensemble | New fictional | Baritone |  |
| Nina Patel | Factory Girl / Ensemble | Cast / Ensemble | New fictional | Mezzo-soprano |  |
| Ruby Flores | Old Woman / Ensemble | Cast / Ensemble | New fictional | Alto |  |
| Isabel Reed | Ensemble / Wedding Guest | Cast / Ensemble | New fictional | Soprano |  |
| Samira Moss | Ensemble / Factory Worker | Cast / Ensemble | New fictional | Alto |  |
| Owen Park | Ensemble / Sailor | Cast / Ensemble | New fictional | Tenor |  |
| Elliot Hayes | Claquesous / Fauchelevent / Ensemble | Cast / Ensemble | New fictional | Baritone |  |
| Micah Turner | Jean Prouvaire / Ensemble | Cast / Ensemble | New fictional | Tenor |  |
| Caleb Stone | Swing / Dance Captain | Cast / Cover | New fictional | Tenor | Marius; Enjolras; Courfeyrac / Ensemble |
| Mira Hart | Swing / Assistant Dance Captain | Cast / Cover | New fictional | Soprano | Cosette; Éponine; Factory Girl / Ensemble |
| Leo Quinn | Standby | Cast / Cover | New fictional | Tenor | Jean Valjean; Javert |
| Tessa Gray | Standby | Cast / Cover | New fictional | Mezzo-soprano | Fantine; Madame Thénardier |
| Finn Bell | Youth alternate | Cast / Cover | New fictional |  | Gavroche |
| Lily Adams | Youth alternate | Cast / Cover | New fictional |  | Young Cosette; Young Éponine |
| Baz Luhrmann | Director | Creative | Reused |  |  |
| Mandy Moore | Choreographer | Creative | Reused |  |  |
| Es Devlin | Scenic Designer | Creative | Reused |  |  |
| Catherine Martin | Costume Designer | Creative | Reused |  |  |
| Natasha Katz | Lighting Designer | Creative | Reused |  |  |
| Jonathan Deans | Sound Designer | Creative | Reused |  |  |
| Ita O'Brien | Intimacy Director | Creative | Reused |  |  |
| Elena Marquez | Music Director / Conductor | Creative | New fictional |  |  |
| Daniel Cho | Associate Music Director / Rehearsal Pianist | Creative | New fictional |  |  |
| Amelia Grant | Vocal Director | Creative | New fictional |  |  |
| Rafael Cruz | Fight Director | Creative | New fictional |  |  |
| Grace Lin | Associate Director | Creative | New fictional |  |  |
| Morgan Vale | Projection Designer | Creative | New fictional |  |  |
| Harper Wells | Wig, Hair & Makeup Designer | Creative | New fictional |  |  |
| Jordan Price | Props Designer | Creative | New fictional |  |  |
| Casey Rowan | Dialect Coach | Creative | New fictional |  |  |
| Alex Morgan | Production Stage Manager | Staff | New fictional |  |  |
| Quinn Brooks | Assistant Stage Manager | Staff | New fictional |  |  |
| Parker Reed | Second Assistant Stage Manager | Staff | New fictional |  |  |
| Drew Hayes | Company Manager | Staff | New fictional |  |  |
| Sage Porter | Child Performer Supervisor | Staff | New fictional |  |  |
| Emery Blake | Technical Director | Crew | New fictional |  |  |
| Riley Shaw | Audio A1 / Mixer | Crew | New fictional |  |  |
| Cameron Fox | Audio A2 / Radio Microphones | Crew | New fictional |  |  |
| Dakota Lee | Wardrobe Supervisor | Crew | New fictional |  |  |
| Taylor James | Deck Chief | Crew | New fictional |  |  |
| Jules Avery | Lighting Programmer / Operator | Crew | New fictional |  |  |
| Reese Nolan | Orchestra Contractor | Staff | New fictional |  |  |
| Adrian West | Keyboard 1 | Other / Orchestra | New fictional |  |  |
| Blair Kim | Keyboard 2 | Other / Orchestra | New fictional |  |  |
| Cleo Martin | Violin | Other / Orchestra | New fictional |  |  |
| Dylan Frost | Cello | Other / Orchestra | New fictional |  |  |
| Eden Walsh | Reeds | Other / Orchestra | New fictional |  |  |
| Frankie Ross | Trumpet | Other / Orchestra | New fictional |  |  |
| Hayden Scott | Trombone | Other / Orchestra | New fictional |  |  |
| Indigo Bell | French Horn | Other / Orchestra | New fictional |  |  |
| Jesse Ford | Bass | Other / Orchestra | New fictional |  |  |
| Kai Monroe | Percussion | Other / Orchestra | New fictional |  |  |

## Full schedule

| Date | Time | Event | Type | State | Venue | Cast called |
| --- | --- | --- | --- | --- | --- | --- |
| 2027-04-06 | 10:00–13:00 | Company welcome & first sing-through | Rehearsal | Published | Margeson Theater | 35 |
| 2027-04-07 | 10:00–13:00 | Principal vocal rehearsal | Rehearsal | Published | Margeson Theater | 6 |
| 2027-04-07 | 10:00–13:00 | Barricade movement rehearsal | Rehearsal | Published | Santos Dantin Studio Theater | 16 |
| 2027-04-08 | 14:00–15:30 | Youth music & blocking | Rehearsal | Published | Margeson Theater | 5 |
| 2027-04-09 | 10:00–13:00 | Understudy & swing rehearsal | Rehearsal | Published | Margeson Theater | 6 |
| 2027-04-10 | 14:00–18:00 | Full company staging | Rehearsal | Published | Margeson Theater | 35 |
| 2027-04-13 | 10:00–13:00 | Canceled vocal brush-up | Rehearsal | Canceled | Margeson Theater | 2 |
| 2027-04-14 | 14:00–17:00 | Draft cover rehearsal | Rehearsal | Draft | Margeson Theater | 6 |
| 2027-04-27 | 10:00–18:00 | Scenery load-in | Load-in | Published | Margeson Theater | — |
| 2027-05-01 | 18:00–21:30 | Technical rehearsal | Tech | Published | Margeson Theater | — |
| 2027-05-02 | 18:00–21:30 | Sound & radio microphone check | Tech | Published | Margeson Theater | — |
| 2027-05-04 | 18:00–21:30 | Sitzprobe: cast and orchestra | Rehearsal | Published | Margeson Theater | 35 |
| 2027-05-05 | 18:00–21:30 | Dress rehearsal | Tech | Published | Margeson Theater | — |
| 2027-05-06 | 18:00–21:30 | Final dress rehearsal | Tech | Published | Margeson Theater | — |
| 2027-05-07 | 19:30–22:30 | Opening night | Performance | Published | Margeson Theater | — |
| 2027-05-08 | 14:00–17:00 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-08 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-09 | 14:00–17:00 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-12 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-13 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-14 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-15 | 14:00–17:00 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-15 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-16 | 14:00–17:00 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-19 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-20 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-21 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-22 | 14:00–17:00 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-22 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-23 | 14:00–17:00 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-26 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-27 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-28 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-29 | 14:00–17:00 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-29 | 19:30–22:30 | Les Misérables | Performance | Published | Margeson Theater | — |
| 2027-05-30 | 14:00–17:00 | Closing performance | Performance | Published | Margeson Theater | — |
| 2027-05-30 | 18:00–22:00 | Production strike | Strike | Published | Margeson Theater | — |

## Variables covered

Musical flag and composer, voice parts, principal and doubled ensemble tracks, youth principals and alternates, swings, standbys, dance captains, separate understudy credits, music direction, rehearsal piano, orchestra musicians, radio microphone crew, multiple show credits on one person, season membership, three-hour performances, accessibility dates, parallel rooms with disjoint casts, draft and canceled rehearsals, and production work outside performance dates.

Coverage and voice parts are test metadata and readable credits. This work does not add automatic cover substitution, youth work-hour validation, orchestra payroll, or musical licensing workflows. Instrumentation is a fictional test pit, not a licensed orchestration specification.

## Verification and release

Offline PostgreSQL integration checks pass against the existing table constraints and rehearsal validation triggers: exact company and performance totals; reused people unchanged; cover credits; season membership; no venue/person collisions; canceled/draft states; repeat imports; and atomic rejection when a shared profile changes. Existing 19 unit tests, TypeScript checking, and the production build pass. Desktop/mobile browser checks confirm the poster, composer label, 88 credits, 35 unique cast choices, no horizontal overflow, and no browser errors. Lint retains the same four errors already present on the base branch; no new lint errors were introduced.

The live Supabase project was inspected read-only. **No live import or Netlify deployment has been performed.** Commit and pull request use Netlify skip markers.

After review approval, merge the musical changes into the current release source, build and deploy that source, then explicitly run `supabase/seeds/les-miserables-demo.sql` against the approved database. The seed is never run automatically by builds or migrations. It requires an existing Orlando theater, current season, venues and the 20 matching demo profiles, and fails if an unrelated production or partial import is present. A repeated successful import is a no-op; later fixture revisions require a new reviewed update script.

To reproduce locally: run `node scripts/build-les-miserables-seed.mjs`, then `PGLITE_MODULE=/absolute/path/to/pglite/dist/index.js node docs/test-shows/verify-les-miserables.mjs` using a temporary PGlite installation. The test never connects to the live database.
