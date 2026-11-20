# Phase 2.5 决策与迁移审查

用户已批准 CF-401 认证代码切换、接受受控员工访问并批准资源目标示例；实际资源迁移及老师替代验收仍未批准，不代表云上验收。未执行 AWS plan/apply/destroy、commit/push/merge。现有忽略的 terraform.tfvars、.env、state 未改。

## 已确认并实施：CF-401 认证

已采用用户批准的核心作业方案：API DB_USER/DB_PASSWORD 位于 ECS secrets，分别引用 `${master_secret_arn}:username::`、`:password::`；普通 environment 不含这两个键。仅 API execution role 获 secretsmanager:GetSecretValue 和环境 key kms:Decrypt（ViaService/secret ARN 限制）。API runtime task role 无 rds-db 权限；应用密码连接保持 CA/hostname 验证，AWS 上缺 CA 拒绝。保持 iam auth 支持本身不影响密码接入，可在过渡结束后再关。

init 使用独立一次性 task definition，仍是同一 API image/私有 App 子网/api-sg，command 为 python init_db.py，使用 bootstrap master secrets，不在正常 API 启动命令串联 init。普通 IAM runtime task 没有 DB_PASSWORD，禁止拿它直接运行 init。已补缺密码/云上缺 CA 前置失败，并创建独立 database_bootstrap task definition 及输出 ARN；没有自动运行任务或新增完整 db-init.sh。

影响：运行应用变成主账号权限，符合 CF-401 核心要求但弱于旧 IAM 限权方案。若选 B5，需要第二 secret 与受限用户，属于另一条需正式批准的认证路径；不能一边声称原样满足 CF-401 一边偷偷改第二 secret。密码轮换后新 task 才读新值，应滚动重部署并验证业务。已按用户批准实施 secret 引用与执行角色权限切换；云上尚未运行。

## 用户已接受、老师验收方式待确认：员工日程与隐私

当前 schedule.html、GET /api/bookings、PATCH /api/bookings/{id} 在公网默认 403；本地 loopback Compose 才允许。这些 API 包含患者姓名和手机号，没有员工认证。不能直接将 ECS LOCAL_STAFF_ACCESS=1。

推荐保留公网禁用，以受控私网/本地转发演示日程（需老师认可 CF-503 验收方式；不能把建议当成已批准替代）。不增加认证框架，不删除已有业务。若保留 IAM 用户，员工功能至少需要 bookings 的 id/clinic_id/patient_name/mobile/slot_date/slot_hour/status SELECT 及 status UPDATE，原 aurora-iam.sql 不足；在访问方式批准前不扩大授权。

## 待确认 3：现有资源与 state

先获取各根 state resource 地址、真实 AWS 资源清单及是否有患者数据（本阶段未读取远程 state）。以下不能直接 apply：

| 调整 | 具体目标 | 影响与安全步骤 |
|---|---|---|
| 网络 | VPC 10.10/20/30.0.0/16，public .0/.1，web .10/.11，app .20/.21，data .30/.31 /24 | 当前偏移 1..8；子网 CIDR 是替换属性。现有 .1 与目标重叠，不能依赖 create_before_destroy。需迁移窗口/并行网络、迁移 task/ALB/DB subnet group，保留快照与回退；仅 state mv 无法修改真实 CIDR。模块新增 subnet_offsets 输入，root 默认保留旧偏移，示例显式给 PDF 偏移。 |
| Aurora | db.serverless；dev/staging 0..1 ACU/暂停/1 writer/1天备份；prod .5..4/不暂停/2实例/7天 | 模块已支持 scaling 显式输入，示例给目标值；默认固定实例仍保留。先核实区域/引擎版本与转换能力、快照、维护窗口、实例 failover；不要替换整个 cluster。禁止直接重建。 |
| 环境 KMS | 保留 data key 的 resource 地址作为环境 key；alias/clinicflow-<env>；dev/staging 7 天、prod30天 | 不改 Aurora 存储 key，存储加密 key 变更通常需快照复制/恢复新 cluster。将日志/SNS/secret 逐个迁到保留的 key 前补 Logs/SNS key policy；旧 key 保留供旧日志解密，禁止删除。当前 data/log key 均保留；已在 data key 增加正式环境 alias，等待期有显式输入，示例为7/7/30。 |
| 共享 KMS | 保留 module.ecr.aws_kms_key.ecr 地址为共享 key，新增 alias/clinicflow-shared；state 桶引用该 ARN | 跨 bootstrap 根传 ARN，不搬 key state；新写 state SSE-KMS 可原地改默认加密，旧对象版本不会自动重加密。先授予 state 使用者 Encrypt/Decrypt/GenerateDataKey；保留旧 key/版本。默认仍为 SSE-S3；新增 shared_kms_key_arn 输入和示例，backend 同时要配置 kms_key_id（仅 encrypt=true 不足），init-backend.sh 第4参数支持该 key。当前权限迁移未执行。 |
| ECR | clinicflow-web、clinicflow-api，原共享 key、不变 tag/scan、最新10 | 改名会新建 repository。先创建目标、复制同 digest 镜像、更新引用、验证回滚，再考虑旧库；不可自动销毁旧仓库。仓库名成为显式 repository_names，默认未改，bootstrap 示例给正式名称；10镜像策略已修，部署前确认旧 rollback digest 不会被清理。 |
| 名称与目录 | PDF 的 infra/envs、指定 role/bucket 名 | 重命名资源可能替换，目录迁移需要 backend key 保持和独立 state 审查。此阶段不为对齐目录大规模移动。 |

