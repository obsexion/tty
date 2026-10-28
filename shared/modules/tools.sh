#!/usr/bin/env bash
# tools.sh — optional, à-la-carte tools + command cheatsheet + TTY ergonomics.
#
# Distro-agnostic: the categories, the per-item picker and all the post-install
# wiring (default editor, tmux/gpm, cheatsheet) live here. Only the "tool key ->
# package name" map is distro-specific (TOOL_PKG / TOOL_AUR in each pkg.sh), so
# a new distro just adds a map. Keys absent from a distro's map are skipped.
#
# This module is purely additive: it does NOT touch the shell module's modern
# CLI baseline (ripgrep/fd/bat/fzf/zoxide/eza). It writes its own managed blocks
# (distinct markers) so it never clobbers the shell module's block.

# --- small helpers -----------------------------------------------------------

# tool_install <key...> : resolve each key via the distro map and install.
# AUR-only keys go through aur_install; unmapped keys are skipped with a warn.
tool_install() {
  local key spec aur
  for key in "$@"; do
    aur="${TOOL_AUR[$key]:-}"
    if [ -n "$aur" ]; then
      aur_install $aur || warn "$key(AUR)安装失败,继续。"
      continue
    fi
    spec="${TOOL_PKG[$key]:-}"
    if [ -z "$spec" ]; then
      warn "本发行版没有 $key 的包映射,跳过。"
      continue
    fi
    # shellcheck disable=SC2086  # intentional word-split: a key may map to >1 pkg
    pkg_install $spec || warn "$key 安装失败,继续。"
  done
}

# _in_list <needle> <haystack...> : membership test.
_in_list() { local x="$1"; shift; local e; for e in "$@"; do [ "$e" = "$x" ] && return 0; done; return 1; }

# _editor_cmd <editor-key> : the command name to put in $EDITOR.
_editor_cmd() {
  case "$1" in
    neovim) printf 'nvim' ;;
    helix)  printf 'hx' ;;
    *)      printf '%s' "$1" ;;   # nano / vim / micro / emacs
  esac
}

# _tools_rc_for <home> <login-shell> : the interactive rc to wire env/alias into.
_tools_rc_for() {
  local home="$1" shell="$2"
  case "$shell" in
    *zsh)  printf '%s/.zshrc' "$home" ;;
    *fish) printf '%s/.config/fish/config.fish' "$home" ;;
    *)     printf '%s/.bashrc' "$home" ;;
  esac
}

# _pick_tools <title> <"key|label">... : print a numbered menu (to stderr) and
# read a multi-select from the terminal. Result goes into the global PICKED[].
_pick_tools() {
  local title="$1"; shift
  local entries=("$@")
  local keys=() labels=() e
  for e in "${entries[@]}"; do keys+=("${e%%|*}"); labels+=("${e#*|}"); done
  {
    printf '\n%s%s%s(多选,空格/逗号分隔序号,all=全选,留空=跳过):\n' "$C_BOLD" "$title" "$C_RESET"
    local i
    for i in "${!keys[@]}"; do printf '  %2d) %-11s %s\n' "$((i+1))" "${keys[$i]}" "${labels[$i]}"; done
  } >&2
  local ans n
  read -r -p "选择: " ans
  PICKED=()
  [ -z "${ans// /}" ] && return 0
  if [ "$ans" = "all" ]; then PICKED=("${keys[@]}"); return 0; fi
  for n in ${ans//,/ }; do
    if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "${#keys[@]}" ]; then
      PICKED+=("${keys[$((n-1))]}")
    else
      warn "忽略无效序号:$n"
    fi
  done
}

# --- post-install wiring -----------------------------------------------------

# _tools_install_cfg <who> <src> <dst> : back up + install a config, owned by who.
_tools_install_cfg() {
  local who="$1" src="$2" dst="$3"
  [ -f "$src" ] || { warn "缺少配置资产 $src,跳过。"; return 0; }
  backup_file "$dst"
  run install -D -m 0644 -o "$who" -g "$who" "$src" "$dst"
  ok "已写入 $dst"
}

