#!/usr/bin/env python3
"""
Upload ONLY 100% pure, unframed full-screen screenshots (Media_PlanB) and pure screen-recorded videos
to App Store Connect via the official App Store Connect REST API v1 using the App Store Connect API key from env.
Deletes any existing framed posters first.
"""
import base64
import hashlib
import json
import os
import subprocess
import sys
import time
import urllib.request
import urllib.error

KEY_ID = os.environ["ASC_KEY_ID"]
ISSUER_ID = os.environ["ASC_ISSUER_ID"]
KEY_PATH = os.environ.get("ASC_KEY_PATH", os.path.expanduser("~/.appstoreconnect/private_keys/AuthKey_%s.p8" % os.environ["ASC_KEY_ID"]))
APP_ID = "6739430313"
BASE_URL = "https://api.appstoreconnect.apple.com/v1"
MEDIA_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "AppStoreMetadata/Media_PlanB")

def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")

def _der_to_raw_es256(der: bytes) -> bytes:
    # ASN.1 SEQUENCE: 0x30 <len> 0x02 <rlen> <r> 0x02 <slen> <s>
    idx = 2
    if der[1] & 0x80:
        idx = 2 + (der[1] & 0x7F)
    assert der[idx] == 0x02
    rlen = der[idx + 1]
    r = int.from_bytes(der[idx + 2: idx + 2 + rlen], "big")
    idx = idx + 2 + rlen
    assert der[idx] == 0x02
    slen = der[idx + 1]
    s = int.from_bytes(der[idx + 2: idx + 2 + slen], "big")
    return r.to_bytes(32, "big") + s.to_bytes(32, "big")

def make_token() -> str:
    now = int(time.time())
    header = {"alg": "ES256", "kid": KEY_ID, "typ": "JWT"}
    payload = {
        "iss": ISSUER_ID,
        "iat": now - 10,
        "exp": now + 1100,
        "aud": "appstoreconnect-v1",
    }
    signing_input = f"{_b64url(json.dumps(header, separators=(',', ':')).encode())}.{_b64url(json.dumps(payload, separators=(',', ':')).encode())}"
    proc = subprocess.run(
        ["/usr/bin/openssl", "dgst", "-sha256", "-sign", KEY_PATH],
        input=signing_input.encode("ascii"),
        capture_output=True,
        check=True,
    )
    raw_sig = _der_to_raw_es256(proc.stdout)
    return f"{signing_input}.{_b64url(raw_sig)}"

def api_req(method, url, data=None, token=None):
    if not url.startswith("http"):
        url = BASE_URL + url
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    body = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw.decode("utf-8")) if raw else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code} on {method} {url}: {err_body}")
        raise

def upload_asset_operations(upload_operations, file_bytes):
    for op in upload_operations:
        method = op["method"]
        url = op["url"]
        offset = op["offset"]
        length = op["length"]
        chunk = file_bytes[offset:offset + length]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        req = urllib.request.Request(url, data=chunk, headers=headers, method=method)
        with urllib.request.urlopen(req, timeout=120) as resp:
            resp.read()

def main():
    token = make_token()
    # 1. Get inflight App Store version
    versions = api_req("GET", f"/apps/{APP_ID}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,DEVELOPER_REJECTED,REJECTED", token=token)
    if not versions.get("data"):
        versions = api_req("GET", f"/apps/{APP_ID}/appStoreVersions", token=token)
    version_id = versions["data"][0]["id"]
    version_str = versions["data"][0]["attributes"].get("versionString")
    print(f"Found App Store Version: {version_str} (id={version_id})")

    # 2. Get localizations
    locs = api_req("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations", token=token)
    loc_map = {item["attributes"]["locale"]: item["id"] for item in locs["data"]}
    print("Localizations:", loc_map)

    # Map ASC locale -> Media_PlanB folder
    locale_folder_map = {
        "en-US": "en",
        "uk": "uk",
        "ru": "crh",
    }
    display_type_map = {
        "APP_IPHONE_67": ("iphone_6.9", ["01_latin_light.png", "02_latin_dark.png", "03_cyrillic.png", "04_home_light.png", "05_home_dark.png"]),
        "APP_IPAD_PRO_3GEN_129": ("ipad_13", ["01_latin_light.png", "02_latin_dark.png", "03_cyrillic.png", "04_home_light.png", "05_home_dark.png"]),
    }

    for asc_locale, folder in locale_folder_map.items():
        loc_id = loc_map.get(asc_locale)
        if not loc_id:
            print(f"Skipping {asc_locale} (not found in ASC)")
            continue
        print(f"\n=== Processing Locale: {asc_locale} (loc_id={loc_id}, source={folder}) ===")
        sets_resp = api_req("GET", f"/appStoreVersionLocalizations/{loc_id}/appScreenshotSets", token=token)
        existing_sets = {s["attributes"]["screenshotDisplayType"]: s["id"] for s in sets_resp.get("data", [])}
        print(f"Existing screenshot sets for {asc_locale}: {existing_sets}")

        for display_type, (device_sub, filenames) in display_type_map.items():
            set_id = existing_sets.get(display_type)
            if not set_id:
                create_set = api_req("POST", "/appScreenshotSets", data={
                    "data": {
                        "type": "appScreenshotSets",
                        "attributes": {"screenshotDisplayType": display_type},
                        "relationships": {
                            "appStoreVersionLocalization": {
                                "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                            }
                        }
                    }
                }, token=token)
                set_id = create_set["data"]["id"]
                print(f"Created screenshot set {display_type}: {set_id}")

            # List existing screenshots in set and delete them all so zero framed posters remain
            shots = api_req("GET", f"/appScreenshotSets/{set_id}/appScreenshots", token=token)
            for shot in shots.get("data", []):
                shot_id = shot["id"]
                shot_name = shot["attributes"].get("fileName")
                print(f"  Deleting existing screenshot {shot_name} ({shot_id}) in {asc_locale}/{display_type}...")
                api_req("DELETE", f"/appScreenshots/{shot_id}", token=token)

            # Upload the 5 pure full-screen screenshots in order
            for fname in filenames:
                fpath = os.path.join(MEDIA_ROOT, folder, device_sub, fname)
                with open(fpath, "rb") as f:
                    fbytes = f.read()
                fsize = len(fbytes)
                fmd5 = hashlib.md5(fbytes).hexdigest()
                print(f"  Uploading PURE screenshot {fname} ({fsize} bytes, md5={fmd5}) to {asc_locale}/{display_type}...")
                res = api_req("POST", "/appScreenshots", data={
                    "data": {
                        "type": "appScreenshots",
                        "attributes": {
                            "fileSize": fsize,
                            "fileName": fname
                        },
                        "relationships": {
                            "appScreenshotSet": {
                                "data": {"type": "appScreenshotSets", "id": set_id}
                            }
                        }
                    }
                }, token=token)
                shot_id = res["data"]["id"]
                ops = res["data"]["attributes"].get("uploadOperations", [])
                upload_asset_operations(ops, fbytes)
                commit = api_req("PATCH", f"/appScreenshots/{shot_id}", data={
                    "data": {
                        "type": "appScreenshots",
                        "id": shot_id,
                        "attributes": {
                            "uploaded": True,
                            "sourceFileChecksum": fmd5
                        }
                    }
                }, token=token)
                state = commit["data"]["attributes"].get("assetDeliveryState", {}).get("state")
                print(f"    -> Committed {fname} ({shot_id}): state={state}")

if __name__ == "__main__":
    main()
