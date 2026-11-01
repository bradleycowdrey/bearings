import CoreLocation
import Foundation
import MapKit
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

// What the app and its widgets share. Compiled into both (and into the self-tests), so the widget's data
// path is the same code the app checks.

/// The app's last fix and settings, as the widgets read them: where you were, the place's name, the
/// elevation and where it came from, when, and the units, coordinate format and marked spot to show.
struct WidgetSnapshot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    /// Horizontal accuracy, metres.
    var accuracy: Double
    /// Metres above sea level, when known.
    var elevation: Double?
    /// true: from GPS; false: terrain data.
    var elevationFromGPS: Bool
    var place: String?
    var time: Date
    var feet: Bool
    /// A Geo.Format raw value.
    var format: String
    var spotLatitude: Double?
    var spotLongitude: Double?

    var coordinateFormat: Geo.Format { Geo.Format(rawValue: format) ?? .dd }

    /// Worth redrawing the widgets for: moved 100 m, a new place or elevation, or changed settings.
    func differsMeaningfully(from old: WidgetSnapshot) -> Bool {
        if Geo.distance(lat1: latitude, lon1: longitude, lat2: old.latitude, lon2: old.longitude) >= 100 { return true }
        if place != old.place || feet != old.feet || format != old.format { return true }
        if spotLatitude != old.spotLatitude || spotLongitude != old.spotLongitude { return true }
        switch (elevation, old.elevation) {
        case (nil, nil): return false
        case let (a?, b?): return abs(a - b) >= 10
        default: return true
        }
    }

    /// Maroon Bells, Colorado: the widget gallery's preview and the self-tests' drawings.
    static let sample = WidgetSnapshot(latitude: 39.09898, longitude: -106.94117, accuracy: 5, elevation: 2922, elevationFromGPS: false,
                                       place: "Maroon Bells, Colorado", time: Date(), feet: true, format: Geo.Format.dd.rawValue,
                                       spotLatitude: 39.1911, spotLongitude: -106.8175)
}

/// The App Group the app writes and the widgets read. On the Mac, the team ID prefix lets a Developer ID
/// app and its widget share it without a provisioning profile; on iPhone and iPad it's a registered group.
enum SharedStore {
    #if os(macOS)
    static let suiteName = "2XV97FZ86G.com.bradcowdrey.bearings"
    #else
    static let suiteName = "group.com.bradcowdrey.bearings"
    #endif
    static let key = "widget.snapshot"
    /// Off for the self-test and the sample place: an ad-hoc signed build isn't in the team's group, and
    /// the sample mustn't replace where you really are.
    nonisolated(unsafe) static var enabled = true

    static var defaults: UserDefaults? { enabled ? UserDefaults(suiteName: suiteName) : nil }

    static func save(_ snapshot: WidgetSnapshot, to defaults: UserDefaults? = SharedStore.defaults) {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(from defaults: UserDefaults? = SharedStore.defaults) -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }
}

/// Ground elevation for a rounded position from Open-Meteo (Copernicus DEM, 90 m). Sends only the
/// rounded position (about 100 m).
enum GroundLookup {
    static func fetch(latitude: Double, longitude: Double, timeout: TimeInterval = 15) async -> Double? {
        var parts = URLComponents(string: "https://api.open-meteo.com/v1/elevation")!
        parts.queryItems = [URLQueryItem(name: "latitude", value: String(Geo.rounded(latitude))),
                            URLQueryItem(name: "longitude", value: String(Geo.rounded(longitude)))]
        var request = URLRequest(url: parts.url!, timeoutInterval: timeout)
        request.setValue("Bearings (+https://github.com/bradleycowdrey/bearings)", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let values = json["elevation"] as? [Double], let first = values.first, first.isFinite else { return nil }
        return first
    }
}

/// Where you are, in words: the system's geocoder first ("Aspen, Colorado"), otherwise the nearest place
/// in the bundled list ("66 mi NE of Montrose, Colorado"), or "Far from any town".
enum PlaceNamer {
    struct Name: Equatable {
        let text: String
        /// From the bundled list, because the geocoder had nothing or couldn't be reached.
        let offline: Bool
    }

