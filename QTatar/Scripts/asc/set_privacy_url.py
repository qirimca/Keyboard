#!/usr/bin/env python3
"""Set privacyPolicyUrl on the DRAFT (PREPARE_FOR_SUBMISSION) appInfo localizations only; backs up previous values."""
import importlib.util, os, json
spec = importlib.util.spec_from_file_location("up", os.path.join(os.path.dirname(os.path.abspath(__file__)), "upload_pure_screenshots_asc_api.py"))
up = importlib.util.module_from_spec(spec); spec.loader.exec_module(up)
URL = "https://github.com/qirimca/Keyboard/blob/main/PRIVACY.md"
t = up.make_token(); g = lambda u: up.api_req("GET", u, token=t)
infos = [i for i in g(f"/apps/{up.APP_ID}/appInfos")["data"] if i["attributes"].get("appStoreState") == "PREPARE_FOR_SUBMISSION"]
assert len(infos) == 1, infos
bk = {}
for l in g(f"/appInfos/{infos[0]['id']}/appInfoLocalizations?limit=50")["data"]:
    loc = l["attributes"]["locale"]; bk[loc] = l["attributes"].get("privacyPolicyUrl")
    if bk[loc] == URL: print(loc, "already"); continue
    up.api_req("PATCH", f"/appInfoLocalizations/{l['id']}", data={"data": {"type": "appInfoLocalizations", "id": l["id"], "attributes": {"privacyPolicyUrl": URL}}}, token=t)
    print(loc, "set")
p = os.path.join(os.path.dirname(os.path.abspath(__file__)), "asc_backup_privacy_urls.json")
if not os.path.exists(p): json.dump(bk, open(p, "w"), indent=1)
print("PRIVACY_DONE")
