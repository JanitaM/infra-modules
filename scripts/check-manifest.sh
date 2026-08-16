#!/usr/bin/env bash
# Validates a consuming project's infra-modules.yml and verifies every
# module `source` ref's ?ref= matches the declared module_version. See
# context/project-overview.md, "How a consuming project uses this repo".
#
# Usage: check-manifest.sh [path-to-project-root]   (default: .)

set -euo pipefail

project_dir="${1:-.}"
manifest="${project_dir}/infra-modules.yml"

if [[ ! -f "$manifest" ]]; then
  echo "check-manifest: no infra-modules.yml found at ${manifest}" >&2
  exit 1
fi

module_version=$(grep -E '^module_version:' "$manifest" | head -n1 | sed -E 's/^module_version:[[:space:]]*//' | tr -d '"'"'"' \r')

if [[ -z "$module_version" ]]; then
  echo "check-manifest: ${manifest} is missing a non-empty 'module_version' field" >&2
  exit 1
fi

providers=$(awk '
  /^providers:/ { in_providers = 1; next }
  in_providers && /^[^[:space:]]/ { in_providers = 0 }
  in_providers && /^[[:space:]]*-[[:space:]]*/ {
    sub(/^[[:space:]]*-[[:space:]]*/, "")
    gsub(/["'"'"']/, "")
    gsub(/[[:space:]]+$/, "")
    if (length($0) > 0) print
  }
' "$manifest")

if [[ -z "$providers" ]]; then
  echo "check-manifest: ${manifest} is missing a non-empty 'providers' list" >&2
  exit 1
fi

mismatch_found=0

while IFS= read -r match; do
  [[ -z "$match" ]] && continue
  file="${match%%:*}"
  rest="${match#*:}"
  line_no="${rest%%:*}"
  line_content="${rest#*:}"

  ref=$(echo "$line_content" | grep -oE '\?ref=[^"'"'"']+' | sed -E 's/^\?ref=//')

  if [[ -z "$ref" ]]; then
    echo "check-manifest: ${file}:${line_no} sources infra-modules without a ?ref= pin" >&2
    mismatch_found=1
  elif [[ "$ref" != "$module_version" ]]; then
    echo "check-manifest: ${file}:${line_no} pins ref '${ref}', but manifest declares module_version '${module_version}'" >&2
    mismatch_found=1
  fi
done < <(grep -rnE 'source[[:space:]]*=[[:space:]]*"[^"]*github\.com/JanitaM/infra-modules//modules/' "$project_dir" --include='*.tf' || true)

if [[ "$mismatch_found" -ne 0 ]]; then
  exit 1
fi

echo "check-manifest: OK — module_version '${module_version}', providers [${providers//$'\n'/, }], all source refs match"
