import XCTest
@testable import DriveDock

final class KeychainServiceTests: XCTestCase {

    private var keychain: KeychainService!
    private let testKey = "com.drivedock.test.key"

    override func setUp() {
        super.setUp()
        keychain = KeychainService.shared
        try? keychain.delete(key: testKey)
    }

    override func tearDown() {
        try? keychain.delete(key: testKey)
        super.tearDown()
    }

    // MARK: - Save and Load String

    func testSaveAndLoadString() throws {
        try keychain.save("hello world", for: testKey)
        let loaded = try keychain.loadString(key: testKey)
        XCTAssertEqual(loaded, "hello world")
    }

    func testSaveAndLoadEmptyString() throws {
        try keychain.save("", for: testKey)
        let loaded = try keychain.loadString(key: testKey)
        XCTAssertEqual(loaded, "")
    }

    func testSaveAndLoadUnicodeString() throws {
        let value = "こんにちは 🌍"
        try keychain.save(value, for: testKey)
        let loaded = try keychain.loadString(key: testKey)
        XCTAssertEqual(loaded, value)
    }

    // MARK: - Save and Load Data

    func testSaveAndLoadData() throws {
        let data = Data([0x01, 0x02, 0x03, 0xFF])
        try keychain.save(data, for: testKey)
        let loaded = try keychain.load(key: testKey)
        XCTAssertEqual(loaded, data)
    }

    func testSaveAndLoadEmptyData() throws {
        let data = Data()
        try keychain.save(data, for: testKey)
        let loaded = try keychain.load(key: testKey)
        XCTAssertEqual(loaded, data)
    }

    // MARK: - Delete

    func testDeleteExistingItem() throws {
        try keychain.save("to be deleted", for: testKey)
        try keychain.delete(key: testKey)

        XCTAssertThrowsError(try keychain.load(key: testKey)) { error in
            guard case KeychainError.itemNotFound = error else {
                XCTFail("Expected itemNotFound error, got \(error)")
                return
            }
        }
    }

    func testDeleteNonexistentItemDoesNotThrow() {
        XCTAssertNoThrow(try keychain.delete(key: "nonexistent.key.that.does.not.exist"))
    }

    // MARK: - Overwrite

    func testOverwriteExistingString() throws {
        try keychain.save("original", for: testKey)
        try keychain.save("updated", for: testKey)
        let loaded = try keychain.loadString(key: testKey)
        XCTAssertEqual(loaded, "updated")
    }

    func testOverwriteExistingData() throws {
        let original = Data([0x01, 0x02])
        let updated = Data([0x03, 0x04, 0x05])

        try keychain.save(original, for: testKey)
        try keychain.save(updated, for: testKey)
        let loaded = try keychain.load(key: testKey)
        XCTAssertEqual(loaded, updated)
    }

    // MARK: - Load Nonexistent

    func testLoadNonexistentItemThrows() {
        XCTAssertThrowsError(try keychain.load(key: "nonexistent.key.that.does.not.exist")) { error in
            guard case KeychainError.itemNotFound = error else {
                XCTFail("Expected itemNotFound error, got \(error)")
                return
            }
        }
    }

    func testLoadStringNonexistentItemThrows() {
        XCTAssertThrowsError(try keychain.loadString(key: "nonexistent.key.that.does.not.exist")) { error in
            guard case KeychainError.itemNotFound = error else {
                XCTFail("Expected itemNotFound error, got \(error)")
                return
            }
        }
    }

    // MARK: - Key Isolation

    func testDifferentKeysAreIsolated() throws {
        let key1 = "com.drivedock.test.key1"
        let key2 = "com.drivedock.test.key2"
        defer {
            try? keychain.delete(key: key1)
            try? keychain.delete(key: key2)
        }

        try keychain.save("value1", for: key1)
        try keychain.save("value2", for: key2)

        XCTAssertEqual(try keychain.loadString(key: key1), "value1")
        XCTAssertEqual(try keychain.loadString(key: key2), "value2")
    }
}
