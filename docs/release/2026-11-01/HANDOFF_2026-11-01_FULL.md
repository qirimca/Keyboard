# QırımKey (QTatar) — Повний Handoff сесії та документація всіх змін (2026-11-01)

- **Дата та час створення**: `2026-11-01 21:55 +02:00`
- **Xcode Conversation ID**: `0A8EB2E5-766F-49B8-98CC-BC98E912A3A5`
- **Antigravity ACP Session ID**: `0cfc27ca-42fd-416d-9c29-608ec8d6f6b6`
- **Робоча директорія**: `/Users/love/Documents/Documents - MacBook Air - Віта/GitHub/Keyboard/QTatar/Demo`
- **Статус збірки та тестів**:
  - `BuildProject` (Xcode MCP): **SUCCESS (`0` помилок, `0` попереджень компіляції)**
  - Модульні та стрес-тести `swift test --package-path Tests/Transliteration`: **27/27 PASS** (включно з `deepAtypicalEventsModeSwitchingCBoundsAndLatencyStress` — перевірка C-bounds SQLite, перемикання режимів, `< 16ms` latency budget на запит та `< 12ms` на swipe decode)
  - Симуляторні UI-тести `QirimKeyUITests` (`iPhone 18 Pro` та `iPad Pro 11-inch (M5)`): **PASS** (`testComprehensiveModesSizesSwitchAndAtypicalEvents`, `testCrossAppStatisticsAndStandardKeyboardComparison`, `testPhase13AdaptiveHeightTrackpadSlideAndSettingsBundle`, `testRound2UkrainianLayoutAndSwipeComet`, `testVisualModesAndScreenshots`)
  - Профілювання `xctrace` (`Time Profiler` + `potential-hangs` + `hang-risks`): **0 зависань (`0 hangs`)**

---

## 1. Файли повного незміненого експорту цієї розмови

Повний незмінений експорт усієї розмови (усі промпти користувача, усі відповіді моделі, думки, виклики інструментів та результати з `conversation.plist` і `0cfc27ca-42fd-416d-9c29-608ec8d6f6b6.db` без жодних скорочень) збережено у таких файлах:

1. **Повний Markdown-транскрипт розмови (усі ходи та всі кроки `0..2008+`)**:
   - [`CONVERSATION_EXPORT_2026-11-01_0cfc27ca-42fd-416d-9c29-608ec8d6f6b6_FULL.md`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Documentation/Handoffs/CONVERSATION_EXPORT_2026-11-01_0cfc27ca-42fd-416d-9c29-608ec8d6f6b6_FULL.md)
2. **Повний JSON-експорт розмови (структура Xcode `conversation.plist` + усі декодовані кроки `steps` бази Antigravity ACP)**:
   - [`CONVERSATION_EXPORT_2026-11-01_0cfc27ca-42fd-416d-9c29-608ec8d6f6b6_FULL.json`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Documentation/Handoffs/CONVERSATION_EXPORT_2026-11-01_0cfc27ca-42fd-416d-9c29-608ec8d6f6b6_FULL.json)
   - [`ШІ/АГ/2026-11-01 at 21.55.00.00.json`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/%D0%A8%D0%86/%D0%90%D0%93/2026-11-01%20at%2021.55.00.00.json)
3. **Оригінальні системні файли сесії на диску**:
   - Xcode CodingAssistant Plist: `/Users/love/Library/Developer/Xcode/UserData/CodingAssistant/QTatar-ebtefmashcidpzdftlcywoqvxjek/0A8EB2E5-766F-49B8-98CC-BC98E912A3A5/conversation.plist`
   - Antigravity ACP SQLite DB: `/Users/love/Library/Developer/Xcode/CodingAssistant/antigravity/antigravity-acp/conversations/0cfc27ca-42fd-416d-9c29-608ec8d6f6b6.db`

---

## 2. Хронологія всіх запитів користувача у цій сесії (дослівно без змін)

### Запит 1 (`2026-11-01 15:07:48 UTC`)
````text
зроби повний глибокий детальний  загальний аудит інтерфейсу, продуктивності ефективності швидкості безпечності та інші тестування  перед релізом  додатку згідно кращих практик і документації apple враховуй доступне вілне місце, пристрої є 2 підключені фізичні можеш брати віртуалні згідно наявного місця тапамʼяті по черзі якщо бракує місця, є перфоманс трейс хенг трейс та автомейшнс юі включено на обох пристроях
/plan /app-resizability /modernize-tests /building-document-based-swiftui-applications /device-interaction /audit-xcode-security-settings /accessibility-voiceover-specialist /adopt-c-bounds-safety /accessibility-sufficient-contrast-specialist /xctrace
````

