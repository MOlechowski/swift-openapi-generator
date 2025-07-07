# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Building and Testing
- `swift build` - Build the main package
- `swift test` - Run all tests
- `swift test --filter <test_name>` - Run specific test
- `swift build --build-tests` - Build tests without running them

### Example Projects
- `./scripts/test-examples.sh` - Test all example projects
- `SINGLE_EXAMPLE_PACKAGE=<name> ./scripts/test-examples.sh` - Test specific example
- `./scripts/run-integration-test.sh` - Run integration tests

### Manual Generator CLI
- `swift run swift-openapi-generator generate --help` - Show CLI options
- `swift run swift-openapi-generator generate --config <config> --output-directory <dir> <openapi.yaml>` - Generate code

### Plugin Development
- Plugin tests are in `Tests/OpenAPIGeneratorTests/`
- Core tests are in `Tests/OpenAPIGeneratorCoreTests/`
- Reference tests are in `Tests/OpenAPIGeneratorReferenceTests/`

## High-Level Architecture

### Code Generation Pipeline
The generator follows a 3-stage compiler-like pipeline (defined in `GeneratorPipeline.swift`):
1. **Parsing**: Raw OpenAPI YAML/JSON → Parsed OpenAPI (using OpenAPIKit)
2. **Translation**: Parsed OpenAPI → Structured Swift representation
3. **Rendering**: Structured Swift → Raw Swift source code

### Generator Modes
The generator can produce three types of files (`GeneratorMode`):
- **Types**: API protocol, reusable types, operation namespaces
- **Client**: Client implementation that calls transport layer
- **Server**: Server handler registration methods

### Key Components

#### Core Generation (`Sources/_OpenAPIGeneratorCore/`)
- `Translator/` - Converts OpenAPI spec to Swift representations
  - `ClientTranslator/` - Generates client code
  - `ServerTranslator/` - Generates server code  
  - `TypesTranslator/` - Generates shared types
  - `CommonTranslations/` - Shared translation logic
- `Parser/` - Parses OpenAPI documents using Yams
- `Renderer/` - Converts structured Swift to source code
- `TypeAssignment/` - Manages Swift type naming and resolution

#### CLI Tool (`Sources/swift-openapi-generator/`)
- `Tool.swift` - Main CLI entry point with subcommands
- `GenerateCommand.swift` - Code generation command
- `FilterCommand.swift` - Document filtering command

#### Plugins (`Plugins/`)
- `OpenAPIGenerator/` - Build-time plugin for Swift Package Manager
- `OpenAPIGeneratorCommand/` - Command plugin for manual generation
- Shared utilities in `PluginsShared/`

### Transport Layer Architecture
The generator produces code that works with transport abstractions:
- **ClientTransport**: HTTP client abstraction (URLSession, AsyncHTTPClient)
- **ServerTransport**: Web framework abstraction (Vapor, Hummingbird)
- Generated code is decoupled from specific HTTP implementations

### Testing Strategy
- **Unit Tests**: Test individual components in isolation
- **Reference Tests**: Generate code from OpenAPI specs and verify output
- **Integration Tests**: Test end-to-end with real HTTP transports
- **Example Tests**: Verify all example projects build and work correctly

### Configuration
- `openapi-generator-config.yaml` - Controls what gets generated
- Supports filtering operations, customizing output, feature flags
- Examples in `Examples/` directory show various configurations

## Development Notes

### Working with Examples
Each example in `Examples/` is a standalone Swift package demonstrating different use cases. They use package dependencies to reference the main generator.

### Reference Test Workflow
When modifying translation logic, update reference tests in `Tests/OpenAPIGeneratorReferenceTests/Resources/ReferenceSources/` to match expected output.

### Feature Flags
New features are gated behind feature flags in `FeatureFlags.swift` to ensure backward compatibility during development.

## Git Conventions

@.rules/git/commit-conventions.md

### Project-Specific Scopes
- `template`: Template system changes
- `generator`: Core generator logic
- `parser`: OpenAPI parsing
- `translator`: Translation layer
- `renderer`: Code rendering
- `config`: Configuration handling
- `plugin`: SPM plugin changes
- `cli`: Command-line interface