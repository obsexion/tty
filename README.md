# tty — 控制台美化工具箱(Debian / Arch)

[English](README.en.md) | 中文

让无桌面 Linux 的内核控制台(Ctrl+Alt+F1~F6)从"黑底白字、又大又糊"变得清爽现代。
`git clone` 下来,进对应发行版的文件夹跑 `install.sh`,交互菜单勾选要做哪些。

```bash
git clone <this-repo> tty && cd tty

# Debian:
sudo ./debian/install.sh

# Arch:
sudo ./arch/install.sh
```

## 它能做什么

| 模块 | 作用 | 生效时机 |
|------|------|----------|
| **分辨率** | 改 GRUB,把 framebuffer 调到 1080p 等,字不再又大又糊 | 重启后 |
| **字体** | 清晰的 **Terminus** 字体(Debian: console-setup;Arch: vconsole + setfont) | 立即 + 开机 |
| **配色** | 把控制台 16 色重定义为 **Gruvbox**(暖色护眼) | 立即 + 开机 |
| **Shell** | zsh/fish + **starship** 提示符 + `ripgrep`/`bat`/`fzf`/`zoxide`/`eza` 等现代工具 | 重新登录后 |
| **工具** | 按分类**逐项勾选**装开发/网络/编辑器/TTY 增强工具,设默认编辑器,装命令速查 | 立即 + 新开 shell |
| **fbterm** | framebuffer 终端,用 **TTF 字体**,登录 tty2-6 自动进入 | 切到 tty2 / 重新登录 |

## 用法

```bash
sudo ./<distro>/install.sh          # 交互菜单(推荐)
sudo ./<distro>/install.sh --all    # 跑全部(fbterm 自启仍会询问)
sudo ./<distro>/install.sh --yes    # 非交互,全取默认值
./<distro>/install.sh --dry-run     # 只打印将做的事、不改系统(可非 root,先看看)
```

菜单里多选用空格/逗号分隔序号,例如 `1 2 3`,或输入 `all`。

## 选装工具(TTY 体验优化)

「工具」模块让你**按分类逐项勾选**要装的东西(先选分类,再在分类里用序号多选):

| 分类 | 内容 |
|------|------|
| **开发工具** | git、构建工具链(gcc/make)、cmake、python、nodejs、go、rust、gdb、jq、shellcheck |
| **网络工具** | curl、wget、openssh、nmap、net-tools、iproute2、dig、mtr、traceroute、tcpdump、rsync、whois、socat、netcat、iftop、nload |
| **编辑器** | nano、vim、neovim、micro、helix、emacs-nox |
| **TTY 增强** | **tmux**(单控制台分屏/回滚/会话)、**gpm**(控制台鼠标:选区复制 + 滚轮)、htop、btop、ncdu |
| **现代 CLI 扩展** | tldr、tree、duf、dust、procs、git-delta |

包名的发行版差异(如 `build-essential`↔`base-devel`、`dnsutils`↔`bind`、`netcat-openbsd`↔`openbsd-netcat`、`tldr`↔`tealdeer`)都由各发行版的 `pkg.sh` 映射;本发行版没有的包(如 Debian stable 的 helix/dust/procs)会自动跳过并提示。

这个模块专门针对**纯 TTY 体验**做了优化:

- **默认编辑器**:选了编辑器后,可把其中一个设为 `$EDITOR`/`$VISUAL`;并给 vim/neovim 装一份 **16 色、开启鼠标**的极简配置。
- **tmux**:随附 `~/.tmux.conf`,开好鼠标、5 万行回滚、`|` 竖分 `-` 横分 —— 在单个控制台里也能分屏、滚屏、挂后台。
- **gpm**:纯内核控制台里用上鼠标(选区复制、滚轮翻页),装完自动 `systemctl enable --now gpm`。
- **命令速查**:把 [shell/CHEATSHEET.md](shell/CHEATSHEET.md) 装到用户目录并加 `cheat` 命令,随时翻常用命令;可选装 `tldr` 查单条命令的用法示例(离线)。

> 现代 CLI 的基线(ripgrep/fd/bat/fzf/zoxide/eza)仍由 **Shell** 模块安装,「工具」模块只做额外选装,两者互不影响。非交互(`--yes`/`--all`)时「工具」模块装一份推荐集:git、curl、wget、openssh、tmux、gpm、htop、vim、tldr、tree。

## 重要说明

- **内核控制台的硬天花板**:只有 16 色、点阵字体、无抗锯齿。分辨率/字体/配色三个模块已经把原生控制台做到极致。
- **starship 和现代 CLI 工具在纯控制台只有 16 色**,会降级显示。想要真彩色,从别处 **SSH** 进来用现代终端(WezTerm / Kitty / Windows Terminal)最省事。
- **fbterm** 用来突破字体天花板:它在 framebuffer 上渲染 **TrueType 字体**(清晰、可缩放、抗锯齿)。但 fbterm 用标准 ANSI 调色板,**不重定义 16 色的 RGB**,所以 Gruvbox 配色主要靠 colors 模块作用于内核控制台;fbterm 里的配色靠 app 级主题(starship、ls 颜色等)。

