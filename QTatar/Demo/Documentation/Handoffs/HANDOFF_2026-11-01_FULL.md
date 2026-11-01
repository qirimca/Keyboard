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
кнопка системні налаштування веде в налаштування додатка а не в налаштування
key flics з налаштувань не зчитується невраховується, перевір зчитуваннявсіхналаштуваньсистемних 
тести є але які результати та чи все виправив?
при вимкненні в системних налаштуваннях предиктивного вводу пересатє працювати свайп, він має працювати просто без верхньої панелі трьох інших варіантів і за рахунок цього може менше ресурсів споживати бо вводиться лише один варіант,але тут ми обробляли бекспейс пропонуючі нові варіанти, то тут вже ми б мали не показувати той самий варіант якщо він був щойно видалений бо користувач очевидно хоче інше слово в той момент якщо видалив щойно
стильклавіші абв на кириличній та українській розкладці має бути ідентичним до кнопки на самій клавіатурі айпада без тіні без 3д 
при натисканні на поле вводу в хомвью скрол трохи опускає екран додаючі клавіатуру хоча місце для всьогополя є і без опускання скролу,тому треба опускати скрол до поля лише якщо воно не влазить повністю 
також на пробілі коли мова зʼявляється на початку напару секунд вона має бути білого шрифту а не сірого як зараз, бо стандартні клавіатури мають білий шрифт, також глянь на фото який колір 3х підкахок зверху який їх колір шрифту такий самий роби для наших 3х підказок замість білого чи чорного 
перемикання в хомвью світлої темної теми тормозить трохи анімацію перемикання світча осоливо при першому запупску додатку 
 заупусти ще раз паралельно це все що пишеш тести
аналізуй фото відео всі на різних пристроях щоб проблеми небуло  та роби свої після виправлення щоб не було проблем вже  
/xctrace  /plan  /modernize-tests   /device-interaction  /app-resizability  /swiftui-specialist  /app-intents-specialist  /adopt-c-bounds-safety  /accessibility-dynamic-type-specialist  /building-document-based-swiftui-applications
````

### Запит 5 (`2026-11-01 18:59:39 UTC`)
````text
"чомусь при перемиканні мови активується поле вводу 
є пролема зміни ширин адаптивності, є ... замість адаптивності 
якщо є в системних налаштуваннях предиктивний ввід вимкнення то в налаштуваннях додатку його можна не давати а брати з системних налаштувань лише 
зроби аудит айпада (3) підключеногоо фенсе хенг перфоманс трейс логи тощо для вирпавлення проблем 
бачу перемикаєтсья на системний фолбек клавіатуру часто 
також мікрофон чомусь зʼявився назад під клавіатурою
кнопка системні налаштування веде в налаштування додатка а не в налаштування
key flics з налаштувань не зчитується невраховується, перевір зчитуваннявсіхналаштуваньсистемних 
тести є але які результати та чи все виправив?
при вимкненні в системних налаштуваннях предиктивного вводу пересатє працювати свайп, він має працювати просто без верхньої панелі трьох інших варіантів і за рахунок цього може менше ресурсів споживати бо вводиться лише один варіант,але тут ми обробляли бекспейс пропонуючі нові варіанти, то тут вже ми б мали не показувати той самий варіант якщо він був щойно видалений бо користувач очевидно хоче інше слово в той момент якщо видалив щойно
стильклавіші абв на кириличній та українській розкладці має бути ідентичним до кнопки на самій клавіатурі айпада без тіні без 3д 
при натисканні на поле вводу в хомвью скрол трохи опускає екран додаючі клавіатуру хоча місце для всьогополя є і без опускання скролу,тому треба опускати скрол до поля лише якщо воно не влазить повністю 
також на пробілі коли мова зʼявляється на початку напару секунд вона має бути білого шрифту а не сірого як зараз, бо стандартні клавіатури мають білий шрифт, також глянь на фото який колір 3х підкахок зверху який їх колір шрифту такий самий роби для наших 3х підказок замість білого чи чорного 
перемикання в хомвью світлої темної теми тормозить трохи анімацію перемикання світча осоливо при першому запупску додатку 
 заупусти ще раз паралельно це все що пишеш тести
