#!/usr/bin/env python3
"""
Generates the complete QırımKey v3.1 (Build 5) 3-Language (crh, uk, en)
Editor-Translator Localization Export across all app screens, keyboard extensions,
Settings.bundle, 85 daily phrases, inline Swift UI labels, and App Store metadata.

Outputs:
  1. docs/localization/EDITOR_TRANSLATOR_EXPORT_V31.md
  2. docs/localization/editor_translator_export_v31.csv (UTF-8 with BOM for Excel/Numbers/Google Sheets)
  3. docs/localization/editor_translator_export_v31.tsv
  4. Brain artifacts:
     - /Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/localization_editor_translator_v31.md
     - /Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/localization_master_table_v24.md
"""

from __future__ import annotations

import csv
import os
import re
from pathlib import Path
from typing import Dict, List, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
LOC_DIR = REPO_ROOT / "QTatar" / "Demo" / "Demo" / "Utilities" / "Localization"
SETTINGS_BUNDLE_DIR = REPO_ROOT / "QTatar" / "Demo" / "Demo" / "Settings.bundle"
KK_LOC_DIR = REPO_ROOT / "QTatar" / "Sources" / "KeyboardKit" / "Resources"
APPSTORE_DIR = REPO_ROOT / "AppStoreMetadata"
DOCS_LOC_DIR = REPO_ROOT / "docs" / "localization"
BRAIN_DIR = Path("/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3")


def parse_strings_file(path: Path) -> Dict[str, str]:
    """Parses an Apple .strings file into an ordered dictionary of key -> value."""
    result: Dict[str, str] = {}
    if not path.exists():
        return result
    content = path.read_text(encoding="utf-8")
    # Remove /* ... */ block comments
    content = re.sub(r"/\*.*?\*/", "", content, flags=re.DOTALL)
    pattern = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', re.MULTILINE)
    for match in pattern.finditer(content):
        k = match.group(1).replace('\\"', '"').replace("\\n", "\n")
        v = match.group(2).replace('\\"', '"').replace("\\n", "\n")
        result[k] = v
    return result


