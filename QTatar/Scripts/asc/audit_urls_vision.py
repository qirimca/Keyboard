#!/usr/bin/env python3
"""Read-only: per-locale support/marketing/privacy URLs of version 3.1, appInfo privacy URLs, and the VISION_OS draft version state."""
import importlib.util, os
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("up", os.path.join(here, "upload_pure_screenshots_asc_api.py"))
up = importlib.util.module_from_spec(spec); spec.loader.exec_module(up)
t = up.make_token(); g = lambda u: up.api_req("GET", u, token=t)
for vid, name in (("c09b51f2-b581-454d-b153-9176d2fcc700", "IOS3.1"), ("3cc928b0-330a-402f-9a52-628eda822d73", "VISION1.0")):
    try:
        v = g(f"/appStoreVersions/{vid}")["data"]["attributes"]
        print(name, v.get("appStoreState"), v.get("releaseType"))
        try:
            b = g(f"/appStoreVersions/{vid}/build")["data"]
            print(name, "build", None if not b else (b["attributes"]["version"], b["attributes"]["processingState"]))
        except Exception as e: print(name, "build err", str(e)[:80])
        for l in g(f"/appStoreVersions/{vid}/appStoreVersionLocalizations?limit=20")["data"]:
            a = l["attributes"]
            print(name, a["locale"], "support=", a.get("supportUrl"), "mkt=", a.get("marketingUrl"), "desc_len=", len(a.get("description") or ""))
            if name.startswith("VISION"):
                sets = g(f"/appStoreVersionLocalizations/{l['id']}/appScreenshotSets")["data"]
                print(name, a["locale"], "screenshot sets", [s["attributes"]["screenshotDisplayType"] for s in sets])
    except Exception as e: print(name, "err", str(e)[:150])
infos = g(f"/apps/{up.APP_ID}/appInfos")["data"]
for i in infos:
    print("APPINFO", i["id"], i["attributes"].get("appStoreState"))
    for l in g(f"/appInfos/{i['id']}/appInfoLocalizations?limit=20")["data"]:
        print("  ", l["attributes"]["locale"], "privacy=", l["attributes"].get("privacyPolicyUrl"))
