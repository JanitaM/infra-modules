package main

import rego.v1

# codebuild module policy.
#
# Organized by security baseline intent (see project-overview.md's "Security
# baseline intents" table), matching global.rego's convention. This intent —
# build environments must not run privileged — is specific to CodeBuild
# projects, so it lives here rather than in global.rego.

# ---- Intent: build environments must not run in privileged mode ----

codebuild_privileged(project) if {
  some e in project.change.after.environment
  e.privileged_mode == true
}

deny contains msg if {
  project := input.resource_changes[_]
  project.type == "aws_codebuild_project"
  codebuild_privileged(project)

  msg := sprintf(
    "CodeBuild project '%s' has environment.privileged_mode = true, enabling Docker-in-Docker with container escape risk. Builds must not run privileged — see modules/aws/codebuild.",
    [project.address],
  )
}
