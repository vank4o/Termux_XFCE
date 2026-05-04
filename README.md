# Termux XFCE

<div align="center">

**[English](README.md)** &nbsp;|&nbsp; [한국어](README.ko.md)

[![Android](https://img.shields.io/badge/Android-Termux-3DDC84?logo=android)](https://termux.dev)
[![Arch](https://img.shields.io/badge/Arch-aarch64-0070C0)](https://github.com/yanghoeg/Termux_XFCE)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)

</div>

---

Bash script that automatically installs **XFCE desktop environment** on Termux for Android.  
Derived from [phoenixbyrd/Termux_XFCE](https://github.com/phoenixbyrd/Termux_XFCE).

**Tested devices**: Galaxy Fold6 (Adreno 750, SD 8 Gen3), Galaxy Tab S9 Ultra (Adreno 740, SD 8 Gen2)

## Features

- **Termux native first** — XFCE, Firefox, fcitx5-hangul, GPU acceleration all installed as Termux native
- **Optional proot** — Ubuntu / Arch Linux / none
- **Hexagonal Architecture** — distro abstraction keeps Ubuntu & Arch code unified
- **Idempotent** — already installed items are skipped automatically
- **GPU acceleration** — Zink + Turnip auto-activated for Adreno 6xx/7xx/8xx
- **zsh + Powerlevel10k** — set as default shell with autosuggestions & syntax-highlighting

## Installation

```bash
# one-liner (auto clones repo then runs)
curl -sL https://raw.githubusercontent.com/yanghoeg/Termux_XFCE/main/install.sh | bash
```

```bash
# with options
bash install.sh --distro ubuntu --user <username> --gpu
bash install.sh --distro archlinux --user <username>
bash install.sh --no-proot          # Termux native only
bash install.sh --distro ubuntu --user <username> --gpu --gpu-dev
bash install.sh --distro archlinux --user <username> --proot-only  # add 2nd distro
```

```bash
# via environment variables
DISTRO=ubuntu USERNAME=<username> INSTALL_GPU=true bash install.sh
```

| Option | Env var | Description |
|--------|---------|-------------|
| `--distro ubuntu\|archlinux` | `DISTRO=` | proot distro |
| `--user <name>` | `USERNAME=` | proot username |
| `--no-proot` | `SKIP_PROOT=true` | Termux native only |
| `--proot-only` | `PROOT_ONLY=true` | proot only (skip Termux native setup, for adding a 2nd distro) |
| `--gpu` | `INSTALL_GPU=true` | Install GPU acceleration |
| `--gpu-dev` | `INSTALL_GPU_DEV=true` | Install GPU dev tools |
| `--korean-locale` | `KOREAN_LOCALE=true` | Enable Korean locale opt-in (see "Korean Locale") |
| `--locale-zip <path>` | `KOREAN_LOCALE_ZIP=` | Path to .mo catalog zip (Release asset) |

## Usage

```bash
startXFCE          # Start XFCE desktop
ubuntu             # Enter Ubuntu proot
archlinux          # Enter Arch Linux proot
prun libreoffice   # Run proot app from Termux terminal
cp2menu            # Copy proot .desktop files to XFCE menu
app-installer      # GUI for installing/removing extra apps
```

## GPU Acceleration

Hardware acceleration via **Zink (OpenGL→Vulkan) + Turnip driver** on Adreno GPUs (Snapdragon 6xx/7xx/8xx).  
Applied automatically to every bash/zsh session after installation.

> **Why Zink, not glamor?**  
> `glamor_egl` (X11 OpenGL acceleration) requires a DRI3-capable driver, but Termux:X11 Xwayland does not expose DRI3 for Adreno.  
> Zink routes OpenGL calls through Vulkan (Turnip), which **does** work via `/dev/kgsl-3d0` — the only path to hardware acceleration on Adreno today.

> **GTK4 apps crashing? (zenity, etc.)**  
> Zink + Turnip fails to create a GLX swap chain with Termux:X11 nightly APK → `GLXBadCurrentWindow`.  
> Fixed by `GSK_RENDERER=cairo` (Cairo software renderer for GTK4). Already set automatically.  
> Use `glmark2-es2` (EGL) instead of `glmark2` (GLX).

```bash
# Verify Zink is active
echo $MESA_LOADER_DRIVER_OVERRIDE   # → zink

# Show GPU model
gpu-info
# or directly:
cat /sys/class/kgsl/kgsl-3d0/gpu_model

# FPS overlay
hud glxgears

# Explicit Zink (same as always-on, useful for overrides)
zink glxgears
```

| Variable | Value | Role |
|----------|-------|------|
| `MESA_LOADER_DRIVER_OVERRIDE` | `zink` | Force OpenGL → Vulkan (Zink) |
| `TU_DEBUG` | `noconform` | Disable Turnip conformance checks |
| `ZINK_DESCRIPTORS` | `lazy` | Optimize descriptor updates |
| `MESA_NO_ERROR` | `1` | Disable GL error checks |
| `MESA_GL_VERSION_OVERRIDE` | `4.6COMPAT` | Advertise OpenGL 4.6 compat |
| `MESA_GLES_VERSION_OVERRIDE` | `3.2` | Advertise GLES 3.2 |
| `MESA_VK_WSI_PRESENT_MODE` | `immediate` | Disable Vulkan VSync (lower latency) |
| `GSK_RENDERER` | `cairo` | GTK4 Cairo renderer (prevents GLX crash) |
| `GALLIUM_HUD` | `fps` | FPS overlay (`hud` alias) |

> **Note**: If the XFCE4 compositor (xfwm4) causes a black screen,  
> go to Settings → Window Manager Tweaks → Compositor → uncheck "Enable display compositing"

## Korean Locale (optional)

Display XFCE menus / settings / app UI in Korean. Termux's bionic libc does not support `setlocale(LC_MESSAGES)`, so the usual "XFCE language setting" path won't work. We bypass this using an **LD_PRELOAD-based gettext hook**.

> This approach is based on the method shared by **흡혈귀왕 at 미코 (Mini Device Korea)**. Thanks! 🙏

### Usage

```bash
# 1) Enable Korean locale + point to locale.zip (downloaded from Release asset)
bash install.sh --distro archlinux --user <username> --korean-locale --locale-zip ~/Downloads/locale.zip

# 2) Start XFCE in Korean mode
tx11start --xstartup "$HOME/bin/startxfce4-ko"
```

### Components

| File | Role |
|------|------|
| `assets/force_gettext.c` | C source hooking gettext/dgettext/dcgettext + GTK label/button/menu/dialog symbols (built with `clang -shared`) |
| `domain/locale_ko.sh` | `setup_korean_locale_native()` — places .mo catalogs, builds `.so`, creates `startxfce4-ko` wrapper |
| `$PREFIX/lib/force_gettext.so` | Runtime-injected shared object |
| `$HOME/bin/startxfce4-ko` | Wrapper that launches XFCE in Korean mode (with DBus autostart) |

`locale.zip` (~163MB of glibc .mo catalogs) is distributed separately as a **GitHub Release asset**, not bundled in the repo.

### Verified apps

GIMP, Inkscape, Audacity, Thunderbird, VLC (proot), XFCE Settings Manager — menus, dialogs, and tooltips render in Korean.

## Shell (zsh + Powerlevel10k)

The installer sets **zsh** as the default shell and configures Powerlevel10k automatically.

```bash
# Reconfigure p10k prompt
p10k configure

# Aliases installed automatically
ll          # eza -alhgF
ls          # eza -lF --icons
cat         # bat
gpu-info    # show Adreno GPU model
zink        # run app with Zink forced
hud         # run app with FPS overlay
zrunhud     # proot app + FPS + GPU
shutdown    # kill -9 -1 (terminate all Termux processes)
```

## What Gets Installed

### Termux Native (always)

| Category | Packages |
|----------|----------|
| Base utils | wget, unzip, dbus, pulseaudio, yad |
| XFCE | xfce4, xfce4-goodies, firefox, papirus-icon-theme, termux-x11-nightly |
| CLI | git, zsh, eza, bat, fzf, htop, jq, neofetch |
| Korean IME | fcitx5, fcitx5-hangul, fcitx5-configtool |
| GPU (optional) | mesa, mesa-vulkan-icd-freedreno, vulkan-loader-generic, mesa-vulkan-icd-swrast |

### proot (optional)

| distro | base | Korean IME | entry command |
|--------|------|------------|---------------|
| ubuntu | Ubuntu (proot-distro) | nimf (auto) | `ubuntu` |
| archlinux | Arch Linux (proot-distro) | nimf (AUR) → fcitx5 fallback | `archlinux` |

> **Arch Linux nimf support**
> The installer automatically attempts an AUR build of nimf, falling back to fcitx5 on failure.
> Manual retry: `yay -S nimf nimf-libhangul`

## App Installer

Extra apps (GIMP, Inkscape, Audacity, VLC, LibreOffice, Thunderbird, etc.) can be installed via the GUI:

```bash
app-installer
```

- **yad-based search UI** — type app name/description to filter instantly (falls back to zenity if yad is missing)
- **Categories** — Graphics / Media / Office / Browser / Dev / Security / Utility / Communication
- **Termux native first** — GIMP, Inkscape, Audacity, Thunderbird install as Termux native (Korean locale supported)
- **proot auto-routing** — VLC, LibreOffice etc. install inside proot; VSCode (code-oss), Burp Suite install as Termux native

Source: [yanghoeg/App-Installer](https://github.com/yanghoeg/App-Installer) (Git Submodule)

## Tests

```bash
bash tests/run_tests.sh              # all 280 tests
bash tests/run_tests.sh domain_termux
bash tests/run_tests.sh domain_locale_ko
```

| Suite | Count | Coverage |
|-------|-------|----------|
| ports | 7 | adapter contract compliance |
| adapters | 24 | pkg_termux, ui_terminal, script_builder_zenity |
| domain_termux | 45 | termux_env logic |
| domain_xfce | 34 | xfce_env + migration logic |
| domain_proot | 58 | proot_env logic (Ubuntu/Arch) |
| domain_locale_ko | 18 | locale_ko logic (Korean locale) |
| app_installer | 50 | installer script validation |
| prun_ld_preload | 17 | prun / LD_PRELOAD regression |
| e2e_install | 27 | end-to-end composition & regression |
| **Total** | **280** | **All pass on real device** |

## Android System Optimization

For a stable, smooth desktop experience, apply the following system-level settings.

### Disable Phantom Process Killer (Android 12+)

Android 12+ aggressively kills background child processes, which can force-terminate the desktop session.  
Run via [LADB](https://github.com/hyperio546/ladb-builds/releases) or a PC ADB connection:

```bash
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
```

### Disable Battery Optimization

Go to **Android Settings → Apps → Termux** (and **Termux:X11**) → Battery → set to **Unrestricted**.  
Without this, Android throttles CPU usage in the background, causing frame drops even with Zink active.

### Wakelock

`startXFCE` calls `termux-wake-lock` automatically. For extended sessions, also enable it from the Termux notification: tap **"Acquire wakelock"**.

---

## Known Issues

### Termux:X11 — Right-click / Arrow Keys Broken After Switching Apps

**Symptoms**: After switching to another app and returning to Termux:X11, touch input registers as right-click and arrow keys stop working.

**Root Cause**: Android stops sending key-release events the moment an app loses focus. The Alt key gets stuck in a pressed state inside the X server — Alt+click = right-click, Alt+arrow = unexpected behavior. ([termux-x11 #781](https://github.com/termux/termux-x11/issues/781))

**No complete fix available**: Android's API does not support selective key interception, so there is no script-level solution. ([termux-x11 #253](https://github.com/termux/termux-x11/issues/253))

> **Samsung DeX devices only**: Termux:X11 → Preferences → Keyboard → enable **"Intercept system shortcuts"** for a proper fix. This option is hidden on standard Android devices.

**Workarounds**:
- **Press Alt once** to release the stuck key (fastest)
- **Super+I** shortcut for manual input reset (clears stuck Alt/Shift/Ctrl + resets pointer button map)
- Switch apps via **swipe gesture** instead of Alt+Tab — the bug does not occur

> The `fix-x11-input` autostart entry runs automatically at session start to initialize input state.

---

## Project Structure

```
Termux_XFCE/
├── install.sh                    ← entry point + DI container
├── ports/
│   ├── pkg_manager.sh            ← package manager contract
│   ├── script_builder.sh         ← runtime script builder contract
│   └── ui.sh                     ← UI contract
├── adapters/
│   ├── input/
│   │   ├── cli.sh                ← CLI arg / env var parsing
│   │   └── interactive.sh        ← interactive prompts
│   └── output/
│       ├── pkg_termux.sh         ← Termux pkg adapter
│       ├── pkg_ubuntu.sh         ← Ubuntu apt adapter
│       ├── pkg_arch.sh           ← Arch pacman adapter
│       ├── pkg_common_termux.sh  ← shared Termux pkg helpers
│       ├── script_builder_zenity.sh ← startXFCE / kill / cp2menu script generator
│       ├── ui_terminal.sh        ← echo-based UI
│       ├── ui_yad.sh             ← yad searchable GUI (zenity superset)
│       └── ui_zenity.sh          ← zenity GUI UI (fallback)
├── domain/
│   ├── packages.sh               ← package list definitions
│   ├── termux_env.sh             ← Termux environment logic
│   ├── xfce_env.sh               ← XFCE setup logic
│   ├── proot_env.sh              ← proot logic (Ubuntu/Arch common)
│   └── locale_ko.sh              ← Korean locale opt-in (LD_PRELOAD gettext hook)
├── tar/
│   ├── config/                   ← XFCE / autostart preset configs
│   └── conky/                    ← Conky theme (Alterf)
├── assets/
│   └── force_gettext.c           ← gettext hooking C source (→ force_gettext.so)
├── tests/                        ← 280 automated tests (9 suites)
└── app-installer/                ← extra app GUI (Git Submodule)
```

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable — real-device tested, for end users |
| `dev` | Development — merged to main after tests pass |

## Contributing

Bug reports and PRs are welcome via GitHub Issues / Pull Requests.
