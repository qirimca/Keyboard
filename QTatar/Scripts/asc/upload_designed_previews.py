#!/usr/bin/env python3
"""Add missing designed previews without deleting or replacing remote assets.

Existing sets must be empty or contain one checksum-identical COMPLETE preview.
Conflicts require separate review; this script never deletes previews.
"""
import hashlib
import os
from pathlib import Path
import sys

MEDIA_ROOT = Path(__file__).resolve().parents[3] / "AppStoreMetadata/Media_Designed"
VERSION_ID = "c09b51f2-b581-454d-b153-9176d2fcc700"
LOCALES = {"en-US": "en", "uk": "uk", "ru": "crh"}
PREVIEWS = {
    "IPHONE_67": "AppPreview_Designed_iPhone_6_9.mp4",
    "IPAD_PRO_3GEN_129": "AppPreview_Designed_iPad_13.mp4",
}


def file_identity(path):
    digest = hashlib.md5()
    size = 0
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
            size += len(chunk)
    if not size:
        raise ValueError(f"Empty preview: {path}")
    return size, digest.hexdigest()


def preflight(root):
    """Read every intended file before authentication or API mutations."""
    files = []
    for locale, folder in LOCALES.items():
        for preview_type, name in PREVIEWS.items():
            path = Path(root) / folder / name
            if not path.exists():
                path = Path(root) / name
            size, checksum = file_identity(path)
            files.append((locale, preview_type, path, size, checksum))
    return files


def collection(api, url, token):
    items = []
    seen = set()
    while url:
        if url in seen:
            raise RuntimeError("Repeated pagination URL")
        seen.add(url)
        response = api.api_req("GET", url, token=token)
        items.extend(response["data"])
        url = response.get("links", {}).get("next")
    return items


def matches(previews, size, checksum):
    if not previews:
        return False
    if len(previews) == 1:
        attributes = previews[0]["attributes"]
        if (attributes.get("assetDeliveryState", {}).get("state") == "COMPLETE"
                and attributes.get("sourceFileChecksum", "").lower() == checksum
                and attributes.get("fileSize") == size):
            return True
    raise RuntimeError("Existing preview differs, is incomplete, or has duplicates; review it separately")


def upload_previews(api, files, version_id=VERSION_ID):
    token = api.make_token()
    localizations = collection(api, f"/appStoreVersions/{version_id}/appStoreVersionLocalizations", token)
    loc_map = {item["attributes"]["locale"]: item["id"] for item in localizations}
    missing = set(LOCALES) - loc_map.keys()
    if missing:
        raise RuntimeError(f"Missing localizations: {sorted(missing)}")
    # Inspect the entire remote plan before creating any set or asset.
    plan = []
    for locale, preview_type, path, size, checksum in files:
        loc_id = loc_map[locale]
        sets = collection(api, f"/appStoreVersionLocalizations/{loc_id}/appPreviewSets", token)
        sets = [item for item in sets if item["attributes"]["previewType"] == preview_type]
        if len(sets) > 1:
            raise RuntimeError(f"Duplicate preview sets: {locale}/{preview_type}")
        set_id = sets[0]["id"] if sets else None
        previews = collection(api, f"/appPreviewSets/{set_id}/appPreviews", token) if set_id else []
        if matches(previews, size, checksum):
            print(f"SKIP COMPLETE: {locale}/{preview_type}")
        else:
            plan.append((loc_id, preview_type, path, size, checksum, set_id))

    for loc_id, preview_type, path, size, checksum, set_id in plan:
        content = path.read_bytes()
        if len(content) != size or hashlib.md5(content).hexdigest() != checksum:
            raise RuntimeError(f"Preview changed after preflight: {path}")
        if set_id:
            # Catch remote edits since planning; never overwrite a concurrent upload.
            previews = collection(api, f"/appPreviewSets/{set_id}/appPreviews", token)
            if matches(previews, size, checksum):
                continue
        else:
            result = api.api_req("POST", "/appPreviewSets", data={"data": {
                "type": "appPreviewSets", "attributes": {"previewType": preview_type},
                "relationships": {"appStoreVersionLocalization": {
                    "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}}}}, token=token)
            set_id = result["data"]["id"]
        result = api.api_req("POST", "/appPreviews", data={"data": {
            "type": "appPreviews", "attributes": {
                "fileSize": size, "fileName": path.name, "mimeType": "video/mp4",
                "previewFrameTimeCode": "00:00:05:00"},
            "relationships": {"appPreviewSet": {"data": {"type": "appPreviewSets", "id": set_id}}}}}, token=token)
        preview_id = result["data"]["id"]
        operations = result["data"]["attributes"].get("uploadOperations")
        if not operations:
            raise RuntimeError(f"Missing upload operations for {preview_id}; remote reservation retained")
        api.upload_asset_operations(operations, content)
        result = api.api_req("PATCH", f"/appPreviews/{preview_id}", data={"data": {
            "type": "appPreviews", "id": preview_id,
            "attributes": {"uploaded": True, "sourceFileChecksum": checksum}}}, token=token)
        state = result["data"]["attributes"].get("assetDeliveryState", {}).get("state")
        if state in ("FAILED", "ERROR"):
            raise RuntimeError(f"Preview processing failed: {preview_id}: {state}")
        print(f"Uploaded {path.name}: {preview_id}, processing state={state}; verify COMPLETE before release")


def main():
    files = preflight(MEDIA_ROOT)
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import upload_pure_screenshots_planb as asc
    upload_previews(asc, files)


if __name__ == "__main__":
    main()
