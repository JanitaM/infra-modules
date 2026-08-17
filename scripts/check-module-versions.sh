#!/usr/bin/env bash
# Every modules/aws/*/versions.tf is supposed to be a byte-for-byte copy of
# the same terraform{required_version/required_providers} block (see
# context/project-overview.md, "Decisions made so far"). There's no
# Terraform mechanism to share it across independently git-ref-pinned
# modules, so this catches drift instead of trusting it never happens.
#
# examples/aws/* are excluded: they're root configs, not modules, and some
# (basic-site, webhook-handler) legitimately require an extra provider.
#
# Usage: check-module-versions.sh

set -euo pipefail

versions_files=(modules/aws/*/versions.tf)

if [[ ! -e "${versions_files[0]}" ]]; then
  echo "check-module-versions: no modules/aws/*/versions.tf files found" >&2
  exit 1
fi

canonical="${versions_files[0]}"
drift_found=0

for f in "${versions_files[@]}"; do
  if ! diff -q "$canonical" "$f" >/dev/null; then
    echo "check-module-versions: ${f} differs from ${canonical}:" >&2
    diff "$canonical" "$f" >&2 || true
    drift_found=1
  fi
done

if [[ "$drift_found" -ne 0 ]]; then
  exit 1
fi

echo "check-module-versions: OK — ${#versions_files[@]} module versions.tf files match ${canonical}"
