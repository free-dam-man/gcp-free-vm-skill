# 来源与致谢（SOURCES）

本仓库吸收了公开文档与成熟开源实践，**不复制其专有业务逻辑**；脚本为本仓库原创。许可证以各上游为准。

## 官方文档（约束来源）

| 来源 | 吸收内容 |
|---|---|
| [Google Cloud Free Tier / Free Trial](https://docs.cloud.google.com/free/docs/free-cloud-features) | Always Free：1×`e2-micro`（`us-west1`/`us-central1`/`us-east1`）、30 GB-months `pd-standard`、北美出站 1 GB/月（不含中国/澳大利亚）；需结算账号；预算告警不自动停机 |
| [Compute Engine free getting started](https://cloud.google.com/free/docs/compute-getting-started) | 免费层按「当月小时数」计而非按实例个数；外网 IP 在免费层文档中说明不另收费（仍以账单为准）；GPU/TPU 永不免费 |
| [Cloud Billing budgets](https://docs.cloud.google.com/billing/docs/how-to/budgets) | 预算告警只通知、不自动封顶；可用 Pub/Sub 自建停机自动化（本仓库不默认开启） |

## 开源脚本 / 仓库（实践）

| 来源 | 许可 | 吸收内容 |
|---|---|---|
| [mandarl/pennyclaw](https://github.com/mandarl/pennyclaw) | MIT | Cloud Shell 一键、起飞前检查（已有 e2-micro / 区域 / STANDARD 网络层 / 磁盘类型与大小）、创建前成本意图说明、自动 swap、拆除命令思路 |
| [dtinth GoogleCloudFreeTier 笔记](https://github.com/dtinth/dt.in.th/blob/gh-pages/GoogleCloudFreeTier.html) | 公开笔记 | 极简 `gcloud compute instances create … --network-tier=STANDARD` + `debian-12` 命令骨架 |
| [stainlu/openclaw-managed-agents `deploy-gcp-compute.sh`](https://github.com/stainlu/openclaw-managed-agents) | 见上游 | 幂等创建、环境变量覆盖、`e2-micro`+30GB 免费区间提示 |
| [feedreader GCE Always Free commit](https://github.com/newscientist101/feedreader/commit/6ae1ba9df835d982483ac045bd9e7b8c6efa16d2) | 见上游 | `pd-standard` 显式写入、cloud-init/startup 加 swap、社区对 IPv4 费用的警惕表述 |
| [gist FreesoSaiFared gcloud free tier](https://gist.github.com/FreesoSaiFared/5c1861f71e5421eca3a14b6af9bc0740) | 公开 gist | 交互菜单式创建的参考（本仓库改为无交互默认向导） |

## 社区踩坑（中文讨论，事实交叉核对官方后吸收）

| 来源 | 吸收内容 |
|---|---|
| V2EX「薅秃谷歌云 / WebDAV」等帖 | 必须选免费区域；关快照；网络层改 STANDARD；出站流量小心；入站免费 |
| Linux.do GCP 扣费 / 一键脚本讨论 | 孤儿盘、快照、超额盘导致「免费机仍扣几毛」；CDN/特定目的地出站账单风险；预算与巡检习惯 |
| 家宽出口实测（本组织另一仓库） | 容器继承 `169.254.169.254` 元数据 DNS → 需 `--dns 8.8.8.8`；VPC 防火墙要单独放行；GCP guest agent / OS Login 可能改写 SSH 公钥 |

## 下游交接

搭好小鸡后，家宽出口请交给（交锁头方式）：

https://github.com/free-dam-man/homeline-residential-exit-skill
