import Foundation
import TVRemoteKit

// Line-buffer stdout so a caller reading through a pipe sees CODE_ON_TV as soon as it is printed.
setvbuf(stdout, nil, _IOLBF, 0)

let usage = """
usage: tvremote <command> [options]

commands:
  pair --host <ip> [--name <client name>] [--code-file <path>]
      Pair with the TV. Prints CODE_ON_TV once the code is on screen, then reads the code
      from --code-file (written after that moment; polled every 0.5 s for up to 120 s)
      or from stdin. Prints PAIRED, or the error name and exits with status 1.
  key --host <ip> <key name> [--long]
      Press a key; --long holds it for 1 s.
  app --host <ip> <link>
      Open an app by its link, e.g. https://www.youtube.com.
  text --host <ip> <text>
      Type into the text field focused on the TV (waits up to 3 s for the TV to report one).
  watch --host <ip> [--seconds <n>]
      Print every event from the TV, for n seconds or until the connection ends (then exit status 1).
  wake --mac <aa:bb:cc:dd:ee:ff>
      Broadcast a Wake-on-LAN packet to port 9.
The remote commands print SENT, or the error name and exit with status 1.

key names: UP DOWN LEFT RIGHT OK \(KeyCode.allCases.map(\.name).joined(separator: " "))
"""

struct UsageError: Error {
    let message: String
}

/// The package directory, so the CLI keeps one identity in `.tvremote/` whatever the working directory.
let packageDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // tvremote
    .deletingLastPathComponent() // Sources
    .deletingLastPathComponent()

/// One command's arguments: options with a value (`--host 1.2.3.4`), flags (`--long`) and positionals.
struct Arguments {
    var options: [String: String] = [:]
    var flags: Set<String> = []
    var positionals: [String] = []

    /// Any other argument starting with `--` is an error.
    init(_ arguments: [String], options allowedOptions: Set<String>, flags allowedFlags: Set<String> = []) throws {
        var rest = arguments[...]
        while let argument = rest.popFirst() {
            if allowedFlags.contains(argument) {
                flags.insert(argument)
            } else if allowedOptions.contains(argument) {
                guard let value = rest.popFirst() else { throw UsageError(message: "\(argument) needs a value") }
                options[argument] = value
            } else if argument.hasPrefix("--") {
                throw UsageError(message: "unknown option \(argument)")
            } else {
                positionals.append(argument)
            }
        }
    }

    func required(_ option: String, by command: String) throws -> String {
        guard let value = options[option] else { throw UsageError(message: "\(command) needs \(option)") }
        return value
    }

    /// The one positional argument, called `what` in errors.
    func single(_ what: String) throws -> String {
        guard positionals.count == 1 else {
            throw UsageError(message: positionals.isEmpty ? "missing \(what)" : "expected one \(what), got \(positionals.count)")
        }
        return positionals[0]
    }

    func noPositionals() throws {
        if let first = positionals.first { throw UsageError(message: "unexpected argument \(first)") }
    }
}

func loadIdentity() throws -> ClientIdentity {
    try FileIdentityStore(directory: packageDirectory.appendingPathComponent(".tvremote")).loadOrCreate()
}

/// Waits for `path` to be written after `since` and returns its trimmed contents.
func readCode(fromFile path: String, writtenAfter since: Date) async throws -> String {
    let url = URL(fileURLWithPath: path)
    let deadline = Date().addingTimeInterval(120)
    while Date() < deadline {
        if let modified = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date,
           modified >= since,
           let text = try? String(contentsOf: url, encoding: .utf8),
           !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        try await Task.sleep(nanoseconds: 500_000_000)
    }
    throw TVLinkError.timeout
}

func pair(_ arguments: [String]) async throws {
    let arguments = try Arguments(arguments, options: ["--host", "--name", "--code-file"])
    try arguments.noPositionals()
    let options = arguments.options
    let host = try arguments.required("--host", by: "pair")
    let session = PairingSession(host: host, identity: try loadIdentity(), clientName: options["--name"] ?? "tv-skin Mac")

    try await session.start()
    let codeShownAt = Date()
    print("CODE_ON_TV")

    let code: String
    if let path = options["--code-file"] {
        code = try await readCode(fromFile: path, writtenAfter: codeShownAt)
    } else {
        print("Enter the code shown on the TV: ", terminator: "")
        fflush(stdout)
        guard let line = readLine() else {
            session.cancel()
            throw TVLinkError.closed
        }
        code = line
    }
    do {
        try await session.finish(code: code)
    } catch {
        session.cancel()
        throw error
    }
    print("PAIRED")
}