аналізуй фото відео всі на різних пристроях щоб проблеми небуло  та роби свої після виправлення щоб не було проблем вже  
/xctrace  /plan  /modernize-tests   /device-interaction  /app-resizability  /swiftui-specialist  /app-intents-specialist  /adopt-c-bounds-safety  /accessibility-dynamic-type-specialist  /building-document-based-swiftui-applications"
перевір чи все повно без обмежень ти тут виконав щоб кожне речення кожне слово повністю було зроблено враховано включно з фото наданими раніше які треба було переобити з робочими станами з відео напланшетах та айфонах різних, глибше аналізуй та виправ все що не виправиви та пропустив
````

### Запит 6 (`2026-11-01 19:52:30 UTC`)
````text
зроби хендоф сього що зроби включно з експортомцієї розмови без змін повністю
````

---

## 3. Детальний технічний опис усіх виконаних змін у коді

### 3.1. Розумна прокрутка поля вводу та відсутність самовільної появи клавіатури при зміні мови інтерфейсу або теми (`P1.2`)
- **Файл**: [`HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift)
- **Що виправлено**:
  1. Прибрано безумовний обробник `.onChange(of: isWritingFieldFocused)`, який раніше викликав `scrollProxy.scrollTo("home.scrollTopAnchor", anchor: .top)` при кожному фокусуванні на полі вводу, через що екран опускався вниз навіть тоді, коли поле повністю поміщалося над клавіатурою.
  2. У [`SandboxTextView.Coordinator`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift):
     - У `textViewShouldBeginEditing(_:)` фіксується поточне зміщення зовнішнього `UIScrollView` (`preKeyboardOuterScrollOffset`) до того, як UIKit/SwiftUI намагається змістити скрол.
     - Додано підписку на `UIResponder.keyboardWillShowNotification`, `UIResponder.keyboardDidShowNotification` та `UIResponder.keyboardWillChangeFrameNotification` (`adjustOuterScrollViewForKeyboard(notification:)`).
     - Обчислюється нижня межа контейнера поля вводу при збереженому зміщенні (`fieldBottomAtSavedOffset`) відносно верхньої межі клавіатури (`keyboardTopY = kbFrameInWindow.minY`).
     - Якщо `fieldBottomAtSavedOffset <= keyboardTopY` (поле повністю вміщується над клавіатурою), будь-яка автоматична прокрутка UIKit/SwiftUI миттєво скасовується (`outerScrollView.setContentOffset(savedOffset, animated: false)` у `UIView.performWithoutAnimation` синхронно та через `0.025s`, `0.08s`, `0.18s`, `0.30s`), і екран залишається нерухомим.
     - Тільки якщо `fieldBottomAtSavedOffset > keyboardTopY` (поле перекривається клавіатурою), `outerScrollView` прокручується рівно на необхідний дельта-відступ `neededOverflow = (fieldBottomAtSavedOffset + 6.0) - keyboardTopY`.
  3. Щоб при перемиканні мови інтерфейсу (`QT` / `УК` / `EN`) або теми клавіатура не вискакувала і фокус не переходив у поле вводу:
     - У [`languageSegmentedControl`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift) перед зміною `language` виставляється `shouldAutoFocusSandbox = false`.
     - При приховуванні клавіатури (`UIResponder.keyboardWillHideNotification`) та в `SandboxTextView.updateUIView` / `textViewDidBeginEditing` / `textViewDidEndEditing` прапорець `shouldAutoFocusSandbox` скидається в `false` через `onDidAutoFocus()`.

### 3.2. Усунення затримки (лагу) при перемиканні Світлої / Темної теми та синхронізації налаштувань без блокування головного потоку (`Critical Bugs 2 & 3`)
- **Файли**: [`HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift), [`AppConfiguration.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Shared/AppConfiguration.swift), [`DemoStyleProvider.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoStyleProvider.swift), [`KeyboardViewController.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/KeyboardViewController.swift)
- **Що виправлено**:
  1. У [`syncThemeToAppGroup`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift), [`syncSandboxFocusToAppGroup`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift), [`clearThemeOverride`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift) та [`SandboxTextView.Coordinator`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift) прибрано синхронні виклики `defaults.synchronize()`, `CFPreferencesAppSynchronize(...)` та `CFNotificationCenterPostNotification(...)` із головного потоку — тепер вони виконуються асинхронно у фоновій черзі `HomeView.bgPrefsAndSQLiteQueue`.
  2. У [`SystemKeyboardSettings.triggerAsyncRefreshIfNeeded`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Shared/AppConfiguration.swift) прибрано синхронний `CFPreferencesSynchronize` на головному потоці (`shouldSync: false` на main thread, `shouldSync: true` лише на фоновій `refreshQueue`).
  3. У [`DemoStyleProvider.effectiveIsDark`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoStyleProvider.swift) та [`KeyboardViewController.refreshProxyState`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/KeyboardViewController.swift) усунено мутацію `@Published state.keyboardContext.traitCollection` під час рендеру та подвійну мутацію у `refreshProxyState`.

### 3.3. Повна адаптивність інтерфейсу при зміні розміру вікна (iPad Stage Manager / Split View: вузькі `375 pt`, середні `560–819 pt` та широкі `>= 820 pt` вікна) без обрізань `...` (`P0.2`)
- **Файли**:
  - [`HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift)
  - [`AboutView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/AboutView.swift)
- **Що зроблено**:
  - У `HomeView` поріг двоколонкової сітки `usesTwoColumns` піднято з `540 pt` до `820 pt` (`effectiveWidth >= 820`), а `minimumSize` вікна Stage Manager знижено до `CGSize(width: 375, height: 420)` із фіксацією `ScrollView` до ширини контейнера.
  - Для середніх вікон (`< 820 pt`), де картки переходять в 1 колонку, `effectiveCardColumnWidth` дорівнює повній ширині картки (`effectiveWidth - 36`), тому рядок «Мова інтерфейсу» має достатньо місця і не переходить на `QT / УК / EN` передчасно; на дуже вузьких вікнах використовується дворядковий `VStack` із повними назвами мов без жодного обрізання `Мов...`.
  - У `AboutView` картку «ПРО ПРОЄКТ» обгорнуто у `ViewThatFits(in: .horizontal)` (2 колонки на широких екранах, 1 колонка при звуженні), а 5 кнопок соцмереж (`GitHub`, `Instagram`, `Facebook`, `Telegram`, `LinkedIn`) мають `fixedHorizontal: true` і автоматично перебудовуються у сітку `2 + 2 + 1` без жодного `Instagr...` чи `Faceb...`.

### 3.4. Робота свайпу при вимкненому системному «Предиктивному вводі» (`Predictive Text` OFF) та розумний `Backspace` (`P0.1`)
- **Файли**:
  - [`KeyboardViewController.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/KeyboardViewController.swift)
  - [`DemoActionHandler.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoActionHandler.swift)
- **Що зроблено**:
  - Відокремлено `SwipeTypingState.shared.isSlideToTypeSettingEnabled = SystemKeyboardSettings.isSlideToTypeEnabled` від `isAutocompleteEnabled` (`Predictive Text`), а базу даних `SuggestionsDataBaseManager` підготовлено також тоді, коли активний `isSlideToTypeEnabled`.
  - Коли `Predictive Text` вимкнено в системних налаштуваннях, свайп-введення (`Slide to Type`) продовжує працювати без верхньої панелі з 3 підказок і споживає менше ресурсів (вставляється лише 1 найкращий кандидат без побудови та рендеру 3-слотової панелі).
  - Коли користувач натискає `Backspace` одразу після свайп-введення слова (видаляючи щойно свайпнуте слово), це слово додається у `lastDeletedSwipeWords`; при повторному свайпі в тій самій позиції щойно видалений варіант відфільтровується з кандидатів і замість нього вставляється наступний найкращий варіант.

### 3.5. Плоский нативний стиль кнопки `[абв]` на iPad (`P0.3`), білий шрифт повної назви мови на пробілі та нативний колір шрифту 3-х підказок (`P0.4`), синхронізація `Key Flicks` (`P0.5–P0.6`) і чиста верхня панель на iPad (`P1.1`)
- **Файли**:
  - [`HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift)
  - [`SpaceBarLabel.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift)
  - [`Autocomplete+NativeToolbarStyle.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift)
  - [`KeyboardViewController.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/KeyboardViewController.swift)
  - [`Settings.bundle/Root~ipad.plist`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Settings.bundle/Root~ipad.plist) та [`Settings.bundle/Root.plist`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Settings.bundle/Root.plist)
- **Що зроблено**:
  - **Плоский стиль `[абв]` на iPad (`P0.3`)**: у `HomeView.iPadAbvSelectorButton` прибрано 3D-тінь/нижній виступ та градієнт; використано плоский `RoundedRectangle(cornerRadius: 7)` із нативними кольорами клавіш iPad.
  - **Білий шрифт повної назви мови на пробілі та колір 3-х підказок (`P0.4`)**: у `SpaceBarLabel` повна назва мови (`Qırımtatarca`, `Къырымтатарджа`, `Кʼиримтатарджа`) протягом перших 3 секунд відображається чисто білим кольором (`Color.white` у темній темі, `Color.black.opacity(0.88)` у світлій), після чого плавно переходить у 2-літерний код (`QT`, `КЪ`, `Кʼ`) із нативною прозорістю (`0.30` / `0.20`). У `Autocomplete+NativeToolbarStyle` вирівняно колір шрифту 3-х підказок до нативного стилю iPadOS (`0.88` у темній / `0.85` у світлій темі).
  - **Синхронізація `Key Flicks` та системних налаштувань (`P0.5–P0.6`)**: у `KeyboardViewController.refreshProxyState` та `syncPreferencesFromDiskInBackground` додано перевірку змін `isKeyFlicksEnabled`, `isSlideToTypeEnabled`, `isPredictiveTextEnabled`, `isAutoCorrectionEnabled`, `isAutoCapitalizationEnabled`, `isShowMathResultsEnabled`; у `Settings.bundle/Root~ipad.plist` додано перемикач `Tüşme belgi jesti` (`Enable Key Flicks` / `Жести прокручування клавіш`, ключ `crh.key.feature.keyFlicks`).
  - **Очищення системних кнопок `UITextInputAssistantItem` на iPad (`P1.1`)**: у `SandboxTextView` та `KeyboardViewController` безумовно очищено `inputAssistantItem.leadingBarButtonGroups = []` та `trailingBarButtonGroups = []` також на iPad, щоб системні іконки Undo/Paste не накладалися на 3 слоти підказок.

### 3.6. Персональний словник («Вивчені слова»): звірка з базовим словником `qırım_tatar.db` (`words`) при оновленні та захист власних назв (`Bug A & Bug B`)
- **Файли**:
  - [`AppConfiguration.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Shared/AppConfiguration.swift)
  - [`SuggestionsDataBaseManager.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift)
- **Що виправлено**:
  1. У [`KeyboardUsageStats.reconcileUserLexiconWithBundledLexiconIfNeeded`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Shared/AppConfiguration.swift) виправлено шлях і схему базового словника: замість неіснуючого `lexicon.sqlite` (`unigrams`) відкривається реальна база `qırım_tatar.db` (у головному бандлі або в `PlugIns/Keyboard.appex/qırım_tatar.db`) і перевіряється таблиця `words` за оригінальною, нижньорегістровою (`crh_Latn`) та капіталізованою формами (`crh.key.stats.bundledLexiconSignature.v2`).
  2. У [`SuggestionsDataBaseManager.bundledFrequency(of:)`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift) запит `SELECT MAX(freq) FROM words WHERE word = ?1 OR word = ?2 OR word = ?3;` перевіряє всі три варіанти регістру (`trimmed`, `lower`, `cap`), завдяки чому власні назви та топоніми з великої літери у `words` (`Qırım` з частотою `95539`, `Aqmescit`, `Bağçasaray` тощо) розпізнаються як базові словникові слова і ніколи помилково не записуються у «Вивчені слова» (`is_custom = 1`).
  3. У [`SuggestionsDataBaseManager.learnWordIfPermitted`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift) відновлено правило `isCustom: explicitlyConfirmed && baseFreq == 0`, щоб звичайний набір слів через пробіл записувався в `user_unigrams` (`is_custom = 0`), а до персонального словника (`is_custom = 1`) потрапляли лише явно підтверджені позасловникові слова.
  4. Вилучено всі рядки приватних API (`TI#Preferences#Controller`, `UI#Keyboard#Preferences#Controller`, `com.apple.#keyboard.preferences`) із [`AppConfiguration.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Shared/AppConfiguration.swift) та розширено [`scripts/check_private_apis.py`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/check_private_apis.py) (`Critical Bug 1`).

---

## 4. Перелік змінених файлів проєкту

| Файл | Короткий зміст змін |
| :--- | :--- |
| [`QTatar/Demo/Demo/Views/HomeView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift) | Розумна прокрутка поля вводу лише при перекритті клавіатурою (`P1.2`); плоский стиль кнопки `[абв]` на iPad (`P0.3`); повна адаптивність вікон Stage Manager (`P0.2`); очищення `inputAssistantItem` на iPad (`P1.1`); усунення лагу перемикача теми (`Critical Bug 2/3`). |
| [`QTatar/Demo/Demo/Views/AboutView.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/AboutView.swift) | Адаптивна сітка картки «Про проєкт» (`ViewThatFits`) та кнопок соцмереж (`2 + 2 + 1`, `fixedHorizontal: true`) без обрізання `...` у вузьких вікнах Stage Manager (`P0.2`). |
| [`QTatar/Demo/Shared/AppConfiguration.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Shared/AppConfiguration.swift) | Видалення обфускованих рядків приватних API (`Critical Bug 1`); звірка `user_lexicon.sqlite` зі справжньою базою `qırım_tatar.db` (`words`) у всіх регістрах (`Bug A`); асинхронне оновлення системних налаштувань без блокування main thread (`Critical Bug 2`). |
| [`QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SuggestionsDataBaseManager.swift) | Регістронезалежний `bundledFrequency(of:)` та `demoteBundledCustomWordsIfNeeded()` для власних назв (`Qırım`, `Aqmescit`) і правило `isCustom: explicitlyConfirmed && baseFreq == 0` (`Bug B`). |
| [`QTatar/Demo/Keyboard/DemoActionHandler.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoActionHandler.swift) | Підтримка свайпу при вимкненому `Predictive Text` без верхньої панелі 3-х варіантів та виключення щойно видаленого через `Backspace` свайп-слова при повторному свайпі (`P0.1`). |
| [`QTatar/Demo/Keyboard/KeyboardViewController.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/KeyboardViewController.swift) | Синхронізація `isKeyFlicksEnabled`, `isSlideToTypeEnabled`, `isPredictiveTextEnabled`, `isShowMathResultsEnabled` (`P0.5–P0.6`), очищення `inputAssistantItem` (`P1.1`), усунення подвійної мутації `traitCollection` (`Critical Bug 3`). |
| [`QTatar/Demo/Keyboard/SpaceBarLabel.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift) та [`QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift) | Чисто білий шрифт повної назви мови на пробілі у перші 3 секунди та нативний колір шрифту 3-х підказок зверху (`P0.4`). |
| [`QTatar/Demo/Demo/Settings.bundle/Root~ipad.plist`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Settings.bundle/Root~ipad.plist) та [`Root.plist`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Settings.bundle/Root.plist) | Додано перемикач `Tüşme belgi jesti` (`Enable Key Flicks` / `Жести прокручування клавіш`, `crh.key.feature.keyFlicks`) для iPad (`P0.5`). |
| [`scripts/check_private_apis.py`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/check_private_apis.py) та [`scripts/tests/test_private_api_guard.py`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/tests/test_private_api_guard.py) | Детектування обфускації приватних селекторів/класів через `replacingOccurrences(of:with:)` (`Critical Bug 1`). |

