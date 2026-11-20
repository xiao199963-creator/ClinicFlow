# Phase 2.6：容器镜像漏洞修复与复验

2026-11-20，Australia/Melbourne。当前分支仍为 `feature/phase-2-5-requirements`；全部 Phase 2/2.5 未提交成果保留，没有 reset/stash/切分支、commit/push/merge。本阶段没有 AWS 操作，没有执行 Terraform plan/apply/destroy 或重跑基础设施测试。

**结论：最终实际测试的两个镜像均满足 HIGH/CRITICAL 阻断门槛，镜像安全检查通过。** 这只表示下述时间、工具和数据库下的本地镜像结果，不是 AWS 验收，也不表示整个 NFR-11 合并门或 Phase 3 已完成。

## 修改文件与理由

| 文件 | 改动及原因 |
|---|---|
| `app/api/Dockerfile` | 同一 Python 3.12.16 改用官方受维护 Alpine 3.24 变体，固定精确 tag+digest；Debian 发行版存在无法通过现有安全仓库修复的阻断。对候选中唯一剩余组件 krb5-libs 精确升级至1.22.3-r0。保留 schema、RDS CA、非root及启动方式。 |
| `app/web/Dockerfile` | 升至官方稳定版 Nginx 1.30.7 / Alpine3.24，固定tag+digest，消除旧Nginx及其系统库漏洞；配置与HTML不改。 |
| `app/api/requirements.txt` | cryptography 43.0.1→50.0.2；将实际成功安装的直接及间接运行依赖全部固定在原文件，无新增依赖管理框架。其余直接依赖不升级。 |
| `Makefile` | 保留既有目标，build支持IMAGE_TAG；增加db-update、scan/scan-api/scan-web、image-check、local-test。扫描绑定实际image ID、保留JSON/文本/DB/退出码，已有证据目录拒绝覆盖。 |
| `scripts/smoke-test.py` | 扩展既有脚本支持本地临时Compose编排，复用原业务断言；随机密码、独立tmpfs数据库、无宿主端口、只读/非root/CA及拒绝路径检查，finally只清理本次随机项目。没有新增测试框架或重复业务脚本。 |
| `docs/requirements-matrix.md` | 更新CF-501及NFR-11，区分本地镜像已通过和后续CI合并门尚未实现。 |
| 本文与 `docs/evidence/phase-2.6/` | 新阶段必须独立保存JSON、身份、分类和真实记录，旧Phase2.5文本不能承担这些职责，故新增证据文件；旧报告原样保留。 |

没有修改 app.py、init_db.py、Nginx配置、HTML、compose.yaml、CF-401认证或任何资源迁移生效配置。

## 扫描依据

