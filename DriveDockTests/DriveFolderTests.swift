import XCTest
@testable import DriveDock

final class DriveFolderTests: XCTestCase {

    // MARK: - DriveFolder Properties

    func testDriveFolderIsRootWithNilParent() {
        let folder = makeFolder(parentID: nil)
        XCTAssertTrue(folder.isRoot)
    }

    func testDriveFolderIsRootWithRootParent() {
        let folder = makeFolder(parentID: "root")
        XCTAssertTrue(folder.isRoot)
    }

    func testDriveFolderIsNotRoot() {
        let folder = makeFolder(parentID: "some-parent-id")
        XCTAssertFalse(folder.isRoot)
    }

    // MARK: - DriveFolder Equality

    func testDriveFolderEqualityBasedOnID() {
        let a = makeFolder(id: "same-id", name: "Folder A")
        let b = makeFolder(id: "same-id", name: "Folder B")
        XCTAssertEqual(a, b)
    }

    func testDriveFolderInequality() {
        let a = makeFolder(id: "id-1", name: "Same Name")
        let b = makeFolder(id: "id-2", name: "Same Name")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - DriveFolder Hashing

    func testDriveFolderHashing() {
        let a = makeFolder(id: "same-id", name: "A")
        let b = makeFolder(id: "same-id", name: "B")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testDriveFolderInSet() {
        let a = makeFolder(id: "id-1")
        let b = makeFolder(id: "id-1")
        var set = Set<DriveFolder>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - DriveFile Properties

    func testDriveFileIsFolder() {
        let file = DriveFile(
            id: "f1",
            name: "My Folder",
            mimeType: "application/vnd.google-apps.folder",
            size: nil,
            parentID: "root",
            webViewLink: nil,
            createdDate: nil,
            modifiedDate: nil
        )
        XCTAssertTrue(file.isFolder)
    }

    func testDriveFileIsNotFolder() {
        let file = DriveFile(
            id: "f2",
            name: "doc.pdf",
            mimeType: "application/pdf",
            size: 1024,
            parentID: "root",
            webViewLink: nil,
            createdDate: nil,
            modifiedDate: nil
        )
        XCTAssertFalse(file.isFolder)
    }

    func testDriveFileFormattedSizeWhenNil() {
        let file = DriveFile(
            id: "f1",
            name: "folder",
            mimeType: "application/vnd.google-apps.folder",
            size: nil,
            parentID: nil,
            webViewLink: nil,
            createdDate: nil,
            modifiedDate: nil
        )
        XCTAssertEqual(file.formattedSize, "—")
    }

    func testDriveFileFormattedSizeWhenPresent() {
        let file = DriveFile(
            id: "f2",
            name: "doc.pdf",
            mimeType: "application/pdf",
            size: 1_048_576,
            parentID: nil,
            webViewLink: nil,
            createdDate: nil,
            modifiedDate: nil
        )
        let result = file.formattedSize
        XCTAssertTrue(result.contains("MB") || result.contains("1"))
    }

    // MARK: - RecentDestination

    func testRecentDestinationEquality() {
        let a = RecentDestination(
            id: "same-id", folderID: "f1", folderName: "A",
            accountID: "acc1", isSharedDrive: false, lastUsedDate: Date()
        )
        let b = RecentDestination(
            id: "same-id", folderID: "f2", folderName: "B",
            accountID: "acc2", isSharedDrive: true, lastUsedDate: Date()
        )
        XCTAssertEqual(a, b)
    }

    func testRecentDestinationInequality() {
        let a = RecentDestination(
            id: "id-1", folderID: "f1", folderName: "Same",
            accountID: "acc1", isSharedDrive: false, lastUsedDate: Date()
        )
        let b = RecentDestination(
            id: "id-2", folderID: "f1", folderName: "Same",
            accountID: "acc1", isSharedDrive: false, lastUsedDate: Date()
        )
        XCTAssertNotEqual(a, b)
    }

    func testRecentDestinationHashing() {
        let a = RecentDestination(
            id: "same-id", folderID: "f1", folderName: "A",
            accountID: "acc1", isSharedDrive: false, lastUsedDate: Date()
        )
        let b = RecentDestination(
            id: "same-id", folderID: "f2", folderName: "B",
            accountID: "acc2", isSharedDrive: true, lastUsedDate: Date()
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    // MARK: - StarredDestination

    func testStarredDestinationEquality() {
        let a = StarredDestination(
            id: "same-id", folderID: "f1", folderName: "A",
            accountID: "acc1", isSharedDrive: false, starredDate: Date()
        )
        let b = StarredDestination(
            id: "same-id", folderID: "f2", folderName: "B",
            accountID: "acc2", isSharedDrive: true, starredDate: Date()
        )
        XCTAssertEqual(a, b)
    }

    func testStarredDestinationInequality() {
        let a = StarredDestination(
            id: "id-1", folderID: "f1", folderName: "Same",
            accountID: "acc1", isSharedDrive: false, starredDate: Date()
        )
        let b = StarredDestination(
            id: "id-2", folderID: "f1", folderName: "Same",
            accountID: "acc1", isSharedDrive: false, starredDate: Date()
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: - SharedDrive

    func testSharedDriveEquality() {
        let a = SharedDrive(id: "same-id", name: "Drive A")
        let b = SharedDrive(id: "same-id", name: "Drive B")
        XCTAssertEqual(a, b)
    }

    func testSharedDriveInequality() {
        let a = SharedDrive(id: "id-1", name: "Same Name")
        let b = SharedDrive(id: "id-2", name: "Same Name")
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Helpers

    private func makeFolder(id: String = UUID().uuidString, name: String = "Folder", parentID: String? = nil) -> DriveFolder {
        DriveFolder(
            id: id,
            name: name,
            parentID: parentID,
            isSharedDrive: false,
            sharedDriveID: nil,
            ownerEmail: nil,
            modifiedDate: nil,
            childCount: nil
        )
    }
}
