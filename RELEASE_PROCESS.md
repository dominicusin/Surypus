# Release Process

This document describes the process for creating and publishing releases of Surypus.

## Release Schedule

We follow a time-based release schedule:

- **Patch releases** - As needed for bug fixes (ad-hoc)
- **Minor releases** - Monthly (first Monday of the month)
- **Major releases** - As needed for breaking changes (quarterly at most)

## Semantic Versioning

We follow [Semantic Versioning](https://semver.org/):

- **MAJOR** (X.0.0) - Breaking changes to public APIs
- **MINOR** (0.X.0) - New backwards-compatible functionality
- **PATCH** (0.0.X) - Backwards-compatible bug fixes

## Release Checklist

### Before Release

- [ ] All tests pass on CI
- [ ] Documentation is up to date
- [ ] CHANGELOG.md is updated with all changes
- [ ] Version number is bumped in relevant files
- [ ] Migration guide is written (for major releases)
- [ ] Release notes are drafted

### Release Day

1. **Create release branch** (if needed):
   ```bash
   git checkout -b release/vX.Y.Z
   ```

2. **Update version**:
   - Update version in `Surypus.cabal`
   - Update version in `package.yaml`
   - Update `CHANGELOG.md` with release date

3. **Create git tag**:
   ```bash
   git tag -a vX.Y.Z -m "Release vX.Y.Z"
   git push origin vX.Y.Z
   ```

4. **Create GitHub Release**:
   - Go to [Releases](https://github.com/surypus/surypus/releases)
   - Click "Draft a new release"
   - Select the tag
   - Add title and description
   - Attach binaries (if applicable)
   - Publish release

### After Release

- [ ] Upload to Hackage (if applicable)
- [ ] Build and push Docker image
- [ ] Announce on social media
- [ ] Update website
- [ ] Send newsletter (if applicable)

## Release Automation

We use GitHub Actions to automate parts of the release process:

- **CI** runs on every commit
- **Tests** must pass before merge
- **Build** artifacts are created automatically
- **Publish** to Hackage and Docker Hub is triggered by tags

## Hotfix Process

For critical security fixes:

1. Create hotfix branch from latest tag
2. Apply fix
3. Bump patch version
4. Create PR to main
5. After merge, create new patch release

## Deprecation Policy

When deprecating features:

1. Mark as deprecated in code with comments
2. Add deprecation notice in CHANGELOG
3. Provide migration guide
4. Remove in next major version

---

*Last updated: 2026-09-03*
