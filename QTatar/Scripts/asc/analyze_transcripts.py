#!/usr/bin/env python3
"""Read-only: compact failure statistics from a Antigravity transcript_full.jsonl (streamed). Usage: analyze_transcripts.py <jsonl> [--users]"""
import json, sys, re, collections
p = sys.argv[1]; users = "--users" in sys.argv
types = collections.Counter(); tools = collections.Counter(); errs = collections.Counter(); first = last = None
corr = re.compile(r"(?i)\b(не так|неправильно|помилк|зависл|знову|ще раз|кіпіш|каша|чому ти|не роб|не треба|перестань|втрат|палиш|поверхнев|мало описав|ні,|нащо|зайв|виправ|проблем)")
ucount = 0; samples = []
slow = collections.Counter(); steps = 0
for line in open(p, encoding="utf-8", errors="replace"):
    try: o = json.loads(line)
    except Exception: continue
    steps += 1
    t = o.get("type"); types[t] += 1
    ts = o.get("created_at"); first = first or ts; last = ts or last
    if t == "USER_INPUT" and o.get("source") == "USER_EXPLICIT":
        c = o.get("content") or ""
        ucount += 1
        if users and corr.search(c): samples.append((ts, c[:240].replace("\n", " ")))
    for tc in o.get("tool_calls") or []:
        tools[tc.get("name")] += 1
    if o.get("status") == "ERROR":
        tn = ",".join(tc.get("name", "?") for tc in (o.get("tool_calls") or [])) or t
        errs[tn] += 1
        c = (o.get("content") or "")[:90].replace("\n", " ")
        errs["MSG:" + re.sub(r"\d+", "N", c)[:70]] += 1
print("steps", steps, "span", first, "->", last, "user_msgs", ucount)
print("types", dict(types.most_common(8)))
print("tools", dict(tools.most_common(14)))
print("errors", [(k, v) for k, v in errs.most_common(14)])
for s in samples[-25:]: print("U", s[0][:16] if s[0] else "", s[1])
