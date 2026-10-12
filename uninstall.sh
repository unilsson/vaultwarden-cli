#!/usr/bin/env bash
set -euo pipefail

target="${HOME}/.local/bin/vw"
if [[ -f "$target" ]]; then
    rm -- "$target"
    echo "Avinstallerat: $target"
else
    echo "Ingen vw-installation hittades på $target"
fi
echo 'Vaultwarden-data, rbw-konfiguration och eventuella vw.bak-filer är orörda.'
