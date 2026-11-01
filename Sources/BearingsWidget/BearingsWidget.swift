import CoreLocation
import SwiftUI
import WidgetKit

// Mac desktop and Notification Center, iPhone and iPad Home Screen and Lock Screen: where you are, the
// elevation in feet and metres, and the sky. The app shares its last fix through the App Group
// (SharedStore); the widget asks for a fresher location itself where the system allows it.

@main
struct BearingsWidgets: WidgetBundle {
    var body: some Widget {
        BearingsWidget()
    }
}

struct BearingsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BearingsWidget", provider: Provider()) { entry in
            WidgetView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Bearings")
        .description("Where you are, your elevation in feet and metres, and the sun and moon.")
        .supportedFamilies(Self.families)
    }

    #if os(iOS)
    /// Home Screen sizes, plus the Lock Screen's.
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge, .accessoryInline, .accessoryCircular, .accessoryRectangular]
    #else
    static let families: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
    #endif
}

// MARK: - Timeline

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BearingsEntry { .placeholder() }

    func getSnapshot(in context: Context, completion: @escaping (BearingsEntry) -> Void) {
        if context.isPreview {
            completion(BearingsEntry(date: Date(), snapshot: SharedStore.load() ?? .sample))
            return
        }
        let large = context.family == .systemLarge
        Task {
            let snapshot = await WidgetSource.current()
            let map = large ? await WidgetSource.map(for: snapshot) : nil
            completion(BearingsEntry(date: Date(), snapshot: snapshot, map: map))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BearingsEntry>) -> Void) {
        let large = context.family == .systemLarge
        Task {
            let snapshot = await WidgetSource.current()
            let map = large ? await WidgetSource.map(for: snapshot) : nil
            let entries = WidgetTimeline.entries(snapshot: snapshot, map: map)
            completion(Timeline(entries: entries, policy: .after(Date().addingTimeInterval(WidgetTimeline.refresh))))
        }
    }
}

/// Where the widget's numbers come from: the app's last fix, brought up to date with the widget's own
/// location when the system gives it one (named from the bundled list and its elevation looked up
/// again if you've moved since).
enum WidgetSource {
    static func current() async -> WidgetSnapshot? {
        let saved = SharedStore.load()
        guard let here = await WidgetLocator.locate() else { return saved }
        var snapshot = saved ?? WidgetSnapshot(latitude: here.latitude, longitude: here.longitude, accuracy: here.accuracy,
                                                elevation: nil, elevationFromGPS: false, place: nil, time: here.time,
                                                feet: Geo.prefersFeet(region: Locale.current.region?.identifier),
                                                format: Geo.Format.dd.rawValue, spotLatitude: nil, spotLongitude: nil)
        // An older fix than the app's isn't news.
        if let saved, here.time <= saved.time { return saved }
        let moved = saved.map { Geo.distance(lat1: $0.latitude, lon1: $0.longitude, lat2: here.latitude, lon2: here.longitude) } ?? .infinity
        snapshot.latitude = here.latitude
        snapshot.longitude = here.longitude
        snapshot.accuracy = here.accuracy
        snapshot.time = here.time
        if moved >= 500 || snapshot.place == nil {
            snapshot.place = Geo.offlinePlaceName(lat: here.latitude, lon: here.longitude, feet: snapshot.feet) ?? snapshot.place
        }
        if let altitude = here.altitude {
            snapshot.elevation = altitude
            snapshot.elevationFromGPS = true
        } else if moved >= 100 || snapshot.elevation == nil {
            if let metres = await GroundLookup.fetch(latitude: here.latitude, longitude: here.longitude, timeout: 6) {
                snapshot.elevation = metres
                snapshot.elevationFromGPS = false
            } else if moved >= 100 {
                snapshot.elevation = nil
            }
        }
        return snapshot
    }

    static func map(for snapshot: WidgetSnapshot?) async -> PlatformImage? {
        guard let snapshot else { return nil }
        return await MapSnapshot.make(latitude: snapshot.latitude, longitude: snapshot.longitude, size: WidgetTimeline.mapSize)
    }
}

/// A fresh location for the widget, if the person allowed it ("While Using the App or Widgets" on
/// iPhone, which NSWidgetWantsLocation asks for). Gives up after a few seconds: a widget gets little time.
@MainActor
final class WidgetLocator: NSObject, CLLocationManagerDelegate {
    struct Located {
        var latitude: Double
        var longitude: Double
        var accuracy: Double
        /// Only when GPS's vertical accuracy is under 25 m, as in the app.
        var altitude: Double?
        var time: Date
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Located?, Never>?

    static func locate(timeout: Double = 6) async -> Located? {
        let locator = WidgetLocator()
        return await locator.run(timeout: timeout)
    }

    private var allowed: Bool {
        switch manager.authorizationStatus {
        case .notDetermined, .denied, .restricted: return false
        default: break
        }
        #if os(iOS)
        return manager.isAuthorizedForWidgetUpdates
        #else
        return true
        #endif
    }

    private func run(timeout: Double) async -> Located? {
        guard allowed else { return nil }
        // A recent fix the system already has is good enough, and costs nothing.
        if let last = manager.location, Date().timeIntervalSince(last.timestamp) < 5 * 60, last.horizontalAccuracy >= 0 {
            return Self.located(last)
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        return await withCheckedContinuation { (c: CheckedContinuation<Located?, Never>) in
            continuation = c
            manager.requestLocation()
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                self.finish(nil)
            }
        }
    }

    private func finish(_ located: Located?) {
        continuation?.resume(returning: located)
        continuation = nil
    }

    nonisolated private static func located(_ l: CLLocation) -> Located {
        let goodAltitude = l.verticalAccuracy > 0 && l.verticalAccuracy < 25
        return Located(latitude: l.coordinate.latitude, longitude: l.coordinate.longitude, accuracy: l.horizontalAccuracy,
                       altitude: goodAltitude ? l.altitude : nil, time: l.timestamp)
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last, last.horizontalAccuracy >= 0 else { return }
        let located = Self.located(last)
        Task { @MainActor in self.finish(located) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}
