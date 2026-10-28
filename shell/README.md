# shell — 常用脚本

存放平时常用的独立 shell 脚本(自包含,不依赖本仓库其它部分)。

| 脚本 | 作用 |
|------|------|
| [sudo-nopasswd.sh](sudo-nopasswd.sh) | 让指定用户用 sudo 时免密:先写 `/etc/sudoers.d/` drop-in 并**清缓存真测**,被覆盖则**自动回退**追加到 `/etc/sudoers` 末尾;全程 `visudo` 校验,支持 `--undo` |

## sudo-nopasswd.sh

```bash
sudo ./sudo-nopasswd.sh            # 给当前用户开启免密
sudo ./sudo-nopasswd.sh -u alice   # 给指定用户开启
sudo ./sudo-nopasswd.sh --undo     # 关闭
./sudo-nopasswd.sh --dry-run       # 只看会做什么,不改系统
```

脚本会在装好 drop-in 后以目标用户身份、清掉凭据缓存**真正验证**一次 sudo 是否免密。如果 `/etc/sudoers` 里有匹配规则排在 `@includedir` 之后(会覆盖 drop-in),脚本会自动把规则追加到 `/etc/sudoers` 末尾(保证最后匹配生效);主 sudoers 改动前会备份到 `/var/backups/sudo-nopasswd/`。

⚠️ 免密 sudo 会降低安全性(拿到该账号即等于 root),只建议在自己的单人机器/虚拟机上用。