# Exact Screen Location, Functional Purpose/Context, and Optimal Character Limit (max_chars)
# for every key across Interface.strings, Home.strings, Onboarding.strings, About.strings,
# Settings.bundle/Root.strings, and KeyboardKit/Localizable.strings.
KEY_METADATA: Dict[str, Tuple[str, str, int, str]] = {
    # --- Interface.strings (110 keys) ---
    "field.standard": (
        "HomeView -> Typing Sandbox Card -> Field Mode Segmented Pill 1 ('Text')",
        "Switches the interactive sandbox text field to standard `.default` text entry mode (shows Daily Phrase when empty + 3 autocomplete suggestions).",
        10,
        "1 line segment pill",
    ),
    "field.search": (
        "HomeView -> Typing Sandbox Card -> Field Mode Segmented Pill 2 ('Search')",
        "Switches the sandbox text field to `.webSearch` mode (shows 3 autocomplete suggestions, hides Daily Phrase banner).",
        10,
        "1 line segment pill",
    ),
    "field.email": (
        "HomeView -> Typing Sandbox Card -> Field Mode Pill ('Email')",
        "Switches the sandbox text field to `.emailAddress` mode (hides both Daily Phrase and autocomplete suggestions).",
        10,
        "1 line segment pill",
    ),
    "field.url": (
        "HomeView -> Typing Sandbox Card -> Field Mode Segmented Pill 3 ('Web / URL')",
        "Switches the sandbox text field to `.URL` mode (hides both Daily Phrase and autocomplete suggestions).",
        8,
        "1 line segment pill",
    ),
    "field.numbers": (
        "HomeView -> Typing Sandbox Card -> Field Mode Pill ('Numbers')",
        "Switches the sandbox text field to `.numbersAndPunctuation` mode (hides both Daily Phrase and suggestions).",
        10,
        "1 line segment pill",
    ),
    "theme.modernLight": (
        "HomeView -> App Settings Card -> Theme Segmented Picker Option ('Light')",
        "Forces Light mode appearance across the host app and keyboard extensions.",
        12,
        "1 line segment label",
    ),
    "theme.modernDark": (
        "HomeView -> App Settings Card -> Theme Segmented Picker Option ('Dark')",
        "Forces Dark mode appearance across the host app and keyboard extensions.",
        12,
        "1 line segment label",
    ),
    "theme.light": (
        "HomeView -> App Settings Card -> Theme Picker Alias ('Light')",
        "Light theme option label.",
        12,
        "1 line segment label",
    ),
    "theme.dark": (
        "HomeView -> App Settings Card -> Theme Picker Alias ('Dark')",
        "Dark theme option label.",
        12,
        "1 line segment label",
    ),
    "settings.title": (
        "HomeView -> Settings Section Header ('Settings')",
        "Main section header above App Settings, System Settings, and Keyboard Layouts.",
        22,
        "1 line section header",
    ),
    "settings.language": (
        "HomeView -> App Settings Card -> Row 1 Title ('Interface language')",
        "Row title for the in-app interface language selector (QT / УК / EN) with dynamic vector emblem (Taraq Tamğa / Tryzub / Union Jack).",
        24,
        "1 line row title",
    ),
    "settings.cyrillic": (
        "HomeView -> Keyboard Layouts Card -> Cyrillic Layout Title ('Kirill klaviaturası' / 'Кирилична клавіатура')",
        "Title for the Crimean Tatar Cyrillic (ФЫВА, Къ) layout card/row with purple-indigo `Къ → Q → Къ` 3D keycap badge.",
        26,
        "1 line card/row title",
    ),
    "settings.suggestions": (
        "HomeView -> System Settings Card -> Word Suggestions Row Title",
        "Toggle row title (`crh.key.suggestions`) for top-bar predictive autocomplete suggestions and daily wisdom phrases.",
        26,
        "1 line row title",
    ),
    "settings.wordLearning": (
        "HomeView -> App Settings Card -> Remember New Words Row Title",
        "Toggle row title (`crh.key.wordLearningEnabled`) for on-device word learning (`user_unigrams` & `user_bigrams`).",
        30,
        "1 line row title",
    ),
    "settings.done": (
        "HomeView / Modal Sheets -> Dismiss Toolbar Button ('Done')",
        "Dismisses the active sheet or keyboard.",
        12,
        "1 line toolbar button",
    ),
    "settings.keyboardHelp": (
        "HomeView (iPad) -> Keyboard Settings Footer Help Text",
        "Explains Cyrillic transliteration, the iPad 'абв/abc' toggle key, on-device word learning, and Full Access requirements.",
        260,
        "Up to 4 lines footer paragraph",
    ),
    "settings.keyboardHelpPhone": (
        "HomeView (iPhone) -> Keyboard Settings Footer Help Text",
        "Explains Cyrillic transliteration, on-device word learning, and Full Access requirements on iPhone.",
        200,
        "Up to 3 lines footer paragraph",
    ),
    "settings.enableBothKeyboards": (
        "HomeView -> Status Card -> Multi-Keyboard Setup Hint",
        "Instructs the user how to add both Qırımtatarca (Latin) and Къырымтатарджа (Cyrillic) in iOS Settings.",
        200,
        "Up to 3 lines helper hint",
    ),
    "settings.missingCyrillic": (
        "HomeView -> Keyboard Layouts Card -> Missing Cyrillic Warning",
        "Shown when the user enables Cyrillic mode in-app on iPhone but has not yet added Къырымтатарджа in iOS Settings.",
        95,
        "Up to 2 lines warning banner",
    ),
    "settings.cyrillicUnverified": (
        "HomeView -> Keyboard Layouts Card -> Unverified Cyrillic Script Note",
        "Fallback note when iOS does not expose the extension's script identifier in `activeInputModes`.",
        180,
        "Up to 3 lines helper note",
    ),
    "sandbox.undo": (
        "HomeView -> Typing Sandbox Toolbar -> Undo Button ('Undo')",
        "Reverts the last text edit in the typing sandbox field.",
        12,
        "1 line compact toolbar button",
    ),
    "sandbox.redo": (
        "HomeView -> Typing Sandbox Toolbar -> Redo Button ('Redo')",
        "Re-applies an undone text edit in the typing sandbox field.",
        12,
        "1 line compact toolbar button",
    ),
    "sandbox.paste": (
        "HomeView -> Typing Sandbox Toolbar -> Paste Button ('Paste')",
        "Pastes clipboard text into the typing sandbox field.",
        12,
        "1 line compact toolbar button",
    ),
    "sandbox.clear": (
        "HomeView -> Typing Sandbox Toolbar -> Clear Button ('Clear')",
        "Clears all text from the typing sandbox field.",
        12,
        "1 line compact toolbar button",
    ),
    "stats.title": (
        "HomeView -> Collapsible Statistics Card Header ('Statistika' / 'Статистика' / 'Statistics')",
        "MUST be a single word (<= 12 chars) so it never wraps or collides with the inline Toggle (`crh.key.statsEnabled`) and expand chevron.",
        12,
        "Single word (<= 12 chars)",
    ),
    "stats.words": (
        "HomeView -> Expanded Statistics Card -> Tile 1 Title ('Words typed')",
        "Primary title of Tile 1 (`stats.wordsTile`) showing total words typed in Crimean Tatar.",
        20,
        "1 line tile title",
    ),
    "stats.chars": (
        "HomeView -> Expanded Statistics Card -> Characters Label",
        "Label for character count metric.",
        14,
        "1 line metric label",
    ),
    "stats.speed": (
        "HomeView -> Expanded Statistics Card -> Tile 2 Title ('Typing speed')",
        "Primary title of Tile 2 showing peak/recent typing speed in WPM.",
        18,
        "1 line tile title",
    ),
    "stats.activeTime": (
        "HomeView -> Expanded Statistics Card -> Tile 3 Title ('Active time')",
        "Primary title of Tile 3 showing cumulative active typing duration.",
        18,
        "1 line tile title",
    ),
    "stats.learnedWords": (
        "HomeView -> Expanded Statistics Card -> Tile 4 Title ('Learned words')",
        "Primary title of Tile 4 (`stats.learnedWordsTile`) opening the Personal Dictionary sheet (`WHERE is_custom = 1`).",
        20,
        "1 line tile title",
    ),
    "stats.wpmUnit": (
        "HomeView -> Collapsed & Expanded Statistics Card -> Speed Unit ('söz/daq' / 'сл/хв' / 'WPM')",
        "Words-per-minute unit shown in both collapsed pill 2 and expanded speed tile; MUST NOT truncate with '...'.",
        8,
        "1 line compact unit (<= 8 chars)",
    ),
    "stats.cpmUnit": (
        "HomeView -> Expanded Statistics Card -> Characters-Per-Minute Unit ('arif/daq' / 'зн/хв' / 'CPM')",
        "Characters-per-minute unit label.",
        10,
        "1 line compact unit",
    ),
    "stats.minUnit": (
        "HomeView -> Collapsed & Expanded Statistics Card -> Minutes Unit ('daq' / 'хв' / 'min')",
        "Short unit for minutes of active typing.",
        5,
        "1 line micro unit",
    ),
    "stats.secUnit": (
        "HomeView -> Collapsed & Expanded Statistics Card -> Seconds Unit ('s' / 'с' / 's')",
        "Short unit for seconds of active typing.",
        3,
        "1 line micro unit",
    ),
    "stats.achievements": (
        "HomeView -> Expanded Statistics Card -> Achievements Sub-Header ('Achievements')",
        "Sub-header above the 4 progressive 5-tier achievement cards.",
        18,
        "1 line sub-header",
    ),
    "stats.ach.firstStep": (
        "HomeView -> Expanded Statistics Card -> Achievement 1 Title ('First Step')",
        "5-tier achievement tracking total words typed (`[10, 50, 200, 500, 1500]` words).",
        18,
        "1 line achievement title",
    ),
    "stats.ach.firstStep.desc": (
        "HomeView -> Expanded Statistics Card -> Achievement 1 Subtitle",
        "Format string with 2 `%d` placeholders (`current / target` words typed).",
        30,
        "1 line achievement subtitle",
    ),
    "stats.ach.speed": (
        "HomeView -> Expanded Statistics Card -> Achievement 2 Title ('Heartbeat Tempo')",
        "5-tier achievement tracking empirical human typing speed (`[15, 25, 40, 55, 75]` WPM; 75 WPM max).",
        18,
        "1 line achievement title",
    ),
    "stats.ach.speed.desc": (
        "HomeView -> Expanded Statistics Card -> Achievement 2 Subtitle",
        "Format string with 2 `%d` placeholders (`current / target` WPM).",
        28,
        "1 line achievement subtitle",
    ),
    "stats.ach.scholar": (
        "HomeView -> Expanded Statistics Card -> Achievement 3 Title ('Word Scholar')",
        "5-tier achievement tracking personal vocabulary growth (`[5, 15, 30, 60, 100]` words).",
        18,
        "1 line achievement title",
    ),
    "stats.ach.scholar.desc": (
        "HomeView -> Expanded Statistics Card -> Achievement 3 Subtitle",
        "Format string with 2 `%d` placeholders (`current / target` learned words).",
        28,
        "1 line achievement subtitle",
    ),
    "stats.ach.wisdom": (
        "HomeView -> Expanded Statistics Card -> Achievement 4 Title ('Ancestral Wisdom')",
        "5-tier achievement tracking daily Crimean Tatar proverbs/quotes inserted (`[1, 5, 15, 30, 50]`).",
        20,
        "1 line achievement title",
    ),
    "stats.ach.wisdom.desc": (
        "HomeView -> Expanded Statistics Card -> Achievement 4 Subtitle",
        "Format string with 2 `%d` placeholders (in Ukrainian MUST use 'Відомі вислови: %d / %d', never 'Крилаті вислови').",
        28,
        "1 line achievement subtitle",
    ),
    "stats.ach.levelBadge": (
        "HomeView -> Expanded Statistics Card -> Achievement Tier Badge ('Sev. %d/%d' / 'Рів. %d/%d' / 'Lv. %d/%d')",
        "Format string with 2 `%d` placeholders displaying current level out of 5 in the top-right corner of each achievement card.",
        12,
        "1 line compact badge",
    ),
    "stats.manualWords": (
        "HomeView -> Expanded Statistics Card -> Input Breakdown Tile 1 ('Typed manually')",
        "Label for words typed letter-by-letter.",
        22,
        "1 line tile label",
    ),
    "stats.suggestedWords": (
        "HomeView -> Expanded Statistics Card -> Input Breakdown Tile 2 ('With suggestions')",
        "Label for words inserted via top-bar autocomplete suggestions or swipe.",
        22,
        "1 line tile label",
    ),
    "stats.suggestionBoost": (
        "HomeView -> Expanded Statistics Card -> Speed Boost Banner",
        "Format string with `%@` multiplier showing typing efficiency gain from suggestions.",
        38,
        "1 line banner text",
    ),
    "stats.reset": (
        "HomeView -> Expanded Statistics Card -> Reset Button ('Reset Statistics')",
        "Destructive button at the bottom of the expanded Statistics card.",
        24,
        "1 line button label",
    ),
    "stats.resetConfirmTitle": (
        "HomeView -> Reset Statistics Confirmation Alert -> Title",
        "Alert dialog title asking the user to confirm clearing typing statistics.",
        28,
        "1 line alert title",
    ),
    "stats.resetConfirmMessage": (
        "HomeView -> Reset Statistics Confirmation Alert -> Message Body",
        "Warns the user that clearing typing and speed statistics cannot be undone.",
        110,
        "Up to 3 lines alert body",
    ),
    "stats.resetConfirmAction": (
        "HomeView -> Reset Statistics Confirmation Alert -> Destructive Button ('Reset')",
        "Confirms and executes statistics reset.",
        14,
        "1 line alert button",
    ),
    "stats.cancel": (
        "HomeView -> Alert Dialogs -> Cancel Button ('Cancel')",
        "Cancels the alert dialog without making changes.",
        14,
        "1 line alert button",
    ),
    "stats.resetCancel": (
        "HomeView -> Reset Statistics Confirmation Alert -> Cancel Button ('Cancel')",
        "Dismisses the reset confirmation alert.",
        14,
        "1 line alert button",
    ),
    "stats.speedLevel": (
        "HomeView -> Expanded Statistics Card -> Speed Progression Card Header",
        "Category label above the current typing speed tier title.",
        20,
        "1 line category label",
    ),
    "stats.speedTier0": (
        "HomeView -> Speed Progression Tier 0 Title (< 15 WPM: 'Calm Start')",
        "Initial speed tier before reaching 15 WPM.",
        20,
        "1 line tier title",
    ),
    "stats.speedTier1": (
        "HomeView -> Speed Progression Tier 1 Title (15–24 WPM: 'Careful Step')",
        "Speed Tier 1 title (15 WPM threshold).",
        20,
        "1 line tier title",
    ),
    "stats.speedTier2": (
        "HomeView -> Speed Progression Tier 2 Title (25–39 WPM: 'Steady Flow')",
        "Speed Tier 2 title (25 WPM threshold).",
        20,
        "1 line tier title",
    ),
    "stats.speedTier3": (
        "HomeView -> Speed Progression Tier 3 Title (40–54 WPM: 'Nimble Fingers')",
        "Speed Tier 3 title (40 WPM threshold).",
        20,
        "1 line tier title",
    ),
    "stats.speedTier4": (
        "HomeView -> Speed Progression Tier 4 Title (55–74 WPM: 'Mountain Stream')",
        "Speed Tier 4 title (55 WPM threshold).",
        20,
        "1 line tier title",
    ),
    "stats.speedTier5": (
        "HomeView -> Speed Progression Tier 5 Title (>= 75 WPM: 'Lightning Speed')",
        "Maximum human typing speed tier (75 WPM threshold).",
        22,
        "1 line tier title",
    ),
    "stats.volumeLevel": (
        "HomeView -> Expanded Statistics Card -> Writing Volume Progression Header",
        "Category label above the current writing volume tier title.",
        20,
        "1 line category label",
    ),
    "stats.volumeTier0": (
        "HomeView -> Writing Volume Tier 0 Title (0 words: 'First Word Ahead')",
        "Initial volume tier when 0 words have been typed.",
        24,
        "1 line tier title",
    ),
    "stats.volumeTier1": (
        "HomeView -> Writing Volume Tier 1 Title ('First Lines')",
        "Writing Volume Tier 1 title.",
        20,
        "1 line tier title",
    ),
    "stats.volumeTier2": (
        "HomeView -> Writing Volume Tier 2 Title ('Active Conversationalist')",
        "Writing Volume Tier 2 title.",
        26,
        "1 line tier title",
    ),
    "stats.volumeTier3": (
        "HomeView -> Writing Volume Tier 3 Title ('Wordsmith')",
        "Writing Volume Tier 3 title.",
        20,
        "1 line tier title",
    ),
    "stats.volumeTier4": (
        "HomeView -> Writing Volume Tier 4 Title ('Language Keeper')",
        "Writing Volume Tier 4 title.",
        22,
        "1 line tier title",
    ),
    "stats.volumeTier5": (
        "HomeView -> Writing Volume Tier 5 Title ('Crimean Tatar Luminary')",
        "Maximum Writing Volume Tier 5 title.",
        30,
        "1 line tier title",
    ),
    "settings.stats": (
        "HomeView -> Statistics Toggle Accessibility Label ('Statistics')",
        "Single-word label for the inline statistics toggle (`crh.key.statsEnabled`).",
        14,
        "Single word",
    ),
    "settings.stats.desc": (
        "HomeView -> Statistics Card -> Collapsed / Disabled Subtitle",
        "Concise description of typing speed, word count, and achievement tracking.",
        50,
        "1 line subtitle",
    ),
    "stats.charsSubtitle": (
        "HomeView -> Expanded Statistics Card -> Tile 1 (`stats.wordsTile`) Subtitle Part 1 ('Characters: %d')",
        "Format string with `%d` combined with `stats.uniqueWordsSubtitle` (`Символів: X · Унікальних: Y`).",
        18,
        "1 line subtitle fragment",
    ),
    "stats.uniqueWordsSubtitle": (
        "HomeView -> Expanded Statistics Card -> Tile 1 (`stats.wordsTile`) Subtitle Part 2 ('Unique: %d')",
        "Format string with `%d` showing total unique vocabulary words recorded in `user_unigrams`.",
        18,
        "1 line subtitle fragment",
    ),
    "stats.uniqueWordsUnit": (
        "HomeView -> Compact Statistics Bar -> Unique Words Unit ('unik.' / 'унік.' / 'unique')",
        "Short unit label for unique words count.",
        8,
        "1 line micro unit",
    ),
    "stats.speedSubtitle": (
        "HomeView -> Expanded Statistics Card -> Tile 2 (`stats.speedTile`) Subtitle ('Recent pace: %d %@')",
        "Format string with `%d` (last WPM) and `%@` (`stats.wpmUnit`).",
        24,
        "1 line tile subtitle",
    ),
    "stats.speedPeakSubtitle": (
        "HomeView -> Expanded Statistics Card -> Tile 2 Fallback Subtitle ('Peak typing pace')",
        "Shown when displaying peak WPM without a recent session pace.",
        26,
        "1 line tile subtitle",
    ),
    "stats.manualWordsSubtitle": (
        "HomeView -> Expanded Statistics Card -> Manual Words Tile Subtitle",
        "Explains words typed key-by-key without tapping suggestions.",
        28,
        "1 line tile subtitle",
    ),
    "stats.suggestedWordsSubtitle": (
        "HomeView -> Expanded Statistics Card -> Suggested Words Tile Subtitle ('Characters saved: %d')",
        "Format string with `%d` showing total characters saved by tapping suggestions.",
        28,
        "1 line tile subtitle",
    ),
    "stats.speedNextFormat": (
        "HomeView -> Expanded Statistics Card -> Speed Tier Progress Hint",
        "Format string (`%@` next tier name, `%d` target WPM, `%@` unit, `+%d` remaining WPM).",
        36,
        "1 line progress hint",
    ),
    "stats.speedMaxReached": (
        "HomeView -> Expanded Statistics Card -> Speed Tier Max Banner",
        "Displayed when the user reaches Tier 5 (`>= 75 WPM`).",
        30,
        "1 line banner text",
    ),
    "stats.volumeNextFormat": (
        "HomeView -> Expanded Statistics Card -> Volume Tier Progress Hint",
        "Format string (`%@` next tier name, `%d` target words, `+%d` remaining words).",
        36,
        "1 line progress hint",
    ),
    "stats.volumeMaxReached": (
        "HomeView -> Expanded Statistics Card -> Volume Tier Max Banner",
        "Displayed when the user reaches the highest writing volume tier.",
        30,
        "1 line banner text",
    ),
    "stats.activeTimeSubtitle": (
        "HomeView -> Expanded Statistics Card -> Tile 3 (`stats.activeTimeTile`) Subtitle",
        "Explains cumulative active typing session time.",
        26,
        "1 line tile subtitle",
    ),
    "stats.learnedWordsSubtitle": (
        "HomeView -> Expanded Statistics Card -> Tile 4 (`stats.learnedWordsTile`) Subtitle & PersonalDictionarySheet Header",
        "Subtitle ('Personal dictionary' / 'Особистий словник' / 'Şahsiy luğat') for words explicitly saved via quoted Slot 0 (`is_custom = 1`).",
        22,
        "1 line tile subtitle",
    ),
    "settings.cyrillicStatusAdded": (
        "HomeView -> Standard Layout Row -> Inline Status Badge ('✓ Added' / '✓ Додано' / '✓ Qoşulğan')",
        "Rendered exclusively inside `status.primaryKeyboard.row` (never duplicated on the bottom Cyrillic rows).",
        12,
        "1 line compact badge",
    ),
    "settings.cyrillicStatusMissing": (
        "HomeView -> Standard Layout Row -> Inline Status Badge ('Not Added' / 'Не додано')",
        "Indicates the keyboard layout has not yet been added in iOS Settings.",
        12,
        "1 line compact badge",
    ),
    "settings.cyrillicPromoTitle": (
        "HomeView -> Cyrillic Promo Callout Banner -> Headline",
        "Prompts users on Cyrillic locales to also enable the Crimean Tatar Cyrillic keyboard.",
        38,
        "1 line callout headline",
    ),
    "settings.cyrillicPromoDesc": (
        "HomeView -> Cyrillic Promo Callout Banner -> Body Text",
        "Explains how adding Къырымтатарджа enables typing in Cyrillic alongside Latin.",
        130,
        "Up to 3 lines callout body",
    ),
    "settings.cyrillicAddAction": (
        "HomeView -> Cyrillic Promo Callout Banner -> CTA Button ('Add in Settings')",
        "Deep-links to iOS Settings to enable the Cyrillic keyboard.",
        22,
        "1 line button label",
    ),
    "settings.cyrillicGuideTitle": (
        "HomeView / OnboardingView -> Cyrillic Setup Guide Title",
        "Headline for instructions on enabling the Cyrillic keyboard.",
        38,
        "1 line headline",
    ),
    "settings.ukrainianCyrillic": (
        "HomeView (uk only) -> Keyboard Layouts Card -> Bottom Row Title ('Українська розкладка')",
        "Rendered at the very bottom of `keyboardSettingsSection` ONLY when `language == 'uk'` with blue-yellow `Кʼ → Q → Кʼ` 3D keycap badge.",
        24,
        "1 line row title",
    ),
    "settings.ukrainianCyrillic.desc": (
        "HomeView (uk only) -> Keyboard Layouts Card -> Ukrainian Layout Mapping Pills",
        "Concise 4-item transliteration summary (`ґ → g · г → ğ · кʼ → q · нʼ → ñ`) for the Ukrainian ФІВА layout.",
        35,
        "1 line pill summary",
    ),
    "settings.cyrillic.ipadFloatingNote": (
        "HomeView (iPad only) -> Cyrillic Layout Row -> Footnote",
        "Clarifies that on iPad, adding a separate Cyrillic keyboard in iOS Settings is only needed for Floating mode (Docked mode switches via 'абв').",
        75,
        "Up to 2 lines footnote",
    ),
    "settings.appSettings": (
        "HomeView -> App Settings Row Title ('App settings' / 'Налаштування програми')",
        "Row title for preferences stored in App Group (`Remember new words`, sound, haptics).",
        26,
        "1 line row title",
    ),
    "settings.appSettings.desc": (
        "HomeView -> App Settings Row Subtitle",
        "Summarizes preferences controlled in-app and in Settings -> Apps -> QırımKey.",
        48,
        "1 line row subtitle",
    ),
    "settings.systemKeyboard": (
        "HomeView -> System Settings Row Title ('System settings' / 'Системні налаштування')",
        "Row title for deep-linking to iOS system keyboard settings.",
        26,
        "1 line row title",
    ),
    "settings.systemKeyboard.desc": (
        "HomeView -> System Settings Row Subtitle (standard)",
        "Lists system-wide keyboard options (Auto-capitalization, auto-correction, math results).",
        55,
        "Up to 2 lines row subtitle",
    ),
    "settings.systemKeyboard.ios26Desc": (
        "HomeView -> System Settings Row Subtitle (iOS 26/27 breadcrumb)",
        "Shows the exact iOS 26/27 navigation path (`General -> Keyboard`) for system-wide keyboard options.",
        80,
        "Up to 2 lines row subtitle",
    ),
    "settings.cyrillic.addHint": (
        "HomeView -> Cyrillic Layout Row -> Add in iOS Settings Breadcrumb",
        "Shows the path (`General -> Keyboard -> Keyboards`) when the Cyrillic extension is not yet enabled.",
        60,
        "Up to 2 lines helper hint",
    ),
    "settings.fullAccess.addHint": (
        "HomeView -> Full Access Row -> Warning & Setup Path (when Full Access is OFF)",
        "Explains that Allow Full Access is required for offline settings/dictionary/haptics sync and gives the exact path (`Settings -> Apps -> QırımKey -> Keyboards -> Allow Full Access`).",
        175,
        "Up to 3 lines helper hint",
    ),
    "settings.fullAccess.onHint": (
        "HomeView -> Full Access Row -> Confirmation Subtitle (when Full Access is ON)",
        "Confirms that settings, dictionary, and haptics sync is active 100% offline on-device.",
        80,
        "Up to 2 lines helper hint",
    ),
    "sandbox.wrongKeyboardWarning": (
        "HomeView -> Typing Sandbox -> Amber Warning Banner (when non-QırımKey keyboard is active)",
        "Alerts the user that another keyboard is currently active and renders an inline Globe icon (`{{globe}}`) to switch to QırımKey.",
        60,
        "Up to 2 lines warning banner",
    ),
    "stats.wordsUnit": (
        "HomeView -> Collapsed Statistics Bar -> Pill 1 Unit ('söz' / 'сл.' / 'words')",
        "Compact unit label after word count in collapsed bar; uses `.fixedSize(horizontal: true)` so it NEVER truncates with '...'.",
        6,
        "1 line micro unit (<= 6 chars)",
    ),
    "stats.learnedWordsUnit": (
        "HomeView -> Collapsed Statistics Bar -> Pill 3 Unit ('luğat' / 'вивч.' / 'learned')",
        "Compact unit label for personal dictionary count in collapsed bar; uses `.fixedSize(horizontal: true)` so it NEVER truncates with '...'.",
        8,
        "1 line micro unit (<= 8 chars)",
    ),
    "stats.learnedWords.emptyTitle": (
        "PersonalDictionarySheet -> Empty State Headline",
        "Displayed when the user has 0 explicitly saved custom words (`is_custom = 1`).",
        32,
        "1 line empty state title",
    ),
    "stats.learnedWords.emptyDesc": (
        "PersonalDictionarySheet -> Empty State Description",
        "Explains that only words manually confirmed by tapping the left quoted suggestion (`\"...\"` in Slot 0) appear in the Personal Dictionary.",
        90,
        "Up to 3 lines body text",
    ),
    "stats.learnedWords.clearAll": (
        "PersonalDictionarySheet -> Bottom / Toolbar Destructive Action ('Clear dictionary')",
        "Deletes all custom words (`is_custom = 1`) from the Personal Dictionary.",
        18,
        "1 line button label",
    ),
    "stats.learnedWords.done": (
        "PersonalDictionarySheet -> Top-Right Dismiss Button ('Done')",
        "Closes the PersonalDictionarySheet modal.",
        10,
        "1 line toolbar button",
    ),
    "stats.learnedWords.delete": (
        "PersonalDictionarySheet -> Word Row Delete Action ('Delete')",
        "Swipe-to-delete / trash button label for removing a single custom word.",
        12,
        "1 line action label",
    ),
    "settings.standardLayout": (
        "HomeView -> Keyboard Layouts Card -> Top Row Title ('Standard layout' / 'Стандартна розкладка')",
        "Title for the primary Crimean Tatar Latin (`Q`) layout row (`status.primaryKeyboard.row`).",
        24,
        "1 line row title",
    ),
    "settings.standardLayout.desc": (
        "HomeView -> Keyboard Layouts Card -> Top Row Subtitle (`q · ğ · ñ · ş · ç · ü · ö · ı`)",
        "Displays the 8 specific Crimean Tatar Latin letters available on the primary layout.",
        32,
        "1 line character pill summary",
    ),
    "settings.abvBridgeTitle": (
        "HomeView (iPad only, uk only) -> Standard Layout Card -> Liquid Glass 'абв' Bridge Header",
        "Header above the 3-state segmented control (`Кирилицю | Caps Lock | Українську`) configuring the docked iPad 'абв' key (shown only in Ukrainian; in crh/en turning off the single Cyrillic toggle directly enables Caps Lock).",
        30,
        "1 line bridge header",
    ),
    # --- Home.strings (14 keys) ---
    "home_crimea_key": (
        "HomeView -> Top Hero Card -> Tagline Subtitle",
        "Warm community tagline displayed directly under the 'QırımKey' title in the top hero header.",
        58,
        "Up to 2 lines hero subtitle",
    ),
    "home_full_off_key": (
        "HomeView -> Status Card -> Full Access Row Title (when Full Access is OFF)",
        "Indicates that 'Allow Full Access' is currently disabled in iOS Settings; tapping opens Onboarding Step 2/4.",
        26,
        "1 line status row title",
    ),
    "home_full_on_key": (
        "HomeView -> Status Card -> Full Access Row Title (when Full Access is ON)",
        "Confirms that 'Allow Full Access' is enabled in iOS Settings.",
        26,
        "1 line status row title",
    ),
    "home_getkeyboard_key": (
        "HomeView -> Typing Sandbox Card -> Helper Instruction with Globe Icon (`{{globe}}`)",
        "Explains how to switch to QırımKey using the Globe key (`{{globe}}`) while typing in the sandbox.",
        125,
        "Up to 3 lines helper text",
    ),
    "home_keyboard_hidden_key": (
        "HomeView -> Typing Sandbox Card -> Keyboard Visibility Badge (when keyboard is dismissed)",
        "Status badge in the sandbox header indicating the software keyboard is currently hidden.",
        22,
        "1 line status pill",
    ),
    "home_keyboard_off_key": (
        "HomeView -> Status Card -> Primary Keyboard Status (when Latin keyboard is not added)",
        "Status label when `crh.key.Keyboard` is not yet enabled in iOS Settings.",
        32,
        "1 line status title",
    ),
    "home_keyboard_on_key": (
        "HomeView -> Status Card -> Primary Keyboard Status (when Latin keyboard is added)",
        "Status label confirming `crh.key.Keyboard` is enabled in iOS Settings.",
        30,
        "1 line status title",
    ),
    "home_keyboard_visible_key": (
        "HomeView -> Typing Sandbox Card -> Keyboard Visibility Badge (when keyboard is active)",
        "Status badge in the sandbox header indicating the software keyboard is currently visible on screen.",
        22,
        "1 line status pill",
    ),
    "home_ok_key": (
        "HomeView / Typing Sandbox -> Dismiss Keyboard Pill Button ('OK' / 'Yahşı')",
        "Dismisses the active keyboard from the sandbox text field.",
        8,
        "1 line compact button",
    ),
    "home_start_key": (
        "HomeView -> Top Onboarding Banner / Setup Button ('Get Started' / 'Почати')",
        "Opens the 4-step OnboardingView walkthrough.",
        16,
        "1 line CTA button",
    ),
    "home_typing_key": (
        "HomeView -> Typing Sandbox TextField Placeholder ('Type something…')",
        "Placeholder text rendered inside the sandbox input field when `text.isEmpty`.",
        24,
        "1 line placeholder",
    ),
    "home_writearea_key": (
        "HomeView -> Typing Sandbox Card Header ('Writing Area' / 'Поле введення')",
        "Header title of the interactive typing sandbox card.",
        20,
        "1 line card header",
    ),
    "home_cyrillic_on_key": (
        "HomeView -> Status Card -> Cyrillic Status Pill (enabled)",
        "Indicates the Cyrillic keyboard extension is enabled.",
        22,
        "1 line status pill",
    ),
    "home_cyrillic_off_key": (
        "HomeView -> Status Card -> Cyrillic Status Pill (disabled)",
        "Indicates the Cyrillic keyboard extension is not yet enabled.",
        22,
        "1 line status pill",
    ),
    # --- Onboarding.strings (14 keys) ---
    "onb_back_key": (
        "OnboardingView -> Bottom Navigation Bar -> Left Button ('Back')",
        "Navigates to the previous step in the 4-step onboarding carousel.",
        16,
        "1 line navigation button",
    ),
    "onb_check_key": (
        "OnboardingView -> Step 3/4 -> Action Button ('Try the Keyboard')",
        "Focuses the test input field or returns to the sandbox to test QırımKey.",
        28,
        "1 line CTA button",
    ),
    "onb_finish_key": (
        "OnboardingView -> Step 4/4 -> Primary Completion Button ('Finish')",
        "Completes onboarding and dismisses the modal sheet.",
        16,
        "1 line primary CTA button",
    ),
    "onb_next_key": (
        "OnboardingView -> Bottom Navigation Bar -> Right Button ('Next')",
        "Advances to the next step in the 4-step onboarding carousel.",
        16,
        "1 line navigation button",
    ),
    "onb_onb1_key": (
        "OnboardingView -> Step 2/4 (`onboard2` — Allow Full Access) -> Instruction Text",
        "Step `2/4` instructions explaining how to enable 'Allow Full Access' in `Settings > Apps > QırımKey > Keyboards`.",
        110,
        "Up to 3 lines instruction card",
    ),
    "onb_onb2_key": (
        "OnboardingView -> Step 1/4 (`onboard1` — Add Keyboard) -> Instruction Text",
        "Step `1/4` instructions explaining how to add QırımKey in `Settings > General > Keyboard > Keyboards`.",
        115,
        "Up to 3 lines instruction card",
    ),
    "onb_onb2_ios26_key": (
        "OnboardingView -> Step 1/4 (`onboard1` on iOS 26/27) -> Instruction Text",
        "iOS 26/27 breadcrumb instructions for adding QırımKey in Settings.",
        130,
        "Up to 3 lines instruction card",
    ),
    "onb_onb3_key": (
        "OnboardingView -> Step 3/4 (`onboard3` — Switch via Globe) -> Instruction Text",
        "Step `3/4` instructions with inline `{{globe}}` icon showing how to switch to QırımKey while typing.",
        140,
        "Up to 3 lines instruction card",
    ),
    "onb_onb4_key": (
        "OnboardingView -> Step 4/4 (`finish` — Start Typing) -> Instruction Text",
        "Step `4/4` summary highlighting haptic feedback, word suggestions, and automatic transliteration.",
        130,
        "Up to 3 lines instruction card",
    ),
    "onb_open_key": (
        "OnboardingView -> Steps 1 & 2 -> Deep-Link CTA Button ('Open Settings')",
        "Opens `UIApplication.openSettingsURLString` (`Settings -> Apps -> QırımKey`).",
        22,
        "1 line primary button",
    ),
    "onb_settings_key": (
        "OnboardingView -> Top Header Title ('Keyboard Settings')",
        "Navigation header title of the OnboardingView modal.",
        26,
        "1 line header title",
    ),
    "onb_remove_cyrillic_title": (
        "OnboardingView (Cyrillic Removal Guide) -> Headline",
        "Headline shown when guiding the user on how to remove a Cyrillic keyboard extension in iOS Settings.",
        34,
        "1 line headline",
    ),
    "onb_remove_cyrillic_desc": (
        "OnboardingView (Cyrillic Removal Guide) -> Step-by-Step Instructions",
        "Explains how to swipe left on 'Къырымтатарджа' or 'Кʼиримтатарджа' in `Settings -> General -> Keyboard -> Keyboards` and tap Delete.",
        180,
        "Up to 4 lines body text",
    ),
    "onb_ipad_floating_only_note": (
        "OnboardingView (iPad only) -> Floating Mode Callout Note",
        "Explains that on iPad, adding a separate Cyrillic keyboard in iOS Settings is only needed for the Floating window because Docked mode switches immediately via the 'абв' key.",
        190,
        "Up to 3 lines callout note",
    ),
    # --- About.strings (16 keys) ---
    "about_description_key": (
        "AboutView -> Hero Mission Paragraph",
        "Describes QırımKey as the first Crimean Tatar keyboard for iOS created to make writing in Crimean Tatar easy and accessible.",
        180,
        "Up to 4 lines body paragraph",
    ),
    "about_feedback_key": (
        "AboutView -> Support & Feedback Section Header ('Feedback')",
        "Section header above Rate, Share, and Support action buttons.",
        18,
        "1 line section header",
    ),
    "about_first_key": (
        "AboutView -> Top Hero Title ('QırımKey — The First Crimean Tatar Keyboard')",
        "Two-line hero title at the top of AboutView (`\\n` separates title and subtitle).",
        48,
        "2 lines centered hero title",
    ),
    "about_init_key": (
        "AboutView -> Related Initiatives Section Header ('Our Initiatives')",
        "Header above the LanguageTool and Crimean Tatar Spell Checker initiative cards.",
        24,
        "1 line section header",
    ),
    "about_join_key": (
        "AboutView -> Social Media Callout Title ('Join us on social media!')",
        "Headline above Instagram / Telegram / GitHub community links.",
        45,
        "1 line section sub-header",
    ),
    "about_language_description_key": (
        "AboutView -> Initiative Card 1 Body ('LanguageTool for iOS')",
        "Describes the multilingual writing and style assistant supporting Crimean Tatar and 30+ languages.",
        115,
        "Up to 3 lines card body",
    ),
    "about_language_title_key": (
        "AboutView -> Initiative Card 1 Title ('LanguageTool for iOS')",
        "Card title for the LanguageTool for iOS app.",
        26,
        "1 line card title",
    ),
    "about_more_key": (
        "AboutView -> Initiative Cards -> Action Link ('Learn More')",
        "Button label on each initiative card opening the external link.",
        20,
        "1 line button label",
    ),
    "about_rate_key": (
        "AboutView -> Feedback Section -> Button 1 ('Rate on the App Store')",
        "Opens the App Store review page for QırımKey.",
        30,
        "1 line action button",
    ),
    "about_website_key": (
        "AboutView -> Initiative Card -> Website Link Pill ('Website')",
        "Opens the web platform for the initiative.",
        12,
        "1 line pill button",
    ),
    "about_rights_key": (
        "AboutView -> Bottom Footer Copyright Notice",
        "Two-line copyright notice (`© 2025 QIRI’M Young\\nAll rights reserved`).",
        65,
        "2 lines footer text",
    ),
    "about_send_key": (
        "AboutView -> Feedback Section -> Button 2 ('Support the Project')",
        "Opens the contact/support link.",
        24,
        "1 line action button",
    ),
    "about_share_key": (
        "AboutView -> Feedback Section -> Button 3 ('Share')",
        "Opens the native iOS share sheet to share QırımKey with friends.",
        16,
        "1 line action button",
    ),
    "about_spell_description_key": (
        "AboutView -> Initiative Card 2 Body ('Crimean Tatar Spell Checker')",
        "Describes the Crimean Tatar orthography and grammar checking tool.",
        115,
        "Up to 3 lines card body",
    ),
    "about_spell_title_key": (
        "AboutView -> Initiative Card 2 Title ('Crimean Tatar Spell Checker')",
        "Card title for the Crimean Tatar Spell Checker initiative.",
        32,
        "1 line card title",
    ),
    "about_title_key": (
        "AboutView -> Navigation Bar Title ('About')",
        "Title of the AboutView screen.",
        16,
        "1 line navigation bar title",
    ),
    # --- Settings.bundle/Root.strings (13 keys) ---
    "Group": (
        "iOS Settings -> Apps -> QırımKey (Settings.bundle system label)",
        "Standard iOS Settings.bundle group key.",
        20,
        "1 line system label",
    ),
    "Name": (
        "iOS Settings -> Apps -> QırımKey (Settings.bundle system label)",
        "Standard iOS Settings.bundle name key.",
        20,
        "1 line system label",
    ),
    "Enabled": (
        "iOS Settings -> Apps -> QırımKey (Settings.bundle system label)",
        "Standard iOS Settings.bundle enabled state label.",
        20,
        "1 line system label",
    ),
    "none given": (
        "iOS Settings -> Apps -> QırımKey (Settings.bundle system label)",
        "Standard iOS Settings.bundle fallback value label.",
        20,
        "1 line system label",
    ),
    "Söz teklifleri": (
        "iOS Settings -> Apps -> QırımKey (Settings.bundle legacy key)",
        "Localized title for Word Suggestions toggle.",
        32,
        "1 line iOS Settings row",
    ),
    "Yañı sözlerni aqılda tutuv": (
        "iOS Settings -> Apps -> QırımKey -> Toggle 1 ('Remember new words')",
        "Active `PSToggleSwitchSpecifier` (`crh.key.wordLearningEnabled`) in `Root.plist`, `Root~iphone.plist`, `Root~ipad.plist`.",
        32,
        "1 line iOS Settings toggle row",
    ),
    "Sözlerni aqılda tutuv": (
        "iOS Settings -> Apps -> QırımKey (Settings.bundle alias key)",
        "Alias key mapped to 'Remember new words' (`Yañı sözlerni aqılda tutuv`).",
        32,
        "1 line iOS Settings row",
    ),
    "Sözlerni ögrenüv": (
        "iOS Settings -> Apps -> QırımKey (Settings.bundle alias key)",
        "Alias key mapped to 'Remember new words' (`Yañı sözlerni aqılda tutuv`).",
        32,
        "1 line iOS Settings row",
    ),
    "Bir el rejimi": (
        "iOS Settings (iPhone only) -> Apps -> QırımKey -> MultiValue Row ('One-Handed Keyboard')",
        "Active `PSMultiValueSpecifier` (`crh.key.oneHandedMode`) on iPhone (`SupportedUserInterfaceIdioms = [Phone]`; hidden on iPad via `Root~ipad.plist`).",
        32,
        "1 line iOS Settings row",
    ),
    "Yoq": (
        "iOS Settings (iPhone only) -> One-Handed Keyboard Option 1 ('Off')",
        "Disables one-handed mode (`off`).",
        12,
        "1 line option value",
    ),
    "Sol": (
        "iOS Settings (iPhone only) -> One-Handed Keyboard Option 2 ('Left')",
        "Left-handed compact keyboard (`left`).",
        12,
        "1 line option value",
    ),
    "Sağ": (
        "iOS Settings (iPhone only) -> One-Handed Keyboard Option 3 ('Right')",
        "Right-handed compact keyboard (`right`).",
        12,
        "1 line option value",
    ),
    "Tüşme belgi jesti": (
        "iOS Settings (iPad legacy key) -> Enable Key Flicks",
        "Localized label for iPad downward key-flick gestures.",
        32,
        "1 line iOS Settings row",
    ),
    # --- KeyboardKit/Localizable.strings (17 active keyboard keys) ---
    "locale": (
        "Keyboard Extension -> Internal Locale Identifier",
        "Locale code (`crh`, `uk`, `en`).",
        8,
        "ISO code",
    ),
    "capsLock": (
        "Keyboard Extension -> Shift / Caps Lock Accessibility Label",
        "VoiceOver label for Caps Lock key.",
        20,
        "1 line key label",
    ),
    "continue": (
        "Keyboard Extension -> Return Key ('Continue')",
        "Return key label when `returnKeyType == .continue`.",
        14,
        "1 line Return keycap",
    ),
    "done": (
        "Keyboard Extension -> Return Key ('Done')",
        "Return key label when `returnKeyType == .done`.",
        12,
        "1 line Return keycap",
    ),
    "emergencyCall": (
        "Keyboard Extension -> Return Key ('Emergency Call')",
        "Return key label when `returnKeyType == .emergencyCall`.",
        18,
        "1 line Return keycap",
    ),
    "go": (
        "Keyboard Extension -> Return Key ('Go')",
        "Return key label when `returnKeyType == .go`.",
        12,
        "1 line Return keycap",
    ),
    "join": (
        "Keyboard Extension -> Return Key ('Join')",
        "Return key label when `returnKeyType == .join`.",
        12,
        "1 line Return keycap",
    ),
    "next": (
        "Keyboard Extension -> Return Key ('Next')",
        "Return key label when `returnKeyType == .next`.",
        12,
        "1 line Return keycap",
    ),
    "ok": (
        "Keyboard Extension -> Return Key ('OK')",
        "Return key label when `returnKeyType == .default` / confirmation.",
        8,
        "1 line Return keycap",
    ),
    "return": (
        "Keyboard Extension -> Return Key ('return' / '↵')",
        "Default Return key label.",
        12,
        "1 line Return keycap",
    ),
    "route": (
        "Keyboard Extension -> Return Key ('Route')",
        "Return key label when `returnKeyType == .route`.",
        12,
        "1 line Return keycap",
    ),
    "search": (
        "Keyboard Extension -> Return Key ('Search')",
        "Return key label when `returnKeyType == .search` or `.webSearch`.",
        12,
        "1 line Return keycap",
    ),
    "send": (
        "Keyboard Extension -> Return Key ('Send')",
        "Return key label when `returnKeyType == .send`.",
        12,
        "1 line Return keycap",
    ),
    "space": (
        "Keyboard Extension -> Spacebar Accessibility Label",
        "VoiceOver label for the spacebar.",
        14,
        "1 line keycap label",
    ),
    "switcherAlphabetic": (
        "Keyboard Extension -> Mode Switch Key ('ABC' / 'АБВ')",
        "Switches from numeric/symbolic keyboard back to alphabetic letters.",
        5,
        "3-char keycap",
    ),
    "switcherNumeric": (
        "Keyboard Extension -> Mode Switch Key ('123')",
        "Switches from alphabetic keyboard to numbers & punctuation.",
        5,
        "3-char keycap",
    ),
    "switcherSymbolic": (
        "Keyboard Extension -> Mode Switch Key ('#+=')",
        "Switches from numeric keyboard to extended symbols.",
        5,
        "3-char keycap",
    ),
}