# Editors: install minimal TTY/16-color configs for vim/nvim, then set $EDITOR.
_tools_setup_editors() {
  local who="$1" home="$2" ushell="$3"; shift 3
  local chosen=("$@")
  local editors=() e
  for e in nano vim neovim micro helix emacs; do
    _in_list "$e" "${chosen[@]}" && editors+=("$e")
  done
  [ "${#editors[@]}" -eq 0 ] && return 0

  _in_list vim    "${editors[@]}" && _tools_install_cfg "$who" "$ASSETS_DIR/editor/vimrc"    "$home/.vimrc"
  _in_list neovim "${editors[@]}" && _tools_install_cfg "$who" "$ASSETS_DIR/editor/init.vim" "$home/.config/nvim/init.vim"

  # For the default-editor pick, drop editors that didn't actually install
  # (e.g. an unmapped one like helix on Debian stable). Skip the filter under
  # dry-run, where nothing is installed yet.
  if [ "$DRY_RUN" != "1" ]; then
    local present=()
    for e in "${editors[@]}"; do have "$(_editor_cmd "$e")" && present+=("$e"); done
    if [ "${#present[@]}" -eq 0 ]; then
      warn "所选编辑器都没装上,跳过设置默认编辑器。"; return 0
    fi
    editors=("${present[@]}")
  fi

  local def; def="$(choose "设为默认编辑器(写入 \$EDITOR/\$VISUAL):" 1 "${editors[@]}")"
  local cmd; cmd="$(_editor_cmd "$def")"

  local rc; rc="$(_tools_rc_for "$home" "$ushell")"
  local content
  if [[ "$ushell" == *fish ]]; then
    run install -d -o "$who" -g "$who" "$home/.config/fish"
    content="set -gx EDITOR $cmd"$'\n'"set -gx VISUAL $cmd"
  else
    content="export EDITOR='$cmd'"$'\n'"export VISUAL='$cmd'"
  fi
  write_managed_block "$rc" "$content" "$who" \
    "# >>> tty-beautify tools:env >>>" "# <<< tty-beautify tools:env <<<"
  ok "默认编辑器设为 $cmd(写入 $rc,重新登录生效)。"
}

# tmux: ship a mouse-enabled, big-scrollback, 16-color-safe config.
_tools_setup_tmux() {
  local who="$1" home="$2"
  _tools_install_cfg "$who" "$ASSETS_DIR/tmux/tmux.conf" "$home/.tmux.conf"
  ok "tmux 已配置:鼠标选区/滚轮、5 万行回滚、| 竖分 - 横分。"
}

# gpm: console mouse — scroll + copy/paste right in the kernel console.
_tools_setup_gpm() {
  if have systemctl; then
    run systemctl enable --now gpm \
      && ok "gpm 已启用:纯控制台也能用鼠标选区复制、滚轮翻页。" \
      || warn "gpm 服务启用失败(可稍后:systemctl enable --now gpm)。"
  else
    warn "没有 systemctl,请手动启用 gpm 服务。"
  fi
}

# tldr: build the offline cache so lookups work without network.
_tools_update_tldr() {
  local who="$1"
  if [ "$DRY_RUN" != "1" ] && ! have tldr; then
    warn "tldr 似乎没装上,跳过缓存更新。"; return 0
  fi
  info "更新 tldr 离线缓存"
  run sudo -u "$who" tldr --update \
    || warn "tldr 缓存更新失败(可稍后手动:tldr --update)。"
}

# Cheatsheet: drop the repo's CHEATSHEET into the user's data dir + a `cheat`
# alias to open it (with bat if present, else less).
_tools_setup_cheatsheet() {
  local who="$1" home="$2" ushell="$3"
  local src="$REPO_ROOT/shell/CHEATSHEET.md"
  [ -f "$src" ] || { warn "缺少 $src,跳过命令速查。"; return 0; }
  local dst="$home/.local/share/tty-cheatsheet.md"
  backup_file "$dst"
  run install -D -m 0644 -o "$who" -g "$who" "$src" "$dst"

  local pager="less"
  have "${BAT_BIN:-bat}" && pager="${BAT_BIN:-bat} -l md --paging=always"

  local rc; rc="$(_tools_rc_for "$home" "$ushell")"
  local content
  if [[ "$ushell" == *fish ]]; then
    run install -d -o "$who" -g "$who" "$home/.config/fish"
    content="alias cheat '$pager $dst'"
  else
    content="alias cheat='$pager $dst'"
  fi
  write_managed_block "$rc" "$content" "$who" \
    "# >>> tty-beautify tools:cheat >>>" "# <<< tty-beautify tools:cheat <<<"
  ok "命令速查已安装:$dst(新开 shell 后输入 ${C_BOLD}cheat${C_RESET} 查看)。"
}

