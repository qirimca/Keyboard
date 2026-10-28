#!/usr/bin/env python3
"""Wait until build 3.1 (5) is VALID in App Store Connect, then attach it to the iOS 3.1 version. Never submits for review."""
import importlib.util, os, sys, time
here = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("up", os.path.join(here, "upload_pure_screenshots_planb.py"))
up = importlib.util.module_from_spec(spec); spec.loader.exec_module(up)
VER = "c09b51f2-b581-454d-b153-9176d2fcc700"
want = sys.argv[1] if len(sys.argv) > 1 else "5"
deadline = time.time() + 60 * 40
last = None
while time.time() < deadline:
    t = up.make_token()
    r = up.api_req("GET", f"/builds?filter[app]={up.APP_ID}&filter[preReleaseVersion.version]=3.1&sort=-uploadedDate&limit=5", token=t)
    hit = [b for b in r["data"] if b["attributes"].get("version") == want]
    if hit:
        a = hit[0]["attributes"]
        state = (a.get("processingState"), a.get("expired"), a.get("usesNonExemptEncryption"))
        if state != last:
            print(time.strftime("%H:%M:%S"), "build", want, "state", state, flush=True); last = state
        if a.get("processingState") == "VALID" and not a.get("expired"):
            bid = hit[0]["id"]
            if a.get("usesNonExemptEncryption") is None:
                try:
                    up.api_req("PATCH", f"/builds/{bid}", data={"data": {"type": "builds", "id": bid, "attributes": {"usesNonExemptEncryption": False}}}, token=t)
                    print("export compliance set: usesNonExemptEncryption=false", flush=True)
                except Exception as e:
                    print("compliance patch skipped:", str(e)[:120], flush=True)
            up.api_req("PATCH", f"/appStoreVersions/{VER}/relationships/build", data={"data": {"type": "builds", "id": bid}}, token=t)
            print("ATTACHED build", want, "to version 3.1", flush=True)
            break
        if a.get("processingState") in ("FAILED", "INVALID"):
            print("BUILD PROCESSING FAILED", flush=True); break
    else:
        if last != "not-listed":
            print(time.strftime("%H:%M:%S"), "build not listed yet", flush=True); last = "not-listed"
    time.sleep(30)
print("ATTACH_DONE", flush=True)
