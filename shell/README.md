# shell — 常用脚本

存放平时常用的独立 shell 脚本(自包含,不依赖本仓库其它部分)。

| 脚本 | 作用 |
|------|------|
| [sudo-nopasswd.sh](sudo-nopasswd.sh) | 让指定用户用 sudo 时免密(写 `/etc/sudoers.d/` drop-in,写前 `visudo -c` 校验,支持 `--undo`) |

## sudo-nopasswd.sh

```bash
sudo ./sudo-nopasswd.sh            # 给当前用户开启免密
sudo ./sudo-nopasswd.sh -u alice   # 给指定用户开启
sudo ./sudo-nopasswd.sh --undo     # 关闭
./sudo-nopasswd.sh --dry-run       # 只看会做什么,不改系统
```

⚠️ 免密 sudo 会降低安全性(拿到该账号即等于 root),只建议在自己的单人机器/虚拟机上用。
