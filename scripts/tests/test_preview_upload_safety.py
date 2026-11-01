"""Offline preview upload regression tests; no credentials or network needed."""
import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest

path = Path(__file__).resolve().parents[2] / "QTatar/Scripts/asc/upload_designed_previews.py"
spec = importlib.util.spec_from_file_location("preview_upload", path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FakeAPI:
    def __init__(self, previews=None):
        self.previews = previews or []
        self.calls = []
        self.uploads = []
        self.error = None

    def make_token(self):
        return "offline"

    def api_req(self, method, url, data=None, token=None):
        self.calls.append((method, url))
        if url.endswith("/appStoreVersionLocalizations"):
            return {"data": [{"id": locale, "attributes": {"locale": locale}} for locale in module.LOCALES]}
        if method == "GET" and url.endswith("/appPreviewSets"):
            return {"data": [{"id": kind, "attributes": {"previewType": kind}} for kind in module.PREVIEWS]}
        if method == "GET" and url.endswith("/appPreviews"):
            return {"data": self.previews}
        if method == "POST" and url == "/appPreviews":
            return {"data": {"id": "new", "attributes": {"uploadOperations": [{"fake": True}]}}}
        if method == "PATCH":
            return {"data": {"attributes": {"assetDeliveryState": {"state": "AWAITING_UPLOAD"}}}}
        raise AssertionError((method, url))

    def upload_asset_operations(self, operations, content):
        if self.error:
            raise self.error
        self.uploads.append(content)


class PreviewUploadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for folder in module.LOCALES.values():
            (self.root / folder).mkdir()
            for name in module.PREVIEWS.values():
                (self.root / folder / name).write_bytes(b"offline test video")
        self.files = module.preflight(self.root)

    def run_upload(self, api):
        with contextlib.redirect_stdout(io.StringIO()):
            module.upload_previews(api, self.files)

    def asset(self, state="COMPLETE", checksum=None):
        return {"id": "existing", "attributes": {"fileSize": self.files[0][3],
                "sourceFileChecksum": checksum or self.files[0][4],
                "assetDeliveryState": {"state": state}}}

    def test_preflight_missing_last_file_fails(self):
        self.files[-1][2].unlink()
        with self.assertRaises(FileNotFoundError):
            module.preflight(self.root)

    def test_empty_file_fails(self):
        self.files[-1][2].write_bytes(b"")
        with self.assertRaises(ValueError):
            module.preflight(self.root)

    def test_complete_matching_assets_are_read_only(self):
        api = FakeAPI([self.asset()])
        self.run_upload(api)
        self.assertTrue(all(method == "GET" for method, _ in api.calls))
        self.assertEqual(api.uploads, [])

    def test_conflicting_incomplete_duplicate_assets_never_mutate(self):
        for previews in ([self.asset(checksum="different")], [self.asset(state="PROCESSING")],
                         [self.asset(), self.asset()]):
            with self.subTest(previews=previews):
                api = FakeAPI(previews)
                with self.assertRaises(RuntimeError):
                    self.run_upload(api)
                self.assertTrue(all(method == "GET" for method, _ in api.calls))

    def test_empty_sets_upload_and_never_delete(self):
        api = FakeAPI()
        self.run_upload(api)
        self.assertEqual(len(api.uploads), 6)
        self.assertEqual(sum(method == "PATCH" for method, _ in api.calls), 6)
        self.assertNotIn("DELETE", [method for method, _ in api.calls])

    def test_changed_file_fails_before_mutation(self):
        self.files[0][2].write_bytes(b"changed")
        api = FakeAPI()
        with self.assertRaises(RuntimeError):
            self.run_upload(api)
        self.assertTrue(all(method == "GET" for method, _ in api.calls))

    def test_transport_failure_does_not_delete_or_commit(self):
        api = FakeAPI()
        api.error = ConnectionError("offline")
        with self.assertRaises(ConnectionError):
            self.run_upload(api)
        self.assertNotIn("DELETE", [method for method, _ in api.calls])
        self.assertNotIn("PATCH", [method for method, _ in api.calls])

    def test_late_remote_conflict_aborts_entire_plan(self):
        asset = self.asset(state="PROCESSING")
        class LateConflict(FakeAPI):
            def __init__(self):
                super().__init__()
                self.reads = 0

            def api_req(self, method, url, data=None, token=None):
                result = super().api_req(method, url, data, token)
                if method == "GET" and url.endswith("/appPreviews"):
                    self.reads += 1
                    if self.reads == 6:
                        return {"data": [asset]}
                return result
        api = LateConflict()
        with self.assertRaises(RuntimeError):
            self.run_upload(api)
        self.assertTrue(all(method == "GET" for method, _ in api.calls))

    def test_pagination_includes_later_conflicts(self):
        class Paged:
            def api_req(self, method, url, token=None):
                return {"data": [url], "links": {"next": "page2" if url == "page1" else None}}
        self.assertEqual(module.collection(Paged(), "page1", "fake"), ["page1", "page2"])


if __name__ == "__main__":
    unittest.main()
