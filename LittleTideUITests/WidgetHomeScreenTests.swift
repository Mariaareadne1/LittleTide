import XCTest

/// Installs the real widgets on the simulator Home Screen with live NOAA data.
/// Skipped unless requested (it changes the Home Screen and needs network):
///     TEST_RUNNER_LT_WIDGET_QA=1 xcodebuild test ... -only-testing:LittleTideUITests/WidgetHomeScreenTests
@MainActor
final class WidgetHomeScreenTests: XCTestCase {
    let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func snapshot(_ name: String, _ app: XCUIApplication? = nil) {
        let shot = (app ?? springboard).screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testChooseCoastThenInstallWidgets() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LT_WIDGET_QA"] == "1", "Home Screen QA not requested")
        // 1. Real app, real NOAA: choose a coast if none is chosen yet.
        let app = XCUIApplication()
        app.launch()
        if app.buttons["chooseCoast"].waitForExistence(timeout: 4) {
            app.buttons["chooseCoast"].tap()
            let search = app.searchFields.firstMatch
            XCTAssertTrue(search.waitForExistence(timeout: 5))
            search.tap()
            search.typeText("santa monica")
            let row = app.buttons["station-9410840"]
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.tap()
        }
        let summary = app.descendants(matching: .any)["nowSummary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 30), "live NOAA predictions did not load")
        snapshot("50-app-live", app)

        // 2. Home Screen → edit → add widget.
        XCUIDevice.shared.press(.home)
        sleep(1)
        let sizes = (ProcessInfo.processInfo.environment["LT_WIDGET_SIZES"] ?? "small,medium").split(separator: ",")
        if sizes.contains("small") { addWidget(search: "Little Tide", swipesToSize: 0) }
        if sizes.contains("medium") { addWidget(search: "Little Tide", swipesToSize: 1) }
        if springboard.buttons["Done"].waitForExistence(timeout: 3) { springboard.buttons["Done"].tap() }
        sleep(3)
        snapshot("51-home-screen-widgets")

        // 3. Tap a widget: it must open the app on the same coast.
        showPageWithLittleTideWidgets()
        let widget = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Santa Monica'")).firstMatch
        XCTAssertTrue(widget.waitForExistence(timeout: 10), "widget not found on Home Screen")
        widget.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["nowSummary"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Santa Monica'")).firstMatch.exists)
        snapshot("52-opened-from-widget", app)
    }

    private func addWidget(search text: String, swipesToSize: Int) {
        // Enter jiggle mode by long-pressing empty wallpaper.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).press(forDuration: 1.6)
        let edit = springboard.buttons["Edit"]
        if edit.waitForExistence(timeout: 4) {
            edit.tap()
            let addWidget = springboard.buttons["Add Widget"]
            XCTAssertTrue(addWidget.waitForExistence(timeout: 4))
            addWidget.tap()
        } else {
            let plus = springboard.buttons["Add Widget"]
            XCTAssertTrue(plus.waitForExistence(timeout: 4))
            plus.tap()
        }
        let field = springboard.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(text)
        // The search result row is a Cell labelled with the app name.
        let result = springboard.cells[text]
        XCTAssertTrue(result.waitForExistence(timeout: 5), "\(text) not in widget gallery")
        result.tap()
        sleep(1)
        for _ in 0..<swipesToSize { springboard.swipeLeft(); sleep(1) }
        snapshot("gallery-\(swipesToSize)")
        // The gallery's button label has a leading space: " Add Widget".
        let add = springboard.buttons.matching(NSPredicate(format: "label ENDSWITH 'Add Widget'")).firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        sleep(2)
    }

    /// Switches the Home Screen icon/widget style (iOS 26 Customize panel) and captures it.
    ///     TEST_RUNNER_LT_WIDGET_QA=1 TEST_RUNNER_LT_STYLE=Tinted|Clear|Default
    func testHomeScreenStyle() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LT_WIDGET_QA"] == "1", "Home Screen QA not requested")
        let style = ProcessInfo.processInfo.environment["LT_STYLE"] ?? "Default"
        XCUIDevice.shared.press(.home)
        sleep(1)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75)).press(forDuration: 1.6)
        let edit = springboard.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 4))
        edit.tap()
        let customize = springboard.buttons["Customize"]
        XCTAssertTrue(customize.waitForExistence(timeout: 4))
        customize.tap()
        sleep(1)
        snapshot("customize-panel")
        let option = springboard.buttons[style]
        XCTAssertTrue(option.waitForExistence(timeout: 4), "no \(style) option")
        option.tap()
        sleep(1)
        // Dismiss the panel, then leave edit mode.
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        sleep(1)
        if springboard.buttons["Done"].waitForExistence(timeout: 2) { springboard.buttons["Done"].tap() }
        sleep(1)
        showPageWithLittleTideWidgets()
        sleep(3)
        snapshot("style-\(style)")
    }

    /// Pages the Home Screen until a Little Tide widget (labelled with the coast) is visible.
    private func showPageWithLittleTideWidgets() {
        let widget = springboard.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Santa Monica.'")).firstMatch
        for swipeLeft in [true, true, false, false, false] {
            if widget.exists && widget.isHittable { return }
            if swipeLeft { springboard.swipeLeft() } else { springboard.swipeRight() }
            sleep(1)
        }
    }
}
