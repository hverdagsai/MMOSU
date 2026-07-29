# Mac Mini One-Shot Setup Utility.

This repository contains a setup script for installing the applications and command-line tools used on a new Mac mini.

## Run it on another Mac

Open **Terminal** and run:

```bash
curl -fsSL https://raw.githubusercontent.com/hverdagsai/MMOSU/main/install-mac.sh \
  -o /tmp/install-mac.sh

chmod +x /tmp/install-mac.sh
/tmp/install-mac.sh
```

Run the script as your normal macOS user. Do not run the entire script with `sudo`. It will ask for the administrator password when required.

The Mac does not need Git installed beforehand, and no GitHub account is required. The public script is downloaded directly with `curl`, which is included with macOS. Git is then installed by the setup script.

## Reload the Terminal environment

A script cannot change the environment of the Terminal process that launched it. After installation, either close and reopen Terminal or run:

```bash
exec zsh -l
```

This reloads the shell and makes the newly installed CLI commands available.

The installer adds the required paths to both `~/.zprofile` and `~/.zshrc`, including:

* Homebrew
* `~/.openclaw/bin`
* `~/.local/bin`
* `/usr/local/bin`

## What it installs

### Desktop applications

* Google Chrome
* Tailscale
* NoMachine
* ChatGPT desktop, including Codex
* 1Password

### Command-line tools

* Homebrew
* Git
* Tailscale CLI
* OpenClaw CLI
* Codex CLI
* 1Password CLI

## After installation

Logins and account setup are intentionally skipped. Complete them afterward with:

```bash
tailscale login
openclaw onboard --install-daemon
codex
```

For 1Password, open the desktop app, sign in, and enable CLI integration in its developer settings.

Tailscale may need to be opened once so macOS can approve its VPN configuration and system extension.

## Verify the CLI commands

After reloading Terminal, run:

```bash
brew --version
git --version
tailscale version
openclaw --version
codex --version
op --version
```

## Run the latest version again

The script is safe to run again. To download and run the newest version:

```bash
curl -fsSL https://raw.githubusercontent.com/hverdagsai/MMOSU/main/install-mac.sh \
  -o /tmp/install-mac.sh

chmod +x /tmp/install-mac.sh
/tmp/install-mac.sh
exec zsh -l
```
