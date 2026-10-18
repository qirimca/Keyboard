# Approved translation import

Source: `AppTranslations_final (2).csv`; all 76 rows exported in `AppTranslations.csv` and `.md` using the approved fixed columns.

- 58 rows map by `Table.key` to About, Home, Interface and Onboarding in all three locale directories (174 values).
- 4 rows map to Settings.bundle Root.strings in all three locales (12 values); new crh/uk resources added.
- 9 rows map to three String Catalogs in all three locales (27 values), updated through Xcode StringCatalogEdit.
- 5 identity rows describe extension names and hardcoded UI autonyms/brand. They are exported; Swift/plist integration belongs to the root task. The Cyrillic name is Къырымтатарджа.

No unidentified rows. No missing fixed values. The progress placeholder remains `%1$@/%2$@`; colons retain their trailing space. Literal `\n` from the CSV is decoded as a runtime newline when writing .strings, and remains literal in the review export.

KeyboardKit resource fixes are separate from the approved 76-row app table: English core labels and locale repaired; Ukrainian untranslated core labels and space corrected; Crimean Tatar capsLock/done/join updated as requested. Emoji names were not changed.
