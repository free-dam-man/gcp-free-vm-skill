# 🐣 GCP 小鸡 Skill：你只登录绑卡，AI 把永久免费 e2-micro 开好并接着搭家宽

> 丢给 Muse / Bot：你只负责 **Google 登录 + 绑卡验证**；开 Cloud Shell、跑脚本、防火墙、swap、检查、交锁头、搭家宽出口——全是 AI 在浏览器里做。向导默认值，不反对就继续。

## 这是什么

给 AI 用的部署说明书（Skill）。

```text
你：登录 GCP + 绑卡（试用/结算验证）
AI：驾驶控制台 → Cloud Shell → 免费层脚本开 e2-micro
  → 检查 / 预算告警 → 交锁头 → 家宽出口 skill
```

粘贴脚本给用户自己跑 = **备路径**（仅当 AI 开不了远程浏览器时）。

## 免费边界（默认写死）

| 项 | 默认 |
|---|---|
| 机型 | `e2-micro`（仅此） |
| 区域 | `us-west1`（或 `us-central1` / `us-east1`） |
| 盘 | 30GB `pd-standard` |
| 网络层 | **STANDARD** |
| 系统 | Debian 12 |
| 出站 | 官方额度很小且**不含中国**——必须设预算告警，别当大流量站 |

越界参数脚本会拒绝。详见 [`docs/PITFALLS.md`](docs/PITFALLS.md)、[`docs/TECH-SUMMARY.md`](docs/TECH-SUMMARY.md)。

## 怎么用

1. 把本仓库交给你的 AI。  
2. 复制下面口令发给它。  
3. 它让你登录/绑卡时，在它的远程浏览器里自己完成；其余点「继续」即可。  
4. 家宽部分自动按  
   https://github.com/free-dam-man/homeline-residential-exit-skill  
   交接（交锁头，不索取密码）。

### 通用启动口令（复制整段发给 AI）

```
按这个仓库的 SKILL.md，帮我在 GCP 上开一台永久免费小鸡，开好后接着搭家宽出口：
https://github.com/free-dam-man/gcp-free-vm-skill
只用免费配置，不要问我密码。我只负责登录和绑卡，其余你来；每步给默认值，我不反对就继续。
```

## 仓库结构

| 路径 | 用途 |
|---|---|
| `SKILL.md` | AI 必读（主路径=代操作浏览器） |
| `templates/create-free-vm.sh` | 幂等创建（`DRY_RUN=1` 可空跑） |
| `templates/check-free-tier.sh` | 只读核对免费层 |
| `templates/budget-alert.example.sh` | 预算告警示例 |
| `docs/` | 踩坑 / 技术摘要 / 来源致谢 |

## 致谢（节选）

官方 Free Tier 文档 · [pennyclaw](https://github.com/mandarl/pennyclaw)（MIT）起飞前检查与 STANDARD/swap 实践 · [dtinth Free Tier 笔记](https://github.com/dtinth/dt.in.th/blob/gh-pages/GoogleCloudFreeTier.html) · 社区关于快照/出站账单的讨论。完整见 [`docs/SOURCES.md`](docs/SOURCES.md)。

## 免责声明

仅供学习与个人实验。遵守 Google 条款与当地法律。Always Free 以官方文档与账单为准；绑卡与费用风险自负。

## License

[MIT](LICENSE)
