#!/usr/bin/env bash
# Builds the docs/ folder that GitHub Pages serves, and that bradcowdrey.com/bearings shows:
#   docs/index.html  the product page (web/site.html), which embeds the app
#   docs/app.html    the app: web/app.html (written without <html>/<head> so it can also be published as a
#                    claude.ai Artifact) with web/core.js inlined, wrapped into a standalone page
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p docs
[ -f web/site.html ] && cp web/site.html docs/index.html
cp Resources/Cities.tsv docs/cities.tsv   # names where you are, offline
python3 - <<'PY'
core = open("web/core.js").read()
app = open("web/app.html").read().replace("/* __CORE__ */", core)
head = ('<!doctype html><html lang="en"><head><meta charset="utf-8">'
        '<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">'
        '<link rel="icon" href="icon.png"><link rel="apple-touch-icon" href="icon.png"></head><body>\n')
open("docs/app.html", "w").write(head + app + "\n</body></html>\n")
PY
echo "Built docs/index.html and docs/app.html"
