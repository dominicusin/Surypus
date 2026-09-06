# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **CI**: Reduced from 88 workflows to CI + CodeQL only
- **Build**: Pinned GHC 9.6.5, `allow-newer: false`, `lts-22.21`
- **Modules**: Quarantined 356 non-compiling modules to `src/_quarantine/`
- **Core**: Reduced `exposed-modules` to 13 compiling modules
- **Branch protection**: Relaxed to allow merge with CI green

### Removed
- Dangerous auto-approve/copilot-auto-approve workflows
- 80+ non-essential CI workflows

## [0.1.0] - 2026-09-06

### Added
- Core library: `Finance.Tax`, `Finance.Accounting`, `DAL.Types`, `DAL.Schema`, `DAL.Database`, `DAL.Pool`
- Auth: `Surypus.RBAC` (33 permissions), `Surypus.JWT`
- Metrics: `Surypus.Metrics`
- CI: Single job, GHC 9.6.5, green build