# Daily Phrase Trigger Metadata (#1 - #85)
PHRASE_TRIGGERS: Dict[int, str] = {
    23: "Priority 3 — Daytime coffee & hospitality proverb (Mon–Thu, 08:00–17:00)",
    50: "Priority 3 — Morning greeting (05:00–11:00)",
    51: "Priority 3 — Morning greeting (05:00–11:00)",
    52: "Priority 3 — Daytime greeting (11:00–18:00)",
    53: "Priority 3 — Evening greeting (18:00–23:00)",
    54: "Priority 3 — Night greeting (23:00–03:00; 03:00–05:00 falls back to Priority 4 wisdom)",
    55: "Priority 1A — Hijri Calendar: Ramadan (Day 2 after astronomical sunset + all of Day 3 of Ramadan)",
    56: "Priority 1A — Hijri Calendar: Oraza Bayram (Day 2 after astronomical sunset + all of Day 3 of Shawwal)",
    57: "Priority 1A — Hijri Calendar: Qurban Bayram (11 Dhu al-Hijjah after sunset + 12–13 Dhu al-Hijjah)",
    58: "Priority 2 — Friday / Cuma blessing (Fri, 05:00–16:00)",
    59: "Priority 1B — 01.02: Memorial Day of Twice Hero Amet-Han Sultan (Riza Fazıl)",
    60: "Priority 1B — 21.02: International Mother Language Day (Remzi Burnaş)",
    61: "Priority 1B — 23.02: Noman Çelebicihan Memorial Day (Noman Çelebicihan)",
    62: "Priority 1B — 21.03: Navrez Spring Holiday & World Poetry Day (Folk song)",
    63: "Priority 1B — 10.04: First issue of 'Terciman' newspaper (İsmail Gasprinskiy)",
    64: "Priority 1B — 23.04: World Book and Copyright Day (Proverb)",
    65: "Priority 1B — 23.04: World Book Day Riddle (Hides ': Kitap' in top bar; reveals full answer on tap)",
    66: "Priority 1B — First Friday of May: Hıdırlez Spring Festival (Proverb)",
    67: "Priority 1B — Second Sunday of May: Mother's Day (Proverb)",
    68: "Priority 1B — 18.05: Remembrance Day of the 1944 Crimean Tatar Genocide (Çerkez-Ali)",
    69: "Priority 1B — 18.05: Remembrance Prayer / Dua for 1944 Deportation Victims",
    70: "Priority 1B — 01.06: International Children's Day (Remziye Tarsinova)",
    71: "Priority 1B — 26.06: Crimean Tatar National Flag Day (Noman Çelebicihan)",
    72: "Priority 1B — 01.09: Knowledge Day / Start of School Year (Proverb)",
    73: "Priority 1B / 2 — 22.09: Derviza Harvest Festival & 01.03: First Day of Spring (Proverb)",
    74: "Priority 1B — 05.10: Teachers' Day (Proverb)",
    75: "Priority 1B — 20.03: Birthday of İsmail Gasprinskiy (Proverb)",
    76: "Priority 1B — 15.05: Birthday of Bekir Çoban-zade (Bekir Çoban-zade)",
    77: "Priority 1B — 21.06: Birthday of Eşref Şemi-zade (Eşref Şemi-zade)",
    78: "Priority 1B — 12.07: Birthday of Şamil Alâdin (Proverb)",
    79: "Priority 1B — 04.09: Birthday of Yunus Qandım (Yunus Qandım)",
    80: "Priority 1B — 10.10: Birthday of Üsein Şamil Tohtarğazı (Üsein Şamil Tohtarğazı)",
    81: "Priority 1B — 01.02: Memorial Day of Twice Hero Amet-Han Sultan (Riza Fazıl)",
    82: "Priority 1B — 13.11: Tribute to İdris Asanin & Nuzet Ümerov (İdris Asanin)",
    83: "Priority 2 — Monday Morning Workweek Blessing (Mon, 06:00–12:00)",
    84: "Priority 2 — Weekend Proverb (Sat–Sun, 09:00–21:00)",
    85: "Priority 2 — 01.12: First Day of Winter (Proverb)",
}


