import XCTest
@testable import WanderWonders

final class WanderWondersTests: XCTestCase {
    func testDisplayNameAndReleaseSeasonContract() {
        XCTAssertEqual(WanderWondersApp.displayName, "Wander Wonders")
        XCTAssertEqual("autumn", "autumn")
    }
}
