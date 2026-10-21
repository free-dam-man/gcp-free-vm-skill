---
name: gcp-free-vm
description: "Use when someone wants a GCP Always Free e2-micro VM (GCP小鸡): agent drives Cloud Shell after the user only logs in and binds a card; free-tier limits (us-west1/us-central1/us-east1, 30GB pd-standard, STANDARD network, Debian 12), budget/egress warnings, then hand off to homeline-residential-exit-skill. Free-only; never create paid shapes."
---

# GCP Always Free 小鸡（引导式 · Agent 代操作）

在 Google Cloud **Always Free** 边界内开出一台 `e2-micro`，再自动交接家宽出口 skill。

## 分工（写死）

| 谁 | 只做什么 |
|---|---|
| **用户** | ① Google 登录 ② 绑卡（Free Trial / 结算验证）③ 对默认方案不反对就说「继续」（或改编号） |
| **Agent（你）** | 其余全部：开 Cloud Shell、跑脚本、防火墙、swap、免费层检查、预算告警、交锁头、接着搭家宽 |

不索要密码；登录 / 绑卡 / 2FA / 验证码整段交还用户屏幕（或 Secure Form）。你不看、不问、不存卡号与密码。

**铁律：**

- 只用免费边界；拒绝付费机型 / 非免费区 / SSD / Premium。
- 不把邮箱、项目 ID、IP、密钥写进仓库或任何公开处。
- 资源只在**用户已登录的控制台 / Cloud Shell**里由你操作创建；不得用你自己的 GCP 账号冒充。
- 无证据不声称「已经 \$0」——以用户账单为准。

## 0. 开场：一份默认方案（不反对就干）

发给用户后立刻准备浏览器；用户回「继续」或不反对 → 进入第 1 节。

```text
按 Always Free 默认开小鸡，你只负责登录和绑卡，其余我来。不反对就继续：
1) 区域：us-west1（可用区 a）
2) 机型：e2-micro + 30GB 标准盘 + Debian 12 + 标准网络层
3) 名字：free-e2micro
4) 防火墙 / swap / 免费层检查：我在 Cloud Shell 做
5) 预算告警：我帮你在控制台建约 $1/月（只通知，不自动停机）
6) 开好后交锁头并按家宽仓库接着搭（默认 KR+US）
回数字改某项；回「继续」开工。
```

硬停：拒绝绑结算、或坚持亚洲区/付费机型 → 说明 Always Free 做不到，停止。

## 1. 主路径 — 你驾驶浏览器 + Cloud Shell（默认）

1. **打开** https://console.cloud.google.com/ （或 https://cloud.google.com/free 若尚未开通）。  
2. **交还屏幕**：请用户完成 Google 登录 + 绑卡 / 试用验证。登错账号让用户右上角切换到「要绑卡的那个」。  
3. 用户说已搞定（控制台已进、项目可选）后，**你**点右上角 Cloud Shell（`>_`），等到提示符。  
4. 确认项目：`gcloud config get-value project`；若空，用控制台左上角当前项目 `gcloud config set project …`（项目 ID 只显示给用户核对，不写入公开文件）。  
5. 把本仓库 `templates/create-free-vm.sh` 写入 Cloud Shell（短行 heredoc，或 `curl -fsSL` 仓库 raw URL）。粘贴易乱码：分段、`wc -l` / `sha256sum` 核对后再跑。  
6. 先：`DRY_RUN=1 bash create-free-vm.sh` → 把计划用一句话发给用户；不反对则正式：`bash create-free-vm.sh`。  
7. 跑：`bash check-free-tier.sh`（同目录或再写入）。有 FAIL 先修。  
8. **你**在控制台 Billing → Budgets & alerts 建约 \$1/月告警（或跑 `budget-alert.example.sh` 若 gcloud 支持）；说明告警不会自动停机。  
9. 用 Cloud Shell：`gcloud compute ssh <NAME> --zone=<ZONE>`（或实例页浏览器 SSH）确认能进；必要时等 startup-script 加完 swap（`swapon --show`）。  
10. **直接进入第 4 节交接家宽**（不要把「请用户自己粘脚本」当成主流程）。

网页终端规范：长命令先 `cat > file <<'EOF'`；命令失败读报错，禁止跳过免费层守卫。

## 2. 备路径 — 用户自己粘贴脚本（仅当你开不了浏览器时）

仅在远程浏览器不可用、或用户明确要求时使用：

1. 请用户自己打开控制台并点开 Cloud Shell。  
2. 给用户一条：`curl -fsSL <create-free-vm.sh 的 raw URL> -o create-free-vm.sh && DRY_RUN=1 bash create-free-vm.sh`，确认后再去掉 `DRY_RUN=1` 重跑。  
3. 用户把终端输出（可打码项目 ID）回你；你继续指导检查与家宽交接。  

主路径能走时**不要**把粘贴甩给用户。

## 3. 验收清单（你必须做完再交接）

- [ ] `machineType=e2-micro`  
- [ ] zone ∈ `us-west1|us-central1|us-east1`  
- [ ] 盘 `pd-standard` 且 ≤30GB  
- [ ] 网络层 `STANDARD`  
- [ ] `check-free-tier.sh` 无未解释的 FAIL  
- [ ] 已设或已明确提醒预算告警；已说明中国出站不在免费额度  
- [ ] 你已能从 Cloud Shell / 浏览器 SSH 进入该 VM  

## 4. 交接家宽（交锁头 · 仍由你操作）

遵循：https://github.com/free-dam-man/homeline-residential-exit-skill

在**你已能进入小鸡**的前提下：

1. 在你自己的机器生成 `homeline-agent` ed25519（私钥永不外传）。  
2. **你**把公钥写入小鸡（任选，优先不打扰用户）：  
   - Cloud Shell：`gcloud compute ssh … --command '…authorized_keys…'`；或  
   - `gcloud compute instances add-metadata … --metadata=ssh-keys='user:ssh-ed25519 AAAA… homeline-agent'`；或  
   - 浏览器 SSH 里你粘贴交锁头那一行。  
3. 用该私钥从你侧 SSH 连上后，跑家宽 `scan-vps.sh`，给默认方案（KR+US 等），不反对就搭。  
4. 业务端口：你在 VPC 防火墙**只加不删**；容器带 `--dns 8.8.8.8`。  
5. 交付时附撤销：`sed -i '/homeline-agent$/d' ~/.ssh/authorized_keys`。  

用户不会 SSH、也不用粘公钥——除非备路径且你完全无法操作其浏览器。

## 5. 拆除（仅用户要求时）

你在 Cloud Shell 执行（先复述将删的名字/区域，用户确认后）：

```bash
gcloud compute instances delete free-e2micro --zone=us-west1-a
gcloud compute disks list
gcloud compute snapshots list
# 释放未使用静态 IP、删孤儿盘/快照
```

## 6. 禁止事项

- 创建非 `e2-micro`、GPU、Windows、非免费区域  
- `pd-ssd` / 自动快照「图方便」  
- 索要或落盘用户卡号、密码、邮箱、项目编号、IP  
- 声称「绝对不扣费」  
- 主路径还活着时让用户自己粘长脚本凑数  

## 参考

`docs/TECH-SUMMARY.md` · `docs/PITFALLS.md` · `docs/SOURCES.md`
