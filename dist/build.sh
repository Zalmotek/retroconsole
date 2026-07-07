#!/bin/bash
# Re-pack the Arduino App Lab projects into importable .zip files in dist/.
# Run this from the repo root after editing any sketch/python/yaml file.
set -e
cd "$(dirname "$0")/.."

for proj in game-console modulino-i2c-changer bus-scanner recovery-changer button-checker; do
    rm -f "dist/$proj.zip"
    # App Lab cache (.cache/) and OS cruft don't belong in the import bundle.
    zip -r "dist/$proj.zip" "$proj" \
        -x "$proj/.cache/*" \
        -x "*.DS_Store" \
        -x "$proj/.gitignore" \
        > /dev/null
    printf "%-30s  %s\n" "$proj.zip" "$(du -h "dist/$proj.zip" | cut -f1)"
done
