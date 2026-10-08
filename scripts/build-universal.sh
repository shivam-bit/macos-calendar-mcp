#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
NAME=macos-calendar-mcp

swift build -c release --arch arm64 --arch x86_64

BIN=".build/apple/Products/Release/$NAME"
[ -f "$BIN" ] || { echo "binary not found at $BIN" >&2; exit 1; }

mkdir -p npm/bin
cp "$BIN" "npm/bin/$NAME"

ARCHS=$(lipo -archs "npm/bin/$NAME")
for arch in arm64 x86_64; do
  case " $ARCHS " in
    *" $arch "*) ;;
    *) echo "missing $arch in: $ARCHS" >&2; exit 1 ;;
  esac
done
echo "$ARCHS"
