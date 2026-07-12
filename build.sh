#!/bin/bash
set -euo pipefail

# Build, test, and package NoNoNo.
#
# This script runs ON THE MAC (via the mac-builder daemon, or directly on a
# local checkout).
#
# Prerequisites:
#   brew install xcodegen   (one-time)
#
# Usage:
#   bash build.sh test         # run XCTests (unit + UI) on simulator
#   bash build.sh archive      # xcodegen + xcodebuild archive only
#   bash build.sh ota          # archive → export IPA → publish OTA install link
#   bash build.sh ship         # test → ota (the full pipeline)
#   bash build.sh ci           # test → archive (no publishing)
#   bash build.sh install      # install last archive to a connected device

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

BUILD_DIR="$SCRIPT_DIR/build"
SCHEME="NoNoNo"
BUNDLE_ID="me.citywok.nonono"
ARCHIVE_PATH="$BUILD_DIR/$SCHEME.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
EXPORT_OPTIONS_PLIST="$SCRIPT_DIR/ExportOptions.plist"
XCODE_DERIVED_DATA="${XCODE_DERIVED_DATA:-$BUILD_DIR/DerivedData}"
# UI test runners fail preflight checks on parallel simulator clones, so run
# the suite serially on the booted simulator.
XCB_PARALLEL="${XCB_PARALLEL:-NO}"
XCB_PARALLEL_WORKERS="${XCB_PARALLEL_WORKERS:-1}"

VERSION="${VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git rev-list --count HEAD 2>/dev/null || echo 1)}"

# App Store Connect API key for headless provisioning (no signed-in Xcode
# account on the builder) and TestFlight uploads. Key/issuer ids are not
# secrets; the .p8 private key lives only on the Mac at
# ~/.appstoreconnect/private_keys/AuthKey_<ASC_KEY_ID>.p8.
ASC_KEY_ID="${ASC_KEY_ID:-MA894X726H}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-69a6de98-0f77-47e3-e053-5b8c7c11a4d1}"
ASC_AUTH_KEY_PATH="${ASC_AUTH_KEY_PATH:-$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8}"

asc_auth_flags=()
if [[ -f "$ASC_AUTH_KEY_PATH" ]]; then
    asc_auth_flags=(
        -authenticationKeyPath "$ASC_AUTH_KEY_PATH"
        -authenticationKeyID "$ASC_KEY_ID"
        -authenticationKeyIssuerID "$ASC_ISSUER_ID"
    )
fi

BUCKET="${BUILD_BUCKET:-cct-golf-builds}"
REGION="${AWS_REGION:-us-east-1}"

# ── Helpers ─────────────────────────────────────────────────
find_simulator() {
    xcrun simctl list devices available -j 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    if 'iOS' not in runtime:
        continue
    for d in devices:
        if 'iPhone' in d['name'] and d['isAvailable']:
            print(d['udid'])
            sys.exit(0)
print('')
" 2>/dev/null || true
}

find_device() {
    JSON_TMP=$(mktemp /tmp/devicectl.XXXXXX.json)
    xcrun devicectl list devices --json-output "$JSON_TMP" >/dev/null 2>/dev/null || true
    python3 -c "
import json
with open('$JSON_TMP') as f:
    data = json.load(f)
for d in data.get('result',{}).get('devices',[]):
    cp = d.get('connectionProperties',{})
    hw = d.get('hardwareProperties',{})
    if hw.get('deviceType') == 'iPhone' and cp.get('tunnelState') == 'connected':
        print(hw['udid'])
        break
" 2>/dev/null || true
    rm -f "$JSON_TMP"
}

# ── Phases ──────────────────────────────────────────────────
phase_generate() {
    echo "==> Generating Xcode project..."
    if ! command -v xcodegen &>/dev/null; then
        echo "    Installing xcodegen..."
        brew install xcodegen
    fi
    xcodegen generate --spec project.yml 2>&1
    echo "    ✓ Generated $SCHEME.xcodeproj"
}

