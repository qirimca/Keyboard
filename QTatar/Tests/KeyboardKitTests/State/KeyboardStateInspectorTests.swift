//
//  KeyboardStateInspectorTests.swift
//  KeyboardKitTests
//
//  Created by Daniel Saidi on 2023-01-09.
//  Copyright © 2023-2024 Daniel Saidi. All rights reserved.
//

#if os(iOS) || os(tvOS)
import XCTest
import Testing

@testable import KeyboardKit

class KeyboardStateInspectorTests: XCTestCase {

    private var inspector: TestInspector!

    let bundleIds = ["com.myapp.keyboard.1", "com.myapp.keyboard.2"]

    override func setUp() {
        inspector = TestInspector()
    }

    func activeResult(for id: String) -> Bool {
        inspector.isKeyboardActive(withId: id, in: bundleIds)
    }

    func enabledResult(for id: String) -> Bool {
        inspector.isKeyboardEnabled(withId: id, in: bundleIds)
    }

    func testIsKeyboardActiveMatchesOnExactBundleId() {
        XCTAssertTrue(activeResult(for: "com.myapp.keyboard.1"))
        XCTAssertFalse(activeResult(for: "com.myapp.keyboard.2"))
    }

    func testIsKeyboardActiveMatchesOnWildcard() {
        XCTAssertTrue(activeResult(for: "com.myapp.keyboard.*"))
        XCTAssertFalse(activeResult(for: "com.myapp.anotherkeyboard.*"))
    }

    func testIsKeyboardEnabledMatchesOnExactBundleId() {
        XCTAssertTrue(enabledResult(for: "com.myapp.keyboard.1"))
        XCTAssertTrue(enabledResult(for: "com.myapp.keyboard.2"))
    }

    func testIsKeyboardEnabledMatchesOnWildcard() {
        XCTAssertTrue(enabledResult(for: "com.myapp.keyboard.*"))
        XCTAssertFalse(enabledResult(for: "com.myapp.anotherkeyboard.*"))
    }
}

private class TestInspector: KeyboardStateInspector {}

@Suite("Public keyboard observations")
struct PublicKeyboardObservationTests {
    @Test func unobservableBundleIdentifiersRemainUnknown() {
        let inspector = TestInspector()
        #expect(!inspector.canInspectKeyboardBundleIds)
        #expect(inspector.activeKeyboardBundleIds.isEmpty)
        #expect(inspector.enabledKeyboardBundleIds().isEmpty)
        #expect(inspector.keyboardActiveState(withBundleId: "crh.key.keyboard.keyboard") == .unknown)
        #expect(inspector.keyboardEnabledState(withBundleId: "crh.key.keyboard.keyboard") == .unknown)
    }

    @Test @MainActor func refreshedContextDoesNotReportVerifiedAbsence() {
        let context = KeyboardStateContext(bundleId: "crh.key.keyboard.keyboard")
        context.refresh()
        #expect(context.activeState == .unknown)
        #expect(context.enabledState == .unknown)
    }
}
#endif