def get_phrase_trigger(pid: int) -> str:
    if pid in PHRASE_TRIGGERS:
        return PHRASE_TRIGGERS[pid]
    if 1 <= pid <= 22 or 24 <= pid <= 49:
        if pid in (24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42):
            return "Priority 4 — Daily Pool: Classic literary verse on the native language"
        if pid in (43, 44, 47, 48, 49):
            return "Priority 4 — Daily Pool: Traditional Crimean Tatar polite wish / greeting"
        return "Priority 4 — Daily Pool: Folk wisdom & proverb (Qırımtatar atalar sözü)"
    return "Priority 4 — General daily pool"


def escape_md(val: str) -> str:
    return val.replace("|", "\\|").replace("\n", "<br>")


def collect_all_rows() -> List[Dict[str, str]]:
    rows: List[Dict[str, str]] = []

    # 1. Standard .strings tables in Utilities/Localization
    for table_name in ["Interface", "Home", "Onboarding", "About"]:
        crh_map = parse_strings_file(LOC_DIR / "crh.lproj" / f"{table_name}.strings")
        uk_map = parse_strings_file(LOC_DIR / "uk.lproj" / f"{table_name}.strings")
        en_map = parse_strings_file(LOC_DIR / "en.lproj" / f"{table_name}.strings")

        all_keys: List[str] = []
        for m in (crh_map, uk_map, en_map):
            for k in m.keys():
                if k not in all_keys:
                    all_keys.append(k)

        for k in all_keys:
            crh_v = crh_map.get(k, "")
            uk_v = uk_map.get(k, "")
            en_v = en_map.get(k, "")
            loc, purpose, max_c, constraint_note = KEY_METADATA.get(
                k,
                (f"{table_name}.strings UI element", "Localized UI string.", 80, "Standard UI label"),
            )
            rows.append(
                {
                    "section": f"{table_name}.strings",
                    "key": k,
                    "screen_location": loc,
                    "purpose_context": purpose,
                    "max_chars": f"<= {max_c} chars ({constraint_note})",
                    "max_int": str(max_c),
                    "len_crh": str(len(crh_v)),
                    "len_uk": str(len(uk_v)),
                    "len_en": str(len(en_v)),
                    "crh": crh_v,
                    "uk": uk_v,
                    "en": en_v,
                }
            )

    # 2. Settings.bundle/Root.strings
    sb_crh = parse_strings_file(SETTINGS_BUNDLE_DIR / "crh.lproj" / "Root.strings")
    sb_uk = parse_strings_file(SETTINGS_BUNDLE_DIR / "uk.lproj" / "Root.strings")
    sb_en = parse_strings_file(SETTINGS_BUNDLE_DIR / "en.lproj" / "Root.strings")
    sb_keys: List[str] = []
    for m in (sb_crh, sb_uk, sb_en):
        for k in m.keys():
            if k not in sb_keys:
                sb_keys.append(k)
    for k in sb_keys:
        crh_v = sb_crh.get(k, "")
        uk_v = sb_uk.get(k, "")
        en_v = sb_en.get(k, "")
        loc, purpose, max_c, constraint_note = KEY_METADATA.get(
            k,
            ("iOS Settings -> Apps -> QırımKey (Settings.bundle)", "iOS Settings specifier label.", 32, "1 line"),
        )
        rows.append(
            {
                "section": "Settings.bundle/Root.strings",
                "key": k,
                "screen_location": loc,
                "purpose_context": purpose,
                "max_chars": f"<= {max_c} chars ({constraint_note})",
                "max_int": str(max_c),
                "len_crh": str(len(crh_v)),
                "len_uk": str(len(uk_v)),
                "len_en": str(len(en_v)),
                "crh": crh_v,
                "uk": uk_v,
                "en": en_v,
            }
        )

    # 3. KeyboardKit/Localizable.strings (17 active keyboard keys; excludes unused upstream Emoji descriptions)
    kk_crh = parse_strings_file(KK_LOC_DIR / "crh.lproj" / "Localizable.strings")
    kk_uk = parse_strings_file(KK_LOC_DIR / "uk.lproj" / "Localizable.strings")
    kk_en = parse_strings_file(KK_LOC_DIR / "en.lproj" / "Localizable.strings")
    for k in kk_crh.keys():
        crh_v = kk_crh.get(k, "")
        uk_v = kk_uk.get(k, "")
        en_v = kk_en.get(k, "")
        loc, purpose, max_c, constraint_note = KEY_METADATA.get(
            k,
            ("Keyboard Extension Keycap", "Localized keycap or Return key label.", 16, "1 line keycap"),
        )
        rows.append(
            {
                "section": "KeyboardKit/Localizable.strings",
                "key": k,
                "screen_location": loc,
                "purpose_context": purpose,
                "max_chars": f"<= {max_c} chars ({constraint_note})",
                "max_int": str(max_c),
                "len_crh": str(len(crh_v)),
                "len_uk": str(len(uk_v)),
                "len_en": str(len(en_v)),
                "crh": crh_v,
                "uk": uk_v,
                "en": en_v,
            }
        )

    # 4. Inline Swift UI Strings (HomeView.swift, SpaceBarLabel.swift & Callouts+ActionCallout.swift)
    inline_items = [
        (
            "inline.abvBridge.cyrillic",
            "HomeView (iPad only, uk only) -> Standard Layout Card -> Liquid Glass 'абв' Bridge Segment 1",
            "Selects Crimean Tatar Cyrillic (ФЫВА, Къ) as the target layout when tapping the docked 'абв' key on iPad (visible only when interface language is 'uk').",
            12,
            "1 line segment button",
            "Kirill",
            "Кирилицю",
            "Cyrillic",
        ),
        (
            "inline.abvBridge.capsLock",
            "HomeView (iPad only, uk only) -> Standard Layout Card -> Liquid Glass 'абв' Bridge Segment 2",
            "Replaces the docked 'абв' key on iPad with standard Caps Lock (`crh.key.ipadAbvKeyDisabled = true`) while keeping Cyrillic keyboards enabled in Ukrainian mode (in crh/en turning off the single Cyrillic toggle directly enables Caps Lock).",
            12,
            "1 line segment button",
            "Caps Lock",
            "Caps Lock",
            "Caps Lock",
        ),
        (
            "inline.abvBridge.ukrainian",
            "HomeView (iPad only, uk only) -> Standard Layout Card -> Liquid Glass 'абв' Bridge Segment 3",
            "Selects Ukrainian-adapted Cyrillic (ФІВА, Кʼ) as the target layout when tapping the docked 'абв' key on iPad (visible only when interface language is 'uk').",
            12,
            "1 line segment button",
            "Ukrayin",
            "Українську",
            "Ukrainian",
        ),
        (
            "inline.callout.floating",
            "Keyboard Extension (Callouts+ActionCallout.swift, iPad) -> '⌄⌨' Dismiss Key Long-Press Menu -> Floating Option",
            "Transitions the iPad keyboard into Floating mode (`~320 pt` window with bottom grabber bar).",
            14,
            "1 line callout menu item",
            "Yüzüci",
            "Плаваюча",
            "Floating",
        ),
        (
            "inline.callout.split",
            "Keyboard Extension (Callouts+ActionCallout.swift, iPad) -> '⌄⌨' Dismiss Key Long-Press Menu -> Split Option",
            "Transitions the docked iPad keyboard into Split mode.",
            14,
            "1 line callout menu item",
            "Bölüngen",
            "Розділити",
            "Split",
        ),
        (
            "inline.callout.merge",
            "Keyboard Extension (Callouts+ActionCallout.swift, iPad) -> '⌄⌨' Dismiss Key Long-Press Menu -> Dock & Merge Option",
            "Docks and merges a Floating or Split iPad keyboard back to the bottom of the screen.",
            14,
            "1 line callout menu item",
            "Birleştir",
            "Обʼєднати",
            "Dock & Merge",
        ),
        (
            "inline.toolbar.nextPhrase",
            "Keyboard Extension (Autocomplete+NativeToolbarStyle.swift) -> Daily Phrase Banner -> Right Sparkle Cycle Button (VoiceOver)",
            "Accessibility label for the right-hand button in the Daily Phrase banner that cycles to the next greeting/wisdom phrase.",
            24,
            "VoiceOver label",
            "Nevbetteki ibare",
            "Наступна фраза",
            "Next phrase",
        ),
        (
            "inline.spacebar.fullName.latn",
            "Keyboard Extension (SpaceBarLabel.swift) -> Spacebar Center Label (Latin layout, first 3s)",
            "Displayed centered on the spacebar for 3.0s upon keyboard appearance or script switch before fading into the breathing Taraq Tamğa.",
            16,
            "1 line spacebar title",
            "Qırımtatarca",
            "Qırımtatarca",
            "Qırımtatarca",
        ),
        (
            "inline.spacebar.code.latn",
            "Keyboard Extension (SpaceBarLabel.swift) -> Spacebar Bottom-Right Corner Code (Latin layout, after 3s)",
            "2-character uppercase code pinned to the bottom-right corner of the spacebar in resting state (opacity 0.20 Light / 0.30 Dark).",
            2,
            "Exact 2-char uppercase code",
            "QT",
            "QT",
            "QT",
        ),
        (
            "inline.spacebar.fullName.cyrl",
            "Keyboard Extension (SpaceBarLabel.swift) -> Spacebar Center Label (Cyrillic ФЫВА layout, first 3s)",
            "Displayed centered on the spacebar for 3.0s when switching to Crimean Tatar Cyrillic (ФЫВА).",
            16,
            "1 line spacebar title",
            "Къырымтатарджа",
            "Къырымтатарджа",
            "Къырымтатарджа",
        ),
        (
            "inline.spacebar.code.cyrl",
            "Keyboard Extension (SpaceBarLabel.swift) -> Spacebar Bottom-Right Corner Code (Cyrillic ФЫВА, after 3s)",
            "2-character uppercase code pinned to the bottom-right corner of the spacebar in resting state (never 3-char 'КЪТ').",
            2,
            "Exact 2-char uppercase code",
            "КЪ",
            "КЪ",
            "КЪ",
        ),
        (
            "inline.spacebar.fullName.ukCyrl",
            "Keyboard Extension (SpaceBarLabel.swift) -> Spacebar Center Label (Ukrainian ФІВА layout, first 3s)",
            "Displayed centered on the spacebar for 3.0s when switching to Ukrainian-adapted Cyrillic (ФІВА).",
            16,
            "1 line spacebar title",
            "Кʼиримтатарджа",
            "Кʼиримтатарджа",
            "Кʼиримтатарджа",
        ),
        (
            "inline.spacebar.code.ukCyrl",
            "Keyboard Extension (SpaceBarLabel.swift) -> Spacebar Bottom-Right Corner Code (Ukrainian ФІВА, after 3s)",
            "2-character uppercase code pinned to the bottom-right corner of the spacebar in resting state.",
            2,
            "Exact 2-char uppercase code",
            "Кʼ",
            "Кʼ",
            "Кʼ",
        ),
    ]
    for key, loc, purpose, max_c, note, crh_v, uk_v, en_v in inline_items:
        rows.append(
            {
                "section": "Inline Swift UI (HomeView & SpaceBarLabel)",
                "key": key,
                "screen_location": loc,
                "purpose_context": purpose,
                "max_chars": f"<= {max_c} chars ({note})",
                "max_int": str(max_c),
                "len_crh": str(len(crh_v)),
                "len_uk": str(len(uk_v)),
                "len_en": str(len(en_v)),
                "crh": crh_v,
                "uk": uk_v,
                "en": en_v,
            }
        )

    # 5. DailyPhrases.strings (#1 - #85)
    dp_crh = parse_strings_file(LOC_DIR / "crh.lproj" / "DailyPhrases.strings")
    dp_uk = parse_strings_file(LOC_DIR / "uk.lproj" / "DailyPhrases.strings")
    dp_en = parse_strings_file(LOC_DIR / "en.lproj" / "DailyPhrases.strings")
    for pid in range(1, 86):
        text_k = f"phrase.{pid}.text"
        attr_k = f"phrase.{pid}.attribution"
        tr_k = f"phrase.{pid}.translation"

        text_crh = dp_crh.get(text_k, "")
        attr_crh = dp_crh.get(attr_k, "")
        tr_crh = dp_crh.get(tr_k, "")
        tr_uk = dp_uk.get(tr_k, "")
        tr_en = dp_en.get(tr_k, "")

        trigger_desc = get_phrase_trigger(pid)
        banner_note = (
            "Top keyboard toolbar when text field is empty (Text fields only; hidden in Search/URL). "
            "Must be a complete sentence <= 48 chars without '...'. "
        )
        if pid == 65:
            banner_note += "Riddle #65 hides ': Kitap' in the banner and reveals it on tap."

        rows.append(
            {
                "section": "DailyPhrases.strings (#1–#85)",
                "key": f"phrase.{pid} (Banner & Tap Insert)",
                "screen_location": f"Keyboard Top Suggestion Bar — Phrase #{pid} ({trigger_desc})",
                "purpose_context": (
                    f"{banner_note} Attribution on tap: '{attr_crh or 'None (direct greeting)'}'. "
                    f"Inserted CRH line: {tr_crh}"
                ),
                "max_chars": "<= 48 chars (banner textCRH) / <= 110 chars (tap translation)",
                "max_int": "48",
                "len_crh": str(len(text_crh)),
                "len_uk": str(len(tr_uk)),
                "len_en": str(len(tr_en)),
                "crh": text_crh if not attr_crh else f"{text_crh} ({attr_crh})",
                "uk": tr_uk,
                "en": tr_en,
            }
        )

    # 6. App Store Connect Metadata (v3.1)
    def read_meta(locale: str, fname: str) -> str:
        p = APPSTORE_DIR / locale / fname
        return p.read_text(encoding="utf-8").strip() if p.exists() else ""

    appstore_items = [
        (
            "appstore.name",
            "App Store Connect -> App Name",
            "Official App Store product title across all storefronts.",
            30,
            "Apple App Store limit <= 30 chars",
            read_meta("crh", "name.txt") or "QırımKey",
            read_meta("uk", "name.txt") or "QırımKey",
            read_meta("en-US", "name.txt") or "QırımKey",
        ),
        (
            "appstore.subtitle",
            "App Store Connect -> Subtitle",
            "Appears directly below QırımKey in App Store search results and product page header.",
            30,
            "Apple App Store limit <= 30 chars",
            read_meta("crh", "subtitle.txt"),
            read_meta("uk", "subtitle.txt"),
            read_meta("en-US", "subtitle.txt"),
        ),
        (
            "appstore.promotional_text",
            "App Store Connect -> Promotional Text",
            "Appears at the top of the App Store description; can be updated any time without a new binary submission.",
            170,
            "Apple App Store limit <= 170 chars",
            read_meta("crh", "promotional_text.txt"),
            read_meta("uk", "promotional_text.txt"),
            read_meta("en-US", "promotional_text.txt"),
        ),
        (
            "appstore.keywords",
            "App Store Connect -> Search Keywords",
            "Comma-separated search index terms (no spaces after commas).",
            100,
            "Apple App Store limit <= 100 chars",
            read_meta("crh", "keywords.txt"),
            read_meta("uk", "keywords.txt"),
            read_meta("en-US", "keywords.txt"),
        ),
        (
            "appstore.whats_new_v31",
            "App Store Connect -> What's New in Version 3.1 (Build 5)",
            "Release notes highlighting QırımKey Swipe v2, Ukrainian ФІВА layout, 2024/2025 Orthography (ДЕСС № 1722/04-03/25), iOS 26/27 Liquid Glass, and iPad Split/Floating support.",
            4000,
            "Apple App Store limit <= 4000 chars",
            read_meta("crh", "whats_new.txt"),
            read_meta("uk", "whats_new.txt"),
            read_meta("en-US", "whats_new.txt"),
        ),
        (
            "appstore.description",
            "App Store Connect -> Full Storefront Description",
            "Complete App Store product description (note: visible 'ru' storefront uses 100% pure Crimean Tatar Latin with explicit 'Qırım (Ukrayna)' & 'Ukrayna' references).",
            4000,
            "Apple App Store limit <= 4000 chars",
            read_meta("crh", "description.txt"),
            read_meta("uk", "description.txt"),
            read_meta("en-US", "description.txt"),
        ),
    ]
    for key, loc, purpose, max_c, note, crh_v, uk_v, en_v in appstore_items:
        rows.append(
            {
                "section": "AppStoreMetadata (v3.1 Storefront)",
                "key": key,
                "screen_location": loc,
                "purpose_context": purpose,
                "max_chars": f"<= {max_c} chars ({note})",
                "max_int": str(max_c),
                "len_crh": str(len(crh_v)),
                "len_uk": str(len(uk_v)),
                "len_en": str(len(en_v)),
                "crh": crh_v,
                "uk": uk_v,
                "en": en_v,
            }
        )

    import json
    comments_file = DOCS_LOC_DIR / "editor_comments_v31.json"
    comments_map: Dict[str, str] = {}
    if comments_file.exists():
        comments_map = json.loads(comments_file.read_text(encoding="utf-8"))
    for r in rows:
        r["editor_comment"] = comments_map.get(f"{r['section']}::{r['key']}", "")

    return rows


