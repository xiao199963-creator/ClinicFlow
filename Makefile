.DEFAULT_GOAL := help
.PHONY: help fmt validate build smoke scan scan-api scan-web db-update image-check

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

export URL
smoke: ## Post-deploy smoke: URL=<controlled-url>; use BASIC=1 for the partial public check
	@bash scripts/smoke-test.sh "$$URL" $(if $(filter 1,$(BASIC)),--basic,)

db-update: ## Refresh the vulnerability database from the official Trivy repository
	$(TRIVY) image --download-db-only --cache-dir "$(TRIVY_CACHE)" --db-repository ghcr.io/aquasecurity/trivy-db:2

scan: scan-api scan-web ## Scan both actual image IDs; use make -k scan to collect both failures

# Validate scanner coverage before exporting allowlisted artifact fields.
image_summary = if .Metadata.ImageID == $$id and .Metadata.OS.Family == "alpine" \
    and (.Metadata.OS.Name | test("^3\\.24([.]|$$)")) \
    and any(.Results[]; .Class == "os-pkgs" and .Type == "alpine" and (.Packages | length) > 0) \
    and ($$tier != "api" or any(.Results[]; .Type == "python-pkg" and (.Packages | length) > 0)) \
  then {image: $$id, os: .Metadata.OS.Name, high: ([.Results[].Vulnerabilities[]? | select(.Severity=="HIGH")] | length), \
    critical: ([.Results[].Vulnerabilities[]? | select(.Severity=="CRITICAL")] | length), \
    cves: ([.Results[].Vulnerabilities[]?.VulnerabilityID | select(test("^CVE-[0-9]{4}-[0-9]{4,}$$"))] | unique)} \
  else error("Image identity or supported package inventory missing") end

scan-api scan-web: ## Save JSON/table, immutable image identity, DB metadata and blocking exit status
	@mkdir -p "$(REPORT_DIR)"
	@test ! -e "$(REPORT_DIR)/$(patsubst scan-%,%,$@).json" || (echo "Choose a new REPORT_DIR; existing evidence is preserved" >&2; exit 2)
	@docker image inspect "clinicflow-$(patsubst scan-%,%,$@):$(IMAGE_TAG)" > "$(REPORT_DIR)/$(patsubst scan-%,%,$@)-identity.json"
	@set -eu; \
	tier="$(patsubst scan-%,%,$@)"; base="$(REPORT_DIR)/$$tier"; \
	image_id=$$(jq -er '.[0].Id' "$$base-identity.json"); \
	status=0; \
	$(TRIVY) image --image-src docker --platform linux/amd64 --scanners vuln \
	  --pkg-types os,library --list-all-pkgs --severity HIGH,CRITICAL --exit-code 1 --exit-on-eol 1 \
	  --db-repository ghcr.io/aquasecurity/trivy-db:2 --cache-dir "$(TRIVY_CACHE)" \
	  --format json --output "$$base.json" "$$image_id" || status=$$?; \
	echo "$$status" > "$$base-exit-code.txt"; \
	$(TRIVY) convert --format table --output "$$base.txt" "$$base.json"; \
	cp "$(TRIVY_CACHE)/db/metadata.json" "$$base-db.json"; \
	jq -e '.Version == 2 and (.NextUpdate | sub("\\.[0-9]+Z$$"; "Z") | fromdateiso8601) > now' "$$base-db.json" >/dev/null; \
	$(TRIVY) --version --cache-dir "$(TRIVY_CACHE)" > "$(REPORT_DIR)/trivy-version.txt"; \
	jq -e --arg id "$$image_id" --arg tier "$$tier" '$(image_summary)' "$$base.json" > "$$base-summary.json"; \
	printf '\nImage ID: %s\nTrivy exit: %s\n' "$$image_id" "$$status" >> "$$base.txt"; \
	cat "$$base-summary.json"; exit "$$status"

image-check: ## Lint Dockerfiles and existing shell entry points
	hadolint app/api/Dockerfile app/web/Dockerfile
	shellcheck terraform/init-backend.sh scripts/*.sh