### fbterm 的安全设计 ⚠️

fbterm 由登录 shell 触发(不替换 getty),锁死风险本就低。脚本进一步:

- 自启片段**只在 tty2-6 生效**,`tty1` 永远保持纯控制台做兜底。
- 片段带守卫:已在 fbterm 内、在 X、或通过 SSH(pts)时都不触发。
- 出问题按 **Ctrl+Alt+F1** 回 tty1 即可。

安装后按 **Ctrl+Alt+F2** 体验(首次需重新登录让 `video` 组生效)。换字体改 `~/.fbtermrc` 的 `font-names`(可装 Nerd Font 后填其名字)。Arch 的 fbterm 在 **AUR**,脚本会用 `paru`/`yay` 安装;没有 AUR 助手时会提示手动装。

### 中文(CJK)显示

**纯内核控制台无法显示中文** —— 它一次只能加载最多 ~512 个字形的点阵字体,而中文有几千个字;Terminus 更是完全不含中文字形,所以装了字体模块后中文会变方框。这是控制台的天生限制,不是 bug。

想在控制台看中文,用 **fbterm**:它渲染 TTF,能显示 CJK。fbterm 模块会询问是否安装中文字体(Debian: `fonts-wqy-microhei`;Arch: `noto-fonts-cjk`),选「是」后自动把 `~/.fbtermrc` 的 `font-names` 配成「拉丁字体 + 中文字体」,进 fbterm 即可正常显示中文。或者直接从宿主机 **SSH** 进来,终端模拟器原生支持中文。

## 还原

全程改动前都会备份到 `backups/<时间戳>/`(含 `manifest.tsv`)。还原:

```bash
sudo ./<distro>/uninstall.sh                 # 还原最近一次
sudo ./<distro>/uninstall.sh backups/<时间戳> # 还原指定一次
```

还原会:按 manifest 恢复被改文件(含 fbterm 自启片段所在的 profile)、删除 `tty-colors.service`、重建引导产物(Debian: grub + initramfs;Arch: grub + mkinitcpio)。**不会**自动卸载装过的包,避免误删。

## 结构(共享 core + 薄发行版层)

```
shared/
  common.sh            日志 / 备份+manifest / 幂等改配置 / 托管块(发行版无关)
  install-core.sh      入口主流程(菜单/调度/小结),两发行版共用
  uninstall-core.sh    还原主流程,两发行版共用
  modules/
    resolution.sh      GRUB 分辨率(两发行版一致)
    colors.sh          Gruvbox 配色(两发行版一致)
    tools.sh           选装工具(分类逐项勾选)+ 默认编辑器 + tmux/gpm + 命令速查
    fbterm.sh          fbterm 安装/配置/自启(两发行版一致,装包走 aur_install)
  assets/
    vtrgb/gruvbox          Gruvbox 调色板
    starship/starship.toml 提示符预设
    fbterm/fbtermrc        fbterm 配置(TTF 字体)
    tmux/tmux.conf         tmux 预设(鼠标 + 大回滚 + 16 色状态栏)
    editor/vimrc           vim 极简 TTY 配置    editor/init.vim  neovim 极简配置
debian/
  install.sh uninstall.sh  薄入口
  pkg.sh                   apt 层(pkg_install / BAT_BIN=batcat … + TOOL_PKG 工具映射)
  modules/{font,shell}.sh  Debian 特有(console-setup / apt 包名 / starship 官方脚本)
arch/
  install.sh uninstall.sh  薄入口
  pkg.sh                   pacman+AUR 层(pkg_install/aur_install … + TOOL_PKG/TOOL_AUR 映射)
  modules/{font,shell}.sh  Arch 特有(vconsole+setfont / pacman 包名 / starship 仓库包)
shell/
  CHEATSHEET.md            常用命令速查(工具模块装到用户目录,cheat 命令打开)
  sudo-nopasswd.sh         免密 sudo 脚本
```

**发行版解耦**:`shared/` 的 core 与通用模块只调用 `pkg_detect` / `pkg_install` / `aur_install` 和二进制名变量 `BAT_BIN`/`FD_BIN`,具体由各发行版 `pkg.sh` 实现,所以通用逻辑不重复。

## 自定义

- **配色**:改 `shared/assets/vtrgb/gruvbox`(3 行 = 红/绿/蓝,每行 16 个 0-255 值),重跑配色模块。
- **提示符**:改 `shared/assets/starship/starship.toml`。
- **fbterm 字体**:改 `shared/assets/fbterm/fbtermrc` 的 `font-names` / `font-size`,或直接改 `~/.fbtermrc`。
- **工具清单**:增删工具改各发行版 `pkg.sh` 的 `TOOL_PKG`(新增 key 时在 `shared/modules/tools.sh` 的分类数组里加一行 `"key|标签"`)。
- **tmux / 编辑器预设**:改 `shared/assets/tmux/tmux.conf`、`shared/assets/editor/{vimrc,init.vim}`,或直接改用户目录下对应文件。
- **命令速查**:改 `shell/CHEATSHEET.md`,重跑工具模块会重新装到用户目录。
