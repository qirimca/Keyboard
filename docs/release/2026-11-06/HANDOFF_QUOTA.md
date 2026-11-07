# HANDOFF — фіналізація 3.1 з бюджетом квоти (6.11.2026)

План: `~/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/quota_plan_2026_11_06.md`
Чекпойнт: гілка `release/3.1-build12-checkpoint`, коміт `53893f6` (все незакомічене станом на 21:59). Відкат: `git checkout 53893f6 -- <файл>`.
Квота на старті: Claude/GPT 7d = 47,1 %, лише на сьогодні.

## Журнал задач

### [ГОТОВО 22:00] P0 + чекпойнт
- Коміт `53893f6`, 233 файли. Пушу немає.

### [РОЗПОЧАТО 22:03] P1.0 Базовий аудит build 12 — може бути обірвано
Після відновлення перевірити:
- Збірка: `xcodebuild build-for-testing -project QTatar/Demo/QTatar.xcodeproj -scheme QTatar -destination 'generic/platform=iOS' -derivedDataPath /tmp/qk_dd_audit -jobs 4` (22:02 успішно, лог `/tmp/qk_audit_build.log`).
- Тести: `test-without-building -only-testing:QirimKeyUITests/QirimKeyUITests/testCompactStatisticsAndFullScreenHeader_20_73` паралельно на iPhone 15 Pro та iPad Air 3, result bundles `/tmp/qk_rb_*`.
- Файли коду не змінюються.

### [РОЗПОЧАТО 22:03] P1.3 Синхронізація перемикачів з iOS Settings — може бути обірвано
Після відновлення перевірити:
- Файли: `QTatar/Demo/Shared/AppConfiguration.swift` (`enabledSystemKeyboardIdentifiers`, `is*KeyboardExtensionEnabled`), можливо `QTatar/Demo/Demo/Views/HomeView.swift` (`refreshCyrillicStatus`).
- Відкат: `git checkout 53893f6 -- QTatar/Demo/Shared/AppConfiguration.swift QTatar/Demo/Demo/Views/HomeView.swift`.
- Перевірка: `python3 scripts/check_private_apis.py`, збірка як у P1.0.
- 22:05 виправлення вже внесено в робоче дерево (копія: `~/.gemini/antigravity/brain/094ccf37-6562-4f7d-ab2d-81becad46bfe/scratch/AppConfiguration.fixed.swift`); базовий прогін тестів іде на білді з оригінальним файлом.
- Нові UI-тести в `QirimKeyUITests.swift`: `testToggleSyncWithSettingsAndGlobe_2026_11_06` (вимикає/вмикає Кириличну клавіатуру в Settings -> QırımKey -> Клавіатури та відновлює), `testKeyboardHeightParity_2026_11_06` (висоти наша/системна в 5 типах полів).

### [ГОТОВО 22:05] P1.1 App Store Connect (лише читання)
- Збірки 3.1: 5, 6, 8, 10, 11 VALID (7, 9 прострочені). Build 12 у ASC НЕ завантажено. У зовнішній групі b43a7213: 11 = IN_BETA_TESTING, 10 = READY_FOR_BETA_SUBMISSION.
- Попередні перегляди IPHONE_DUO є в усіх 9 локалях (en-US, en-GB, en-CA, uk, ru, tr, de-DE, ro + ще одна), `AppPreview_Designed_iPhone_6_9.mp4` (886x1920), стан COMPLETE. Довантаження не потрібне.
- Скрипт: `~/.gemini/antigravity/brain/094ccf37-6562-4f7d-ab2d-81becad46bfe/scratch/asc_audit.py` (`--builds-only`).

### [ГОТОВО 22:06] P3.2 (зроблено разом з P1.1) аудит скриншотів ASC
- Кожна локаль: APP_IPHONE_67 5 x 1320x2868, APP_IPHONE_61 5 x 1206x2622, APP_IPHONE_DUO 5 x 1398x2034, APP_IPAD_PRO_3GEN_129 5 x 2064x2752, усі COMPLETE. Прогалин немає.

