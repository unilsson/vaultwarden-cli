#!/usr/bin/env bash
set -euo pipefail

# vaultwarden-cli — interactive rbw / fzf frontend.
SIMPLE_MODE=false
case "${1:-}" in
    -s|--simple) SIMPLE_MODE=true ;;
    -h|--help)
        cat <<'HELP'
Usage: vw [-s|--simple] [-h|--help]

  -s, --simple  Start with the compact list (no preview)
  -h, --help    Show this help

Enter copy password    Ctrl+U username      Ctrl+T TOTP
Ctrl+O open URL        Ctrl+F select folder   Ctrl+A all folders
Ctrl+R sync            Ctrl+V switch view     Esc quit
HELP
        exit 0 ;;
    '') ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
esac
if (( $# > 1 )); then
    echo "Too many arguments. Try: vw --help" >&2
    exit 2
fi

for cmd in rbw fzf jq awk; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        printf 'Missing required command: %s\n' "$cmd" >&2
        exit 1
    fi
done

# Use ASCII unit separator internally; input metadata is sanitized by jq.
# TSV is used for compatibility with fzf's field selection.
load_entries() {
    rbw list --raw | jq -er '
        if type != "array" then error("rbw list --raw must return an array") else . end |
        def clean:
            (. // "-") | tostring | gsub("[\\t\\r\\n]"; " ") |
            if . == "" then "-" else . end;
        [
            .[] |
            [
                (.id | clean),
                (.name | clean),
                ((.user // .login.username) | clean),
                (.folder | clean),
                (
                    (.uris // .login.uris // [])
                    | map(if type == "string" then . else (.uri // "") end)
                    | .[0] | clean
                )
            ]
        ]
        | sort_by(.[1] | ascii_downcase)
        | .[]
        | @tsv
    '
}

choose_folder() {
    local entries="$1"
    local selection
    selection=$(
        {
            printf '%s\n' '[Alla mappar]'
            printf '%s\n' "$entries" | cut -f4 | LC_ALL=C sort -fu
        } | fzf --prompt='Mapp > ' --height=60% --border --layout=reverse \
                --header='Enter: välj | Esc: avbryt'
    ) || return 1
    printf '%s\n' "$selection"
}

filter_entries() {
    local entries="$1" folder="$2"
    if [[ "$folder" == '[Alla mappar]' ]]; then
        printf '%s\n' "$entries"
    else
        printf '%s\n' "$entries" | awk -F '\t' -v folder="$folder" '$4 == folder'
    fi
}

copy_secret() {
    local action="$1" id="$2"
    case "$action" in
        password) rbw get --clipboard "$id" && echo 'Lösenord kopierat' ;;
        username) rbw get --clipboard --field username "$id" && echo 'Användarnamn kopierat' ;;
        totp) rbw code --clipboard "$id" && echo 'TOTP-kod kopierad' ;;
    esac
}

open_url() {
    local url="$1"
    if [[ "$url" == "-" || -z "$url" ]]; then
        echo 'Ingen URL för denna post.'
        return 1
    fi
    if [[ ! "$url" =~ ^https?://[^[:space:]]+$ ]]; then
        echo 'Endast http(s)-adresser kan öppnas.'
        return 1
    fi
    if command -v firefox >/dev/null 2>&1; then
        nohup firefox "$url" >/dev/null 2>&1 </dev/null &
    elif command -v xdg-open >/dev/null 2>&1; then
        nohup xdg-open "$url" >/dev/null 2>&1 </dev/null &
    else
        echo 'Saknar Firefox eller xdg-open.' >&2
        return 1
    fi
    echo 'Öppnar webbadress.'
}

current_folder='[Alla mappar]'
while true; do
    if ! entries=$(load_entries); then
        echo 'Kunde inte läsa poster från rbw (kräver rbw 1.15+).' >&2
        exit 1
    fi
    if [[ -z "$entries" ]]; then
        echo 'Inga poster i valvet.'
        exit 0
    fi

    filtered=$(filter_entries "$entries" "$current_folder")
    count=$(printf '%s\n' "$filtered" | awk 'NF {n++} END {print n+0}')
    opts=(
        --delimiter=$'\t'
        --border --height=90% --layout=reverse --info=inline
        --expect=ctrl-u,ctrl-t,ctrl-o,ctrl-f,ctrl-a,ctrl-r,ctrl-v
    )

    if [[ "$SIMPLE_MODE" == true ]]; then
        opts+=(
            --with-nth=2,3 --nth=2,3,4,5
            --prompt="Vaultwarden ($count) > "
            --preview-window=hidden
            --header='Enter: lösenord | ^U: användare | ^T: TOTP | ^F: mapp | ^V: detaljer'
        )
    else
        opts+=(
            --with-nth=2,3,4,5 --nth=2,3,4,5
            --prompt="$current_folder ($count) > "
            --preview-window='right:45%:wrap'
            --header='Enter: lösenord | ^U: användare | ^T: TOTP | ^O: URL | ^F: mapp | ^A: alla | ^R: sync | ^V: enkel'
            --preview='
                printf "\n  VAULTWARDEN\n  ------------------------------\n\n"
                printf "  Namn:      %s\n" {2}
                printf "  Användare: %s\n" {3}
                printf "  Mapp:      %s\n" {4}
                printf "\n  URL: %s\n" {5}
            '
        )
    fi

    selection=$(printf '%s\n' "$filtered" | fzf "${opts[@]}") || break
    key=${selection%%$'\n'*}
    if [[ "$selection" == *$'\n'* ]]; then
        entry=${selection#*$'\n'}
    else
        entry=''
    fi

    case "$key" in
        ctrl-v)
            if [[ "$SIMPLE_MODE" == true ]]; then SIMPLE_MODE=false; else SIMPLE_MODE=true; fi
            continue ;;
        ctrl-f)
            new_folder=$(choose_folder "$entries") || continue
            current_folder="$new_folder"
            continue ;;
        ctrl-a)
            current_folder='[Alla mappar]'
            continue ;;
        ctrl-r)
            if rbw sync; then echo 'Vaultwarden synkroniserad'; else echo 'Synkronisering misslyckades' >&2; fi
            continue ;;
    esac

    [[ -z "$entry" ]] && continue
    id=${entry%%$'\t'*}
    url=${entry##*$'\t'}
    case "$key" in
        ctrl-u) copy_secret username "$id" ;;
        ctrl-t) copy_secret totp "$id" ;;
        ctrl-o) open_url "$url" ;;
        *) copy_secret password "$id" ;;
    esac
    break
done
