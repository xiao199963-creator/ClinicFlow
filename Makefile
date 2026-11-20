.DEFAULT_GOAL := help
.PHONY: help fmt validate build smoke scan scan-api scan-web db-update image-check local-test

IMAGE_TAG ?= $(shell git rev-parse --short HEAD)
REPORT_DIR ?= docs/evidence/phase-2.6/final
TRIVY ?= trivy
TRIVY_CACHE ?= /tmp/clinicflow-phase26-trivy

help: ## Show local/static commands (no cloud deployment targets)
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "%-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

fmt: ## Format Terraform
	terraform fmt -recursive terraform

validate: ## Validate all six Terraform roots without backend initialization
	bash scripts/validate-terraform.sh

build: ## Build both linux/amd64 images using the short commit hash
	docker build --platform linux/amd64 -f app/api/Dockerfile -t clinicflow-api:$(IMAGE_TAG) .
	docker build --platform linux/amd64 -t clinicflow-web:$(IMAGE_TAG) app/web

smoke: ## Business smoke on disposable DB: URL=http://...; STAFF=1 for controlled staff access
	@test -n "$(URL)" || (echo "Usage: make smoke URL=<url> [STAFF=1]" >&2; exit 2)
	bash scripts/smoke-test.sh "$(URL)" $(if $(filter 1,$(STAFF)),--staff,)

db-update: ## Refresh the vulnerability database from the official Trivy repository
	$(TRIVY) image --download-db-only --cache-dir "$(TRIVY_CACHE)" --db-repository ghcr.io/aquasecurity/trivy-db:2

scan: scan-api scan-web ## Scan both actual image IDs; use make -k scan to collect both failures

scan-api scan-web: ## Save JSON/table, immutable image identity, DB metadata and blocking exit status
	@mkdir -p "$(REPORT_DIR)"
	@test ! -e "$(REPORT_DIR)/$(patsubst scan-%,%,$@).json" || (echo "Choose a new REPORT_DIR; existing evidence is preserved" >&2; exit 2)
	@docker image inspect "clinicflow-$(patsubst scan-%,%,$@):$(IMAGE_TAG)" > "$(REPORT_DIR)/$(patsubst scan-%,%,$@)-identity.json"
	@image_id=$$(docker image inspect "clinicflow-$(patsubst scan-%,%,$@):$(IMAGE_TAG)" --format '{{.Id}}'); $(TRIVY) image --image-src docker --platform linux/amd64 --scanners vuln --severity HIGH,CRITICAL --exit-code 1 --db-repository ghcr.io/aquasecurity/trivy-db:2 --cache-dir "$(TRIVY_CACHE)" --format json --output "$(REPORT_DIR)/$(patsubst scan-%,%,$@).json" "$$image_id"; status=$$?; $(TRIVY) convert --format table --output "$(REPORT_DIR)/$(patsubst scan-%,%,$@).txt" "$(REPORT_DIR)/$(patsubst scan-%,%,$@).json" || exit $$?; cp "$(TRIVY_CACHE)/db/metadata.json" "$(REPORT_DIR)/$(patsubst scan-%,%,$@)-db.json" || exit $$?; $(TRIVY) --version --cache-dir "$(TRIVY_CACHE)" > "$(REPORT_DIR)/trivy-version.txt"; printf '\nImage ID: %s\nHIGH/CRITICAL gate exit code: %s (0 means no findings at these severities)\n' "$$image_id" "$$status" >> "$(REPORT_DIR)/$(patsubst scan-%,%,$@).txt"; echo "$$status" > "$(REPORT_DIR)/$(patsubst scan-%,%,$@)-exit-code.txt"; exit "$$status"

image-check: ## Lint Dockerfiles and existing shell entry points
	hadolint app/api/Dockerfile app/web/Dockerfile
	shellcheck scripts/*.sh

local-test: ## Run isolated disposable database and business checks against IMAGE_TAG
	python3 scripts/smoke-test.py --local-images "$(IMAGE_TAG)" --report-dir "$(REPORT_DIR)"
