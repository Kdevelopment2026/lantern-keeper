import XCTest
@testable import LanternKeeper

final class LanternKeeperTests: XCTestCase {
    func testHostAppLoads() {
        XCTAssertNotNil(Bundle(for: Self.self))
    }
}
