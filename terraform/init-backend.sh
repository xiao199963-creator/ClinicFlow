#!/usr/bin/env bash
# Called with a bucket already approved for the chosen state root.
set -euo pipefail
if [[ $# -lt 2 || $# -gt 4 || -z ${2:-} ]]; then
  echo "Usage: $0 dev|staging|prod|platform STATE_BUCKET [REGION] [SHARED_KMS_KEY_ARN]" >&2
  exit 2
fi
case "$1" in
  dev|staging|prod) root="environments/$1" ;;
  platform) root="bootstrap/platform" ;;
  *) echo "Unknown Terraform root: $1" >&2; exit 2 ;;
esac
state_env=$1
state_bucket=$2
state_region=${3:-ap-southeast-2}
state_kms_key=${4:-}
cd "$(dirname "$0")/$root"
set -- terraform init -backend-config="bucket=$state_bucket" -backend-config="region=$state_region" \
  -backend-config="key=$state_env/terraform.tfstate"
if [[ -n $state_kms_key ]]; then
  set -- "$@" -backend-config="kms_key_id=$state_kms_key"
fi
exec "$@"
