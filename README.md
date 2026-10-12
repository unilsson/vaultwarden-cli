# vaultwarden-cli

A small, keyboard-driven terminal interface for [Vaultwarden](https://github.com/dani-garcia/vaultwarden) and Bitwarden-compatible vaults, powered by [rbw](https://github.com/doy/rbw) and [fzf](https://github.com/junegunn/fzf).

Launch it with **`vw`** (details + preview) or **`vw --simple`** (just entry names and usernames). Press **Ctrl+V** to switch views.

## Requirements

- Linux with Bash 4+; tested workflow on Ubuntu
- **rbw 1.15.0+** (required for URLs in `rbw list --raw`)
- `fzf`, `jq`; `awk` and standard coreutils
- Firefox or `xdg-open` for opening URLs
- Working clipboard support for `rbw --clipboard` (X11 or Wayland)

On Ubuntu/Debian:

```bash
sudo apt update
sudo apt install fzf jq xdg-utils
```

Some distributions ship an older `rbw` (e.g. Ubuntu 26.04 ships 1.13.2). Install a newer one via Cargo if necessary:

```bash
sudo apt install cargo rustc build-essential pkg-config libssl-dev
cargo install --locked rbw --version 1.15.0
export PATH="$HOME/.cargo/bin:$PATH"
rbw --version
```

Put the `PATH` export in `~/.bashrc` if necessary. If `rbw` behaves oddly after an upgrade, `rbw stop-agent` can terminate the old agent; the next command starts a compatible one.

## Install

```bash
git clone https://github.com/unilsson/vaultwarden-cli.git
cd vaultwarden-cli
bash install.sh
```

The installer copies `vw` to `~/.local/bin/vw`, preserves any existing installation as `vw.bak`, and checks required commands. Ensure `~/.local/bin` is in your `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

For a persistent Bash setting, add that line to `~/.bashrc`.

## Connect to your own Vaultwarden server

Configure `rbw` **on each computer**; the repository contains no credentials or server settings.

```bash
rbw config set base_url https://vault.example.com
rbw config set email you@example.com
rbw login
rbw sync
rbw list
```

If your `rbw` is already configured, leave the existing settings as they are.

## Usage

```bash
vw             # detailed UI
vw -s          # simple UI
vw --simple
vw --help
```

| Key | Action |
| --- | --- |
| Enter | Copy password |
| Ctrl+U | Copy username |
| Ctrl+T | Copy TOTP |
| Ctrl+O | Open first website URL in browser |
| Ctrl+F | Select folder |
| Ctrl+A | Show all folders |
| Ctrl+R | Sync vault |
| Ctrl+V | Toggle detailed/simple mode |
| Esc | Quit |

Fuzzy search matches name, username, folder and URL in either UI. Folder filtering is session-only; a filter is retained when switching views. Entries without a folder show `-`.

## Safety

- Secrets are retrieved only when requested, using `rbw get --clipboard` or `rbw code --clipboard`. The UI never displays a password or TOTP.
- `rbw list --raw` is used for metadata. The resulting list is kept in memory and is not written to a file.
- URL opening is restricted to `http://` and `https://`; always check the website you open.
- Clipboard expiration is managed by `rbw` and your clipboard environment; check `rbw config show`.
- Do **not** commit vault exports, environment files, or `rbw` configuration to this project.

## Update and uninstall

```bash
cd vaultwarden-cli
git pull --ff-only
bash install.sh
```

To remove only the installed command:

```bash
bash uninstall.sh
```

## Development

```bash
bash -n vw install.sh uninstall.sh
shellcheck vw install.sh uninstall.sh
```

GitHub Actions runs the syntax and ShellCheck checks for each push and pull request.

## License

[MIT](LICENSE).
