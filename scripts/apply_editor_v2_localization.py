#!/usr/bin/env python3
"""
Applies all verified localization updates from the linguistic editor's final review
(`/tmp/editor_review/editor_translator_export_v31_final_v2.csv`) across:
  1. QTatar/Demo/Demo/Utilities/Localization/{crh,uk,en}.lproj/{Interface,Home,Onboarding,About,DailyPhrases}.strings
  2. QTatar/Demo/Demo/Settings.bundle/{crh,uk,en}.lproj/Root.strings
  3. QTatar/Sources/KeyboardKit/Resources/{crh,uk,en}.lproj/Localizable.strings
  4. QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift (KeyboardGreetingPhrase.all #1-#85)
  5. AppStoreMetadata/{crh,uk,en-US,ru}/*.txt + docs/appstore/{LOCALIZATIONS_V31,WHATS_NEW_V31}.md
"""

from __future__ import annotations

import csv
import json
import re
from pathlib import Path
from typing import Dict, List, Optional, Tuple

REPO_ROOT = Path(__file__).resolve().parent.parent
LOC_DIR = REPO_ROOT / "QTatar" / "Demo" / "Demo" / "Utilities" / "Localization"
SETTINGS_BUNDLE_DIR = REPO_ROOT / "QTatar" / "Demo" / "Demo" / "Settings.bundle"
KK_LOC_DIR = REPO_ROOT / "QTatar" / "Sources" / "KeyboardKit" / "Resources"
APPSTORE_DIR = REPO_ROOT / "AppStoreMetadata"
DOCS_APPSTORE_DIR = REPO_ROOT / "docs" / "appstore"
DOCS_LOC_DIR = REPO_ROOT / "docs" / "localization"
V2_CSV_PATH = DOCS_LOC_DIR / "editor_source_files" / "editor_translator_export_v31_final_v2.csv"


def escape_strings_val(val: str) -> str:
    return val.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def update_strings_file(path: Path, updates: Dict[str, str]) -> int:
    content = path.read_text(encoding="utf-8")
    changed = 0
    for k, new_v in updates.items():
        esc_k = re.escape(k)
        esc_v = escape_strings_val(new_v)
        pattern = re.compile(rf'^(\s*"{esc_k}"\s*=\s*)"((?:[^"\\]|\\.)*)"(\s*;)', re.MULTILINE)
        match = pattern.search(content)
        if match:
            old_v_raw = match.group(2)
            if old_v_raw != esc_v:
                content = pattern.sub(
                    lambda m: f'{m.group(1)}"{esc_v}"{m.group(3)}',
                    content,
                    count=1,
                )
                changed += 1
        else:
            raise RuntimeError(f"Key {k!r} not found in {path}")
    path.write_text(content, encoding="utf-8")
    return changed


def parse_crh_phrase(raw: str) -> Tuple[str, str]:
    """Splits 'Quote text [Author]' or 'Quote text (Author)' into (text, attribution)."""
    raw = raw.strip()
    m_sq = re.match(r"^(.*?)\s*\[([^\]]+)\]$", raw)
    if m_sq:
        return m_sq.group(1).strip(), m_sq.group(2).strip()
    m_par = re.match(r"^(.*?)\s*\(([^)]+)\)$", raw)
    if m_par:
        return m_par.group(1).strip(), m_par.group(2).strip()
    return raw, ""


def swift_escape(s: str) -> str:
    return s.replace("\\", "\\\\").replace('"', '\\"')


