#!/bin/sh
# Builds an installable zip for this addon.
#
# ESO requires the archive to contain a single top-level folder whose name
# matches the manifest, or the addon will not load when extracted into AddOns.
# That is the whole reason this script exists rather than zipping by hand.
#
# Usage: scripts/package.sh [output-dir]      (default: dist)
set -e

cd "$(dirname "$0")/.."
ADDON=$(basename "$PWD")
MANIFEST="$ADDON.txt"
OUT_DIR=${1:-dist}

if [ ! -f "$MANIFEST" ]; then
    echo "error: no $MANIFEST here; the folder name must match the manifest" >&2
    exit 1
fi

VERSION=$(sed -n 's/^## Version:[[:space:]]*//p' "$MANIFEST" | head -1 | tr -d '\r')
if [ -z "$VERSION" ]; then
    echo "error: no '## Version:' in $MANIFEST" >&2
    exit 1
fi

ZIP_NAME="$ADDON-$VERSION.zip"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

rsync -a --exclude-from=.build-ignore ./ "$STAGE/$ADDON/"

mkdir -p "$OUT_DIR"
rm -f "$OUT_DIR/$ZIP_NAME"
OUT_ABS=$(cd "$OUT_DIR" && pwd)
(cd "$STAGE" && zip -rq "$OUT_ABS/$ZIP_NAME" "$ADDON")

echo "built $OUT_DIR/$ZIP_NAME"
echo "contents:"
unzip -Z1 "$OUT_ABS/$ZIP_NAME" | sed 's/^/  /'
