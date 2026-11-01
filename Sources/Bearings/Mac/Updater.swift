import Foundation

/// Checks GitHub Releases once at launch; when there's a newer version, the window shows a banner with
/// a Download button (the DMG on the release page). Nothing is sent but the request itself.
@MainActor
final class Updater: ObservableObject {
    static let shared = Updater()

    struct Release: Equatable { let version: String; let url: URL }
    @Published private(set) var available: Release?

    func check(current: String? = nil) async {
        let current = current ?? MainView.version
        var request = URLRequest(url: Brand.releasesAPI, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearings/\(current)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String else { return }
        let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let page = (json["html_url"] as? String).flatMap(URL.init(string:)) ?? Brand.releasesPage
        if Self.isNewer(latest, than: current) { available = Release(version: latest, url: page) }
    }

    /// "0.2.0" is newer than "0.1.9"; anything is newer than a development build.
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }, pb = b.split(separator: ".").map { Int($0) ?? 0 }
        if pb.isEmpty || b == "dev" { return false }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