### [ГОТОВО 22:06] P1.2 Рядок «Мобільні дані» в Налаштуваннях iPhone
- `otool -L` застосунку та 3 розширень: жодних мережевих фреймворків поза стандартними; у коді немає URLSession/NWConnection/WKWebView (лише `openURL` на App Store у [AppStoreReviewManager.swift](../../../QTatar/Demo/Demo/Utilities/AppStoreReviewManager.swift)). Entitlements: лише App Group.
- Висновок: iOS показує «Мобільні дані» для застосунків, чиї клавіатурні розширення мають `RequestsOpenAccess = true` (усі 3). Це системна поведінка, змін у коді не потрібно.

### [ГОТОВО 22:17] P1.0 Базовий аудит (build 12 код)
- `testCompactStatisticsAndFullScreenHeader_20_73` на iPhone: FAIL лише через збережений стан (картка Statistika розгорнута користувачем), не дефект продукту. iPad: спершу заблокований, далі прогони пройшли.
- Журнали з пристроїв (`devicectl ... systemCrashLogs`, 3-6.11): жодного .ips від QTatar / Keyboard*. Лише системні процеси.
- HUD «QırımKey NNN ms» на iPad видно на 2 скриншотах базового прогону (319 ms і 442/487 ms) під час холодного запуску з `-qt_field`; це HUD Hang Detection з налаштувань розробника iPad, а не наш UI.
- Пріоритети: (1) висота iPhone без підказок (рядки клавіш розтягувались до 67 pt); (2) синхронізація перемикачів — Globe не змінює перемикачі (підтверджено на обох пристроях), перевірка Settings -> Keyboards у процесі; (3) iPad: еталон системної клавіатури не отримано (Globe на iPad не дійшов до системної).

### [РОЗПОЧАТО 22:20] P1.4/P2.2 Висота клавіатури в портреті — може бути обірвано
Після відновлення перевірити:
- Файли: `QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift` (`KeyboardAdaptiveGeometry.resolve`, гілка iPhone), `QTatar/Demo/Keyboard/KeyboardViewController.swift` (`recordLayoutDiagnosticsIfChanged`, ключ `crh.key.debug.layout`).
- Відкат: `git checkout 53893f6 -- QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift QTatar/Demo/Keyboard/KeyboardViewController.swift`.
- Вимірювання (iPhone 15 Pro, 393x852 pt, скриншоти 1178x2556 px, 3 px/pt), верх скляної підкладки / верх 1-го ряду / низ ряду «123»:

| Стан | Верх підкладки | Верх клавіш | Низ «123» | Висота на екрані |
| --- | --- | --- | --- | --- |
| Системна (з панеллю передбачень) | 524 | 576 | 780 | 328 |
| Наша build 12, з підказками | 505 | 568 | 771 | 347 (+19) |
| Наша build 12, без підказок | 505 | 522 | 771 | 347, клавіші 55 pt замість 42 |
| Наша виправлена, без підказок | 545 | 568 | 771 | 307 |

- Розширення: 255 pt з підказками (40 панель + 215 рядів), 215 pt без; нижня системна смуга для сторонніх клавіатур 75 pt (у системної 58 pt), тому наші клавіші на 8-9 pt вище системних.

### [ГОТОВО 22:35] P1.4/P2.2 Висота (iPhone портрет)
- Виправлено: без підказок iPhone-портрет більше не розтягує 3 ряди літер (раніше +13,3 pt кожен); висота = лише ряди (215 pt), клавіші 42 pt як у системній. Ландшафт, iPad Docked/Floating не змінено.
- З підказками: наш блок на екрані на ~19 pt вищий за системний (347 vs 328). Причина: системна смуга знизу для сторонніх клавіатур на 17 pt вища, плюс наша панель 40 pt. Точний збіг вимагає панелі ~21-29 pt, а пігулки підказок/фрази дня мають 34-38 pt, тому НЕ змінював (рішення за користувачем).
- iPad: еталон системної клавіатури не знято (Globe на iPad веде до Grammarly, не до системної). Сумарна висота iPad Docked інваріантна (258 pt) з/без підказок, як вимагалось.
- Доказ: [proofs](proofs/) `Proof_Height_iPhone_Build12WithSugg_vs_System_vs_FixNoSugg.png`, `Proof_Height_iPhone_fix_Std_Email_sugg1_sugg0.png`, `Proof_Height_iPad_Docked_Std_Email_sugg1_sugg0.png`.
- Діагностика: розширення пише `crh.key.debug.layout` в App Group (з build 13).

