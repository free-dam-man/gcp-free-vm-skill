# 常见坑（GCP 小鸡 / Always Free）

按出现频率排序。本 skill 的脚本会挡住一部分，挡不住的必须在交付时口头讲清。

## 1. 登错 Google 账号 / 项目没有 Compute 权限

**现象**：Cloud Shell 或控制台提示没有权限、看不到项目、API 开不了。  
**原因**：浏览器登的是另一个 Google 账号，或项目没挂结算。  
**处理**：让用户在账号头像处切换到「绑了卡 / 开了试用」的那个账号；`gcloud config get-value account` 与 `gcloud projects list` 对得上再继续。

## 2. 没有结算账号（Billing）

**现象**：创建 VM 失败，或提示 billing。  
**事实**：Always Free **也需要**有效的 Cloud Billing 账号（新用户走 Free Trial 绑卡验证）。  
**处理**：https://cloud.google.com/free → 开始免费试用 → 绑卡（官方写验证用途；试用期内不扣费，超出免费层由 \$300 赠金抵）。赠金/90 天结束前建议「Activate」升到 Paid，否则资源可能被停。

## 3. 区域不是免费三区

**现象**：机器跑着但月底有 Compute 费用。  
**必须**：`us-west1` / `us-central1` / `us-east1` 之一。亚洲、欧洲区的 e2-micro **不在** Compute Always Free 内。

## 4. 磁盘类型 / 大小 / 快照

| 会扣费 | 免费意图 |
|---|---|
| `pd-balanced` / `pd-ssd` | 只用 `pd-standard` |
| 盘 > 30GB，或多个盘合计超过 30GB-月 | 单盘 ≤30GB，删掉孤儿盘 |
| 自动快照、手工快照、自定义镜像长期存 | 创建时关掉快照计划；定期 `gcloud compute snapshots list` |

社区多次出现「以为免费却每月 \$0.4」——账单 SKU 常是 Storage PD Capacity（多出来的盘或超额）。

## 5. 网络层 PREMIUM

控制台默认有时是 Premium。必须 **Standard**（脚本：`--network-tier=STANDARD`）。Premium 出站更贵。

## 6. 出站流量（最大雷）

官方 Always Free Compute 出站：从北美到「除中国、澳大利亚外」目的地 **1 GB/月**。  
到中国的出站 **不在** 该免费额度内。入站免费。  
社区还报告：访问部分商业 CDN 网段可能导致异常高的出站账单——本仓库**不**默认装「封 CDN」防火墙（易误伤），但必须：

1. 设 \$1 左右的预算告警（见 `templates/budget-alert.example.sh`）；  
2. 每月看 Billing；  
3. 不要把这台机当大流量下载站或公开中转。

预算告警 **只会发邮件，不会自动关机**。

## 7. 静态 IP / 停机占 IP

运行中的临时外网 IP：免费层文档写明不另收 IP 费（仍以你的账单为准）。  
**预留静态 IP 且未挂到运行中的实例**可能计费。不用就释放。

## 8. VPC 防火墙 vs 系统防火墙

GCP 必须在 **VPC 防火墙** 放行端口，光在 VM 里开 `ufw` 不够。  
脚本默认加 `tcp:22`（tag `gcp-free-vm`）以及常见的 http/https tag 规则（若不存在）。  
后续家宽/Xray 端口：只 **新增** 规则，不删别人的。

## 9. 元数据 DNS `169.254.169.254`

GCP VM 的 `/etc/resolv.conf` 常指向元数据 DNS。Docker 容器继承后，**容器内解析公网域名会失败或怪异**。  
跑容器时加：`--dns 8.8.8.8`（或同等公共 DNS）。家宽 skill 已默认如此。

## 10. SSH 公钥被 guest agent / OS Login 改掉

**现象**：昨天还能连，今天 `Permission denied (publickey)`。  
**原因**：Compute guest agent 同步 metadata 里的 `ssh-keys`，或开了 OS Login。  
**处理**：

- 交锁头后若断连：重新走一次「加公钥」；或  
- `gcloud compute instances add-metadata … --metadata=ssh-keys='user:ssh-ed25519 AAAA… comment'`；或  
- 用 Cloud Shell / 浏览器 SSH 进去修 `authorized_keys`。  
本仓库默认 `enable-oslogin=FALSE`，降低踩坑；若你刻意开 OS Login，改用 OS Login 流程，不要混用手工 authorized_keys。

## 11. 内存只有 ~1GB

e2-micro 内存紧。脚本用 startup-script 加约 1GB swap（可 `SWAP_MB` / `SKIP_SWAP=1`）。  
仍避免在这台机上跑重型面板或多个大容器。

## 12. 同时开多台 e2-micro

免费额度是「当月总小时数 ≈ 一台不停机」，多台会分食额度并可能计费。脚本发现已有 e2-micro 会拒绝再开。

## 13. Free Trial 到期未 Activate

试用账号到期且未升级 Paid：资源会停、可能进 30 天宽限期后删除。Always Free 需要有效结算账号继续挂着。

## 14. IPv6

免费层主路径是双栈视镜像/子网而定；许多教程只开 IPv4。本脚本不强制 IPv6。若你只用 IPv6 规避某种 IPv4 计费传闻——先查**当前**官方 Networking 定价与你的账单，再决定；以官方与账单为准。
