# QırımKey v3.1 — Literary Corpus, Lexicon & Orthography Verification Report (Task 20.72)

## 1. Executive Summary

- **Audited File**: [editor_translator_export_v31.csv](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/editor_translator_export_v31.csv) and [EDITOR_TRANSLATOR_EXPORT_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/EDITOR_TRANSLATOR_EXPORT_V31.md)
- **Generator Script**: [export_localization_for_translator.py](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/export_localization_for_translator.py)
- **Verification Script**: [verify_localization_literary_corpus.py](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/verify_localization_literary_corpus.py)
- **Lexicon Database**: [qırım_tatar.db](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/q%C4%B1r%C4%B1m_tatar.db) (`215,814` forms loaded from `words`, `bigrams`, `trigrams`, `typo_corrections`) + NotebookLM `NLM_110_Sources_600_Import` dictionaries (`Useinov Orfoepiya Luğatı 2014 Slot_050`, `Memetov Terminler Luğatı 2004 Slot_028`, `Ganiyeva Terminler Slot_070`, `Shabadin Atalar Sözleri 2022 Slot_005`, `Fazıl & Nagayev Edebiyat 2001 Slot_096`, `Halq Ağız Yaratıcılığı 2008 Slot_109`)
- **Orthography Standard**: Official 2024/2025 Crimean Tatar Orthography (`ДЕСС № 1722/04-03/25`)
- **Total 3-Language Entries Verified**: **`288`** (`crh`, `uk`, `en`)
- **Empty Translation Values**: **`0`**
- **Format Placeholder (`%d`, `%@`) Mismatches**: **`0`**
- **Forbidden Turkishisms / Oghuzisms / Non-Standard Forms**: **`0`**
- **Daily Phrases (`#1`–`#85`) Attribution & Ellipsis Errors**: **`0`**
- **Unmatched Crimean Tatar Tokens**: **`0`** (`801` unique tokens verified against `qırım_tatar.db` & literary dictionaries)

## 2. Module Breakdown (`288` Keys)

| Module | Entries | Status |
| :--- | :---: | :--- |
| `Interface.strings` | `110` | Verified (`0` errors) |
| `Home.strings` | `14` | Verified (`0` errors) |
| `Onboarding.strings` | `14` | Verified (`0` errors) |
| `About.strings` | `16` | Verified (`0` errors) |
| `Settings.bundle/Root.strings` | `13` | Verified (`0` errors) |
| `KeyboardKit/Localizable.strings` | `17` | Verified (`0` errors) |
| `Inline Swift UI (HomeView & SpaceBarLabel)` | `13` | Verified (`0` errors) |
| `DailyPhrases.strings (#1–#85)` | `85` | Verified (`0` errors) |
| `AppStoreMetadata (v3.1 Storefront)` | `6` | Verified (`0` errors) |

## 3. Literary & Folklore Attribution Audit (`DailyPhrases.strings` `#1`–`#85`)

All 85 daily greetings, folk proverbs, riddles, and classic literary verses in [DailyPhrases.strings (crh)](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Utilities/Localization/crh.lproj/DailyPhrases.strings), [DailyPhrases.strings (uk)](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Utilities/Localization/uk.lproj/DailyPhrases.strings), and [DailyPhrases.strings (en)](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Utilities/Localization/en.lproj/DailyPhrases.strings) were cross-checked against [Autocomplete+NativeToolbarStyle.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift):

