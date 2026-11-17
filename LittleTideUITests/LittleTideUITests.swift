import XCTest

/// Drives the real app UI in DEBUG demo mode: real captured NOAA responses for
/// Nov 15–18 2026 and a fixed clock of 2026-11-16 10:20 PST.
final class LittleTideUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ scenario: String, _ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-LTDemo", scenario] + extra
        app.launch()
        return app
    }

    /// Any element whose label contains `text` (labels use U+202F before AM/PM).
    private func element(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    private func byID(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFirstLaunchSearchAndChooseCoast() {
        let app = launch("onboarding")
        XCTAssertTrue(app.staticTexts["A little window into your coast."].waitForExistence(timeout: 5))
        snapshot(app, "01-onboarding")
        app.buttons["chooseCoast"].tap()

        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Featured coasts"].exists || app.otherElements["Featured coasts"].exists)
        snapshot(app, "02-search-featured")

        search.tap()
        search.typeText("zzqx beach")
        XCTAssertTrue(app.staticTexts["No station matches “zzqx beach”"].waitForExistence(timeout: 5))
        snapshot(app, "03-search-no-match")

        search.buttons["Clear text"].tap()
        search.typeText("santa monica")
        let row = app.buttons["station-9410840"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        snapshot(app, "04-search-results")
        row.tap()

        XCTAssertTrue(element(app, containing: "Santa Monica").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, containing: "High tide at 1:04").waitForExistence(timeout: 5))
    }

    func testSwitchCoastAndBackFromRecents() {
        let app = launch("curve")
        XCTAssertTrue(element(app, containing: "High tide at 1:04").waitForExistence(timeout: 5))
        app.buttons["changeCoast"].tap()
        XCTAssertTrue(app.buttons["currentStation-9410840"].waitForExistence(timeout: 5))
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("king harbor")
        let kingHarbor = app.buttons["station-9410738"]
        XCTAssertTrue(kingHarbor.waitForExistence(timeout: 5))
        kingHarbor.tap()
        XCTAssertTrue(element(app, containing: "King Harbor").waitForExistence(timeout: 5))

        app.buttons["changeCoast"].tap()
        XCTAssertTrue(app.buttons["currentStation-9410738"].waitForExistence(timeout: 5))
        let recent = app.buttons["station-9410840"]
        XCTAssertTrue(recent.waitForExistence(timeout: 5), "the previous coast is offered as a recent coast")
        snapshot(app, "05-search-your-coasts")
        recent.tap()
        XCTAssertTrue(element(app, containing: "High tide at 1:04").waitForExistence(timeout: 5))
    }

    func testCurveScrubAndReturnToNow() {
        let app = launch("curve")
        XCTAssertTrue(element(app, containing: "High tide at 1:04").waitForExistence(timeout: 5))
        XCTAssertTrue(byID(app, "nowSummary").label.contains("Tide rising"), byID(app, "nowSummary").label)
        snapshot(app, "10-home-curve")

        let study = byID(app, "tideStudy")
        app.swipeUp()
        XCTAssertTrue(study.waitForExistence(timeout: 5))
        let readout = byID(app, "selectionReadout")
        let before = readout.label
        XCTAssertTrue(before.hasPrefix("Now, 10:20"), before)

        // Drag from early morning to ~9 PM (the evening low).
        let start = study.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
        let end = study.coordinate(withNormalizedOffset: CGVector(dx: 0.885, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
        let after = readout.label
        XCTAssertNotEqual(after, before)
        XCTAssertTrue(after.contains("PM"), after)
        XCTAssertTrue(after.contains("predicted height"), after)
        snapshot(app, "11-home-scrubbed")

        // Lifting the finger keeps the preview; Now resets it.
        XCTAssertTrue(app.buttons["nowButton"].exists)
        app.buttons["nowButton"].tap()
        XCTAssertTrue(readout.label.hasPrefix("Now, 10:20"), readout.label)
        XCTAssertFalse(app.buttons["nowButton"].exists)
    }

    func testHighLowOnlyStationSnapsToEvents() {
        let app = launch("highLow")
        XCTAssertTrue(element(app, containing: "King Harbor").waitForExistence(timeout: 5))
        snapshot(app, "20-home-highlow")
        app.swipeUp()
        let study = byID(app, "tideStudy")
        XCTAssertTrue(study.waitForExistence(timeout: 5))
        let readout = byID(app, "selectionReadout")
        // Between events NOAA publishes no height for a subordinate station.
        XCTAssertFalse(readout.label.contains("predicted height"), readout.label)
        study.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let snapped = readout.label
        XCTAssertTrue(snapped.contains("High tide") || snapped.contains("Low tide"), snapped)
        XCTAssertTrue(snapped.contains("predicted height"), snapped)
        snapshot(app, "21-highlow-snapped")
    }

    func testOfflineShowsDatedCache() {
        let app = launch("offline")
        XCTAssertTrue(element(app, containing: "High tide at 1:04").waitForExistence(timeout: 5))
        let banner = app.descendants(matching: .any)["freshnessBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(banner.label.contains("Offline"), banner.label)
        snapshot(app, "30-offline-cached")
    }

    func testExpiredCacheNeverShowsOldTides() {
        let app = launch("expired", ["-LTNow", "2026-11-25T18:20:00Z"])
        XCTAssertTrue(app.staticTexts["Forecast unavailable"].waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, containing: "High tide at 1:04").exists)
        XCTAssertTrue(app.buttons["retryButton"].exists)
        snapshot(app, "31-expired")
    }

    func testOfflineWithNothingCached() {
        let app = launch("failure")
        XCTAssertTrue(app.staticTexts["Predictions unavailable"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["You appear to be offline."].exists)
        snapshot(app, "32-failure")
    }

    func testLoadingState() {
        let app = launch("slow")
        XCTAssertTrue(app.descendants(matching: .any)["loadingState"].waitForExistence(timeout: 5))
        snapshot(app, "33-loading")
    }

    func testUnitsAndSourceSheet() {
        let app = launch("curve")
        XCTAssertTrue(element(app, containing: "High tide at 1:04").waitForExistence(timeout: 5))
        app.buttons["settings"].tap()
        let picker = app.segmentedControls["unitPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        snapshot(app, "40-settings")
        picker.buttons["Meters"].tap()
        app.buttons["Done"].tap()
        XCTAssertTrue(byID(app, "selectionReadout").waitForExistence(timeout: 5))
        XCTAssertTrue(byID(app, "selectionReadout").label.contains("meters above MLLW"), byID(app, "selectionReadout").label)
        snapshot(app, "40b-home-meters")

        app.swipeUp(); app.swipeUp()
        app.buttons["sourceFooter"].tap()
        XCTAssertTrue(app.staticTexts["Mean Lower Low Water (MLLW)"].exists || app.navigationBars["About this prediction"].waitForExistence(timeout: 5))
        snapshot(app, "41-source-sheet")
    }
}