### Запит 2 (`2026-11-01 15:25:38 UTC`)
````text
проконтролюй щоб  найдрібніі рекоменадції та побажання були застосовані враховані згідно
/plan /app-resizability /modernize-tests /building-document-based-swiftui-applications /device-interaction /audit-xcode-security-settings /accessibility-voiceover-specialist /adopt-c-bounds-safety /accessibility-sufficient-contrast-specialist /xctrace
````

### Запит 3 (`2026-11-01 15:50:09 UTC`)
````text
ще раз глибше детальніше проконтролюй щоб  найдрібніі рекоменадції та побажання були застосовані враховані згідно
/plan 

/app-resizability 

/modernize-tests 

/building-document-based-swiftui-applications 

/device-interaction 

/audit-xcode-security-settings 

/accessibility-voiceover-specialist 

/adopt-c-bounds-safety 

/accessibility-sufficient-contrast-specialist 

/xctrace

щоб були повні тести з перевеіркою та оптимізацією перфоманс трейс хенгінг трейс. юі автомейшнс тощо включно з симуляторами, різними додатками роботи клавіатури в різних режимах розмірах , перемикання режимів перемикання клавіатур мов нетипові викоирстання та події тощо детально, глбоко з кращим виправленням та оптимізацією глибокою 
````

### Запит 4 (`2026-11-01 18:11:34 UTC`)
````text
чомусь при перемиканні мови активується поле вводу 
є пролема зміни ширин адаптивності, є ... замість адаптивності 
якщо є в системних налаштуваннях предиктивний ввід вимкнення то в налаштуваннях додатку його можна не давати а брати з системних налаштувань лише 
зроби аудит айпада (3) підключеногоо фенсе хенг перфоманс трейс логи тощо для вирпавлення проблем 
бачу перемикаєтсья на системний фолбек клавіатуру часто 
також мікрофон чомусь зʼявився назад під клавіатурою
кнопка системні налаштування пропала 
перевір вивчені слова кількість в статистиці бо після додавання слів не міняється кількість в статистиці і деякі слова не видаляються з неї при спробі видалити наприклад spotify
при клікі на поле вводу воно не тільки піднімає клавіатуру але й опускає екран хоча поле вводу влізає  і не тре рухати екран і якщо не влізає то тільки тоді рухати рівно так шщоб влізло 
в латиському вводі на айпаді біля пробілу чомусь на двох мовах дві клавіші а Кримськотатарська тільки одна замість двох щоб перемикатися на обидві розкладки 
зроби скляним  напівпрозорим ліквід глас в кримськотатарській клавіатурі  поле підказок з 3х підказок замість білого чи чорного 
перемикання в хомвью світлої темної теми тормозить трохи анімацію перемикання світча осоливо при першому запупску додатку 
 заупусти ще раз паралельно це все що пишеш тести
аналізуй фото відео всі на різних пристроях щоб проблеми небуло  та роби свої після виправлення щоб не було проблем вже  
/xctrace /plan /modernize-tests /device-interaction /app-resizability /swiftui-specialist /app-intents-specialist /adopt-c-bounds-safety /accessibility-dynamic-type-specialist /building-document-based-swiftui-applications
````

### Запит 5 (`2026-11-01 18:59:39 UTC`)
````text
"чомусь при перемиканні мови активується поле вводу 
є пролема зміни ширин адаптивності, є ... замість адаптивності 
якщо є в системних налаштуваннях предиктивний ввід вимкнення то в налаштуваннях додатку його можна не давати а брати з системних налаштувань лише 
зроби аудит айпада (3) підключеногоо фенсе хенг перфоманс трейс логи тощо для вирпавлення проблем 
бачу перемикаєтсья на системний фолбек клавіатуру часто 
також мікрофон чомусь зʼявився назад під клавіатурою
кнопка системні налаштування пропала 
перевір вивчені слова кількість в статистиці бо після додавання слів не міняється кількість в статистиці і деякі слова не видаляються з неї при спробі видалити наприклад spotify
при клікі на поле вводу воно не тільки піднімає клавіатуру але й опускає екран хоча поле вводу влізає  і не тре рухати екран і якщо не влізає то тільки тоді рухати рівно так шщоб влізло 
в латиському вводі на айпаді біля пробілу чомусь на двох мовах дві клавіші а Кримськотатарська тільки одна замість двох щоб перемикатися на обидві розкладки 
зроби скляним  напівпрозорим ліквід глас в кримськотатарській клавіатурі  поле підказок з 3х підказок замість білого чи чорного 
перемикання в хомвью світлої темної теми тормозить трохи анімацію перемикання світча осоливо при першому запупску додатку 
 заупусти ще раз паралельно це все що пишеш тести
