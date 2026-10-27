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
        #if os(macOS)
            app.buttons["Next Line"].click()
        #else
            app.buttons["Next Line"].tap()
        #endif
        XCTAssertTrue(
            app.staticTexts.containing(
                NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Line 2 of", "Line 2 of")
            ).firstMatch.exists)
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
            for _ in 0..<6 where !app.buttons["Next Line"].isHittable { app.swipeUp() }
            XCTAssertTrue(app.buttons["Next Line"].isHittable)
        }
    #endif

    #if os(macOS)
        @MainActor func testBrowsingTableKeepsKeyboardFocus() {
            let app = launch()
            search(app)
            let reader = app.textViews["lyricReader"]
            XCTAssertTrue(reader.waitForExistence(timeout: 5))
            app.typeKey("m", modifierFlags: [.command, .option])
            let table = app.tables["matchesTable"]
            XCTAssertTrue(table.waitForExistence(timeout: 5))
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
            app.typeKey(.downArrow, modifierFlags: [])
            // SwiftUI exposes static text as a label or value depending on the macOS version.
            let secondLine = app.staticTexts.containing(
                NSPredicate(format: "label == %@ OR value == %@", "Line 2 of 2", "Line 2 of 2")
            ).firstMatch
            XCTAssertTrue(secondLine.waitForExistence(timeout: 5), app.debugDescription)
        }
    #endif
}
