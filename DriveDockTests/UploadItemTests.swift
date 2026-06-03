import XCTest
@testable import DriveDock

final class UploadItemTests: XCTestCase {

    // MARK: - UploadItemStatus

    func testStatusDisplayNames() {
        XCTAssertEqual(UploadItemStatus.preparing.displayName, "Preparing")
        XCTAssertEqual(UploadItemStatus.waiting.displayName, "Waiting")
        XCTAssertEqual(UploadItemStatus.uploading.displayName, "Uploading")
        XCTAssertEqual(UploadItemStatus.paused.displayName, "Paused")
        XCTAssertEqual(UploadItemStatus.completed.displayName, "Completed")
        XCTAssertEqual(UploadItemStatus.failed.displayName, "Failed")
        XCTAssertEqual(UploadItemStatus.cancelled.displayName, "Cancelled")
        XCTAssertEqual(UploadItemStatus.needsAccountReconnect.displayName, "Needs Reconnect")
        XCTAssertEqual(UploadItemStatus.needsDestinationPermission.displayName, "Permission Needed")
        XCTAssertEqual(UploadItemStatus.skipped.displayName, "Skipped")
    }

    func testStatusSystemImages() {
        XCTAssertEqual(UploadItemStatus.preparing.systemImage, "gearshape")
        XCTAssertEqual(UploadItemStatus.uploading.systemImage, "arrow.up.circle")
        XCTAssertEqual(UploadItemStatus.completed.systemImage, "checkmark.circle.fill")
        XCTAssertEqual(UploadItemStatus.failed.systemImage, "exclamationmark.circle.fill")
        XCTAssertEqual(UploadItemStatus.cancelled.systemImage, "xmark.circle")
    }

    func testStatusIsActive() {
        XCTAssertTrue(UploadItemStatus.preparing.isActive)
        XCTAssertTrue(UploadItemStatus.uploading.isActive)
        XCTAssertFalse(UploadItemStatus.waiting.isActive)
        XCTAssertFalse(UploadItemStatus.paused.isActive)
        XCTAssertFalse(UploadItemStatus.completed.isActive)
        XCTAssertFalse(UploadItemStatus.failed.isActive)
        XCTAssertFalse(UploadItemStatus.cancelled.isActive)
    }

    func testStatusIsTerminal() {
        XCTAssertTrue(UploadItemStatus.completed.isTerminal)
        XCTAssertTrue(UploadItemStatus.cancelled.isTerminal)
        XCTAssertTrue(UploadItemStatus.skipped.isTerminal)
        XCTAssertFalse(UploadItemStatus.preparing.isTerminal)
        XCTAssertFalse(UploadItemStatus.uploading.isTerminal)
        XCTAssertFalse(UploadItemStatus.failed.isTerminal)
    }

    func testStatusAllCases() {
        XCTAssertEqual(UploadItemStatus.allCases.count, 10)
    }

    // MARK: - UploadItem Computed Properties

    func testProgressPercent() {
        var item = makeItem()
        item.progress = 0.0
        XCTAssertEqual(item.progressPercent, 0)

        item.progress = 0.5
        XCTAssertEqual(item.progressPercent, 50)

        item.progress = 1.0
        XCTAssertEqual(item.progressPercent, 100)

        item.progress = 0.333
        XCTAssertEqual(item.progressPercent, 33)
    }

    func testFormattedSize() {
        var item = makeItem()
        item.fileSize = 1024
        XCTAssertTrue(item.formattedSize.contains("KB") || item.formattedSize.contains("1"))

        item.fileSize = 1_048_576
        XCTAssertTrue(item.formattedSize.contains("MB") || item.formattedSize.contains("1"))
    }

    func testFormattedSpeedWhenZero() {
        let item = makeItem()
        XCTAssertEqual(item.formattedSpeed, "—")
    }

    func testFormattedSpeedWhenPositive() {
        var item = makeItem()
        item.speed = 1_048_576
        let result = item.formattedSpeed
        XCTAssertTrue(result.hasSuffix("/s"))
        XCTAssertFalse(result == "—")
    }

