import Foundation

/// Single source of truth for branding. Change these to rebrand the app.
enum Brand {
    static let appName = "Bearings"
    static let tagline = "A compass with your coordinates, elevation and a map, on one screen."
    static let author = "Bradley Cowdrey"
    static let website = URL(string: "https://bradcowdrey.com")!
    static let legal = URL(string: "https://bradcowdrey.com/legal")!
    /// Bump when the terms change materially, so everyone is asked to agree again.
    static let termsVersion = "2026-11-01"
    static let repository = URL(string: "https://github.com/bradleycowdrey/bearings")!
    static let productPage = URL(string: "https://bradcowdrey.com/bearings")!
    static let releasesPage = URL(string: "https://github.com/bradleycowdrey/bearings/releases/latest")!
    static let releasesAPI = URL(string: "https://api.github.com/repos/bradleycowdrey/bearings/releases/latest")!
    static let issues = URL(string: "https://github.com/bradleycowdrey/bearings/issues")!
    static let shareMessage = "Bearings: a compass with your latitude, longitude, elevation and a map, on one screen. Free and open source, by Bradley Cowdrey."
    static let copyright = "© 2026 Bradley Cowdrey · bradcowdrey.com"
    static let termsSummary = "Bearings is free and provided as is, without warranty. It is not a navigation or safety instrument: compasses are thrown off by metal and magnets, and positions and elevations can be wrong, so carry a map and a real compass where it matters. Your location stays on your device; only a rounded position goes to Open-Meteo for the ground elevation, and the map loads from Apple Maps."
}
