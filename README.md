# infra-modules

Reusable Terraform modules and Conftest/OPA policies, shared across projects and across clouds.

Two things live here, with two different versioning rules:

- **Modules** — versioned building blocks. Consuming projects pin them to a tag.
- **Policies** — mandatory security rules checked against `terraform plan` output before `apply`. Consuming projects always run the latest, never a pin.

Modules are grouped by provider. There are no cloud-agnostic modules that abstract over, say, S3 and GCS — the abstraction leaks, and the provider-specific settings are exactly what the policies need to inspect. What's shared across clouds is the pattern, not the resource code.

## Layout

```
modules/<provider>/<module>/     # e.g. modules/aws/s3-bucket
policy/<provider>/global.rego    # rules applying to every project on that provider
policy/<provider>/modules/       # rules for a specific module
examples/<provider>/             # working root configs
```

## Using a module

Pin to a tag. The provider is part of the path:

```hcl
module "images_bucket" {
  source      = "github.com/JanitaM/infra-modules//modules/aws/s3-bucket?ref=v1.0.0"
  bucket_name = "example-images"
}
```

## Declaring what you use

Every consuming project commits an `infra-modules.yml` at its root. Both fields are required:

```yaml
module_version: v1.0.0   # the tag every module source ref in this project pins to
providers:               # which policy sets apply
  - aws
```

`module_version` is a declaration, not an injection — Terraform `source` refs must be literal strings, so CI verifies that every ref in the project matches the declared version rather than rewriting them. `providers` selects which `policy/<provider>/` directories get loaded.

## The policy gate

CI runs `terraform plan`, exports it as JSON, clones this repo at `main`, and runs `conftest` against the policy directories named in the manifest. `apply` runs only if the check passes.

```yaml
- git clone https://github.com/JanitaM/infra-modules.git /tmp/infra-policy
- terraform show -json tfplan > plan.json
# one --policy flag per provider in infra-modules.yml
- conftest test --policy /tmp/infra-policy/policy/aws plan.json
```

The clone is unpinned on purpose: every project enforces current rules with no drift. A newly added rule can fail an existing project's next build, which is the intended tradeoff.

All rules are mandatory. There is no per-project opt-out.

## Testing policy rules

Each rule set has fixture plan JSON under `policy/<provider>/testdata/<module>/` — an `allow.json` that should produce no violations, and one `deny-<reason>.json` per failing case the rule checks. Fixtures are minimal hand-written fragments of `terraform show -json` output, just enough of `resource_changes` to exercise the rule; they are not real `terraform plan` output.

To spot-check one fixture against its rules:

```
conftest test --policy policy/aws policy/aws/testdata/<module>/allow.json
```

Don't run a whole `testdata/<module>/` directory through `conftest test` at once — `deny-*.json` fixtures are *supposed* to produce a violation, so batching them with `allow.json` collapses everything into one aggregate pass/fail and can hide a regression in either direction. `scripts/test-policy-fixtures.sh aws` runs every fixture individually and checks its result against the `allow`/`deny-*` filename convention; this is what CI runs.

When adding a new module's policy, add a matching `testdata/<module>/` directory alongside it, covering every intent the new `.rego` file checks.

## Testing module logic

Policy fixtures check plan output against security rules; they don't exercise a module's own logic — variable `validation` blocks, or resources gated behind `count`/`for_each`/a ternary. That's what `terraform test` (`.tftest.hcl`) covers, one `tests/` directory per module (`modules/aws/<module>/tests/<module>.tftest.hcl`), Terraform's own convention for test file discovery.

CI has no AWS credentials configured anywhere, so every test file must open with `mock_provider "aws" {}` — this mocks the provider entirely, so `command = plan` never makes a real API call. Requires Terraform >= 1.7 (see each module's `versions.tf`).

Two things worth testing per module:
- **Conditional resources/attributes**: a `run` block per branch, asserting the resulting plan looks right in each case. Set/list attributes (many AWS resource schemas represent repeated blocks as sets) usually need `tolist(...)` before indexing — Terraform will error with "Cannot index a set value" otherwise.
- **Variable validation**: a `run` block per `validation` rule, setting an input that should fail it and asserting with `expect_failures = [var.<name>]`.

`budget` (`modules/aws/budget/tests/budget.tftest.hcl`) is the reference implementation — one module's coverage, proven working in CI, before the rest get backfilled.

To run a module's tests locally:

```
cd modules/aws/<module> && terraform init -backend=false && terraform test
```

CI (`terraform-test` job) loops over every `modules/aws/*/tests/` directory that exists, so adding a new module's test coverage needs no CI change — just the directory.

## Static analysis

CI also runs [checkov](https://www.checkov.io/) against `modules/aws`, config at `.checkov.yaml`. This is a real blocking gate, not report-only — but checkov is a generic scanner, and this repo's policy is a curated set of rules each tied to a specific documented intent (see "Security baseline intents" in `context/project-overview.md`). Left un-configured, checkov flags plenty of things this repo never claimed to check (access logging, X-Ray tracing, VPC placement, and so on), so every skipped check in `.checkov.yaml` has an inline comment explaining why it's not a gap here — either architecturally not applicable, or an accepted default a consuming project can override.

When adding a module, run `checkov -d modules/aws --compact --quiet` before pushing. A new finding means either fixing it or adding a justified skip to `.checkov.yaml` — never a blanket suppression.

## Status

Early. See [context/project-overview.md](context/project-overview.md) for decisions, roadmap, and the security baseline intents that policy rules derive from.
