import XCTest
@testable import DriveDock

final class SpeedTrackerTests: XCTestCase {

    // MARK: - Basic Tracking

    func testInitialAddBytesReturnsSpeed() {
        let tracker = SpeedTracker()
        let speed = tracker.addBytes(1024)
        // First entry: timeSpan is 0, so speed should be 0
        XCTAssertEqual(speed, 0)
    }

    func testMultipleAddsReturnPositiveSpeed() {
        let tracker = SpeedTracker()
        _ = tracker.addBytes(1024)

        let expectation = XCTestExpectation(description: "Speed measurement")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let speed = tracker.addBytes(2048)
            XCTAssertGreaterThan(speed, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }

    func testSpeedReflectsByteRate() {
        let tracker = SpeedTracker()
        _ = tracker.addBytes(1000)

        let expectation = XCTestExpectation(description: "Speed rate check")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let speed = tracker.addBytes(1000)
            // ~2000 bytes over ~1 second
            XCTAssertGreaterThan(speed, 1000)
            XCTAssertLessThan(speed, 3000)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }

    // MARK: - Window Behavior

    func testOldEntriesExpire() {
        let tracker = SpeedTracker()
        _ = tracker.addBytes(1000)

        let expectation = XCTestExpectation(description: "Window expiry")
        // Wait longer than the 5-second window
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            let speed = tracker.addBytes(500)
            // Old entry should have expired; only new entry remains
            // With a single entry at timeSpan ~0, speed should be 0
            XCTAssertEqual(speed, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 7)
    }

    // MARK: - Zero Bytes

    func testZeroBytesReturnsZeroSpeed() {
        let tracker = SpeedTracker()
        let speed = tracker.addBytes(0)
        XCTAssertEqual(speed, 0)
    }

    // MARK: - Large Values

    func testLargeByteValues() {
        let tracker = SpeedTracker()
        let largeBytes: Int64 = 100_000_000 // 100 MB
        _ = tracker.addBytes(largeBytes)

        let expectation = XCTestExpectation(description: "Large values")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let speed = tracker.addBytes(largeBytes)
            XCTAssertGreaterThan(speed, 0)
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2)
    }
}