# --- main --------------------------------------------------------------------
module_tools() {
  section "选装工具 + 命令速查"

  local who home ushell
  who="$(target_user)"; home="$(target_home)"
  ushell="$(getent passwd "$who" | cut -d: -f7)"
  info "目标用户:$who ($home),登录 shell:${ushell:-未知}"

  # Category item tables: "key|label", in display order. Distro-agnostic;
  # a key missing from the distro map is skipped at install time.
  local DEV=(
    "git|git 版本控制" "buildtools|构建工具链(gcc/make 等)" "make|make" "cmake|cmake"
    "python|Python3 + pip + venv" "nodejs|Node.js + npm" "go|Go" "rust|Rust(rustc/cargo)"
    "gdb|GDB 调试器" "jq|jq(JSON 处理)" "shellcheck|ShellCheck(shell 静态检查)"
  )
  local NET=(
    "curl|curl" "wget|wget" "openssh|OpenSSH(客户端+服务端)" "nmap|nmap(端口扫描)"
    "net-tools|net-tools(ifconfig 等)" "iproute2|iproute2(ip/ss)" "dig|dig/nslookup(DNS)"
    "mtr|mtr(路由+丢包)" "traceroute|traceroute" "tcpdump|tcpdump(抓包)" "rsync|rsync"
    "whois|whois" "socat|socat" "netcat|netcat(nc)" "iftop|iftop(实时流量)" "nload|nload(带宽)"
  )
  local EDI=(
    "nano|nano(最易上手)" "vim|Vim" "neovim|Neovim" "micro|micro(鼠标友好)"
    "helix|Helix(Debian stable 无)" "emacs|Emacs(无 X 版)"
  )
  local TTYX=(
    "tmux|tmux(单控制台分屏/回滚/会话)" "gpm|gpm(控制台鼠标:滚动+复制)"
    "htop|htop(进程监控)" "btop|btop(资源监控)" "ncdu|ncdu(磁盘占用)"
  )
  local CLI=(
    "tldr|tldr(命令示例速查)" "tree|tree(目录树)" "duf|duf(磁盘用量)"
    "dust|dust(目录体积,Debian 无)" "procs|procs(现代 ps,Debian 无)" "delta|git-delta(漂亮 diff)"
  )

  local CHOSEN=()
  if [ "$ASSUME_YES" = "1" ]; then
    # Non-interactive: a sensible TTY-friendly recommended set.
    CHOSEN=(git curl wget openssh tmux gpm htop vim tldr tree)
    info "非交互模式:安装推荐集:${CHOSEN[*]}"
  else
    cat >&2 <<'MENU'

选择要浏览的分类(多选,空格/逗号分隔序号,all=全部,留空=跳过本模块):
  1) 开发工具       git / gcc / python / node / go / rust / gdb …
  2) 网络工具       curl / wget / ssh / nmap / ip / dig / mtr / tcpdump …
  3) 编辑器         nano / vim / neovim / micro / helix / emacs
  4) TTY 增强       tmux / gpm(鼠标) / htop / btop / ncdu
  5) 现代 CLI 扩展  tldr / tree / duf / dust / procs / delta
MENU
    local cans n
    read -r -p "分类选择 [1 2 3 4 5]: " cans
    cans="${cans:-1 2 3 4 5}"
    [ "$cans" = "all" ] && cans="1 2 3 4 5"
    for n in ${cans//,/ }; do
      case "$n" in
        1) _pick_tools "开发工具"      "${DEV[@]}";  CHOSEN+=("${PICKED[@]}") ;;
        2) _pick_tools "网络工具"      "${NET[@]}";  CHOSEN+=("${PICKED[@]}") ;;
        3) _pick_tools "编辑器"        "${EDI[@]}";  CHOSEN+=("${PICKED[@]}") ;;
        4) _pick_tools "TTY 增强"      "${TTYX[@]}"; CHOSEN+=("${PICKED[@]}") ;;
        5) _pick_tools "现代 CLI 扩展" "${CLI[@]}";  CHOSEN+=("${PICKED[@]}") ;;
        *) warn "忽略无效分类:$n" ;;
      esac
    done
  fi

  if [ "${#CHOSEN[@]}" -eq 0 ]; then
    warn "没有选择任何工具,工具模块结束。"
    return 0
  fi

  info "将安装:${CHOSEN[*]}"
  tool_install "${CHOSEN[@]}"

  # Post-install wiring, each only if its tool was chosen.
  _tools_setup_editors "$who" "$home" "$ushell" "${CHOSEN[@]}"
  _in_list tmux "${CHOSEN[@]}" && _tools_setup_tmux "$who" "$home"
  _in_list gpm  "${CHOSEN[@]}" && _tools_setup_gpm
  _in_list tldr "${CHOSEN[@]}" && _tools_update_tldr "$who"

  # Cheatsheet: offer it whenever the tools module runs.
  if confirm "安装「常用命令速查」到用户目录并加 cheat 命令吗?" "y"; then
    _tools_setup_cheatsheet "$who" "$home" "$ushell"
  fi

  ok "工具模块完成。"
  warn "提示:默认编辑器 / cheat 别名在${C_BOLD}新开 shell${C_RESET}后生效;gpm 让纯控制台也能用鼠标。"
}