### [ГОТОВО 22:35] P1.3/P2.1 Синхронізація перемикачів
- Причина: на головному потоці `is*KeyboardExtensionEnabled` повертали застарілий кеш `enabledSystemKeyboardIdentifiers` та «seen»-прапорці, а `hasAuthoritativeSystemKeyboardsList` вважав список авторитетним лише коли в ньому є `crh.key.` — вилучена клавіатура лишалась ON.
- Виправлення: [AppConfiguration.swift](../../../QTatar/Demo/Shared/AppConfiguration.swift) `hasLiveContainingAppInputModeSnapshot()`: у застосунку на головному потоці живий список `UITextInputMode.activeInputModes` (+ ідентифікатори контролера) авторитетний для наявності й відсутності. Нових приватних класів немає, `check_private_apis.py` OK.
- Перевірено: iPad (запуск з іконки, без XCTest) Settings -> QırımKey -> Keyboards: Кирилична OFF -> перемикач OFF, ON -> ON. iPhone: вилучення -> OFF, повторне додавання -> ON. Globe (4 перемикання, у т.ч. Grammarly) не змінює перемикачі на обох пристроях. На iPhone Кириличну клавіатуру відновлено (ON).
- Примітка: HUD «QırımKey 295 ms» видно на iPad після повторного запуску (Hang Detection, холодний старт) — у доказах не приховано.
- Доказ: `proofs/Proof_Toggles_iPad_Globe_SettingsRemoveAdd_fix.png`, `proofs/Proof_Toggles_iPhone_Globe_SettingsRemove_Restore_fix.png`.
- Квота після P1/P2.1-2.2: 21-22 %.

### [РОЗПОЧАТО 22:36] P2.4 Build 3.1 (13) — може бути обірвано
Після відновлення перевірити:
- `CURRENT_PROJECT_VERSION = 13` (10 входжень), коміт гілки `release/3.1-build12-checkpoint`.
- Команда: `source .env.local; ARCHIVE_DIR=/tmp/qk_build13 bash QTatar/Scripts/archive_and_upload.sh all` (лог `/tmp/qk_build13_all.log`, `/tmp/qk_build13/archive.log`). What to Test (uk/en) у `QTatar/Scripts/asc/distribute_testflight.py`.
- Стан ASC: `python3 ~/.gemini/antigravity/brain/094ccf37-6562-4f7d-ab2d-81becad46bfe/scratch/asc_audit.py --builds-only`.

### [ГОТОВО 22:42] P2.4 Build 3.1 (13)
- Архів Release (`-jobs 4`) + експорт + завантаження: успішно. ASC: build 13 (`1ee6f8c5-2f1a-45fc-8c07-72e7b72d6b1c`) VALID, What to Test uk/en-US оновлено, додано до зовнішньої групи b43a7213, подано на Beta App Review (HTTP 201), стан до схвалення READY_FOR_BETA_SUBMISSION -> WAITING_FOR_REVIEW. Посилання: https://testflight.apple.com/join/suKzDBAS
- Release build 13 встановлено паралельно на iPhone 15 Pro та iPad Air 3 (`devicectl install`, код 0).
- Прибрано `/tmp/qk_dd_audit`, `/tmp/qk_build13/DerivedData`, result bundles; вільно 19 GiB. Архів лишається в `/tmp/qk_build13/QTatar.xcarchive`.
- `QTatar/Scripts` у `.gitignore`: правки `distribute_testflight.py` (What to Test) та `archive_and_upload.sh` (`-jobs 4`) локальні, не в коміті.
- Пропущено через квоту: повний P2.3 (Floating iPad, swipe, фраза дня, статистика на build 13) — лише точкові тести вище.

