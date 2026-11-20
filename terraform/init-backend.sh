#!/bin/sh
# Usage: sh terraform/init-backend.sh dev|staging|prod|platform STATE_BUCKET [REGION]
set -eu
if [ "$#" -lt 2 ] || [ "$#" -gt 3 ] || [ -z "$2" ]; then
  echo "Usage: $0 dev|staging|prod|platform STATE_BUCKET [REGION]" >&2
  exit 2
fi
case "$1" in
  dev|staging|prod) root="environments/$1" ;;
  platform) root="bootstrap/platform" ;;
  *) echo "Unknown Terraform root: $1" >&2; exit 2 ;;
esac
cd "$(dirname "$0")/$root"
exec terraform init -backend-config="bucket=$2" -backend-config="region=${3:-ap-southeast-2}" \
  -backend-config="key=$1/terraform.tfstate"