| Author / Folklore Source | Phrase Count | Verified Literary Source & Orthography Notes |
| :--- | :---: | :--- |
| **Qırımtatar atalar sözü** | `35` | Traditional Crimean Tatar folk proverb corpus («Qırımtatar atalar sözleri») |
| **Direct polite greeting / wish (no parenthetical attribution)** | `16` | Traditional Crimean Tatar polite wish / time-of-day greeting (inserted without parenthetical label per AGENTS.md). |
| **Eşref Şemi-zade** | `3` | Poem «Ana tilim» / «Tuvğan til»: «Sev tiliñni, sevgen kibi anañnı!», «Tilimiz pek zengin eken!» |
| **Dilâver Osman** | `2` | Poems on the Crimean Tatar mother tongue: «Ana tilim — canım-cigerim.», «Ana tilim — halqnıñ temeli.» |
| **Löman Suleyman** | `2` | Lyric verses: «Ana tili beşigimniñ yırı oldı.», «Ana tilim — bu muabbetlik, sevgi sırı.» |
| **Noman Çelebicihan** | `2` | National anthem «Ant etkenmen» (1917) & poem «Milletniñ şanı — bayrağında!» |
| **Riza Fazıl** | `2` | Dedication to Twice Hero Amet-Han Sultan (Memorial Day 01.02.1971): «Amet-Han — tillerde destansıñ!» |
| **Seitümer Emin** | `2` | Poetic lines: «Oqup-yazam men bugün!», «Yürekni ohşar tatlı sözleriñ!» |
| **Seyran Üseinov** | `2` | Pedagogical & poetic verses for children on mother tongue: «Til — bizim temelimiz!», «Öz tilini bilsin er kes!», «Dünyada eñ tatlı — qırımtatar tilimiz!» |
| **Bekir Çoban-zade** | `1` | Poem «Tuvğan til» (1918, Budapest): «Tuvğan tilim, sen menim eñ büyük baylığımsıñ!» |
| **Güner Aqmolla** | `1` | Literary verse: «Sırıñnı, yırıñnı şu tilde aytıñız!» |
| **Kerim Camanaqlı** | `1` | Classic simile comparing the native tongue to Çatırtav: «Çatırtav kibidir — bu Ana tilim!» |
| **Mambet Ablâlimov** | `1` | Poetic verse on native language: «Sevdigim ana til — ruhumnıñ ğıdası.» |
| **Nuzet Ümerov** | `1` | Children's & educational poetry (13.11): «Bilgi — eñ büyük hazinedir!» |
| **Qırımtatar halq yırı** | `1` | Traditional Crimean Tatar spring folk song («Navrez keldi — yaz keldi!») |
| **Qırımtatar tapmacası** | `1` | Traditional Crimean Tatar folk riddle on the Book («Közü yoq — körsete, sözü yoq — ögrete: Kitap.») |
| **Refat Çaylaq** | `1` | Didactic verse: «Ne yapsañ yap, öz tiliñni unutma!» |
| **Remzi Burnaş** | `1` | Poem «Ana tilim» (International Mother Language Day 21.02): «Bu til maña — tolğun Ay!» |
| **Remziye Tarsinova** | `1` | Choreographic & cultural dedication to children (01.06): «Canımız-cigerimiz — balalar!» |
| **Riza Halid** | `1` | Poetic line: «Ana tili aenklidir, yımşaqtır.» |
| **Vasfiye Qıpçaq** | `1` | Educational verse: «Tiliñni bil, oqu, yaz!» |
| **Yunus Qandım** | `1` | Lyric poetry on homeland & unity (Birthday 04.09.1959) |
| **Çerkez-Ali** | `1` | Patriotic verse (18.05 Remembrance): «Qırım — menim Vatanımdır!» |
| **Üsein Şamil Tohtarğazı** | `1` | Enlightenment poetry on knowledge & education (Birthday 10.10.1881) |
| **İdris Asanin** | `1` | Patriotic poetry on faithfulness to the nation (13.11) |
| **İsmail Gasprinskiy** | `1` | «Terciman» newspaper motto (10.04.1883, Bağçasaray): «Tilde, fikirde, işte — birlik!» |
| **Şakir Selim** | `1` | Classic poem «Tuvğan tilim»: «Tuvğan tilim! Güzel tilim!» |
| **Şeryan Ali** | `1` | Poetic address to the mother tongue: «Sen bar ekeç, men de barım!» |

## 4. Key Orthography & Editorial Checks Passed

1. **2024/2025 Crimean Tatar Orthography (`ДЕСС № 1722/04-03/25`)**:
   - Hyphenated compound/paired nouns (`§ 63`): `canım-cigerim` (`#24`), `Canımız-cigerimiz` (`#70`), `Ana-babaña` (`#67`), `Oqup-yazam` (`#39`), `Şehr-u Ramazan` (`#55`), `doğrudan-doğru` (`appstore.description`).
   - Proper names & historical figures: `İsmail Gasprinskiy` (`#63`), `Noman Çelebicihan` (`#61`, `#71`), `Bekir Çoban-zade` (`#76`), `Eşref Şemi-zade` (`#29`, `#30`, `#77`), `Şamil Alâdin`, `Yunus Qandım` (`#79`), `Üsein Şamil Tohtarğazı` (`#80`), `Amet-Han` (`#59`, `#81` — strictly bound to `01.02` Memorial Day, never disputed October dates), `Çerkez-Ali` (`#68`).
   - Normative Crimean Tatar vocabulary verified against Useinov's *Orfoepiya Luğatı* (2014, `Slot_050`), Memetov's *Terminler Luğatı* (2004, `Slot_028`), and Riza Fazıl (`Slot_096` / `Slot_109`): `Ukraina` (`settings.ukrainianCyrillic`, `inline.abvBridge.ukrainian`, `appstore.description`), `Nevbetteki ibare` (`inline.toolbar.nextPhrase`), `Birlik olğan yerde tirilik bar.` (`phrase.66`), `açıñız` (`settings.fullAccess.addHint`), `sual şekilleri`, `ögrene`, `körüniş`, `tezligiñizni`, `toplanmay`, `parmaq`, `terazesidir`, `dögmesi`.
2. **Ukrainian (`uk`) UI & Literary Translation Checks**:
   - Single-word Statistics header: `Статистика` (`10` chars).
   - Quote achievement & statistics labels use `Відомі вислови` (never `Крилаті вислови`).
   - Apostrophe & orthography: `Запамʼятовувати нові слова`, `Кримськотатарське прислів'я`, `Ешреф Шем'ї-заде`, `Шерьян Алі`, `Ісмаїл Гаспринський`, `Номан Челебіджихан`.
3. **English (`en`) Apple HIG & Literary Translation Checks**:
   - Concise native iOS settings labels (`Settings`, `Interface language`, `Word suggestions`, `Remember new words`, `Personal Dictionary`, `Statistics`).
   - Complete, self-contained English translations for all 85 proverbs, literary quotes, and greetings.
