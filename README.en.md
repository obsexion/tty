# tty — console beautifier toolbox (Debian / Arch)

English | [中文](README.md)

Turns the kernel console (Ctrl+Alt+F1~F6) of a headless Linux box from "white-on-black, huge and blurry" into something clean and modern.
`git clone` it, enter the folder for your distro, run `install.sh`, and tick what you want in the interactive menu.

```bash
git clone <this-repo> tty && cd tty

# Debian:
sudo ./debian/install.sh

# Arch:
sudo ./arch/install.sh
```

## What it does

| Module | Effect | When it takes effect |
|--------|--------|----------------------|
| **Resolution** | Edit GRUB to bump the framebuffer to 1080p etc., so text is no longer huge and blurry | after reboot |
| **Font** | A crisp **Terminus** font (Debian: console-setup; Arch: vconsole + setfont) | immediately + on boot |
| **Colors** | Redefine the console's 16 colors to **Gruvbox** (warm, easy on the eyes) | immediately + on boot |
| **Shell** | zsh/fish + the **starship** prompt + modern tools like `ripgrep`/`bat`/`fzf`/`zoxide`/`eza` | after re-login |
| **Tools** | **Per-item** pick of dev/network/editor/TTY-enhancer tools, set a default editor, install the cheatsheet | immediately + new shell |
| **fbterm** | A framebuffer terminal using **TTF fonts**, auto-started on login to tty2-6 | switch to tty2 / re-login |

## Usage

```bash
sudo ./<distro>/install.sh          # interactive menu (recommended)
sudo ./<distro>/install.sh --all    # run everything (fbterm autostart still asks)
sudo ./<distro>/install.sh --yes    # non-interactive, take all defaults
./<distro>/install.sh --dry-run     # only print what it would do, change nothing (non-root OK; preview first)
```

In a menu, multi-select with space/comma-separated numbers, e.g. `1 2 3`, or type `all`.

## Optional tools (TTY experience)

The **Tools** module lets you pick what to install **per item by category** (choose categories first, then pick items by number inside each):

| Category | Contents |
|----------|----------|
| **Dev tools** | git, build toolchain (gcc/make), cmake, python, nodejs, go, rust, gdb, jq, shellcheck |
| **Network tools** | curl, wget, openssh, nmap, net-tools, iproute2, dig, mtr, traceroute, tcpdump, rsync, whois, socat, netcat, iftop, nload |
| **Editors** | nano, vim, neovim, micro, helix, emacs-nox |
| **TTY enhancers** | **tmux** (split/scrollback/sessions on a single console), **gpm** (console mouse: select-copy + wheel), htop, btop, ncdu |
| **Modern CLI extras** | tldr, tree, duf, dust, procs, git-delta |

Per-distro package-name differences (e.g. `build-essential`↔`base-devel`, `dnsutils`↔`bind`, `netcat-openbsd`↔`openbsd-netcat`, `tldr`↔`tealdeer`) are all mapped in each distro's `pkg.sh`; a package your distro doesn't have (e.g. helix/dust/procs on Debian stable) is skipped with a notice.

This module is tuned specifically for the **bare TTY experience**:

- **Default editor**: after you pick editors, you can set one as `$EDITOR`/`$VISUAL`; vim/neovim also get a minimal **16-color, mouse-enabled** config.
- **tmux**: ships a `~/.tmux.conf` with mouse on, 50k-line scrollback, `|` vertical split and `-` horizontal split — so you can split, scroll and background jobs within a single console.
- **gpm**: gives you a mouse in the bare kernel console (select-copy, wheel scroll); `systemctl enable --now gpm` runs automatically after install.
- **Cheatsheet**: installs [shell/CHEATSHEET.en.md](shell/CHEATSHEET.en.md) into your home dir and adds a `cheat` command for quick lookups; optionally install `tldr` for per-command usage examples (offline).

> The modern-CLI baseline (ripgrep/fd/bat/fzf/zoxide/eza) is still installed by the **Shell** module; the **Tools** module only adds extra opt-in installs, and the two don't interfere. In non-interactive mode (`--yes`/`--all`) the Tools module installs a recommended set: git, curl, wget, openssh, tmux, gpm, htop, vim, tldr, tree.

## Important notes

- **The kernel console's hard ceiling**: only 16 colors, bitmap fonts, no anti-aliasing. The resolution/font/colors modules already push the native console to its limit.
- **starship and modern CLI tools only have 16 colors on the bare console** and degrade accordingly. For truecolor, the easiest path is to **SSH** in from elsewhere with a modern terminal (WezTerm / Kitty / Windows Terminal).
- **fbterm** breaks through the font ceiling: it renders **TrueType fonts** on the framebuffer (crisp, scalable, anti-aliased). But fbterm uses the standard ANSI palette and **does not redefine the 16 RGB values**, so Gruvbox coloring mainly applies to the kernel console via the colors module; inside fbterm, color comes from app-level themes (starship, ls colors, etc.).

