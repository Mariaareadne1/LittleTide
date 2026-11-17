import XCTest

/// Opt-in rendering cost probe: CPU time and memory of the app while it sits on the home
/// screen, first with the painted hero visible, then scrolled to the details.
///
///     TEST_RUNNER_LT_PERF=1 xcodebuild test ... -only-testing:LittleTideUITests/RenderingPerformanceTests
///
/// Simulator numbers are relative (the Mac's GPU does the Metal work); use them to compare
/// builds, not to predict battery life on a phone.
final class RenderingPerformanceTests: XCTestCase {
    private static let holdSeconds: UInt32 = 5

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["LT_PERF"] == "1", "Performance probe not requested")
        continueAfterFailure = false
    }

    private func launchHome() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-LTDemo", "curve"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["nowSummary"].waitForExistence(timeout: 10))
        sleep(2) // let first-frame work (shader compile, atlas decode) finish
        return app
    }

    private var options: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 6
        return options
    }

    func testIdleHeroVisible() {
        let app = launchHome()
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            sleep(Self.holdSeconds)
        }
    }

    func testIdleScrolledToDetails() {
        let app = launchHome()
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)
        sleep(2)
        XCTAssertTrue(app.descendants(matching: .any)["selectionReadout"].isHittable)
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            sleep(Self.holdSeconds)
        }
    }
}
