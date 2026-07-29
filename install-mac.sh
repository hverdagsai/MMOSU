#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_VERSION="2.0.0"
readonly MIN_MACOS_MAJOR=12

log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32mOK\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR\033[0m %s\n' "$*" >&2; exit 1; }

on_error() {
  local exit_code=$?
  printf '\n\033[1;31mInstallation stopped on line %s (exit code %s).\033[0m\n' \
    "${BASH_LINENO[0]}" "$exit_code" >&2
  exit "$exit_code"
}
trap on_error ERR

[[ "$(uname -s)" == "Darwin" ]] || die "This script only supports macOS."
[[ "$EUID" -ne 0 ]] || die "Run this script as your normal macOS user, not with sudo."

macos_major="$(sw_vers -productVersion | cut -d. -f1)"
(( macos_major >= MIN_MACOS_MAJOR )) || die "macOS ${MIN_MACOS_MAJOR} or newer is required."

printf '\nMMOSU installer version %s\n' "$SCRIPT_VERSION"

append_line_once() {
  local file="$1"
  local line="$2"

  touch "$file"
  grep -Fqx "$line" "$file" 2>/dev/null || printf '\n%s\n' "$line" >> "$file"
}

configure_shell_path() {
  local brew_bin="$1"
  local brew_prefix="$2"
  local brew_line="eval \"\$(${brew_bin} shellenv)\""
  local tools_line='export PATH="$HOME/.openclaw/bin:$HOME/.local/bin:/usr/local/bin:$PATH"'
  local profile

  for profile in "$HOME/.zprofile" "$HOME/.zshrc"; do
    append_line_once "$profile" "$brew_line"
    append_line_once "$profile" "$tools_line"
  done

  eval "$("$brew_bin" shellenv)"
  export PATH="$HOME/.openclaw/bin:$HOME/.local/bin:/usr/local/bin:${brew_prefix}/bin:${brew_prefix}/sbin:$PATH"
  hash -r 2>/dev/null || true
}

install_homebrew() {
  local brew_bin
  local brew_prefix

  if [[ -x /opt/homebrew/bin/brew ]]; then
    brew_bin="/opt/homebrew/bin/brew"
  elif [[ -x /usr/local/bin/brew ]]; then
    brew_bin="/usr/local/bin/brew"
  else
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    if [[ -x /opt/homebrew/bin/brew ]]; then
      brew_bin="/opt/homebrew/bin/brew"
    elif [[ -x /usr/local/bin/brew ]]; then
      brew_bin="/usr/local/bin/brew"
    else
      die "Homebrew installed, but brew could not be found."
    fi
  fi

  brew_prefix="$("$brew_bin" --prefix)"
  configure_shell_path "$brew_bin" "$brew_prefix"
  ok " Homebrew is available at $brew_bin"
}

install_formula() {
  local formula="$1"

  if brew list --formula "$formula" >/dev/null 2>&1; then
    ok " $formula is already installed"
  else
    log "Installing $formula"
    brew install "$formula"
  fi
}

install_app_cask() {
  local cask="$1"
  local display_name="$2"
  local app_path="$3"

  if [[ -e "$app_path" ]]; then
    ok " $display_name is already installed"
    return
  fi

  if brew list --cask "$cask" >/dev/null 2>&1; then
    warn " $display_name is registered with Homebrew but missing from Applications. Reinstalling."
    brew reinstall --cask "$cask"
  else
    log "Installing $display_name"
    brew install --cask "$cask"
  fi
}

install_cli_cask() {
  local cask="$1"
  local display_name="$2"
  local command_name="$3"

  if command -v "$command_name" >/dev/null 2>&1; then
    ok " $display_name is already installed"
    return
  fi

  if brew list --cask "$cask" >/dev/null 2>&1; then
    warn " $display_name is registered with Homebrew but '$command_name' is unavailable. Reinstalling."
    brew reinstall --cask "$cask"
  else
    log "Installing $display_name"
    brew install --cask "$cask"
  fi

  hash -r 2>/dev/null || true
}

install_tailscale() {
  if [[ -d /Applications/Tailscale.app && -x /usr/local/bin/tailscale ]]; then
    ok " Tailscale desktop and CLI are already installed"
    return
  fi

  if brew list --cask tailscale-app >/dev/null 2>&1; then
    warn " Tailscale is partially installed. Reinstalling the Homebrew cask."
    brew reinstall --cask tailscale-app
  else
    log "Installing Tailscale desktop and CLI"
    brew install --cask tailscale-app
  fi

  [[ -d /Applications/Tailscale.app ]] || warn " Tailscale.app was not found in /Applications."
  [[ -x /usr/local/bin/tailscale ]] || warn " The Tailscale CLI was not found at /usr/local/bin/tailscale."

  hash -r 2>/dev/null || true
}

install_openclaw() {
  if [[ -x "$HOME/.openclaw/bin/openclaw" ]]; then
    ok " OpenClaw CLI is already installed"
    return
  fi

  log "Installing OpenClaw CLI into ~/.openclaw without onboarding"
  curl -fsSL --proto '=https' --tlsv1.2 https://openclaw.ai/install-cli.sh \
    | bash -s -- --prefix "$HOME/.openclaw" --no-onboard

  export PATH="$HOME/.openclaw/bin:$PATH"
  hash -r 2>/dev/null || true
}

verify_command() {
  local command_name="$1"

  if command -v "$command_name" >/dev/null 2>&1; then
    ok " $command_name: $(command -v "$command_name")"
  else
    warn " $command_name was not found in PATH"
  fi
}

log "Checking administrator access"
sudo -v

install_homebrew

log "Updating Homebrew metadata"
brew update

# Command-line tools
install_formula "git"
install_cli_cask "codex" "Codex CLI" "codex"
install_cli_cask "1password-cli" "1Password CLI" "op"

# Desktop applications
install_app_cask "google-chrome" "Google Chrome" "/Applications/Google Chrome.app"
install_app_cask "nomachine" "NoMachine" "/Applications/NoMachine.app"
install_app_cask "chatgpt" "ChatGPT desktop with Codex" "/Applications/ChatGPT.app"
install_app_cask "1password" "1Password desktop" "/Applications/1Password.app"

# Special installers
install_tailscale
install_openclaw

# Reapply PATH after all installs
if [[ -x /opt/homebrew/bin/brew ]]; then
  configure_shell_path "/opt/homebrew/bin/brew" "/opt/homebrew"
else
  configure_shell_path "/usr/local/bin/brew" "/usr/local"
fi

log "Verifying command-line tools"
verify_command "brew"
verify_command "git"
verify_command "tailscale"
verify_command "openclaw"
verify_command "codex"
verify_command "op"

printf '\n\033[1;32mInstallation complete.\033[0m\n'
printf '%s\n' \
  "Logins and onboarding were intentionally skipped." \
  "" \
  "Reload your Terminal environment:" \
  "  exec zsh -l" \
  "" \
  "Then verify:" \
  "  brew --version" \
  "  git --version" \
  "  tailscale version" \
  "  openclaw --version" \
  "  codex --version" \
  "  op --version" \
  "" \
  "Complete setup later with:" \
  "  tailscale login" \
  "  openclaw onboard --install-daemon" \
  "  codex"
