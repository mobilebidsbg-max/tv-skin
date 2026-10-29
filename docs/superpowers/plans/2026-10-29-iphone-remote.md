# iPhone TV Remote Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** An iPhone app (black, Claude Code orange, dotted swipe touchpad, hidden controls) that pairs with and controls Dimitar's TCL Google TV over Google's Android TV Remote v2 protocol, installed on two iPhones.

**Architecture:** All logic lives in the Swift package `ios/TVRemoteKit`: a hand-written protobuf codec, pairing (port 6467) and remote sessions (port 6466) over SwiftNIO + NIOSSL TLS with a per-device self-signed client certificate, a pure gesture interpreter, and an observable `ConnectionManager` state machine behind protocols so it is unit-tested with fakes. A Mac CLI (`tvremote`) in the same package proves the protocol against the real TV before any iPhone is involved. The SwiftUI app in `ios/App` (XcodeGen) is a thin UI over `ConnectionManager`.

**Tech Stack:** Swift 6 toolchain (Xcode 26.6) in Swift 5 language mode, SwiftUI (iOS 17), SwiftNIO, swift-nio-ssl, swift-certificates (X509), swift-crypto `_CryptoExtras` (RSA), SwiftASN1, Network.framework (Bonjour), XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-29-iphone-remote-design.md` (visual reference: `docs/design/mockup-remote.html`).

## Global Constraints

- iOS deployment target 17.0, iPhone only (`TARGETED_DEVICE_FAMILY = 1`), portrait only, dark appearance. Package also builds for macOS 14 (CLI + tests).
- Bundle ID `com.dzafirov.tvskin.remote`, display name `TV Remote`. Signing: free Apple ID, automatic signing.
- Colors: background `#000000`; surfaces `#0A0A0A` / `#141414` / `#1A1A1A`; hairline `#222222`; text `#F2F2F2`, secondary `#8A8A8E`; idle dot `#2C2C2E`; accent (Claude Code orange) `#D97757`. Orange appears only on touch feedback, play/pause, power and the connection dot.
- Protocol constants: pairing port `6467`, remote port `6466`, Bonjour type `_androidtvremote2._tcp`, pairing `service_name` `"atvremote"`, code = 6 hex chars, requested features `615` (PING 1 | KEY 2 | IME 4 | POWER 32 | VOLUME 64 | APP_LINK 512). Every message is a protobuf payload prefixed by its length as a varint.
- Each device generates its own RSA-2048 client certificate (CN `atvremote`) on first launch and keeps it (iOS: Keychain generic password, service `com.dzafirov.tvskin.remote`, account `client-identity`; CLI: `ios/TVRemoteKit/.tvremote/`).
- TV under test: `192.168.8.16`, MAC `44:0f:b4:88:a4:9b`. **Live steps take over the TV: ask Dimitar before running them.** Read pairing codes from `adb -s 192.168.8.16:5555 exec-out screencap -p > /tmp/tv.png`.
- Apps installed on the TV (2026-10-29): YouTube, YouTube Music, Netflix, Prime Video, Apple TV, Disney+. Not installed: Spotify, HBO Max, Twitch. Shortcuts use only installed apps.
- UI copy is English. No secrets in git (`.env` is ignored).
- Every commit: `git -c user.name="mobilebidsbg-max" -c user.email="mobilebidsbg@gmail.com" commit` with message ending `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Commit with explicit paths.

## Review Focus

1. **TV off, in standby or unplugged:** the header says "TV is off" or "Can't reach the TV", retries back off and never spin forever, and Power sends Wake-on-LAN then reconnects. Tests: Task 6 `testUnreachableRetriesWithBackoff`, `testPowerWhenUnreachableWakesAndReconnects`.
2. **App locked or backgrounded and reopened, Wi-Fi blip:** exactly one reconnect when it comes back, never two parallel sessions. Test: Task 6 `testBackgroundThenActiveReconnectsExactlyOnce`.
3. **TV forgot the pairing (reset, remote removed):** goes straight to pairing, no retry loop. Test: Task 6 `testNotPairedGoesToNeedsPairingWithoutRetry`.
4. **Code typed in lowercase, with spaces or a letter O, or simply wrong:** it is normalized, and a wrong code is caught locally with a clear retry instead of a dead session. Tests: Task 2 `testCodeNormalization`, `testSecretRejectsWrongCode`; Task 6 `testBadCodeKeepsPairingOpen`.
5. **Local Network permission denied:** explains and links to Settings, no retry loop. Test: Task 6 `testLocalNetworkDeniedStopsRetrying`.

---

### Task 1: Package skeleton and protobuf codec

**Files:**
- Create: `ios/TVRemoteKit/Package.swift`
- Create: `ios/TVRemoteKit/Sources/TVRemoteKit/Proto/ProtoWriter.swift`, `ProtoReader.swift`, `Framing.swift`
- Create: `ios/TVRemoteKit/Sources/tvremote/main.swift` (prints usage only for now)
- Test: `ios/TVRemoteKit/Tests/TVRemoteKitTests/ProtoTests.swift`, `FramingTests.swift`

**Interfaces:**
- Produces:
  - `struct ProtoWriter { var bytes: [UInt8]; mutating func varint(_ field: Int, _ value: UInt64); mutating func bool(_ field: Int, _ value: Bool); mutating func string(_ field: Int, _ value: String); mutating func bytes(_ field: Int, _ value: [UInt8]); mutating func message(_ field: Int, _ build: (inout ProtoWriter) -> Void) }`
  - `struct ProtoMessage { init(_ bytes: [UInt8]) throws; func has(_ field: Int) -> Bool; func varint(_ field: Int) -> UInt64?; func bytes(_ field: Int) -> [UInt8]?; func string(_ field: Int) -> String?; func message(_ field: Int) throws -> ProtoMessage?; var fieldNumbers: [Int] }` (skips wire types 1 and 5; last value wins for repeated scalars)
  - `enum Framing { static func frame(_ payload: [UInt8]) -> [UInt8] }`, `struct FrameDecoder { mutating func append(_ bytes: [UInt8]); mutating func next() throws -> [UInt8]? }`
  - `enum ProtoError: Error, Equatable { case truncated, malformedVarint, frameTooLarge, unsupportedWireType(Int) }`

- [ ] **Step 1: Write `Package.swift`**: `// swift-tools-version: 5.10`, platforms `.iOS(.v17), .macOS(.v14)`, products `library TVRemoteKit` and `executable tvremote`. Dependencies: `swift-nio` from `2.65.0`, `swift-nio-ssl` from `2.27.0`, `swift-certificates` from `1.5.0`, `swift-crypto` from `3.4.0`, `swift-asn1` from `1.1.0`. Target `TVRemoteKit` depends on `NIOCore`, `NIOPosix`, `NIOSSL`, `X509`, `_CryptoExtras`, `SwiftASN1`. Run `swift package resolve` in `ios/TVRemoteKit`. Expected: resolves without errors.
- [ ] **Step 2: Write failing tests** (golden bytes computed from the reference implementation's field numbers):

```swift
func testWriterEncodesKeyInject() {
    var w = ProtoWriter()
    w.message(10) { $0.varint(1, 19); $0.varint(2, 3) }
    XCTAssertEqual(w.bytes.hex, "520408131003")
}
func testWriterEncodesPingResponse() { var w = ProtoWriter(); w.message(9) { $0.varint(1, 5) }; XCTAssertEqual(w.bytes.hex, "4a020805") }
func testWriterEncodesMultiByteFieldTag() { var w = ProtoWriter(); w.message(90) { $0.string(1, "https://www.youtube.com") }
    XCTAssertEqual(w.bytes.hex, "d205190a1768747470733a2f2f7777772e796f75747562652e636f6d") }
func testReaderParsesVolume() throws {
    let m = try ProtoMessage(Array(hex: "92030b1a0354434c3064380c4000")).message(50)!
    XCTAssertEqual(m.varint(6), 100); XCTAssertEqual(m.varint(7), 12); XCTAssertEqual(m.varint(8), 0); XCTAssertEqual(m.string(3), "TCL")
}
func testReaderRejectsTruncated() { XCTAssertThrowsError(try ProtoMessage(Array(hex: "5204081310"))) }
func testFrameAddsVarintLength() { XCTAssertEqual(Framing.frame(Array(hex: "520408131003")).hex, "06520408131003") }
func testDecoderHandlesByteByByte() throws { /* two frames fed one byte at a time → next() returns both payloads in order, nil in between */ }
func testDecoderHandlesTwoFramesInOneChunk() throws { /* "0206520408131003" style chunk containing frames A and B → A then B then nil */ }
func testDecoderHandles300ByteFrame() throws { /* payload of 300 bytes → 2-byte varint length "ac02" → decodes */ }
func testDecoderRejectsHugeFrame() { /* length varint > 1_048_576 → throws .frameTooLarge */ }
```
  Add test helpers `extension Array where Element == UInt8 { init(hex: String); var hex: String }` in `Tests/TVRemoteKitTests/Hex.swift`.
- [ ] **Step 3: Run** `swift test --filter ProtoTests` and `--filter FramingTests` in `ios/TVRemoteKit`. Expected: compile failure (types missing).
- [ ] **Step 4: Implement** `ProtoWriter`, `ProtoMessage`, `Framing`, `FrameDecoder`. Max frame size 1 MiB.
- [ ] **Step 5: Run** `swift test`. Expected: all pass.
- [ ] **Step 6: Commit** `ios/TVRemoteKit` with message "TVRemoteKit: package skeleton and protobuf codec".

### Task 2: Pairing messages, pairing secret, client identity

**Files:**
- Create: `Sources/TVRemoteKit/Pairing/PoloMessages.swift`, `PairingCode.swift`, `PairingSecret.swift`
- Create: `Sources/TVRemoteKit/Identity/ClientIdentity.swift`, `RSAPublicNumbers.swift`, `IdentityStore.swift`
- Test: `Tests/TVRemoteKitTests/PoloTests.swift`, `PairingSecretTests.swift`, `IdentityTests.swift`

**Interfaces:**
- Consumes: `ProtoWriter`, `ProtoMessage` (Task 1).
- Produces:
  - `enum PoloMessage { static func pairingRequest(clientName: String) -> [UInt8]; static func options() -> [UInt8]; static func configuration() -> [UInt8]; static func secret(_ secret: [UInt8]) -> [UInt8] }`. Every message carries `protocol_version = 2` (field 1) and `status = 200` (field 2). Field numbers: pairing_request 10 {service_name 1, client_name 2}, options 20 {input_encodings 1 {type 1, symbol_length 2}, preferred_role 3}, configuration 30 {encoding 1, client_role 2}, configuration_ack 31, secret 40 {secret 1}, secret_ack 41, pairing_request_ack 11. Encoding type HEXADECIMAL = 3, symbol_length 6, role INPUT = 1.
  - `struct PoloReply: Equatable { enum Kind { case pairingRequestAck, options, configurationAck, secretAck, other } let status: Int; let kind: Kind; static func parse(_ bytes: [UInt8]) throws -> PoloReply }`
  - `enum PairingCode { static func normalize(_ input: String) -> String? }`: trims whitespace and inner spaces, uppercases, maps letter `O` to `0`, then requires exactly 6 hex characters.
  - `struct RSAPublicNumbers: Equatable { let modulus: [UInt8]; let exponent: [UInt8]; init(modulus:exponent:) (strips leading zero bytes); init(pkcs1DER: [UInt8]) throws; init(certificateDER: [UInt8]) throws }`. The certificate init reads the SubjectPublicKeyInfo with `X509.Certificate(derEncoded:)` and parses the BIT STRING's PKCS#1 `RSAPublicKey` with SwiftASN1.
  - `enum PairingSecret { static func compute(client: RSAPublicNumbers, server: RSAPublicNumbers, code: String) throws -> [UInt8] }`. It hashes SHA-256(client.modulus ‖ client.exponent ‖ server.modulus ‖ server.exponent ‖ hexBytes(code[2..<6])), and throws `PairingError.codeMismatch` when `digest[0] != hexByte(code[0..<2])`.
  - `struct ClientIdentity: Codable, Equatable { let certificatePEM: String; let privateKeyPEM: String; static func generate(commonName: String = "atvremote") throws -> ClientIdentity; func publicNumbers() throws -> RSAPublicNumbers }`. It uses `_RSA.Signing.PrivateKey(keySize: .bits2048)` and a self-signed `X509.Certificate` (v3, sha256WithRSAEncryption, valid from now − 1 day to now + 20 years).
  - `protocol IdentityStore { func load() throws -> ClientIdentity?; func save(_ identity: ClientIdentity) throws }`, `struct FileIdentityStore: IdentityStore { init(directory: URL) }` (writes `identity.json`), `struct KeychainIdentityStore: IdentityStore { init(service: String = "com.dzafirov.tvskin.remote", account: String = "client-identity") }`, `extension IdentityStore { func loadOrCreate() throws -> ClientIdentity }`.
  - `enum PairingError: Error, Equatable { case codeMismatch, invalidCode }`

- [ ] **Step 1: Write failing tests:**

```swift
func testPairingRequestBytes() { XCTAssertEqual(PoloMessage.pairingRequest(clientName: "test").hex, "080210c80152110a0961747672656d6f7465120474657374") }
func testOptionsBytes() { XCTAssertEqual(PoloMessage.options().hex, "080210c801a201080a04080310061801") }
func testConfigurationBytes() { XCTAssertEqual(PoloMessage.configuration().hex, "080210c801f201080a04080310061001") }
func testParseConfigurationAck() throws { XCTAssertEqual(try PoloReply.parse(Array(hex: "080210c801fa0100")), PoloReply(status: 200, kind: .configurationAck)) }
func testParseBadSecretStatus() throws { XCTAssertEqual(try PoloReply.parse(Array(hex: "0802109203")), PoloReply(status: 402, kind: .other)) }
func testCodeNormalization() {
    XCTAssertEqual(PairingCode.normalize(" 65a1b2 "), "65A1B2"); XCTAssertEqual(PairingCode.normalize("65 A1 B2"), "65A1B2")
    XCTAssertEqual(PairingCode.normalize("65a1o2"), "65A102"); XCTAssertNil(PairingCode.normalize("65A1B")); XCTAssertNil(PairingCode.normalize("65A1BZ"))
}
func testSecretMatchesReferenceVector() throws {
    let c = RSAPublicNumbers(modulus: Array(hex: "c0ffee1122334455"), exponent: [1, 0, 1])
    let s = RSAPublicNumbers(modulus: Array(hex: "badc0de566778899"), exponent: [1, 0, 1])
    XCTAssertEqual(try PairingSecret.compute(client: c, server: s, code: "65A1B2").hex, "65492b92b6551b868bee5fa9528db204d75f838705a733aeb53f40d41610d974")
}
func testSecretRejectsWrongCode() { /* same numbers, code "66A1B2" → throws PairingError.codeMismatch */ }
func testModulusStripsLeadingZero() { XCTAssertEqual(RSAPublicNumbers(modulus: [0, 0xC0, 1], exponent: [0, 1, 0, 1]).modulus, [0xC0, 1]) }
func testGeneratedIdentityIsSelfSignedRSA2048() throws {
    let id = try ClientIdentity.generate(); let n = try id.publicNumbers()
    XCTAssertEqual(n.modulus.count, 256); XCTAssertEqual(n.exponent, [1, 0, 1])
    let cert = try X509.Certificate(pemEncoded: id.certificatePEM)
    XCTAssertEqual(cert.subject.description, "CN=atvremote"); XCTAssertEqual(try RSAPublicNumbers(certificateDER: try cert.serializeAsPEM().derBytes), n)
}
func testFileIdentityStoreRoundTrip() throws { /* temp dir → loadOrCreate twice returns equal identities */ }
```
- [ ] **Step 2: Run** `swift test --filter "PoloTests|PairingSecretTests|IdentityTests"`. Expected: fail to compile.
- [ ] **Step 3: Implement** the files above. `KeychainIdentityStore` stores the JSON-encoded identity as `kSecClassGenericPassword` with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` (no unit test; it is exercised on device in Task 11).
- [ ] **Step 4: Run** `swift test`. Expected: all pass.
- [ ] **Step 5: Commit** "TVRemoteKit: pairing messages, secret and client identity".

### Task 3: TLS channel, pairing session, `tvremote pair` (live)

**Files:**
- Create: `Sources/TVRemoteKit/Link/TLSChannel.swift`, `PairingSession.swift`, `TVLinkError.swift`
- Modify: `Sources/tvremote/main.swift`
- Test: `Tests/TVRemoteKitTests/ErrorMappingTests.swift`

**Interfaces:**
- Consumes: `Framing`, `FrameDecoder` (Task 1); `PoloMessage`, `PoloReply`, `PairingSecret`, `PairingCode`, `ClientIdentity`, `RSAPublicNumbers`, `IdentityStore` (Task 2).
- Produces:
  - `enum TVLinkError: Error, Equatable { case unreachable, notPaired, timeout, closed, badCode, localNetworkDenied, noTextField, protocolError(String) }` and `static func map(_ error: Error, port: Int) -> TVLinkError`. An NIOSSL handshake failure or an unexpected-EOF/connection-reset before the first message on port 6466 maps to `.notPaired`. `ECONNREFUSED`, `EHOSTUNREACH`, `ENETUNREACH` and connect timeouts map to `.unreachable`. Status 402 during pairing maps to `.badCode`.
  - `final class TLSChannel { static func connect(host: String, port: Int, identity: ClientIdentity, timeout: TimeInterval = 5) async throws -> TLSChannel; let messages: AsyncThrowingStream<[UInt8], Error>; func send(_ payload: [UInt8]); func peerCertificateDER() async throws -> [UInt8]; func close() }`. It uses one shared `MultiThreadedEventLoopGroup.singleton`, a client `TLSConfiguration` with `certificateVerification = .none` and `minimumTLSVersion = .tlsv12`, the identity's certificate and key loaded from PEM, and a handler that frames outbound payloads and decodes inbound frames with `FrameDecoder`.
  - `final class PairingSession { init(host: String, identity: ClientIdentity, clientName: String); func start() async throws; func finish(code: String) async throws; func cancel() }`. `start()` connects to 6467, then sends pairingRequest, options after pairingRequestAck, and configuration after options, and returns at configurationAck (the code is now on the TV). `finish` normalizes the code and computes the secret (an invalid or locally mismatching code throws `.badCode` without sending anything) from `identity.publicNumbers()` and the peer certificate, sends it, and waits for secretAck (10 s timeout).

- [ ] **Step 1: Write failing tests** for `TVLinkError.map`: `NIOSSLError.handshakeFailed(...)` on port 6466 → `.notPaired`; `IOError(errnoCode: ECONNREFUSED, ...)` → `.unreachable`; `IOError(errnoCode: EHOSTUNREACH, ...)` → `.unreachable`; `ChannelError.connectTimeout(.seconds(5))` → `.unreachable`.
- [ ] **Step 2: Run** `swift test --filter ErrorMappingTests`. Expected: fail to compile.
- [ ] **Step 3: Implement** `TVLinkError`, `TLSChannel`, `PairingSession`.
- [ ] **Step 4: Run** `swift test`. Expected: all pass.
- [ ] **Step 5: Implement `tvremote pair --host <ip> [--name <client name>] [--code-file <path>]`** in `main.swift` (plain `CommandLine.arguments` parsing, no extra dependency). Identity comes from `FileIdentityStore(directory: <package dir>/.tvremote)`. After `start()` it prints `CODE_ON_TV` and reads the code from `--code-file` (polls every 0.5 s, up to 120 s) or else stdin. It prints `PAIRED` on success, or the error name and exit code 1.
- [ ] **Step 6: Live check (ask Dimitar first; the TV shows a pairing dialog):** run `swift run tvremote pair --host 192.168.8.16 --name "tv-skin Mac" --code-file /tmp/tvcode.txt` in the background. When it prints `CODE_ON_TV`, take `adb -s 192.168.8.16:5555 exec-out screencap -p > /tmp/tv.png`, read the 6-character code from the image, and `echo <code> > /tmp/tvcode.txt`. Expected output: `PAIRED`. Then repeat with a deliberately wrong code (flip the last character). Expected: `badCode` or `codeMismatch` reported without hanging, and the TV dialog is dismissed or stays recoverable.
- [ ] **Step 7: Commit** "TVRemoteKit: TLS channel, pairing session and tvremote pair".

### Task 4: Remote session, key codes, app shortcuts, `tvremote` commands (live)

**Files:**
- Create: `Sources/TVRemoteKit/Remote/RemoteMessages.swift`, `KeyCode.swift`, `RemoteSession.swift`, `AppShortcut.swift`, `WakeOnLAN.swift`
- Modify: `Sources/tvremote/main.swift`
- Test: `Tests/TVRemoteKitTests/RemoteMessageTests.swift`, `WakeOnLANTests.swift`

**Interfaces:**
- Consumes: `TLSChannel`, `TVLinkError` (Task 3); `ProtoWriter`/`ProtoMessage` (Task 1).
- Produces:
  - `enum KeyCode: Int { case home = 3, back = 4, dpadUp = 19, dpadDown = 20, dpadLeft = 21, dpadRight = 22, dpadCenter = 23, volumeUp = 24, volumeDown = 25, power = 26, enter = 66, del = 67, search = 84, playPause = 85, stop = 86, next = 87, previous = 88, rewind = 89, fastForward = 90, mute = 164, captions = 175, settings = 176, tvInput = 178, hdmi1 = 243, hdmi2 = 244, hdmi3 = 245, skipForward = 272, skipBackward = 273, allApps = 284 }`, with `init?(name:)` accepting `UP DOWN LEFT RIGHT OK BACK HOME …` for the CLI.
  - `enum Seek { static let forward: KeyCode; static let backward: KeyCode }`: values decided in Step 7.
  - `enum KeyDirection: Int { case startLong = 1, endLong = 2, short = 3 }`
  - `enum RemoteOutbound { static func key(_ k: KeyCode, _ d: KeyDirection) -> [UInt8]; static func appLink(_ url: String) -> [UInt8]; static func configureReply(features: Int) -> [UInt8]; static func setActiveReply(features: Int) -> [UInt8]; static func pingResponse(_ val1: Int) -> [UInt8]; static func text(_ text: String, imeCounter: Int, fieldCounter: Int) -> [UInt8] }`. Field numbers: configure 1 {code1 1, device_info 2 {unknown1 3 = 1, unknown2 4 = "1", package_name 5 = "atvremote", app_version 6 = "1.0.0"}}, set_active 2 {active 1}, ping_request 8 {val1 1}, ping_response 9 {val1 1}, key_inject 10 {key_code 1, direction 2}, ime_key_inject 20 {app_info 1 {app_package 12}}, ime_batch_edit 21 {ime_counter 1, field_counter 2, edit_info 3 {insert 1 = 1, text_field_status 2 {start 1, end 2, value 3}}}, start 40 {started 1}, set_volume_level 50 {volume_max 6, volume_level 7, volume_muted 8}, app_link 90 {app_link 1}. Text uses `start = end = text.count - 1`.
  - `enum RemoteInbound: Equatable { case configure(code1: Int), setActive, ping(val1: Int), start(isOn: Bool), volume(level: Int, max: Int, muted: Bool), imeField(imeCounter: Int, fieldCounter: Int), currentApp(String), error, unknown; static func parse(_ bytes: [UInt8]) throws -> RemoteInbound }`
  - `enum RemoteEvent: Equatable { case ready(isOn: Bool), power(isOn: Bool), volume(level: Int, max: Int, muted: Bool), textField(available: Bool), currentApp(String), closed(TVLinkError) }`
  - `final class RemoteSession { static func open(host: String, identity: ClientIdentity) async throws -> RemoteSession; let events: AsyncStream<RemoteEvent>; func send(_ key: KeyCode, _ direction: KeyDirection = .short); func launch(appLink: String); func type(_ text: String) throws (throws .noTextField before any imeField); func close() }`. It answers configure (features `615 & code1`), setActive and ping by itself. `open` returns after the first `start` message (5 s timeout), so `.ready(isOn:)` is the first event. With no inbound message for 16 s it closes with `.closed(.timeout)`.
  - `struct AppShortcut: Identifiable, Equatable { let id: String; let name: String; let link: String?; let key: KeyCode?; let tint: String; static let all: [AppShortcut] }`. There are 8 entries in this order: YouTube, Netflix, Prime Video, Apple TV, Disney+, YouTube Music, Home (key `.home`), All apps (key `.allApps`). Links are finalized in Step 7.
  - `enum WakeOnLAN { static func packet(mac: String) throws -> [UInt8]; static func send(mac: String) async throws }` (UDP broadcast to `255.255.255.255:9` with `SO_BROADCAST`).

- [ ] **Step 1: Write failing tests:**

```swift
func testKeyInjectBytes() { XCTAssertEqual(RemoteOutbound.key(.dpadUp, .short).hex, "520408131003") }
func testConfigureReplyBytes() { XCTAssertEqual(RemoteOutbound.configureReply(features: 615).hex, "0a1c08e704121718012201312a0961747672656d6f74653205312e302e30") }
func testSetActiveReplyBytes() { XCTAssertEqual(RemoteOutbound.setActiveReply(features: 615).hex, "120308e704") }
func testAppLinkBytes() { XCTAssertEqual(RemoteOutbound.appLink("https://www.youtube.com").hex, "d205190a1768747470733a2f2f7777772e796f75747562652e636f6d") }
func testTextBytes() { XCTAssertEqual(RemoteOutbound.text("hello", imeCounter: 4, fieldCounter: 7).hex, "aa0115080410071a0f0801120b080410041a0568656c6c6f") }
func testParsePing() throws { XCTAssertEqual(try RemoteInbound.parse(Array(hex: "4204082a1000")), .ping(val1: 42)) }
func testParseStart() throws { XCTAssertEqual(try RemoteInbound.parse(Array(hex: "c202020801")), .start(isOn: true)) }
func testParseVolume() throws { XCTAssertEqual(try RemoteInbound.parse(Array(hex: "92030b1a0354434c3064380c4000")), .volume(level: 12, max: 100, muted: false)) }
func testWakePacket() throws { let p = try WakeOnLAN.packet(mac: "44:0f:b4:88:a4:9b"); XCTAssertEqual(p.count, 102); XCTAssertEqual(Array(p[0..<6]), Array(repeating: 0xFF, count: 6)); XCTAssertEqual(Array(p[96..<102]), [0x44, 0x0f, 0xb4, 0x88, 0xa4, 0x9b]) }
func testWakePacketRejectsBadMac() { XCTAssertThrowsError(try WakeOnLAN.packet(mac: "44:0f:b4")) }
```
- [ ] **Step 2: Run** `swift test --filter "RemoteMessageTests|WakeOnLANTests"`. Expected: fail to compile.
- [ ] **Step 3: Implement** the files above.
- [ ] **Step 4: Run** `swift test`. Expected: all pass.
- [ ] **Step 5: Add CLI commands:** `tvremote key --host H <NAME> [--long]`, `tvremote app --host H <url>`, `tvremote text --host H <text>`, `tvremote watch --host H [--seconds N]` (prints each `RemoteEvent`), `tvremote wake --mac M`.
- [ ] **Step 6: Live check (ask Dimitar first):**
  - `swift run tvremote watch --host 192.168.8.16 --seconds 20`. Expected: `ready(isOn: true)` and a `volume(...)` line, and it stays open across at least 3 server pings.
  - `tvremote key HOME`, then `adb -s 192.168.8.16:5555 shell dumpsys activity activities | grep -m1 topResumedActivity`. Expected: `com.google.android.apps.tv.launcherx`. Then `tvremote key DOWN`, `RIGHT`, `OK`, and confirm the focus moved with a screenshot.
  - `tvremote key OK --long`. Expected: a long-press menu on the focused tile.
- [ ] **Step 7: Decide the seek keys and app links on the real TV:**
  - Start a YouTube video (`tvremote app "https://www.youtube.com/watch?v=aqz-KE-bpKQ"`), then try `fastForward`, `skipForward` and `dpadRight` one at a time. Read the position each time from `adb shell dumpsys media_session | grep -m1 "position="`. Set `Seek.forward/backward` to the pair that jumps about 10 s. If none does, use `dpadRight/dpadLeft` and note it.
  - For each app, run `tvremote app <link>` and check `topResumedActivity` for its package: YouTube `https://www.youtube.com` (`com.google.android.youtube.tv`), Netflix `https://www.netflix.com/title` (`com.netflix.ninja`), Prime Video `https://app.primevideo.com` (`com.amazon.amazonvideo.livingroom`), Apple TV `https://tv.apple.com` (`com.apple.atve.androidtv.appletv`), Disney+ `https://www.disneyplus.com` (`com.disney.disneyplus`), YouTube Music `https://music.youtube.com` (`com.google.android.youtube.tvmusic`). If a link fails, try `market://launch?id=<package>`. Write the working link into `AppShortcut.all`.
  - Typing: `tvremote key SEARCH`, wait 2 s, `tvremote text "lofi"`. Expected: "lofi" appears in the search field (screenshot). If `noTextField`, select the YouTube search box with keys first and retry. Record which works in the commit message.
- [ ] **Step 8: Commit** "TVRemoteKit: remote session, key codes, app shortcuts, CLI commands" (include the seek/link findings in the body).

### Task 5: Gesture interpreter

**Files:**
- Create: `Sources/TVRemoteKit/Gestures/GestureInterpreter.swift`
- Test: `Tests/TVRemoteKitTests/GestureInterpreterTests.swift`

**Interfaces:**
- Consumes: `KeyCode`, `Seek` (Task 4).
- Produces:
  - `struct TouchSample: Equatable { let id: Int; let location: CGPoint; let time: TimeInterval }`
  - `enum RemoteCommand: Equatable { case key(KeyCode); case longStart(KeyCode); case longEnd(KeyCode) }`
  - `struct GestureConfig { var stepDistance: CGFloat = 44; var tapMaxDuration: TimeInterval = 0.25; var tapMaxMovement: CGFloat = 10; var longPressDelay: TimeInterval = 0.5; var edgeWidth: CGFloat = 28; var volumeStep: CGFloat = 24; var twoFingerSwipeDistance: CGFloat = 60; var flickVelocity1: CGFloat = 1500; var flickVelocity2: CGFloat = 2500; var maxKeysPerSecond: Int = 20; static let `default` = GestureConfig() }`
  - `final class GestureInterpreter { init(size: CGSize, config: GestureConfig = .default); func began(_ touches: [TouchSample]) -> [RemoteCommand]; func moved(_ touches: [TouchSample]) -> [RemoteCommand]; func ended(_ touches: [TouchSample]) -> [RemoteCommand]; func tick(now: TimeInterval) -> [RemoteCommand]; func cancelAll() -> [RemoteCommand] }`
- Rules: one finger, moving by `stepDistance` along the dominant axis, emits one d-pad key and re-anchors. A release faster than `flickVelocity1`/`flickVelocity2` adds 1 or 2 extra steps in that direction. A tap emits `.key(.dpadCenter)`. A press held still for `longPressDelay` emits `.longStart(.dpadCenter)`, and its release emits `.longEnd(.dpadCenter)`. A touch that begins within `edgeWidth` of the right edge enters volume mode: every `volumeStep` up or down emits `volumeUp`/`volumeDown`, and no d-pad keys. A two-finger tap emits `.key(.playPause)`. A two-finger horizontal move beyond `twoFingerSwipeDistance` emits one `.key(Seek.forward)` (right) or `.key(Seek.backward)` (left) per gesture. Key output is capped at `maxKeysPerSecond` over a rolling second (extra steps are dropped). `cancelAll` ends an active long press.

- [ ] **Step 1: Write failing tests** (size 360×480; times in seconds):

```swift
func testSwipeRightEmitsOneKeyPerStep() // began (100,200)@0 → moved (190,205)@0.1 → [.key(.dpadRight), .key(.dpadRight)]
func testDiagonalUsesDominantAxis()     // moved (130,250) from (100,200) → [.key(.dpadDown)]
func testTapEmitsCenter()               // began@0, ended same point @0.1 → [.key(.dpadCenter)]
func testHoldEmitsLongStartThenEnd()    // began@0, tick(now: 0.6) → [.longStart(.dpadCenter)], ended@0.9 → [.longEnd(.dpadCenter)]
func testMovedPressIsNotLongPress()     // began, moved 50pt @0.2, tick(0.6) → no longStart
func testTwoFingerTapEmitsPlayPause()   // two touches began@0, ended@0.15 without moving → [.key(.playPause)]
func testTwoFingerSwipeLeftSeeksBackOnce() // both move −90pt → exactly one .key(Seek.backward)
func testRightEdgeSlideControlsVolume() // began (345,300) → moved (345,250) → [.key(.volumeUp), .key(.volumeUp)], no d-pad
func testFastFlickAddsExtraStep()       // 50pt right in 0.025s then ended → 1 step + 1 extra (velocity 2000)
func testBurstIsRateLimited()           // 2000pt right within 0.5s → at most 10 keys
```
- [ ] **Step 2: Run** `swift test --filter GestureInterpreterTests`. Expected: fail.
- [ ] **Step 3: Implement** `GestureInterpreter`.
- [ ] **Step 4: Run** `swift test`. Expected: all pass.
- [ ] **Step 5: Commit** "TVRemoteKit: gesture interpreter".

### Task 6: Connection manager (state machine)

**Files:**
- Create: `Sources/TVRemoteKit/App/ConnectionManager.swift`, `PairedTV.swift`, `TVLinking.swift`
- Test: `Tests/TVRemoteKitTests/ConnectionManagerTests.swift` (with `FakeLink`, `FakeChannel`, `FakeStore`, `FakeWaker`)

**Interfaces:**
- Consumes: `RemoteSession`, `PairingSession`, `RemoteEvent`, `TVLinkError`, `KeyCode`, `KeyDirection`, `AppShortcut`, `WakeOnLAN`, `IdentityStore` (Tasks 2–4); `RemoteCommand` (Task 5).
- Produces:
  - `struct VolumeInfo: Equatable { let level: Int; let max: Int; let muted: Bool }`
  - `struct PairedTV: Codable, Equatable { var host: String; var name: String; var mac: String? }`, `protocol PairedTVStore { func load() -> PairedTV?; func save(_ tv: PairedTV?) }`, `struct UserDefaultsPairedTVStore: PairedTVStore` (key `pairedTV`).
  - `protocol RemoteChannel: AnyObject { var events: AsyncStream<RemoteEvent> { get }; func send(_ key: KeyCode, _ direction: KeyDirection); func launch(appLink: String); func type(_ text: String) throws; func close() }` (`RemoteSession` conforms).
  - `protocol PairingChannel: AnyObject { func start() async throws; func finish(code: String) async throws; func cancel() }` (`PairingSession` conforms).
  - `protocol TVLinking { func openRemote(host: String) async throws -> RemoteChannel; func pairing(host: String) -> PairingChannel; func wake(mac: String) async throws }`, `struct LiveLink: TVLinking { init(identityStore: IdentityStore, clientName: String) }`.
  - `@MainActor @Observable final class ConnectionManager { enum State: Equatable { case noTV, connecting, connected(tvOn: Bool), unreachable, needsPairing, pairing(PairingStep), localNetworkDenied }; enum PairingStep: Equatable { case connecting, enterCode, checking, wrongCode, failed(String) }; private(set) var state: State; private(set) var tv: PairedTV?; private(set) var volume: VolumeInfo?; private(set) var canType: Bool; init(link: TVLinking, store: PairedTVStore, sleep: @escaping (TimeInterval) async -> Void = { try? await Task.sleep(for: .seconds($0)) }); func appBecameActive(); func appWentBackground(); func perform(_ command: RemoteCommand); func press(_ key: KeyCode); func open(_ app: AppShortcut); func type(_ text: String); func power(); func startPairing(host: String, name: String) async; func submitCode(_ code: String) async; func forgetTV(); func localNetworkDenied() }`
- Behavior: reconnect delays `[1, 2, 4, 8, 10, 10, …]` seconds while active. A `.notPaired` result stops retries and sets `.needsPairing`. `appWentBackground` closes the channel and cancels retries. `appBecameActive` starts at most one connect (a second call while connecting is ignored). `power()` sends `.power` when connected; when unreachable with a known MAC it calls `wake(mac:)` and then reconnects after 3 s. `submitCode` with `.badCode`/`codeMismatch` sets `.pairing(.wrongCode)` and keeps the session for retry. On success it saves the TV with `mac = "44:0f:b4:88:a4:9b"` when `host == "192.168.8.16"` (known TV) and connects.

- [ ] **Step 1: Write failing tests:**

```swift
func testConnectsAndReportsTvOn()                       // channel emits .ready(isOn: true) → state == .connected(tvOn: true)
func testUnreachableRetriesWithBackoff()                // openRemote throws .unreachable ×2 then succeeds → recorded sleeps == [1, 2], final state .connected(tvOn: true)
func testNotPairedGoesToNeedsPairingWithoutRetry()      // throws .notPaired → state .needsPairing, openRemote called once
func testBackgroundThenActiveReconnectsExactlyOnce()    // connected → appWentBackground (channel.closed == true) → appBecameActive ×2 → openRemote count +1
func testPowerWhenUnreachableWakesAndReconnects()       // state .unreachable, tv.mac set → power() → waker got "44:0f:b4:88:a4:9b", then openRemote called again
func testBadCodeKeepsPairingOpen()                      // pairing.finish throws .badCode → state .pairing(.wrongCode); second submitCode succeeds → .connected
func testLocalNetworkDeniedStopsRetrying()              // localNetworkDenied() during retries → state .localNetworkDenied, no further openRemote
func testPerformMapsCommandsToKeys()                    // perform(.longStart(.dpadCenter)) → channel got (dpadCenter, startLong)
func testTypeWithoutTextFieldDoesNotCrash()             // channel.type throws .noTextField → canType == false, state unchanged
```
- [ ] **Step 2: Run** `swift test --filter ConnectionManagerTests`. Expected: fail.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run** `swift test`. Expected: all pass.
- [ ] **Step 5: Commit** "TVRemoteKit: connection manager".

### Task 7: iOS app scaffold and app icon

**Files:**
- Create: `ios/App/project.yml`, `ios/App/TVRemote/TVRemoteApp.swift`, `RootView.swift`, `Theme.swift`, `DemoLink.swift`
- Create: `ios/App/TVRemote/Assets.xcassets/AppIcon.appiconset/{Contents.json, icon-1024.png, icon-1024-dark.png, icon-1024-tinted.png}`, `Assets.xcassets/Contents.json`
- Create: `ios/icon/icon.html` (generator), `ios/icon/render.sh`

**Interfaces:**
- Consumes: `ConnectionManager`, `LiveLink`, `KeychainIdentityStore`, `UserDefaultsPairedTVStore` (Tasks 2, 6).
- Produces: `enum Theme { static let background, surface, surface2, surface3, hairline, text, secondary, idleDot, accent: Color }` (values from Global Constraints); the `TVRemoteApp` environment injects one `ConnectionManager`. `RootView` shows `SetupView` for `.noTV`, `.needsPairing` and `.pairing`, and `RemoteView` otherwise. Until Tasks 8–9 these are placeholders: `Text("Setup")` and `Text("Remote")`. Launch argument `-demo` swaps `LiveLink` for `DemoLink` (a fake that is always connected with `isOn: true` and volume 12/100) so the UI can be shown without the TV.

- [ ] **Step 1: Install XcodeGen:** `brew install xcodegen`. Expected: `xcodegen --version` prints a version.
- [ ] **Step 2: Icon:** `icon.html` draws option C, "Ripple", at 1024×1024. It uses the generator from `docs/design/mockup-remote.html` (9×9 grid, padding 152, background radial `#151515`→`#000`, dots `#2C2C2E` r14, orange `#D97757` r = 14 + 16t with opacity 0.15 + 0.85t², halo r250). `?tinted` renders grayscale with a transparent background. `render.sh` uses headless Chrome (`"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --hide-scrollbars --window-size=1024,1024 --screenshot=...`) to write the three PNGs. The dark PNG is the same as the light one. Run `sips -g hasAlpha icon-1024.png`. Expected: `hasAlpha: no` for the light icon.
- [ ] **Step 3: `project.yml`:** app target `TVRemote` (iOS 17.0, sources `TVRemote`, package dependency `TVRemoteKit` at path `../TVRemoteKit`). Settings: `PRODUCT_BUNDLE_IDENTIFIER: com.dzafirov.tvskin.remote`, `TARGETED_DEVICE_FAMILY: "1"`, `CODE_SIGN_STYLE: Automatic`, `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`, `SWIFT_VERSION: 5.0`, `DEVELOPMENT_TEAM: ${TV_TEAM_ID}` (empty until Task 11). Info properties: `CFBundleDisplayName: TV Remote`, `UILaunchScreen: {UIColorName: ""}`, `UIUserInterfaceStyle: Dark`, `UISupportedInterfaceOrientations: [UIInterfaceOrientationPortrait]`, `NSLocalNetworkUsageDescription: "TV Remote finds and controls your TV on this Wi-Fi."`, `NSBonjourServices: [_androidtvremote2._tcp]`. Run `xcodegen generate` in `ios/App`.
- [ ] **Step 4: Implement** `TVRemoteApp` (calls `appBecameActive`/`appWentBackground` from `scenePhase`, black background everywhere), `RootView`, `Theme`, `DemoLink`.
- [ ] **Step 5: Build:** `xcodebuild -project ios/App/TVRemote.xcodeproj -scheme TVRemote -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build | tail -3`. Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 6: Commit** `ios/App ios/icon` "iOS app scaffold and Ripple icon".

### Task 8: Discovery and pairing screens

**Files:**
- Create: `ios/TVRemoteKit/Sources/TVRemoteKit/Link/TVDiscovery.swift`
- Create: `ios/App/TVRemote/Setup/SetupView.swift`, `CodeEntryView.swift`
- Modify: `ios/TVRemoteKit/Sources/tvremote/main.swift` (add `discover`), `ios/App/TVRemote/RootView.swift`

**Interfaces:**
- Consumes: `ConnectionManager.startPairing/submitCode/state/localNetworkDenied` (Task 6), `PairingCode.normalize` (Task 2), `Theme` (Task 7).
- Produces: `struct DiscoveredTV: Identifiable, Equatable { let id: String; let name: String; let host: String }`, `final class TVDiscovery { init(); let results: AsyncStream<[DiscoveredTV]>; var onPolicyDenied: (() -> Void)?; func start(); func stop() }`. It uses `NWBrowser(for: .bonjour(type: "_androidtvremote2._tcp", domain: nil), using: .tcp)`. Hosts are resolved by opening a short `NWConnection` to the service endpoint and reading `currentPath?.remoteEndpoint` (IPv4 preferred). `.waiting` with DNS error `-65570` (PolicyDenied) calls `onPolicyDenied`.
- Screens (copy is exact):
  - `SetupView`: title "Find your TV", subtitle "Your iPhone and TV need to be on the same Wi-Fi.", a list of found TVs (name + host), "Enter IP address" (numeric field, button "Connect"). While searching it shows a subtle "Looking for TVs…".
  - `CodeEntryView`: title "Enter the code on your TV", 6 boxes (monospaced digits, auto-uppercase, accepts paste), auto-submits at 6 valid characters. `.wrongCode` → "That code didn't match. Check the TV and try again." (boxes clear, keyboard stays). `.failed(msg)` → msg + "Try again".
  - Local network denied: "TV Remote needs Local Network access to find your TV." + button "Open Settings" (`UIApplication.openSettingsURLString`).
  - Unreachable during pairing: "Can't reach the TV. Is it on and on the same Wi-Fi?"

- [ ] **Step 1: Add `tvremote discover [--seconds 5]`** using `TVDiscovery`. Live check: `swift run tvremote discover`. Expected: a line with `192.168.8.16`.
- [ ] **Step 2: Implement the views** and wire `RootView`.
- [ ] **Step 3: Build** (same command as Task 7 Step 5). Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 4: Commit** "Discovery and pairing screens".

### Task 9: Remote screen (dotted touchpad, buttons, header)

**Files:**
- Create: `ios/App/TVRemote/Remote/RemoteView.swift`, `HeaderView.swift`, `DotTouchpadView.swift`, `TouchCaptureView.swift`, `TrailModel.swift`, `Haptics.swift`
- Modify: `ios/App/TVRemote/RootView.swift`

**Interfaces:**
- Consumes: `GestureInterpreter`, `RemoteCommand`, `TouchSample` (Task 5); `ConnectionManager.perform/press/power/state` (Task 6); `Theme` (Task 7).
- Produces: `RemoteView` with a `@State var showControls: Bool` and `@State var showKeyboard: Bool`, used by Task 10.
- Layout (iPhone portrait), matching `docs/design/mockup-remote.html` screen 1:
  - Header: TV name (17 pt semibold), and under it a status line with a 6 pt dot. `.connected(true)` shows "Connected" with an orange dot. `.connected(false)` shows "TV is off" with a grey dot. `.connecting` shows "Connecting…". `.unreachable` shows "Can't reach the TV". `.localNetworkDenied` shows "Local Network is off" and is tappable to open Settings. On the right is a 40 pt circular power button with an orange icon.
  - Touchpad: fills the space between header and buttons, corner radius 28, fill `#070707`, 1 pt `#1A1A1A` border. Dot grid spacing 22 pt, idle radius 1.5 pt `#2C2C2E`. `TrailModel` keeps touch points for 0.6 s. Each dot's intensity = max over points of (1 − d/70)·(1 − age/0.6), giving radius 1.5 + 1.5·intensity and colour `#D97757` at opacity = intensity. A radial glow (radius 60 pt, `#D97757` at 0.28) sits at each live touch. Rendered with `Canvas` inside `TimelineView(.animation)`, and only animates while the trail is non-empty. The hint "Swipe to move · Tap to select" (11 pt, `#4A4A4E`) fades out after the first touch of the session.
  - `TouchCaptureView`: a `UIViewRepresentable` with `isMultipleTouchEnabled = true` that forwards `touchesBegan/Moved/Ended/Cancelled` as `TouchSample`s to `GestureInterpreter`. A `CADisplayLink` calls `tick(now:)` while touches are down. Resulting commands go to `manager.perform`.
  - Buttons row: four 56 pt circles (`#141414`, 1 pt `#222222`): Back (`.back`), Home (`.home`), Play/Pause (`.playPause`, orange icon), Keyboard (opens the keyboard sheet). SF Symbols: `chevron.left`, `house`, `playpause.fill`, `keyboard`.
  - Handle: a 36×5 pt `#3A3A3C` pill with the label "Controls". Tapping it or swiping up on it sets `showControls`.
  - Haptics (`Haptics.swift`): d-pad step → light impact; `.dpadCenter` → medium; `.longStart` → rigid; volume keys → selection; play/pause and buttons → soft.
- [ ] **Step 1: Implement** the files and wire `RootView`.
- [ ] **Step 2: Build.** Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Commit** "Remote screen with dotted touchpad".

### Task 10: Hidden controls sheet and keyboard sheet

**Files:**
- Create: `ios/App/TVRemote/Remote/ControlsSheet.swift`, `PlaybackPage.swift`, `VolumePage.swift`, `AppsPage.swift`, `TVPage.swift`, `KeyboardSheet.swift`
- Modify: `ios/App/TVRemote/Remote/RemoteView.swift`

**Interfaces:**
- Consumes: `ConnectionManager.press/open/type/volume/canType/power` (Task 6), `AppShortcut.all` and `Seek` (Task 4), `Theme` (Task 7), `RemoteView.showControls/showKeyboard` (Task 9).
- Sheet: `.sheet` with `presentationDetents([.fraction(0.62)])`, background `#0F0F0F`, corner radius 26, drag indicator visible. A custom four-tab segmented control: "Playback", "Volume", "Apps", "TV" (remembers the last tab).
  - Playback: Previous (`.previous`), "10 s" back (`Seek.backward`), a big 72 pt orange Play/Pause (`.playPause`, black glyph), "10 s" forward (`Seek.forward`), Next (`.next`). Pills: "Subtitles" (`.captions`), "Stop" (`.stop`). A card headed "Gestures on the touchpad" with rows: "Two-finger tap — Play / pause", "Two-finger swipe — ±10 s", "Right edge, slide — Volume", "Press and hold — Hold OK".
  - Volume: buttons "−" (`.volumeDown`, repeats while held at 8/s), "Mute" (`.mute`), "+" (`.volumeUp`, repeats). Shows "Volume 12 of 100", or "Muted" from `manager.volume`, or "—" when unknown, with a thin orange level bar.
  - Apps: a 4-column grid of `AppShortcut.all`: 56 pt rounded squares in the app's tint with its name as a text mark, the label underneath, and `manager.open(app)` on tap.
  - TV: "Input" (`.tvInput`), "HDMI 1", "HDMI 2", "HDMI 3" (`.hdmi1…3`), "Settings" (`.settings`), "Search" (`.search`), "Power" (orange, `manager.power()`).
- Keyboard sheet: a text field with autofocus and placeholder "Type on the TV". Return or "Send" calls `manager.type(text)` and clears the field. A "Delete" button presses `.del`. When `manager.canType == false` it shows: "Select a search box on the TV first, then type here."

- [ ] **Step 1: Implement** the files and present them from `RemoteView`.
- [ ] **Step 2: Build.** Expected: `** BUILD SUCCEEDED **`.
- [ ] **Step 3: Commit** "Hidden controls and keyboard sheets".

### Task 11: Install on both iPhones and live acceptance (with Dimitar)

**Files:**
- Create: `ios/scripts/install.sh`, `docs/ACCEPTANCE.md`
- Modify: `README.md`

**Interfaces:**
- Consumes: everything above.

- [ ] **Step 1: Dimitar's steps (guide him one at a time):** Xcode → Settings → Accounts → add Apple ID. Plug in iPhone 1 and tap "Trust". On the iPhone, Settings → Privacy & Security → Developer Mode → On (it restarts). Read the team ID with `security find-identity -v -p codesigning` (a line with "Apple Development: …") or from Xcode's account panel.
- [ ] **Step 2: `install.sh`:** exports `TV_TEAM_ID`, runs `xcodegen generate`, builds with `xcodebuild -project ios/App/TVRemote.xcodeproj -scheme TVRemote -configuration Debug -destination 'generic/platform=iOS' -allowProvisioningUpdates -allowProvisioningDeviceRegistration DEVELOPMENT_TEAM=$TV_TEAM_ID -derivedDataPath ios/App/build build`, then installs to every connected iPhone listed by `xcrun devicectl list devices` with `xcrun devicectl device install app --device <id> ios/App/build/Build/Products/Debug-iphoneos/TVRemote.app`. Run it. Expected: "App installed". On the iPhone: Settings → General → VPN & Device Management → trust the developer app.
- [ ] **Step 3: First run on iPhone 1:** allow Local Network, pick the TV, and enter the code. Expected: the header shows "Connected".
- [ ] **Step 4: Acceptance checklist** (record pass/fail in `docs/ACCEPTANCE.md`): swipe in all four directions; tap = OK; hold = long-press menu; two-finger tap = play/pause in YouTube; two-finger swipe = ±10 s; right-edge slide = volume; Back, Home, Play/Pause buttons; every Playback, Volume, Apps and TV item; typing into YouTube search; lock the phone for 1 min and unlock (reconnects by itself within 2 s); airplane mode on, then off ("Can't reach the TV", then "Connected"); TV to standby with Power, then Power again (wakes, either via the protocol or Wake-on-LAN; note which).
- [ ] **Step 5: iPhone 2:** plug in, Developer Mode, run `install.sh`, pair, and smoke-test swipe, tap and Play/Pause. Use both phones at the same time. Expected: both work without kicking each other off.
- [ ] **Step 6: README:** add "Re-install every 7 days: plug in the iPhone and run `ios/scripts/install.sh`" plus the CLI usage.
- [ ] **Step 7: Commit** "Install script, acceptance results, README".
