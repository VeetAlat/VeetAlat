#!/bin/sh
# Builds the ambience RPM into ./RPMS/noarch/ using plain rpmbuild.
# No Sailfish SDK needed: the package is noarch (just files, no code).
set -e
cd "$(dirname "$0")"
SPEC=$(ls *.spec | head -n 1)
python3 -m json.tool ambience/*.ambience >/dev/null || { echo "Your .ambience file is not valid JSON"; exit 1; }
ls ambience/images/*.jpg >/dev/null 2>&1 || { echo "Put your wallpaper (.jpg) in ambience/images/"; exit 1; }
rpmbuild -bb "$SPEC" \
    --define "_sourcedir $PWD" \
    --define "_rpmdir $PWD/RPMS" \
    --define "_builddir $PWD/.build" \
    --define "_buildrootdir $PWD/.buildroot"
echo "Done! Your package is in: $(ls "$PWD"/RPMS/noarch/*.rpm)"
