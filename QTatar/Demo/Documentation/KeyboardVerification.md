# Keyboard verification — 2026-10-17

BuildProject succeeded after changes. On iPhone 15 Pro (iOS 27), a focused visual check confirmed a single system globe, shortened Latin/Cyrillic names, twelve slots across each Cyrillic row (ё and comma included), and visibly different modern/classic system key colors. No overlapping previous keyboard was visible after switching themes. The final nil-language handling adjustment was compiled after the visual installation.

Enabled-keyboard warning uses public UITextInputMode.primaryLanguage identifiers. crh-Cyrl confirms the Cyrillic input mode; when iOS omits the script/language, the UI reports an unverified state rather than falsely claiming the keyboard is missing. Refreshes on screen appearance, app activation, and input-mode changes.

iPad floating layout shares the compact provider but was not visually rechecked in this pass. Typing/transliteration was not rerun in this visual pass; previous corpus tests covered 6382 reference cases plus2499 dictionary words with one documented server discrepancy for селямет.
