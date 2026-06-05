#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_MARKDOWN="${MD2_TEST_MARKDOWN:-$ROOT_DIR/Examples/Sample.md}"
cd "$ROOT_DIR"

cleanup() {
    pkill -x MD2 2>/dev/null || true
}

frontmost_app() {
    osascript -e 'tell application "System Events" to get name of first process whose frontmost is true'
}

assert_frontmost_md2() {
    local label="$1"
    local front
    front="$(frontmost_app)"

    if [[ "$front" != "MD2" ]]; then
        echo "FAIL: $label did not activate MD2; frontmost app is '$front'." >&2
        return 1
    fi

    echo "PASS: $label activated MD2."
}

assert_md2_visible() {
    local label="$1"
    local visible
    visible="$(osascript -e 'tell application "System Events" to tell process "MD2" to get visible' 2>/dev/null || echo false)"

    if [[ "$visible" != "true" ]]; then
        echo "FAIL: $label did not create a visible MD2 process." >&2
        return 1
    fi

    echo "PASS: $label created a visible MD2 process."
}

assert_health_file() {
    local label="$1"
    local health_file="$2"

    if ! rg -q 'visible=[1-9]' "$health_file"; then
        echo "FAIL: $label did not report a visible window." >&2
        cat "$health_file" >&2 || true
        return 1
    fi

    echo "PASS: $label reported a visible window."
}

cleanup

echo "== Unit tests =="
swift test

echo "== Release build =="
swift build -c release --product MD2

echo "== App bundle =="
Scripts/package_app.sh
plutil -lint dist/MD2.app/Contents/Info.plist
test -x dist/MD2.app/Contents/MacOS/MD2

echo "== swift run launch =="
health_file="/tmp/md2-functional-health.txt"
rm -f "$health_file"
MD2_HEALTH_FILE="$health_file" swift run MD2 "$TARGET_MARKDOWN" >/tmp/md2-functional-swift-run.log 2>&1 &
runner_pid=$!
sleep 10
assert_md2_visible "swift run"
assert_health_file "swift run" "$health_file"
if kill -0 "$runner_pid" 2>/dev/null; then
    echo "FAIL: swift run launcher should exit after handing off to the app bundle." >&2
    exit 1
fi
cleanup
sleep 1

echo "== dist app launch =="
rm -f "$health_file"
MD2_HEALTH_FILE="$health_file" "$ROOT_DIR/dist/MD2.app/Contents/MacOS/MD2" "$TARGET_MARKDOWN" >/tmp/md2-functional-dist.log 2>&1 &
dist_pid=$!
sleep 5
assert_md2_visible "dist/MD2.app"
assert_health_file "dist/MD2.app" "$health_file"
kill "$dist_pid" 2>/dev/null || true
cleanup

echo "All functional checks passed."
