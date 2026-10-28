#!/usr/bin/env python3
"""Submission readiness (read-only unless --fill-review): version attrs, review detail, URLs, age rating, privacy, build, encryption.
--fill-review sets App Review contact from the project profile and review notes from AppStoreMetadata/en-US/review_notes.txt."""
import importlib.util, os, sys, json
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("up", os.path.join(here, "upload_pure_screenshots_planb.py"))
up = importlib.util.module_from_spec(spec); spec.loader.exec_module(up)
t = up.make_token()
def g(u):
    try: return up.api_req("GET", u, token=t)
    except Exception as e: return {"error": str(e)[:200]}
VER = "c09b51f2-b581-454d-b153-9176d2fcc700"
v = g(f"/appStoreVersions/{VER}")
a = v["data"]["attributes"]
print("VERSION", {k: a.get(k) for k in ("versionString", "appStoreState", "copyright", "releaseType", "earliestReleaseDate")})
rd = g(f"/appStoreVersions/{VER}/appStoreReviewDetail")
d = rd.get("data")
print("REVIEW_DETAIL", None if not d else {k: (str(val)[:60] if val else val) for k, val in d["attributes"].items()})
if "--fill-review" in sys.argv:
    notes = open("/Users/love/Documents/Documents - MacBook Air - Віта/GitHub/Keyboard/AppStoreMetadata/en-US/review_notes.txt", encoding="utf-8").read().strip()
    attrs = {"contactFirstName": "El'dar", "contactLastName": "Osman", "contactEmail": "e@qirimca.org",
             "contactPhone": "+380505708576", "demoAccountRequired": False, "notes": notes}
    if d:
        r = up.api_req("PATCH", f"/appStoreReviewDetails/{d['id']}", data={"data": {"type": "appStoreReviewDetails", "id": d["id"], "attributes": attrs}}, token=t)
    else:
        r = up.api_req("POST", "/appStoreReviewDetails", data={"data": {"type": "appStoreReviewDetails", "attributes": attrs,
              "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": VER}}}}}, token=t)
    print("REVIEW_DETAIL FILLED:", {k: (str(val)[:40]) for k, val in r["data"]["attributes"].items() if k.startswith("contact") or k == "demoAccountRequired"}, "notes_len", len(notes))
b = g(f"/appStoreVersions/{VER}/build")
print("BUILD", None if not b.get("data") else b["data"]["attributes"].get("version"))
for l in g(f"/appStoreVersions/{VER}/appStoreVersionLocalizations?limit=50")["data"]:
    at = l["attributes"]
    if at["locale"] in ("en-US", "uk", "ru", "tr"):
        print("LOC", at["locale"], "support:", at.get("supportUrl"), "| marketing:", at.get("marketingUrl"), "| desc", len(at.get("description") or ""), "kw", len(at.get("keywords") or ""))
for info in g(f"/apps/{up.APP_ID}/appInfos")["data"]:
    st = info["attributes"].get("appStoreState")
    if st == "READY_FOR_SALE": continue
    ar = g(f"/appInfos/{info['id']}/ageRatingDeclaration")
    print("APPINFO", st, "ageRating:", None if not ar.get("data") else ar["data"]["attributes"])
    for il in g(f"/appInfos/{info['id']}/appInfoLocalizations?limit=50")["data"]:
        if il["attributes"]["locale"] in ("en-US", "uk", "ru", "tr"):
            print("  INFO_LOC", il["attributes"]["locale"], "privacy:", il["attributes"].get("privacyPolicyUrl"))
app = g(f"/apps/{up.APP_ID}")
print("APP", {k: app["data"]["attributes"].get(k) for k in ("name", "primaryLocale", "contentRightsDeclaration", "isOrEverWasMadeForKids")} if "data" in app else app)
