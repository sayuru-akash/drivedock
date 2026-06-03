import XCTest
@testable import DriveDock

final class PersistenceServiceTests: XCTestCase {

    private var service: PersistenceService!

    override func setUp() {
        super.setUp()
        service = PersistenceService.shared
        service.clearAllLocalData()
    }

    override func tearDown() {
        service.clearAllLocalData()
        super.tearDown()
    }

    // MARK: - Queue Roundtrip

    func testSaveAndLoadQueue() {
        let items = [
            makeItem(id: "1", name: "file1.txt"),
            makeItem(id: "2", name: "file2.txt"),
        ]

        service.saveQueue(items)
        let loaded = service.loadQueue()

        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, "1")
        XCTAssertEqual(loaded[0].localFileName, "file1.txt")
        XCTAssertEqual(loaded[1].id, "2")
    }

    func testLoadEmptyQueue() {
        let loaded = service.loadQueue()
        XCTAssertTrue(loaded.isEmpty)
    }

    func testSaveEmptyQueue() {
        service.saveQueue([makeItem(id: "1", name: "a.txt")])
        service.saveQueue([])
        let loaded = service.loadQueue()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - History Roundtrip

    func testSaveAndLoadHistory() {
        let entry = makeHistoryEntry(id: "h1", name: "uploaded.txt")
        service.addHistoryEntry(entry)

        let loaded = service.loadHistory()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].id, "h1")
        XCTAssertEqual(loaded[0].fileName, "uploaded.txt")
    }

    func testHistoryPrependsNewest() {
        service.addHistoryEntry(makeHistoryEntry(id: "h1", name: "first.txt"))
        service.addHistoryEntry(makeHistoryEntry(id: "h2", name: "second.txt"))

        let loaded = service.loadHistory()
        XCTAssertEqual(loaded.count, 2)
        XCTAssertEqual(loaded[0].id, "h2")
        XCTAssertEqual(loaded[1].id, "h1")
    }

    func testHistoryMaxLimit() {
        for i in 0..<1005 {
            service.addHistoryEntry(makeHistoryEntry(id: "h\(i)", name: "file\(i).txt"))
        }
        let loaded = service.loadHistory()
        XCTAssertEqual(loaded.count, 1000)
    }

    // MARK: - Recent Destinations

    func testAddAndLoadRecentDestinations() {
        let dest = makeRecentDestination(id: "r1", folderID: "f1", name: "Folder A")
        service.addRecentDestination(dest)

        let loaded = service.loadRecentDestinations()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].folderName, "Folder A")
    }

    func testRecentDestinationDeduplication() {
        let dest1 = makeRecentDestination(id: "r1", folderID: "f1", name: "Folder A")
        let dest2 = makeRecentDestination(id: "r2", folderID: "f1", name: "Folder A Updated")

        service.addRecentDestination(dest1)
        service.addRecentDestination(dest2)

        let loaded = service.loadRecentDestinations()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].folderName, "Folder A Updated")
    }

    func testRecentDestinationMaxLimit() {
        for i in 0..<25 {
            let dest = makeRecentDestination(id: "r\(i)", folderID: "f\(i)", name: "Folder \(i)")
            service.addRecentDestination(dest)
        }
        let loaded = service.loadRecentDestinations()
        XCTAssertEqual(loaded.count, 20)
    }

    // MARK: - Starred Destinations

    func testToggleStarredAdds() {
        let dest = makeStarredDestination(id: "s1", folderID: "f1")
        service.toggleStarred(dest)

        let loaded = service.loadStarredDestinations()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].folderID, "f1")
    }

    func testToggleStarredRemoves() {
        let dest = makeStarredDestination(id: "s1", folderID: "f1")
        service.toggleStarred(dest)
        service.toggleStarred(dest)

        let loaded = service.loadStarredDestinations()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - Clear History

    func testClearHistory() {
        service.addHistoryEntry(makeHistoryEntry(id: "h1", name: "a.txt"))
        service.addHistoryEntry(makeHistoryEntry(id: "h2", name: "b.txt"))
        service.clearHistory()

        let loaded = service.loadHistory()
        XCTAssertTrue(loaded.isEmpty)
    }

    // MARK: - Clear All Data

    func testClearAllData() {
        service.saveQueue([makeItem(id: "1", name: "a.txt")])
        service.addHistoryEntry(makeHistoryEntry(id: "h1", name: "b.txt"))
        service.clearAllLocalData()

        XCTAssertTrue(service.loadQueue().isEmpty)
        XCTAssertTrue(service.loadHistory().isEmpty)
    }

    // MARK: - Export

    func testExportCSV() {
        service.addHistoryEntry(makeHistoryEntry(id: "h1", name: "test.txt"))
        let data = service.exportHistory(as: .csv)
        XCTAssertNotNil(data)

        let csv = String(data: data!, encoding: .utf8) ?? ""
        XCTAssertTrue(csv.contains("Date,File Name"))
        XCTAssertTrue(csv.contains("test.txt"))
    }

    func testExportJSON() {
        service.addHistoryEntry(makeHistoryEntry(id: "h1", name: "test.txt"))
        let data = service.exportHistory(as: .json)
        XCTAssertNotNil(data)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try? decoder.decode(HistoryExport.self, from: data!)
        XCTAssertNotNil(export)
        XCTAssertEqual(export?.entries.count, 1)
        XCTAssertEqual(export?.summary.totalFiles, 1)
    }

    func testExportText() {
        service.addHistoryEntry(makeHistoryEntry(id: "h1", name: "report.pdf"))
        let data = service.exportHistory(as: .text)
        XCTAssertNotNil(data)

        let text = String(data: data!, encoding: .utf8) ?? ""
        XCTAssertTrue(text.contains("DriveDock Upload Report"))
        XCTAssertTrue(text.contains("report.pdf"))
        XCTAssertTrue(text.contains("Summary"))
    }

    func testExportEmptyHistory() {
        let csvData = service.exportHistory(as: .csv)
        XCTAssertNotNil(csvData)
        let csv = String(data: csvData!, encoding: .utf8) ?? ""
        XCTAssertTrue(csv.contains("Date,File Name"))
    }

    // MARK: - Helpers

    private func makeItem(id: String, name: String) -> UploadItem {
        UploadItem(
            id: id,
            localFileName: name,
            localFilePath: "/tmp/\(name)",
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

    private func makeHistoryEntry(id: String, name: String) -> UploadHistoryEntry {
        UploadHistoryEntry(
            id: id,
            fileName: name,
            fileSize: 2048,
            accountEmail: "test@example.com",
            destinationFolderName: "Dest",
            destinationFolderID: "dest-id",
            status: .completed,
            startedDate: Date().addingTimeInterval(-60),
            completedDate: Date(),
            duration: 60,
            averageSpeed: 1024,
            driveFileLink: nil,
            errorMessage: nil,
            batchID: nil,
            isFolder: false
        )
    }

    private func makeRecentDestination(id: String, folderID: String, name: String) -> RecentDestination {
        RecentDestination(
            id: id,
            folderID: folderID,
            folderName: name,
            accountID: "account1",
            isSharedDrive: false,
            lastUsedDate: Date()
        )
    }

    private func makeStarredDestination(id: String, folderID: String) -> StarredDestination {
        StarredDestination(
            id: id,
            folderID: folderID,
            folderName: "Starred Folder",
            accountID: "account1",
            isSharedDrive: false,
            starredDate: Date()
        )
    }
}
