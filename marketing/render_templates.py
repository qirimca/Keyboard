#!/usr/bin/env python3
"""Deterministic SVG marketing template renderer and provenance verifier for QırımKey."""

from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def render_single(
    config: dict,
    repo_root: Path,
    screenshot_path: str,
    title: str,
    subtitle: str,
    locale: str,
    theme: str,
    device_class: str,
    output_path: Path,
) -> dict:
    dev = config["device_classes"][device_class]
    pal = config["themes"][theme]
    typo = config["typography"]
    template_path = repo_root / dev["template"]
    svg = template_path.read_text(encoding="utf-8")

    replacements = {
        "{{WIDTH}}": str(dev["width_px"]),
        "{{HEIGHT}}": str(dev["height_px"]),
        "{{CORNER_RADIUS}}": str(dev["corner_radius"]),
        "{{BG_START}}": pal["bg_start"],
        "{{BG_END}}": pal["bg_end"],
        "{{ACCENT}}": pal["accent"],
        "{{HEADLINE_FONT}}": html.escape(typo["headline_font"], quote=True),
        "{{BODY_FONT}}": html.escape(typo["body_font"], quote=True),
        "{{HEADLINE_COLOR}}": pal["headline"],
        "{{SUBTITLE_COLOR}}": pal["subtitle"],
        "{{FRAME_BORDER}}": pal["frame_border"],
        "{{TITLE}}": html.escape(title),
        "{{SUBTITLE}}": html.escape(subtitle),
        "{{SCREENSHOT_HREF}}": html.escape(screenshot_path, quote=True),
    }
    for k, v in replacements.items():
        svg = svg.replace(k, v)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(svg, encoding="utf-8")

    shot_file = repo_root / screenshot_path
    return {
        "output_svg": str(output_path.relative_to(repo_root)),
        "output_sha256": sha256_file(output_path),
        "source_screenshot": screenshot_path,
        "source_exists": shot_file.is_file(),
        "source_sha256": sha256_file(shot_file) if shot_file.is_file() else None,
        "locale": locale,
        "theme": theme,
        "device_class": device_class,
        "width_px": dev["width_px"],
        "height_px": dev["height_px"],
        "template_version": config["template_version"],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        default="marketing/templates/config.json",
        help="Path to template configuration JSON",
    )
    parser.add_argument(
        "--output-dir",
        default="marketing/rendered",
        help="Directory for rendered SVG compositions and manifest",
    )
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    config_path = repo_root / args.config
    config = json.loads(config_path.read_text(encoding="utf-8"))
    out_dir = repo_root / args.output_dir

    shots = [
        ("01_latin_light", "light", "01_latin_light.png"),
        ("02_latin_dark", "dark", "02_latin_dark.png"),
        ("03_cyrillic", "light", "03_cyrillic.png"),
        ("04_home_light", "light", "04_home_light.png"),
        ("05_home_dark", "dark", "05_home_dark.png"),
    ]
    targets = [
        ("iphone_6_3", "AppStoreMetadata/Screenshots/iphone-6.3-1206x2622"),
        ("ipad_13", "AppStoreMetadata/Screenshots/ipad-13-2064x2752"),
    ]

    records = []
    for locale, copy_map in config["copy"].items():
        for device_class, shot_dir in targets:
            for key, theme, filename in shots:
                entry = copy_map[key]
                rel_shot = f"{shot_dir}/{filename}"
                out_svg = out_dir / locale / device_class / f"{key}.svg"
                rec = render_single(
                    config=config,
                    repo_root=repo_root,
                    screenshot_path=rel_shot,
                    title=entry["title"],
                    subtitle=entry["subtitle"],
                    locale=locale,
                    theme=theme,
                    device_class=device_class,
                    output_path=out_svg,
                )
                records.append(rec)

    manifest_path = out_dir / "render_manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "template_version": config["template_version"],
                "rendered_count": len(records),
                "outputs": records,
            },
            indent=2,
            ensure_ascii=False,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"OK: rendered {len(records)} marketing SVG templates -> {manifest_path.relative_to(repo_root)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