аналізуй фото відео всі на різних пристроях щоб проблеми небуло  та роби свої після виправлення щоб не було проблем вже  
/xctrace  % #  
 
 BuiltinSlashCommandName.PLAN  
  /modernize-tests   /device-interaction  /app-resizability  /swiftui-specialist  /app-intents-specialist  /adopt-c-bounds-safety  /accessibility-dynamic-type-specialist  /building-document-based-swiftui-applications"
перевір чи все повно без обмежень ти тут виконав щоб кожне речення кожне слово повністю було зроблено враховано включно з фото наданими раніше які треба було переобити з робочими станами з відео напланшетах та айфонах різних, глибше аналізуй та виправ все що не виправиви та пропустив
````

### Запит 6 (уточнення щодо поведінки клавіатури, адаптивності, теми та словника під час сесії)
````text
в полі вводу все ж коли воно поміщаєтсья при клікі туди екран опускаєтсья вниз - тре щоб опускався тіки коли поле не поміщається. також при зміні мови інетрефейсу не має клава вискакувати і фокус ставати у поле вводу для перевірки і письма, перевір адаптивність елементів вікна програми при зміні розміру бо при звужені деякі елементи стають на три крапки обрізані замість того щоб адаптовуватися і переноситися і тп - тре глянути по всій програмі де не адаптивно для вужчих і ширших екранів. також вивчені слова лічильник інколи не рахує нових слів хоть вони зявляютсья у вивчених словах при клікі на лічильник і переході туди + при оновлені програми з ап стора чи перевстановлені тре мабуть звіряти вивчені слова якщо якісь вже є у базовому словнику то їх прибирати з вивчених і так само мабуть прибирати з підрахунку лічильника + перевірити щоб видалення вивчених слів працювало коректно, також при перемикані теми з тетсуваня і письмо кнопки світла і темна трохи підвисає при перемикані - глянь чому і виправ
````

### Запит 7 (`2026-11-01 19:54:20 UTC`)
````text
зроби хендоф сього що зроби включно з експортомцієї розмови без змін повністю
````

---

## 3. Детальний технічний опис усіх виконаних змін у коді

