# Common Shell Command Cheatsheet

English | [中文](CHEATSHEET.md)

Everyday operations for the bare TTY / console. After the "Tools" module is installed, just type `cheat` in your shell to open this table.
The modern tools (`rg`/`fd`/`bat`/`fzf`/`eza`/`z`) come from the Shell module; `tldr <command>` shows usage examples for any command at any time.

## TTY switching & tips

| Action | Notes |
|--------|-------|
| `Ctrl+Alt+F1`~`F6` | Switch between the 6 virtual consoles (F1 stays a plain console as a fallback) |
| `Shift+PgUp` / `PgDn` | Console scrollback paging (buffer is small; use tmux for lots of scrollback) |
| Mouse select / middle-click paste | Needs `gpm` (Tools module → TTY enhancers); the wheel scrolls too |
| `setterm --blank 15` | Blank the screen after 15 idle minutes; `--blank 0` disables blanking |
| `clear` / `Ctrl+L` | Clear the screen |
| `reset` | Reset the terminal when the display gets garbled |

## Files & directories

```sh
ls -lah              # list (incl. hidden, human-readable sizes); with eza, use ll
cd -                 # go back to the previous directory
z keyword            # zoxide: jump to a frequently-visited dir (needs Shell module)
cp -r src dst        # recursive copy       mv src dst   # move/rename
rm -rf dir           # recursive force-delete (dangerous, be sure)
mkdir -p a/b/c       # create nested dirs
ln -s target link    # create a symlink
du -sh *             # size of each item here; ncdu browses interactively
df -h                # free disk space; duf looks nicer
find . -name '*.log' # find by name; fd '\.log$' is faster and simpler
stat file            # show file metadata
```

## Text / viewing / searching

```sh
cat file             # view; bat file adds syntax highlight and line numbers
less file            # paged view (q quit, / search, g/G top/bottom)
head -n 20 file      # first 20 lines; tail -n 20 file last 20 lines
tail -f log          # follow a log live
grep -rn 'xxx' .     # recursive search; rg 'xxx' is faster (ripgrep)
rg -i 'xxx' --type py# ignore case, limit to a file type
sed -n '10,20p' file # print lines 10-20
awk '{print $1}' file# take the first column
sort file | uniq -c  # sort then count duplicate lines
wc -l file           # count lines
fzf                  # fuzzy finder; Ctrl+R fuzzy-search command history (needs Shell module)
```

## Processes / resources

```sh
htop / btop          # interactive process / resource monitor (Tools module)
ps aux | rg name     # find a process; procs name is more modern
kill -9 PID          # force-kill; pkill name kills by name
jobs / fg / bg       # job control; Ctrl+Z suspend, & run in background
nohup cmd &          # keep running after you log out
free -h              # memory usage        uptime   # load / uptime
watch -n1 'cmd'      # re-run a command every second and refresh
```

## Network (Tools module → network tools)

```sh
ip a                 # show NICs / IPs (replaces ifconfig)
ip r                 # routing table
ss -tulpn            # listening ports / connections (replaces netstat)
ping host            # connectivity
dig domain / nslookup# DNS queries
mtr host             # live route + packet-loss diagnosis
curl -I url          # headers only; curl -O url downloads
wget url             # download
nmap -p- host        # scan all ports (only targets you're authorized to scan)
tcpdump -i any port 80  # packet capture
scp file user@host:path # copy to a remote; rsync -avP src dst incremental sync
ssh user@host        # log into a remote (best experience with a truecolor terminal)
```

## systemd / services

```sh
systemctl status svc      # show status
systemctl start/stop/restart svc
systemctl enable --now svc   # enable at boot + start now
systemctl list-units --failed # list failed units
journalctl -u svc -e      # that service's logs (end); -f to follow live
journalctl -b             # all logs from this boot
systemctl reboot / poweroff
```

## tmux (split / multi-session even on a single console)

```sh
tmux                 # new session; tmux a reattaches the most recent
Prefix Ctrl+b, then:
  |  split vertical   -  split horizontal   (this repo's config; defaults are % and ")
  arrows      move between panes
  c  new window   n/p switch windows   number jump to a window
  d  detach session (programs keep running in the background)
  [  enter scrollback/copy mode (q to quit; configured for vi keys)
  r  reload ~/.tmux.conf
Mouse is on: click panes, drag borders, scroll with the wheel.
```

## git

```sh
git status           # current state       git diff   # unstaged changes
git add -A           # stage everything     git commit -m "message"
git log --oneline --graph --all   # compact commit graph
git switch -c branch # create and switch; git switch branch to switch
git pull / git push
git stash / git stash pop         # stash / restore the working tree
git restore file      # discard changes to a file
```

## Vim / Neovim quick start

```
i insert   Esc back to normal mode   :w save   :q quit   :wq save & quit   :q! quit without saving
dd delete line  yy copy line  p paste   u undo   Ctrl+r redo
/keyword search (n next)      :%s/old/new/g global replace
gg go to top   G go to bottom   :number jump to a line
```

---
Tip: when you can't recall a command's flags, `tldr <command>` gives you the few most common usages (offline).
