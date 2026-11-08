# Візуальні пропозиції редизайну, мінімалістичної архітектури та алгоритмічних мікроанімацій QırımKey (2026-11-08)

Документ узагальнює паралельне дослідження та візуальні концепти, створені із застосуванням чотирьох спеціалізованих навичок дизайну:
- [SKILL.md (claude-canvas-design)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-canvas-design/SKILL.md) — музейні композиційні дошки високої роздільної здатності (`2400x1600`), просторова типографіка, мінімалістична ієрархія клавіш.
- [SKILL.md (claude-frontend-design)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-frontend-design/SKILL.md) — інтерактивний прототип робочої станції клавіатури та `Bento`-карток додатку без шаблонних штампів, з тактильною фізикою `Liquid Glass`.
- [SKILL.md (claude-algorithmic-art)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-algorithmic-art/SKILL.md) — генеративна `p5.js`-лабораторія гармонійного дихання емблеми [`TaraqTamgaShape`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift#L70-L111), фазово-неперервна математика `CoreAnimation` (`15..75 WPM -> 1.0x..2.9x`) та фізика комети свайпу `QırımKey Swipe v2`.
- [SKILL.md (claude-theme-factory)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-theme-factory/SKILL.md) — колекція з 6 культурно закорінених та мінімалістичних палітр для клавіатури й основного додатку з перевіреним контрастом `WCAG AA/AAA`.

> **Статус пропозицій**: Усі матеріали зібрані ізольовано у каталозі [visual_proposals](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals) без внесення змін у робочі файли [HomeView.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift), [Autocomplete+NativeToolbarStyle.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift), [SpaceBarLabel.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift), [SystemKeyboard.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Sources/KeyboardKit/_Essentials/SystemKeyboard.swift) та [DemoStyleProvider.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoStyleProvider.swift) до вибору користувачем бажаних варіантів.

---

## 0. Реєстр згенерованих візуальних артефактів та інтерактивних прототипів

| Категорія | Артефакт | Призначення |
| :--- | :--- | :--- |
| **Дошка 1 (`PNG`, `2400x1600`)** | [Proposal_1_Minimalist_Keyboard_Concepts.png](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Proposal_1_Minimalist_Keyboard_Concepts.png) | Три архітектури 12-колонкової клавіатури: `1A Liquid Whisper (Rim-Lit Glass)`, `1B Typographic Air (Borderless)`, `1C Nocturnal Glass & ФІВА 12x12` + 4x оптичний розріз клавіші (`ğ`, `ş`, `ʼ U+02BC`). |
| **Дошка 2 (`PNG`, `2400x1600`)** | [Proposal_2_HomeView_Editorial_Bento.png](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Proposal_2_HomeView_Editorial_Bento.png) | Редизайн [HomeView.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift): замкнені векторні емблеми мови (`#FFD700` на `#1295D8`), нижні стек-рядки `Кирилична клавіатура` та `Українська розкладка` з селекторами [`iPadAbvSelectorButton`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L4104-L4135), чистий заголовок `Статистика` з 2-плитковою згорнутою сіткою [`bentoCollapsedStatisticsGrid`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L4752-L4789) та 5 рівнів швидкості (`15 · 25 · 40 · 55 · 75 WPM`). |
| **Дошка 3 (`PNG`, `2400x1600`)** | [Proposal_3_MicroAnimations_And_Comet_Spec.png](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Proposal_3_MicroAnimations_And_Comet_Spec.png) | Специфікація алгоритмічних мікроанімацій: графік фазово-неперервного дихання [`BreathingTamgaUIView`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift#L131-L364), геометрія комети `Swipe v2` (`Bezier + Chaikin`) із підсвічуванням кутових якорів `Δθ >= 22°` (`s -> e -> l -> a -> m`), та 3 стани верхньої панелі без перекриття. |
| **Дошка 4 (`PNG`, `2400x1600`)** | [Proposal_4_ThemeFactory_Palettes.png](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Proposal_4_ThemeFactory_Palettes.png) | Візуальне порівняння 6 палітр `Theme Factory` безпосередньо на 12-колонковій клавіатурі (`QT` та `Кʼ`). |
| **Прев'ю інтерактивного прототипу 1 (`PNG`, `1600x1040`)** | [Preview_Interactive_1_Tamga_Harmonic_Flow.png](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Preview_Interactive_1_Tamga_Harmonic_Flow.png) | Реальний браузерний знімок генеративного гармонійного поля `Taraq Tamğa` навколо 20-вершинного полігону `9x5` ([Interactive_1_Tamga_Harmonic_Flow_p5.html](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Interactive_1_Tamga_Harmonic_Flow_p5.html)). |
| **Прев'ю інтерактивного прототипу 2 (`PNG`, `1600x1040`)** | [Preview_Interactive_2_Minimalist_Keyboard_And_Comet_Lab.png](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Preview_Interactive_2_Minimalist_Keyboard_And_Comet_Lab.png) | Реальний браузерний знімок інтерактивної лабораторії клавіатури, комети `Swipe v2` та `HomeView` ([Interactive_2_Minimalist_Keyboard_And_Comet_Lab.html](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Interactive_2_Minimalist_Keyboard_And_Comet_Lab.html)). |
| **Інтерактивний прототип 1 (`p5.js`)** | [Interactive_1_Tamga_Harmonic_Flow_p5.html](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Interactive_1_Tamga_Harmonic_Flow_p5.html) | Живий генеративний `p5.js`-стенд (на базі шаблону [viewer.html](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-algorithmic-art/templates/viewer.html)) із керуванням `Seed`, `WPM (0..75)`, силою тяжіння до 20 вершин `Taraq Tamğa`, вихоровою турбулентністю та імпульсом золотого кільця при фіксації слова. |
| **Інтерактивний прототип 2 (`HTML/JS/Canvas`)** | [Interactive_2_Minimalist_Keyboard_And_Comet_Lab.html](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Interactive_2_Minimalist_Keyboard_And_Comet_Lab.html) | Інтерактивна лабораторія: перемикання 3 мінімалістичних режимів клавіатури, 6 тем `Theme Factory`, 3 розкладок (`QT`, `КЪ`, `Кʼ`), живий свайп мишею/трекпадом з кометою `Swipe v2` та інтерактивні картки [HomeView.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift). |
| **Філософії та специфікації (`MD`)** | [CANVAS_DESIGN_PHILOSOPHY.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/CANVAS_DESIGN_PHILOSOPHY.md), [ALGORITHMIC_ART_PHILOSOPHY.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/ALGORITHMIC_ART_PHILOSOPHY.md), [THEME_FACTORY_PALETTES.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/THEME_FACTORY_PALETTES.md) | Теоретичні засади оптичної тиші (`Tactile Whisper`), алгоритмічної біо-синхронізації та таблиці кольорових токенів. |
| **Генератор дощок (`Python`)** | [generate_visual_boards.py](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/generate_visual_boards.py) | Відтворюваний векторно-растровий скрипт генерації статичних `PNG`-дощок без жодного символу емодзі. |

---

## 1. Напрям I ([SKILL.md (claude-canvas-design)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-canvas-design/SKILL.md) + [SKILL.md (claude-frontend-design)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-frontend-design/SKILL.md)): Три мінімалістичні архітектури 12-колонкової клавіатури

![Proposal 1 Minimalist Keyboard Concepts](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Proposal_1_Minimalist_Keyboard_Concepts.png)

У поточній реалізації [DemoStyleProvider.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoStyleProvider.swift) та [SystemKeyboard.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Sources/KeyboardKit/_Essentials/SystemKeyboard.swift) 12-колонкова сітка (`q..ü`, `й..ъ`, `й..ї`) розміщує 36 алфавітних клавіш з додатковими flick-символами. На вузьких екранах iPhone 36 окремих прямокутних рамок можуть створювати відчуття візуальної щільності. Ми пропонуємо **три рівні мінімалізму**, які можна або застосувати як базове покращення (`Варіант 1A`), або додати як перемикач стилю клавіатури в [HomeView.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift):

### Варіант 1A — `Liquid Whisper (Rim-Lit Glass)` (Рекомендований для базового стилю за замовчуванням)
1. **Тонкий верхній блік (`0.5 pt Top Specular Rim`) замість важкої нижньої тіні**:
   - У [`buttonBackgroundColor(for:isPressed:)`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoStyleProvider.swift#L486-L582) та стилях клавіш зменшити непрозорість нижньої тіні до `0.10` (`radius: 0.75, y: 1.0`) і додати верхній лінійний градієнтний контур `0.5 pt` (`white 45% -> 8%` у світлій темі, `white 18% -> 3%` у темній). Це надає клавішам відчуття цільного матового скла iOS 26/27 без візуального шуму.
2. **Оптичне приглушення вторинних flick-символів (`Whisper Flick Hierarchy`)**:
   - Зменшити базову непрозорість вторинних символів у верхньому правому куті клавіші з `0.38` до **`0.22`** у стані спокою (`9.5 pt SF Pro Condensed Semibold`).
   - Під час дотику (`isPressed`) або початку вертикального жесту (`flick down`) плавно піднімати непрозорість flick-символу активної клавіші до **`0.65`** за `90 ms`. Очі бачать чисті літери під час звичайного набору, але миттєво зчитують цифри та знаки при жесті.
3. **Центрована фраза дня без фону (`Color.clear`) поруч із кнопкою `sparkles`**:
   - У [`greetingBannerView(centerWidth:)`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift#L1427-L1490) емблема [`BreathingTamgaView`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift#L115-L129), текст прислів'я (`16.0 pt` iPhone / `17.0 pt` iPad Docked), іконка `arrow.up.left.circle.fill` та кнопка `sparkles` розташовуються **поряд по центру панелі** (`HStack(alignment: .center, spacing: 4)`) на абсолютно прозорому фоні (`Color.clear`), тоді як стадіонна капсула (`cornerRadius = 14.0 pt`) резервується виключно для активного кандидата автовиправлення (`suggestion.isAutocorrect`).

### Варіант 1B — `Typographic Air (Borderless Minimalist Mode)` (Ультрамінімалістичний режим)
1. **Повна відмова від рамок для 33 літерних клавіш**:
   - Для алфавітних клавіш рядів `0..2` фон клавіші стає повністю прозорим (`Color.clear`), залишаючи у повітрі лише бездоганно вирівняну типографіку (`24.5 pt SF Pro Regular`) та ледь помітні flick-мітки (`18%` непрозорості).
2. **Периметральний якір системних клавіш**:
   - Лише периметральні функціональні клавіші (`Shift`, `Backspace`, `123`, `абв`/`abc` у [`buttonText(for:)`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoStyleProvider.swift#L367-L395), `Space`, `Return`) зберігають напівпрозорі скляні капсули (`cornerRadius = 8.5 pt`). Це зберігає м'язову пам'ять великих пальців і межі клавіатури, але зменшує кількість високочастотних контрастних граней на екрані на **74%**.
3. **Тактильне світлове коло при дотику (`Touch-Down Radial Bloom`)**:
   - Коли палець торкається літери у безрамковому режимі, під літерою на `120 ms` розквітає м'який радіальний ореол (`radius = 24 pt`, `accentPrimary.opacity(0.14)`) перед появою стандартного балона збільшення літери.

### Варіант 1C — `Nocturnal Glass & Українська ФІВА 12x12`
1. **Візуальний акцент спеціалізованих клавіш `ФІВА` (`ї`, `є`, `ʼ`, `ґ`) та клавіші `abc`**:
   - На українській адаптованій розкладці (`ФІВА`, де `ї -> yi` на Ряді 0 Кол 11, `є -> ye/e` на Ряді 1 Кол 10, розумний апостроф `ʼ (U+02BC) -> q/ñ/ğ` на Ряді 1 Кол 11, `ґ -> g` на Ряді 2 Кол 10, а клавіша перемикання абетки відображає `abc` згідно з [`buttonText(for:)`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoStyleProvider.swift#L367-L395)) пропонується делікатно позначати flick-підказки трансляції (`yi`, `ye`, `q/ñ`, `g`) акцентним небесно-блакитним кольором (`#1295D8` з непрозорістю `0.48`), щоб нові користувачі миттєво бачили фонетичний міст між українською та кримськотатарською абетками.

---

## 2. Напрям II ([SKILL.md (claude-frontend-design)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-frontend-design/SKILL.md) + [SKILL.md (claude-canvas-design)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-canvas-design/SKILL.md)): Едиторіал-ієрархія [HomeView.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift), нижні рядки `Къ`/`Кʼ` із селекторами `[абв]` на iPad та 2-плиткова `Статистика`

![Proposal 2 HomeView Editorial Bento](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Proposal_2_HomeView_Editorial_Bento.png)

Аналіз [HomeView.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift) виявив кілька точок, де візуальну ієрархію та мікроанімації можна зробити ще чистішими й виразнішими з 100% дотриманням архітектурних правил проєкту:

### 2.1. Замкнені векторні емблеми та ізоляція тригерів анімації ([HomeView.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift))
- **Національне золото на небесно-блакитному тлі**: У рядку «Мова інтерфейсу» емблема [`TaraqTamgaShape`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift#L70-L111) для `crh` (`Qırımtatarca`) рендериться у національному золоті (`#FFD700`) на градієнтній небесно-блакитній 3D-клавіші (`#1295D8 -> #0B72B5`).
- **Сувора ізоляція тригерів**: Перемикання мови інтерфейсу (`QT <-> УК <-> EN`) анімує виключно векторну емблему мови (`Taraq Tamğa` / `Тризуб` / `Union Jack`) і ніколи не викликає повторного спрацьовування анімації бейджів кириличної (`Къ -> Q -> Къ`, `cyrillicBadgeTrigger`) чи української (`Кʼ -> Q -> Кʼ`, `ukrainianBadgeTrigger`) клавіатур.

### 2.2. Нижні стек-рядки `Кирилична клавіатура` та `Українська розкладка` і тактильний селектор [`iPadAbvSelectorButton`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L4104-L4135)
- У секції [`keyboardSettingsSection`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L3980-L4102) бейджі `Къ Додано` (`status.cyrillicKeyboard.addedBadge`) та `Кʼ Додано` (`status.ukrainianKeyboard.addedBadge`, виключно при `language == "uk"`) відображаються лише у верхньому рядку `status.primaryKeyboard.row`.
- Рядок `Кирилична клавіатура` (`settings.cyrillic.statusRow`) розташований унизу картки у всіх 3 мовах інтерфейсу, а безпосередньо під ним у самому низу — окремий рядок `Українська розкладка` (`settings.ukrainianCyrillic.statusRow` із компактними капсулами `ґ → g · г → ğ · кʼ → q · нʼ → ñ`), який відображається **виключно при `language == "uk"`**, щоб перемикання `QT ↔ УК ↔ EN` ніколи не зсувало верхні рядки.
- Коли на iPad обидві розкладки увімкнені в `uk`, у кожному з двох нижніх рядків праворуч поруч із `Toggle` рендериться вертикально центрована кнопка-клавіша `[абв]` ([`iPadAbvSelectorButton`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L4104-L4135): `settings.cyrillic.abvSelector` та `settings.ukrainianCyrillic.abvSelector`) з пружинним відгуком `.spring(response: 0.26, dampingFraction: 0.78)`.

### 2.3. Мікро-спарклайн та кільце майстерності у 2-плитковій сітці [`bentoCollapsedStatisticsGrid`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L4752-L4789)
- У згорнутому режимі картки `Статистика` (`statsEnabled && !isStatsExpanded`) заголовок залишається абсолютно чистим (`[бейдж графіка] Статистика [Toggle] >` без застарілих 4 міні-капсул у шапці), а під ним відображаються 2 великі симетричні плитки в `HStack(spacing: 10)`:
  1. **`stats.wordsTile` («Написано слів»)**: велике моноширинне число (`system(size: 26, weight: .bold, design: .rounded)`), підзаголовок `Унікальних: Y` (із таблиці `user_unigrams`) та **пропонований 7-денний векторний мікро-спарклайн** (`Path` завширшки `46 pt`, що показує динаміку щоденного набору без перевантаження інтерфейсу).
  2. **`stats.speedTile` («Швидкість друку»)**: показник виключно у `WPM` / `сл/хв` / `söz/daq` (без `CPM` / `зн/хв`) та **пропоноване 5-сегментне кільце прогресу (`WPM Mastery Ring`)**, яке візуально відображає поточний емпіричний рівень користувача серед 5 норм (`15 · 25 · 40 · 55 · 75 WPM`).

---

## 3. Напрям III ([SKILL.md (claude-algorithmic-art)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-algorithmic-art/SKILL.md)): Біо-синхронна математика `Taraq Tamğa`, комета `Swipe v2` та золотий імпульс слова

![Proposal 3 MicroAnimations And Comet Spec](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Proposal_3_MicroAnimations_And_Comet_Spec.png)

![Preview Interactive 1 Tamga Harmonic Flow](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Preview_Interactive_1_Tamga_Harmonic_Flow.png)

![Preview Interactive 2 Minimalist Keyboard And Comet Lab](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Preview_Interactive_2_Minimalist_Keyboard_And_Comet_Lab.png)

### 3.1. Нова мікроанімація: «Золотий гармонійний імпульс» (`Word-Commit Golden Ripple`) на пробілі
У [`BreathingTamgaUIView`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift#L131-L364) емблема [`TaraqTamgaShape`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift#L70-L111) вже має безшовне фазово-неперервне дихання (`minOpacity = 0.25 -> 0.52`, `scale = 0.975 -> 1.045`, `duration = 2.2s`, прискорення `1.0x -> 2.9x` пропорційно `15..75 WPM` та заспокоєння через `60s`).
- **Пропозиція**: Додати вторинний контурний шар `rippleShapeLayer: CAShapeLayer` з тим самим 20-вершинним шляхом [`TaraqTamgaShape`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift#L70-L111) (`fillColor = nil`, `strokeColor = UIColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0).cgColor`, `lineWidth = 0.8`).
- **Коли спрацьовує**: Тільки у два моменти високої цінності — (1) коли користувач фіксує автовиправлення пробілом (`.space`), або (2) коли завершується розпізнавання слова свайпом (`Swipe v2`).
- **Хореографія (`0.42s`, `0% CPU` у спокої)**: Контур `Taraq Tamğa` розширюється від `scale = 1.0` до `1.45` з кривою `CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)`, а його `opacity` плавно згасає з `0.45` до `0.0`. Це дає тонке підсвідоме підтвердження, що клавіатура розпізнала й зберегла кримськотатарське слово.

```swift
// Пропоноване розширення для SpaceBarLabel.swift (BreathingTamgaUIView)
func triggerWordCommitGoldenRipple() {
    let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
    scaleAnim.fromValue = 1.0
    scaleAnim.toValue = 1.45

    let opacityAnim = CABasicAnimation(keyPath: "opacity")
    opacityAnim.fromValue = 0.45
    opacityAnim.toValue = 0.0

    let group = CAAnimationGroup()
    group.animations = [scaleAnim, opacityAnim]
    group.duration = 0.42
    group.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0)
    group.isRemovedOnCompletion = true
    rippleShapeLayer.add(group, forKey: "wordCommitGoldenRipple")
}
```

### 3.2. Нова візуальна підказка `QırımKey Swipe v2`: Магнітне підсвічування кутових якорів (`Δθ >= 22° Anchor Keycap Glow`)
У [SystemKeyboard.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Sources/KeyboardKit/_Essentials/SystemKeyboard.swift) рушій `Swipe v2` вже обчислює кути повороту траєкторії та надає підвищену вагу точкам перегину (`Δθ >= 22°`), відсікаючи колінеарні транзитні клавіші.
- **Пропозиція**: Під час активного свайпу підсвічувати тонким золотим/блакитним контуром (`1.2 pt`, `opacity = 0.42`, загасання `180 ms`) лише ті клавіші, які стали **кутовими якорями (`Δθ >= 22°`)** або стартовою/кінцевою точкою слова, залишаючи транзитні клавіші нейтральними.
- **Ефект**: Користувач інтуїтивно відчуває «магнітну геометрію» свайпу і розуміє, що навіть швидкий розмашистий жест точно зафіксував ключові літери слова (протестувати наживо можна у [Interactive_2_Minimalist_Keyboard_And_Comet_Lab.html](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Interactive_2_Minimalist_Keyboard_And_Comet_Lab.html)).

---

## 4. Напрям IV ([SKILL.md (claude-theme-factory)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-theme-factory/SKILL.md)): 6 культурних та мінімалістичних палітр QırımKey

![Proposal 4 ThemeFactory Palettes](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Proposal_4_ThemeFactory_Palettes.png)

Повна таблиця `HEX`/`RGBA`-токенів та коефіцієнтів контрастності `WCAG AA/AAA` наведена у файлі [THEME_FACTORY_PALETTES.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/THEME_FACTORY_PALETTES.md):

1. **`01 · Native iOS Liquid Glass`** — еталонна системна прозорість iOS 26/27 із кримським небесно-блакитним акцентом (`#0087DB`) та золотом [`TaraqTamgaShape`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift#L70-L111) (`#FFD700`).
2. **`02 · Bağçasaray Limestone & Gold`** — теплий бахчисарайський вапняк (`#EAE0D0`), кремові клавіші (`#FBF8F3`), глибоке горіхове чорнило (`#231F1B`, контраст `13.8:1 AAA`) та філігранне золото (`#C88A14`).
3. **`03 · Qara Deñiz Midnight`** — глибока нічна палітра Чорного моря (`#0B131E`) з морськими сланцевими клавішами (`#18263A`) та біолюмінесцентною блакитною кометою свайпу (`#38BDF8`).
4. **`04 · Aqmescit Minimalist Paper`** — архівний папір (`#F3F1EC`) із кобальтовим акцентом (`#1D4ED8`), спроєктований спеціально для безрамкового режиму `Typographic Air (Borderless)`.
5. **`05 · Steppe Dawn (Çöl Tañı)`** — світанковий кримський степ: полиново-шавлієвий акцент (`#4A7C6F`), тепла шовкова поверхня клавіш (`#FFFDFB`) та теракотово-абрикосовий слід комети (`#E07A5F`).
6. **`06 · Chufut-Kale Obsidian (OLED Monolith)`** — висококонтрастна `OLED`-палітра (`#08080A`, контраст `18.4:1 AAA`) з базальтовими клавішами (`#16161B`) та чистим національним золотом (`#FFD700`).

---

## 5. Як переглянути та протестувати інтерактивні прототипи

1. Відкрийте у браузері [Interactive_1_Tamga_Harmonic_Flow_p5.html](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Interactive_1_Tamga_Harmonic_Flow_p5.html), щоб дослідити генеративне поле `Taraq Tamğa`, змінити `Typing Cadence (WPM) (0..75)`, перевірити інерційне охолодження та натиснути `Commit Word (Pulse)`.
2. Відкрийте у браузері [Interactive_2_Minimalist_Keyboard_And_Comet_Lab.html](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-06/visual_proposals/Interactive_2_Minimalist_Keyboard_And_Comet_Lab.html), щоб у реальному часі перемикати 3 режими мінімалізму (`Liquid Whisper`, `Typographic Air Borderless`, `Sculpted Monolith`), усі 6 тем `Theme Factory`, розкладки `QT` / `КЪ` / `Кʼ`, та провести курсором по клавішах для перевірки комети `Swipe v2` із золотим підсвічуванням кутових якорів `Δθ >= 22°`.
