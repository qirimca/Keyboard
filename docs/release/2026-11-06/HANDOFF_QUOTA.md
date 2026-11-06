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

