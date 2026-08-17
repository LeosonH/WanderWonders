import XCTest

@MainActor
final class WanderWondersUITests: XCTestCase {
    func testLaunchShowsConfiguredSignInSurface() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Wander Wonders"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["A calm reason to wander outside."].exists)
        XCTAssertTrue(app.images["Wander Wonders app icon"].exists)
        XCTAssertFalse(app.staticTexts["Add safe local configuration to run the app."].exists)
    }
}
