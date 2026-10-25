#!/usr/bin/env python3
"""
Deterministic renderer for QırımKey App Store & social marketing templates.
Reads `marketing/templates/config.json` and `marketing/provenance.json`,
binds Crimean coast sunset photography (`marketing/templates/assets/crimea_sunset_bg.png`)
and real simulator/device screenshots into `marketing/templates/{iphone,ipad}/template.svg`,
and outputs parameterized SVGs and a verification manifest to `marketing/rendered/`.
"""

import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CONFIG_PATH = ROOT / "marketing" / "templates" / "config.json"
PROVENANCE_PATH = ROOT / "marketing" / "provenance.json"
OUT_DIR = ROOT / "marketing" / "rendered"


def render_svg(
    template_text: str,
    width: int,
    height: int,
    corner_radius: int,
    theme: dict,
    typography: dict,
    badge: str,
    title: str,
    subtitle: str,
    pills: list[str],
    screenshot_uri: str,
    crimea_bg_uri: str,
) -> str:
    center_x = width // 2

    badge_w = int(width * 0.56)
    badge_h = max(36, int(height * 0.022))
    badge_x = center_x - badge_w // 2
    badge_y = int(height * 0.028)
    badge_rx = badge_h // 2
    badge_size = max(16, int(width * 0.020))
    badge_text_y = badge_y + int(badge_h * 0.68)

    title_y = int(height * 0.082)
    subtitle_y = int(height * 0.114)
    title_size = max(32, int(width * 0.044))
    subtitle_size = max(20, int(width * 0.024))

    pill_y = int(height * 0.132)
    pill_h = max(34, int(height * 0.022))
    pill_rx = pill_h // 2
    pill_w = int(width * 0.26)
    pill_gap = int(width * 0.022)
    total_pills_w = 3 * pill_w + 2 * pill_gap
    pill1_x = center_x - total_pills_w // 2
    pill2_x = pill1_x + pill_w + pill_gap
    pill3_x = pill2_x + pill_w + pill_gap
    pill_font_size = max(15, int(width * 0.018))
    pill_text_y = pill_y + int(pill_h * 0.67)

    screen_w = int(width * 0.80)
    screen_h = int(height * 0.76)
    screen_x = (width - screen_w) // 2
    screen_y = int(height * 0.185)

    bezel = max(12, int(width * 0.012))
    frame_x = screen_x - bezel
    frame_y = screen_y - bezel
    frame_w = screen_w + bezel * 2
    frame_h = screen_h + bezel * 2
    frame_radius = corner_radius + bezel

    p1 = pills[0] if len(pills) > 0 else "QırımKey"
    p2 = pills[1] if len(pills) > 1 else "Söz teklifleri"
    p3 = pills[2] if len(pills) > 2 else "100% Oflayn"

    replacements = {
        "{{WIDTH}}": str(width),
        "{{HEIGHT}}": str(height),
        "{{BG_START}}": theme["bg_start"],
        "{{BG_END}}": theme["bg_end"],
        "{{VEIL_OPACITY}}": theme.get("veil_opacity", "0.55"),
        "{{ACCENT}}": theme["accent"],
        "{{HEADLINE_COLOR}}": theme["headline"],
        "{{SUBTITLE_COLOR}}": theme["subtitle"],
        "{{FRAME_BORDER}}": theme["frame_border"],
        "{{HEADLINE_FONT}}": typography["headline_font"],
        "{{BODY_FONT}}": typography["body_font"],
        "{{CENTER_X}}": str(center_x),
        "{{BADGE_X}}": str(badge_x),
        "{{BADGE_Y}}": str(badge_y),
        "{{BADGE_W}}": str(badge_w),
        "{{BADGE_H}}": str(badge_h),
        "{{BADGE_RX}}": str(badge_rx),
        "{{BADGE_SIZE}}": str(badge_size),
        "{{BADGE_TEXT_Y}}": str(badge_text_y),
        "{{BADGE_TEXT}}": html.escape(badge),
        "{{TITLE_Y}}": str(title_y),
        "{{SUBTITLE_Y}}": str(subtitle_y),
        "{{TITLE_SIZE}}": str(title_size),
        "{{SUBTITLE_SIZE}}": str(subtitle_size),
        "{{TITLE}}": html.escape(title),
        "{{SUBTITLE}}": html.escape(subtitle),
        "{{PILL_Y}}": str(pill_y),
        "{{PILL_W}}": str(pill_w),
        "{{PILL_H}}": str(pill_h),
        "{{PILL_RX}}": str(pill_rx),
        "{{PILL_FONT_SIZE}}": str(pill_font_size),
        "{{PILL_TEXT_Y}}": str(pill_text_y),
        "{{PILL1_X}}": str(pill1_x),
        "{{PILL1_CX}}": str(pill1_x + pill_w // 2),
        "{{PILL1_TEXT}}": html.escape(p1),
        "{{PILL2_X}}": str(pill2_x),
        "{{PILL2_CX}}": str(pill2_x + pill_w // 2),
        "{{PILL2_TEXT}}": html.escape(p2),
        "{{PILL3_X}}": str(pill3_x),
        "{{PILL3_CX}}": str(pill3_x + pill_w // 2),
        "{{PILL3_TEXT}}": html.escape(p3),
        "{{SCREEN_X}}": str(screen_x),
        "{{SCREEN_Y}}": str(screen_y),
        "{{SCREEN_W}}": str(screen_w),
        "{{SCREEN_H}}": str(screen_h),
        "{{CORNER_RADIUS}}": str(corner_radius),
        "{{FRAME_X}}": str(frame_x),
        "{{FRAME_Y}}": str(frame_y),
        "{{FRAME_W}}": str(frame_w),
        "{{FRAME_H}}": str(frame_h),
        "{{FRAME_RADIUS}}": str(frame_radius),
        "{{SCREENSHOT_URI}}": screenshot_uri,
        "{{CRIMEA_BG_URI}}": crimea_bg_uri,
    }
    out = template_text
    for k, v in replacements.items():
        out = out.replace(k, v)
    return out


def main() -> int:
    config = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
    provenance = json.loads(PROVENANCE_PATH.read_text(encoding="utf-8"))
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    bg_rel = config.get("background_asset", "marketing/templates/assets/crimea_sunset_bg.png")
    crimea_bg_uri = str((ROOT / bg_rel).resolve())

    manifest = {
        "template_version": config["template_version"],
        "background_asset": bg_rel,
        "video_storyboard_22s": config.get("video_storyboard_22s", {}),
        "rendered_files": [],
    }
    for locale, copy_map in config["copy"].items():
        for dev_key in ("iphone_6_3", "ipad_13"):
            dev_cfg = config["device_classes"][dev_key]
            template_path = ROOT / dev_cfg["template"]
            template_text = template_path.read_text(encoding="utf-8")
            subdir = "iphone-6.3-1206x2622" if dev_key == "iphone_6_3" else "ipad-13-2064x2752"
            for shot_id, copy_entry in copy_map.items():
                theme_key = "dark" if "dark" in shot_id else "light"
                shot_rel = f"AppStoreMetadata/Screenshots/{subdir}/{shot_id}.png"
                shot_abs = ROOT / shot_rel
                svg_content = render_svg(
                    template_text=template_text,
                    width=dev_cfg["width_px"],
                    height=dev_cfg["height_px"],
                    corner_radius=dev_cfg["corner_radius"],
                    theme=config["themes"][theme_key],
                    typography=config["typography"],
                    badge=copy_entry.get("badge", "QIRIMKEY"),
                    title=copy_entry["title"].strip(),
                    subtitle=copy_entry["subtitle"].strip(),
                    pills=copy_entry.get("pills", []),
                    screenshot_uri=str(shot_abs),
                    crimea_bg_uri=crimea_bg_uri,
                )
                out_subdir = OUT_DIR / locale / dev_key
                out_subdir.mkdir(parents=True, exist_ok=True)
                out_file = out_subdir / f"{shot_id}.svg"
                out_file.write_text(svg_content, encoding="utf-8")
                manifest["rendered_files"].append(
                    {
                        "locale": locale,
                        "device_class": dev_key,
                        "shot_id": shot_id,
                        "svg_path": str(out_file.relative_to(ROOT)),
                        "source_screenshot": shot_rel,
                        "source_exists": shot_abs.exists(),
                    }
                )

    manifest_path = OUT_DIR / "render_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Rendered {len(manifest['rendered_files'])} marketing SVG templates into {OUT_DIR.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