## Що лишилося до публікації в App Store (~через тиждень)
1. Вирішити висоту iPhone з підказками: наш блок на ~19 pt вищий за системний з панеллю передбачень (рішення: зменшити панель до ~30 pt і пігулки до ~28 pt, або залишити).
2. Зняти еталон системної клавіатури iPad Air 3 (Docked портрет, з передбаченнями) — вручну, бо Globe веде до Grammarly — і звірити з нашими 258 pt.
3. Регресія на build 13: iPad Floating, swipe на iPhone, фраза дня, статистика, Hang Detection HUD після перемикання мови (на iPad HUD 295-487 ms на холодному старті).
4. Дочекатися схвалення Beta App Review для build 13, зібрати відгуки тестувальників.
5. Прибрати діагностику `crh.key.debug.layout` або залишити (запис лише при зміні розміру).
6. Після тижня тестів: прив'язати фінальний білд до версії 3.1 (`attach_build.py`), `asc_submission_readiness.py`, подати на рецензію (вручну, з дозволу користувача). Медіа ASC повні: усі 9 локалей, 4 класи пристроїв, COMPLETE.

### [ГОТОВО 23:00] Висота iPhone з підказками = системна + Build 3.1 (14)
- Зміни (коміт `90d5a1e`): iPhone портрет — панель підказок 40 -> 29 pt; нижній ряд (Standard/Pro, 376-419 pt) крок 53 -> 47,5 pt, без нижнього відступу (впритул до системної смуги з глобусом, як у системній) — [SuggestionsDataBaseManager.swift](../../../QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift), [DemoStyleProvider.swift](../../../QTatar/Demo/Keyboard/DemoStyleProvider.swift) `itemEdgeInsets`. Пігулки підказок і фрази дня: висота = панель - 3 pt (26 pt), двохрядкова фраза до 28 pt з `minimumScaleFactor` 0.62 — [Autocomplete+NativeToolbarStyle.swift](../../../QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift). Ландшафт, iPad Docked/Floating не змінено. `crh.key.debug.layout` лише в `#if DEBUG`.
- Замір (iPhone 15 Pro): розширення 238,5 pt з підказками / 209,5 pt без; верх першого ряду 567,5 pt (системна 576 за вимірюванням до виправлення, тепер різниця ~2-3 pt), верх підкладки збігається з системною (~522 vs 524 pt), низ ряду «123» на ~4 pt вище системного (було 9). Фраза дня «Aqşam şerfiñiz hayır olsun!» повністю, без обрізання.
- Тести (паралельно iPhone + iPad): `testKeyboardHeightParity_2026_11_06` PASS обидва, `testToggleSyncWithSettingsAndGlobe_2026_11_06` PASS обидва (Settings OFF -> перемикач OFF, ON -> ON; Глобус не змінює).
- Доказ: `proofs/Proof_Height_iPhone_System_vs_Build14candidate_Std1_Email1_Std0.png` (системна | наша з підказками | Email | без підказок).
- Build 14 (`4338034d-5af3-4db9-b4c0-529f8c622876`): VALID, What to Test uk/en оновлено, зовнішня група b43a7213, подано на Beta App Review (HTTP 201). Встановлено на iPhone та iPad (код 0). Квота після: 9,7 %.
- Не перевірено на build 14: iPad Floating, swipe на iPhone, статистика (квота).

## Наступні задачі (точні кроки, не виконано через квоту)

