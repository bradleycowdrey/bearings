#!/usr/bin/env python3
"""Print the app record and its recent builds in App Store Connect, with processing state.

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8. Read-only."""
import json, os, time, urllib.request, urllib.parse
import jwt

BUNDLE = "com.bradcowdrey.bearings"
now = int(time.time())
TOK = jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
                 os.environ["ASC_KEY_P8"], algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def get(path, **q):
    url = "https://api.appstoreconnect.apple.com" + path + ("?" + urllib.parse.urlencode(q) if q else "")
    with urllib.request.urlopen(urllib.request.Request(url, headers={"Authorization": f"Bearer {TOK}"}), timeout=30) as r:
        return json.load(r)


apps = get("/v1/apps", **{"filter[bundleId]": BUNDLE})["data"]
if not apps:
    print(f"No app record for {BUNDLE}.")
    raise SystemExit
app = apps[0]
print(f'App record: {app["attributes"]["name"]} ({BUNDLE}), id {app["id"]}')
builds = get("/v1/builds", **{"filter[app]": app["id"], "sort": "-uploadedDate", "limit": "10",
                              "include": "preReleaseVersion,buildBetaDetail"})
detail = {i["id"]: i["attributes"] for i in builds.get("included", []) if i["type"] == "buildBetaDetails"}
vers = {i["id"]: i["attributes"].get("version") for i in builds.get("included", []) if i["type"] == "preReleaseVersions"}
if not builds["data"]:
    print("No builds yet.")
# Uploads, with Apple's errors for ones that failed processing (newer API; skipped if unavailable).
try:
    ups = get(f'/v1/apps/{app["id"]}/buildUploads', limit="10")
    for u in ups.get("data", []):
        print("upload:", json.dumps(u.get("attributes", {}), indent=1))
except Exception as e:
    print(f"(build uploads not available: {e})")
for b in builds["data"]:
    a, r = b["attributes"], b.get("relationships", {})
    v = vers.get((r.get("preReleaseVersion", {}).get("data") or {}).get("id"), "?")
    d = detail.get((r.get("buildBetaDetail", {}).get("data") or {}).get("id"), {})
    print(f'  {v} ({a.get("version")}): processing={a.get("processingState")} expired={a.get("expired")} '
          f'encryption-answered={a.get("usesNonExemptEncryption") is not None} '
          f'internal={d.get("internalBuildState")} external={d.get("externalBuildState")} uploaded={a.get("uploadedDate")}')

# Each build's icon as App Store Connect sees it (saved to asc-icons/ when ASC_ICONS_DIR is set).
out = os.environ.get("ASC_ICONS_DIR")
for b in builds["data"]:
    tok = (b["attributes"].get("iconAssetToken") or {}).get("templateUrl")
    print(f'  icon of build {b["attributes"].get("version")}: {tok or "none"}')
    if out and tok:
        os.makedirs(out, exist_ok=True)
        url = tok.replace("{w}", "512").replace("{h}", "512").replace("{f}", "png")
        with urllib.request.urlopen(url, timeout=30) as r, open(f'{out}/build-{b["attributes"].get("version")}.png', "wb") as f:
            f.write(r.read())
