import Foundation

/// The TV this device has paired with, remembered between launches.
public struct PairedTV: Codable, Equatable {
    public var host: String
    public var name: String
    /// For Wake-on-LAN; the protocol never reports it, so it is only known for TVs listed in `knownMACs`.
    public var mac: String?

    public init(host: String, name: String, mac: String?) {
        self.host = host
        self.name = name
        self.mac = mac
    }

    /// MAC addresses of TVs known in advance, by IP address.
    static let knownMACs = ["192.168.8.16": "44:0f:b4:88:a4:9b"]
}

public protocol PairedTVStore {
    func load() -> PairedTV?
    /// Saves `tv`, or forgets the saved TV when it is nil.
    func save(_ tv: PairedTV?)
}

/// Keeps the paired TV as JSON under the key `pairedTV`.
public struct UserDefaultsPairedTVStore: PairedTVStore {
    static let key = "pairedTV"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// The saved TV; nil if none was saved or the saved data can't be read.
    public func load() -> PairedTV? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(PairedTV.self, from: data)
    }

    public func save(_ tv: PairedTV?) {
        guard let tv, let data = try? JSONEncoder().encode(tv) else {
            defaults.removeObject(forKey: Self.key)
            return
        }
        defaults.set(data, forKey: Self.key)
    }
}
