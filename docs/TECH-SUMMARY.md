# 技术总结：GCP Always Free 小鸡（引导式）

## 目标状态

用户本人**只做** Google 登录 + 绑卡验证；其余由 agent 驾驶已登录的控制台 / Cloud Shell 完成，最终得到：

1. 一台符合 Always Free 的 `e2-micro`（Debian 12，≤30GB `pd-standard`，STANDARD 网络层，免费三区之一）；  
2. agent 已能 SSH（Cloud Shell / 浏览器 SSH / 交锁头）；  
3. 已加 swap、已设或已提醒预算告警与出站风险；  
4. 已交接 [homeline-residential-exit-skill](https://github.com/free-dam-man/homeline-residential-exit-skill) 并继续搭家宽（默认不反对就干）。

本仓库 **绝不** 用 agent 自己的 GCP 账号创建资源；只在用户登录后的会话里操作。用户自粘脚本仅为备路径。

## 免费边界（以官方表为准）

| 项 | 值 |
|---|---|
| VM | 非抢占式 `e2-micro`，按当月小时数合计免费 |
| 区域 | `us-west1` / `us-central1` / `us-east1` |
| 盘 | 30 GB-months **标准**持久盘 |
| 出站 | 北美出发 1 GB/月，**不含**中国与澳大利亚 |
| 结算 | 必须有 Billing 账号 |

脚本硬拒绝：非免费区域、非 e2-micro、非 pd-standard、盘>30G、PREMIUM 网络层。

## 主路径：Agent 驾驶 Cloud Shell

1. Agent 打开控制台；用户只完成 Google 登录 + 绑卡；  
2. Agent 打开 Cloud Shell，写入并执行 `templates/create-free-vm.sh`（先 `DRY_RUN=1`）；  
3. 脚本：开 Compute API → 幂等防火墙 → 创建/复用实例 → startup 加 swap → 打印外网 IP；  
4. Agent 跑 `check-free-tier.sh`，并在控制台建预算告警；  
5. Agent 用 `gcloud compute ssh` / 浏览器 SSH / metadata 完成交锁头 → 家宽 skill。

备路径：远程浏览器不可用时，才让用户自己在 Cloud Shell 粘贴脚本。

## 设计选择

| 选择 | 原因 |
|---|---|
| 默认 `us-west1-a` | 免费三区之一；可用 `ZONE`/`REGION` 覆盖 |
| Debian 12 | 稳、与家宽 skill 实测一致 |
| STANDARD 网络层 | 避免 Premium 出站溢价（pennyclaw / dtinth 实践） |
| 幂等 | 重跑不删机、不重建；已有同名则复用 |
| 已有其他 e2-micro 则中止 | 防止分食免费小时 |
| startup-script 加 swap | e2-micro ~1GB RAM，防 OOM（社区常用 512MB–2GB） |
| 不默认封 CDN IP | 误伤大；改为强提醒 + 预算告警 |
| `DRY_RUN=1` | agent 可先展示计划 |

## 与家宽 skill 的衔接

- 本仓库只负责「有一台干净、免费边界内的 VPS」。  
- SSH 用家宽仓库的 **交锁头**（agent 生成钥匙并自己写入小鸡；主路径不要求用户粘公钥）。  
- 容器 DNS、VPC 放行业务端口、出口实测：全部在家宽 skill 完成。

## 诚实声明

- 免费层条款 Google 可变更（官方保留提前通知权）。  
- 「\$0」只在严格遵守边界且出站克制时成立；账单是唯一真相。  
- 本仓库不创建真实 GCP 资源做 CI；脚本用 `bash -n` / shellcheck 做静态校验。
