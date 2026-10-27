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
        search.tap()
        search.typeText("A Quiet Morning\n")
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
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Reader"
        attachment.lifetime = .keepAlways
        add(attachment)
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
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Largest Dynamic Type"
            attachment.lifetime = .keepAlways
            add(attachment)
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
            for index in 1...12 {
                app.typeKey(.downArrow, modifierFlags: [])
                let loaded = NSPredicate(format: "value CONTAINS %@", "Example \(index) begins")
                expectation(for: loaded, evaluatedWith: reader)
                waitForExpectations(timeout: 5)
            }
            app.typeKey(.downArrow, modifierFlags: [])
            expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: reader)
            waitForExpectations(timeout: 5)
            app.typeKey(.downArrow, modifierFlags: [])
            expectation(for: NSPredicate(format: "value CONTAINS %@", "A final page"), evaluatedWith: reader)
            waitForExpectations(timeout: 5)
            app.typeKey(.return, modifierFlags: [])
            app.typeKey(.downArrow, modifierFlags: [])
            XCTAssertTrue(
                app.staticTexts.containing(NSPredicate(format: "value == %@", "Line 2 of 2")).firstMatch.exists)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "Mac results table"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    #endif
}