### A. Зависання на iPad при холодному запуску (HUD 295-487 ms)
1. На iPad: Settings -> Developer -> Hang Detection (увімкнено) -> Hang Logs: знайти записи QTatar за 6.11 (`.ips`, tailspin). Поділитися (AirDrop) або витягти: `xcrun devicectl device copy from --device 00008020-00025DC63AA3002E --domain-type systemCrashLogs --source / --destination /tmp/qk_hang` і шукати `QTatar*` / `*.tailspin` / `*hang*`. (Сьогоднішній прогін systemCrashLogs .ips від QTatar не містив — Hang Logs можуть лежати лише в розділі Developer.)
2. Xcode -> Window -> Organizer -> Hangs (для TestFlight build 13/14) — агреговані стеки.
3. Символікація: `tailspin`-файл відкрити в Instruments або `spindump -i <file>`; dSYM з `/tmp/qk_build14/QTatar.xcarchive/dSYMs`.
4. Аналізувати головний потік під час `DemoApp` init і першого рендеру `HomeView` (7,5 тис. рядків): синхронні `CFPreferencesAppSynchronize`, `UserDefaults` App Group, SQLite (`SuggestionsDataBaseManager`), локалізаційний кеш, `UITextInputMode.activeInputModes` (тепер читається на головному потоці при `refreshCyrillicStatus`). Інструмент: Instruments -> Time Profiler + Hangs на iPad Air 3 з `-qt_field standard`.

### B. Еталон системної клавіатури iPad Air 3
1. Користувач уже має скриншоти системної клавіатури iPad у Фото на iPad — перенести (AirDrop) у `docs/release/2026-11-06/reference/`.
2. Або: у полі тестування утримати Глобус -> вибрати системну (English/Українська), не Grammarly; Docked портрет, з передбаченнями і без (Settings -> General -> Keyboard -> Predictive).
3. Старі фото: `docs/release/2026-11-01/physical/Proof_20_16_SystemKeyboardSettings_ipad*.png` (налаштування, не клавіатура); `testCrossAppStatisticsAndStandardKeyboardComparison` системну клавіатуру не знімає.
4. Виміряти (iPad 2 px/pt): верх підкладки, верх 1-го ряду, низ нижнього ряду; порівняти з нашими 258 pt (`KeyboardAdaptiveGeometry.resolve`, гілка 810-959 pt), змінювати лише iPad Docked portrait.

### C. TestFlight: старе фото в описі для тестувальників
- Скриншоти в TestFlight беруться з App Store (не з API Test Information); «Beta App Description» — лише текст (`betaAppLocalizations`). Якщо фото — це іконка/скриншот у публічному посиланні, перевірити в App Store Connect -> TestFlight -> Test Information вручну; через API змінюється лише текст (`PATCH /v1/betaAppLocalizations/{id}`, поле `description`).


### [РОЗПОЧАТО 23:06] Раунд 15: висота iPad Docked +8 pt, зависання iPad на старті, build 15 — може бути обірвано
Після відновлення перевірити:
- Файли: `QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift` (гілка iPad portrait 810-959 pt), можливо `QTatar/Demo/Demo/DemoApp.swift`.
- Відкат: `git checkout 9d584f3 -- <файл>`.
- Замір еталону користувача (768x1024 px, 1 px = 1,086 pt): верх підкладки системна 730 px, наша 737,5 px; рядок undo/redo системна 753 px, наша 760 px -> наша нижча на ~7,5 px = ~8 pt.
- iPhone: залишок 2-3 pt не прибрати константою — нижній ряд уже впритул до системної смуги (кінець view = 777 pt), системні клавіші закінчуються на ~780 pt за межами нашого view.

### [ЧАСТКОВО 23:15] Раунд 15 — зупинено на квоті 3 %
- iPad Docked портрет (810-959 pt): загальна висота 258 -> 266 pt (рядки 58/57 pt), однакова з підказками і без. Floating, ландшафт не змінено. Коміт цього кроку — нижче; результати тестів: `/tmp/qk_test_ipad_15.log`, `/tmp/qk_test_iphone_15.log`, доказ `proofs/Proof_Height_iPad_Docked_266pt_*_build15candidate.png` (якщо прогін встиг).
- Зависання iPad: у systemCrashLogs за 6.11 немає жодного hang/tailspin/.ips від QTatar (Hang Logs лежать лише в Settings -> Developer -> Hang Detection на iPad, витягти вручну через AirDrop). `DemoApp.init` уже асинхронний (CFPreferences у фоні) — очевидної синхронної роботи немає; кандидат — перший рендер `HomeView` (див. задачу A).
- Build 15 НЕ зібрано і НЕ завантажено (квоти < 4 %). Наступний крок: `CURRENT_PROJECT_VERSION = 15`, `source .env.local; ARCHIVE_DIR=/tmp/qk_build15 bash QTatar/Scripts/archive_and_upload.sh all`, оновити `(Build 14)` -> `(Build 15)` у `distribute_testflight.py`, встановити на обидва пристрої.
- Не перевірено: Floating iPad, swipe iPhone, статистика.

