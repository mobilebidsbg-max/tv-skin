import SwiftUI
import TVRemoteKit
import UIKit

@main
struct TVRemoteApp: App {
    @State private var connection = TVRemoteApp.makeConnection()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(connection)
                .preferredColorScheme(.dark)
                .background(Theme.background.ignoresSafeArea())
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                connection.appBecameActive()
            case .background:
                connection.appWentBackground()
            default:
                break
            }
        }
    }

    /// `-demo` swaps the real link for `DemoLink`, so the UI works without a TV.
    private static func makeConnection() -> ConnectionManager {
        if CommandLine.arguments.contains("-demo") {
            return ConnectionManager(link: DemoLink(), store: DemoStore())
        }
        return ConnectionManager(
            link: LiveLink(identityStore: KeychainIdentityStore(), clientName: UIDevice.current.name),
            store: UserDefaultsPairedTVStore()
        )
    }
}
