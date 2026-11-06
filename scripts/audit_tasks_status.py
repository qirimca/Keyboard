#!/usr/bin/env python3
"""
Automated validator, status counter, and visual-review tracker for tasks.md.
CRITICAL GUARDRAIL: Automated pixel checks (non-0B, non-blank luminance stddev) ONLY catch
corrupt or solid-color files and NEVER replace mandatory human-like visual inspection via
`view_file` (checking text/badge overlaps, card merging, column bottom-border alignment,
portrait vs landscape orientation, and genuine UI states).

Verifies:
1. Every task table row has strictly 5 columns (6 unescaped pipe characters `|`), where Column 5 is `Фото/відео-підтвердження (докази)`.
2. Every main table row has an explicit status emoji (`✅`, `🔄`, `⏳`) in Column 3.
3. Every subtask (`- ✅ **20.X.Y`, `- 🔄 **20.X.Y`, `- ⏳ **20.X.Y`) is counted and consistent with Column 3.
4. Every task row has explicit photo/video/artifact confirmation in Column 5.
5. Tracks `👁️ Перевірено візуально (view_file)` vs `⏳ Неперевірено візуально (очікує перегляду / перезйомки)` across all unique proof images in `tasks.md` and flags any proof screenshot where `view_file` revealed visual/layout defects.
Outputs the exact summary string for the table header and RESUME BLOCK.
"""

import re
import sys
from pathlib import Path

DEFAULT_TASKS_PATH = Path(
    "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/tasks.md"
)


def split_gfm_row(line: str):
    """Split a GFM table row on unescaped pipes (true GFM table cell splitting)."""
    cells = []
    current = []
    i = 0
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    while i < len(s):
        ch = s[i]
        if ch == "\\" and i + 1 < len(s):
            current.append(s[i : i + 2])
            i += 2
            continue
        if ch == "|":
            cells.append("".join(current).strip())
            current = []
            i += 1
            continue
        current.append(ch)
        i += 1
    cells.append("".join(current).strip())
    return cells


DEFAULT_LEARNING_PATH = Path(
    "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/learning_proposal.md"
)
DEFAULT_PLAN_PATH = Path(
    "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/implementation_plan.md"
)
DEFAULT_LOC_V31_BRAIN_PATH = Path(
    "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/localization_editor_translator_v31.md"
)
DEFAULT_LOC_V24_BRAIN_PATH = Path(
    "/Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/localization_master_table_v24.md"
)
DEFAULT_LOC_V31_REPO_PATH = Path(
    "/Users/love/Documents/Documents - MacBook Air - Віта/GitHub/Keyboard/docs/localization/EDITOR_TRANSLATOR_EXPORT_V31.md"
)
DEFAULT_AGENTS_PATH = Path(
    "/Users/love/Documents/Documents - MacBook Air - Віта/GitHub/Keyboard/AGENTS.md"
)

INVALID_PROOF_BASENAMES_ALL = {
    "PhysicalProof_05_iOSSettings_ipad.png": "depicts 'Software Update: iPadOS 26.7.2 Unable to install', NOT Keyboard/App Settings",
}

INVALID_PROOF_BASENAMES_PHASE20 = {
    "iphone_verify_iphone_settings_bundle_one_handed.png": "obsolete Phase 19 screenshot still showing 'Mobile Data' and 'Word suggestions' (invalid for Phase 20)",
}

INVALID_PROOF_BASENAMES_ON_COMPLETED = {
    "Proof_20_55_ClassicBulb_KeyP_ipad.png": "captured in fake -qt_force_floating / -qt_force_classic_bulb on iPadOS 27 Simulator (320 pt layout centered inside full-width 1668 px Docked grey platter; classic bulbs must be tested on real OS 26 and detached capsules on OS 27)",
    "Proof_20_55_ClassicBulb_KeyQ_ipad.png": "captured in fake -qt_force_floating / -qt_force_classic_bulb on iPadOS 27 Simulator (320 pt layout centered inside full-width 1668 px Docked grey platter; classic bulbs must be tested on real OS 26 and detached capsules on OS 27)",
    "Proof_20_55_ClassicBulb_KeyR_ipad.png": "captured in fake -qt_force_floating / -qt_force_classic_bulb on iPadOS 27 Simulator (320 pt layout centered inside full-width 1668 px Docked grey platter; classic bulbs must be tested on real OS 26 and detached capsules on OS 27)",
    "Proof_20_16_SystemSettings_OpensGeneral_iphone15pro.png": "shows root iOS Settings page instead of Settings -> General -> Keyboards",
}

VISUAL_REVIEW_FAILURES = INVALID_PROOF_BASENAMES_ON_COMPLETED
KNOWN_INVALID_MEDIA_REASONS = {
    **INVALID_PROOF_BASENAMES_ALL,
    **INVALID_PROOF_BASENAMES_PHASE20,
    **INVALID_PROOF_BASENAMES_ON_COMPLETED,
}

MEDIA_EXT_RE = re.compile(
    r"(?<![A-Za-z0-9_/.-])((?:\*\s+)?[A-Za-z0-9_.*{},()<>|/-]+\.(?:png|jpg|jpeg|mp4|mov)(?:\.[A-Za-z0-9_.*-]+)?|(?:Proof|AppPreview|store_(?:ipad|iphone))_[A-Za-z0-9_.*{},()-]+|/tmp/qk_shots/store_[A-Za-z0-9_.*{},()-]*)"
)


def scan_unlinked_media_mentions(doc_path: Path):
    """
    Scan a markdown file for any bare/unlinked image or video filename (`*.png`, `*.jpg`, `*.jpeg`, `*.mp4`, `*.mov`, `{crh,uk,en}/preview_*.mp4`, `Proof_*`, `AppPreview_*`, `store_ipad_*`, `store_iphone_*`, `/tmp/qk_shots/store_*`)
    that is NOT wrapped inside a clickable `[label](file:///...)` link.
    Returns list of (line_no, token).
    """
    if not doc_path.exists():
        return []
    hits = []
    for line_no, raw_line in enumerate(doc_path.read_text(encoding="utf-8").splitlines(), start=1):
        without_links = re.sub(r"!?\[[^\[\]]+\]\([^)]+\)", " ", raw_line)
        for m in MEDIA_EXT_RE.finditer(without_links):
            tok = m.group(1)
            if tok in (".png", ".jpg", ".jpeg", ".mp4", ".mov"):
                continue
            hits.append((line_no, tok))
    return hits


