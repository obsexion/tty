# tty — Debian 控制台美化工具箱

让无桌面 Debian 的内核控制台(Ctrl+Alt+F1~F6)从"黑底白字、又大又糊"变得清爽现代。
在 Debian 里 `git clone` 下来就能跑,交互菜单勾选要做哪些。

```bash
git clone <this-repo> tty
cd tty
sudo ./install.sh
```

## 它能做什么

| 模块 | 作用 | 生效时机 |
|------|------|----------|
| **分辨率** | 改 GRUB,把 framebuffer 调到 1080p 等,字不再又大又糊 | 重启后 |
| **字体** | `console-setup` + **Terminus**,清晰点阵字体,可选字号 | 立即 + 开机 |
| **配色** | 把控制台 16 色重定义为 **Gruvbox**(暖色护眼) | 立即 + 开机 |
| **Shell** | zsh/fish + **starship** 提示符 + `ripgrep`/`bat`/`fzf`/`zoxide`/`eza` 等现代工具 | 重新登录后 |
| **kmscon**(高级) | 从源码编译 kmscon,用 **TTF 字体 + 更多颜色** 的控制台接管 **tty2** | 切到 tty2 / 重启 |

## 用法

```bash
sudo ./install.sh          # 交互菜单(推荐)
sudo ./install.sh --all    # 跑全部(kmscon 仍二次确认)
sudo ./install.sh --yes    # 非交互,全取默认值
./install.sh --dry-run     # 只打印将做的事、不改系统(可非 root,先看看)
```

菜单里多选用空格/逗号分隔序号,例如 `1 2 3`,或输入 `all`。

## 重要说明

- **内核控制台的硬天花板**:只有 16 色、点阵字体、无抗锯齿。分辨率/字体/配色三个模块已经把原生控制台做到极致。
- **starship 和现代 CLI 工具在纯控制台只有 16 色**,会降级显示。想要真彩色、漂亮 TTF 字体、连字,最划算的是**在 Debian 里开 SSH,从宿主机的现代终端(WezTerm / Kitty / Windows Terminal)连进来**。
- **kmscon 是突破天花板的办法**,但它不在 Debian 仓库、需源码编译(拉一堆开发依赖、耗时几分钟)。

### kmscon 的安全设计 ⚠️

替换控制台的 getty 一旦配错有被锁在外面的风险,所以本工具:

- **只接管 tty2**,`tty1` 永远保持原生 getty。
- kmscon 启动失败会**自动回滚** tty2 的 getty。
- 出任何问题,按 **Ctrl+Alt+F1** 切回 tty1 就能正常登录。

安装后按 **Ctrl+Alt+F2** 看 kmscon 效果(首次需重新登录/重启让 `video`、`input` 组权限生效)。想换字体,编辑 `/etc/kmscon/kmscon.conf` 里的 `font-name`(可装 Nerd Font 后填其名字)。

## 还原

全程改动前都会备份到 `backups/<时间戳>/`(含 `manifest.tsv`)。还原:

```bash
sudo ./uninstall.sh                 # 还原最近一次
sudo ./uninstall.sh backups/<时间戳> # 还原指定一次
```

还原会:按 manifest 恢复被改文件、删除 `tty-colors.service`、把 tty2 还给 getty、重建 grub.cfg 与 initramfs。**不会**自动卸载 apt 包(避免误删),只提示包名。

## 自定义

- **配色**:改 `assets/vtrgb/gruvbox`(setvtrgb 格式:3 行 = 红/绿/蓝,每行 16 个 0-255 值),重跑配色模块。
- **提示符**:改 `assets/starship/starship.toml`。
- **kmscon**:改 `assets/kmscon/kmscon.conf`(字体、字号、palette)。

## 目录结构

```
install.sh / uninstall.sh   入口
lib/common.sh               日志 / 备份+manifest / apt / 幂等工具(其余模块都依赖)
lib/{resolution,font,colors,shell,kmscon}.sh   各模块
assets/vtrgb/gruvbox        Gruvbox 调色板
assets/starship/starship.toml   提示符预设
assets/kmscon/kmscon.conf   kmscon 配置
```

## 兼容性

面向 **Debian**(stable/testing)。`eza` 等个别工具在 Debian 12 stable 仓库可能缺失,脚本会跳过并提示,不影响其余功能。
