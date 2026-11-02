#!/usr/bin/env python3
"""Revoke the throwaway "Apple Development: Created via API" certificates.

Every cloud build that signs with -allowProvisioningUpdates makes a new Apple Development certificate
whose private key lives only on that runner and is gone when the runner is. Apple allows only a few
development certificates per team, so after a handful of builds signing fails. This revokes those
leftovers, and nothing else: only development certificate types, and only ones named
"Created via API". Developer ID and Apple Distribution certificates are never touched.

Needs ASC_KEY_ID, ASC_ISSUER_ID and ASC_KEY_P8 in the environment. Pass --dry-run to only list.
"""
import base64, json, os, sys, time, urllib.request

API = "https://api.appstoreconnect.apple.com/v1/certificates"
DEV_TYPES = {"DEVELOPMENT", "IOS_DEVELOPMENT", "MAC_APP_DEVELOPMENT"}
MARK = "Created via API"


def throwaway(cert):
    a = cert.get("attributes", {})
    names = f'{a.get("name", "")} {a.get("displayName", "")}'
    return a.get("certificateType") in DEV_TYPES and MARK in names


def token():
    import jwt  # PyJWT with cryptography
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600,
                       "aud": "appstoreconnect-v1"}, os.environ["ASC_KEY_P8"], algorithm="ES256",
                      headers={"kid": os.environ["ASC_KEY_ID"], "typ": "JWT"})


def call(method, url, tok):
    req = urllib.request.Request(url, method=method, headers={"Authorization": f"Bearer {tok}"})
    with urllib.request.urlopen(req, timeout=30) as r:
        body = r.read()
        return json.loads(body) if body else None


def main():
    dry = "--dry-run" in sys.argv
    tok = token()
    certs, url = [], f"{API}?limit=200"
    while url:
        page = call("GET", url, tok)
        certs += page.get("data", [])
        url = page.get("links", {}).get("next")
    gone = [c for c in certs if throwaway(c)]
    print(f"{len(certs)} certificates on the team; {len(gone)} throwaway development certificates.")
    for c in gone:
        a = c["attributes"]
        print(f'  {"would revoke" if dry else "revoking"} {a.get("name")} ({a.get("certificateType")}, '
              f'serial {a.get("serialNumber")}, expires {a.get("expirationDate")})')
        if not dry:
            call("DELETE", f'{API}/{c["id"]}', tok)


if __name__ == "__main__":
    main()