原安装Trivy为0.74.0。先从 `ghcr.io/aquasecurity/trivy-db:2` 下载独立缓存，再重新构建当前源码的linux/amd64基线并复扫。随后为获得维护版对新Alpine的完整支持，将官方Trivy0.76.2下载到 `/tmp/clinicflow-phase26-trivy-bin/`；依据官方release checksums核对SHA256，未修改系统Trivy。官方release：[v0.76.2](https://github.com/aquasecurity/trivy/releases/tag/v0.76.2)。

数据库schema v2，UpdatedAt=`2026-11-20T01:04:07.386165244Z`（墨尔本12:04），NextUpdate=`2026-11-21T01:04:07.386165093Z`，DownloadedAt=`2026-11-20T04:40:23.356391Z`（墨尔本15:40）。下载成功，扫描时仍在有效期内；Makefile扫描没有skip-db-update。完整元数据和数据库文件SHA256见 [scan-provenance.json](evidence/phase-2.6/scan-provenance.json)，每个报告另保存自己的 `*-db.json`。

基线0.74与维护版0.76.2的结果相同；最终比较使用0.76.2。扫描明确使用 `--scanners vuln --severity HIGH,CRITICAL --exit-code 1`，OS与Python均扫描。没有ignore-unfixed、ignore文件、降级严重度、豁免或用exit-code0绕过阻断。

`trivy convert` 对JSON输出的汇总表提示“No enabled scanners found”，属于转换展示提示；原扫描日志明确记录Alpine和python-pkg扫描，JSON为权威结果。可读报告附镜像ID及真实gate退出码，不能把该转换提示解释为关闭了OS/语言扫描。

## 版本与digest

| 项目 | Phase2.6基线 | 最终 |
|---|---|---|
| API Python | 3.12.16-slim / Debian13.7 | 3.12.16-alpine3.24 / Alpine3.24.4 |
| API base index digest | `sha256:5e2bdb1b0d542d5039cffb8181c65930093949194a65c365dfb1b0fe13a4fa5b` | `sha256:c5ba3deef00c7758561a0f03c26f44f10589263d40e732b8748e0d1f38f6dd89` |
| Web Nginx | 1.28.3-alpine / Alpine3.23.3 | 1.30.7-alpine3.24 / Alpine3.24.4 |
| Web base index digest | `sha256:a8b39bd9cf0f83869a2162827a0caf6137ddf759d50a171451b335cecc87d236` | `sha256:caf4e1e032a20f9c3c5e28fc7f25ffd768ad8677b4975c54193075997b3a97e3` |
| cryptography | 43.0.1 | 50.0.2 |
| API krb5-libs | Alpine候选1.22.2-r1（16 HIGH） | 精确1.22.3-r0 |

其他直接依赖仍为Flask3.0.3、PyMySQL1.2.4、boto3 1.44.7、gunicorn22.0.0。最终cffi2.1.1等解析版本全部精确固定，详见requirements和 [versions.json](evidence/phase-2.6/versions.json)。没有删除运行依赖。Python Alpine变体会改变libc；本阶段已验证wheel安装、pip check、PyMySQL RSA路径及完整本地业务，未声称该结果代替Aurora云上验证。

官方选择依据：

- [Docker Official Images Python清单](https://github.com/docker-library/official-images/blob/master/library/python)与[官方Alpine3.24 Dockerfile](https://github.com/docker-library/python/blob/3d7e95597e56a415d9e4abc0f15877e005d2cb2e/3.12/alpine3.24/Dockerfile)确认精确Python变体。manifest记录包含amd64子manifest、源码revision和索引digest。
- [Nginx官方镜像清单](https://github.com/docker-library/official-images/blob/master/library/nginx)及[1.30.7官方变更记录](https://nginx.org/en/CHANGES-1.30)确认稳定版和安全修复。
- [cryptography官方changelog](https://cryptography.io/en/latest/changelog/)、[50.0.2安装支持](https://cryptography.io/en/50.0.2/installation/)和[PyPI官方release](https://pypi.org/project/cryptography/50.0.2/)确认修复/受支持Python与musllinux wheel；官方元数据要求Python>=3.9，适用于3.12。没有选择未发布的51开发版。
- [PyMySQL官方安装说明](https://pymysql.readthedocs.io/en/latest/user/installation.html)说明sha256_password/caching_sha2_password需RSA额外依赖。当前PyMySQL metadata的rsa extra要求cryptography>=46.0.7。旧43.0.1不应保留，也不应为计数直接删除；本地复验包含sha2_rsa_encrypt真实加密路径。
- [Alpine官方krb5-libs包](https://pkgs.alpinelinux.org/package/v3.24/main/x86_64/krb5-libs)确认1.22.3-r0；[官方SecDB](https://secdb.alpinelinux.org/v3.24/main.json)列出候选16个HIGH的修复，摘录保存在alpine-candidate/official-krb5-secfixes.json。这是升级已有组件，不是删包掩盖扫描。

## 分类、前后比较和身份绑定

完整逐包/CVE分类含OS/Python、当前版、修复版、有无可用修复及官方链接：[findings.csv](evidence/phase-2.6/baseline/findings.csv)。按底层source组件去重解释见 [classification.md](evidence/phase-2.6/baseline/classification.md)。例如API的util-linux 36条来自9个二进制包的4个相同CVE；Web的curl22条来自curl/libcurl的11个CVE。分类不改变扫描原始条数或阻断行为。

| 报告目录 | 扫描器 | API HIGH / CRITICAL | Web HIGH / CRITICAL | 处理 |
|---|---|---|---|---|
| Phase2.5旧文本 | 0.74.0 | 51 / 0 | 77 / 8 | 原文件保留；历史未记录不可变image ID，不能事后伪造绑定 |
| baseline | 0.74.0 | 51 / 0 | 77 / 8 | 本阶段重新构建，身份/JSON齐全 |
| baseline-v0762 | 0.76.2 | 51 / 0 | 77 / 8 | 同一基线image ID，维护版复扫 |
| candidate（bookworm） | 0.74.0 | 99 / 2 | 0 / 0 | API候选拒绝，未采用 |
| alpine-candidate（krb5升级前） | 0.76.2 | 16 / 0 | 0 / 0 | 官方krb5安全更新后消除 |
| **final** | **0.76.2** | **0 / 0** | **0 / 0** | **两个扫描均退出0** |

bookworm虽受[Debian LTS维护](https://www.debian.org/News/2026/20260712)，且[某个util-linux问题在bookworm不受影响](https://security-tracker.debian.org/tracker/CVE-2026-76642)，实际扫描仍发现更多未修复系统库问题，因此没有依据单个公告就认定安全，未采用该候选。`nginx:1.28.3-alpine3.24`也经仓库查询不存在，未使用猜测tag。

当前未解决的HIGH/CRITICAL为0，无需申请漏洞例外。所有候选报告保留自己的不可变ID；候选用过的本地tag后来指向最终镜像，审阅时应以identity.json及扫描JSON中的ID为准。

最终业务测试与扫描逐一比对，三处ID一致：local-test.json、docker image inspect identity.json、Trivy JSON Metadata.ImageID。

| 镜像 | Docker image ID | 平台/用户 | Docker Size |
|---|---|---|---|
| API | `sha256:9585d8d39010193a3d341465bfc44b2f7f1a4fa00d5e1ba386a1033d22613805` | linux/amd64；10001:10001 | 45,314,245 bytes，45.3 MB，<200MB |
| Web | `sha256:5fe061f2e8ac72bd8fcf79a14124de9f5c3b4675663c320abf49e3b79dc2c202` | linux/amd64；10001:10001 | 26,075,336 bytes，26.1 MB |

最终扫描时间：API 15:49:10、Web15:49:10（墨尔本）。详情见 [final/api.json](evidence/phase-2.6/final/api.json)、[final/web.json](evidence/phase-2.6/final/web.json)，可读报告为同目录api.txt/web.txt，身份和base manifest也在同目录。

## 实际命令与退出码

所有构建/扫描/本地业务入口均在现有Makefile。主要命令如下；scan子命令的1表示按设计阻断，Make总体返回2是Make对失败recipe的退出码。

| 命令 | 退出码 |
|---|---|
| `make build IMAGE_TAG=phase26-baseline` | 0 |
| `make -k scan IMAGE_TAG=phase26-baseline REPORT_DIR=docs/evidence/phase-2.6/baseline` | Make2；API1、Web1 |
| `make db-update TRIVY=/tmp/clinicflow-phase26-trivy-bin/trivy` | 0（官方独立DB缓存可用） |
| `make -k scan IMAGE_TAG=phase26-baseline TRIVY=/tmp/clinicflow-phase26-trivy-bin/trivy REPORT_DIR=docs/evidence/phase-2.6/baseline-v0762` | Make2；API1、Web1 |
| `make build IMAGE_TAG=phase26-final`（bookworm候选，日志candidate/build.txt） | 0 |
| `make -k scan IMAGE_TAG=phase26-final REPORT_DIR=docs/evidence/phase-2.6/candidate` | Make2；API1、Web0 |
| `make build IMAGE_TAG=phase26-final`（Alpine候选，日志alpine-candidate/build.txt） | 0 |
| `make -k scan IMAGE_TAG=phase26-final TRIVY=/tmp/clinicflow-phase26-trivy-bin/trivy REPORT_DIR=docs/evidence/phase-2.6/alpine-candidate` | Make2；API1、Web0 |
| `make build IMAGE_TAG=phase26-final`（最终krb5修复，日志final/build.txt） | 0 |
| `make local-test IMAGE_TAG=phase26-final REPORT_DIR=docs/evidence/phase-2.6/final` | 0 |
| `make image-check`、`git diff --check` | 0 |
| `make -k scan IMAGE_TAG=phase26-final TRIVY=/tmp/clinicflow-phase26-trivy-bin/trivy REPORT_DIR=docs/evidence/phase-2.6/final` | **Make0；API0、Web0** |

Makefile默认TRIVY使用PATH工具；要复现本次维护版结果，明确传TRIVY路径或在PATH安装相同维护版。默认IMAGE_TAG为短Git hash，可显式指定；重复扫描须换REPORT_DIR，不能覆盖已存在JSON。原系统Python3.8查询PyPI时发生证书验证失败，后改用系统curl的正常证书验证成功；没有关闭TLS校验。

## 业务、安全约定与清理

详见 [final/local-test.txt](evidence/phase-2.6/final/local-test.txt) 与 [final/local-test.json](evidence/phase-2.6/final/local-test.json)：

- 两个最终镜像构建成功；初始化连续两次均`schema applied: 3 statements`，种子诊所仍为3个。
- 创建预约201、重复预约409、员工日程显示相同合成预约、attended/cancelled更新成功，取消后时间槽重新可用。
- 同一Web镜像的公网默认模式拒绝schedule.html、GET bookings、PATCH bookings；受控模式员工流程可用。
- 两种Web配置均通过nginx -t；/health与/healthz均200，API_URL代理正常；GET/HEAD三个安全头正确且Server隐藏版本。
- schema与RDS CA存在且CA可解析；非root运行；容器ReadonlyRootfs=true且capabilities全部drop。
- AWS模式API与init缺CA立即拒绝；缺密码分别明确失败。pip check无依赖冲突，PyMySQL RSA路径成功。
- `make image-check`的ShellCheck和Hadolint均通过；独立只读审查未发现重要问题。

本次随机项目 `clinicflow-p26-c94f218ff2` 无宿主端口，使用独立网络与MySQL tmpfs数据库；密码用secrets随机生成，临时配置0600，Compose显式 `--env-file /dev/null` 和临时project-directory，不读取仓库.env。finally已删除本次四个容器、网络/数据库；TemporaryDirectory删除含密码配置。检查原有container IDs仍存在；没有向原项目发出up/down/rm、修改或清理其数据卷。

本次新建的本地基线/候选/最终镜像和下载缓存保留用于身份复核，不是运行资源；未清理此前镜像或缓存，未创建任何AWS资源。

**Phase 3 镜像门槛已满足，止于本阶段。** 原有资源迁移、老师确认的员工验收方式、完整CI/CD合并门和AWS secrets/TLS/ALB/回滚等云上证据仍按Phase2.5记录待后续处理，没有自动进入下一阶段。
