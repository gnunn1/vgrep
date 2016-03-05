#!/usr/bin/env sh

if [ -z  "$1" ]; then
    export PREFIX=/usr
    # Make sure only root can run our script
    if [ "$(id -u)" != "0" ]; then
        echo "This script must be run as root" 1>&2
        exit 1
    fi
else
    export PREFIX=$1
fi

echo "Installing to prefix ${PREFIX}"

# Compile po files
echo "Copying and installing localization files"
for f in po/*.po; do
    echo "Processing $f"
    LOCALE=$(basename "$f" .po)
    mkdir -p ${PREFIX}/share/locale/${LOCALE}/LC_MESSAGES
    msgfmt $f -o ${PREFIX}/share/locale/${LOCALE}/LC_MESSAGES/vgrep.mo
done

# Generate desktop file
msgfmt --desktop --template=pkg/desktop/com.gexperts.VisualGrep.desktop.in -d po -o pkg/desktop/com.gexperts.VisualGrep.desktop

# Copy executable and desktop file
mkdir -p ${PREFIX}/bin
cp vgrep ${PREFIX}/bin/vgrep
mkdir -p ${PREFIX}/share/applications
cp pkg/desktop/com.gexperts.VisualGrep.desktop ${PREFIX}/share/applications