### 3.1. Розумна прокрутка поля вводу та відсутність самовільної появи клавіатури при зміні мови інтерфейсу або теми
- **Файл**: [`HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift)
- **Що виправлено**:
  1. Прибрано безумовний обробник `.onChange(of: isWritingFieldFocused)`, який раніше викликав `scrollProxy.scrollTo("home.scrollTopAnchor", anchor: .top)` при кожному фокусуванні на полі вводу, через що екран опускався вниз навіть тоді, коли поле повністю поміщалося над клавіатурою.
  2. У [`SandboxTextView.Coordinator`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L5212-L5304):
     - У `textViewShouldBeginEditing(_:)` фіксується поточне зміщення зовнішнього `UIScrollView` (`preKeyboardOuterScrollOffset`) до того, як UIKit/SwiftUI намагається змістити скрол.
     - Додано підписку на `UIResponder.keyboardWillShowNotification` та `UIResponder.keyboardWillChangeFrameNotification` (`adjustOuterScrollViewForKeyboard(notification:)`).
     - Обчислюється нижня межа контейнера поля вводу при збереженому зміщенні (`fieldBottomAtSavedOffset`) відносно верхньої межі клавіатури (`keyboardTopY = kbFrameInWindow.minY`).
     - Якщо `fieldBottomAtSavedOffset <= keyboardTopY` (поле повністю вміщується над клавіатурою), будь-яка автоматична прокрутка UIKit/SwiftUI миттєво скасовується (`outerScrollView.setContentOffset(savedOffset, animated: false)` у `UIView.performWithoutAnimation`), і екран залишається нерухомим.
     - Тільки якщо `fieldBottomAtSavedOffset > keyboardTopY` (поле перекривається клавіатурою), `outerScrollView` прокручується рівно на необхідний дельта-відступ `neededOverflow = (fieldBottomAtSavedOffset + 6.0) - keyboardTopY`.
  3. Щоб при перемиканні мови інтерфейсу (`QT` / `УК` / `EN`) або теми клавіатура не вискакувала і фокус не переходив у поле вводу:
     - У [`languageSegmentedControl`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L2237-L2259) перед зміною `language` виставляється `shouldAutoFocusSandbox = false`.
     - При приховуванні клавіатури (`UIResponder.keyboardWillHideNotification`) та в `SandboxTextView.updateUIView` / `textViewDidBeginEditing` / `textViewDidEndEditing` прапорець `shouldAutoFocusSandbox` скидається в `false` через `onDidAutoFocus()`.

### 3.2. Усунення затримки (лагу) при перемиканні Світлої / Темної теми в «Тестування і письмо»
- **Файл**: [`HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift)
- **Виявлені та усунені причини підвисання при натисканні кнопок Світла / Темна**:
  1. У [`syncThemeToAppGroup`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L1200-L1228), [`syncSandboxFocusToAppGroup`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L1150-L1168), [`clearThemeOverride`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L1533-L1554) та [`SandboxTextView.Coordinator`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L5475-L5535) прибрано синхронні виклики `defaults.synchronize()`, `CFPreferencesAppSynchronize(...)` та `CFNotificationCenterPostNotification(...)` із головного потоку — тепер вони виконуються асинхронно у фоновій черзі `HomeView.bgPrefsAndSQLiteQueue`.
  2. Відкладено виклик `textView.reloadInputViews()` на `40ms` (`DispatchQueue.main.asyncAfter(deadline: .now() + 0.04)`), щоб розширення клавіатури не перебудовувало свою ієрархію в той самий кадр, коли `UIWindow` починає кросфейд `UIView.transition(with: window, duration: 0.22, options: [.transitionCrossDissolve, .allowAnimatedContent])`.
  3. Прибрано зайву обгортку `withAnimation(.easeInOut(duration: 0.2))` у біндінгу перемикача теми, яка конкурувала з системним кросфейдом `UIWindow`.
  4. У [`NativeSegmentedControl.Coordinator.valueChanged`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L3650-L3665) оновлення `selection` перенесено на наступний тік `DispatchQueue.main.async` (поза UI-тестами), щоб нативна анімація повзунка `UISegmentedControl` стартувала миттєво без очікування перерахунку всього дерева `HomeView`.

