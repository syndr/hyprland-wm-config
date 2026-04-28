[![jp](https://img.shields.io/badge/lang-jp-blue.svg)](./i18n/README/README.jp.md)
[![ro](https://img.shields.io/badge/lang-ro-green.svg)](./i18n/README/README.ro.md)
[![ru](https://img.shields.io/badge/lang-ru-red.svg)](./i18n/README/README.ru.md)
[![ua](https://img.shields.io/badge/lang-ua-white.svg)](./i18n/README/README.ua.md)
[![de](https://img.shields.io/badge/lang-de-magenta.svg)](./i18n/README/README.de.md)
[![fr](https://img.shields.io/badge/lang-fr-cyan.svg)](./i18n/README/README.fr.md)

> Forked from [LinuxBeginnings/Hyprland-Dots](https://github.com/LinuxBeginnings/Hyprland-Dots) (originally JaKooLit/Hyprland-Dots).

<h3 align="center">
<img align="center" width="80%" src=https://github.com/user-attachments/assets/bc18bd4d-944b-4d5f-a119-7578fa38f9b4 />
</h3>

<p align="center">
  <img src="https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/assets/latte.png" width="400" />
</p>

<div align="center">
<br>
  <a href="#-installationupdate-instructions"><kbd> <br> Installation <br> </kbd></a>&ensp;&ensp;
  <a href="https://github.com/LinuxBeginnings/Hyprland-Dots/wiki"><kbd> <br> Upstream Wiki <br> </kbd></a>&ensp;&ensp;
</div><br>

<div align="center">

<br/>
</div>

<h3 align="center">
  <img src="https://github.com/LinuxBeginnings/Telegram-Animated-Emojis/blob/main/Activity/Sparkles.webp" alt="Sparkles" width="38" height="38" />
  KooL's Hyprland Dotfiles Showcase
  <img src="https://github.com/LinuxBeginnings/Telegram-Animated-Emojis/blob/main/Activity/Sparkles.webp" alt="Sparkles" width="38" height="38" />
</h3>

<div align="center">
  <https://github.com/user-attachments/assets/49bc12b2-abaf-45de-a21c-67aacd9bb872>
</div>

---

[![Typing SVG](https://readme-typing-svg.herokuapp.com?font=Fira+Code&weight=700&size=22&pause=1000&color=F7077E&vCenter=true&width=435&height=30&lines=INSTALLATION)](https://git.io/typing-svg)

### 🏁 Auto Distro-Hyprland install scripts cloning and starting

> [!IMPORTANT]
> The distro install scripts in this section clone **upstream**
> (`LinuxBeginnings/Hyprland-Dots`), **not this fork**. They install
> Hyprland itself plus upstream's dotfiles. To install **this fork's**
> dotfiles, skip this section and use the `git clone` + `./copy.sh`
> flow under [Installation/Update instructions](#-installationupdate-instructions).

> [!CAUTION]
> If you are using FISH SHELL, DO NOT use this function. Clone the Distro-Hyprland and ran install.sh instead

- NOTE: you need package `curl` for this to work

```bash
sh <(curl -L https://raw.githubusercontent.com/LinuxBeginnings/Hyprland-Dots/main/Distro-Hyprland.sh)
```

- You can use the above command to automatically clone the `Distro-Hyprland` install scripts
- It will clone the install script and start the `install.sh`

### 👁️‍🗨️ My Hyprland install Scripts

Automated Hyprland Scripts for Distro of choice which will pull this dotfiles if opted to install these configurations

- [Arch-Linux](https://github.com/LinuxBeginnings/Arch-Hyprland)

- [OpenSUSE(Tumbleweed)](https://github.com/LinuxBeginnings/OpenSuse-Hyprland)

- [Fedora-Linux (43/Rawhide)](https://github.com/LinuxBeginnings/Fedora-Hyprland)

- [Debian-Linux (Trixie & SID)](https://github.com/LinuxBeginnings/Debian-Hyprland)

- [NixOS (25.05+)](https://github.com/LinuxBeginnings/NixOS-Hyprland)

- [Ubuntu 24.04 LTS](https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/24.04)
- [Ubuntu 24.10 (deprecated)](https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/24.10)
- [Ubuntu 25.04 (deprecated)](https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/25.04)
- [Ubuntu 25.10](https://github.com/LinuxBeginnings/Ubuntu-Hyprland/tree/25.10)

---

### 🪧 Attention

- This repo does NOT contain or will NOT install any packages. These are only pre-configured-hyprland configs or dotfiles
- refer to install scripts what packages needed to install... but at least, Hyprland packages are required
- This repo will be pulled by the Distro-Hyprland install scripts above if you opt to download pre-configured dots

### 👀 Screenshots

- All screenshots are collected here [Screenshots](https://github.com/LinuxBeginnings/screenshots/tree/main/Hyprland-ScreenShots)

### 📦 What's new?

- Fork-side changes are tracked in [`CHANGELOG.md`](./CHANGELOG.md). Upstream's
  release notes live at the [upstream wiki](https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Changelogs).

### 💥 Installation/Update instructions

  > [!Note]
  > The auto copy script `copy.sh` will create backups of intended directories to be copied.
  > However, it's still a good idea to manually backup just incase script fails to backup your configuration.
  > If you already have a hyprland configuration, uninstall it first, or create a new user, and install it with that user

> Clone the fork (recommended)

```bash
git clone --depth=1 https://github.com/syndr/hyprland-wm-config.git && cd hyprland-wm-config
```

> Or clone a specific branch (e.g. `merge/upstream-2026-04-26`)

```bash
git clone --depth=1 https://github.com/syndr/hyprland-wm-config.git -b main && cd hyprland-wm-config
```

- automatic copy/install of pre-configured dots (recommended for updating)

```bash
chmod +x copy.sh
./copy.sh
```

#### ⚠️ BACKUPS CREATED by SCRIPT

> [!CAUTION]
> `copy.sh` creates a backup!
> Kindly investigate manually contents on your `$HOME/.config`
> Delete manually any backups which you dont want.

#### 🛎️ a small note on wallpapers

- by default, only few wallpapers will be copied (1 each dark and light plus 3 more). You will be offered to download more wallpapers. You can preview/check the additional wallpapers from this [`LINK`](https://github.com/LinuxBeginnings/Wallpaper-Bank/tree/main/wallpapers)

#### ⚠️ after installing these dots

- NVIDIA Owners: see the upstream [`FAQ_NVIDIA`](https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/FAQ_NVIDIA)
  for guidance, then edit your `~/.config/hypr/UserConfigs/ENVariables.conf`.
- If you have already set your own keybinds, monitors, etc.... Just copy over from backup created before log-out or reboot. (recommended)

#### 🙋 QUESTIONS ?

- FAQ! Yes you can use these dotfiles to other distro! Just ensure to install proper packages first!
- QUICK HINT! Click the HINT! Waybar module (only available on some layouts). Also can be launched by keybind `SUPER + H`
- More questions? Open an issue on [this fork's repo](https://github.com/syndr/hyprland-wm-config/issues),
  or browse the upstream [WIKI](https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/) for general
  Hyprland-Dots reference material.

#### ⌨ Keybinds

- Keybinds reference (upstream): [`HERE`](https://github.com/LinuxBeginnings/Hyprland-Dots/wiki/Keybinds)

### ✍️ Contributing

- If you have improvements on the dotfiles or configuration, feel free to submit a PR.
- See [`CONTRIBUTING.md`](./CONTRIBUTING.md) for a guide on how to contribute to this fork.

### 💖 Support

- a Star on the [fork's repo](https://github.com/syndr/hyprland-wm-config) would be nice 🌟
- Upstream KooL's project also welcomes stars: <https://github.com/LinuxBeginnings/Hyprland-Dots>

## 🫰 Thank you for the stars 🩷

### Document translations

- Spanish: [Código de Conducta](./i18n/CODE_OF_CONDUCT/CODE_OF_CONDUCT.es.md) · [Guía de mensajes de commit](./i18n/COMMIT_MESSAGE_GUIDELINES/COMMIT_MESSAGE_GUIDELINES.es.md) · [Guía de contribución](./i18n/CONTRIBUTING/CONTRIBUTING.es.md)

- French: [Code de Conduite](./i18n/CODE_OF_CONDUCT/CODE_OF_CONDUCT.fr.md) · [Directives pour les messages de commit](./i18n/COMMIT_MESSAGE_GUIDELINES/COMMIT_MESSAGE_GUIDELINES.fr.md) · [Guide de contribution](./i18n/CONTRIBUTING/CONTRIBUTING.fr.md)
