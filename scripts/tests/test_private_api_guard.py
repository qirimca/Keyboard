#!/usr/bin/env python3
"""Adversarial regression tests for the deliberately bounded source scanner."""
import importlib.util
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

GUARD = Path(__file__).resolve().parents[1] / 'check_private_apis.py'
spec = importlib.util.spec_from_file_location('private_api_guard', GUARD)
guard = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = guard
spec.loader.exec_module(guard)


class SourceTests(unittest.TestCase):
    def test_private_literals_and_identifiers(self):
        fixtures = [
            'let c = NSClassFromString("UIKeyboardImpl")',
            'let c = UIKeyboardImpl.shared()',
            'let c = NSClassFromString(["UIKeyboard", "Impl"].joined())',
            'let c = NSClassFromString(["UIKeyboard", "Impl"].joined(separator: ""))',
            'let c = NSClassFromString("UIKeyboard" + "Impl")',
            'let c = NSClassFromString(("UI" + "Keyboard") + ("Im" + "pl"))',
            'let c = ["UI" + "Keyboard", "Impl"].joined(separator: ("" + ""))',
            'let c = "UIKeyboard" /* public-looking comment */ + "Impl"',
            r'let c = "UIKeyboard\u{49}mpl"',
            r'let c = #"UIKeyboard\#u{49}mpl"#',
            'let c = """UIKeyboardImpl"""',
            'id c = NSClassFromString(@"UIKeyboardImpl");',
            r'const char *c = "UIKeyboard\u0049mpl";',
            'let selector = "_host" + "BundleID"',
            'let selector = ["_host", "PID"].joined()',
            'let selector = "_xpcConnection"',
            'let service = NSClassFromString("PKService")',
            'let symbol = "xpc_connection_copy_bundle_id"',
            'let prefs = UserDefaults(suiteName: "com.apple." + "keyboard")',
            'let prefs = "com.apple.keyboard.preferences"',
            'let selector = "keyboardScreenReferenceBounds"',
            'let prefs = "TIPreferencesController"',
            'let prefs = "UIKeyboardPreferencesController"',
            'let host = "UIPeripheralHost"',
            'dlsym(handle, ["UIKeyboardDevice", "SupportsSplit"].joined())',
            'dlsym(handle, "UI" + "SomeUnlistedAppleSymbol")',
            'dlsym(handle, "_OBJC_CLASS_$_SomeClass")',
        ]
        for source in fixtures:
            with self.subTest(source=source):
                self.assertTrue(guard.source_findings(source))

    def test_public_apis_comments_and_public_kvc_are_allowed(self):
        fixtures = [
            '// UIKeyboardImpl\nlet c = UIInputViewController()',
            '/* UIKeyboardImpl /* _hostPID */ PKService */\nimport UIKit',
            'let c = UIKeyboardLayoutGuide()',
            'let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")',
            'let c = UIInputView(frame: .zero, inputViewStyle: .keyboard)',
            'let modes = UITextInputMode.activeInputModes',
            'let proxy: UITextDocumentProxy = textDocumentProxy',
            'var safeDocumentIdentifier: UUID { (self as AnyObject).value(forKey: "documentIdentifier") as? UUID ?? UUID() }',
            'let scale = layer.value(forKeyPath: "transform.scale")',
            'dlsym(handle, "malloc")',
            'let url = "https://example.com/a/*b*/"',
            'let value = ["UIKeyboard", "Impl"].joined(separator: "-")',
            'let prose = "Unicode: \\u{1F600}"',
            'let char: Character = "\\\""',
        ]
        for source in fixtures:
            with self.subTest(source=source):
                self.assertEqual(guard.source_findings(source), [])

    def test_multiple_findings_and_lines(self):
        self.assertIn((3, '_hostPID'), guard.source_findings('// UIKeyboardImpl\n\nlet s = "_hostPID"'))

    def test_unterminated_input_fails(self):
        for source in ['/* missing end', 'let x = "missing end']:
            with self.assertRaises(ValueError):
                guard.source_findings(source)


class CommandTests(unittest.TestCase):
    def run_guard(self, *args):
        return subprocess.run([sys.executable, str(GUARD), *map(str, args)], capture_output=True, text=True)

    def test_invalid_missing_empty_and_undecodable_inputs_fail(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for args in [(), (root / 'missing',), (root,), ('--binary', root), ('--binary', root / 'missing')]:
                with self.subTest(args=args):
                    self.assertNotEqual(self.run_guard(*args).returncode, 0)
            file = root / 'input.swift'
            for content in [b'', b'   \n', b'\xff\xfe', b'/* broken']:
                file.write_bytes(content)
                self.assertNotEqual(self.run_guard(file).returncode, 0)
            binary = root / 'empty.bin'
            binary.touch()
            self.assertNotEqual(self.run_guard('--binary', binary).returncode, 0)
            self.assertNotEqual(self.run_guard(binary).returncode, 0)

    def test_only_supported_source_extensions_are_scanned(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'README.md').write_text('UIKeyboardImpl')
            (root / 'fixture.json').write_text('"UIKeyboardImpl"')
            (root / 'public.swift').write_text('import UIKit')
            self.assertEqual(self.run_guard(root).returncode, 0)
            for extension in guard.SOURCE_SUFFIXES:
                file = root / ('bad' + extension)
                file.write_text('UIKeyboardImpl')
                self.assertEqual(self.run_guard(root).returncode, 1)
                file.unlink()

    def test_binary_executable_and_resources_are_scanned(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'actual-executable'
            file.write_bytes(b'\x00safe executable bytes\xff')
            result = self.run_guard('--binary', file)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('not proof', result.stdout)
            for encoding in ['utf-8', 'utf-16-le', 'utf-16-be']:
                file.write_bytes(b'\x00\xff\x01' + 'UIKeyboardImpl'.encode(encoding) + b'\x00')
                self.assertEqual(self.run_guard('--binary', file).returncode, 1)

    def test_read_errors_fail_closed(self):
        # A dangling source symlink provides a deterministic read error even
        # when CI runs as root (chmod-based permission tests are unreliable).
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'broken.swift').symlink_to(root / 'missing')
            self.assertEqual(self.run_guard(root).returncode, 2)


if __name__ == '__main__':
    unittest.main()
