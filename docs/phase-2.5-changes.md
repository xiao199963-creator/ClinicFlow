# 实际文件变更与原因

全部为未提交修改。原 PDF 保留且未编辑；.env、现有 tfvars、state 未修改。

| 文件 | 原因 |
|---|---|
| `.dockerignore` | 排除本地配置/state/历史等构建输入 |
| `.github/actions/docker-build/action.yml` | 根构建上下文/amd64，并补 bootstrap validate |
| `.github/workflows/ci.yml` | 根构建上下文/amd64，并补 bootstrap validate |
| `Makefile` | 仅本阶段本地/静态操作入口，不新增部署流水线 |
| `README.md` | 阶段入口、限制与交付导航 |
| `app/api/.dockerignore` | 排除本地配置/state/历史等构建输入 |
| `app/api/Dockerfile` | 镜像契约、获批认证/TLS和初始化前置检查；不改业务路由 |
| `app/api/app.py` | 镜像契约、获批认证/TLS和初始化前置检查；不改业务路由 |
| `app/api/init_db.py` | 镜像契约、获批认证/TLS和初始化前置检查；不改业务路由 |
| `app/web/.dockerignore` | 排除本地配置/state/历史等构建输入 |
| `app/web/Dockerfile` | 固定base、healthz/API_URL/安全头，保留公网员工禁用 |
| `app/web/nginx.conf.template` | 固定base、healthz/API_URL/安全头，保留公网员工禁用 |
| `compose.yaml` | API根上下文、内置schema、API_URL |
| `db/aurora-iam.sql` | 标明旧IAM脚本不适用于获批密码运行方案 |
| `docs/evidence/phase-2.5/api-image-scan.txt` | 本地扫描证据或阶段交付记录；不代表云上验收 |
| `docs/evidence/phase-2.5/web-image-scan.txt` | 本地扫描证据或阶段交付记录；不代表云上验收 |
| `docs/phase-2.5-changes.md` | 本地扫描证据或阶段交付记录；不代表云上验收 |
| `docs/phase-2.5-plan.md` | 正式要求、决策/迁移或真实验证记录 |
| `docs/phase-2.5-review.md` | 正式要求、决策/迁移或真实验证记录 |
| `docs/phase-2.5-validation.md` | 正式要求、决策/迁移或真实验证记录 |
| `docs/requirements-matrix.md` | 正式要求、决策/迁移或真实验证记录 |
| `scripts/smoke-test.py` | 复用现有技术栈的业务冒烟/六根静态验证 |
| `scripts/smoke-test.sh` | 复用现有技术栈的业务冒烟/六根静态验证 |
| `scripts/validate-terraform.sh` | 复用现有技术栈的业务冒烟/六根静态验证 |
| `terraform/bootstrap/budget/main.tf` | 统一必需标签，保留原资源名称与地址 |
| `terraform/bootstrap/budget/providers.tf` | 统一必需标签，保留原资源名称与地址 |
| `terraform/bootstrap/platform/main.tf` | 最近10镜像、名称输入/共享key alias与输出；旧仓库默认保留 |
| `terraform/bootstrap/platform/outputs.tf` | 最近10镜像、名称输入/共享key alias与输出；旧仓库默认保留 |
| `terraform/bootstrap/platform/providers.tf` | 最近10镜像、名称输入/共享key alias与输出；旧仓库默认保留 |
| `terraform/bootstrap/platform/terraform.tfvars.example` | 无个人信息的正式目标；实际迁移仍需确认 |
| `terraform/bootstrap/platform/variables.tf` | 最近10镜像、名称输入/共享key alias与输出；旧仓库默认保留 |
| `terraform/bootstrap/state/backend.hcl.example` | 无个人信息的正式目标；实际迁移仍需确认 |
| `terraform/bootstrap/state/main.tf` | state KMS输入/后端参数兼容；旧默认和state保留 |
| `terraform/bootstrap/state/providers.tf` | state KMS输入/后端参数兼容；旧默认和state保留 |
| `terraform/bootstrap/state/terraform.tfvars.example` | 无个人信息的正式目标；实际迁移仍需确认 |
| `terraform/bootstrap/state/variables.tf` | state KMS输入/后端参数兼容；旧默认和state保留 |
| `terraform/environments/dev/main.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/dev/output.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/dev/providers.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/dev/terraform.tfvars.example` | 无个人信息的正式目标；实际迁移仍需确认 |
| `terraform/environments/dev/variables.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/prod/main.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/prod/output.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/prod/providers.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/prod/terraform.tfvars.example` | 无个人信息的正式目标；实际迁移仍需确认 |
| `terraform/environments/prod/variables.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/staging/main.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/staging/output.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/staging/providers.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/environments/staging/terraform.tfvars.example` | 无个人信息的正式目标；实际迁移仍需确认 |
| `terraform/environments/staging/variables.tf` | 显式传入环境差异、必需标签、secret/初始化输出；保留资源地址 |
| `terraform/init-backend.sh` | state KMS输入/后端参数兼容；旧默认和state保留 |
| `terraform/modules/alb/main.tf` | 按tier区分health路径，日志行为由输入控制；保留SSE-S3 |
| `terraform/modules/alb/variables.tf` | 按tier区分health路径，日志行为由输入控制；保留SSE-S3 |
| `terraform/modules/compute/main.tf` | ECS secrets/独立init定义、API_URL与显式规模输入 |
| `terraform/modules/compute/outputs.tf` | ECS secrets/独立init定义、API_URL与显式规模输入 |
| `terraform/modules/compute/variables.tf` | ECS secrets/独立init定义、API_URL与显式规模输入 |
| `terraform/modules/ecr/main.tf` | 最近10镜像、名称输入/共享key alias与输出；旧仓库默认保留 |
| `terraform/modules/ecr/outputs.tf` | 最近10镜像、名称输入/共享key alias与输出；旧仓库默认保留 |
| `terraform/modules/ecr/variables.tf` | 最近10镜像、名称输入/共享key alias与输出；旧仓库默认保留 |
| `terraform/modules/endpoints/main.tf` | S3 gateway及四类interface endpoint，避免模块依赖环 |
| `terraform/modules/endpoints/variables.tf` | S3 gateway及四类interface endpoint，避免模块依赖环 |
| `terraform/modules/endpoints/versions.tf` | S3 gateway及四类interface endpoint，避免模块依赖环 |
| `terraform/modules/iam/main.tf` | API execution读取指定主secret，API task不再持rds-db权限 |
| `terraform/modules/iam/variables.tf` | API execution读取指定主secret，API task不再持rds-db权限 |
| `terraform/modules/rds/main.tf` | 容量/备份/快照显式输入及slowquery；不默认切换实例 |
| `terraform/modules/rds/variables.tf` | 容量/备份/快照显式输入及slowquery；不默认切换实例 |
| `terraform/modules/secrets/main.tf` | 等待期输入及正式alias，保留原key供迁移审查 |
| `terraform/modules/secrets/variables.tf` | 等待期输入及正式alias，保留原key供迁移审查 |
| `terraform/modules/vpc/README.md` | nat计数/子网偏移输入和route输出；旧网默认保留 |
| `terraform/modules/vpc/main.tf` | nat计数/子网偏移输入和route输出；旧网默认保留 |
| `terraform/modules/vpc/outputs.tf` | nat计数/子网偏移输入和route输出；旧网默认保留 |
| `terraform/modules/vpc/variables.tf` | nat计数/子网偏移输入和route输出；旧网默认保留 |
