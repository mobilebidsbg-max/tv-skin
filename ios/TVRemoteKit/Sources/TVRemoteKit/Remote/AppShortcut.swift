/// A one-tap launcher on the Apps page: an app link, or a key for the TV's own screens.
public struct AppShortcut: Identifiable, Equatable {
    public let id: String
    public let name: String
    /// Opened with `remote_app_link_launch_request`.
    public let link: String?
    /// Pressed instead of opening a link.
    public let key: KeyCode?
    /// Tile colour, `#RRGGBB`.
    public let tint: String

    public init(id: String, name: String, link: String? = nil, key: KeyCode? = nil, tint: String) {
        self.id = id
        self.name = name
        self.link = link
        self.key = key
        self.tint = tint
    }

    /// The apps installed on the TV, then Home and All apps.
    // unverified on TV — see Task 4 Step 7
    public static let all: [AppShortcut] = [
        AppShortcut(id: "youtube", name: "YouTube", link: "https://www.youtube.com", tint: "#FF0033"),
        AppShortcut(id: "netflix", name: "Netflix", link: "https://www.netflix.com/title", tint: "#E50914"),
        AppShortcut(id: "prime-video", name: "Prime Video", link: "https://app.primevideo.com", tint: "#1399FF"),
        AppShortcut(id: "apple-tv", name: "Apple TV", link: "https://tv.apple.com", tint: "#3A3A3C"),
        AppShortcut(id: "disney-plus", name: "Disney+", link: "https://www.disneyplus.com", tint: "#113CCF"),
        AppShortcut(id: "youtube-music", name: "YouTube Music", link: "https://music.youtube.com", tint: "#FF0000"),
        AppShortcut(id: "home", name: "Home", key: .home, tint: "#1A1A1A"),
        AppShortcut(id: "all-apps", name: "All apps", key: .allApps, tint: "#1A1A1A"),
    ]
}
