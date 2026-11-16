import XCTest

/// Apple's automated accessibility audit (contrast, hit regions, Dynamic Type, labels…)
/// over the main screens in DEBUG demo mode.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = true
    }

    /// Logs every issue with its element so it can be fixed, and fails the test.
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        sleep(2) // let scrolling and sheet presentation settle; mid-animation frames skew contrast
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "audit-\(screen)"
        shot.lifetime = .keepAlways
        add(shot)
        try app.performAccessibilityAudit { issue in
            let element = issue.element.map { "\($0.elementType.rawValue) '\($0.label)' id=\($0.identifier) frame=\($0.frame)" } ?? "none"
            let ignored = Self.isKnownFalsePositive(issue)
            print("AXAUDIT [\(screen)] \(ignored ? "ignored" : "FAIL") \(issue.compactDescription) :: \(element)")
            return ignored
        }
    }

    /// Documented exclusions (see Documentation/ACCESSIBILITY.md):
    /// - textClipped: fires for elements whose spoken label is intentionally richer than the
    ///   visible text ("High at 1:04 PM" → "High tide at 1:04 PM, predicted height…").
    ///   Truncation is checked visually at Accessibility sizes instead.
    /// - System controls (search field placeholder, navigation Close button).
    /// - Text drawn inside the tide-study Canvas: exposed via the chart's adjustable value.
    static func isKnownFalsePositive(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        if issue.auditType == .textClipped { return true }
        guard let element = issue.element else { return issue.auditType == .trait || issue.compactDescription.contains("inaccessible text") }
        if element.elementType == .searchField { return true }
        if element.elementType == .button, element.label == "Close" { return true }
        // Contrast sampled over neighbouring surfaces (white list card / glass scroll edge).
        // Both are `Palette.ink` on paper, measured at 10.9:1 (Documentation/ACCESSIBILITY.md).
        if issue.auditType == .contrast, ["Featured coasts", "Rising"].contains(element.label) { return true }
        return false
    }

    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-LTDemo", scenario]
        app.launch()
        return app
    }

    func testOnboardingAudit() throws {
        let app = launch("onboarding")
        XCTAssertTrue(app.buttons["chooseCoast"].waitForExistence(timeout: 5))
        try audit(app, "onboarding")
    }

    func testHomeCurveAudit() throws {
        let app = launch("curve")
        XCTAssertTrue(app.descendants(matching: .any)["nowSummary"].waitForExistence(timeout: 5))
        try audit(app, "home-top")
        app.swipeUp()
        try audit(app, "home-scrolled")
    }

    func testHomeHighLowAudit() throws {
        let app = launch("highLow")
        XCTAssertTrue(app.descendants(matching: .any)["nowSummary"].waitForExistence(timeout: 5))
        try audit(app, "home-highlow")
    }

    func testSearchAudit() throws {
        let app = launch("onboarding")
        app.buttons["chooseCoast"].tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        try audit(app, "search")
    }
}
