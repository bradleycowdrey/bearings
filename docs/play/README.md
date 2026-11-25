# Bearings on Google Play

Everything Google Play needs for Bearings (package `com.bradcowdrey.bearings`), and how new builds reach testers.
A personal developer account must run a **closed test with at least 12 testers, opted in for 14 days in a row**,
before it can apply for production.

## What's in this folder

- `listing.json`: the store listing (title "Bearings Compass", short and full description, contact email and
  website). Play's limits are 30, 80 and 4,000 characters.
- `icon.png`: 512 × 512, from the full-bleed iOS icon (`Resources/iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png`,
  drawn by `scripts/make-art.js`). Play rounds the corners itself.
- `feature-graphic.png`: 1024 × 500, the icon, "Bearings" and "Compass, place, elevation, sun and moon" on the sky.
- `phone-1.png` to `phone-6.png`: real Android screenshots from the
  [`ci-shots-android`](https://github.com/bradleycowdrey/bearings/tree/ci-shots-android) branch, in the App Store's
  order: the compass (Extra Large, `android-17-store-xl`), place and time (Small, `android-18-store-small`), elevation
  (Medium, `android-16-store`), the sun and moon (Large, `android-19-store-large`), the map (`android-11-map-sheet`)
  and night mode (`android-20-store-night`). The status and navigation bars are cropped off and the sides padded
  with the app's black, because Play allows at most 2:1. There's no Android widget picture on a Home Screen yet, so
  the widgets aren't shown.

## How it gets to Play

- **Store listing**: `.github/workflows/play-listing.yml` sends this folder to Play whenever it changes on `main`,
  or when you run it by hand (Actions, Google Play listing, Run workflow).
- **New builds for testers**: the last step of `.github/workflows/android.yml` ("Google Play closed test") sends
  the signed App Bundle to the closed test (Play's `alpha` track). It runs only for runs on `main` started by
  hand (Actions, Android, Run workflow) or by `release.yml` / `finish-release.yml` after a new version is
  published, only when the self-test passed, and only when the upload key secrets are set. Ordinary pushes, pull
  requests and other branches never upload.
- **Version codes**: `versionCode` is the number of commits in `main`'s history (`git rev-list --count HEAD`, the
  same build number as the iPhone and Mac apps; the workflow checks out the full history). Every commit on `main`
  raises it, so each upload is higher than the last. Running the same commit again gives the same code, and the
  upload is skipped. Branches never upload because their count can run ahead of `main`. Don't force-push `main`
  to a shorter history, or the codes would go down.
- Each release is named like "2.4.0 (83)", with the first paragraph of that version's `CHANGELOG.md` entry as
  "What's new".

## Repository secrets

- `PLAY_SERVICE_ACCOUNT_JSON` (new): the JSON key of a Google Cloud service account with the Google Play Android
  Developer API enabled (the same one can serve all your apps). Without it, both Play steps do nothing and every
  build still passes.
- `ANDROID_KEYSTORE_B64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` (already used by
  `android.yml`): the key that signs the release APK and App Bundle. It is the **upload key** for Play. Without
  these the build signs with a throwaway debug key and skips Play.

## One-time steps in Play Console

1. **Create app**: App name "Bearings Compass", default language English (United States), App, Free; accept the
   declarations. Play doesn't ask for the package name here: it takes it from the first App Bundle.
2. **Set up the closed test**: Testing, Closed testing. Use the default track (Closed testing, Alpha) or create
   one. Testers: create an email list with at least 12 testers' Google account emails (a few spare helps).
   Countries and regions: add the countries your testers are in (or all).
3. **Upload the first App Bundle by hand**: in GitHub, Actions, Android, open the latest successful run on `main`
   (or Run workflow to make one) and download its `bearings-android` artifact; inside is `app-release.aab`. Check
   that run's "Build and unit-test" log says "Release APK signed with the permanent key". In the closed testing
   track: Create new release, accept Play App Signing (Google holds the app signing key; your keystore stays the
   upload key), upload `app-release.aab`, Next, Save. Note: Play's copy is then signed by Google's key, not the
   one on the GitHub `Bearings.apk`, so a tester who installed that APK must uninstall it first (losing the marked
   spot and settings). To let them update in place instead, choose to use your own app signing key at that step
   and upload the `ANDROID_KEYSTORE` key with Play's export tool.
4. **Let the workflow in**: Users and permissions, Invite new users, the service account's email; app
   permissions for Bearings: Release apps to testing tracks, Manage testing tracks and edit tester lists, and
   Manage store presence. Then run "Google Play listing" by hand to fill the store listing. From now on,
   `android.yml` uploads each new version (and each run you start by hand) itself.
5. **App content** (Policy, App content): the answers below.
6. **Store settings**: App category: Maps & Navigation. Contact details: email legal@bradcowdrey.com, website
   https://bradcowdrey.com/bearings (the workflow sends these too).
7. **Send for review**: Publishing overview, Send changes for review, then roll out the first release to the
   closed test. Share the test's opt-in link with the testers.
8. **12 testers, 14 days**: at least 12 testers must stay opted in for 14 days in a row. Then Dashboard, Apply
   for production, and answer Google's questions about the test.

## Suggested App content answers

Checked against the Android code (`android/`) and the Terms (`TERMS.md`, Sections 15 and 25).

- **Privacy policy**: https://bradcowdrey.com/legal
- **Ads**: No, the app has no ads.
- **App access**: All functionality is available without special access (no account, no login). Bearings shows
  the terms first, then asks for location; without location the compass still works.
- **Content rating**: category "All Other App Types". Violence, sexuality, language, controlled substances, crude
  humour, gambling: all No. Users interact or exchange content: No. Shares the user's location with other users:
  No (Bearings has no other users; "Share My Location…" hands text to an app the person picks, through Android's
  share sheet; answering Yes only adds a "Shares location" note). Digital purchases: No. Web browser or search
  engine: No. Expect Everyone / PEGI 3 / IARC 3+.
- **Target audience**: 13 to 15, 16 to 17, and 18 and over. Not designed for children; the Terms aren't directed
  at children under 13. The listing doesn't appeal to children.
- **Data safety**:
  - Collects or shares user data: Yes. Encrypted in transit: Yes (HTTPS only). Accounts: none. Way to request
    deletion: No (nothing is kept by Bradley; there's nothing to delete).
  - **Location, precise**: Collected: Yes. Shared: Yes. Processed ephemerally: No. Optional (the person can deny
    location and still use the compass). Purpose: App functionality only. Why: the app and its widget send a
    position rounded to about 100 m to Open-Meteo for the ground elevation, and the map loads tiles for where you
    are from OpenFreeMap. Google counts anything finer than about 3 km² as precise.
  - Every other type (personal info, financial, health, messages, photos and videos, audio, files, calendar,
    contacts, app activity, web browsing, app info and performance, device or other IDs): not collected. No
    analytics, no crash reporting, no advertising ID.
  - Where Google's definitions leave room for judgement: Open-Meteo and OpenFreeMap could be treated as service
    providers (then "Shared: No"), but they're independent public services under their own privacy policies, so
    "Shared: Yes" is the safer answer. Bearings can't vouch for their server logs, so "ephemeral" is No. The place name
    comes from the phone's own geocoder (Android's location service, usually Google's), which Bearings doesn't
    send anything to itself; it isn't counted here. "Share My Location" and "Copy Coordinates" happen only when
    the person chooses, which Google doesn't count as sharing. The marked spot and settings stay on the device
    (Android's own backup may copy them to the person's Google account; that isn't collection by the app).
- **Advertising ID**: No. **News app**: No. **Government app**: No. **Financial features**: none. **Health**: none.
  Bearings asks for no background location and runs no foreground service; if Play Console asks, say so.
