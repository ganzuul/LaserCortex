#!/usr/bin/env bash
# headless_check.sh — run a WebGPU page headless via Chromium's SwiftShader
# (software Vulkan) and print the [LaserCortex] console lines.
#
# Why: this sandbox has no /dev/dri, but Chromium bundles a SwiftShader Vulkan
# ICD (VK_ICD_FILENAMES=/usr/lib/chromium/vk_swiftshader_icd.json), so WebGPU
# runs headless on the software adapter. Console lines go to stderr with
# --enable-logging=stderr — WGSL compile errors (which we can't otherwise
# validate offline) and the page's [LaserCortex] status lines appear there.
#
# Usage:
#   webgpu/headless_check.sh [page [seconds]]
#   webgpu/headless_check.sh webgpu/mhd_globe_webgpu.html 20
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PAGE="${1:-$ROOT/webgpu/mhd_globe_webgpu.html}"
SECS="${2:-18}"
WORK="$ROOT/webgpu"
PROF="$(mktemp -d "$WORK/.prof.XXXXXX")"
LOG="$WORK/.headless.log"
: > "$LOG"

VK_ICD_FILENAMES=/usr/lib/chromium/vk_swiftshader_icd.json \
chromium --headless=new --no-sandbox --disable-gpu-sandbox --disable-dev-shm-usage \
  --user-data-dir="$PROF" \
  --enable-unsafe-webgpu --enable-features=Vulkan \
  --ignore-gpu-blocklist --use-vulkan=swiftshader \
  --enable-logging=stderr --v=0 --disable-extensions \
  "file://$PAGE" > /dev/null 2>>"$LOG" &
CHROME=$!
sleep "$SECS"
kill "$CHROME" 2>/dev/null
sleep 1
kill -9 "$CHROME" 2>/dev/null
rm -rf "$PROF"

echo "== [LaserCortex] console lines =="
grep -a "LaserCortex" "$LOG" | head -20
echo "== WGSL/validation hints =="
grep -aiE "error while|wgsl|invalid|validation|uncaught" "$LOG" \
  | grep -avE "qt.qpa|portal|systemd1|Crash Reports" | head -14
rm -f "$LOG"
