import Foundation
import Security
import LocalAuthentication

enum KeychainError: LocalizedError {
    case duplicateItem
    case itemNotFound
    case unexpectedStatus(OSStatus)
    case dataConversionFailed
    case biometricNotAvailable
    case biometricNotEnrolled
    case authenticationFailed(String)
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .duplicateItem: return "Item already exists in Keychain"
        case .itemNotFound: return "Item not found in Keychain"
        case .unexpectedStatus(let status):
            return humanReadableKeychainError(status)
        case .dataConversionFailed: return "Failed to convert Keychain data"
        case .biometricNotAvailable: return "Biometric authentication is not available on this device"
        case .biometricNotEnrolled: return "No biometric credentials are enrolled. Please set up Touch ID or Face ID."
        case .authenticationFailed(let reason): return "Authentication failed: \(reason)"
        case .accessDenied: return "Access to the secure item was denied"
        }
    }

    private func humanReadableKeychainError(_ status: OSStatus) -> String {
        switch status {
        case errSecDuplicateItem: return "Item already exists in Keychain"
        case errSecItemNotFound: return "Item not found in Keychain"
        case errSecAuthFailed: return "Keychain authentication failed"
        case errSecDecode: return "Failed to decode Keychain data"
        case errSecParam: return "Invalid Keychain parameters"
        case errSecAllocate: return "Failed to allocate Keychain memory"
        case errSecNotAvailable: return "Keychain is not available"
        case errSecReadOnly: return "Keychain is read-only"
        case errSecInteractionNotAllowed: return "Keychain interaction is not allowed"
        default: return "Keychain error (code: \(status))"
        }
    }
}

final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.drivedock.app"
    private let accessGroup: String? = nil

    var useBiometricAuthentication = false

    private init() {}

    func save(_ data: Data, for key: String) throws {
        try delete(key: key)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]

        if useBiometricAuthentication {
            let access = try createBiometricAccessControl()
            query[kSecAttrAccessControl as String] = access
        }

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key
            ]
            let updateAttributes: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainError.unexpectedStatus(updateStatus)
            }
        } else if status != errSecSuccess {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func save(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        try save(data, for: key)
    }

    func load(key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            }
            throw KeychainError.unexpectedStatus(status)
        }

        guard let data = result as? Data else {
            throw KeychainError.dataConversionFailed
        }

        return data
    }

    func loadWithBiometric(key: String, reason: String = "Authenticate to access secure data") async throws -> Data {
        let context = LAContext()
        context.localizedReason = reason

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationContext as String: context
        ]

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                var result: AnyObject?
                let status = SecItemCopyMatching(query as CFDictionary, &result)

                guard status == errSecSuccess else {
                    if status == errSecItemNotFound {
                        continuation.resume(throwing: KeychainError.itemNotFound)
                    } else if status == errSecUserCanceled || status == errSecAuthFailed {
                        continuation.resume(throwing: KeychainError.authenticationFailed("Biometric authentication was cancelled or failed"))
                    } else {
                        continuation.resume(throwing: KeychainError.unexpectedStatus(status))
                    }
                    return
                }

                guard let data = result as? Data else {
                    continuation.resume(throwing: KeychainError.dataConversionFailed)
                    return
                }

                continuation.resume(returning: data)
            }
        }
    }

    func loadString(key: String) throws -> String {
        let data = try load(key: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.dataConversionFailed
        }
        return string
    }

    func delete(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    func migrateService(from oldService: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: oldService,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let items = result as? [[String: Any]] else {
            return
        }

        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data else { continue }

            let newQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data
            ]

            SecItemAdd(newQuery as CFDictionary, nil)

            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: oldService,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(deleteQuery as CFDictionary)
        }
    }

    func checkBiometricAvailability() -> (available: Bool, enrolled: Bool, type: String) {
        let context = LAContext()
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        let type: String
        if #available(macOS 12.0, *) {
            switch context.biometryType {
            case .touchID: type = "Touch ID"
            case .faceID: type = "Face ID"
            default: type = "Biometric"
            }
        } else {
            type = "Touch ID"
        }
        return (available: available, enrolled: error == nil, type: type)
    }

    private func createBiometricAccessControl() throws -> SecAccessControl {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            let cfError = error?.takeRetainedValue()
            throw KeychainError.authenticationFailed(cfError?.localizedDescription ?? "Failed to create access control")
        }
        return access
    }
}