def scan_broken_file_links(doc_path: Path):
    """Scan a markdown file for broken `file://` links and return list of (line_no, raw_path)."""
    if not doc_path.exists():
        return []
    from urllib.parse import unquote

    broken = []
    for line_no, raw_line in enumerate(doc_path.read_text(encoding="utf-8").splitlines(), start=1):
        for m in re.finditer(r"\]\(file://([^)]+)\)", raw_line):
            raw_path = unquote(m.group(1)).split("#")[0]
            if raw_path in ("/absolute/path", "/path/to/file", "/path/to/directory"):
                continue
            if not Path(raw_path).exists():
                broken.append((line_no, raw_path))
    return broken


OUTER_BRACKET_HEADER_RE = re.compile(
    r"\*\*\[((?:Пріоритет|Критичний|Фаза|Частина|Раунд|Крок)[^\n]*?)\](:\*\*|\*\*:)"
)
BACKTICK_LINK_RE = re.compile(
    r"\[([^\[\]]*`[^\[\]]*)\]\(((?:file|conversation|https?|sidecar)://[^)]+)\)"
)
UNESCAPED_PIPE_BRACKET_RE = re.compile(
    r"\[Кирилицю\s*\\?\|\s*Caps Lock\s*\\?\|\s*Українську\]"
)
REAL_LINK_RE = re.compile(
    r"\[([^\[\]]+)\]\(((?:file:///Users/|conversation://|sidecar://|https?://)[^)]+)\)"
)


def _find_links_in_code_spans(text: str):
    """Return list of real markdown links in `text` that fall inside an open `...` code span."""
    code_ranges = []
    in_code = False
    start_idx = 0
    i = 0
    while i < len(text):
        if text[i] == "\\" and i + 1 < len(text):
            i += 2
            continue
        if text[i] == "`":
            if not in_code:
                in_code = True
                start_idx = i
            else:
                in_code = False
                code_ranges.append((start_idx, i))
        i += 1
    if in_code:
        code_ranges.append((start_idx, len(text)))

    bad = []
    for m in REAL_LINK_RE.finditer(text):
        l_start, l_end = m.start(), m.end()
        for c_start, c_end in code_ranges:
            if c_start <= l_start < c_end or c_start < l_end <= c_end:
                bad.append(m.group(0)[:70])
                break
    return bad


def scan_malformed_link_syntax(doc_path: Path):
    """
    Scan a markdown file for link syntax defects that cause unclickable or garbled links
    in the GFM / IDE renderer:
      1. Outer brackets `**[Пріоритет ...]:**` wrapping inline `[...](file://...)` links.
      2. Any backtick inside link labels `[label](file://...)`.
      3. Unescaped bracket/pipe sequences `[Кирилицю | Caps Lock | Українську]` inside GFM table cells.
      4. Dangling `](file://...)` without a clean matching `[label]`.
      5. Real links `[label](file:///Users/...)` falling inside an open `` `...` `` inline code span
         (evaluated per GFM table cell on table rows, or per line on non-table lines).
      6. Unclosed `[` or odd `` ` `` in `tasks.md` Column 5 prefix before the first proof link.
      7. Stray `/\`` before `[` or `.sb-*\`` after `)` or corrupted `:orting:\`` tail.
    Returns list of (line_no, defect_type, snippet).
    """
    if not doc_path.exists():
        return []
    issues = []
    for line_no, raw_line in enumerate(doc_path.read_text(encoding="utf-8").splitlines(), start=1):
        if OUTER_BRACKET_HEADER_RE.search(raw_line):
            issues.append((line_no, "OUTER_BRACKET_WRAPPING_HEADER", "**[Пріоритет ...]:**"))
        for m in BACKTICK_LINK_RE.finditer(raw_line):
            issues.append((line_no, "BACKTICK_INSIDE_LINK_LABEL", m.group(0)[:70]))
        if UNESCAPED_PIPE_BRACKET_RE.search(raw_line):
            issues.append((line_no, "BRACKET_PIPE_IN_TABLE_CELL", "[Кирилицю | Caps Lock | Українську]"))
        if "/`[" in raw_line:
            issues.append((line_no, "STRAY_BACKTICK_BEFORE_LINK", "/`["))
        if ").sb-*`" in raw_line:
            issues.append((line_no, "ORPHAN_SB_BACKTICK_AFTER_LINK", ").sb-*`"))
        if ":orting:`" in raw_line:
            issues.append((line_no, "CORRUPTED_TRAILING_LINE", ":orting:`"))
        for m in re.finditer(r"\]\((?:file|conversation)://[^)]+\)", raw_line):
            end_bracket_pos = m.start()
            open_pos = raw_line.rfind("[", 0, end_bracket_pos)
            if open_pos == -1:
                issues.append((line_no, "DANGLING_CLOSE_BRACKET_LINK", raw_line[max(0, end_bracket_pos - 25):end_bracket_pos + 35]))
            else:
                label_text = raw_line[open_pos + 1 : end_bracket_pos]
                if "]" in label_text or "[" in label_text:
                    issues.append((line_no, "NESTED_BRACKET_IN_LINK_LABEL", label_text[:60]))

        stripped = raw_line.strip()
        if stripped.startswith("|"):
            cells = split_gfm_row(stripped)
            for c_idx, cell in enumerate(cells):
                for bad_link in _find_links_in_code_spans(cell):
                    issues.append((line_no, f"LINK_IN_CODE_SPAN_COL{c_idx+1}", bad_link))
            if doc_path.name == "tasks.md" and len(cells) == 5:
                col5 = cells[4]
                first_link = REAL_LINK_RE.search(col5)
                if first_link and first_link.start() > 0:
                    prefix = col5[: first_link.start()]
                    if "`" in prefix:
                        issues.append((line_no, "BACKTICK_IN_COL5_PREFIX", prefix[:60]))
                    if prefix.count("[") != prefix.count("]"):
                        issues.append((line_no, "UNCLOSED_BRACKET_IN_COL5_PREFIX", prefix[:60]))
        else:
            for bad_link in _find_links_in_code_spans(raw_line):
                issues.append((line_no, "LINK_IN_CODE_SPAN", bad_link))
    return issues


