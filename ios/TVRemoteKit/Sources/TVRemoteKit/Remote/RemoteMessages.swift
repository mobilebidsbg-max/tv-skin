/// Field numbers of `RemoteMessage`, the one message type on the remote port (6466).
/// Each message on the wire sets exactly one of them (androidtvremote2's `remotemessage.proto`).
enum RemoteField {
    static let configure = 1
    static let setActive = 2
    static let error = 3
    static let pingRequest = 8
    static let pingResponse = 9
    static let keyInject = 10
    static let imeKeyInject = 20
    static let imeBatchEdit = 21
    static let start = 40
    static let setVolumeLevel = 50
    static let appLinkLaunch = 90
}

/// Messages this device sends on the remote port.
public enum RemoteOutbound {
    /// Device info sent with the configure reply; fixed values the TV expects from a remote.
    static let packageName = "atvremote"
    static let appVersion = "1.0.0"

    public static func key(_ k: KeyCode, _ d: KeyDirection) -> [UInt8] {
        message(RemoteField.keyInject) {
            $0.varint(1, int32(k.rawValue))
            $0.varint(2, int32(d.rawValue))
        }
    }

    public static func appLink(_ url: String) -> [UInt8] {
        message(RemoteField.appLinkLaunch) { $0.string(1, url) }
    }

    public static func configureReply(features: Int) -> [UInt8] {
        message(RemoteField.configure) { configure in
            configure.varint(1, int32(features))
            configure.message(2) { deviceInfo in
                deviceInfo.varint(3, 1)
                deviceInfo.string(4, "1")
                deviceInfo.string(5, packageName)
                deviceInfo.string(6, appVersion)
            }
        }
    }

    public static func setActiveReply(features: Int) -> [UInt8] {
        message(RemoteField.setActive) { $0.varint(1, int32(features)) }
    }

    public static func pingResponse(_ val1: Int) -> [UInt8] {
        message(RemoteField.pingResponse) { $0.varint(1, int32(val1)) }
    }

    /// Replaces the focused text field's contents with `text`, cursor at the end (as androidtvremote2 does).
    /// The counters come from the TV's latest `remote_ime_batch_edit`.
    public static func text(_ text: String, imeCounter: Int, fieldCounter: Int) -> [UInt8] {
        let cursor = text.count - 1
        return message(RemoteField.imeBatchEdit) { edit in
            edit.varint(1, int32(imeCounter))
            edit.varint(2, int32(fieldCounter))
            edit.message(3) { editInfo in
                editInfo.varint(1, 1)
                editInfo.message(2) { status in
                    status.varint(1, int32(cursor))
                    status.varint(2, int32(cursor))
                    status.string(3, text)
                }
            }
        }
    }

    private static func message(_ field: Int, _ build: (inout ProtoWriter) -> Void) -> [UInt8] {
        var writer = ProtoWriter()
        writer.message(field, build)
        return writer.bytes
    }

    /// protobuf `int32`: a negative value goes on the wire sign-extended to 64 bits.
    private static func int32(_ value: Int) -> UInt64 {
        UInt64(bitPattern: Int64(value))
    }
}

/// A message from the TV on the remote port.
public enum RemoteInbound: Equatable {
    /// The TV's supported features; answer with `configureReply`.
    case configure(code1: Int)
    /// Answer with `setActiveReply`.
    case setActive
    /// Keep-alive, about every 5 s; answer with `pingResponse(val1)`.
    case ping(val1: Int)
    /// The TV's power state: sent once after connecting and whenever it changes.
    case start(isOn: Bool)
    case volume(level: Int, max: Int, muted: Bool)
    /// A text field is focused; its counters are needed to type into it.
    case imeField(imeCounter: Int, fieldCounter: Int)
    /// Package of the app in the foreground.
    case currentApp(String)
    /// The TV rejected something this device sent.
    case error
    /// A message this client does not use.
    case unknown

    /// - Throws: `ProtoError` when the bytes are not a valid protobuf message.
    public static func parse(_ bytes: [UInt8]) throws -> RemoteInbound {
        let message = try ProtoMessage(bytes)
        if let configure = try message.message(RemoteField.configure) {
            return .configure(code1: int(configure.varint(1)))
        }
        if message.has(RemoteField.setActive) {
            return .setActive
        }
        if let ping = try message.message(RemoteField.pingRequest) {
            return .ping(val1: int(ping.varint(1)))
        }
        if let start = try message.message(RemoteField.start) {
            return .start(isOn: int(start.varint(1)) != 0)
        }
        if let volume = try message.message(RemoteField.setVolumeLevel) {
            return .volume(level: int(volume.varint(7)), max: int(volume.varint(6)), muted: int(volume.varint(8)) != 0)
        }
        if let edit = try message.message(RemoteField.imeBatchEdit) {
            return .imeField(imeCounter: int(edit.varint(1)), fieldCounter: int(edit.varint(2)))
        }
        if let inject = try message.message(RemoteField.imeKeyInject) {
            // app_info.app_package
            guard let app = try inject.message(1)?.string(12), !app.isEmpty else { return .unknown }
            return .currentApp(app)
        }
        if message.has(RemoteField.error) {
            return .error
        }
        return .unknown
    }

    /// A varint field as a signed integer; proto3 leaves zero values off the wire.
    private static func int(_ value: UInt64?) -> Int {
        Int(truncatingIfNeeded: value ?? 0)
    }
}
