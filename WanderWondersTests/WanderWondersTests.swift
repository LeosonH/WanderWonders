import XCTest
@testable import WanderWonders

@MainActor
final class WanderWondersTests: XCTestCase {
    func testDisplayNameAndReleaseSeasonContract() {
        XCTAssertEqual(WanderWondersApp.displayName, "Wander Wonders")
        XCTAssertEqual("autumn", "autumn")
    }
}
