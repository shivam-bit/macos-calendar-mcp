#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
scripts/build-universal.sh
cp README.md LICENSE npm/