phase_test() {
    echo "==> Running XCTests (unit + UI)..."
    SIM_UDID=$(find_simulator)
    if [[ -z "$SIM_UDID" ]]; then
        echo "ERROR: No iPhone simulator available"
        exit 1
    fi
    echo "    Simulator: $SIM_UDID"

    SIM_STATE=$(xcrun simctl list devices -j 2>/dev/null \
        | python3 -c "
import json, sys
data = json.load(sys.stdin)
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d['udid'] == '$SIM_UDID':
            print(d['state'])
            sys.exit(0)
print('Unknown')
" 2>/dev/null || echo "Unknown")

    if [[ "$SIM_STATE" != "Booted" ]]; then
        echo "    Booting simulator..."
        xcrun simctl boot "$SIM_UDID" 2>/dev/null || true
        sleep 3
    fi

    TEST_LOG="$BUILD_DIR/test.log"
    mkdir -p "$BUILD_DIR"

    set +e
    xcodebuild test \
        -project "$SCHEME.xcodeproj" \
        -scheme "$SCHEME" \
        -destination "platform=iOS Simulator,id=$SIM_UDID" \
        -derivedDataPath "$XCODE_DERIVED_DATA" \
        -resultBundlePath "$BUILD_DIR/TestResults.xcresult" \
        -parallel-testing-enabled "$XCB_PARALLEL" \
        -parallel-testing-worker-count "$XCB_PARALLEL_WORKERS" \
        -maximum-concurrent-test-simulator-destinations "$XCB_PARALLEL_WORKERS" \
        2>&1 | tee "$TEST_LOG"
    TEST_EXIT=${PIPESTATUS[0]}
    set -e

    PASSED=$(grep -c "Test [Cc]ase.*passed" "$TEST_LOG" 2>/dev/null || true)
    FAILED=$(grep -c "Test [Cc]ase.*failed" "$TEST_LOG" 2>/dev/null || true)
    echo ""
    echo "    Tests: $PASSED passed, $FAILED failed"

    if [[ $TEST_EXIT -ne 0 ]]; then
        echo "    ✗ TESTS FAILED"
        echo ""
        echo "==> Failures:"
        grep "Test Case.*failed" "$TEST_LOG" 2>/dev/null || true
        exit 1
    fi
    echo "    ✓ All tests passed"
}

phase_archive() {
    echo "==> Archiving $SCHEME (Release)..."
    mkdir -p "$BUILD_DIR"
    xcodebuild archive \
        -project "$SCHEME.xcodeproj" \
        -scheme "$SCHEME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=iOS" \
        -derivedDataPath "$XCODE_DERIVED_DATA" \
        -allowProvisioningUpdates \
        ${asc_auth_flags[@]+"${asc_auth_flags[@]}"} \
        CODE_SIGN_STYLE=Automatic \
        DEVELOPMENT_TEAM=827WYA3YJJ \
        MARKETING_VERSION="$VERSION" \
        CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
        -quiet
    echo "    ✓ Archive: $ARCHIVE_PATH"
}

phase_export_ipa() {
    echo "==> Exporting IPA..."
    rm -rf "$EXPORT_DIR"
    mkdir -p "$EXPORT_DIR"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_DIR" \
        -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" \
        -allowProvisioningUpdates \
        ${asc_auth_flags[@]+"${asc_auth_flags[@]}"}
    local ipa
    ipa="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' -print -quit)"
    if [[ -z "$ipa" ]]; then
        echo "ERROR: IPA export produced no .ipa" >&2
        exit 1
    fi
    echo "    ✓ Exported $(basename "$ipa")"
}

phase_publish_ota() {
    if ! command -v aws >/dev/null 2>&1; then
        echo "ERROR: aws CLI unavailable; cannot publish OTA" >&2
        exit 1
    fi
    local ipa commit prefix ipa_key manifest_key page_key
    ipa="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' -print -quit)"
    if [[ -z "$ipa" ]]; then
        echo "ERROR: no IPA in $EXPORT_DIR — run 'ota' from the start" >&2
        exit 1
    fi
    commit="$(git rev-parse --short=8 HEAD 2>/dev/null || echo unknown)"
    prefix="builds/nonono/$(date +%Y%m%d-%H%M%S)-${commit}"
    ipa_key="$prefix/NoNoNo.ipa"
    manifest_key="$prefix/manifest.plist"
    page_key="$prefix/install.html"

    echo "==> Uploading IPA to s3://$BUCKET/$ipa_key ..."
    aws s3 cp "$ipa" "s3://$BUCKET/$ipa_key" --region "$REGION"

    local ipa_url manifest_url install_url page_url
    ipa_url="$(aws s3 presign "s3://$BUCKET/$ipa_key" --region "$REGION" --expires-in 604800)"

    echo "==> Writing OTA manifest..."
    python3 - "$BUILD_DIR/manifest.plist" "$ipa_url" "$VERSION" <<'PY'
import sys
from xml.sax.saxutils import escape
path, ipa_url, version = sys.argv[1:4]
manifest = f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>{escape(ipa_url)}</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>me.citywok.nonono</string>
        <key>bundle-version</key>
        <string>{escape(version)}</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>NO NO NO!</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
"""
open(path, "w", encoding="utf-8").write(manifest)
PY
    aws s3 cp "$BUILD_DIR/manifest.plist" "s3://$BUCKET/$manifest_key" \
        --region "$REGION" --content-type "application/xml"
    manifest_url="$(aws s3 presign "s3://$BUCKET/$manifest_key" --region "$REGION" --expires-in 604800)"
    install_url="$(python3 - "$manifest_url" <<'PY'
import sys
from urllib.parse import quote
print("itms-services://?action=download-manifest&url=" + quote(sys.argv[1], safe=""))
PY
)"

    echo "==> Writing install page..."
    python3 - "$BUILD_DIR/install.html" "$install_url" "$VERSION" "$BUILD_NUMBER" "$commit" <<'PY'
import html
import sys
from datetime import datetime, timezone
path, install_url, version, build_number, commit = sys.argv[1:6]
stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Install NoNoNo</title>
<style>
  body {{ font-family: -apple-system, sans-serif; background: #A81616; margin: 0;
         display: flex; min-height: 100vh; align-items: center; justify-content: center; }}
  .card {{ background: white; border-radius: 24px; padding: 40px 32px; text-align: center;
          box-shadow: 0 10px 30px rgba(0,0,0,.08); max-width: 340px; margin: 20px; }}
  h1 {{ color: #A81616; font-size: 30px; margin: 8px 0; font-weight: 900; }}
  p {{ color: #9a8580; font-size: 14px; line-height: 1.5; }}
  .btn {{ display: block; background: #D9260F; color: white; text-decoration: none;
         font-size: 19px; font-weight: 600; padding: 16px 24px; border-radius: 999px;
         margin: 24px 0 12px; }}
  .meta {{ font-size: 12px; color: #b5a6a1; }}
</style>
</head>
<body>
<div class="card">
  <div style="font-size:56px">😤</div>
  <h1>NO NO NO!</h1>
  <p>The rage game. Smack everything he hates. Do NOT touch the mai tai. He is not a redhead. (He is.)</p>
  <a class="btn" href="{html.escape(install_url, quote=True)}">Install on iPhone</a>
  <p class="meta">v{html.escape(version)} (build {html.escape(build_number)}) · {html.escape(commit)}<br>{stamp}<br>
  Open this page in Safari on your iPhone, tap Install, then confirm the iOS prompt.
  The icon appears on your home screen after a short download.</p>
</div>
</body>
</html>
"""
open(path, "w", encoding="utf-8").write(page)
PY
    aws s3 cp "$BUILD_DIR/install.html" "s3://$BUCKET/$page_key" \
        --region "$REGION" --content-type "text/html"
    page_url="$(aws s3 presign "s3://$BUCKET/$page_key" --region "$REGION" --expires-in 604800)"

    echo ""
    echo "    ✓ OTA package published (links valid 7 days)"
    echo "INSTALL_PAGE_URL: $page_url"
    echo "ITMS_URL: $install_url"
    echo "IPA_URL: $ipa_url"
}

# Resolve the next TestFlight build number as (max build on App Store
# Connect) + 1, so re-runs never collide. Requires the app record to exist.
resolve_testflight_build_number() {
    local asc_max
    asc_max="$(/usr/bin/python3 - "$ASC_KEY_ID" "$ASC_ISSUER_ID" "$ASC_AUTH_KEY_PATH" "$BUNDLE_ID" <<'PY'
import sys, time, json, urllib.request, urllib.parse
import jwt

kid, iss, keyp, bundle_id = sys.argv[1:5]
key = open(keyp).read()
now = int(time.time())
tok = jwt.encode({"iss": iss, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
                 key, algorithm="ES256", headers={"kid": kid, "typ": "JWT"})
headers = {"Authorization": f"Bearer {tok}"}

req = urllib.request.Request(
    "https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]="
    + urllib.parse.quote(bundle_id), headers=headers)
apps = json.load(urllib.request.urlopen(req, timeout=30)).get("data", [])
if not apps:
    print("NO_APP_RECORD")
    sys.exit(0)
app_id = apps[0]["id"]

req = urllib.request.Request(
    f"https://api.appstoreconnect.apple.com/v1/builds?filter[app]={app_id}&limit=200",
    headers=headers)
data = json.load(urllib.request.urlopen(req, timeout=30))
mx = 0
for b in data.get("data", []):
    try:
        mx = max(mx, int(b["attributes"].get("version") or 0))
    except (TypeError, ValueError):
        pass
print(mx)
PY
)"
    if [[ "$asc_max" == "NO_APP_RECORD" ]]; then
        echo "ERROR: no App Store Connect app record for $BUNDLE_ID." >&2
        echo "       Create it once at appstoreconnect.apple.com: My Apps -> + -> New App" >&2
        echo "       (platform iOS, name NoNoNo, bundle $BUNDLE_ID, SKU nonono)" >&2
        exit 1
    fi
    case "$asc_max" in
        ''|*[!0-9]*) echo "ERROR: could not resolve ASC max build (got '$asc_max')" >&2; exit 1;;
    esac
    # Floor against the git commit count so the number is strictly monotonic
    # and unique even when a just-uploaded build hasn't registered in ASC yet
    # (ASC-max alone lags during processing and collided across rapid uploads).
    local gitcount
    gitcount="$(git rev-list --count HEAD 2>/dev/null || echo 0)"
    BUILD_NUMBER=$(( asc_max + 1 > gitcount ? asc_max + 1 : gitcount ))
    echo "    TestFlight build number: $BUILD_NUMBER (ASC max $asc_max, git $gitcount)"
}