    func testFormattedETAWhenNil() {
        let item = makeItem()
        XCTAssertEqual(item.formattedETA, "—")
    }

    func testFormattedETAWhenZero() {
        var item = makeItem()
        item.eta = 0
        XCTAssertEqual(item.formattedETA, "—")
    }

    func testFormattedETAWhenPositive() {
        var item = makeItem()
        item.eta = 3661 // 1h 1m 1s
        let result = item.formattedETA
        XCTAssertFalse(result.isEmpty)
        XCTAssertNotEqual(result, "—")
    }

    // MARK: - ErrorCategory

    func testErrorCategoryIsRetryable() {
        XCTAssertTrue(ErrorCategory.network.isRetryable)
        XCTAssertTrue(ErrorCategory.quotaRateLimit.isRetryable)
        XCTAssertTrue(ErrorCategory.unknown.isRetryable)

        XCTAssertFalse(ErrorCategory.authentication.isRetryable)
        XCTAssertFalse(ErrorCategory.permission.isRetryable)
        XCTAssertFalse(ErrorCategory.destinationMissing.isRetryable)
        XCTAssertFalse(ErrorCategory.localFileMissing.isRetryable)
        XCTAssertFalse(ErrorCategory.fileChanged.isRetryable)
        XCTAssertFalse(ErrorCategory.fileTooLarge.isRetryable)
        XCTAssertFalse(ErrorCategory.storageQuotaExceeded.isRetryable)
        XCTAssertFalse(ErrorCategory.sharedDriveRestriction.isRetryable)
    }

    func testErrorCategoryUserActions() {
        XCTAssertFalse(ErrorCategory.network.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.quotaRateLimit.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.authentication.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.permission.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.destinationMissing.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.localFileMissing.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.fileChanged.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.fileTooLarge.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.storageQuotaExceeded.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.sharedDriveRestriction.userAction.isEmpty)
        XCTAssertFalse(ErrorCategory.unknown.userAction.isEmpty)
    }

    func testErrorCategoryDisplayNames() {
        XCTAssertEqual(ErrorCategory.network.displayName, "Network Error")
        XCTAssertEqual(ErrorCategory.authentication.displayName, "Authentication Error")
        XCTAssertEqual(ErrorCategory.permission.displayName, "Permission Denied")
        XCTAssertEqual(ErrorCategory.storageQuotaExceeded.displayName, "Storage Full")
        XCTAssertEqual(ErrorCategory.unknown.displayName, "Unknown Error")
    }

    func testErrorCategoryAllCases() {
        XCTAssertEqual(ErrorCategory.allCases.count, 11)
    }

    // MARK: - DuplicateMode

    func testDuplicateModeDisplayNames() {
        XCTAssertEqual(DuplicateMode.keepBoth.displayName, "Keep Both")
        XCTAssertEqual(DuplicateMode.renameNew.displayName, "Rename New File")
        XCTAssertEqual(DuplicateMode.skipExisting.displayName, "Skip Existing")
        XCTAssertEqual(DuplicateMode.replaceExisting.displayName, "Replace Existing")
    }

    func testDuplicateModeAllCases() {
        XCTAssertEqual(DuplicateMode.allCases.count, 4)
    }

    // MARK: - Helpers

    private func makeItem() -> UploadItem {
        UploadItem(
            id: UUID().uuidString,
            localFileName: "test.txt",
            localFilePath: "/tmp/test.txt",
            fileSize: 1024,
            mimeType: "text/plain",
            destinationFolderID: "folder1",
            destinationFolderName: "My Folder",
            accountID: "account1",
            status: .waiting,
            progress: 0,
            uploadedBytes: 0,
            speed: 0,
            eta: nil,
            retryCount: 0,
            errorMessage: nil,
            errorCategory: nil,
            driveFileID: nil,
            driveFileLink: nil,
            resumableSessionURL: nil,
            createdDate: Date(),
            lastActivityDate: Date(),
            completedDate: nil,
            batchID: nil,
            isFolder: false,
            folderPath: nil,
            duplicateHandling: .keepBoth
        )
    }
}
