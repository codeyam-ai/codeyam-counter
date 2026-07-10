#!/usr/bin/env bash
#
# Archive the App target and upload it to App Store Connect / TestFlight.
#
# Auth uses an App Store Connect API key. Generate one at:
#   App Store Connect ▸ Users and Access ▸ Integrations ▸ App Store Connect API
# The key MUST belong to the account that owns com.codeyam.counter (team
# 88QLZH998K) and have "Admin" or "App Manager" access, so that
# -allowProvisioningUpdates can create the distribution certificate and
# provisioning profile automatically.
#
# Set these three env vars before running (do NOT commit the .p8):
#   export ASC_KEY_ID=XXXXXXXXXX                       # the Key ID
#   export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-...   # the Issuer ID
#   export ASC_KEY_PATH=~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8
#
# Then:
#   ./.codeyam/store/appstore/upload-testflight.sh
#
set -euo pipefail

PROJECT="App.xcodeproj"
SCHEME="App"
CONFIG="Release"
ARCHIVE_PATH="build/App.xcarchive"
EXPORT_PATH="build/export"
EXPORT_OPTS=".codeyam/store/appstore/ExportOptions.plist"

: "${ASC_KEY_ID:?set ASC_KEY_ID (App Store Connect API Key ID)}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID (App Store Connect Issuer ID)}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH (path to your AuthKey_XXXX.p8)}"

cd "$(git rev-parse --show-toplevel)"

# Expand a leading ~ in the key path.
ASC_KEY_PATH="${ASC_KEY_PATH/#\~/$HOME}"
[ -f "$ASC_KEY_PATH" ] || { echo "❌ API key not found at: $ASC_KEY_PATH" >&2; exit 1; }

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

# Archive UNSIGNED. During `archive`, automatic signing would otherwise pick a
# *Development* profile (which requires a registered device — "no devices"
# error). App Store distribution signing is applied at the -exportArchive step
# below instead, and distribution profiles need no registered devices.
echo "▸ Archiving ($CONFIG, unsigned)…"
xcodebuild archive \
	-project "$PROJECT" \
	-scheme "$SCHEME" \
	-configuration "$CONFIG" \
	-destination 'generic/platform=iOS' \
	-archivePath "$ARCHIVE_PATH" \
	CODE_SIGN_IDENTITY="" \
	CODE_SIGNING_REQUIRED=NO \
	CODE_SIGNING_ALLOWED=NO

# Export re-signs with an Xcode-managed App Store distribution cert + profile,
# created on the fly via the API key (-allowProvisioningUpdates), then uploads.
echo "▸ Exporting & uploading to App Store Connect…"
xcodebuild -exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportPath "$EXPORT_PATH" \
	-exportOptionsPlist "$EXPORT_OPTS" \
	-allowProvisioningUpdates \
	-authenticationKeyID "$ASC_KEY_ID" \
	-authenticationKeyIssuerID "$ASC_ISSUER_ID" \
	-authenticationKeyPath "$ASC_KEY_PATH"

echo "✅ Upload submitted. The build appears in TestFlight once Apple finishes"
echo "   processing (typically 5–15 min). Watch it in App Store Connect ▸ TestFlight."