def build_markdown(rows: List[Dict[str, str]]) -> str:
    sections: Dict[str, List[Dict[str, str]]] = {}
    for r in rows:
        sections.setdefault(r["section"], []).append(r)

    lines: List[str] = [
        "# QırımKey v3.1 (Build 5) — Complete 3-Language Editor-Translator Localization Export (`crh` / `uk` / `en`)",
        "",
        "## Overview & Editorial Guidelines for the Translator / Language Editor",
        "",
        "- **Target Release**: **QırımKey v3.1 (Build 5)** for iOS & iPadOS 26/27 (`crh.key.keyboard`).",
        "- **Languages Covered**:",
        "  1. **Crimean Tatar (`crh`)** — strictly compliant with the official **2024/2025 Crimean Tatar Orthography** approved by the Cabinet of Ministers of Ukraine / DESS Order No. 1722/04-03/25 (`ДЕСС № 1722/04-03/25`).",
        "  2. **Ukrainian (`uk`)** — modern natural Ukrainian UI terminology (e.g., `'Статистика'` single-word header, `'Відомі вислови'` instead of `'Крилаті вислови'`, `'Запамʼятовувати нові слова'`).",
        "  3. **English (`en`)** — concise native Apple HIG terminology.",
        "- **Why Character Limits (`Max Chars`) Matter**:",
        "  - Compact metric pills, segmented pickers (`QT | УК | EN`, `Системна | Світла | Темна`, `Кирилицю | Caps Lock | Українську`), and the top keyboard banner have strict horizontal width budgets on iPhone (393 pt width) and iPad Split/Floating keyboards.",
        "  - Keeping translations within the listed `Max Chars` budget guarantees **zero ellipsis truncation (`...`)** across all devices.",
        "  - Format placeholders (`%d`, `%@`) and their order MUST be preserved.",
        "- **Source & Export Files**:",
        "  - Generator Script: [export_localization_for_translator.py](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/export_localization_for_translator.py)",
        "  - Markdown Reference: [EDITOR_TRANSLATOR_EXPORT_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/EDITOR_TRANSLATOR_EXPORT_V31.md)",
        "  - Spreadsheet CSV (UTF-8 BOM for Excel / Numbers / Google Sheets): [editor_translator_export_v31.csv](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/editor_translator_export_v31.csv)",
        "  - Tab-Separated TSV: [editor_translator_export_v31.tsv](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/editor_translator_export_v31.tsv)",
        "",
        "### Summary Counts by Localization Module",
        "",
        "| Module / Resource File | Total Keys / Entries | Source Path |",
        "| :--- | :---: | :--- |",
        f"| `Interface.strings` (Main App & Cards) | {len(sections.get('Interface.strings', []))} | [Interface.strings](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Utilities/Localization/uk.lproj/Interface.strings) |",
        f"| `Home.strings` (Support & Actions) | {len(sections.get('Home.strings', []))} | [Home.strings](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Utilities/Localization/uk.lproj/Home.strings) |",
        f"| `Onboarding.strings` (4-Step Setup & Full Access) | {len(sections.get('Onboarding.strings', []))} | [Onboarding.strings](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Utilities/Localization/uk.lproj/Onboarding.strings) |",
        f"| `About.strings` (About & Related Initiatives) | {len(sections.get('About.strings', []))} | [About.strings](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Utilities/Localization/uk.lproj/About.strings) |",
        f"| `Settings.bundle/Root.strings` (iOS System Settings) | {len(sections.get('Settings.bundle/Root.strings', []))} | [Root.strings](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Settings.bundle/uk.lproj/Root.strings) |",
        f"| `KeyboardKit/Localizable.strings` (Return & Mode Keys) | {len(sections.get('KeyboardKit/Localizable.strings', []))} | [Localizable.strings](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Sources/KeyboardKit/Resources/uk.lproj/Localizable.strings) |",
        f"| `Inline Swift UI` (`HomeView.swift` & `SpaceBarLabel.swift`) | {len(sections.get('Inline Swift UI (HomeView & SpaceBarLabel)', []))} | [HomeView.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift) / [SpaceBarLabel.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift) |",
        f"| `DailyPhrases.strings` (`#1`–`#85` Proverbs, Quotes & Greetings) | {len(sections.get('DailyPhrases.strings (#1–#85)', []))} | [DailyPhrases.strings](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Utilities/Localization/uk.lproj/DailyPhrases.strings) |",
        f"| `AppStoreMetadata` (v3.1 Storefront & Release Notes) | {len(sections.get('AppStoreMetadata (v3.1 Storefront)', []))} | [LOCALIZATIONS_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/appstore/LOCALIZATIONS_V31.md) / [WHATS_NEW_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/appstore/WHATS_NEW_V31.md) |",
        f"| **TOTAL LOCALIZED ENTRIES** | **{len(rows)}** | Complete 3-language coverage (`crh`, `uk`, `en`) |",
        "",
    ]

    for sec_title, sec_rows in sections.items():
        lines.append(f"## {sec_title} ({len(sec_rows)} entries)")
        lines.append("")
        lines.append(
            "| Key / ID | Screen & UI Location | Functional Purpose & Editor Comment | Optimal Max Chars (Current: crh / uk / en) | Qırımtatarca (`crh`) | Українська (`uk`) | English (`en`) |"
        )
        lines.append("| :--- | :--- | :--- | :--- | :--- | :--- | :--- |")
        for r in sec_rows:
            len_info = f"{r['max_chars']}<br>`crh={r['len_crh']}` · `uk={r['len_uk']}` · `en={r['len_en']}`"
            purpose_and_comment = r["purpose_context"]
            if r.get("editor_comment"):
                purpose_and_comment = f"{purpose_and_comment}<br>**Editor Review**: {r['editor_comment']}"
            lines.append(
                f"| `{escape_md(r['key'])}` | {escape_md(r['screen_location'])} | {escape_md(purpose_and_comment)} | {len_info} | {escape_md(r['crh'])} | {escape_md(r['uk'])} | {escape_md(r['en'])} |"
            )
        lines.append("")

    return "\n".join(lines)