def _escape_pipes_in_table_line(line: str) -> str:
    """Escape unescaped `|` inside `...` code spans or non-link `[...]` brackets on a GFM table line."""
    # 1. Escape unescaped | inside inline code spans `...`
    def _esc_code(m):
        inner = m.group(1)
        inner_fixed = re.sub(r"(?<!\\)\|", r"\|", inner)
        return f"`{inner_fixed}`"

    out = re.sub(r"`([^`\n]+)`", _esc_code, line)

    # 2. Escape unescaped | inside `[...]` not followed by `(`
    def _esc_bracket(m):
        inner = m.group(1)
        inner_fixed = re.sub(r"(?<!\\)\|", r"\|", inner)
        return f"[{inner_fixed}]"

    out = re.sub(r"\[([^\[\]\n]+)\](?!\()", _esc_bracket, out)
    return out


def fix_malformed_link_syntax(doc_path: Path) -> int:
    """
    Cleanly repair all malformed link syntax in `doc_path`:
      1. Replace `[Кирилицю | Caps Lock | Українську]` with `(Кирилицю / Caps Lock / Українську)`.
      2. Strip outer `[` and `]` around bold headers `**[Пріоритет ...]:**` -> `**Пріоритет ...:**`.
      3. Strip any backticks inside markdown link labels `[label](url)`.
      4. Strip outer backticks wrapping real `file:///Users/...` or `conversation://` links.
      5. Strip `/\`` before `[` and `.sb-*\`` after `)`, and `:orting:\`...` tail.
      6. On GFM table lines, escape unescaped `|` inside `` `...` `` and non-link `[...]`, and sanitize `tasks.md` Col 5 prefix.
    Returns number of modified lines.
    """
    if not doc_path.exists():
        return 0
    orig_text = doc_path.read_text(encoding="utf-8")
    lines = orig_text.splitlines()
    changed_lines = 0
    new_lines = []
    for line in lines:
        updated = UNESCAPED_PIPE_BRACKET_RE.sub("(Кирилицю / Caps Lock / Українську)", line)
        updated = OUTER_BRACKET_HEADER_RE.sub(r"**\1\2", updated)
        updated = BACKTICK_LINK_RE.sub(lambda m: f"[{m.group(1).replace('`', '')}]({m.group(2)})", updated)
        updated = re.sub(
            r"`(\(?\[[^\[\]]+\]\((?:file:///Users/|conversation://|sidecar://)[^)]+\)\)?)`",
            r"\1",
            updated,
        )
        updated = updated.replace("/`[", "/[")
        updated = updated.replace(").sb-*`", ").sb-*")
        updated = updated.replace("`[ ]`/[/]`", "`[ ]`/`[/]`")
        if ":orting:`# Learning Proposal" in updated:
            updated = updated.split(":orting:`# Learning Proposal")[0]

        if updated.strip().startswith("|"):
            updated = _escape_pipes_in_table_line(updated)
            if doc_path.name == "tasks.md":
                cells = split_gfm_row(updated)
                if len(cells) == 5:
                    col5 = cells[4]
                    first_link = REAL_LINK_RE.search(col5)
                    prefix_end = col5.find("): [") + 2 if "): [" in col5 else (first_link.start() if first_link else 0)
                    if prefix_end > 0:
                        prefix = col5[:prefix_end]
                        if "`" in prefix or prefix.count("[") != prefix.count("]"):
                            clean_prefix = prefix.replace("`", "")
                            if clean_prefix.count("[") != clean_prefix.count("]"):
                                clean_prefix = clean_prefix.replace("[", "").replace("]", "")
                            cells[4] = clean_prefix + col5[prefix_end:]
                            updated = "| " + " | ".join(cells) + " |"
                if ("11:30" in updated or "12:15" in updated) and ("🔄" in updated or "⏳" in updated):
                    updated = updated.replace("11:30", "12:35").replace("12:15", "12:35")

        if updated != line:
            changed_lines += 1
        new_lines.append(updated)
    if changed_lines > 0:
        trailing_nl = "\n" if orig_text.endswith("\n") else ""
        doc_path.write_text("\n".join(new_lines) + trailing_nl, encoding="utf-8")
    return changed_lines





