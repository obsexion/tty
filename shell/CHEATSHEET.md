# 常用 Shell 命令速查

[English](CHEATSHEET.en.md) | 中文

面向纯 TTY / 控制台的日常操作。装了「工具」模块后,可在 shell 里直接输入 `cheat` 打开本表。
现代工具(`rg`/`fd`/`bat`/`fzf`/`eza`/`z`)来自 Shell 模块;`tldr <命令>` 可随时查某条命令的用法示例。

## TTY 切换与技巧

| 操作 | 说明 |
|------|------|
| `Ctrl+Alt+F1`~`F6` | 在 6 个虚拟控制台之间切换(F1 保持纯控制台做兜底) |
| `Shift+PgUp` / `PgDn` | 控制台回滚翻页(缓冲有限;大量回滚用 tmux) |
| 鼠标选区 / 中键粘贴 | 需装 `gpm`(工具模块的 TTY 增强);滚轮也可翻页 |
| `setterm --blank 15` | 15 分钟无操作后息屏;`--blank 0` 关闭息屏 |
| `clear` / `Ctrl+L` | 清屏 |
| `reset` | 终端显示错乱时重置 |

## 文件与目录

```sh
ls -lah              # 列出(含隐藏、人类可读大小);装了 eza 可用 ll
cd -                 # 回到上一个目录
z 关键字             # zoxide:跳到最近常去的目录(需 Shell 模块)
cp -r 源 目标        # 递归复制       mv 源 目标   # 移动/改名
rm -rf 目录          # 递归强删(危险,想清楚)
mkdir -p a/b/c       # 递归建目录
ln -s 目标 链接名    # 创建软链接
du -sh *             # 当前目录各项体积;ncdu 可交互浏览
df -h                # 磁盘剩余空间;duf 更好看
find . -name '*.log' # 按名查找;fd '\.log$' 更快更简单
stat 文件            # 查看文件元信息
```

## 文本 / 查看 / 搜索

```sh
cat 文件             # 查看;bat 文件 带语法高亮和行号
less 文件            # 分页查看(q 退出,/ 搜索,g/G 首尾)
head -n 20 文件      # 前 20 行;tail -n 20 文件 后 20 行
tail -f 日志         # 实时跟踪日志
grep -rn 'xxx' .     # 递归搜索;rg 'xxx' 更快(ripgrep)
rg -i 'xxx' --type py# 忽略大小写、限定类型
sed -n '10,20p' 文件 # 打印 10~20 行
awk '{print $1}' 文件# 取第一列
sort 文件 | uniq -c  # 排序后统计重复行
wc -l 文件           # 统计行数
fzf                  # 模糊查找;Ctrl+R 模糊搜命令历史(需 Shell 模块)
```

## 进程 / 资源

```sh
htop / btop          # 交互式进程 / 资源监控(工具模块)
ps aux | rg 名字     # 查进程;procs 名字 更现代
kill -9 PID          # 强制结束;pkill 名字 按名结束
jobs / fg / bg       # 作业控制;Ctrl+Z 挂起,& 后台运行
nohup 命令 &         # 退出登录也继续跑
free -h              # 内存占用       uptime   # 负载 / 运行时长
watch -n1 '命令'     # 每秒重复执行并刷新
```

## 网络(工具模块的网络工具)

```sh
ip a                 # 查看网卡 / IP(替代 ifconfig)
ip r                 # 路由表
ss -tulpn            # 监听端口 / 连接(替代 netstat)
ping 主机            # 连通性
dig 域名 / nslookup  # DNS 查询
mtr 主机             # 路由 + 丢包实时诊断
curl -I 网址         # 只看响应头;curl -O 网址 下载
wget 网址            # 下载
nmap -p- 主机        # 扫全端口(仅限你有权扫描的目标)
tcpdump -i any port 80  # 抓包
scp 文件 user@主机:路径 # 复制到远端;rsync -avP 源 目标 增量同步
ssh user@主机        # 登录远端(真彩色终端体验最佳)
```

## systemd / 服务

```sh
systemctl status 服务     # 查看状态
systemctl start/stop/restart 服务
systemctl enable --now 服务   # 开机自启 + 立即启动
systemctl list-units --failed # 查看失败的单元
journalctl -u 服务 -e     # 该服务日志(末尾);-f 实时跟踪
journalctl -b             # 本次开机的全部日志
systemctl reboot / poweroff
```

## tmux(单控制台也能分屏 / 多会话)

```sh
tmux                 # 新建会话;tmux a 重连最近会话
前缀键 Ctrl+b 再按:
  |  竖分屏   -  横分屏   (本仓库配置;默认是 % 和 ")
  方向键      在 pane 间移动
  c  新窗口   n/p 切换窗口   数字 跳到某窗口
  d  脱离会话(程序仍在后台跑)
  [  进入回滚/复制模式(q 退出;配置为 vi 键位)
  r  重新加载 ~/.tmux.conf
鼠标已开启:可直接点选 pane、拖拽边界、滚轮翻页。
```

## git

```sh
git status           # 当前状态       git diff   # 未暂存改动
git add -A           # 暂存全部        git commit -m "信息"
git log --oneline --graph --all   # 简洁提交图
git switch -c 分支    # 新建并切换;git switch 分支 切换
git pull / git push
git stash / git stash pop         # 暂存 / 恢复工作区
git restore 文件      # 丢弃对某文件的改动
```

## Vim / Neovim 极速入门

```
i 插入   Esc 回到普通模式   :w 保存   :q 退出   :wq 保存退出   :q! 不保存退出
dd 删行  yy 复制行  p 粘贴   u 撤销   Ctrl+r 重做
/关键字 搜索(n 下一个)    :%s/旧/新/g 全局替换
gg 到文件头   G 到文件尾    :行号 跳到某行
```

---
提示:记不住某条命令的参数时,`tldr 命令名` 给你最常用的几个用法示例(离线)。