def main() -> None:
    if not V2_CSV_PATH.exists():
        raise FileNotFoundError(f"Missing {V2_CSV_PATH}")

    with V2_CSV_PATH.open("r", encoding="utf-8-sig") as f:
        rows = list(csv.DictReader(f))

    assert len(rows) == 288, f"Expected 288 rows, got {len(rows)}"

    # Save editor comments map for export_localization_for_translator.py
    comments_map: Dict[str, str] = {}
    for r in rows:
        comments_map[f"{r['section']}::{r['key']}"] = r.get("editor_comment", "").strip()
    DOCS_LOC_DIR.mkdir(parents=True, exist_ok=True)
    (DOCS_LOC_DIR / "editor_comments_v31.json").write_text(
        json.dumps(comments_map, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    # 1. Standard .strings files
    section_to_dir_and_file = {
        "Interface.strings": (LOC_DIR, "Interface.strings"),
        "Home.strings": (LOC_DIR, "Home.strings"),
        "Onboarding.strings": (LOC_DIR, "Onboarding.strings"),
        "About.strings": (LOC_DIR, "About.strings"),
        "Settings.bundle/Root.strings": (SETTINGS_BUNDLE_DIR, "Root.strings"),
        "KeyboardKit/Localizable.strings": (KK_LOC_DIR, "Localizable.strings"),
    }

    for sec, (base_dir, fname) in section_to_dir_and_file.items():
        sec_rows = [r for r in rows if r["section"] == sec]
        for lang in ("crh", "uk", "en"):
            updates = {r["key"]: r[f"{lang}_final"] for r in sec_rows}
            p = base_dir / f"{lang}.lproj" / fname
            c = update_strings_file(p, updates)
            print(f"[{sec}] {lang}.lproj/{fname}: updated {c} keys")

    # 2. DailyPhrases.strings (#1 - #85) & Autocomplete+NativeToolbarStyle.swift
    dp_rows = [r for r in rows if r["section"].startswith("DailyPhrases.strings")]
    assert len(dp_rows) == 85, f"Expected 85 DailyPhrases rows, got {len(dp_rows)}"

    crh_lines = ["/* DailyPhrases.strings — Synced 1:1 with KeyboardGreetingPhrase.all (#1–#85) */", ""]
    uk_lines = ["/* DailyPhrases.strings — Synced 1:1 with KeyboardGreetingPhrase.all (#1–#85) */", ""]
    en_lines = ["/* DailyPhrases.strings — Synced 1:1 with KeyboardGreetingPhrase.all (#1–#85) */", ""]
    swift_items: List[str] = []

    for idx, r in enumerate(dp_rows, 1):
        key_prefix = f"phrase.{idx}."
        assert r["key"].startswith(f"phrase.{idx} "), f"Mismatch at {idx}: {r['key']}"
        text_crh, attr_crh = parse_crh_phrase(r["crh_final"])
        tr_crh = f"«{text_crh}» ({attr_crh})" if attr_crh else text_crh
        tr_uk = r["uk_final"].strip()
        tr_en = r["en_final"].strip()

        for lines_list, tr_val in ((crh_lines, tr_crh), (uk_lines, tr_uk), (en_lines, tr_en)):
            lines_list.append(f'"phrase.{idx}.text" = "{escape_strings_val(text_crh)}";')
            lines_list.append(f'"phrase.{idx}.attribution" = "{escape_strings_val(attr_crh)}";')
            lines_list.append(f'"phrase.{idx}.translation" = "{escape_strings_val(tr_val)}";')
            lines_list.append("")

        attr_swift = f'"{swift_escape(attr_crh)}"' if attr_crh else "nil"
        swift_items.append(
            f"        .init(\n"
            f"            id: {idx},\n"
            f'            text: "{swift_escape(text_crh)}",\n'
            f"            attribution: {attr_swift},\n"
            f'            translationUA: "{swift_escape(tr_uk)}",\n'
            f'            translationEN: "{swift_escape(tr_en)}"\n'
            f"        )"
        )

    (LOC_DIR / "crh.lproj" / "DailyPhrases.strings").write_text("\n".join(crh_lines), encoding="utf-8")
    (LOC_DIR / "uk.lproj" / "DailyPhrases.strings").write_text("\n".join(uk_lines), encoding="utf-8")
    (LOC_DIR / "en.lproj" / "DailyPhrases.strings").write_text("\n".join(en_lines), encoding="utf-8")
    print("[DailyPhrases.strings] Updated crh, uk, en (#1-#85)")

    # Update Autocomplete+NativeToolbarStyle.swift
    swift_path = REPO_ROOT / "QTatar" / "Demo" / "Keyboard" / "Autocomplete+NativeToolbarStyle.swift"
    swift_src = swift_path.read_text(encoding="utf-8")
    new_all_block = "    static let all: [KeyboardGreetingPhrase] = [\n" + ",\n".join(swift_items) + "\n    ]"
    pattern_all = re.compile(
        r"    static let all: \[KeyboardGreetingPhrase\] = \[\n.*?\n    \]",
        re.DOTALL,
    )
    assert pattern_all.search(swift_src), "Could not locate KeyboardGreetingPhrase.all in Autocomplete+NativeToolbarStyle.swift"
    swift_src = pattern_all.sub(lambda _: new_all_block, swift_src, count=1)
    swift_path.write_text(swift_src, encoding="utf-8")
    print("[Autocomplete+NativeToolbarStyle.swift] Synced KeyboardGreetingPhrase.all (#1-#85)")

    # 3. AppStoreMetadata (v3.1 Storefront)
    appstore_rows = {r["key"]: r for r in rows if r["section"].startswith("AppStoreMetadata")}
    key_to_fname = {
        "appstore.name": "name.txt",
        "appstore.subtitle": "subtitle.txt",
        "appstore.promotional_text": "promotional_text.txt",
        "appstore.keywords": "keywords.txt",
        "appstore.whats_new_v31": "whats_new.txt",
        "appstore.description": "description.txt",
    }

    import unicodedata
    for k, fname in key_to_fname.items():
        r = appstore_rows[k]
        crh_val = unicodedata.normalize("NFC", r["crh_final"].strip())
        uk_val = unicodedata.normalize("NFC", r["uk_final"].strip())
        en_val = unicodedata.normalize("NFC", r["en_final"].strip())

        if k == "appstore.description":
            # Synthesize 20.72 lexicon-verified orthography forms with V2 editor improvements
            crh_val = (
                crh_val.replace(unicodedata.normalize("NFC", "toğrudan-toğru"), unicodedata.normalize("NFC", "doğrudan-doğru"))
                .replace(unicodedata.normalize("NFC", "toğrudan-doğru"), unicodedata.normalize("NFC", "doğrudan-doğru"))
                .replace(unicodedata.normalize("NFC", "körünüş"), unicodedata.normalize("NFC", "körüniş"))
                .replace(unicodedata.normalize("NFC", "yıynalmay"), unicodedata.normalize("NFC", "toplanmay"))
            )

        (APPSTORE_DIR / "crh" / fname).write_text(crh_val + "\n", encoding="utf-8")
        (APPSTORE_DIR / "uk" / fname).write_text(uk_val + "\n", encoding="utf-8")
        (APPSTORE_DIR / "en-US" / fname).write_text(en_val + "\n", encoding="utf-8")
        if (APPSTORE_DIR / "en-GB" / fname).exists():
            (APPSTORE_DIR / "en-GB" / fname).write_text(en_val + "\n", encoding="utf-8")
        if k != "appstore.keywords":
            (APPSTORE_DIR / "ru" / fname).write_text(crh_val + "\n", encoding="utf-8")

    # Sync docs/appstore/LOCALIZATIONS_V31.md and WHATS_NEW_V31.md
    loc_md_path = DOCS_APPSTORE_DIR / "LOCALIZATIONS_V31.md"
    if loc_md_path.exists():
        loc_md = loc_md_path.read_text(encoding="utf-8")
        loc_md = loc_md.replace(
            "- **Subtitle**: `Latin, Kiril ve Svayp yazuv`",
            f"- **Subtitle**: `{appstore_rows['appstore.subtitle']['crh_final'].strip()}`",
        )
        loc_md = loc_md.replace(
            "  `Yañartılğan QırımKey iOS 26/27: QırımKey Swipe v2 svayp yazuvı, 2024/2025 resmiy imlâsı, Ukraina ФІВА tizilişi, aqıllı söz tevsiyeleri ve 100% internetsiz mahremiyet!`",
            f"  `{appstore_rows['appstore.promotional_text']['crh_final'].strip()}`",
        )
        loc_md_path.write_text(loc_md, encoding="utf-8")

    wn_md_path = DOCS_APPSTORE_DIR / "WHATS_NEW_V31.md"
    if wn_md_path.exists():
        wn_crh = appstore_rows["appstore.whats_new_v31"]["crh_final"].strip()
        wn_uk = appstore_rows["appstore.whats_new_v31"]["uk_final"].strip()
        wn_en = appstore_rows["appstore.whats_new_v31"]["en_final"].strip()
        wn_md = (
            "# What's New in Version 3.1 — QırımKey (Build 5)\n\n"
            "Source files:\n"
            "- [`AppStoreMetadata/crh/whats_new.txt`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/AppStoreMetadata/crh/whats_new.txt)\n"
            "- [`AppStoreMetadata/uk/whats_new.txt`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/AppStoreMetadata/uk/whats_new.txt)\n"
            "- [`AppStoreMetadata/en-US/whats_new.txt`](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/AppStoreMetadata/en-US/whats_new.txt)\n\n"
            "---\n\n"
            "## Crimean Tatar (`crh` & Visible `ru` Storefront)\n\n"
            f"```text\n{wn_crh}\n```\n\n"
            "---\n\n"
            "## Ukrainian (`uk`)\n\n"
            f"```text\n{wn_uk}\n```\n\n"
            "---\n\n"
            "## English (`en-US` / `en-GB`)\n\n"
            f"```text\n{wn_en}\n```\n"
        )
        wn_md_path.write_text(wn_md, encoding="utf-8")
    print("[AppStoreMetadata] Updated crh, uk, en-US, ru & docs/appstore/*.md")


if __name__ == "__main__":
    main()
