# Deprecation Policy

This document describes how we handle deprecations in Surypus.

## Why Deprecate?

Sometimes we need to remove or change features. Deprecation gives users time to adapt.

## Deprecation Process

### 1. Announce (Minor Version)

When deprecating a feature:

1. Add `@deprecated` annotation in code
2. Add deprecation notice in CHANGELOG.md
3. Provide migration guide in documentation
4. Announce on social media

### 2. Support (Next Major Version)

During the deprecation period:

1. Feature still works but shows deprecation warning
2. Documentation includes migration instructions
3. Both old and new approaches are documented

### 3. Remove (Next Major Version)

When removing a deprecated feature:

1. Remove code and documentation
2. Add note in CHANGELOG about removal
3. Provide clear error messages if feature is used

## Examples

### Deprecating a Function

```haskell
-- | Deprecated: Use 'newFunction' instead. Will be removed in v3.0.0.
oldFunction :: a -> b
oldFunction = deprecated "Use newFunction instead" . newFunction
```

### Deprecating a Module

```haskell
-- | Deprecated: Use 'NewModule' instead. Will be removed in v3.0.0.
module OldModule {-# DEPRECATED "Use NewModule instead" #-} where
```

## Timeline

| Action | Version | Timeline |
|--------|---------|----------|
| Announce | v2.x | Immediate |
| Support | v2.x+1 | 6-12 months |
| Remove | v3.0 | Next major |

## Exceptions

Security issues may be removed immediately without deprecation period.

---

*Last updated: 2026-09-03*
