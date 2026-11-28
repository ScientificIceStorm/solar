#!/bin/sh

set -eu

# Flutter currently embeds iOS native-asset frameworks into Runner.app/Frameworks
# without re-signing them for the app's device identity. Re-sign the frameworks
# referenced by NativeAssetsManifest.json after Flutter copies them.

if [ "${PLATFORM_NAME:-}" != "iphoneos" ]; then
  exit 0
fi

if [ "${CODE_SIGNING_REQUIRED:-}" = "NO" ]; then
  exit 0
fi

if [ -z "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
  echo "No iPhone code signing identity available; skipping Flutter native asset re-signing."
  exit 0
fi

FRAMEWORKS_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
MANIFEST_PATH="${FRAMEWORKS_DIR}/App.framework/flutter_assets/NativeAssetsManifest.json"

if [ ! -f "${MANIFEST_PATH}" ]; then
  exit 0
fi

NATIVE_ASSET_FRAMEWORKS="$(
  /usr/bin/grep -oE '"[^"]+\.framework/[^"]+"' "${MANIFEST_PATH}" \
    | /usr/bin/sed -E 's/^"([^"]+)\.framework\/[^"]+"$/\1/' \
    | /usr/bin/sort -u || true
)"

if [ -z "${NATIVE_ASSET_FRAMEWORKS}" ]; then
  exit 0
fi

echo "Re-signing Flutter native asset frameworks"

printf '%s\n' "${NATIVE_ASSET_FRAMEWORKS}" | while IFS= read -r framework_name; do
  if [ -z "${framework_name}" ]; then
    continue
  fi

  framework_path="${FRAMEWORKS_DIR}/${framework_name}.framework"
  if [ ! -d "${framework_path}" ]; then
    echo "warning: Expected native asset framework at ${framework_path}, but it was not found."
    continue
  fi

  echo "Re-signing ${framework_name}.framework"
  /usr/bin/codesign \
    --force \
    --sign "${EXPANDED_CODE_SIGN_IDENTITY}" \
    --preserve-metadata=identifier,flags,requirements \
    --generate-entitlement-der \
    --timestamp=none \
    "${framework_path}"
done
