# Security Policy

## Scope

This repo ships Terraform modules (`modules/`) and Conftest/OPA policy rules (`policy/`) that other projects pin to and run against their infrastructure. A security issue here means either:

- A module provisions something insecure by default (e.g. a resource that should be private/encrypted and isn't).
- A policy rule fails to catch a case it claims to check, letting an insecure plan pass the gate.

## Reporting a vulnerability

Use GitHub's private vulnerability reporting: **Security tab → "Report a vulnerability"** on this repo. Don't open a public issue for a real finding — that discloses it before a fix ships.

## Response expectations

This is a solo-maintainer project. Reports are handled best-effort; there's no formal SLA.

## Fix process

Security fixes go through the same PR + CI gate as any other change — see [README.md's "Contributing" section](README.md#contributing). Branch protection applies to every change, security fixes included.
