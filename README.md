# ClinicFlow Capstone

Phase 2.5 正式验收对齐工作区。完整 story 状态和差距见 [requirements matrix](docs/requirements-matrix.md)，认证/访问决定和资源迁移影响见 [Phase 2.5 review](docs/phase-2.5-review.md)，真实本地验证结果见 [validation](docs/phase-2.5-validation.md)。这些文档不等于云上验收证据。

本阶段入口：`make help`、`make fmt`、`make validate`、`make build`。业务冒烟：`make smoke URL=<disposable-url>`；只在批准的受控员工访问 URL 上加 `STAFF=1`。smoke 会写合成预约，只对临时数据库运行；公网模式验证员工接口拒绝，员工模式验证日程/状态/取消释放时间槽。

API 本地构建必须以仓库根为 context（Makefile/Compose/现有 CI 已同步），镜像包含 schema 与 RDS CA。普通 API 不自动初始化；AWS db-init 有独立 task definition，未来脚本必须以 App 私网/api-sg 运行它并检查退出码。禁止将 IAM runtime task 覆盖成 init 命令而不提供密码。

三个环境的 `terraform.tfvars.example` 不含个人信息，包含正式网络与 Serverless 目标配置。占位账号/证书/digest 需替换；不要覆盖现有忽略的 tfvars 或把示例直接 apply 到已有 state。KMS 日志整合、state 共享加密切换和 ECR 改名仍需迁移确认。

完整部署流水线、up/down/teardown-prod、轮换/恢复与最终交接手册属于后续阶段，当前没有这些操作入口。最终操作规则：每次工作结束运行 `make down ENV=dev` 和 `make down ENV=staging`（待 Phase 3 实现）；当前不要用不存在的目标声称资源已清理。本阶段未创建任何 AWS 资源。
