import CoreLocation
import Foundation
import SwiftUI
import WidgetKit
#if os(iOS)
import CoreMotion
import UIKit
#endif

/// Where you are, as the location services report it.
struct Fix: Equatable {
    var latitude: Double
    var longitude: Double
    /// Horizontal accuracy, metres.
    var accuracy: Double
    /// Height above sea level from GPS, only when it's good enough to show (vertical accuracy under 25 m).
    var altitude: Double?
    var altitudeAccuracy: Double?
    var time: Date
}

/// Ground elevation for a rounded position, from Open-Meteo (Copernicus DEM, 90 m).
struct Ground: Equatable {
    var metres: Double
    var latitude: Double
    var longitude: Double
}

/// A marked spot to find again ("where did I park?").
struct Spot: Equatable {
    var latitude: Double
    var longitude: Double
}

/// Everything on Bearings' one screen: position, place, heading, the level, elevation, the sun and moon,
/// a marked spot, and the settings that change how they read. One for the whole app.
@MainActor
final class Navigator: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Access: Equatable { case notAsked, allowed, denied }
    enum CompassStatus: Equatable { case starting, live, unavailable }
    enum GroundState: Equatable { case idle, loading, ok, failed }

    @Published private(set) var fix: Fix?
    @Published private(set) var access: Access = .notAsked
    @Published private(set) var locating = false
    /// Smoothed heading toward true or magnetic north (see `usingTrueNorth`), degrees.
    @Published private(set) var heading: Double?
    /// The dial card's rotation, unwrapped so it always turns the short way past north.
    @Published private(set) var cardRotation: Double = 0
    @Published private(set) var headingAccuracy: Double?
    /// True heading minus magnetic heading (east is positive), when the device knows it.
    @Published private(set) var declination: Double?
    @Published private(set) var usingTrueNorth = false
    @Published private(set) var compass: CompassStatus = .starting
    /// Gravity across the screen (x right, y down), -1…1; nil without motion sensors.
    @Published private(set) var tilt: CGVector?
    @Published private(set) var ground: Ground?
    @Published private(set) var groundState: GroundState = .idle
    @Published var lock: Double?
    @Published private(set) var sample = false
    /// "Aspen, Colorado", or nil until it's known.
    @Published private(set) var place: String?
    /// Whether a name has been looked for at this fix (so "Finding where you are…" can give way).
    @Published private(set) var placeLookedUp = false
    /// The time the screen shows and the sun and moon are worked out for: updated each minute.
    @Published private(set) var now = Date()
    /// Metres per second, only while moving faster than 0.5 m/s.
    @Published private(set) var speed: Double?
    /// Air pressure, hectopascals, from the barometer (on an iPhone or iPad that has one).
    @Published private(set) var pressure: Double?
    /// The magnetic field's strength, microteslas (smoothed). Earth's is about 25–65.
    @Published private(set) var fieldStrength: Double?

    // Settings, kept between launches.
    @Published var format: Geo.Format { didSet { defaults.set(format.rawValue, forKey: "format"); shareWithWidgets(force: true) } }
    @Published var feet: Bool { didSet { defaults.set(feet, forKey: "feet"); placeUnitsChanged() } }
    @Published var preferTrueNorth: Bool { didSet { defaults.set(preferTrueNorth, forKey: "trueNorth"); smoother.reset() } }
    @Published var followHeading: Bool { didSet { defaults.set(followHeading, forKey: "followHeading") } }
    @Published var satellite: Bool { didSet { defaults.set(satellite, forKey: "satellite") } }
    @Published var nightMode: Bool { didSet { defaults.set(nightMode, forKey: "nightMode") } }
    /// How large the compass is (docs/LAYOUTS.md): Small, Medium (the default), Large or Extra Large.
    /// A `--layout` launch argument shows one without saving it (`showLayout`).
    @Published var layout: Layout { didSet { if !layoutForThisLaunch { defaults.set(layout.rawValue, forKey: "layout") } } }
    /// The full-height map sheet is open (the Map tile, the header's map button, `--map-sheet`).
    @Published var mapSheet = false
    @Published private(set) var spot: Spot? {
        didSet {
            guard !sample else { return }
            if let spot {
                defaults.set(spot.latitude, forKey: "spot.lat")
                defaults.set(spot.longitude, forKey: "spot.lon")
            } else {
                defaults.removeObject(forKey: "spot.lat")
                defaults.removeObject(forKey: "spot.lon")
            }
            shareWithWidgets(force: true)
        }
    }

    private let defaults: UserDefaults
    private let manager = CLLocationManager()
    private var smoother = HeadingSmoother(k: 0.25)
    private var groundTask: Task<Void, Never>?
    private var lastGroundAttempt: Date?
    private var placeTask: Task<Void, Never>?
    /// Where the place was last looked up, and whether that name came from the offline list (then it's
    /// asked again after a few minutes, in case the network is back).
    private var placeAt: (latitude: Double, longitude: Double, time: Date, offline: Bool)?
    private var lastShared: WidgetSnapshot?
    private var lastSharedAt: Date?
    private var started = false
    /// Set only while `showLayout` applies a launch argument, so it isn't saved.
    private var layoutForThisLaunch = false
    #if os(iOS)
    private let motion = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let ticker = UISelectionFeedbackGenerator()
    #endif

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        format = Geo.Format(rawValue: defaults.string(forKey: "format") ?? "") ?? .dd
        layout = Layout.of(defaults.string(forKey: "layout"))
        feet = defaults.object(forKey: "feet") as? Bool ?? Geo.prefersFeet(region: Locale.current.region?.identifier)
        preferTrueNorth = defaults.object(forKey: "trueNorth") as? Bool ?? true
        followHeading = defaults.bool(forKey: "followHeading")
        satellite = defaults.bool(forKey: "satellite")
        nightMode = defaults.bool(forKey: "nightMode")
        super.init()
        if let lat = defaults.object(forKey: "spot.lat") as? Double, let lon = defaults.object(forKey: "spot.lon") as? Double {
            spot = Spot(latitude: lat, longitude: lon)
        }
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
        #if os(iOS)
        manager.headingFilter = 1
        #endif
        updateAccess()
        #if !os(iOS)
        compass = .unavailable
        #endif
        startClock()
    }

    // MARK: Starting and stopping

    /// Starts location, compass, level and barometer; asks for location permission the first time.
    func start() {
        guard !sample else { return }
        started = true
        now = Date()
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        if access == .allowed { locating = fix == nil; manager.startUpdatingLocation() }
        #if os(iOS)
        if CLLocationManager.headingAvailable() {
            updateHeadingOrientation()
            manager.startUpdatingHeading()
            if heading == nil { compass = .starting }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                if self.heading == nil && !self.sample { self.compass = .unavailable }
            }
        } else {
            compass = .unavailable
        }
        if motion.isDeviceMotionAvailable && !motion.isDeviceMotionActive {
            motion.deviceMotionUpdateInterval = 1.0 / 30
            motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
                guard let g = data?.gravity else { return }
                MainActor.assumeIsolated { self?.tilt = CGVector(dx: g.x, dy: -g.y) }
            }
        }
        if CMAltimeter.isRelativeAltitudeAvailable() {
            altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
                // CMAltitudeData.pressure is in kilopascals.
                guard let kPa = data?.pressure.doubleValue, kPa > 0 else { return }
                MainActor.assumeIsolated { self?.pressure = kPa * 10 }
            }
        }
        ticker.prepare()
        #endif
    }

    /// Stops the sensors (in the background, to save battery).
    func stop() {
        started = false
        manager.stopUpdatingLocation()
        #if os(iOS)
        manager.stopUpdatingHeading()
        motion.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        #endif
    }

    /// Keeps `now` on the minute, so the header's time and the sun and moon move with the clock.
    private func startClock() {
        Task { @MainActor [weak self] in
            while true {
                let seconds = 60 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 60)
                try? await Task.sleep(for: .seconds(seconds + 0.05))
                guard let self else { return }
                if !self.sample { self.now = Date() }
            }
        }
    }

    #if os(iOS)
    /// The compass measures from the top of the screen as you hold it, also on an iPad turned sideways.
    func updateHeadingOrientation() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let orientation: CLDeviceOrientation
        switch scene?.interfaceOrientation {
        case .landscapeLeft: orientation = .landscapeRight
        case .landscapeRight: orientation = .landscapeLeft
        case .portraitUpsideDown: orientation = .portraitUpsideDown
        default: orientation = .portrait
        }
        if manager.headingOrientation != orientation { manager.headingOrientation = orientation; smoother.reset() }
    }
    #endif

    private func updateAccess() {
        switch manager.authorizationStatus {
        case .notDetermined: access = .notAsked
        case .denied, .restricted: access = .denied
        default: access = .allowed
        }
    }

    // MARK: Readings

    private func take(_ location: CLLocation) {
        guard location.horizontalAccuracy >= 0 else { return }
        let goodAltitude = location.verticalAccuracy > 0 && location.verticalAccuracy < 25
        fix = Fix(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude,
                  accuracy: location.horizontalAccuracy,
                  altitude: goodAltitude ? location.altitude : nil,
                  altitudeAccuracy: goodAltitude ? location.verticalAccuracy : nil,
                  time: location.timestamp)
        speed = location.speed >= 0.5 ? location.speed : nil
        locating = false
        lookUpGround()
        lookUpPlace()
        shareWithWidgets()
    }

    private func takeHeading(magnetic: Double, trueHeading: Double, accuracy: Double, field: Double) {
        guard accuracy >= 0 else { return }   // negative: no valid heading yet
        let hasTrue = trueHeading >= 0
        usingTrueNorth = preferTrueNorth && hasTrue
        declination = hasTrue ? Geo.delta(from: magnetic, to: trueHeading) : nil
        setHeading(usingTrueNorth ? trueHeading : magnetic, tick: true)
        headingAccuracy = accuracy
        if field > 0 { fieldStrength = fieldStrength.map { $0 + 0.2 * (field - $0) } ?? field }
        compass = .live
    }

    private func setHeading(_ raw: Double, tick: Bool = false) {
        let previous = heading
        let h = smoother.push(raw)
        heading = h
        cardRotation += Geo.delta(from: cardRotation, to: -h)
        #if os(iOS)
        // A light tick as the heading passes N, E, S or W, like the detents on a real bezel.
        if tick, let previous {
            for cardinal in [0.0, 90, 180, 270] {
                let a = Geo.delta(from: cardinal, to: previous), b = Geo.delta(from: cardinal, to: h)
                if (a < 0) != (b < 0) && abs(a) < 45 && abs(b) < 45 { ticker.selectionChanged(); break }
            }
        }
        #endif
    }

    // MARK: Ground elevation

    /// Asks Open-Meteo for the ground elevation, again only after moving about 100 m (or a minute after a
    /// failure). Sends only the rounded position.
    func lookUpGround() {
        guard let fix else { return }
        let lat = Geo.rounded(fix.latitude), lon = Geo.rounded(fix.longitude)
        if let ground, ground.latitude == lat, ground.longitude == lon { return }
        if groundState == .loading { return }
        if groundState == .failed, let last = lastGroundAttempt, Date().timeIntervalSince(last) < 60 { return }
        groundState = .loading
        lastGroundAttempt = Date()
        groundTask = Task { @MainActor in
            if let metres = await Self.fetchGround(latitude: lat, longitude: lon) {
                ground = Ground(metres: metres, latitude: lat, longitude: lon)
                groundState = .ok
                shareWithWidgets()
            } else {
                groundState = .failed
            }
        }
    }

    nonisolated static func fetchGround(latitude: Double, longitude: Double) async -> Double? {
        await GroundLookup.fetch(latitude: latitude, longitude: longitude)
    }

    // MARK: The place's name

    /// Names the place (the system's geocoder, else the bundled list), and again after moving 500 m, or
    /// five minutes after an offline answer.
    private func lookUpPlace() {
        guard let fix, placeTask == nil, !sample else { return }
        if let at = placeAt {
            let moved = Geo.distance(lat1: at.latitude, lon1: at.longitude, lat2: fix.latitude, lon2: fix.longitude)
            let retry = at.offline && Date().timeIntervalSince(at.time) > 300
            if moved < 500 && !retry { return }
        }
        let lat = fix.latitude, lon = fix.longitude, inFeet = feet
        placeAt = (latitude: lat, longitude: lon, time: Date(), offline: false)
        placeTask = Task { @MainActor in
            let name = await PlaceNamer.name(latitude: lat, longitude: lon, feet: inFeet)
            if let name {
                place = name.text
                placeAt = (latitude: lat, longitude: lon, time: Date(), offline: name.offline)
            } else {
                placeAt = (latitude: lat, longitude: lon, time: Date(), offline: true)
            }
            placeLookedUp = true
            placeTask = nil
            shareWithWidgets()
        }
    }

    /// "66 mi NE of Montrose" becomes "106 km NE of Montrose" when the units change.
    private func placeUnitsChanged() {
        if let at = placeAt, at.offline, !sample, let text = Geo.offlinePlaceName(lat: at.latitude, lon: at.longitude, feet: feet) {
            place = text
        }
        shareWithWidgets(force: true)
    }

    // MARK: Widgets

    /// Saves the last fix, place, elevation and settings for the widgets, and redraws them when that
    /// changed meaningfully (moved 100 m, a new place, new settings). Smaller changes are saved at most
    /// once a minute without a redraw, so a widget's "as of" time stays close.
    private func shareWithWidgets(force: Bool = false) {
        guard !sample, SharedStore.enabled, let fix else { return }
        var snapshot = WidgetSnapshot(latitude: fix.latitude, longitude: fix.longitude, accuracy: fix.accuracy,
                                      elevation: nil, elevationFromGPS: false, place: place, time: fix.time,
                                      feet: feet, format: format.rawValue,
                                      spotLatitude: spot?.latitude, spotLongitude: spot?.longitude)
        if case let .value(metres, fromGPS, _) = elevation {
            snapshot.elevation = metres
            snapshot.elevationFromGPS = fromGPS
        }
        let meaningful = force || (lastShared.map { snapshot.differsMeaningfully(from: $0) } ?? true)
        if !meaningful, let at = lastSharedAt, Date().timeIntervalSince(at) < 60 { return }
        SharedStore.save(snapshot)
        lastShared = snapshot
        lastSharedAt = Date()
        if meaningful { WidgetCenter.shared.reloadAllTimelines() }
    }

    // MARK: What the screen shows

    enum ElevationReading: Equatable {
        case value(metres: Double, fromGPS: Bool, source: String)
        case pending(String)
    }

    /// Ground elevation from GPS when it's accurate, otherwise from terrain data.
    var elevation: ElevationReading {
        guard let fix else { return .pending(" ") }
        if let alt = fix.altitude, let acc = fix.altitudeAccuracy {
            return .value(metres: alt, fromGPS: true, source: "GPS \(Geo.accuracy(acc, feet: feet))")
        }
        if let ground { return .value(metres: ground.metres, fromGPS: false, source: "Terrain data") }
        switch groundState {
        case .failed: return .pending("Needs a connection")
        default: return .pending("Looking it up…")
        }
    }

    /// The header's first line.
    var placeTitle: String {
        if let place { return place }
        if fix == nil { return locating ? "Finding where you are…" : "Bearings" }
        return placeLookedUp ? "Bearings" : "Finding where you are…"
    }

    /// "Magnetic north" or "True north", and the declination.
    var northLabel: String {
        var text = usingTrueNorth ? "True north" : "Magnetic north"
        if usingTrueNorth, let d = declination, abs(d) >= 0.5 {
            text += " · \(Int(Geo.jsRound(abs(d))))° \(d >= 0 ? "E" : "W")"
        }
        return text
    }

    /// The status line under the readout: "True north · 8° E declination · ±8° accuracy".
    var statusText: String {
        var parts = [usingTrueNorth ? "True north" : "Magnetic north"]
        if usingTrueNorth, let d = declination, abs(d) >= 0.5 {
            parts.append("\(Int(Geo.jsRound(abs(d))))° \(d >= 0 ? "E" : "W") declination")
        }
        if let acc = headingAccuracy { parts.append("±\(Int(acc.rounded()))° accuracy") }
        return parts.joined(separator: " · ")
    }

    /// The status line spelled out for VoiceOver: "True north, 8 degrees east declination, plus or minus
    /// 8 degrees accuracy".
    var spokenStatus: String {
        var parts = [usingTrueNorth ? "True north" : "Magnetic north"]
        if usingTrueNorth, let d = declination, abs(d) >= 0.5 {
            parts.append("\(Int(Geo.jsRound(abs(d)))) degrees \(d >= 0 ? "east" : "west") declination")
        }
        if let acc = headingAccuracy { parts.append("plus or minus \(Int(acc.rounded())) degrees accuracy") }
        return parts.joined(separator: ", ")
    }

    /// No compass here (a Mac, or a device without one): the dial rests at north, faded.
    var noCompass: Bool { compass == .unavailable && heading == nil }

    /// Accuracy worse than this asks for a figure 8.
    static let poorHeadingAccuracy = 25.0

    /// A warning that takes the subline's place: a magnet nearby first, then low accuracy.
    var compassWarning: String? {
        guard compass == .live else { return nil }
        if let f = fieldStrength, f < 20 || f > 70 { return "Magnet or metal nearby: move away" }
        if let acc = headingAccuracy, acc > Self.poorHeadingAccuracy { return "Low accuracy: move your phone in a figure 8" }
        return nil
    }

    var lockText: String? {
        guard let lock, let heading else { return nil }
        let d = Int(Geo.jsRound(Geo.delta(from: heading, to: lock)))
        let how = d == 0 ? "on bearing" : "turn \(abs(d))° \(d > 0 ? "right" : "left")"
        return "Locked \(Int(lock.rounded()) % 360)° · \(how)"
    }

    func toggleLock() {
        guard let heading else { return }
        lock = lock == nil ? Double(Int(heading.rounded()) % 360) : nil
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    func cycleFormat() { format = format.next }

    /// Shows a layout without saving it (the `--layout` launch argument; CI's screenshots).
    func showLayout(_ id: String) {
        layoutForThisLaunch = true
        layout = Layout.of(id)
        layoutForThisLaunch = false
    }

    /// One layout larger or smaller (⌘= and ⌘−, the dial's VoiceOver actions, a pinch). False at the ends.
    @discardableResult
    func stepLayout(larger: Bool) -> Bool {
        guard let next = larger ? layout.larger : layout.smaller else { return false }
        layout = next
        return true
    }

    /// Where a true bearing sits on the card, which is turned to magnetic north when that's in use.
    func cardAngle(_ trueBearing: Double) -> Double {
        if !usingTrueNorth, let d = declination { return Geo.normalize(trueBearing - d) }
        return trueBearing
    }

    // MARK: Sun and moon, now

    var sunPosition: Sky.Position? { fix.map { Sky.sunPosition(at: now, lat: $0.latitude, lon: $0.longitude) } }
    var moonPosition: Sky.Position? { fix.map { Sky.moonPosition(at: now, lat: $0.latitude, lon: $0.longitude) } }
    var sunTimes: Sky.Times? { fix.map { Sky.sunTimes(at: now, lat: $0.latitude, lon: $0.longitude) } }
    var moonPhase: Sky.Phase { Sky.moonPhase(at: now) }

    // MARK: A marked spot

    func markSpot() {
        guard let fix else { return }
        spot = Spot(latitude: fix.latitude, longitude: fix.longitude)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    func clearSpot() { spot = nil }

    /// Locks the bearing toward the marked spot, on the same north as the dial (the spot line's menu).
    func lockToSpot() {
        guard let b = spotBearing else { return }
        lock = Double(Int(Geo.jsRound(cardAngle(b))) % 360)
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    /// Metres from here to the marked spot.
    var spotDistance: Double? {
        guard let fix, let spot else { return nil }
        return Geo.distance(lat1: fix.latitude, lon1: fix.longitude, lat2: spot.latitude, lon2: spot.longitude)
    }

    /// The true bearing from here to the marked spot.
    var spotBearing: Double? {
        guard let fix, let spot else { return nil }
        return Geo.bearing(lat1: fix.latitude, lon1: fix.longitude, lat2: spot.latitude, lon2: spot.longitude)
    }

    /// "0.4 mi · 245° SW", the bearing toward the same north as the dial.
    var spotText: String? {
        guard let d = spotDistance, let b = spotBearing else { return nil }
        let shown = cardAngle(b)
        return "\(Geo.distanceText(d, feet: feet)) · \(Int(Geo.jsRound(shown)) % 360)° \(Geo.point(shown))"
    }

    // MARK: Copy and share

    var copyText: String? {
        guard let fix else { return nil }
        return Geo.copyText(format, lat: fix.latitude, lon: fix.longitude)
    }

    /// The coordinates and an Apple Maps link, for Share My Location.
    var shareLocationText: String? {
        guard let fix, let copyText else { return nil }
        return "\(copyText)\n\(Self.mapsURL(fix).absoluteString)"
    }

    static func mapsURL(_ fix: Fix) -> URL {
        URL(string: String(format: "https://maps.apple.com/?ll=%.5f,%.5f&q=My%%20Location&z=16", fix.latitude, fix.longitude))!
    }

    // MARK: A sample place (screenshots, and the self-tests' drawings)

    /// 9:41 AM in Colorado on 1 November 2026, with the sun and the moon both up over Maroon Bells.
    static let sampleTime = Date(timeIntervalSince1970: 1793551260)

    /// `noCompass`: the same place on a device without a compass (CI's no-compass photographs): no heading,
    /// the rose at rest, "—°" and the no-compass note.
    func showSample(heading sampleHeading: Double = 228, lock sampleLock: Double? = nil, noCompass: Bool = false) {
        stop()
        sample = true
        now = Self.sampleTime
        fix = Fix(latitude: 39.09898, longitude: -106.94117, accuracy: 5, altitude: nil, altitudeAccuracy: nil, time: Self.sampleTime)
        ground = Ground(metres: 2922, latitude: 39.099, longitude: -106.941)
        groundState = .ok
        place = "Maroon Bells, Colorado"
        placeLookedUp = true
        usingTrueNorth = true
        declination = 7.6
        headingAccuracy = 8
        fieldStrength = 51
        smoother.reset()
        if noCompass {
            compass = .unavailable
            heading = nil
            headingAccuracy = nil
            cardRotation = 0
            tilt = nil
            lock = nil
        } else {
            compass = .live
            setHeading(sampleHeading)
            tilt = CGVector(dx: 0.02, dy: -0.015)
            lock = sampleLock
        }
        spot = Spot(latitude: 39.1911, longitude: -106.8175)
        speed = 1.43
        pressure = 712.4
        locating = false
        access = .allowed
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            updateAccess()
            if started && access == .allowed && !sample { locating = fix == nil; manager.startUpdatingLocation() }
            if access == .denied { locating = false }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let last = locations.last else { return }
        Task { @MainActor in if !sample { take(last) } }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in locating = false }
    }

    #if os(iOS)
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let magnetic = newHeading.magneticHeading, trueHeading = newHeading.trueHeading, accuracy = newHeading.headingAccuracy
        // The raw field, microteslas: far from Earth's 25–65 means a magnet or metal is bending it.
        let field = (newHeading.x * newHeading.x + newHeading.y * newHeading.y + newHeading.z * newHeading.z).squareRoot()
        Task { @MainActor in if !sample { takeHeading(magnetic: magnetic, trueHeading: trueHeading, accuracy: accuracy, field: field) } }
    }

    /// Bearings shows its own figure-8 hint when the compass needs it, instead of iOS's full-screen one.
    nonisolated func locationManagerShouldDisplayHeadingCalibration(_ manager: CLLocationManager) -> Bool { false }
    #endif
}
