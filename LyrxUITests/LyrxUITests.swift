import XCTest

/// End-to-end checks use original fixture text and isolated preferences, without network access.
final class LyrxUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    @MainActor private func launch(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    @MainActor private func search(_ app: XCUIApplication) {
        let search = app.textFields["searchField"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        // The fixture accepts any query; a short input still exercises typing and Return.
        #if os(macOS)
            app.typeKey("f", modifierFlags: .command)
            app.typeText("x\n")
        #else
            search.tap()
            search.typeText("x\n")
        #endif
    }

    @MainActor func testSearchAndLineNavigation() {
        let app = launch()
        search(app)
        let reader = app.textViews["lyricReader"]
        XCTAssertTrue(reader.waitForExistence(timeout: 5))
        XCTAssertTrue((reader.value as? String)?.contains("Morning light across the room") == true)
        XCTAssertFalse(app.buttons["Next Line"].exists)
        XCTAssertFalse(app.staticTexts["linePosition"].exists)
        #if os(macOS)
            let originalText = reader.value as? String
            // The menu shortcut changes the real preference without opening another window.
            app.typeKey("n", modifierFlags: [.command, .shift])
            XCTAssertTrue(app.buttons["Next Line"].waitForExistence(timeout: 3))
            app.buttons["Next Line"].click()
            XCTAssertTrue(
                app.staticTexts.containing(
                    NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Line 2 of", "Line 2 of")
                ).firstMatch.exists)
            XCTAssertEqual(reader.value as? String, originalText)
            app.typeKey("n", modifierFlags: [.command, .shift])
            XCTAssertFalse(app.buttons["Next Line"].exists)
            XCTAssertFalse(app.staticTexts["linePosition"].exists)
        #else
            XCTAssertEqual(app.buttons["matchesDisclosure"].value as? String, "Collapsed")
        #endif
    }

    #if os(iOS)
        @MainActor func testProviderProtectionAndPlatformCopy() {
            let app = launch()
            app.buttons["Settings"].tap()
            let primary = app.switches["LRCLIB"]
            XCTAssertTrue(primary.waitForExistence(timeout: 5))
            XCTAssertFalse(primary.isEnabled)
            // SwiftUI exposes the whole labeled row as the switch; activate the actual trailing control.
            app.switches["lyrics.ovh"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            XCTAssertTrue(primary.isEnabled)
            primary.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
            XCTAssertFalse(app.switches["lyrics.ovh"].isEnabled)
        }

        @MainActor func testLargestTextKeepsReadingControlsReachable() {
            let app = launch(largeText: true)
            search(app)
            let reader = app.textViews["lyricReader"]
            XCTAssertTrue(reader.waitForExistence(timeout: 5))
            XCTAssertGreaterThanOrEqual(reader.frame.height, 200)
            let matches = app.buttons["matchesDisclosure"]
            for _ in 0..<6 where !matches.isHittable { app.swipeUp() }
            XCTAssertTrue(matches.isHittable)
        }
    #endif

    #if os(macOS)
        @MainActor func testBrowsingTableKeepsKeyboardFocus() {
            let app = launch()
            search(app)
            let reader = app.textViews["lyricReader"]
            XCTAssertTrue(reader.waitForExistence(timeout: 5))
            let table = app.tables["matchesTable"]
            XCTAssertTrue(table.waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["matchesDisclosure"].exists)
            // Repeated focus commands must keep the always-visible table open.
            app.typeKey("m", modifierFlags: [.command, .option])
            app.typeKey("m", modifierFlags: [.command, .option])
            XCTAssertTrue((reader.value as? String)?.contains("Morning light across the room") == true)
            // Use application-level key events: targeting the table would conceal a focus jump.
            app.typeKey(.downArrow, modifierFlags: [])
            expectation(for: NSPredicate(format: "value CONTAINS %@", "Example 1 begins"), evaluatedWith: reader)
            waitForExpectations(timeout: 3)
            // One input batch crosses the scroll boundary; only its distinct outcome needs a wait.
            app.typeText(String(repeating: XCUIKeyboardKey.downArrow.rawValue, count: 13))
            expectation(for: NSPredicate(format: "value CONTAINS %@", "A final page"), evaluatedWith: reader)
            waitForExpectations(timeout: 3)
            app.typeKey(.upArrow, modifierFlags: [])
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: reader)
            waitForExpectations(timeout: 3)
            app.typeKey(.downArrow, modifierFlags: [])
            expectation(for: NSPredicate(format: "value CONTAINS %@", "A final page"), evaluatedWith: reader)
            waitForExpectations(timeout: 3)
            app.typeKey(.return, modifierFlags: [])
            // If Return leaves focus in the table, Up selects the preceding instrumental
            // and removes the reader. Check table exit independently of native read-only
            // caret behavior; the smoke test covers Lyrx's Next Line action.
            app.typeKey(.upArrow, modifierFlags: [])
            XCTAssertTrue(reader.exists)
            XCTAssertTrue((reader.value as? String)?.contains("A final page") == true)
        }
    #endif
}