phase_export_appstore() {
    echo "==> Exporting App Store IPA..."
    rm -rf "$EXPORT_DIR"
    mkdir -p "$EXPORT_DIR"
    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_DIR" \
        -exportOptionsPlist "$SCRIPT_DIR/ExportOptions-AppStore.plist" \
        -allowProvisioningUpdates \
        ${asc_auth_flags[@]+"${asc_auth_flags[@]}"}
    echo "    ✓ Exported to $EXPORT_DIR"
}

phase_upload_testflight() {
    local ipa
    ipa="$(find "$EXPORT_DIR" -maxdepth 1 -name '*.ipa' -print -quit)"
    if [[ -z "$ipa" ]]; then
        echo "ERROR: no IPA found in $EXPORT_DIR to upload" >&2
        exit 1
    fi
    if [[ ! -f "$ASC_AUTH_KEY_PATH" ]]; then
        echo "ERROR: missing $ASC_AUTH_KEY_PATH for TestFlight upload" >&2
        exit 1
    fi
    echo "==> Uploading $(basename "$ipa") to App Store Connect (TestFlight)..."
    xcrun altool --upload-app --type ios --file "$ipa" \
        --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"
    echo "    ✓ Upload complete — build $BUILD_NUMBER appears in TestFlight"
    echo "      after App Store Connect finishes processing (5-30 min)."
}

