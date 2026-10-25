# App Store Review Notes — QırımKey v3.1 (Build 5)

Canonical App Review Notes for **QırımKey v3.1 (Build 5)**, aligned with Apple App Review Guideline **2.5.1 (Public APIs Only)** and **2.5.13 / 5.1.1 (Keyboard Extension Privacy)**.

Source files:
- [`AppStoreMetadata/en-US/review_notes.txt`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/AppStoreMetadata/en-US/review_notes.txt)
- [`AppStoreMetadata/uk/review_notes.txt`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/AppStoreMetadata/uk/review_notes.txt)
- [`AppStoreMetadata/crh/review_notes.txt`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/AppStoreMetadata/crh/review_notes.txt)

---

## English (`en-US`)

1. **How to Enable**: Open `"Settings → General → Keyboard → Keyboards → Add New Keyboard…"` and select **"QırımKey"** (includes both Crimean Tatar Latin and Cyrillic-to-Latin transliteration keyboards).
2. **Privacy & Offline Operation**: Both keyboard extensions (`crh.key.keyboard.keyboard` and `crh.key.keyboard.keyboard.cyrillic`) set `RequestsOpenAccess = YES` in `Info.plist` solely for local on-device App Group (`group.crh.key.keyboardplus`) preference and typing statistics synchronization between `QTatar.app` and the keyboard extensions, and make **zero network requests**. When Full Access is disabled (`hasFullAccess == false`), the keyboard remains 100% functional using the bundled read-only corpus database (`qırım_tatar.db`) and standard `UserDefaults.standard` fallback without writing to the shared App Group container.
3. **100% Public Apple SDK APIs (Guideline 2.5.1)**: All keyboard layout adaptation (Docked, Floating, Split on iPad, and Compact on iPhone) uses solely public UIKit geometry (`view.bounds`, `UIScreen.main.bounds`, `traitCollection`), `UITextInputMode.activeInputModes`, and `UIApplication.openSettingsURLString`.
4. **System App Settings (`Settings.bundle`)**: Toggle switches for Word Suggestions and Word Learning are located in `"Settings → Apps → QırımKey"` (reachable directly via the `"App settings"` row on the app's Home screen), while Typing Statistics is toggled directly in the Statistics card header on the Home screen.
5. **Organization & Corpus Attribution**: Developed by **QIRI'M Young NGO** (`KYRYM YANH HO`) on the basis of the National Corpus of the Crimean Tatar Language (`https://ctcorpus.org`).
6. **Version Train Note**: Version `1.0` is currently live on the App Store. The closed TestFlight train `3.0` (Builds 1–4) was superseded; this submission is version **`3.1`** (`CFBundleShortVersionString = 3.1`, Build `5`).
