#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
terraform fmt -check -recursive terraform
for root in environments/dev environments/staging environments/prod bootstrap/state bootstrap/platform bootstrap/budget; do
  terraform -chdir="terraform/$root" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="terraform/$root" validate -no-color
done
