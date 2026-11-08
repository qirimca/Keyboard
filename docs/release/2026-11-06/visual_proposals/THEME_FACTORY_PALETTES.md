# QırımKey Curated Theme Factory Collection

Following the **Theme Factory** ([SKILL.md (claude-theme-factory)](file:///Users/love/.gemini/config/plugins/claude-skills/skills/claude-theme-factory/SKILL.md)) methodology, this specification defines **6 cohesive, culturally grounded and minimalist visual themes** designed for both the **QırımKey Keyboard Extension** ([DemoStyleProvider.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/DemoStyleProvider.swift), [Autocomplete+NativeToolbarStyle.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift), [SpaceBarLabel.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift), [SystemKeyboard.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Sources/KeyboardKit/_Essentials/SystemKeyboard.swift)) and the **QırımKey Host Application** ([HomeView.swift](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift) Bento cards, Statistics tiles, and [`iPadAbvSelectorButton`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Views/HomeView.swift#L4104-L4135)).

Every theme preserves 100% WCAG AA/AAA contrast compliance, supports both Light and Dark adaptive variants, and honors the strict non-regression rules of QırımKey (unplattered `Color.clear` daily wisdom banner in [`greetingBannerView(centerWidth:)`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift#L1427-L1490), stadium `14.0 pt` autocorrect pill, national gold `#FFD700` on sky-blue `#1295D8` for the `crh` [`TaraqTamgaShape`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/SpaceBarLabel.swift#L70-L111) badge, and 2-character spacebar corner codes `QT` / `КЪ` / `Кʼ`).

---

## Theme 1: Native iOS Liquid Glass (System Reference Baseline)

A pure, optically neutral Apple iOS 26/27 Liquid Glass surface with translucent keycaps, zero artificial drop shadows in modern mode, and crisp sky-blue brand accents.

### Color Palette
- **Keyboard Surface (Light / Dark)**: `rgba(212, 216, 224, 0.42)` / `rgba(28, 28, 30, 0.72)` — Translucent host backdrop blur
- **Input Keycap Fill (Light / Dark)**: `#FFFFFF` (`95%` opacity) / `#B5B5B5` (`24%` opacity) — Crisp tactile key surface
- **System Keycap Fill (Light / Dark)**: `#000000` (`17%` opacity) / `#B5B5B5` (`24%` opacity) — Functional perimeter anchor keys
- **Primary Brand Accent**: `#0087DB` (`brandBlue`) — Active toggles, primary Return/Search key, and speed badges
- **National Emblem Accent**: `#FFD700` on `#1295D8` → `#0B72B5` — Crimean Tatar Taraq Tamğa badge
- **Primary Ink (Light / Dark)**: `#000000` / `#FFFFFF` — Keycap glyphs and Bento titles

### Typography
- **Host App Headers & Bento Titles**: `GeneralSans-Semibold` (`15 pt`)
- **Host App Body & Subtitles**: `GeneralSans-Regular` / `GeneralSans-Medium` (`12 pt..13 pt`)
- **Keyboard Keycaps**: `SF Pro Text Regular` (`22.0 pt..25.5 pt` lowercase, condensed `12.0 pt` corner code)

### Best Used For
Default system-wide typing experience across all iOS 26/27 and iPadOS 26/27 apps where seamless native Apple integration is paramount.

---

## Theme 2: Bağçasaray Limestone & Gold (Cultural Heritage Light/Warm)

Inspired by the sun-warmed oolitic limestone courtyards of Hansaray in Bağçasaray and traditional Crimean Tatar gold embroidery (*altın sırma / mıhlama*). Warm ivory stone keycaps paired with deep walnut ink and subtle antique gold specular accents.

### Color Palette
- **Keyboard Surface & Bento Canvas**: `#F4EFE6` (Light) / `#1E1B18` (Dark) — Warm Crimean limestone base
- **Input Keycap & Card Surface**: `#FBF8F3` (`96%` opacity, Light) / `#2C2723` (`88%` opacity, Dark) — Honed travertine keycaps
- **System Keycap Fill**: `#E4DDD0` (Light) / `#3A332C` (Dark) — Warm sandstone perimeter keys
- **Primary Accent (Crimean Filigree Gold)**: `#C88A14` (Light) / `#F0B429` (Dark) — Autocorrect pill rim, Swipe v2 comet glow, and active switches
- **Secondary Accent (Terracotta Tile)**: `#B85A3A` — Peak WPM and achievement highlights
- **Primary Ink**: `#231F1B` (Light) / `#F5EFE6` (Dark) — Deep espresso-walnut typography

### Typography
- **Host App Display & Wisdom Quotes**: `InstrumentSerif-Regular` / `Lora-Medium` (`16 pt`)
- **Host App UI & Bento Controls**: `GeneralSans-Medium` (`12.5 pt..15 pt`)
- **Keyboard Keycaps**: `SF Pro Text Regular` with warm walnut ink `#231F1B`

### Best Used For
Literary writing, cultural correspondence, journaling, and users who want QırımKey to feel like a bespoke Crimean Tatar cultural artifact.

---

## Theme 3: Qara Deñiz Midnight (Bioluminescent Deep Sea Dark)

Inspired by the nocturnal waters of the Black Sea (*Qara Deñiz*) off the southern coast of Crimea, where deep abyssal slate meets luminous cyan-blue coastal reflections and golden starlight on the Taraq Tamğa.

### Color Palette
- **Keyboard Surface & Bento Canvas**: `#0B131E` — Abyssal Black Sea midnight navy
- **Input Keycap & Card Surface**: `#162233` (`86%` opacity) with `#2A405E` (`35%` top specular rim) — Deep marine glass keycaps
- **System Keycap Fill**: `#101A28` (`92%` opacity) — Submerged slate functional keys
- **Primary Accent (Bioluminescent Cyan-Blue)**: `#1295D8` → `#38BDF8` — Swipe v2 comet ribbon, active segmented bridges, and autocorrect stadium aura
- **Secondary Accent (Starlight Gold)**: `#FFD700` — Spacebar Taraq Tamğa word-commit pulse and mastery rings
- **Primary Ink**: `#EDF4FC` (Primary) / `#8CA3BA` (Secondary flick & subtitles)

### Typography
- **Host App Headers**: `GeneralSans-Semibold` (`15 pt`)
- **Numeric Telemetry & WPM Badges**: `GeistMono-Regular` / `SF Pro Rounded Semibold` (`11 pt..18 pt`)
- **Keyboard Keycaps**: `SF Pro Text Regular` in crisp ice-white `#EDF4FC`

### Best Used For
Nighttime typing, OLED battery efficiency on iPhone 15/16 Pro, developer/power-user workflows, and high-contrast nocturnal aesthetics.

---

## Theme 4: Aqmescit Minimalist Paper (Editorial E-Ink & Linen)

An ultra-calm, distraction-free editorial theme inspired by fine archival book paper and typographic broadsheets. Designed specifically to pair with the **Typographic Air (Borderless)** keyboard mode.

### Color Palette
- **Keyboard Surface & Bento Canvas**: `#F7F6F2` (Light) / `#161615` (Dark) — Unbleached archival cotton paper
- **Input Keycap Surface**: `transparent` (in Borderless mode) or `#FFFFFF` (`92%` with `1 px` `#E5E3DC` hairline border)
- **System Keycap Fill**: `#EAE7DF` (Light) / `#262624` (Dark) — Subtle stone-wash anchor pills
- **Primary Accent (Editorial CobaltInk)**: `#1D4ED8` (Light) / `#60A5FA` (Dark) — Crisp editorial proofreader blue
- **Secondary Accent (Sage Bookmark)**: `#4D7C5D` — Personal dictionary (`вивч.`) and vocabulary growth indicators
- **Primary Ink**: `#141413` (Light) / `#EDEDEC` (Dark) — High-contrast carbon ink

### Typography
- **Host App Headers**: `BricolageGrotesque-Bold` / `GeneralSans-Semibold`
- **Daily Wisdom Banner**: `CrimsonPro-Italic` / `SF Pro Text Regular` (`16 pt`)
- **Keyboard Keycaps**: `InstrumentSans-Regular` / `SF Pro Text Regular`

### Best Used For
Long-form essay writing, academic work in Crimean Tatar and Ukrainian, and minimalist purists who prefer zero visual clutter.

---

## Theme 5: Steppe Dawn — Çöl Tañı (Warm Horizon & Sage)

Evoking sunrise over the northern Crimean steppe (*Çöl*), where silver wormwood sage meets warm dawn apricot, muted lavender-indigo (`Къ`), and sky-blue (`Q`).

### Color Palette
- **Keyboard Surface & Bento Canvas**: `#F6F2EE` (Light) / `#1C191C` (Dark) — Morning mist over steppe grass
- **Input Keycap & Card Surface**: `#FFFDFB` (`94%` opacity, Light) / `#2A252A` (Dark)
- **System Keycap Fill**: `#E8E1DA` (Light) / `#363036` (Dark)
- **Primary Accent (Steppe Wormwood Sage)**: `#4A7C6F` — Calm botanical teal-sage for primary controls
- **Secondary Accent (Dawn Apricot & Amber)**: `#E07A5F` — Warm sunrise glow for Swipe v2 trail and speed tiles
- **Cyrillic Bridge Accent**: `#5956D6` — Harmonized lavender-indigo for `Къ` badge

### Typography
- **Host App Headers & Controls**: `Outfit-Bold` / `GeneralSans-Semibold`
- **Body & Subtitles**: `WorkSans-Regular` / `GeneralSans-Regular`
- **Keyboard Keycaps**: `SF Pro Text Regular`

### Best Used For
Daytime creative writing, warm ergonomic eye comfort, and users seeking an organic, nature-grounded palette.

---

## Theme 6: Chufut-Kale Obsidian (High-Contrast Monolith)

Named after the cliffside cave fortress of Çufut Qale, this theme delivers maximum architectural contrast: sculpted obsidian monolith keys, razor-sharp silver-white legends, and pure national gold (`#FFD700`) accents.

### Color Palette
- **Keyboard Surface & Bento Canvas**: `#050506` — Pure OLED obsidian void
- **Input Keycap & Card Surface**: `#141417` with `#2E2E36` (`1.0 pt` chamfered top border) — Carved basalt keycaps
- **System Keycap Fill**: `#0D0D10` with `#222228` border
- **Primary Accent (Taraq National Gold)**: `#FFD700` — High-visibility gold autocorrect stadium pill, swipe trail, and active toggles
- **Secondary Accent (Crimean Sky Cyan)**: `#1295D8` — Secondary telemetry and layout badges
- **Primary Ink**: `#FFFFFF` (`100%` contrast) / `#A1A1AA` (Secondary legends)

### Typography
- **Host App Headers**: `GeneralSans-Semibold` (`15.5 pt`)
- **Numeric Telemetry**: `JetBrainsMono-Bold` (`12 pt..18 pt`)
- **Keyboard Keycaps**: `SF Pro Text Medium` (`22 pt..25.5 pt` for enhanced legibility)

### Best Used For
Accessibility-first high-contrast needs (`colorSchemeContrast == .increased`), bright outdoor sunlight readability on OLED screens, and bold architectural aesthetics.
