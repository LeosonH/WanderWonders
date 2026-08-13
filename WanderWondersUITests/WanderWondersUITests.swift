import XCTest

@MainActor
final class WanderWondersUITests: XCTestCase {
    func testLaunchShowsBrandedAutumnSurface() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Wander Wonders"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Autumn V1"].exists)
    }
}
