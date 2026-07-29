#!/usr/bin/env bash
set -Eeuo pipefail

readonly MIN_MACOS_MAJOR=12
readonly TAILSCALE_PKG_URL="https://pkgs.tailscale.com/stable/Tailscale-latest-macos.pkg"

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m✓\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This script only supports macOS."
[[ "$EUID" -ne 0 ]] || die "Run this script as your normal macOS user, not with sudo."

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
(( macos_major >= MIN_MACOS_MAJOR )) || die "macOS ${MIN_MACOS_MAJOR} or newer is required."

TMP_DIR="$(mktemp -d)"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

ensure_zprofile_line() {
  local line="$1"
  local profile="$HOME/.zprofile"
  touch "$profile"
  grep -Fqx "$line" "$profile" || printf '\n%s\n' "$line" >> "$profile"
}

install_homebrew() {
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  else
    ok "Homebrew is already installed"
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    ensure_zprofile_line 'eval "$(/opt/homebrew/bin/brew shellenv)"'
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    ensure_zprofile_line 'eval "$(/usr/local/bin/brew shellenv)"'
  else
    die "Homebrew installed, but brew could not be found."
  fi
}

install_app_cask() {
  local cask="$1"
  local app_path="$2"

  if [[ -e "$app_path" ]] || brew list --cask "$cask" >/dev/null 2>&1; then
    ok "$cask is already installed"
  else
    log "Installing $cask"
    brew install --cask "$cask"
  fi
}

install_cli_cask() {
  local cask="$1"
  local command_name="$2"

  if command -v "$command_name" >/dev/null 2>&1 || brew list --cask "$cask" >/dev/null 2>&1; then
    ok "$cask is already installed"
  else
    log "Installing $cask"
    brew install --cask "$cask"
  fi
}

install_tailscale() {
  if [[ -d /Applications/Tailscale.app && -x /usr/local/bin/tailscale ]]; then
    ok "Tailscale desktop and CLI are already installed"
    return
  fi

  log "Installing Tailscale desktop and CLI"
  local pkg="$TMP_DIR/Tailscale.pkg"
  local expected actual

  curl --fail --location --silent --show-error \
    --proto '=https' --tlsv1.2 \
    "$TAILSCALE_PKG_URL" -o "$pkg"

  expected="$(curl --fail --location --silent --show-error \
    --proto '=https' --tlsv1.2 \
    "${TAILSCALE_PKG_URL}.sha256" | awk '{print $1}')"
  actual="$(shasum -a 256 "$pkg" | awk '{print $1}')"

  [[ -n "$expected" && "$actual" == "$expected" ]] || die "Tailscale checksum verification failed."
  sudo installer -pkg "$pkg" -target /
}

install_openclaw() {
  if command -v openclaw >/dev/null 2>&1; then
    ok "OpenClaw CLI is already installed"
    return
  fi

  log "Installing OpenClaw CLI without onboarding"
  curl --fail --location --silent --show-error \
    --proto '=https' --tlsv1.2 \
    https://openclaw.ai/install.sh | bash -s -- --no-onboard

  export PATH="$HOME/.local/bin:$PATH"
  ensure_zprofile_line 'export PATH="$HOME/.local/bin:$PATH"'
}

verify_command() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    ok "$command_name: $(command -v "$command_name")"
  else
    warn "$command_name is not currently in PATH. Open a new Terminal window and check again."
  fi
}

log "Checking administrator access"
sudo -v

install_homebrew
log "Updating Homebrew metadata"
brew update

# Desktop applications
install_app_cask "google-chrome" "/Applications/Google Chrome.app"
install_app_cask "nomachine" "/Applications/NoMachine.app"
install_app_cask "chatgpt" "/Applications/ChatGPT.app"
install_app_cask "1password" "/Applications/1Password.app"

# Command-line tools
install_cli_cask "codex" "codex"
install_cli_cask "1password-cli" "op"

# Installers handled separately
install_tailscale
install_openclaw

log "Verifying command-line tools"
verify_command "tailscale"
verify_command "openclaw"
verify_command "codex"
verify_command "op"

printf '\n\033[1;32mInstallation complete.\033[0m\n'
printf '%s\n' \
  "Logins and setup were intentionally skipped." \
  "" \
  "Later, run:" \
  "  tailscale login" \
  "  openclaw onboard --install-daemon" \
  "  codex" \
  "" \
  "For 1Password, open the desktop app, sign in, then enable CLI integration in its developer settings."