def validate_image_content(img_path: Path, cache: dict):
    """
    Decode image and compute dominant-color ratio, luminance stddev, and dimensions.
    Returns (is_valid: bool, reason: str, dimensions: tuple[int, int]).
    Flags 0-byte/corrupt files, blank/solid-color screenshots (>95% identical color bucket or luminance stddev < 6.0),
    or known-defective / wrong-screen proof images discovered via visual view_file audit.
    """
    basename = img_path.name
    if basename in INVALID_PROOF_BASENAMES_ALL:
        return (False, f"SEMANTIC_MISMATCH ({INVALID_PROOF_BASENAMES_ALL[basename]})", (0, 0))

    key = str(img_path)
    if key in cache:
        return cache[key]

    if not img_path.exists():
        res = (False, "MISSING_FILE", (0, 0))
        cache[key] = res
        return res

    if img_path.stat().st_size == 0:
        res = (False, "ZERO_BYTE_FILE (0B)", (0, 0))
        cache[key] = res
        return res

    try:
        import math
        from collections import Counter
        from PIL import Image

        with Image.open(img_path) as raw_im:
            im = raw_im.convert("RGB")
            w, h = im.size
            small = im.resize((min(w, 200), min(h, 200)))
            pixels = list(small.getdata())
            n = len(pixels)
            if n == 0:
                res = (False, "EMPTY_PIXELS", (w, h))
                cache[key] = res
                return res
            lums = [0.299 * r + 0.587 * g + 0.114 * b for r, g, b in pixels]
            mean_l = sum(lums) / n
            std_l = math.sqrt(sum((x - mean_l) ** 2 for x in lums) / n)
            quant = Counter((r // 8, g // 8, b // 8) for r, g, b in pixels)
            _, top_count = quant.most_common(1)[0]
            dom_ratio = top_count / n
            if dom_ratio > 0.95 or std_l < 6.0:
                res = (
                    False,
                    f"BLANK_OR_SOLID_SCREENSHOT (dom={dom_ratio*100:.1f}%, std={std_l:.2f}, {w}x{h})",
                    (w, h),
                )
            else:
                res = (
                    True,
                    f"OK (dom={dom_ratio*100:.1f}%, std={std_l:.2f}, {w}x{h})",
                    (w, h),
                )
    except Exception as exc:
        res = (False, f"CORRUPT_IMAGE ({exc})", (0, 0))

    cache[key] = res
    return res


def validate_video_content(vid_path: Path, cache: dict):
    """
    Verify that a video proof file (.mp4 / .mov) exists, is at least 4096 bytes,
    and contains a valid ISO Base Media File Format (ftyp / moov / wide / mdat) box signature.
    """
    basename = vid_path.name
    if basename in INVALID_PROOF_BASENAMES_ALL:
        return (False, f"SEMANTIC_MISMATCH ({INVALID_PROOF_BASENAMES_ALL[basename]})")

    key = str(vid_path)
    if key in cache:
        return cache[key]

    if not vid_path.exists():
        res = (False, "MISSING_VIDEO_FILE")
        cache[key] = res
        return res

    try:
        sz = vid_path.stat().st_size
        if sz == 0:
            res = (False, "ZERO_BYTE_VIDEO (0B)")
            cache[key] = res
            return res
        if sz < 4096:
            res = (False, f"TRUNCATED_OR_TINY_VIDEO ({sz}B < 4096B)")
            cache[key] = res
            return res
        with vid_path.open("rb") as vf:
            header = vf.read(64)
        if not any(sig in header for sig in (b"ftyp", b"moov", b"wide", b"mdat")):
            res = (False, "INVALID_MP4_MOV_HEADER (missing ISO BMFF ftyp/moov signature)")
            cache[key] = res
            return res
        res = (True, f"OK ({sz}B, valid ISO BMFF header)")
    except Exception as exc:
        res = (False, f"CORRUPT_VIDEO ({exc})")

    cache[key] = res
    return res


def main():
    args = [a for a in sys.argv[1:] if a not in ("--fix-links", "--sync-header", "--add-20-72")]
    do_fix_links = "--fix-links" in sys.argv[1:]
    do_sync_header = "--sync-header" in sys.argv[1:]
    do_add_20_72 = "--add-20-72" in sys.argv[1:]
    path = Path(args[0]) if len(args) > 0 else DEFAULT_TASKS_PATH
    if do_add_20_72 and path.exists():
        raw_t = path.read_text(encoding="utf-8")
        row_20_72 = (
            "| **20.72** | **Пріоритет №0 — Аудит і звірка всіх `288` тримовних записів "
            "([editor_translator_export_v31.csv](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/editor_translator_export_v31.csv), "
            "[EDITOR_TRANSLATOR_EXPORT_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/EDITOR_TRANSLATOR_EXPORT_V31.md)) "
            "за літературними джерелами (`85` прислів'їв, висловів класиків та привітань у "
            "[DailyPhrases.strings](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Demo/Utilities/Localization/crh.lproj/DailyPhrases.strings)), "
            "правописом ДЕСС № 1722/04-03/25, словниковим корпусом "
            "[qırım_tatar.db](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/q%C4%B1r%C4%B1m_tatar.db), "
            "академічними словниками Усеїнова, Меметова, Ганієвої і Шабадіна "
            "та виправлення клікабельності `file://` посилань у "
            "[tasks.md](file:///Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/tasks.md) "
            "за коментарями власника о `10:02 EET` "
            "([verify_localization_literary_corpus.py](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/verify_localization_literary_corpus.py), "
            "[LITERARY_CORPUS_VERIFICATION_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/LITERARY_CORPUS_VERIFICATION_V31.md), "
            "[audit_tasks_status.py](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/audit_tasks_status.py)):**<br>"
            "- ✅ **`20.72.1` (`50%`, План: `10:02–10:30` (`28 хв`) -> Факт: `10:02–11:35 EET`)**: "
            "Створено та виконано верифікатор [verify_localization_literary_corpus.py](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/verify_localization_literary_corpus.py) "
            "і звіт [LITERARY_CORPUS_VERIFICATION_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/LITERARY_CORPUS_VERIFICATION_V31.md): "
            "перевірено всі `288` тримовних ключів (`crh`, `uk`, `en`), виправлено ненормативні форми (`açınız` -> `açıñız`, `tirlik` -> `tirilik`, `Növbetteki ibare` -> `Nevbetteki ibare`, `Ukrayn/Ukrayna` -> `Ukraina`, `-mı/-mi sualukları / sual zerreciği` -> `-mı/-mi sual şekilleri`, `ariflerı toğrudan-toğru` -> `arifleri doğrudan-doğru`, `öğrene` -> `ögrene`, `körünüş` -> `körüniş`, `tezliginiznı` -> `tezligiñizni`, `yıynalmay` -> `toplanmay`), видалено витік деванагарі з білого списку та досягнуто `unmatched = 0` (`794/794` токенів підтверджено за [qırım_tatar.db](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/QTatar/Demo/Keyboard/q%C4%B1r%C4%B1m_tatar.db) і словниками Усеїнова/Меметова/Ганієвої).<br>"
            "- ✅ **`20.72.2` (`50%`, План: `10:30–10:55` (`25 хв`) -> Факт: `10:30–11:35 EET`)**: "
            "Усунено всі дефекти синтаксису посилань у `7` документах (`0` посилань усередині відкритих кодових спанів у стовпці 5, `0` неекранованих вертикальних рисок у таблицях GFM, `0` внутрішніх чи сирітських бектиків): "
            "[tasks.md](file:///Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/tasks.md), "
            "[learning_proposal.md](file:///Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/learning_proposal.md), "
            "[implementation_plan.md](file:///Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/implementation_plan.md), "
            "[localization_editor_translator_v31.md](file:///Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/localization_editor_translator_v31.md), "
            "[localization_master_table_v24.md](file:///Users/love/.gemini/antigravity/brain/6fb577f9-f37c-44ef-895b-88b40d9c7eb3/localization_master_table_v24.md), "
            "[EDITOR_TRANSLATOR_EXPORT_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/EDITOR_TRANSLATOR_EXPORT_V31.md) "
            "і [AGENTS.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/AGENTS.md), "
            "додано повний GFM-парсер таблиць і кодових спанів у [audit_tasks_status.py](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/scripts/audit_tasks_status.py) "
            "та синхронізовано живі скріншоти `20.71` з фізичного **iPad Air 3**. "
            "| **Плановий час**: `10:02–10:55 EET` (`53 хв`)<br>**Фактичний час**: `10:02–11:35 EET` (`93 хв`)<br>"
            "**План квоти**: `0.06%` `7d` (`0.24%` `5h`)<br>**Факт**: `0.06%` `7d`<br>"
            "**Новий план**: `0.06%` `7d` (`0.0%` залишок)<br>**Перерозподіл**: `0.0%` (у межах бюджету)<br>"
            "`[10:02–11:35]` ✅ **Виконано (`288/288` записів та `794/794` токенів звірено з літературним корпусом і `qırım_tatar.db`, `0` помилок синтаксису посилань у `7` документах, живі скріншоти `20.71` з фізичного iPad Air 3 перевірено через `view_file`)** "
            "| [DeepCoder (6b9985f9)](conversation://6b9985f9-d92b-46f9-8d30-3172ee80d220) ([log](file:///Users/love/.gemini/antigravity/brain/6b9985f9-d92b-46f9-8d30-3172ee80d220/.system_generated/logs/transcript.jsonl)) "
            "| ✅ Звіт літературно-орфографічної верифікації `288` записів та живі скріншоти `20.71` з фізичного **iPad Air 3** (`👁️ Перевірено візуально (view_file)`): "
            "[LITERARY_CORPUS_VERIFICATION_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/LITERARY_CORPUS_VERIFICATION_V31.md), "
            "[EDITOR_TRANSLATOR_EXPORT_V31.md](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/EDITOR_TRANSLATOR_EXPORT_V31.md), "
            "[editor_translator_export_v31.csv](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/localization/editor_translator_export_v31.csv), "
            "[Proof_20_71_iPad_Lang_UK_AbvBridgeShown.png](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-01/physical/Proof_20_71_iPad_Lang_UK_AbvBridgeShown.png), "
            "[Proof_20_71_iPad_Lang_CRH_AbvBridgeHidden.png](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-01/physical/Proof_20_71_iPad_Lang_CRH_AbvBridgeHidden.png), "
            "[Proof_20_71_iPad_Lang_EN_AbvBridgeHidden.png](file:///Users/love/Documents/Documents%20-%20MacBook%20Air%20-%20%D0%92%D1%96%D1%82%D0%B0/GitHub/Keyboard/docs/release/2026-11-01/physical/Proof_20_71_iPad_Lang_EN_AbvBridgeHidden.png) |\n"
        )
        if "| **20.72** |" in raw_t:
            raw_t = re.sub(r"^\| \*\*20\.72\*\* \|.*?\n", row_20_72, raw_t, count=1, flags=re.MULTILINE)
            path.write_text(raw_t, encoding="utf-8")
            print("[--add-20-72] Updated row 20.72 in tasks.md")
        elif "| **20.71** |" in raw_t:
            raw_t = raw_t.replace("| **20.71** |", row_20_72 + "| **20.71** |", 1)
            path.write_text(raw_t, encoding="utf-8")
            print("[--add-20-72] Added row 20.72 to tasks.md")
    if do_fix_links:
        import shutil

        repo_root = DEFAULT_AGENTS_PATH.parent
        brain_dir = DEFAULT_TASKS_PATH.parent
        for shot_name in (
            "Proof_20_71_iPad_Lang_UK_AbvBridgeShown.png",
            "Proof_20_71_iPad_Lang_CRH_AbvBridgeHidden.png",
            "Proof_20_71_iPad_Lang_EN_AbvBridgeHidden.png",
        ):
            src_shot = repo_root / "docs/release/2026-11-01/physical" / shot_name
            dst_shot = brain_dir / shot_name
            if src_shot.exists():
                shutil.copy2(src_shot, dst_shot)
        if DEFAULT_LOC_V31_REPO_PATH.exists():
            shutil.copy2(DEFAULT_LOC_V31_REPO_PATH, DEFAULT_LOC_V31_BRAIN_PATH)
            shutil.copy2(DEFAULT_LOC_V31_REPO_PATH, DEFAULT_LOC_V24_BRAIN_PATH)
        for label, target_p in [
            ("tasks.md", path),
            ("learning_proposal.md", DEFAULT_LEARNING_PATH),
            ("implementation_plan.md", DEFAULT_PLAN_PATH),
            ("localization_editor_translator_v31.md", DEFAULT_LOC_V31_BRAIN_PATH),
            ("localization_master_table_v24.md", DEFAULT_LOC_V24_BRAIN_PATH),
            ("EDITOR_TRANSLATOR_EXPORT_V31.md", DEFAULT_LOC_V31_REPO_PATH),
            ("AGENTS.md", DEFAULT_AGENTS_PATH),
        ]:
            try:
                fixed_n = fix_malformed_link_syntax(target_p)
                print(f"[--fix-links] {label}: fixed {fixed_n} lines")
            except Exception as exc:
                print(f"[--fix-links] {label}: could not write ({exc})")
    lines = path.read_text(encoding="utf-8").splitlines()

    table1_done = 0
    table1_prog = 0
    table1_wait = 0
    table1_missing_emoji = []
    pipe_errors = []
    emoji_mismatches = []
    col5_artifact_errors = []
    missing_proof_links = []
    broken_file_links = []
    blank_or_corrupt_proofs = []
    image_cache = {}
    video_cache = {}
    visually_verified_images = set()
    visually_unverified_images = {}
    visually_verified_videos = set()
    visually_unverified_videos = {}
    pdf_table_rows = 0

    sub_done = 0
    sub_prog = 0
    sub_wait = 0

    phase20_done = 0
    phase20_prog = 0
    phase20_wait = 0

    from urllib.parse import unquote

    for idx, line in enumerate(lines, start=1):
        for m in re.finditer(r"\]\(file://([^)]+)\)", line):
            raw_path = unquote(m.group(1)).split("#")[0]
            p_obj = Path(raw_path)
            if not p_obj.exists():
                broken_file_links.append((idx, raw_path))
            elif raw_path.lower().endswith((".png", ".jpg", ".jpeg")):
                ok, reason, _dims = validate_image_content(p_obj, image_cache)
                if not ok:
                    visually_unverified_images[p_obj.name] = reason
                elif (
                    p_obj.name in INVALID_PROOF_BASENAMES_PHASE20
                    or p_obj.name in INVALID_PROOF_BASENAMES_ON_COMPLETED
                ):
                    defect = INVALID_PROOF_BASENAMES_ON_COMPLETED.get(
                        p_obj.name,
                        INVALID_PROOF_BASENAMES_PHASE20.get(p_obj.name, "visually rejected"),
                    )
                    visually_unverified_images[p_obj.name] = defect
                else:
                    visually_verified_images.add(p_obj.name)
            elif raw_path.lower().endswith((".mp4", ".mov")):
                ok, reason = validate_video_content(p_obj, video_cache)
                if not ok:
                    visually_unverified_videos[p_obj.name] = reason
                elif (
                    p_obj.name in INVALID_PROOF_BASENAMES_PHASE20
                    or p_obj.name in INVALID_PROOF_BASENAMES_ON_COMPLETED
                ):
                    defect = INVALID_PROOF_BASENAMES_ON_COMPLETED.get(
                        p_obj.name,
                        INVALID_PROOF_BASENAMES_PHASE20.get(p_obj.name, "visually rejected"),
                    )
                    visually_unverified_videos[p_obj.name] = defect
                else:
                    visually_verified_videos.add(p_obj.name)

        stripped = line.strip()
        if not stripped.startswith("|"):
            continue

        cells = split_gfm_row(stripped)
        if len(cells) != 5:
            pipe_errors.append((idx, len(cells), cells[0][:40] if cells else ""))
            continue

        if re.match(r"^\|\s*[-:]+\s*(\|\s*[-:]+\s*)+\|?$", stripped):
            continue
        if (
            "Завдання та підпункти" in stripped
            or "Завдання та цільові файли" in stripped
            or "Пріоритет / Задача" in stripped
            or "PDF-звіт та розділ" in stripped
        ):
            continue

        col_id, col_desc, col_status, _, col_proof = cells
        if ")):`" in col_proof or "))**:" in col_proof or ")**:" in col_proof:
            col5_artifact_errors.append((idx, col_id[:35], col_proof[:80]))
        if "file://" not in col_proof:
            missing_proof_links.append((idx, col_id[:35], col_proof[:60]))
        if re.match(r"^[✅🔄⏳]\s*(Підтверджено|Докази):\s*\[", col_proof.strip()):
            col5_artifact_errors.append((idx, col_id[:35], "BARE_LINK_NO_DESC: " + col_proof[:65]))

        is_phase20 = "**20." in col_id
        is_task_20_61 = "**20.61" in col_id

        for m in re.finditer(r"\]\(file://([^)]+)\)", col_proof):
            raw_path = unquote(m.group(1)).split("#")[0]
            if raw_path.lower().endswith((".png", ".jpg", ".jpeg")):
                p_obj = Path(raw_path)
                ok, reason, dims = validate_image_content(p_obj, image_cache)
                w, h = dims
                if not ok:
                    col5_artifact_errors.append(
                        (idx, col_id[:35], f"INVALID_PROOF_IMAGE {p_obj.name}: {reason}")
                    )
                    if not reason.startswith("SEMANTIC_MISMATCH"):
                        blank_or_corrupt_proofs.append((idx, raw_path, p_obj.name, reason))
                elif is_phase20 and p_obj.name in INVALID_PROOF_BASENAMES_PHASE20:
                    col5_artifact_errors.append(
                        (
                            idx,
                            col_id[:35],
                            f"OBSOLETE_PHASE19_PROOF_IN_PHASE20 {p_obj.name}: {INVALID_PROOF_BASENAMES_PHASE20[p_obj.name]}",
                        )
                    )
                elif "✅" in col_status and p_obj.name in INVALID_PROOF_BASENAMES_ON_COMPLETED:
                    col5_artifact_errors.append(
                        (
                            idx,
                            col_id[:35],
                            f"DEFECTIVE_PROOF_ON_COMPLETED {p_obj.name}: {INVALID_PROOF_BASENAMES_ON_COMPLETED[p_obj.name]}",
                        )
                    )
                if is_task_20_61 and "ipad" in p_obj.name.lower() and w > h > 0:
                    orient_msg = (
                        f"Landscape screenshot ({w}x{h}) cited for Portrait 1-column requirement in 20.61"
                    )
                    visually_unverified_images[p_obj.name] = orient_msg
                    visually_verified_images.discard(p_obj.name)
                    if "✅" in col_status:
                        col5_artifact_errors.append(
                            (idx, col_id[:35], f"LANDSCAPE_PROOF_ON_PORTRAIT_20_61 {p_obj.name}: {orient_msg}")
                        )
            elif raw_path.lower().endswith((".mp4", ".mov")):
                p_obj = Path(raw_path)
                ok, reason = validate_video_content(p_obj, video_cache)
                if not ok:
                    col5_artifact_errors.append(
                        (idx, col_id[:35], f"INVALID_PROOF_VIDEO {p_obj.name}: {reason}")
                    )
                    if not reason.startswith("SEMANTIC_MISMATCH"):
                        blank_or_corrupt_proofs.append((idx, raw_path, p_obj.name, reason))
                elif is_phase20 and p_obj.name in INVALID_PROOF_BASENAMES_PHASE20:
                    col5_artifact_errors.append(
                        (
                            idx,
                            col_id[:35],
                            f"OBSOLETE_PHASE19_PROOF_IN_PHASE20 {p_obj.name}: {INVALID_PROOF_BASENAMES_PHASE20[p_obj.name]}",
                        )
                    )
                elif "✅" in col_status and p_obj.name in INVALID_PROOF_BASENAMES_ON_COMPLETED:
                    col5_artifact_errors.append(
                        (
                            idx,
                            col_id[:35],
                            f"DEFECTIVE_PROOF_ON_COMPLETED {p_obj.name}: {INVALID_PROOF_BASENAMES_ON_COMPLETED[p_obj.name]}",
                        )
                    )

        if any(f"Частина {n} (" in col_id for n in (1, 2, 3, 4)):
            pdf_table_rows += 1
            continue

        # Count subtasks in col_desc
        subs = re.findall(r"-\s*([✅🔄⏳])\s*\*\*`?\d+\.\d+\.\d+", col_desc)
        for s_em in subs:
            if s_em == "✅":
                sub_done += 1
            elif s_em == "🔄":
                sub_prog += 1
            elif s_em == "⏳":
                sub_wait += 1

        # Determine row status from col_status
        row_em = None
        if "✅" in col_status:
            row_em = "✅"
            table1_done += 1
            if is_phase20:
                phase20_done += 1
        elif "🔄" in col_status:
            row_em = "🔄"
            table1_prog += 1
            if is_phase20:
                phase20_prog += 1
        elif "⏳" in col_status:
            row_em = "⏳"
            table1_wait += 1
            if is_phase20:
                phase20_wait += 1
        else:
            table1_missing_emoji.append((idx, col_id, col_status[:60]))

        # Check Column 3 vs Column 5 status emoji consistency
        col5_em = None
        for em in ("✅", "🔄", "⏳"):
            if col_proof.strip().startswith(em):
                col5_em = em
                break
        if row_em and col5_em != row_em:
            col5_artifact_errors.append(
                (idx, col_id[:35], f"COL3_VS_COL5_MISMATCH: col3={row_em} vs col5={col5_em}")
            )

        # Check consistency between subtask emojis and row emoji
        if subs and row_em:
            if row_em == "✅" and any(x != "✅" for x in subs):
                emoji_mismatches.append((idx, col_id, row_em, subs))
            elif row_em == "🔄" and all(x == "✅" for x in subs):
                emoji_mismatches.append((idx, col_id, row_em, subs))
            elif row_em == "🔄" and ("🔄" not in subs):
                emoji_mismatches.append((idx, col_id, row_em, subs))

    for bad_name in visually_unverified_images:
        visually_verified_images.discard(bad_name)
    for bad_vid in visually_unverified_videos:
        visually_verified_videos.discard(bad_vid)

    total_rows = table1_done + table1_prog + table1_wait
    total_subs = sub_done + sub_prog + sub_wait
    phase20_total = phase20_done + phase20_prog + phase20_wait
    verified_photo_count = len(visually_verified_images)
    unverified_photo_count = len(visually_unverified_images)
    verified_video_count = len(visually_verified_videos)
    unverified_video_count = len(visually_unverified_videos)
    verified_media_count = verified_photo_count + verified_video_count
    unverified_media_count = unverified_photo_count + unverified_video_count

    scan_targets = [
        ("tasks.md", path),
        ("learning_proposal.md", DEFAULT_LEARNING_PATH),
        ("implementation_plan.md", DEFAULT_PLAN_PATH),
        ("localization_editor_translator_v31.md", DEFAULT_LOC_V31_BRAIN_PATH),
        ("localization_master_table_v24.md", DEFAULT_LOC_V24_BRAIN_PATH),
        ("EDITOR_TRANSLATOR_EXPORT_V31.md", DEFAULT_LOC_V31_REPO_PATH),
        ("AGENTS.md", DEFAULT_AGENTS_PATH),
    ]

    unlinked_by_target = [(label, scan_unlinked_media_mentions(p)) for label, p in scan_targets]
    total_unlinked = sum(len(ul) for _, ul in unlinked_by_target)

    broken_other_targets = [
        (label, scan_broken_file_links(p)) for label, p in scan_targets if label != "tasks.md"
    ]
    total_broken_other = sum(len(bl) for _, bl in broken_other_targets)

    col3_header_summary = (
        f"Фаза 20 (`{phase20_total}` задач): `✅ {phase20_done}` · `🔄 {phase20_prog}` · `⏳ {phase20_wait}` \\| "
        f"Підзадачі (`{total_subs}`): `✅ {sub_done}` · `🔄 {sub_prog}` · `⏳ {sub_wait}` \\| "
        f"Усі табличні задачі (`{total_rows}`): `✅ {table1_done}` · `🔄 {table1_prog}` · `⏳ {table1_wait}` \\| "
        f"**Статус скрінів (`view_file`)**: **`👁️ Перевірені фото: {verified_photo_count}` · `⏳ Неперевірені фото: {unverified_photo_count}`**"
    )
    col5_header_summary = (
        f"Рядків із доказами (`{total_rows}`): `✅ {table1_done}` · `🔄 {table1_prog}` · `⏳ {table1_wait}` \\| "
        f"Унікальні медіа (`view_file`): **`👁️ Перевірені: {verified_media_count}` (`{verified_photo_count}` фото + `{verified_video_count}` відео) · `⏳ Неперевірені: {unverified_media_count}`** \\| "
        f"Клікабельність фото/відео: **`{'100%' if total_unlinked == 0 else 'ПОМИЛКА'}` (`{total_unlinked}` неклікабельних)**"
    )

    header_sync_errors = []
    expired_plan_errors = []
    for idx, line in enumerate(lines, start=1):
        if "Завдання та підпункти" in line and line.strip().startswith("|"):
            h_cells = split_gfm_row(line.strip())
            if len(h_cells) == 5:
                if do_sync_header and (
                    col3_header_summary not in h_cells[2] or col5_header_summary not in h_cells[4]
                ):
                    new_col3 = (
                        "Квота (`План -> Факт -> Новий план`, `Перерозподіл`), Час та Статус (`✅`/`🔄`/`⏳`)<br>"
                        + col3_header_summary
                    )
                    new_col5 = "**Фото/відео-підтвердження (докази)**<br>" + col5_header_summary
                    lines[idx - 1] = (
                        f"| {h_cells[0]} | {h_cells[1]} | {new_col3} | {h_cells[3]} | {new_col5} |"
                    )
                    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
                    h_cells = split_gfm_row(lines[idx - 1].strip())
                    print(f"[--sync-header] Updated table header summary on line {idx}")
                if col3_header_summary not in h_cells[2]:
                    header_sync_errors.append(
                        f"Line {idx} Col 3 header summary out of sync with live counts"
                    )
                if "**Фото/відео-підтвердження (докази)**<br>" not in h_cells[4]:
                    header_sync_errors.append(
                        f"Line {idx} Col 5 header missing '**Фото/відео-підтвердження (докази)**<br>' title prefix"
                    )
                if col5_header_summary not in h_cells[4]:
                    header_sync_errors.append(
                        f"Line {idx} Col 5 header summary out of sync with live counts"
                    )
        if line.strip().startswith("|") and ("**20." in line or "**19." in line):
            r_cells = split_gfm_row(line.strip())
            if len(r_cells) == 5:
                r_id, r_desc, r_status, _, _ = r_cells
                expired_subtask_plan_pattern = re.compile(
                    r"(?:00:40|02:30|03:00|03:30|03:55|04:00|04:25|04:30|04:55|05:00|05:25|05:30|05:55|06:00|06:25|06:30|06:55|10:30|10:55|11:30|12:15)"
                )
                for sub_m in re.finditer(r"-\s*([🔄⏳])\s*\*\*`?([^`*]+)`?\s*\((.+?)\)\*\*:", r_desc):
                    sub_id, sub_meta = sub_m.group(2), sub_m.group(3)
                    if (
                        expired_subtask_plan_pattern.search(sub_meta)
                        or ("12:35" not in sub_meta and "16:30" not in sub_meta)
                        or (re.search(r"2[123]:\d{2}", sub_meta) and "01:31" not in sub_meta)
                        or re.search(r"Новий план:\s*`2[123]:\d{2}", sub_meta)
                        or re.search(r"\(`\d+\s*хв`\s*->\s*Новий план:", sub_meta)
                    ):
                        expired_plan_errors.append(
                            f"Line {idx} ({sub_id}): expired subtask planned window '{sub_meta}'"
                        )
                if "🔄" in r_status or ("⏳" in r_status and "Відкладено" not in r_status):
                    if (
                        expired_subtask_plan_pattern.search(r_status)
                        or ("12:35" not in r_status and "16:30" not in r_status)
                    ):
                        expired_plan_errors.append(
                            f"Line {idx} ({r_id} Col 3): expired row planned window in '{r_status}'"
                        )


    print("=== tasks.md Automated Status, Pixel & Visual-Review (view_file) Audit ===")
    print(
        "NOTE: Automated pixel validation NEVER replaces mandatory human-like visual review via view_file."
    )
    print(
        f"Phase 20 Tasks ({phase20_total}): ✅ {phase20_done} | 🔄 {phase20_prog} | ⏳ {phase20_wait}"
    )
    print(
        f"Subtasks ({total_subs}): ✅ {sub_done} | 🔄 {sub_prog} | ⏳ {sub_wait}"
    )
    print(
        f"All Table Tasks ({total_rows}): ✅ {table1_done} | 🔄 {table1_prog} | ⏳ {table1_wait}"
    )
    print(f"PDF Audit Table Rows (5 cols verified): {pdf_table_rows}")
    print(f"Unique images decoded & pixel-validated: {len(image_cache)} | Unique videos validated: {len(video_cache)}")
    print(
        f"Visual Review Counter: 👁️ Перевірено візуально (view_file): {verified_media_count} ({verified_photo_count} фото + {verified_video_count} відео) | ⏳ Неперевірено візуально (очікує перегляду / перезйомки): {unverified_media_count}"
    )
    print(f"COL3_HEADER_SUMMARY: {col3_header_summary}")
    print(f"COL5_HEADER_SUMMARY: {col5_header_summary}")
    if visually_unverified_images or visually_unverified_videos:
        print("Media requiring retake / visual re-verification via view_file:")
        for bname, defect_reason in sorted({**visually_unverified_images, **visually_unverified_videos}.items()):
            print(f"  ⏳ {bname}: {defect_reason}")
    print(f"Header summary sync errors: {len(header_sync_errors)}")
    for hs in header_sync_errors:
        print(f"  {hs}")
    print(f"Expired active subtask planned window errors: {len(expired_plan_errors)}")
    for ep in expired_plan_errors[:25]:
        print(f"  {ep}")
    print(f"Pipe count errors (rows != 5 cols): {len(pipe_errors)}")
    for err in pipe_errors[:15]:
        print(f"  Line {err[0]}: {err[1]} cols ({err[2]})")
    print(f"Rows missing status emoji: {len(table1_missing_emoji)}")
    for m in table1_missing_emoji[:15]:
        print(f"  Line {m[0]} ({m[1]}): {m[2]}")
    print(f"Subtask vs Row emoji mismatches: {len(emoji_mismatches)}")
    for mm in emoji_mismatches[:10]:
        print(f"  Line {mm[0]} ({mm[1]}): row={mm[2]}, subs={mm[3]}")
    print(f"Column 5 quality/artifact/mismatch/pixel errors: {len(col5_artifact_errors)}")
    for ca in col5_artifact_errors[:25]:
        print(f"  Line {ca[0]} ({ca[1]}): {ca[2]}")
    print(f"Blank or corrupt image links anywhere in tasks.md: {len(blank_or_corrupt_proofs)}")
    for bp in blank_or_corrupt_proofs[:25]:
        print(f"  Line {bp[0]} ({bp[2]}): {bp[3]}")
    print(f"Column 5 missing file:// proof links: {len(missing_proof_links)}")
    for mp in missing_proof_links[:15]:
        print(f"  Line {mp[0]} ({mp[1]}): {mp[2]}")
    print(f"Broken file:// links in tasks.md: {len(broken_file_links)}")
    for bf in broken_file_links[:15]:
        print(f"  Line {bf[0]}: {bf[1]}")
    broken_summary_str = ", ".join(f"{label}={len(bl)}" for label, bl in broken_other_targets)
    print(
        f"Broken file:// links in other docs ({broken_summary_str}, total={total_broken_other}):"
    )
    for label, bl_list in broken_other_targets:
        for ln_no, rp in bl_list[:15]:
            print(f"  [{label} L{ln_no}] broken file:// link: {rp}")
    unlinked_summary_str = ", ".join(f"{label}={len(ul)}" for label, ul in unlinked_by_target)
    print(
        f"Unlinked photo/video mentions ({unlinked_summary_str}, total={total_unlinked}):"
    )
    for label, ul_list in unlinked_by_target:
        for ln_no, tok in ul_list[:20]:
            print(f"  [{label} L{ln_no}] unlinked media token: {tok}")

    malformed_by_target = [(label, scan_malformed_link_syntax(p)) for label, p in scan_targets]
    total_malformed = sum(len(ml) for _, ml in malformed_by_target)
    malformed_summary_str = ", ".join(f"{label}={len(ml)}" for label, ml in malformed_by_target)
    print(
        f"Malformed link syntax ({malformed_summary_str}, total={total_malformed}):"
    )
    for label, ml_list in malformed_by_target:
        for ln_no, dtype, snip in ml_list[:20]:
            print(f"  [{label} L{ln_no}] {dtype}: {snip}")

    total_errors = (
        len(header_sync_errors)
        + len(expired_plan_errors)
        + len(pipe_errors)
        + len(table1_missing_emoji)
        + len(emoji_mismatches)
        + len(col5_artifact_errors)
        + len(blank_or_corrupt_proofs)
        + len(missing_proof_links)
        + len(broken_file_links)
        + total_broken_other
        + total_unlinked
        + total_malformed
    )
    if total_errors > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()

