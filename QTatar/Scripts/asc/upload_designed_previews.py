#!/usr/bin/env python3
"""
Upload ONLY 1 clean copy of AppPreview_PureScreen_iPhone_6_9.mp4 (IPHONE_67)
and 1 clean copy of AppPreview_PureScreen_iPad_13.mp4 (IPAD_PRO_3GEN_129)
to en-US, uk, and ru in App Store Connect via REST API v1, removing any old/duplicate previews.
"""
import hashlib
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import upload_pure_screenshots_planb as asc

MEDIA_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "..", "AppStoreMetadata/Media_Designed")

def main():
    token = asc.make_token()
    version_id = "c09b51f2-b581-454d-b153-9176d2fcc700"
    locs = asc.api_req("GET", f"/appStoreVersions/{version_id}/appStoreVersionLocalizations", token=token)
    loc_map = {item["attributes"]["locale"]: item["id"] for item in locs["data"]}

    locale_folder_map = {
        "en-US": "en",
        "uk": "uk",
        "ru": "crh",
    }
    preview_type_map = {
        "IPHONE_67": ("iphone_6.9", "AppPreview_Designed_iPhone_6_9.mp4"),
        "IPAD_PRO_3GEN_129": ("ipad_13", "AppPreview_Designed_iPad_13.mp4"),
    }

    for asc_locale, folder in locale_folder_map.items():
        loc_id = loc_map.get(asc_locale)
        if not loc_id:
            continue
        print(f"\n=== Processing Previews for {asc_locale} ({loc_id}) ===")
        psets_resp = asc.api_req("GET", f"/appStoreVersionLocalizations/{loc_id}/appPreviewSets", token=token)
        existing_psets = {p["attributes"]["previewType"]: p["id"] for p in psets_resp.get("data", [])}

        for preview_type, (device_sub, fname) in preview_type_map.items():
            pset_id = existing_psets.get(preview_type)
            if not pset_id:
                create_pset = asc.api_req("POST", "/appPreviewSets", data={
                    "data": {
                        "type": "appPreviewSets",
                        "attributes": {"previewType": preview_type},
                        "relationships": {
                            "appStoreVersionLocalization": {
                                "data": {"type": "appStoreVersionLocalizations", "id": loc_id}
                            }
                        }
                    }
                }, token=token)
                pset_id = create_pset["data"]["id"]
                print(f"Created preview set {preview_type}: {pset_id}")

            prevs = asc.api_req("GET", f"/appPreviewSets/{pset_id}/appPreviews", token=token)
            for p in prevs.get("data", []):
                pid = p["id"]
                pname = p["attributes"].get("fileName")
                print(f"  Deleting existing preview {pname} ({pid}) in {asc_locale}/{preview_type}...")
                asc.api_req("DELETE", f"/appPreviews/{pid}", token=token)

            fpath = os.path.join(MEDIA_ROOT, folder, fname)
            if not os.path.exists(fpath):
                fpath = os.path.join(MEDIA_ROOT, fname)
            with open(fpath, "rb") as f:
                fbytes = f.read()
            fsize = len(fbytes)
            fmd5 = hashlib.md5(fbytes).hexdigest()
            print(f"  Uploading PURE screen-recorded preview {fname} ({fsize} bytes, md5={fmd5}) to {asc_locale}/{preview_type}...")
            res = asc.api_req("POST", "/appPreviews", data={
                "data": {
                    "type": "appPreviews",
                    "attributes": {
                        "fileSize": fsize,
                        "fileName": fname,
                        "mimeType": "video/mp4",
                        "previewFrameTimeCode": "00:00:05:00"
                    },
                    "relationships": {
                        "appPreviewSet": {
                            "data": {"type": "appPreviewSets", "id": pset_id}
                        }
                    }
                }
            }, token=token)
            pid = res["data"]["id"]
            ops = res["data"]["attributes"].get("uploadOperations", [])
            asc.upload_asset_operations(ops, fbytes)
            commit = asc.api_req("PATCH", f"/appPreviews/{pid}", data={
                "data": {
                    "type": "appPreviews",
                    "id": pid,
                    "attributes": {
                        "uploaded": True,
                        "sourceFileChecksum": fmd5
                    }
                }
            }, token=token)
            state = commit["data"]["attributes"].get("assetDeliveryState", {}).get("state")
            print(f"    -> Committed {fname} ({pid}): state={state}")

if __name__ == "__main__":
    main()