### 3.3. Повна адаптивність інтерфейсу при зміні розміру вікна (вузькі/широкі екрани, iPad Split View / Stage Manager) без обрізань `...`
- **Файли**:
  - [`HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift)
  - [`AboutView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/AboutView.swift)
  - [`PrimaryButton.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/Components/PrimaryButton.swift)
  - [`NavButton.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/Components/NavButton.swift)
  - [`KeyboardStateItem.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/Components/KeyboardStateItem.swift)
  - [`Demo/Info.plist`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Info.plist)
- **Що зроблено**:
  - Відстежується реальна ширина контейнера `containerSize` усередині `ScrollView`, щоб двоколонкова сітка досягнень та карток на iPad при звуженні вікна у Split View / Stage Manager (`effectiveWidth < 540pt`) автоматично перебудовувалася в одну колонку.
  - Рядок вибору мови інтерфейсу у `keyboardSettingsSection` обгорнуто у `ViewThatFits(in: .horizontal)`: коли ширина дозволяє — показуються повні назви мов (`Qırımtatarca` / `Українська` / `English`), а при звуженні вікна чи збільшеному шрифті — автоматично підставляється компактний варіант (`QT` / `УК` / `EN`) або вертикальний стек без жодних трьох крапок `...`.
  - Міні-капсули розкладок (`LatinCharactersMiniCapsulesView` та `UkrainianTransliterationMiniCapsulesView`) та компактні пігулки статистики (`statisticsAndAchievementsSection`) зроблено адаптивними через `ViewThatFits(in: .horizontal)`.
  - Знято жорсткі обмеження `.lineLimit(1)` та фіксовану висоту `frame(height: 20)` у заголовках секцій (`statusIndicatorsSection`, `keyboardSettingsSection`, `standardLayoutSection`, `cyrillicLayoutsSection`, `testingAndWritingSection`), плитках статистики (`statTile`, `walnutBrainStatTile`), бейджах досягнень (`progressiveAchievementBadge`), вікні «Вивчені слова» (`learnedWordsSheetView`), `AboutView`, `PrimaryButton`, `NavButton` та `KeyboardStateItem` — тепер усі тексти переносяться по рядках (`lineLimit(nil)`, `fixedSize(horizontal: false, vertical: true)`).

### 3.4. Персональний словник («Вивчені слова»): точність лічильника, видалення слів та автоматична звірка з базовим словником при оновленні з App Store
- **Файли**:
  - [`AppConfiguration.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Shared/AppConfiguration.swift)
  - [`SuggestionsDataBaseManager.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift)
  - [`DemoActionHandler.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoActionHandler.swift)
  - [`HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift)
- **Що виправлено**:
  1. **Миттєве оновлення лічильника «Вивчені слова»**:
     - У `HomeView` обробник `.onReceive(NotificationCenter.default.publisher(for: Self.localStatsRefreshNotification))` тепер викликає `refreshStatsFromAppGroup(syncSQLite: true, immediate: true)` замість `syncSQLite: false`, а `refreshStatsFromAppGroup` використовує прямий результат `KeyboardUsageStats.syncLearnedWordsCountFromSQLite()`.
     - У `KeyboardUsageStats.scheduleCrossProcessSync(immediate:)` додано `KeyboardPreferences.defaults.synchronize()` перед `CFPreferencesAppSynchronize` для гарантованого скидання кешу між процесами клавіатури та головного застосунку.
     - У `DemoActionHandler.handle(_ suggestion:)` при натисканні на підказку в панелі автодоповнення передається `explicitlyConfirmed: true`, а в `SuggestionsDataBaseManager.learnWordIfPermitted` повторно введені позасловникові слова (`(explicitlyConfirmed || existingUserFreq > 0) && baseFreq == 0`) отримують `is_custom = 1`. Водночас одиничне введення випадкового слова через пробіл (`explicitlyConfirmed == false && existingUserFreq == 0`) залишається `is_custom = 0`, що повністю зберігає контракт UI-тестів `QirimKeyUITests`.
  2. **Надійне видалення вивчених слів у будь-якому регістрі (включно з `Spotify`, `Qırımsöz` тощо)**:
     - У `KeyboardUsageStats.deleteLearnedWord(_:)` та `SuggestionsDataBaseManager.unlearnWord(_:)` зареєстровано користувацьку SQLite-функцію `unicode_lower` (з локаллю `crh_Latn`), видалення виконується за умовою `WHERE word = ?1 OR word = ?2 OR LOWER(word) = ?2 OR unicode_lower(word) = ?2` одночасно з `user_unigrams` та `user_bigrams`, після чого виконується `PRAGMA wal_checkpoint(PASSIVE)` і синхронно оновлюються обидва лічильники (`learnedWordsCount` і `uniqueWordsCount`).
  3. **Автоматична звірка вивчених слів із базовим словником `lexicon.sqlite` після оновлення з App Store або перевстановлення**:
     - Додано [`KeyboardUsageStats.reconcileUserLexiconWithBundledLexiconIfNeeded(userDB:)`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Shared/AppConfiguration.swift#L596-L654) та розширено [`SuggestionsDataBaseManager.demoteBundledCustomWordsIfNeeded()`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift#L976-L999) (регістронезалежна перевірка через `unicode_lower` з `crh_Latn` та кешування відбитка `size-mtime` файлу `lexicon.sqlite` у ключі `crh.key.stats.reconciledLexiconFingerprint`).
     - Якщо після оновлення застосунку з App Store слово з `user_unigrams` (`is_custom = 1`) вже присутнє в оновленому базовому словнику `lexicon.sqlite`, воно автоматично переводиться в `is_custom = 0` (прибирається зі списку «Вивчені слова» та з лічильника `learnedWordsCount`, але зберігає накопичену користувацьку частоту `freq` для ранжування підказок).

### 3.5. Покращення клавіатури, панелі підказок Liquid Glass, iPad-розкладки, мікрофона та продуктивності SQLite
- **Скляна напівпрозора панель підказок (Liquid Glass)**: у [`Autocomplete+NativeToolbarStyle.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift) та [`KeyboardViewController.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/KeyboardViewController.swift) реалізовано напівпрозорий скляний ефект (`UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))` та `.ultraThinMaterial` для капсул підказок).
- **Дві клавіші перемикання мов біля пробілу на iPad у латинській розкладці**: у [`CrimeanTatarIPadKeyboardLayoutProvider.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/CrimeanTatarIPadKeyboardLayoutProvider.swift) та [`DemoLayoutProvider.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoLayoutProvider.swift) забезпечено відображення обох клавіш швидкого перемикання розкладок біля пробілу.
- **Приховування системної кнопки мікрофона та синхронізація предиктивного вводу із системними налаштуваннями**: у [`KeyboardViewController.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/KeyboardViewController.swift) виставлено `hasDictationKey = false`, відфільтровано `.dictation` з розкладки, а стан предиктивного вводу синхронізовано із системним налаштуванням iOS.
- **Повернення кнопки «Системні налаштування»**: у [`HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift) відновлено кнопку переходу до системних налаштувань iOS (`home.settings.openSystemSettings`).
- **Кешування підготовлених SQLite-виразів (`sqlite3_stmt`) та C-bounds safety**: у [`SuggestionsDataBaseManager.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift) усунено повторну компіляцію `sqlite3_prepare_v2` на кожне натискання клавіші завдяки кешуванню `stmtWordsPrefix`, `stmtWordsFallbackPrefix`, `stmtUnigramFreq`, `stmtUserBigram`, `stmtBigram`, `stmtTrigram`, `stmtTypo` із безпечним `sqlite3_reset` + `sqlite3_clear_bindings` та обмеженням довжини вхідних буферів (`maxQueryLength = 64`, `maxSwipePoints = 256`).

