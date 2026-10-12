#!/usr/bin/env bash
set -euo pipefail

source_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${HOME}/.local/bin"
target="${target_dir}/vw"

for command in rbw fzf jq awk; do
    if ! command -v "$command" >/dev/null 2>&1; then
        printf 'Saknar beroende: %s\n' "$command" >&2
        exit 1
    fi
done

if ! rbw --version | grep -Eq '^rbw 1\.(1[5-9]|[2-9][0-9])\.'; then
    echo 'Kräver rbw >= 1.15.0. Kontrollera: rbw --version' >&2
    exit 1
fi

mkdir -p "$target_dir"
if [[ -e "$target" ]]; then
    cp -p -- "$target" "${target}.bak"
    echo "Säkerhetskopia: ${target}.bak"
fi
install -m 700 -- "${source_dir}/vw" "$target"
echo "Installerat: $target"
if [[ ":$PATH:" != *":$target_dir:"* ]]; then
    echo 'Lägg till ~/.local/bin i PATH, t.ex. i ~/.bashrc:'
    echo 'export PATH="$HOME/.local/bin:$PATH"'
fi
echo 'Testa med: vw --help'
