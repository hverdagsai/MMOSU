# Mac Mini One-Shot Setup Utility.

This repository contains a setup script that installs the required CLI tools and desktop applications on a new Mac.

## Run on another Mac

Open Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/hverdagsai/MMOSU/main/install-mac.sh \
  -o /tmp/install-mac.sh

chmod +x /tmp/install-mac.sh

/tmp/install-mac.sh
```

Run the script as your normal Mac user. Do not run the entire script with `sudo`.

macOS may ask for your administrator password during installations that require elevated permissions.

A GitHub account and Git are not required beforehand. The script is downloaded directly from the public repository using `curl`, which is included with macOS. Git is installed by the setup script.

## Installed applications and tools

The script currently installs:

* Homebrew
* Git
* Google Chrome
* Tailscale desktop and CLI
* NoMachine
* OpenClaw CLI
* ChatGPT desktop
* Codex CLI
* 1Password desktop and CLI

## Login and configuration

The script installs the applications and tools, but does not sign in to any accounts.

Logins and configuration can be completed afterward.

```bash
tailscale login
openclaw onboard --install-daemon
codex
```

For 1Password CLI integration, sign in to the 1Password desktop app and enable CLI integration in the app settings.

Some desktop applications may need to be opened manually the first time so macOS can approve system permissions or extensions.

## Verify Git

After installation, you can confirm that Git is installed by running:

```bash
git --version
```

## Run the script again

The script can be run again later when new applications or tools are added:

```bash
curl -fsSL https://raw.githubusercontent.com/hverdagsai/MMOSU/main/install-mac.sh \
  -o /tmp/install-mac.sh

chmod +x /tmp/install-mac.sh

/tmp/install-mac.sh
```
