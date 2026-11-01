"""Offline regression checks; never authenticates or calls App Store Connect."""
import contextlib
import importlib.util
import io
from pathlib import Path
import unittest

path = Path(__file__).resolve().parents[2] / "QTatar/Scripts/asc/attach_build.py"
spec = importlib.util.spec_from_file_location("attach_build", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FakeAPI:
    APP_ID = "app"

    def __init__(self, state="VALID", expired=False, attached="build"):
        self.state, self.expired, self.attached = state, expired, attached
        self.calls = []
        self.version = "3.1"
        self.app = "app"

    def make_token(self):
        return "fake"

    def api_req(self, method, url, data=None, token=None):
        self.calls.append((method, url, data))
        build = {"id": "build", "type": "builds", "attributes": {
            "version": "8", "processingState": self.state, "expired": self.expired}}
        if url == "/appStoreVersions/version":
            return {"data": {"attributes": {"versionString": self.version}}}
        if url.endswith("/app"):
            return {"data": {"id": self.app}}
        if url.startswith("/builds?"):
            return {"data": [build]}
        if url == "/builds/build":
            return {"data": build}
        if method == "PATCH":
            return {}
        if url.endswith("/relationships/build"):
            return {"data": {"type": "builds", "id": self.attached}}
        raise AssertionError((method, url))


class AttachBuildTests(unittest.TestCase):
    def run_attach(self, api, **kwargs):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            result = module.attach_build(api, "8", "version", "3.1", **kwargs)
        return result, output.getvalue()

    def test_valid_build_is_read_back_after_patch(self):
        api = FakeAPI()
        result, output = self.run_attach(api)
        self.assertEqual(result, "build")
        self.assertIn("ATTACH_DONE", output)
        self.assertEqual([c[0] for c in api.calls][-2:], ["PATCH", "GET"])

    def test_invalid_and_expired_never_attach(self):
        for state, expired in [("FAILED", False), ("INVALID", False), ("VALID", True)]:
            with self.subTest(state=state, expired=expired):
                api = FakeAPI(state, expired)
                with self.assertRaises(RuntimeError):
                    self.run_attach(api)
                self.assertFalse(any(c[0] == "PATCH" for c in api.calls))

    def test_timeout_is_failure(self):
        api = FakeAPI("PROCESSING")
        now = [0]
        def sleep(seconds):
            now[0] += seconds
        with self.assertRaises(TimeoutError):
            self.run_attach(api, timeout=2, poll=1, clock=lambda: now[0], sleep=sleep)
        self.assertFalse(any(c[0] == "PATCH" for c in api.calls))

    def test_readback_mismatch_is_failure(self):
        with self.assertRaises(RuntimeError):
            self.run_attach(FakeAPI(attached="different"))

    def test_wrong_version_or_app_never_attach(self):
        for field in ("version", "app"):
            api = FakeAPI()
            setattr(api, field, "wrong")
            with self.assertRaises(ValueError):
                self.run_attach(api)
            self.assertFalse(any(c[0] == "PATCH" for c in api.calls))

    def test_build_argument_is_required_without_loading_credentials(self):
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit) as error:
            module.main([])
        self.assertEqual(error.exception.code, 2)

    def test_transport_failure_propagates(self):
        api = FakeAPI()
        def fail(*args, **kwargs):
            raise ConnectionError("offline")
        api.api_req = fail
        with self.assertRaises(ConnectionError):
            self.run_attach(api)


if __name__ == "__main__":
    unittest.main()
