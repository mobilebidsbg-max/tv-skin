import SwiftUI
import TVRemoteKit

@main
struct TVRemoteApp: App {
    @State private var connection = TVRemoteApp.makeConnection()
    @State private var probe = LocalNetworkProbe()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(connection)
                .preferredColorScheme(.dark)
                .background(Theme.background.ignoresSafeArea())
                .environment(\.makeTVFinder, TVRemoteApp.makeFinder)
                .task { await DemoMode.current?.prepare(connection) }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            switch phase {
            case .active:
                connection.appBecameActive()
                if DemoMode.current == nil {
                    probe.run(
                        lookingFor: connection.tv?.name,
                        onFound: { [connection] in connection.discovered($0) },
                        onDenied: { [connection] in connection.localNetworkDenied() }
                    )
                }
            case .background:
                probe.stop()
                connection.appWentBackground()
            default:
                break
            }
        }
    }

    private static func makeFinder() -> TVFinding {
        DemoMode.current == nil ? TVDiscovery() : DemoFinder()
    }

    /// How this iPhone is named on the TV. `UIDevice.current.name` is just "iPhone" since iOS 16, so a fixed name
    /// says more.
    private static let clientName = "TV Remote (iPhone)"

    /// A demo launch argument (see `DemoMode`) swaps the real link for `DemoLink`, so the UI works without a TV.
    private static func makeConnection() -> ConnectionManager {
        if let demo = DemoMode.current {
            return ConnectionManager(link: demo.link, store: demo.store)
        }
        return ConnectionManager(
            link: LiveLink(identityStore: KeychainIdentityStore(), clientName: clientName),
            store: UserDefaultsPairedTVStore()
        )
    }
}