### fbterm's safety design ⚠️

fbterm is launched from the login shell (it does not replace getty), so the lock-out risk is already low. The script goes further:

- The autostart snippet **only runs on tty2-6**; `tty1` always stays a plain console as a fallback.
- The snippet is guarded: it won't fire when already inside fbterm, under X, or over SSH (pts).
- If something goes wrong, press **Ctrl+Alt+F1** to get back to tty1.

After installing, press **Ctrl+Alt+F2** to try it (the first time you need to re-login so the `video` group takes effect). To change fonts, edit `font-names` in `~/.fbtermrc` (install a Nerd Font and put its name there). On Arch, fbterm is in the **AUR**, so the script installs it via `paru`/`yay`; without an AUR helper it prints a manual hint.

### Chinese (CJK) display

**The bare kernel console cannot show Chinese** — it can load a bitmap font of at most ~512 glyphs at a time, while Chinese has thousands; Terminus contains no CJK glyphs at all, so after the font module Chinese turns into boxes. This is an inherent console limitation, not a bug.

To read Chinese on the console, use **fbterm**: it renders TTF and can display CJK. The fbterm module asks whether to install a Chinese font (Debian: `fonts-wqy-microhei`; Arch: `noto-fonts-cjk`); say "yes" and it sets `font-names` in `~/.fbtermrc` to "Latin font + Chinese font", so Chinese shows correctly inside fbterm. Or just **SSH** in from the host — the terminal emulator supports Chinese natively.

## Restore

Everything is backed up to `backups/<timestamp>/` (with a `manifest.tsv`) before any change. To restore:

```bash
sudo ./<distro>/uninstall.sh                 # restore the most recent run
sudo ./<distro>/uninstall.sh backups/<timestamp> # restore a specific run
```

Restore will: recover changed files per the manifest (including the profile that holds the fbterm autostart snippet), delete `tty-colors.service`, and regenerate boot artifacts (Debian: grub + initramfs; Arch: grub + mkinitcpio). It will **not** auto-uninstall packages it installed, to avoid deleting things by mistake.

## Structure (shared core + thin distro layers)

```
shared/
  common.sh            logging / backup+manifest / idempotent config edits / managed blocks (distro-agnostic)
  install-core.sh      entry main flow (menu/dispatch/summary), shared by both distros
  uninstall-core.sh    restore main flow, shared by both distros
  modules/
    resolution.sh      GRUB resolution (same for both distros)
    colors.sh          Gruvbox palette (same for both distros)
    tools.sh           optional tools (per-item pick) + default editor + tmux/gpm + cheatsheet
    fbterm.sh          fbterm install/config/autostart (same for both; installs via aur_install)
  assets/
    vtrgb/gruvbox          Gruvbox palette
    starship/starship.toml prompt preset
    fbterm/fbtermrc        fbterm config (TTF fonts)
    tmux/tmux.conf         tmux preset (mouse + big scrollback + 16-color status bar)
    editor/vimrc           minimal vim TTY config    editor/init.vim  minimal neovim config
debian/
  install.sh uninstall.sh  thin entry points
  pkg.sh                   apt layer (pkg_install / BAT_BIN=batcat … + TOOL_PKG tool map)
  modules/{font,shell}.sh  Debian-specific (console-setup / apt names / starship official script)
arch/
  install.sh uninstall.sh  thin entry points
  pkg.sh                   pacman+AUR layer (pkg_install/aur_install … + TOOL_PKG/TOOL_AUR maps)
  modules/{font,shell}.sh  Arch-specific (vconsole+setfont / pacman names / starship repo package)
shell/
  CHEATSHEET.md            common-command cheatsheet (Tools module installs it to home; open with `cheat`)
  sudo-nopasswd.sh         passwordless-sudo script
```

**Distro decoupling**: the `shared/` core and common modules only call `pkg_detect` / `pkg_install` / `aur_install` and the binary-name vars `BAT_BIN`/`FD_BIN`, which each distro's `pkg.sh` implements — so the common logic isn't duplicated.

## Customize

- **Colors**: edit `shared/assets/vtrgb/gruvbox` (3 rows = red/green/blue, 16 values of 0-255 each), then re-run the colors module.
- **Prompt**: edit `shared/assets/starship/starship.toml`.
- **fbterm font**: edit `font-names` / `font-size` in `shared/assets/fbterm/fbtermrc`, or edit `~/.fbtermrc` directly.
- **Tool list**: add/remove tools in each distro's `TOOL_PKG` in `pkg.sh` (for a new key, add a `"key|label"` line to the category arrays in `shared/modules/tools.sh`).
- **tmux / editor presets**: edit `shared/assets/tmux/tmux.conf`, `shared/assets/editor/{vimrc,init.vim}`, or the corresponding files in your home dir.
- **Cheatsheet**: edit `shell/CHEATSHEET.md`; re-running the Tools module reinstalls it to your home dir.
