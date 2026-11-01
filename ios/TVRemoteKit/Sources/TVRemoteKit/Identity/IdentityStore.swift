import Foundation
import Security

public protocol IdentityStore {
    /// The saved identity, or nil if none was saved yet.
    func load() throws -> ClientIdentity?
    func save(_ identity: ClientIdentity) throws
}

/// How `loadOrCreateReporting()` got the identity.
public enum IdentityOrigin: Equatable {
    /// The saved identity.
    case loaded
    /// None was saved: a new one was generated and saved.
    case created
    /// The saved identity used the shared name `CN=atvremote`, so a new one with its own name replaced it.
    /// The device has to pair again.
    case replacedSharedName
}

extension IdentityStore {
    /// Returns the saved identity; on first use generates one and saves it.
    public func loadOrCreate() throws -> ClientIdentity {
        try loadOrCreateReporting().identity
    }

    /// Like `loadOrCreate()`, and says where the identity came from.
    /// A saved identity with the shared name `CN=atvremote` is replaced by a new one with its own name, because the
    /// TV keeps only one pairing per name and devices sharing it unpaired each other.
    public func loadOrCreateReporting() throws -> (identity: ClientIdentity, how: IdentityOrigin) {
        let how: IdentityOrigin
        if let existing = try load() {
            guard try existing.usesSharedLegacyName() else { return (existing, .loaded) }
            how = .replacedSharedName
        } else {
            how = .created
        }
        let created = try ClientIdentity.generate()
        try save(created)
        return (created, how)
    }
}

/// Keeps the identity as `identity.json` in a directory (the Mac CLI uses `.tvremote/`).
public struct FileIdentityStore: IdentityStore {
    private let fileURL: URL

    public init(directory: URL) {
        fileURL = directory.appendingPathComponent("identity.json")
    }

    public func load() throws -> ClientIdentity? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(ClientIdentity.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ identity: ClientIdentity) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try JSONEncoder().encode(identity).write(to: fileURL, options: .atomic)
        // The file holds a private key: owner-only.
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}

/// Keeps the JSON-encoded identity in the Keychain as a generic password that stays on this device.
public struct KeychainIdentityStore: IdentityStore {
    public struct KeychainError: Error, Equatable {
        public let status: OSStatus
    }

    private let service: String
    private let account: String

    public init(service: String = "com.dzafirov.tvskin.remote", account: String = "client-identity") {
        self.service = service
        self.account = account
    }

    public func load() throws -> ClientIdentity? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw KeychainError(status: status) }
        return try JSONDecoder().decode(ClientIdentity.self, from: data)
    }

    public func save(_ identity: ClientIdentity) throws {
        let data = try JSONEncoder().encode(identity)
        let updateStatus = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw KeychainError(status: updateStatus) }

        var add = baseQuery
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
