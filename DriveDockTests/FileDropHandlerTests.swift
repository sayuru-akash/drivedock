import XCTest
@testable import DriveDock

final class FileDropHandlerTests: XCTestCase {

    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileDropHandlerTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - MIME Type Detection

    func testMIMETypeDetectionForSingleFile() {
        let fileURL = createTempFile(name: "photo.jpg", size: 100)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let files = FileDropHandler.processDroppedItems([fileURL])
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].mimeType, "image/jpeg")
    }

    func testMIMETypeDetectionForPDF() {
        let fileURL = createTempFile(name: "document.pdf", size: 200)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let files = FileDropHandler.processDroppedItems([fileURL])
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].mimeType, "application/pdf")
    }

    func testMIMETypeDetectionForVideo() {
        let fileURL = createTempFile(name: "video.mp4", size: 500)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let files = FileDropHandler.processDroppedItems([fileURL])
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].mimeType, "video/mp4")
    }

    // MARK: - File Info

    func testFileInfoProperties() {
        let fileURL = createTempFile(name: "test.txt", size: 1024)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let files = FileDropHandler.processDroppedItems([fileURL])
        XCTAssertEqual(files.count, 1)
        XCTAssertEqual(files[0].fileName, "test.txt")
        XCTAssertEqual(files[0].fileSize, 1024)
        XCTAssertNil(files[0].relativePath)
    }

    // MARK: - Folder Scanning

    func testFolderScanning() {
        let folderURL = tempDir.appendingPathComponent("TestFolder")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        createTempFile(at: folderURL, name: "a.txt", size: 100)
        createTempFile(at: folderURL, name: "b.jpg", size: 200)

        let files = FileDropHandler.processDroppedItems([folderURL])
        XCTAssertEqual(files.count, 2)

        let names = files.map(\.fileName).sorted()
        XCTAssertEqual(names, ["a.txt", "b.jpg"])
    }

    func testFolderScanningWithSubfolders() {
        let folderURL = tempDir.appendingPathComponent("NestedFolder")
        let subfolderURL = folderURL.appendingPathComponent("Sub")
        try? FileManager.default.createDirectory(at: subfolderURL, withIntermediateDirectories: true)

        createTempFile(at: folderURL, name: "root.txt", size: 50)
        createTempFile(at: subfolderURL, name: "nested.txt", size: 75)

        let files = FileDropHandler.processDroppedItems([folderURL])
        XCTAssertEqual(files.count, 2)

        let nestedFile = files.first { $0.fileName == "nested.txt" }
        XCTAssertNotNil(nestedFile)
        XCTAssertNotNil(nestedFile?.relativePath)
    }

    // MARK: - Hidden Files Filtering

    func testHiddenFilesAreIgnored() {
        let fileURL = createTempFile(name: ".hidden", size: 10)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let files = FileDropHandler.processDroppedItems([fileURL])
        XCTAssertTrue(files.isEmpty)
    }

    func testDSStoreIsIgnored() {
        let fileURL = createTempFile(name: ".DS_Store", size: 10)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let files = FileDropHandler.processDroppedItems([fileURL])
        XCTAssertTrue(files.isEmpty)
    }

    // MARK: - Nonexistent File

    func testNonexistentFileIsSkipped() {
        let fakeURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).txt")
        let files = FileDropHandler.processDroppedItems([fakeURL])
        XCTAssertTrue(files.isEmpty)
    }

    // MARK: - Multiple Files

    func testMultipleFiles() {
        let file1 = createTempFile(name: "one.txt", size: 100)
        let file2 = createTempFile(name: "two.png", size: 200)
        let file3 = createTempFile(name: "three.pdf", size: 300)
        defer {
            try? FileManager.default.removeItem(at: file1)
            try? FileManager.default.removeItem(at: file2)
            try? FileManager.default.removeItem(at: file3)
        }

        let files = FileDropHandler.processDroppedItems([file1, file2, file3])
        XCTAssertEqual(files.count, 3)
    }

    // MARK: - Folder Info

    func testFolderInfo() {
        let folderURL = tempDir.appendingPathComponent("InfoFolder")
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        createTempFile(at: folderURL, name: "a.txt", size: 100)
        createTempFile(at: folderURL, name: "b.txt", size: 200)

        let info = FileDropHandler.folderInfo(path: folderURL.path)
        XCTAssertEqual(info.fileCount, 2)
        XCTAssertEqual(info.totalSize, 300)
    }

    // MARK: - Helpers

    @discardableResult
    private func createTempFile(name: String, size: Int) -> URL {
        let url = tempDir.appendingPathComponent(name)
        let data = Data(repeating: 0xAA, count: size)
        try? data.write(to: url)
        return url
    }

    @discardableResult
    private func createTempFile(at directory: URL, name: String, size: Int) -> URL {
        let url = directory.appendingPathComponent(name)
        let data = Data(repeating: 0xBB, count: size)
        try? data.write(to: url)
        return url
    }
}
