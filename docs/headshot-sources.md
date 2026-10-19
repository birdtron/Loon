# Demo headshots

All show assignments and biographies are fictional test data. Portraits identify the named public figures and do not establish participation in these productions.

Source spreadsheet: https://docs.google.com/spreadsheets/d/1bn_QCRmNlIGxsXdrCux4K0p9wFFpQJzo6AIItwhyRa0/edit

The machine-readable attribution register is [credits.json](../public/headshots/credits.json). Every included image has its creator, original Commons description page, and applicable license recorded there and displayed in its Loon profile. Downloaded image pixels are preserved; Loon uses CSS to crop/resize the display. These public demonstration assets are separate from private user-uploaded headshots.

Nine profiles need a headshot: Roman Griffin Davis, Gareth Fry, Mandy Moore (choreographer), Jonathan Deans, Ita O'Brien, Finn Ross, Nick Powell (stunt coordinator), Lizzy Talbot, Tal Yarden. No reusable, identity-verified image was located for these records. Upload an authorized photo from their profile.

To reproduce demo data after the schema migration, run supabase/seeds/personnel-demo.sql in a trusted database session. It resolves theater and production IDs by the existing source labels, skips existing source-key profiles, and skips duplicate credits, preserving later user edits. Do not reuse this public seed file for real private personnel data.
