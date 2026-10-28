# shell — handy scripts + command cheatsheet

English | [中文](README.md)

A place for standalone, everyday shell scripts (self-contained, independent of the rest of this repo), plus a common-command cheatsheet.

| File | Purpose |
|------|---------|
| [CHEATSHEET.en.md](CHEATSHEET.en.md) | Common shell-command cheatsheet (TTY switching, files/text/processes/network/systemd/tmux/git/vim). The **Tools** module installs it to `~/.local/share/tty-cheatsheet.md` and adds a `cheat` command to open it anytime |
| [sudo-nopasswd.sh](sudo-nopasswd.sh) | Let a user run sudo without a password: first writes a `/etc/sudoers.d/` drop-in and **really tests it with the credential cache cleared**; if it's overridden, **automatically falls back** to appending the rule to the end of `/etc/sudoers`; validated throughout with `visudo`, supports `--undo` |

## sudo-nopasswd.sh

```bash
sudo ./sudo-nopasswd.sh            # enable passwordless sudo for the current user
sudo ./sudo-nopasswd.sh -u alice   # enable it for a specific user
sudo ./sudo-nopasswd.sh --undo     # disable
./sudo-nopasswd.sh --dry-run       # only show what it would do, change nothing
```

After installing the drop-in, the script **actually verifies** once — as the target user, with the credential cache cleared — whether sudo is now passwordless. If `/etc/sudoers` has a matching rule ordered after `@includedir` (which would override the drop-in), the script automatically appends the rule to the end of `/etc/sudoers` (so the last match wins); the main sudoers file is backed up to `/var/backups/sudo-nopasswd/` before any change.

⚠️ Passwordless sudo lowers security (whoever gets that account effectively gets root). Only recommended on your own single-user machine / VM.
