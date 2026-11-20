# Phase 2.5 验证记录（2026-11-20，Australia/Melbourne）

## 结果

- `terraform fmt -check -recursive terraform`：通过。
- `bash scripts/validate-terraform.sh`：六根目录全部 `init -backend=false -input=false -lockfile=readonly` / `validate` 通过。根为 environments/dev、staging、prod 以及 bootstrap/state、platform、budget；保留 lock file 既有 provider 版本，未 upgrade。
- `git diff --check`：通过。
- `shellcheck scripts/*.sh terraform/init-backend.sh`、`hadolint app/api/Dockerfile app/web/Dockerfile`：通过。
- Python AST 语法检查 app.py、init_db.py、smoke-test.py：通过。
- PDF ID 覆盖核对：11 个 NFR、32 个 CF、B1–B6 均在 requirements-matrix 中；这只是覆盖检查，不等于要求通过。

## 临时容器验证

使用项目名 `clinicflow-phase25`、临时 JSON Compose 配置、独立网络、MySQL tmpfs 数据库，不发布任何宿主机端口。随机本地数据库密码只写入权限0600的临时文件，不输出到日志；没有读取现有 .env。原 `clinicflow` 项目未停止/重建。

实际执行：

```bash
docker compose -p clinicflow-phase25 -f /tmp/clinicflow-phase25-compose.json build
docker compose -p clinicflow-phase25 -f /tmp/clinicflow-phase25-compose.json up -d --no-build --wait
# 连续执行两次，两个输出都是 schema applied: 3 statements
docker compose -p clinicflow-phase25 -f /tmp/clinicflow-phase25-compose.json exec -T api python init_db.py
docker compose -p clinicflow-phase25 -f /tmp/clinicflow-phase25-compose.json exec -T api python init_db.py
# 从 API 容器访问 Web 代理，不绕开 Nginx 的业务访问限制
docker compose -p clinicflow-phase25 -f /tmp/clinicflow-phase25-compose.json exec -T api python - http://web:8080 --staff < scripts/smoke-test.py
docker compose -p clinicflow-phase25 -f /tmp/clinicflow-phase25-compose.json run -d --no-deps --name clinicflow-phase25-public -e LOCAL_STAFF_ACCESS=0 web
docker compose -p clinicflow-phase25 -f /tmp/clinicflow-phase25-compose.json exec -T api python - http://clinicflow-phase25-public:8080 < scripts/smoke-test.py
docker compose -p clinicflow-phase25 -f /tmp/clinicflow-phase25-compose.json exec -T web nginx -t -c /tmp/nginx.conf
```

结果：两个镜像成功构建；初始化两次成功；员工模式通过 healthz、clinics、slots、预约201、重复预约409、日程匹配新预约、attended、cancelled 和释放时间槽；公网模式通过预约流程，员工页面/GET/PATCH 均403。Nginx `syntax is ok` / `test is successful`。

另执行容器内 Python 检查：schema 文件存在、RDS CA 能创建 SSL context；AWS APP_ENV 下 API 与 init 缺 CA 均在连接前拒绝；init 缺密码明确拒绝；GET/HEAD 三个安全头正确，Server 仅为 nginx。没有记录真实患者信息。

最终镜像：Python 3.12.16-slim 与 Nginx 1.28.3-alpine，均固定已构建的 manifest digest；amd64、User=10001:10001。API 约69 MB，Web约26 MB（Docker inspect Size），API满足<200MB体积要求。这里只证明本地构建与体积，不能证明镜像无漏洞。

## 安全扫描：失败，未豁免

```bash
trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 1 \
  --cache-dir /tmp/clinicflow-trivy-cache clinicflow-phase25-api:test
trivy image --scanners vuln --severity HIGH,CRITICAL --exit-code 1 \
  --cache-dir /tmp/clinicflow-trivy-cache clinicflow-phase25-web:test
```

API：退出1，Debian 包48 HIGH、Python cryptography 3 HIGH，共51 HIGH、0 CRITICAL。
Web：退出1，77 HIGH、8 CRITICAL。

扫描器 Trivy 0.74.0；原始本地报告在 [API](evidence/phase-2.5/api-image-scan.txt)、[Web](evidence/phase-2.5/web-image-scan.txt)。这些是本地镜像报告，不是云上 evidence。未自动 suppress 或声称所有 CVE 实际可利用；仍需更新基础系统包/依赖、评估受影响路径并复扫，或按 CF-501 经正式理由审查例外。当前不满足镜像安全放行条件。

## 限制与未执行项

首次 Terraform provider/Docker socket 验证受沙箱限制，获准以本地验证权限重跑后通过；未运行任何 AWS CLI 资源操作，未运行真实 plan/apply/destroy。init 使用 backend=false，不迁移现有 state。

临时 MySQL 使用密码连接，不是 Aurora；本地没有验证 Aurora IAM token、RDS-managed secret 轮换、ECS execution role 的 AWS 授权、真实 CA/hostname 的 Aurora TLS 连接、S3 endpoint 路由、private DNS、ALB 日志交付、ECS circuit breaker/AZ 分布、PITR 或 SNS 通知。正式 engine 在 Sydney 可用性、Serverless 修改对现有实例影响也未核实云资源。

部署前还需：资源/state 清单与迁移批准；KMS 日志整合/state共享密钥 IAM 与 backend 参数迁移；员工受控演示方式获老师认可；修复/正式审查镜像漏洞；补后续阶段的流水线和运维证据。

结论：可继续 Phase 3 的本地流水线准备；不能据此批准真实部署或声称 Phase 2.5 正式验收完成。

独立审查后补验：根构建context使用必要文件allowlist，Web兼容 /health 与 /healthz，生产备份/快照/日志保护在root校验。最终镜像重新构建并重跑完整员工业务、公网拒绝及Nginx检查；最终六根验证再次运行。

清理结果：本次 `clinicflow-phase25` 的全部临时容器/网络/数据库已删除，生成密码的临时 Compose 文件也已删除；本地测试镜像/构建缓存保留以便复核。`docker compose ls --format json` 确认原 `clinicflow` 项目仍为 running(2)。未清理或修改原项目数据卷。
