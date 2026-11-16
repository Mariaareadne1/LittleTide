import XCTest
@testable import LittleTide

final class DeepLinkTests: XCTestCase {
    func testParsesStationLinks() {
        XCTAssertEqual(DeepLink(url: URL(string: "littletide://station/9410840")!), .station("9410840"))
        XCTAssertEqual(DeepLink.station("TPT2705").url.absoluteString, "littletide://station/TPT2705")
    }

    func testRejectsForeignOrMalformedLinks() {
        XCTAssertNil(DeepLink(url: URL(string: "https://station/9410840")!))
        XCTAssertNil(DeepLink(url: URL(string: "littletide://other/9410840")!))
        XCTAssertNil(DeepLink(url: URL(string: "littletide://station/")!))
        XCTAssertNil(DeepLink(url: URL(string: "littletide://station/..%2F..")!))
    }
}