/// Opens a remote session, runs `body`, then closes the session once the TV has had time to act on it.
func withRemoteSession(host: String, _ body: (RemoteSession) async throws -> Void) async throws {
    let session = try await RemoteSession.open(host: host, identity: try loadIdentity())
    do {
        try await body(session)
    } catch {
        session.close()
        throw error
    }
    // Sends are queued on the network thread; let them reach the TV before the process exits.
    try await Task.sleep(nanoseconds: 500_000_000)
    session.close()
    for await _ in session.events {}
}

func pressKey(_ arguments: [String]) async throws {
    let arguments = try Arguments(arguments, options: ["--host"], flags: ["--long"])
    let host = try arguments.required("--host", by: "key")
    let name = try arguments.single("key name")
    guard let key = KeyCode(name: name) else { throw UsageError(message: "unknown key \(name)") }
    try await withRemoteSession(host: host) { session in
        if arguments.flags.contains("--long") {
            session.send(key, .startLong)
            try await Task.sleep(nanoseconds: 1_000_000_000)
            session.send(key, .endLong)
        } else {
            session.send(key)
        }
    }
    print("SENT")
}

func openApp(_ arguments: [String]) async throws {
    let arguments = try Arguments(arguments, options: ["--host"])
    let host = try arguments.required("--host", by: "app")
    let link = try arguments.single("app link")
    try await withRemoteSession(host: host) { $0.launch(appLink: link) }
    print("SENT")
}

func typeText(_ arguments: [String]) async throws {
    let arguments = try Arguments(arguments, options: ["--host"])
    let host = try arguments.required("--host", by: "text")
    let text = try arguments.single("text")
    try await withRemoteSession(host: host) { session in
        let deadline = Date().addingTimeInterval(3)
        while true {
            do {
                return try session.type(text)
            } catch TVLinkError.noTextField where Date() < deadline {
                try await Task.sleep(nanoseconds: 100_000_000)
            }
        }
    }
    print("SENT")
}

/// One line per event, e.g. `ready(isOn: true)` or `closed(timeout)`.
func describe(_ event: RemoteEvent) -> String {
    if case .closed(let error) = event { return "closed(\(error))" }
    return String(describing: event)
}

func watchEvents(_ arguments: [String]) async throws {
    let arguments = try Arguments(arguments, options: ["--host", "--seconds"])
    try arguments.noPositionals()
    let host = try arguments.required("--host", by: "watch")
    var seconds: Double?
    if let value = arguments.options["--seconds"] {
        guard let parsed = Double(value), parsed > 0 else { throw UsageError(message: "--seconds needs a positive number") }
        seconds = parsed
    }

    let session = try await RemoteSession.open(host: host, identity: try loadIdentity())
    let stopsAt = seconds.map { Date().addingTimeInterval($0) }
    if let seconds {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            session.close()
        }
    }
    for await event in session.events {
        print(describe(event))
        if case .closed = event, stopsAt.map({ Date() < $0 }) ?? true {
            // The connection ended before --seconds ran out.
            exit(1)
        }
    }
}

func wakeTV(_ arguments: [String]) async throws {
    let arguments = try Arguments(arguments, options: ["--mac"])
    try arguments.noPositionals()
    let mac = try arguments.required("--mac", by: "wake")
    do {
        try await WakeOnLAN.send(mac: mac)
    } catch WakeOnLANError.invalidMAC {
        throw UsageError(message: "invalid MAC address \(mac)")
    }
    print("SENT")
}

var arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.isEmpty ? nil : arguments.removeFirst()

do {
    switch command {
    case "pair":
        try await pair(arguments)
    case "key":
        try await pressKey(arguments)
    case "app":
        try await openApp(arguments)
    case "text":
        try await typeText(arguments)
    case "watch":
        try await watchEvents(arguments)
    case "wake":
        try await wakeTV(arguments)
    case "help", "--help", "-h":
        print(usage)
    case let other:
        throw UsageError(message: other.map { "unknown command \($0)" } ?? "missing command")
    }
    exit(0)
} catch let error as UsageError {
    FileHandle.standardError.write(Data("tvremote: \(error.message)\n\n\(usage)\n".utf8))
    exit(1)
} catch let error as TVLinkError {
    print(error)
    exit(1)
} catch {
    print("error: \(error)")
    exit(1)
}
