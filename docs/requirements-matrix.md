# 正式要求对照矩阵（Phase 2.5 / 2.6）

依据：仓库根目录 `ClinicFlow-Capstone-Brief.pdf`，25 页，2026-10-13 版本；2026-11-20 核对。PDF 为默认验收目标，未找到老师批准的替代方案或此前审查文档。这里的“已有”仅表示源码存在，不表示 AWS 已验收。旧 AC1–AC9 不作为依据。

起点：远程 main `f26b97e` 已包含 Phase 2 `5360e55`；新分支 `feature/phase-2-5-requirements`。未跟踪 PDF 保留，忽略的本地 .env/tfvars 未读取值或修改。仓库未找到 AGENTS.md。保留 terraform/ 而非移动为 infra/，仓库名也与第5节示例不同，未取得正式豁免。

| 要求 | 当前实现 | 差距 | 修改方案 | 验证方式 |
|---|---|---|---|---|
| **NFR-1** 仅 Web ALB 公网可达 | 私有 task、内部 ALB、隔离 Data | 尚无云上可达性证据 | 保留网络隔离 | 云上从公网探测 API/DB |
| **NFR-2** 相邻层通过 SG 引用通信 | 五层引用规则、DB 无 egress | 缺云上证据 | 保留 | SG 描述和连接测试 |
| **NFR-3** 无明文 secret 入 Git/tfvars/image/task environment | 按用户批准，API ECS secrets 引用 RDS 主凭据；主密码 RDS 管理 | 已移除 AWS task environment 的 DB_USER；未扫描全历史 | 认证代码已切换，待云验；不打印本地 .env/tfvars | 全历史 gitleaks；describe-task-definition |
| **NFR-4** 环境 CMK；ECR/state 共享 CMK；DB TLS | 环境 data/log 两 key；ECR/audit 独立 key；state SSE-S3 | key 数量/共享/alias 不符；ALB SSE-KMS 无法支持 | key 整合及 state 改密钥待迁移确认；ALB SSE-S3 例外 | key/桶/日志配置及 TLS 连接 |
| **NFR-5** 角色最小权限 | execution/task/deploy 分离、Web 无权限 | API execution role 只读指定主 secret；无模拟证据 | 已按获批 secret ARN 收敛 | simulate-principal-policy |
| **NFR-6** Prod 两 task/服务跨 AZ，Aurora reader | 根输入约束、双 AZ 配置 | 尚无运行分布证据 | 明确 minimum_task_count 输入 | describe-tasks/DB 实例 AZ |
| **NFR-7** Prod 7 天 PITR、删除保护、恢复演练 | 备份/删除保护已有；现改显式输入 | 未做恢复演练 | 本阶段不创建恢复资源 | Phase 3 记录恢复时间/清理 |
| **NFR-8** make up/down 可重建/拆除 | Terraform 根目录已有 | 仅本地/静态检查 Makefile，无完整云操作脚本 | 后续阶段 | 空 state 重建计时 |
| **NFR-9** 必需标签、Prod 人工审批 | 补 CostCentre、ManagedBy=terraform | 未云上查标签；无 GitHub prod gate | 标签修复；审批 Phase 3 | Tagging API/Environment 截图 |
| **NFR-10** CloudWatch/SNS 告警 | 日志/SNS/多个告警/dashboard 已有 | 阈值和 widgets 不完全匹配 CF-901/902 | 列出差距，后续运维阶段 | 触发邮件及 dashboard |
| **NFR-11** 泄漏/镜像高危/IaC 严重问题阻断合并 | Phase2.6新增本地严格镜像阻断入口，最终两镜像HIGH/CRITICAL为0 | 完整CI合并门、secret/IaC扫描与分支保护仍未实现，不能标整个NFR通过 | 镜像阻断已本地复验；流水线留Phase3 | phase-2.6-validation.md及final扫描JSON；后续坏PR验证 |
| **CF-101** 幂等 bootstrap.sh、指定 bucket、TLS、锁 | state Terraform + init-backend.sh，S3 lockfile | 无 bootstrap.sh；bucket_prefix 而非精确名 | 避免改名重建；脚本后续实现 | 两次 bootstrap/后端锁 |
| **CF-102** OIDC 三 deploy+PR readonly、证据 | OIDC 和分环境 deploy 已有 | 角色名/创建位置不符；无 PR readonly/完整 IaC deploy 权限 | Phase 3，不直接搬 state | 跨环境拒绝/无 access key 证据 |
| **CF-103** 统一标签/命名/tag-check | 补必需 default_tags | 部分 SG/角色/仓库名称差异；tag-check 缺失 | 已有资源改名待迁移；后续脚本 | Tagging API |
| **CF-104** 每环境单 key alias/clinicflow-<env>，7/7/30 天；共享 key | data/log/audit/ecr 多 key；新增正式环境/shared alias 和可配置等待期 | alias 已补；key 拓扑整合待迁移；账户委托 kms:* 与题面字面冲突 | 迁移方案见 phase-2.5-review；不替换加密 key | key policy/alias/rotation/等待期 |
| **CF-201** 精确 CIDR、nat_gateway_count=1/1/2、模块 README/net-check | 8 子网、NAT、无 Data 默认路由 | root 旧偏移默认保留；示例为 PDF 精确值；已采用 nat_gateway_count | 明确 subnet_offsets 输入和 PDF 示例；真实迁移仍待确认 | 精确子网表/路由检查 |
| **CF-202** S3 gateway 全环境；prod 四 interface endpoints | 本阶段新增 endpoints 模块及 SG 引用 | 尚未云上创建/DNS 测试 | root 显式 enable_interface_endpoints | validate；云上路由/DNS/拉镜像 |
| **CF-203** 五 SG，层间引用，DB 无 egress | 已有，保留 | 公网只有 443，无 80 redirect；无 README 证据 | TLS 保留；80 redirect 作为 B1 差距 | stateful 返回流量无需 DB egress；云上检查 |
| **CF-301** Serverless v2/TLS/RDS secret/环境容量/slowquery | RDS-managed secret、TLS 已有；补容量/备份输入和 slowquery | 默认仍固定实例，切换待确认；现有日志 key 不统一 | 保持地址；批准后配置 db.serverless 和 scaling | validate；describe-db-clusters/instances/日志 |
| **CF-302** 私有 one-off Fargate db-init，两次幂等 | init_db.py；补镜像 schema、缺密码/CA 前置校验、独立 db-init task definition | 无 db-init.sh；专用定义未云上运行 | 独立 bootstrap task 定义已完成，不会自动执行 | 本地双 init；云上 task exit/logs |
| **CF-303** Dev PITR restore-test 及清理证据 | 无 | 未演练 | 后续云上批准后操作 | 时间/恢复数据/删除记录 |
| **CF-401** ECS secrets 引用 RDS secret username/password | API secrets 引用 :username:: / :password::，API task role 无 AWS 权限 | 源码已对齐；缺云上 task/权限/TLS 证据 | 2026-11-20 用户批准并已实施密码切换 | JSON secrets 引用/secret IAM/TLS 业务测试 |
| **CF-402** SSM app_env/log_level/db_name 由 task 读取 | 普通 environment 内设置 | 无 SSM 参数/引用 | 与认证执行角色方案一起后续补齐 | 改 log level 后 redeploy |
| **CF-403** rotate-check、重部署、smoke | 无脚本；密码运行任务需重启读新 secret | 不满足指定演示 | 认证已批准，轮换脚本和云验 Phase 3 | rotation.txt |
| **CF-501** 精确 base 版本、非 root、CA、<200MB、amd64、扫描 | Phase2.6：Python3.12.16-alpine3.24/Nginx1.30.7-alpine3.24固定digest；cryptography50.0.2；API45.3MB/Web26.1MB，非root/只读/schema/CA保留 | 本地镜像门槛已通过；不代表AWS验收 | 无HIGH/CRITICAL未解决项、未豁免；旧失败报告保留 | Makefile build/local-test/image-check/scan；同一image ID最终Trivy0.76.2退出0，见phase-2.6-validation.md |
| **CF-502** clinicflow-web/api、immutable、scan、最新10镜像 | immutable/scan 已有；保留数修为10 | 当前 clinicflow/web、clinicflow/api 名称不符 | 重命名新仓库需复制 digest/确认迁移 | ECR policy/扫描/digest |
| **CF-503** Web /healthz、API /health、两 ALB、员工见新预约 | Web 支持 healthz（暂兼容health），ALB 显式路径输入及最终示例；公网员工禁用（用户已确认保留） | 日程验收与患者隐私冲突 | 继续禁用公网；用户接受受控演示；仍需老师认可验收方式 | 本地完整业务；云上受控日程 |
| **CF-504** 同 ECS service module 每环境调用两次、回滚 | 单模块内部 for_each 两 tier，私有 task/自动回滚 | 调用结构字面不符；未演示失败部署回滚 | 保留地址避免无意义 state 重构，记录差距 | 坏镜像 dev 回滚证据 |
| **CF-505** smoke 预约后 GET、release-watch 零失败 | CI 原本只 health；本阶段业务 smoke | 云上日程受限；无 release-watch | 本地验证完整流程；部署监测后续 | smoke + 发布过程每秒请求 |
| **CF-601** 一 execution/env、task/tier、secret ARN、权限模拟 | 当前 execution/tier，Web/API task 均无权限，API execution 读取主 secret | 结构差异；已按 CF-401 限定 secret ARN | 已移除 API rds-db IAM policy，保留旧用户 SQL 为 legacy | 跨环境 secret denied、API S3 denied |
| **CF-602** security-check 各环境 PASS 证据 | 无脚本 | 未验收 | Phase 3 | 三个环境真实输出 |
| **CF-603** 三个安全头/隐藏版本/公网隔离 | 本阶段 Nginx 补齐；保留隔离 | 无 ALB curl/公网失败证据 | 本地 nginx 校验 | curl -I/外网探测 |
| **CF-604** 6 个安全问题≤5行含证据 | 无 | 未交付最终问卷 | 不以本矩阵冒充正式证据 | 后续 security-answers.md |
| **CF-701** PR 并行 lint/scan/plan、SHA/最小权限/保护 | CI fmt/init/validate/build | 缺完整安全及 plan 门 | Phase 3，不执行 AWS plan | 失败 PR/分支保护 |
| **CF-702** main 单次构建 SHA tag、ECR/digest | 现有本地 CI 构建 | 无 release pipeline | Phase 3 | build summary/digests |
| **CF-703** dev→staging→审批prod/保存plan回滚 | 无 | 未实现 | Phase 3 | 全链 run/审批截图 |
| **CF-704** 3 个坏 PR guardrails 证据 | 无 | 未实现 | Phase 3 | 3 个已关闭 PR 链接 |
| **CF-801** 完整 Makefile/up/down 保护 | 无 | 未实现 | 本阶段仅增加本地/静态检查入口，完整运维留 Phase 3 | make help/非法ENV/prod down拒绝 |
| **CF-802** 脚本严格模式/幂等/shellcheck/动态账号区域 | 现有 init-backend.sh | 无完整脚本标准验证 | 后续统一脚本 | shellcheck/双运行 |
| **CF-803** nonprod AUD150 Budget/周报/销毁规则 | clinicflow-budget/USD，先预算依赖已有 | 名称/币种/过滤不符；无 Cost Explorer 脚本 | 不直接替换账单资源；官方限制核对后单列 | 预算配置/标签激活/费用报告 |
| **CF-901** 5xx>5/5min、unhealthy 2period、DB>80/10min、ECS>85/10min | 现有 5xx 60s×2、CPU80/3min、healthy 数量告警 | 阈值与时间不完全匹配 | 列差距，后续运维阶段修 | 真实邮件/恢复 task |
| **CF-902** 六类指标 dashboard+20次smoke截图 | CPU/memory、target、AuroraCPU 共5 widgets | 缺 request/5xx/p95/connections | Phase 3 | dashboard 截图 |
| **CF-903** README/三事件 runbook/架构图 | 此前无 tracked Markdown 文档 | 最终交接不完整 | 本阶段新增矩阵/迁移审查；最终手册后续 | 陌生人按 README 重建 |
| **B1** HTTPS ACM DNS validation/80→443 | 现有外部证书 ARN、443、可选DNS | 无 ACM 创建/80 redirect/证据 | 保留已有 TLS；不宣称 Bonus 完成 | HTTP301/HTTPS200 |
| **B2** WAF Common+300/5min | 无 | 可选未做 | 不扩展本阶段 | 403证据 |
| **B3** Prod API 2..6/60% autoscaling | 无 | 可选未做 | 不扩展本阶段 | load/dashboard |
| **B4** Sydney 工作日19→0/07→1 | 无 | 可选未做 | 不扩展本阶段 | schedule/service events |
| **B5** 受限用户 SELECT/INSERT/UPDATE + 第二 secret | IAM 受限列授权 | 不符密码第二 secret；staff 缺 SELECT id/name/mobile、UPDATE status | 业务访问决定前不扩大患者字段授权 | 获批后业务成功且 DROP 拒绝 |
| **B6** CloudTrail+GuardDuty | multi-region CloudTrail/KMS 已有 | 无 GuardDuty/事件证据 | 保留已有审计，不新建收费服务 | CloudTrail event/GuardDuty截图 |