phase_install() {
    APP_PATH="$ARCHIVE_PATH/Products/Applications/$SCHEME.app"
    if [[ ! -d "$APP_PATH" ]]; then
        echo "ERROR: No archive at $APP_PATH — run 'archive' first"
        exit 1
    fi
    echo "==> Finding connected device..."
    UDID=$(find_device)
    if [[ -z "$UDID" ]]; then
        echo "ERROR: no connected iPhone"
        exit 1
    fi
    echo "    Device: $UDID"
    echo "==> Installing..."
    xcrun devicectl device install app --device "$UDID" "$APP_PATH" 2>&1
    echo "    ✓ $SCHEME installed on device"
}

# ── Main ────────────────────────────────────────────────────
ACTION="${1:-test}"

case "$ACTION" in
    test)
        phase_generate
        phase_test
        ;;
    archive)
        phase_generate
        phase_archive
        ;;
    ota)
        phase_generate
        phase_archive
        phase_export_ipa
        phase_publish_ota
        ;;
    ship)
        phase_generate
        phase_test
        phase_archive
        phase_export_ipa
        phase_publish_ota
        echo ""
        echo "==> Ship complete: tested, archived, OTA published"
        ;;
    ci)
        phase_generate
        phase_test
        phase_archive
        ;;
    testflight)
        resolve_testflight_build_number
        phase_generate
        phase_archive
        phase_export_appstore
        phase_upload_testflight
        ;;
    release)
        resolve_testflight_build_number
        phase_generate
        phase_test
        phase_archive
        phase_export_appstore
        phase_upload_testflight
        echo ""
        echo "==> Release complete: tested, archived, uploaded to TestFlight"
        ;;
    install)
        phase_install
        ;;
    *)
        echo "Usage: bash build.sh [test|archive|ota|ship|ci|testflight|release|install]"
        exit 1
        ;;
esac