### [РОЗПОЧАТО 2026-11-07 12:32] Раунд 16: Key Flicks на iPad, відновлення горизонтальної (Landscape) висоти + паритет портретної висоти (iPad 266 pt / iPhone 243,0 pt з кроком 54 pt), заокруглення фону автовиправлення, усунення стартової анімації капсул кирилиці, усунення cold-start зависань (295–487 ms), повна регресія на iPhone 15 Pro + iPad та реліз Build 3.1 (15)
Після відновлення перевірити:
- Файли: [AppConfiguration.swift](../../../QTatar/Demo/Shared/AppConfiguration.swift), [SuggestionsDataBaseManager.swift](../../../QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift), [Autocomplete+NativeToolbarStyle.swift](../../../QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift), [KeyboardContext.swift](../../../QTatar/Sources/KeyboardKit/_Essentials/KeyboardContext.swift), [KeyboardViewController.swift](../../../QTatar/Demo/Keyboard/KeyboardViewController.swift), [KeyboardStateInspector.swift](../../../QTatar/Sources/KeyboardKit/State/KeyboardStateInspector.swift), [HomeView.swift](../../../QTatar/Demo/Demo/Views/HomeView.swift), [TransliterationTests.swift](../../../QTatar/Demo/Tests/Transliteration/Tests/TransliterationTests/TransliterationTests.swift).
- Відкат: `git checkout c475fa9 -- <файл>`.

### [ГОТОВО 2026-11-07 15:59] Раунд 16 + Release Build 3.1 (15)
- **Key Flicks на iPad та синхронізація всіх 16 системних налаштувань iOS**: у [AppConfiguration.swift](../../../QTatar/Demo/Shared/AppConfiguration.swift) (`SystemKeyboardSettings`) додано 3-рівневу синхронізацію без блокування головного потоку (App Group `crh.key.sys.*` -> системні `com.apple.keyboard.preferences` / `com.apple.Preferences` з правильними дефолтами `EnableKeyFlicks = true`, `KeyboardPrediction = true`, `KeyboardShowPredictionBar = true` -> фоновий `refreshFromSystemInBackground()` з публікацією в App Group). На iPad Docked відображаються всі вторинні символи Key Flicks (`1 2 3 4 5 6 7 8 9 0 - °`, `@ # $ ₴ & * - ( ) ' "`, `№ % _ + = / ; : / . ! ?`) і працює свайп донизу (`q -> 1`, `a -> @`).
- **Портретна висота клавіатури (iPhone 15 Pro + iPad) та відновлення Landscape висоти (`f08f42f` / `6b09aed`)**:
  - На фізичному **iPhone 15 Pro** (`1106 px` нижній кроп): `letterRowHeight = 54.0 pt` (`162 px`), `letterTopBottomInset = 5.5 pt` (видима клавіша `43.0 pt = 129 px`, міжрядковий проміжок `11.0 pt = 33 px`), `bottomRowHeight = 44.5 pt` (`top: 5.5, bottom: 0.0` у [DemoStyleProvider.swift](../../../QTatar/Demo/Keyboard/DemoStyleProvider.swift)), `toolbarHeight = 36.5 pt` (`243.0 pt` з підказками / `206.5 pt` без). Різниця з системною клавіатурою по кожному з 4 рядів — **`1 px` (`0.33 pt`)**: `Row 0 = [278..406 px]` (системна `[277..405 px]`), `Row 1 = [440..568 px]` (системна `[439..567 px]`), `Row 2 = [602..730 px]` (системна `[601..729 px]`), `Row 3 Top = 765 px` (системна `764 px`, `0 px` обрізання знизу).
  - Плашка фрази дня та автокорекції ([Autocomplete+NativeToolbarStyle.swift](../../../QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift)): `selectionHeight = 26.0 pt` (`78 px`), `verticalCenterOffset = -5.0 pt` на iPhone (`[153..230 px]`, `54 px` запас зверху до `card_top = 99 px`, `48 px` знизу до `Row 0 = 278 px`, `0 px` обрізання), `cornerRadius = 14.0 pt` (нативна форма stadium-капсули).
  - Відновлено горизонтальну (Landscape) геометрію з комітів `f08f42f` / `6b09aed` для всіх розмірів iPhone (`160 / 198 pt` з панеллю, `40.0 pt` рядок у Safari Landscape на iPhone 15 Pro) та iPad (`338 / 350 / 378 pt`).
  - На iPad Docked портрет (`810..959 pt`): інваріантна висота `266.0 pt` (`card_top = 173 px` у 780 px кропі однаково для `Std1`, `Email`, `Std0`, `Search` — `0.0 px` розбіжності).
