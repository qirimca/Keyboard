#!/usr/bin/env python3
"""Download a small Crimean Tatar text sample from crh.wikipedia.org."""

from __future__ import annotations

import argparse
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

DEFAULT_OUTPUT = Path(__file__).resolve().parent / "corpus" / "crh_wikipedia_sample.txt"
USER_AGENT = "QirimKeyCorpusBuilder/1.0 (keyboard research)"


def fetch_json(url: str) -> dict:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_random_articles(batch_size: int, batches: int) -> list[str]:
    texts: list[str] = []
    for _ in range(batches):
        params = urllib.parse.urlencode(
            {
                "action": "query",
                "format": "json",
                "prop": "extracts",
                "explaintext": "1",
                "generator": "random",
                "grnnamespace": "0",
                "grnlimit": str(batch_size),
            }
        )
        payload = fetch_json(f"https://crh.wikipedia.org/w/api.php?{params}")
        pages = payload.get("query", {}).get("pages", {})
        for page in pages.values():
            extract = (page.get("extract") or "").strip()
            if len(extract) > 40:
                texts.append(extract)
        time.sleep(1.0)
    return texts


def main() -> None:
    parser = argparse.ArgumentParser(description="Fetch Crimean Tatar Wikipedia sample")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--batch-size", type=int, default=20)
    parser.add_argument("--batches", type=int, default=5)
    args = parser.parse_args()

    articles = fetch_random_articles(args.batch_size, args.batches)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n\n".join(articles), encoding="utf-8")
    print(f"Saved {len(articles)} articles to {args.output}")


if __name__ == "__main__":
    main()