---

## 4. Перелік змінених файлів проєкту

| Файл | Короткий зміст змін |
| :--- | :--- |
| [`QTatar/Demo/Demo/Views/HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift) | Розумна прокрутка поля вводу лише при перекритті клавіатурою; блокування автофокусу при зміні мови/теми; усунення лагу перемикача Світла/Темна тема; повна адаптивність елементів через `ViewThatFits` і `containerSize`; миттєва синхронізація лічильника та видалення «Вивчених слів»; відновлення кнопки «Системні налаштування». |
| [`QTatar/Demo/Shared/AppConfiguration.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Shared/AppConfiguration.swift) | Регістронезалежне видалення вивчених слів (`unicode_lower` з `crh_Latn`); автоматична звірка `user_lexicon.sqlite` із базовим `lexicon.sqlite` при оновленні з App Store (`reconcileUserLexiconWithBundledLexiconIfNeeded`); миттєва міжпроцесна синхронізація `scheduleCrossProcessSync`. |
| [`QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift) | Кешування `sqlite3_stmt`; C-bounds захист; `OSSignposter` інтервали; коректне виставлення `is_custom = 1` для підтверджених і повторюваних позасловникових слів; регістронезалежне `unlearnWord` та `demoteBundledCustomWordsIfNeeded`. |
| [`QTatar/Demo/Keyboard/DemoActionHandler.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoActionHandler.swift) | Передача `explicitlyConfirmed: true` при виборі підказки в панелі автодоповнення; оптимізація обробки натискань. |
| [`QTatar/Demo/Keyboard/KeyboardViewController.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/KeyboardViewController.swift) | Приховування системного мікрофона (`hasDictationKey = false`), скляна підкладка Liquid Glass панелі підказок, стабільний життєвий цикл розширення без фолбеку на системну клавіатуру. |
| [`QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift) | Напівпрозорий скляний стиль Liquid Glass (`.ultraThinMaterial`) для 3 слотів панелі підказок. |
| [`QTatar/Demo/Keyboard/CrimeanTatarIPadKeyboardLayoutProvider.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/CrimeanTatarIPadKeyboardLayoutProvider.swift) та [`DemoLayoutProvider.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoLayoutProvider.swift) | Симетричні клавіші перемикання розкладок біля пробілу на iPad та відфільтрування `.dictation`. |
| [`QTatar/Demo/Keyboard/CrimeanTatarTransliterator.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/CrimeanTatarTransliterator.swift) та [`TransliterationTests.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Tests/Transliteration/Tests/TransliterationTests/TransliterationTests.swift) | Правила `йы -> yı` після голосних, `джюри -> jüri` та 27 модульних і стрес-тестів. |
| [`AboutView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/AboutView.swift), [`PrimaryButton.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/Components/PrimaryButton.swift), [`NavButton.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/Components/NavButton.swift), [`KeyboardStateItem.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/Components/KeyboardStateItem.swift) | Багаторядкова адаптивність без обрізання тексту трьома крапками (`...`), Accessibility VoiceOver мітки та підвищений контраст. |
