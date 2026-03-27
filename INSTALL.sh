#!/bin/sh
# NTS Install Script
# Wires NTS into the system by setting up profile.d symlinks,
# skeleton directory files, and ensuring correct permissions.
# Must be run as root.

set -e

NTS_DIR="/opt/nts"

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: must be run as root." >&2
    exit 1
fi

if [ ! -d "$NTS_DIR" ]; then
    echo "Error: $NTS_DIR does not exist." >&2
    exit 1
fi

echo "Installing NTS from $NTS_DIR ..."

# Ensure all bin and lib scripts are executable
echo "  Setting permissions on $NTS_DIR/bin/ ..."
chmod +x "$NTS_DIR/bin/"*
if [ -d "$NTS_DIR/lib" ] && ls "$NTS_DIR/lib/"* >/dev/null 2>&1; then
    echo "  Setting permissions on $NTS_DIR/lib/ ..."
    chmod +x "$NTS_DIR/lib/"*
fi

# Symlink profile.d scripts into /etc/profile.d
echo "  Linking profile.d scripts ..."
for f in "$NTS_DIR/etc/profile.d/"*.sh; do
    name="$(basename "$f")"
    target="/etc/profile.d/$name"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$f" ]; then
        echo "    $name (already linked)"
    else
        ln -sf "$f" "$target"
        echo "    $name -> $target"
    fi
done

# Copy skeleton files into /etc/skel
echo "  Installing skeleton files to /etc/skel/ ..."
cp -a "$NTS_DIR/etc/skel/." /etc/skel/

echo "Done. Changes take effect on next login."
