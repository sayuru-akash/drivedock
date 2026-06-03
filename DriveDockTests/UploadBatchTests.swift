import XCTest
@testable import DriveDock

final class UploadBatchTests: XCTestCase {

    // MARK: - UploadBatchStatus

    func testBatchStatusDisplayNames() {
        XCTAssertEqual(UploadBatchStatus.preparing.displayName, "Preparing")
        XCTAssertEqual(UploadBatchStatus.ready.displayName, "Ready")
        XCTAssertEqual(UploadBatchStatus.uploading.displayName, "Uploading")
        XCTAssertEqual(UploadBatchStatus.partiallyCompleted.displayName, "Partially Completed")
        XCTAssertEqual(UploadBatchStatus.completed.displayName, "Completed")
        XCTAssertEqual(UploadBatchStatus.paused.displayName, "Paused")
        XCTAssertEqual(UploadBatchStatus.failed.displayName, "Failed")
        XCTAssertEqual(UploadBatchStatus.cancelled.displayName, "Cancelled")
    }

    // MARK: - Progress

    func testProgressCalculation() {
        let batch = makeBatch(totalSize: 1000, uploadedSize: 500)
        XCTAssertEqual(batch.progress, 0.5, accuracy: 0.001)
        XCTAssertEqual(batch.progressPercent, 50)
    }

    func testProgressZeroTotal() {
        let batch = makeBatch(totalSize: 0, uploadedSize: 0)
        XCTAssertEqual(batch.progress, 0)
        XCTAssertEqual(batch.progressPercent, 0)
    }

    func testProgressComplete() {
        let batch = makeBatch(totalSize: 2048, uploadedSize: 2048)
        XCTAssertEqual(batch.progress, 1.0, accuracy: 0.001)
        XCTAssertEqual(batch.progressPercent, 100)
    }

    func testProgressPartial() {
        let batch = makeBatch(totalSize: 3000, uploadedSize: 1000)
        XCTAssertEqual(batch.progress, 1.0 / 3.0, accuracy: 0.001)
        XCTAssertEqual(batch.progressPercent, 33)
    }

    // MARK: - Duration

    func testDurationWhenNotStarted() {
        let batch = makeBatch(startedDate: nil, completedDate: nil)
        XCTAssertNil(batch.duration)
    }

    func testDurationWhenStartedNotCompleted() {
        let start = Date().addingTimeInterval(-60)
        let batch = makeBatch(startedDate: start, completedDate: nil)
        XCTAssertNotNil(batch.duration)
        XCTAssertTrue(batch.duration! >= 59)
    }

    func testDurationWhenCompleted() {
        let start = Date().addingTimeInterval(-120)
        let end = Date().addingTimeInterval(-60)
        let batch = makeBatch(startedDate: start, completedDate: end)
        XCTAssertNotNil(batch.duration)
        XCTAssertEqual(batch.duration!, 60, accuracy: 1)
    }

    func testFormattedDurationWhenNil() {
        let batch = makeBatch(startedDate: nil, completedDate: nil)
        XCTAssertEqual(batch.formattedDuration, "—")
    }

    func testFormattedDurationWhenPresent() {
        let start = Date().addingTimeInterval(-3661)
        let end = Date()
        let batch = makeBatch(startedDate: start, completedDate: end)
        let result = batch.formattedDuration
        XCTAssertFalse(result.isEmpty)
        XCTAssertNotEqual(result, "—")
    }

    // MARK: - Formatted Size

    func testFormattedTotalSize() {
        let batch = makeBatch(totalSize: 1_048_576)
        let result = batch.formattedTotalSize
        XCTAssertTrue(result.contains("MB") || result.contains("1"))
    }

    // MARK: - Helpers

    private func makeBatch(
        totalSize: Int64 = 1024,
        uploadedSize: Int64 = 0,
        startedDate: Date? = nil,
        completedDate: Date? = nil
    ) -> UploadBatch {
        UploadBatch(
            id: UUID().uuidString,
            name: "Test Batch",
            accountID: "account1",
            destinationFolderID: "folder1",
            destinationFolderName: "My Folder",
            status: .uploading,
            itemIDs: ["item1"],
            createdDate: Date(),
            startedDate: startedDate,
            completedDate: completedDate,
            totalSize: totalSize,
            uploadedSize: uploadedSize,
            duplicateHandling: .keepBoth,
            preserveStructure: true
        )
    }
}