    static func name(latitude: Double, longitude: Double, feet: Bool) async -> Name? {
        if let text = await geocode(latitude: latitude, longitude: longitude) { return Name(text: text, offline: false) }
        return Geo.offlinePlaceName(lat: latitude, lon: longitude, feet: feet).map { Name(text: $0, offline: true) }
    }

    /// Locality, then the state or province, written out ("CO" reads "Colorado").
    static func geocode(latitude: Double, longitude: Double) async -> String? {
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(CLLocation(latitude: latitude, longitude: longitude)),
              let mark = placemarks.first, let locality = mark.locality, !locality.isEmpty else { return nil }
        var text = locality
        if let area = mark.administrativeArea, !area.isEmpty {
            let region = regionName(area, country: mark.isoCountryCode)
            if region != locality { text += ", \(region)" }
        }
        return text
    }

    /// Apple's geocoder abbreviates states and provinces in a few countries; Bearings writes them out.
    static func regionName(_ area: String, country: String?) -> String {
        guard let country, let names = regions[country] else { return area }
        return names[area.uppercased()] ?? area
    }

    static let regions: [String: [String: String]] = [
        "US": ["AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas", "CA": "California", "CO": "Colorado",
               "CT": "Connecticut", "DE": "Delaware", "DC": "District of Columbia", "FL": "Florida", "GA": "Georgia",
               "HI": "Hawaii", "ID": "Idaho", "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
               "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland", "MA": "Massachusetts",
               "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi", "MO": "Missouri", "MT": "Montana",
               "NE": "Nebraska", "NV": "Nevada", "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico",
               "NY": "New York", "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
               "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina", "SD": "South Dakota",
               "TN": "Tennessee", "TX": "Texas", "UT": "Utah", "VT": "Vermont", "VA": "Virginia", "WA": "Washington",
               "WV": "West Virginia", "WI": "Wisconsin", "WY": "Wyoming", "PR": "Puerto Rico"],
        "CA": ["AB": "Alberta", "BC": "British Columbia", "MB": "Manitoba", "NB": "New Brunswick",
               "NL": "Newfoundland and Labrador", "NS": "Nova Scotia", "NT": "Northwest Territories", "NU": "Nunavut",
               "ON": "Ontario", "PE": "Prince Edward Island", "QC": "Quebec", "SK": "Saskatchewan", "YT": "Yukon"],
        "AU": ["ACT": "Australian Capital Territory", "NSW": "New South Wales", "NT": "Northern Territory",
               "QLD": "Queensland", "SA": "South Australia", "TAS": "Tasmania", "VIC": "Victoria", "WA": "Western Australia"],
    ]
}

/// A dark map picture of a place, for the large widget (a widget can't show a live map).
enum MapSnapshot {
    /// `span` is the width shown, metres. nil if MapKit can't draw it (offline with nothing cached).
    static func make(latitude: Double, longitude: Double, size: CGSize, span: Double = 3000) async -> PlatformImage? {
        guard size.width > 0, size.height > 0 else { return nil }
        let options = MKMapSnapshotter.Options()
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        options.region = MKCoordinateRegion(center: center, latitudinalMeters: span * Double(size.height / size.width), longitudinalMeters: span)
        options.size = size
        options.mapType = .mutedStandard
        options.pointOfInterestFilter = .excludingAll
        #if os(iOS)
        options.traitCollection = UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceStyle: .dark), UITraitCollection(displayScale: 2)])
        #else
        options.appearance = NSAppearance(named: .darkAqua)
        #endif
        let snapshotter = MKMapSnapshotter(options: options)
        do {
            return try await snapshotter.start().image
        } catch {
            return nil
        }
    }
}
