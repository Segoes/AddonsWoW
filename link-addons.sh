#!/usr/bin/env bash
set -euo pipefail
GAME="$HOME/Games/battlenet/drive_c/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns"
cd "$(dirname "$0")"
for toc in */*.toc; do
    name="$(dirname "$toc")"
    target="$GAME/$name"
    if [ -L "$target" ]; then echo "already linked: $name"
    elif [ -e "$target" ]; then echo "WARNING: $name exists in AddOns and is not a symlink, skipping"
    else ln -s "$PWD/$name" "$target" && echo "linked: $name"
    fi
done
