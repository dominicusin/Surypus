---
inclusion: always
description: Enterprise governance — admin-controlled MCP registry, model registry, prompt logging, IdP
---
# Enterprise Governance

## MCP Registry (admin-controlled)
Approved MCP servers are listed at: [admin-hosted JSON URL]

Kiro fetches this allow-list every 24h and terminates any MCP server
not on the list. Do NOT manually add MCP servers without approval —
they will be auto-revoked.

To request a new MCP server: contact your Kiro admin.

## Model Registry (admin-controlled)
Approved models are listed at: [admin-hosted JSON URL]

Agent `model:` fields must reference an approved model ID. Off-policy
models will be silently rewritten to the org default.

## Prompt Logging
This workspace runs with prompt logging ENABLED for SOC2 / regulatory
auditability. All prompts and conversations are recorded by Kiro.

- Do NOT include secrets, PII, customer data, or production credentials
  in prompts.
- Use placeholders or test fixtures for sensitive examples.
- Reference `secrets/` files by path, never paste contents.

## Identity Provider
Authentication uses Okta.

- Sign in via the corporate IdP — never use personal accounts for
  enterprise workspaces.
- Token refresh and revocation are handled by the IdP. Sessions expire
  per org policy.

## What this means for agents
- Cite governance constraints in spec output when relevant (e.g. "this
  feature requires a new MCP — admin approval needed").
- Surface model/MCP gaps as questions, never silently substitute.
- Treat `audit.log` and `.kiro/sessions/` as evidence — do not delete.

## See also
- https://kiro.dev/docs/cli/enterprise/governance/mcp/
- https://kiro.dev/docs/cli/enterprise/governance/model/
- https://kiro.dev/docs/cli/enterprise/monitor-and-track/prompt-logging/
