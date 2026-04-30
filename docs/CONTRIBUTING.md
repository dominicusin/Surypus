# Contributing to Surypus

## Development Setup

### Prerequisites

- GHC 9.6.6
- Stack
- PostgreSQL 14+

### Building

```bash
stack build
```

### Testing

```bash
stack test
```

### Running

```bash
stack exec surypus
```

## Code Style

- Follow Haskell conventions
- Use meaningful names
- Add comments for complex logic
- Keep functions small and focused

## Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `stack test`
5. Commit and push
6. Create a Pull Request

## Project Structure

```
src/
├── Core/           # Business logic
├── DB/             # Database layer
├── Domain/         # Domain models
├── APIServer.hs    # REST API
└── Surypus/        # Core modules
```

## Testing

Run all tests:
```bash
stack test
```

Run specific test file:
```bash
stack test --test-show-details=always
```

## Questions

For questions, please open an issue on GitHub.