## 不能混淆的技术合理性与作业符合性

IAM 认证减少长效数据库密码使用，但不满足 CF-401 指定的 ECS secrets 登录及 CF-403 轮换演示。公网禁用员工读写能避免匿名患者数据泄漏，但 CF-503 的员工流程尚未完成验收。单模块 for_each 与多 CMK 设计技术上可行，但不完全符合 CF-104/504 的指定结构。没有教师正式批准材料，不能标“通过”。

ALB 访问日志只支持 SSE-S3，应保留可工作的 AES256，登记 NFR-4 例外并请老师确认；不能机械改成 KMS。ECS secrets 注入后秘密实际仍存在运行容器环境内，NFR-3 应解释为禁止在 task definition 的普通 environment 写入明文，不能声称运行内存无秘密。

官方依据：
- [ALB 日志仅支持 SSE-S3](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html)
- [ECS secret JSON key、执行角色和轮换后重新部署](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html)
- [Aurora Serverless v2 自动暂停，MySQL 3.08.0+](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-auto-pause.html)
- [Terraform state 地址迁移](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring)

## 本次用户确认（2026-11-20）

- 已批准 CF-401 切换：源码改为 ECS secrets + TLS 密码连接，移除 API task 的 rds-db:connect；独立 db-init task 使用相同镜像和主 secret，不自动运行。
- 接受受控员工演示方案，公网继续禁用。此用户决定不等于老师正式批准 CF-503 替代验收方式。
- 已批准把 CIDR/Serverless/KMS/ECR 正式目标写入代码示例；实际资源迁移仍待 state/资源清单确认。旧 tfvars/state 不修改，旧网络/实例/仓库默认保留。
- Phase2.5当时本地业务与静态检查通过不抵消镜像扫描失败；其历史结论保留。Phase2.6最新镜像结果见下，不能因此把整个NFR-11合并门标成通过。

健康路径迁移：root 默认保留 /health 直到双路径 Web 镜像全部健康，再切换示例 /healthz。见 review；不能把目标示例认作已切换的云上状态。

## Phase 2.6 更新（2026-11-20）

最终实际业务复验与扫描的image ID一致，API/Web的HIGH及CRITICAL均为0，严格扫描退出码均0，CF-501本地镜像门槛已满足。详见 [Phase2.6验证记录](phase-2.6-validation.md)。Trivy维护版0.76.2和官方schema-v2数据库元数据、JSON/可读报告与基线分类均在evidence/phase-2.6，Phase2.5失败报告未改。

本次只改Dockerfile、requirements、现有Makefile与smoke脚本及验证资料；不修改业务/数据库认证/资源迁移配置，不执行AWS操作或自动进入Phase3。NFR-11的CI合并门和所有原有云上/迁移确认差距继续保留。
