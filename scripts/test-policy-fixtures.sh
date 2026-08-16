#!/usr/bin/env bash
# Runs every fixture under policy/<provider>/testdata/<module>/ individually
# and checks its result against filename convention: allow.json must produce
# no violations, deny-*.json must produce at least one. `conftest test` on a
# whole directory can't make this distinction — it only reports one
# aggregate pass/fail for the batch, so an allow.json regression can hide
# behind an unrelated deny-*.json correctly failing (or vice versa). See
# README.md, "Testing policy rules".
#
# Usage: test-policy-fixtures.sh [provider]   (default: aws)

set -uo pipefail

provider="${1:-aws}"
policy_dir="policy/${provider}"
testdata_dir="${policy_dir}/testdata"

if [[ ! -d "$testdata_dir" ]]; then
  echo "test-policy-fixtures: no ${testdata_dir}, nothing to test"
  exit 0
fi

failures=0
checked=0

for fixture in "$testdata_dir"/*/*.json; do
  [[ -e "$fixture" ]] || continue
  checked=$((checked + 1))
  name=$(basename "$fixture")

  if conftest test --quiet --policy "$policy_dir" "$fixture" > /tmp/fixture-output.$$ 2>&1; then
    fired=0
  else
    fired=1
  fi

  if [[ "$name" == allow.json ]]; then
    if [[ "$fired" -ne 0 ]]; then
      echo "FAIL ${fixture}: expected no violation (allow.json), got one:"
      sed 's/^/    /' /tmp/fixture-output.$$
      failures=$((failures + 1))
    fi
  elif [[ "$name" == deny-*.json ]]; then
    if [[ "$fired" -ne 1 ]]; then
      echo "FAIL ${fixture}: expected a violation (deny-*.json), got none"
      failures=$((failures + 1))
    fi
  else
    echo "FAIL ${fixture}: fixture name must be 'allow.json' or 'deny-<reason>.json'"
    failures=$((failures + 1))
  fi

  rm -f /tmp/fixture-output.$$
done

echo
echo "test-policy-fixtures: ${checked} fixtures checked, ${failures} failed"

if [[ "$failures" -ne 0 ]]; then
  exit 1
fi
