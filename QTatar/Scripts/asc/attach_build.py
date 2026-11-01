#!/usr/bin/env python3
"""Attach an explicitly selected VALID build; never upload or submit for review."""
import argparse
import importlib.util
from pathlib import Path
import sys
import time
from urllib.parse import urlencode

VERSION_ID = "c09b51f2-b581-454d-b153-9176d2fcc700"


def attach_build(api, build_number, version_id, version, timeout=2400, poll=30,
                 clock=time.monotonic, sleep=time.sleep):
    token = api.make_token()
    target = api.api_req("GET", f"/appStoreVersions/{version_id}", token=token)["data"]
    if target["attributes"].get("versionString") != version:
        raise ValueError("Target App Store version does not match --version")
    app = api.api_req("GET", f"/appStoreVersions/{version_id}/app", token=token)["data"]
    if app["id"] != api.APP_ID:
        raise ValueError("Target App Store version belongs to a different app")
    query = urlencode({
        "filter[app]": api.APP_ID,
        "filter[preReleaseVersion.version]": version,
        "filter[version]": build_number,
        "limit": 200,
    })
    deadline = clock() + timeout
    while clock() < deadline:
        token = api.make_token()
        url = f"/builds?{query}"
        matches = []
        while url:
            response = api.api_req("GET", url, token=token)
            matches.extend(b for b in response["data"]
                           if b["attributes"].get("version") == build_number)
            url = response.get("links", {}).get("next")
        if len(matches) > 1:
            raise ValueError("Multiple matching builds; refusing an ambiguous attachment")
        if matches:
            build = matches[0]
            # Re-read the selected build before mutating the version relationship.
            build = api.api_req("GET", f"/builds/{build['id']}", token=token)["data"]
            attributes = build["attributes"]
            state = attributes.get("processingState")
            if attributes.get("expired") or state in ("FAILED", "INVALID"):
                raise RuntimeError(f"Build {build_number} is expired or {state}")
            if state == "VALID":
                relationship = f"/appStoreVersions/{version_id}/relationships/build"
                expected = {"type": "builds", "id": build["id"]}
                api.api_req("PATCH", relationship, data={"data": expected}, token=token)
                actual = api.api_req("GET", relationship, token=token).get("data")
                if actual is None or actual.get("id") != build["id"] or actual.get("type") != "builds":
                    raise RuntimeError("Build attachment could not be verified")
                print(f"ATTACH_DONE build={build_number} version={version}", flush=True)
                return build["id"]
        remaining = deadline - clock()
        if remaining > 0:
            sleep(min(poll, remaining))
    raise TimeoutError(f"Build {build_number} did not become VALID before timeout")


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build", required=True, help="Explicit build number")
    parser.add_argument("--version", default="3.1")
    parser.add_argument("--version-id", default=VERSION_ID)
    parser.add_argument("--timeout", type=float, default=2400)
    args = parser.parse_args(argv)
    if args.timeout <= 0:
        parser.error("--timeout must be positive")
    try:
        path = Path(__file__).with_name("upload_pure_screenshots_planb.py")
        spec = importlib.util.spec_from_file_location("asc_transport", path)
        api = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(api)
        attach_build(api, args.build, args.version_id, args.version, args.timeout)
    except Exception as error:
        print(f"ATTACH_FAILED: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
