import XCTest
@testable import DriveDock

final class DriveAccountTests: XCTestCase {

    // MARK: - TokenStatus

    func testTokenStatusDisplayNames() {
        XCTAssertEqual(DriveAccount.TokenStatus.valid.displayName, "Connected")
        XCTAssertEqual(DriveAccount.TokenStatus.expired.displayName, "Token Expired")
        XCTAssertEqual(DriveAccount.TokenStatus.revoked.displayName, "Access Revoked")
        XCTAssertEqual(DriveAccount.TokenStatus.unknown.displayName, "Unknown")
    }

    func testTokenStatusSystemImages() {
        XCTAssertEqual(DriveAccount.TokenStatus.valid.systemImage, "checkmark.circle.fill")
        XCTAssertEqual(DriveAccount.TokenStatus.expired.systemImage, "clock.badge.exclamationmark")
        XCTAssertEqual(DriveAccount.TokenStatus.revoked.systemImage, "xmark.shield.fill")
        XCTAssertEqual(DriveAccount.TokenStatus.unknown.systemImage, "questionmark.circle")
    }

    func testTokenStatusAllCases() {
        XCTAssertEqual(DriveAccount.TokenStatus.allCases.count, 4)
    }

    // MARK: - Equality

    func testEqualityBasedOnID() {
        let date = Date()
        let a = DriveAccount(
            id: "same-id", email: "a@test.com", displayName: "A",
            avatarURL: nil, connectedDate: date, isActive: true,
            defaultDestinationID: nil, tokenStatus: .valid
        )
        let b = DriveAccount(
            id: "same-id", email: "b@test.com", displayName: "B",
            avatarURL: nil, connectedDate: date, isActive: false,
            defaultDestinationID: "dest", tokenStatus: .expired
        )
        XCTAssertEqual(a, b)
    }

    func testInequalityBasedOnID() {
        let date = Date()
        let a = DriveAccount(
            id: "id-1", email: "a@test.com", displayName: "A",
            avatarURL: nil, connectedDate: date, isActive: true,
            defaultDestinationID: nil, tokenStatus: .valid
        )
        let b = DriveAccount(
            id: "id-2", email: "a@test.com", displayName: "A",
            avatarURL: nil, connectedDate: date, isActive: true,
            defaultDestinationID: nil, tokenStatus: .valid
        )
        XCTAssertNotEqual(a, b)
    }

    // MARK: - Hashing

    func testHashingBasedOnID() {
        let date = Date()
        let a = DriveAccount(
            id: "same-id", email: "a@test.com", displayName: "A",
            avatarURL: nil, connectedDate: date, isActive: true,
            defaultDestinationID: nil, tokenStatus: .valid
        )
        let b = DriveAccount(
            id: "same-id", email: "b@test.com", displayName: "B",
            avatarURL: nil, connectedDate: date, isActive: false,
            defaultDestinationID: nil, tokenStatus: .expired
        )
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testAccountsInSet() {
        let date = Date()
        let a = DriveAccount(
            id: "id-1", email: "a@test.com", displayName: "A",
            avatarURL: nil, connectedDate: date, isActive: true,
            defaultDestinationID: nil, tokenStatus: .valid
        )
        let b = DriveAccount(
            id: "id-1", email: "different@test.com", displayName: "B",
            avatarURL: nil, connectedDate: date, isActive: false,
            defaultDestinationID: nil, tokenStatus: .expired
        )
        var set = Set<DriveAccount>()
        set.insert(a)
        set.insert(b)
        XCTAssertEqual(set.count, 1)
    }

    // MARK: - Codable

    func testCodableRoundTrip() throws {
        let account = DriveAccount(
            id: "test-id",
            email: "test@example.com",
            displayName: "Test User",
            avatarURL: URL(string: "https://example.com/avatar.png"),
            connectedDate: Date(timeIntervalSince1970: 1_000_000),
            isActive: true,
            defaultDestinationID: "dest-folder",
            tokenStatus: .valid
        )

        let data = try JSONEncoder().encode(account)
        let decoded = try JSONDecoder().decode(DriveAccount.self, from: data)

        XCTAssertEqual(decoded.id, account.id)
        XCTAssertEqual(decoded.email, account.email)
        XCTAssertEqual(decoded.displayName, account.displayName)
        XCTAssertEqual(decoded.isActive, account.isActive)
        XCTAssertEqual(decoded.tokenStatus, account.tokenStatus)
    }
}
