# GitHub Copilot Customization for Surypus

## Custom Instructions

Create `.github/copilot-instructions.md` to customize Copilot for the project:

```markdown
# Copilot Instructions for Surypus

## Project Overview

Surypus is a Haskell ERP/CRM system with formal verification. Primary language is Haskell with GHC 9.6.6+.

## Code Style

- Use Haskell2010 standard
- Follow fourmolu formatting rules
- Use 2-space indentation
- Maximum line length: 100 characters
- Use explicit imports (no wildcard imports)

## Naming Conventions

- Modules: PascalCase (e.g., `Core.Tax`, `DAL.Queries`)
- Types: PascalCase (e.g., `TaxRate`, `LedgerEntry`)
- Functions: camelCase (e.g., `calcVAT`, `validateTaxRate`)
- Record fields: camelCase (e.g., `trId`, `trName`)

## Architecture

- Core/ - Domain logic (no database dependencies)
- DAL/ - Database access layer
- Surypus/ - Utilities and common types
- API/ - REST API handlers

## Testing

- Use Hspec for unit tests
- Use QuickCheck for property-based tests
- Place tests in test/ directory
- Mirror source file structure

## Documentation

- Add Haddock comments to all public functions
- Use `-- |` for function documentation
- Use `-- ^` for parameter documentation

## Security

- Never log sensitive data
- Validate all inputs at API boundary
- Use parameterized queries (no SQL injection)
- Check permissions for all operations

## Performance

- Use Text instead of String for user data
- Use Int64 for database IDs
- Consider lazy vs strict evaluation
- Profile before optimizing
```

## Repository Configuration

To enable these instructions, create `.github/copilot-instructions.md` in the repository root.