- **Усунення cold-start зависань (`295–487 ms`) та стартової анімації капсул кирилиці**:
  - У [KeyboardContext.swift](../../../QTatar/Sources/KeyboardKit/_Essentials/KeyboardContext.swift), [KeyboardViewController.swift](../../../QTatar/Demo/Keyboard/KeyboardViewController.swift), [KeyboardStateInspector.swift](../../../QTatar/Sources/KeyboardKit/State/KeyboardStateInspector.swift) та [HomeView.swift](../../../QTatar/Demo/Demo/Views/HomeView.swift) усунено синхронні виклики `UITextInputMode.activeInputModes` та SQLite/UserDefaults під час `init` / першого кадру. Жодної плашки Hang Detection HUD (`QırımKey ... ms`) на iPhone 15 Pro та iPad.
  - У [HomeView.swift](../../../QTatar/Demo/Demo/Views/HomeView.swift) видалено всі 6 тригерів `.onAppear` у інтерактивних бейджах (`InteractiveKeycapBadge`, `InteractiveUkrainianKeycapBadge`, `InteractiveChartBadge`, `InteractiveSystemSettingsBadge`, `InteractiveSettingsIconBadge`, `InteractiveWalnutIconBadge`). Серія з 3 кадрів (`t=0ms, 150ms, 350ms`) з увімкненими живими анімаціями (`-qt_enable_live_animations`) має різницю пікселів `((0, 0), (0, 0), (0, 0))` (`0.000 %`) як на iPhone 15 Pro, так і на iPad.
- **Візуальні докази (без подвійних ліній сітки — single-pass gridlines across `x = 0 .. width - 1`)**:
  - `proofs/Proof_Height_iPhone_System_vs_Build15_Std1_Email1_Std0.png`
  - `proofs/Proof_Height_iPad_System_vs_Build15_KeyFlicks.png` та `proofs/Proof_Height_iPad_Docked_Std_Email_sugg1_sugg0.png`
  - `proofs/Proof_Home_FirstOpen_ZeroCapsuleAnimation_3Frames.png` та `proofs/Proof_R16_Home_FirstOpen_3FrameBurst_Diff0.png`
  - Повний набір R16 (`Proof_R16_iphone_01..10.png` та `Proof_R16_ipad_01..09.png`).
- **Release Build 3.1 (15) у TestFlight та на пристроях**:
  - Build 15 (`id = ea0fe69d-416b-4ebd-8a14-96b522318ea4`): `processingState = VALID`, оновлено What to Test (`uk`, `en-US`, HTTP 200), прикріплено до зовнішньої групи `b43a7213-fb8d-40ae-b34f-c354fa9aab13` (`https://testflight.apple.com/join/suKzDBAS`, HTTP 204), подано на Beta App Review (HTTP 201). `appStoreVersions` не змінювались.
  - Встановлено та запущено Release Build `3.1 (15)` на фізичному **iPhone 15 Pro (`00008130-000954812231001C`)** (`devicectl install/launch`, код 0).

