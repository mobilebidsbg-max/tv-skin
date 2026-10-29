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
"""

struct UsageError: Error {
    let message: String
}

/// The package directory, so the CLI keeps one identity in `.tvremote/` whatever the working directory.
let packageDirectory = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent() // tvremote
    .deletingLastPathComponent() // Sources
    .deletingLastPathComponent()

/// Parses `--name value` pairs; every option takes a value and must be in `allowed`.
func parseOptions(_ arguments: [String], allowed: Set<String>) throws -> [String: String] {
    var options: [String: String] = [:]
    var rest = arguments[...]
    while let flag = rest.popFirst() {
        guard allowed.contains(flag) else { throw UsageError(message: "unknown option \(flag)") }
        guard let value = rest.popFirst() else { throw UsageError(message: "\(flag) needs a value") }
        options[flag] = value
    }
    return options
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
    let options = try parseOptions(arguments, allowed: ["--host", "--name", "--code-file"])
    guard let host = options["--host"] else { throw UsageError(message: "pair needs --host") }
    let identity = try FileIdentityStore(directory: packageDirectory.appendingPathComponent(".tvremote")).loadOrCreate()
    let session = PairingSession(host: host, identity: identity, clientName: options["--name"] ?? "tv-skin Mac")

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

var arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.isEmpty ? nil : arguments.removeFirst()

do {
    switch command {
    case "pair":
        try await pair(arguments)
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
