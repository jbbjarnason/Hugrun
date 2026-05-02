#!/usr/bin/env bash
# Hugrún Phase 1 Marionette / integration-test smoke runner.
#
# Two modes:
#
#   tools/run-marionette.sh ios | android
#       Run the SCRIPTED integration_test/marionette_smoke_test.dart against
#       a real iOS Simulator (iPad Air) or Android Emulator (Pixel Tablet)
#       via `flutter drive`. Fast, deterministic, runs in CI.
#
#   tools/run-marionette.sh mcp ios | mcp android
#       Launch the app in debug mode with MarionetteBinding initialized
#       (lib/main.dart auto-detects kDebugMode). Prints the VM-service URI
#       for the operator to feed into a Marionette MCP server. Then it
#       hands control to the operator/AI agent — does NOT exit on its own
#       and does NOT make pass/fail assertions itself. The AI agent drives
#       the scenarios documented in marionette/smoke.marionette.dart.
#
# Default (no args) is `ios`.
set -euo pipefail

MODE="scripted"
PLATFORM="${1:-ios}"
if [[ "$PLATFORM" == "mcp" ]]; then
  MODE="mcp"
  PLATFORM="${2:-ios}"
fi

resolve_ios_device() {
  local id
  id="$(xcrun simctl list devices available 2>/dev/null \
        | grep -E 'iPad Air' \
        | head -n1 \
        | grep -oE '\([0-9A-F-]+\)' \
        | tr -d '()' || true)"
  if [[ -z "$id" ]]; then
    echo "ERROR: No iPad Air simulator available." >&2
    echo "Install one in Xcode → Settings → Platforms (or" >&2
    echo "  xcrun simctl create 'iPad Air' 'iPad Air (5th generation)' iOS17.0" >&2
    echo "etc.)." >&2
    exit 1
  fi
  xcrun simctl boot "$id" 2>/dev/null || true
  echo "$id"
}

resolve_android_device() {
  local avd
  avd="$(emulator -list-avds 2>/dev/null | grep -E 'Pixel.*Tablet' | head -n1 || true)"
  if [[ -z "$avd" ]]; then
    echo "ERROR: No Pixel Tablet AVD found." >&2
    echo "Create one in Android Studio → Tools → Device Manager." >&2
    exit 1
  fi
  # Boot the emulator detached. The caller must wait for it; we use adb
  # wait-for-device below.
  if ! adb devices | awk 'NR>1 {print $1}' | grep -q .; then
    echo "Booting emulator $avd ..." >&2
    nohup emulator -avd "$avd" -no-window -no-audio -no-snapshot \
      >/tmp/emu-$$.log 2>&1 &
    adb wait-for-device
    # Wait for boot complete.
    until [[ "$(adb shell getprop sys.boot_completed 2>/dev/null \
                  | tr -d '[:space:]')" == "1" ]]; do
      sleep 2
    done
  fi
  adb devices | awk 'NR==2 {print $1}'
}

case "$PLATFORM" in
  ios)
    DEVICE_ID="$(resolve_ios_device)"
    ;;
  android)
    DEVICE_ID="$(resolve_android_device)"
    ;;
  *)
    echo "Usage: $0 [mcp] ios|android" >&2
    exit 2
    ;;
esac

case "$MODE" in
  scripted)
    echo "Running scripted Marionette smoke on $PLATFORM ($DEVICE_ID)..."
    flutter drive \
      --driver=test_driver/integration_driver.dart \
      --target=integration_test/marionette_smoke_test.dart \
      -d "$DEVICE_ID"
    ;;
  mcp)
    echo "Launching app with MarionetteBinding on $PLATFORM ($DEVICE_ID)..."
    echo
    echo "After the app launches, the Flutter VM-service URI is printed."
    echo "Pass that URI to your Marionette MCP server:"
    echo "    dart run marionette_mcp --uri=<vm-service-uri>"
    echo "Then connect your AI agent (Claude Code / Cursor / Copilot)."
    echo "Drive the scenarios in marionette/smoke.marionette.dart."
    echo
    flutter run -d "$DEVICE_ID" --debug
    ;;
esac