新增 required 根参数意味着旧本地 tfvars 需要补齐才能 plan；使用示例逐项人工合并，不覆盖原文件。模块内不再按 prod 判断行为；环境根仍保留安全约束。S3 gateway 新增 prefix-list 路由不是互联网默认路由；interface endpoint 只允许 web/api SG 的443，NAT HTTPS 仍保留以支持镜像源等访问。

## 官方限制与验收例外

- [ALB access logs](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/enable-access-logging.html)：只支持 SSE-S3，故 access_logs bucket 保持 AES256；与 NFR-4 字面要求冲突，待老师认可例外。
- [ECS secrets](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/secrets-envvar-secrets-manager.html)：secret 在启动时注入，轮换不自动刷新运行 task。不要声称运行容器环境内没有 secret。
- [Aurora auto-pause](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/aurora-serverless-v2-auto-pause.html)：MySQL 3.08.0+ 支持零 ACU。API /health 持续 SELECT 1 会建立数据库连接，ALB 每30秒检查可能使数据库一直无法空闲暂停；允许暂停的配置不等于已证明暂停。需停止非prod task/健康检查后观察，不能为省费取消 API 真实健康契约。
- [KMS 默认 key policy](https://docs.aws.amazon.com/kms/latest/developerguide/key-policy-default.html)：账户 root principal 的 kms:* / Resource:* 表示该 key 的账户 IAM 委托，不是所有 key 的 IAM 全局权限。CF-104 “No policy allows kms:* on *” 与默认账户委托示例字面冲突，需说明并请求老师认可，不能随意删掉导致 lockout。

## 进入 Phase 3 条件

可开展不依赖决策的 CI 安全检查设计；不能认定 Phase 2.5 已正式验收。认证源码已获批，员工受控访问需老师认可，资源迁移仍待清单确认；不启动真实部署/资源替换。缺云上 PITR、IAM 模拟、ALB/endpoint/TLS、轮换、回滚、AZ 故障和预算证据；本地测试仅证明本地契约和业务。

## 资源地址变化清单

- 删除 `module.iam.aws_iam_role_policy.api_database`，新增 `api_secret`：仅内联 IAM policy 更换，不替换 role/数据库；应用运行认证改动有部署顺序要求，先注册含 secret 的 revision/授 execution 权限，再滚动替换旧 IAM task，旧 task 退出前不要过早收回其 rds-db 权限。实际部署顺序须在 Phase 3 方案中处理。
- 新增 `module.compute.aws_ecs_task_definition.database_bootstrap`，不会自行运行，不替换 ECS service。
- 新增 `module.endpoints.*`、slowquery log group、KMS aliases；现有 VPC/subnet/RDS/role/key/repo state 地址保留。未添加 moved/import/state mv 命令。
- `nat_gateway_count` 替代 `high_availability` 接口，旧 tfvars 的 high_availability 必须删除并显式设置 nat_gateway_count，prod=2；其他新增 required 输入逐项合并。不要直接覆盖本地文件。

## 新发现的镜像门槛

最终基础镜像固定为实测补丁版本及 digest，但 Trivy 仍发现漏洞。没有自动豁免或伪造“无高危”；详见 validation。修复系统包/依赖并复扫属于进入真实部署前的必要后续工作。

State 加密依据：[Terraform S3 backend 的 kms_key_id 与 KMS 权限](https://developer.hashicorp.com/terraform/language/backend/s3)、[AWS backend 最佳实践](https://docs.aws.amazon.com/prescriptive-guidance/latest/terraform-aws-provider-best-practices/backend.html)。state bootstrap 先前可独立建桶；共享 ECR key 由 platform 管理，正式切换需先给 platform 一个可用后端并创建共享 key，再更新 state 默认加密及各 backend 参数，防止引入 bootstrap 循环。

## 独立审查修复与健康检查迁移

独立只读审查指出 prod 显式输入可能绕过先前默认保护，已在环境 root 补备份7天、必须final snapshot、保留自动备份、日志禁止force_destroy/至少365天约束，模块仍不按env名判断。API根构建 context 改为只允许必要源码、依赖、Dockerfile和schema的 allowlist，排除任意本地 state、plan、credentials 等资料。

健康路径不能在老 Web revision 仍只支持 /health 时直接改 target group。新 Nginx 临时兼容 /health 与 /healthz；root 默认仍 /health。先在保持原检查路径和原 IAM 授权的过渡配置中滚动部署兼容镜像并确认所有旧 task 退出，再将 web_health_check_path 改为 /healthz（示例为最终目标），收回旧 rds-db 权限。此阶段只交付代码/迁移方案，没有执行任一步云上滚动。不得把本分支最终权限/示例一次性 apply 到仍运行 IAM 旧镜像的环境。