def write_delimited(rows: List[Dict[str, str]], out_path: Path, delimiter: str, bom: bool = False) -> None:
    fieldnames = [
        "section",
        "key",
        "screen_location",
        "purpose_context",
        "max_chars",
        "len_crh",
        "len_uk",
        "len_en",
        "crh",
        "uk",
        "en",
        "editor_comment",
    ]
    encoding = "utf-8-sig" if bom else "utf-8"
    with out_path.open("w", encoding=encoding, newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter=delimiter, extrasaction="ignore")
        writer.writeheader()
        for r in rows:
            writer.writerow(r)


def main() -> None:
    DOCS_LOC_DIR.mkdir(parents=True, exist_ok=True)
    rows = collect_all_rows()
    md_content = build_markdown(rows)

    md_path = DOCS_LOC_DIR / "EDITOR_TRANSLATOR_EXPORT_V31.md"
    csv_path = DOCS_LOC_DIR / "editor_translator_export_v31.csv"
    tsv_path = DOCS_LOC_DIR / "editor_translator_export_v31.tsv"

    md_path.write_text(md_content, encoding="utf-8")
    write_delimited(rows, csv_path, delimiter=",", bom=True)
    write_delimited(rows, tsv_path, delimiter="\t", bom=False)

    doc_trans_dir = REPO_ROOT / "QTatar" / "Demo" / "Documentation" / "Translations"
    if doc_trans_dir.exists():
        (doc_trans_dir / "AppTranslations.md").write_text(md_content, encoding="utf-8")
        write_delimited(rows, doc_trans_dir / "AppTranslations.csv", delimiter=",", bom=True)

    if BRAIN_DIR.exists():
        try:
            (BRAIN_DIR / "localization_editor_translator_v31.md").write_text(md_content, encoding="utf-8")
            (BRAIN_DIR / "localization_master_table_v24.md").write_text(md_content, encoding="utf-8")
        except PermissionError:
            pass

    print(f"Exported {len(rows)} 3-language entries to:")
    print(f"  - {md_path}")
    print(f"  - {csv_path}")
    print(f"  - {tsv_path}")
    if doc_trans_dir.exists():
        print(f"  - {doc_trans_dir / 'AppTranslations.md'}")
        print(f"  - {doc_trans_dir / 'AppTranslations.csv'}")


if __name__ == "__main__":
    main()
