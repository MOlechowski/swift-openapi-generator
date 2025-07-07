# Template System Design for Swift OpenAPI Generator

## Executive Summary

This document outlines the design for adding a template-based code generation system to Apple's Swift OpenAPI Generator. The goal is to allow customization of generated code to meet specific architectural requirements (HLD compliance) while maintaining full backward compatibility with existing users.

## Problem Statement

Currently, Apple's Swift OpenAPI Generator produces fixed code patterns that don't align with specific HLD requirements. We need a template system (similar to OpenAPI Generator's mustache templates) to customize:

1. **API Endpoint Generation** - Replace Operations namespace with APIEndpoint protocol pattern
2. **Error Type Generation** - Implement two-level error architecture with RFC 9457 support
3. **Client Generation** - Use builder pattern instead of simple initializer

## Current Architecture Analysis

### Code Generation Pipeline

The generator follows a 3-stage compiler-like pipeline:

```
1. Parsing: Raw YAML/JSON → ParsedOpenAPIRepresentation (using OpenAPIKit)
2. Translation: ParsedOpenAPIRepresentation → StructuredSwiftRepresentation
3. Rendering: StructuredSwiftRepresentation → Raw Swift source code
```

### Key Components

- **GeneratorPipeline.swift**: Orchestrates the three stages
- **MultiplexTranslator**: Routes to appropriate translator based on mode (types/client/server)
- **FileTranslator**: Protocol for translators that generate specific files
- **TextBasedRenderer**: Converts structured Swift representation to text
- **StructuredSwiftRepresentation**: Low-level AST-like representation of Swift code

### Current Code Generation Approach

The system uses a low-level representation where Swift code is built from individual syntax elements:

```swift
// Current approach - very granular
Declaration.variable(
    accessModifier: .public,
    kind: .let,
    left: "userId",
    type: .member("String"),
    right: .literal("123")
)
```

## Proposed Template System Architecture

### Design Principles

1. **Backward Compatibility**: Template mode is opt-in, existing users unaffected
2. **Flexibility**: Support partial templating (some components templated, others standard)
3. **Maintainability**: Clear separation between standard and template paths
4. **Extensibility**: Easy to add new template engines or template types

### Dual Pipeline Support

Maintain existing pipeline while adding template path:

```
Standard Pipeline (Default):
OpenAPI → Parse → Translate → StructuredSwift → TextBasedRenderer → Swift Code

Template Pipeline (Opt-in):
OpenAPI → Parse → Translate → Template Context → StencilRenderer → Swift Code
```

### Template Engine Choice

**Stencil** is recommended because:
- Industry standard for Swift code generation (used by SwiftGen, Sourcery)
- Full-featured with inheritance, loops, conditionals
- Active maintenance and Swift ecosystem adoption
- StencilSwiftKit adds Swift-specific capabilities

### Implementation Components

#### 1. Configuration Extension

Extend `UserConfig.swift` to support template configuration:

```swift
struct _UserConfig: Codable {
    // Existing fields...
    
    /// Template configuration for custom code generation
    var templates: TemplateConfig?
    
    struct TemplateConfig: Codable {
        /// Enable template mode
        var enabled: Bool
        
        /// Path to templates directory
        var directory: String?
        
        /// Individual template files
        var endpoints: String?
        var errors: String?
        var client: String?
        var models: String?
        
        /// Component-level control
        var components: ComponentTemplates?
    }
    
    struct ComponentTemplates: Codable {
        var operations: String?
        var models: String?
        var apiProtocol: String?
    }
}
```

#### 2. High-Level Template Context Types

Create context types that match HLD requirements instead of low-level AST:

```swift
// Sources/_OpenAPIGeneratorCore/TemplateContexts/

struct EndpointContext {
    let name: String                        // "GetUser"
    let path: String                        // "/users/{userId}"
    let method: String                      // "GET"
    let pathParameters: [ParameterContext]
    let queryParameters: [ParameterContext]
    let headerParameters: [ParameterContext]
    let bodyType: String?
    let responseType: String
    let errorCases: [ErrorCaseContext]
    let acceptableContentTypes: [String]
}

struct ParameterContext {
    let name: String
    let originalName: String
    let type: String
    let required: Bool
    let defaultValue: String?
}

struct ErrorCaseContext {
    let name: String
    let statusCode: Int
    let errorType: String
    let description: String?
}

struct ClientBuilderContext {
    let clientName: String
    let baseURL: String
    let defaultHeaders: [HeaderContext]
    let middlewares: [String]
    let transportType: String
}

struct ModelContext {
    let name: String
    let properties: [PropertyContext]
    let conformances: [String]
}
```

#### 3. Template-Aware Translators

Modify existing translators to support both modes:

```swift
protocol TemplateAwareFileTranslator: FileTranslator {
    associatedtype Context: TemplateContext
    func translateToTemplateContext(parsedOpenAPI: ParsedOpenAPIRepresentation) throws -> Context
}

struct TemplateAwareClientTranslator: TemplateAwareFileTranslator {
    func translateFile(parsedOpenAPI: ParsedOpenAPIRepresentation) throws -> StructuredSwiftRepresentation {
        if config.templates?.enabled == true {
            // Generate minimal structure that signals template rendering
            let context = try translateToTemplateContext(parsedOpenAPI: parsedOpenAPI)
            return StructuredSwiftRepresentation(
                file: NamedFileDescription(
                    name: "Client.swift",
                    contents: FileDescription(
                        topComment: topComment,
                        imports: imports,
                        codeBlocks: [.templateMarker(context)]
                    )
                )
            )
        }
        // Existing implementation for standard generation
        return try existingTranslateFile(parsedOpenAPI: parsedOpenAPI)
    }
    
    func translateToTemplateContext(parsedOpenAPI: ParsedOpenAPIRepresentation) throws -> ClientTemplateContext {
        // Convert OpenAPI to high-level context
        let operations = try gatherOperations(from: parsedOpenAPI)
        let endpoints = try operations.map { operation in
            EndpointContext(
                name: operation.operationId.uppercasingFirstLetter(),
                path: operation.path,
                method: operation.method.rawValue,
                // ... map other fields
            )
        }
        
        return ClientTemplateContext(
            clientName: "Client",
            endpoints: endpoints,
            serverURLs: parsedOpenAPI.servers
        )
    }
}
```

#### 4. Stencil Renderer Implementation

```swift
import Stencil
import PathKit

struct StencilRenderer: RendererProtocol {
    let config: Config
    let templateLoader: FileSystemLoader
    let environment: Environment
    
    init(config: Config) throws {
        self.config = config
        
        let templateDirectory = config.templates?.directory ?? "./templates"
        let path = Path(templateDirectory)
        self.templateLoader = FileSystemLoader(paths: [path])
        
        // Configure Stencil environment with Swift-specific filters
        self.environment = Environment(
            loader: templateLoader,
            extensions: [StencilSwiftExtension()]
        )
    }
    
    func render(
        structured: StructuredSwiftRepresentation,
        config: Config,
        diagnostics: any DiagnosticCollector
    ) throws -> InMemoryOutputFile {
        // Extract template context from structured representation
        guard let templateContext = structured.extractTemplateContext() else {
            // Fallback to standard rendering if no template context
            return try TextBasedRenderer.default.render(
                structured: structured,
                config: config,
                diagnostics: diagnostics
            )
        }
        
        // Select template based on file type
        let templateName = selectTemplate(for: structured.file.name)
        
        // Render template
        let rendered = try environment.renderTemplate(
            name: templateName,
            context: templateContext.asDictionary()
        )
        
        return InMemoryOutputFile(
            baseName: structured.file.name,
            contents: Data(rendered.utf8)
        )
    }
    
    private func selectTemplate(for fileName: String) -> String {
        switch fileName {
        case "Client.swift":
            return config.templates?.client ?? "client/default.stencil"
        case "Types.swift":
            return config.templates?.endpoints ?? "types/default.stencil"
        default:
            return "default.stencil"
        }
    }
}
```

#### 5. Modified Pipeline Integration

Update the pipeline to support template rendering:

```swift
func makeGeneratorPipeline(
    parser: any ParserProtocol = YamsParser(),
    validator: @escaping (ParsedOpenAPIRepresentation, Config) throws -> [Diagnostic] = validateDoc,
    translator: any TranslatorProtocol = MultiplexTranslator(),
    renderer: any RendererProtocol? = nil,  // Allow override
    config: Config,
    diagnostics: any DiagnosticCollector
) -> GeneratorPipeline {
    
    // Choose renderer based on configuration
    let actualRenderer: any RendererProtocol
    if let providedRenderer = renderer {
        actualRenderer = providedRenderer
    } else if config.templates?.enabled == true {
        do {
            actualRenderer = try StencilRenderer(config: config)
        } catch {
            diagnostics.emit(.warning("Failed to initialize template renderer, falling back to standard", context: nil))
            actualRenderer = TextBasedRenderer.default
        }
    } else {
        actualRenderer = TextBasedRenderer.default
    }
    
    // Rest of pipeline setup remains the same
    return GeneratorPipeline(
        parseOpenAPIFileStage: ...,
        translateOpenAPIToStructuredSwiftStage: ...,
        renderSwiftFilesStage: .init(
            preTransitionHooks: [],
            transition: { input in
                try actualRenderer.render(
                    structured: input,
                    config: config,
                    diagnostics: diagnostics
                )
            },
            postTransitionHooks: []
        )
    )
}
```

### Template Structure

Organize templates to match the HLD requirements:

```
templates/
├── api/
│   ├── endpoint.stencil          # Individual endpoint structs
│   ├── api_protocol.stencil      # APIEndpoint protocol definition
│   └── operations.stencil        # Operations namespace (compatibility)
├── error/
│   ├── http_error.stencil        # HTTPError protocol (RFC 9457)
│   ├── network_error.stencil     # NativeNetworkLibError enum
│   └── operation_error.stencil   # Per-operation error enums
├── client/
│   ├── client.stencil            # Main client struct
│   ├── builder.stencil           # Client builder pattern
│   └── transport.stencil         # Transport configuration
├── model/
│   ├── model.stencil             # Data model structs
│   └── enum.stencil              # Enum types
└── shared/
    ├── header.stencil            # File headers and imports
    └── helpers.stencil           # Common template functions
```

### Example Templates

#### Endpoint Template (api/endpoint.stencil)

```stencil
{% for endpoint in endpoints %}
// MARK: - {{ endpoint.name }}

/// {{ endpoint.description | default: "Operation " + endpoint.name }}
public struct {{ endpoint.name }}: APIEndpoint, Sendable {
    public typealias Response = {{ endpoint.responseType }}
    {% if endpoint.errorCases %}
    public typealias EndpointError = {{ endpoint.name }}Error
    {% else %}
    public typealias EndpointError = Never
    {% endif %}
    
    // MARK: Parameters
    {% for param in endpoint.pathParameters %}
    public let {{ param.name }}: {{ param.type }}
    {% endfor %}
    {% for param in endpoint.queryParameters %}
    public let {{ param.name }}: {{ param.type }}{% if param.defaultValue %} = {{ param.defaultValue }}{% endif %}
    {% endfor %}
    
    // MARK: Request Properties
    public var path: String { 
        "{{ endpoint.path }}"
        {%- for param in endpoint.pathParameters -%}
            .replacingOccurrences(of: "{{"{{" }}{{ param.originalName }}{{ "}}" }}", with: "\({{ param.name }})")
        {%- endfor -%}
    }
    
    public var method: HTTPMethod { .{{ endpoint.method|lowercase }} }
    
    {% if endpoint.queryParameters %}
    public var queryParameters: [String: String] {
        var params: [String: String] = [:]
        {% for param in endpoint.queryParameters %}
        {% if param.required %}
        params["{{ param.originalName }}"] = String(describing: {{ param.name }})
        {% else %}
        if let {{ param.name }} = self.{{ param.name }} {
            params["{{ param.originalName }}"] = String(describing: {{ param.name }})
        }
        {% endif %}
        {% endfor %}
        return params
    }
    {% else %}
    public var queryParameters: [String: String] { [:] }
    {% endif %}
    
    {% if endpoint.headerParameters %}
    public var headers: [String: String] {
        var headers: [String: String] = [:]
        {% for header in endpoint.headerParameters %}
        headers["{{ header.originalName }}"] = {{ header.name }}
        {% endfor %}
        return headers
    }
    {% else %}
    public var headers: [String: String] { [:] }
    {% endif %}
    
    {% if endpoint.bodyType %}
    public let body: {{ endpoint.bodyType }}?
    {% else %}
    public var body: Never? { nil }
    {% endif %}
    
    // MARK: Initializer
    public init(
        {%- for param in endpoint.allParameters -%}
        {{ param.name }}: {{ param.type }}
        {%- if param.defaultValue %} = {{ param.defaultValue }}{% endif -%}
        {%- if not forloop.last %}, {% endif -%}
        {%- endfor -%}
        {%- if endpoint.bodyType -%}
        {%- if endpoint.allParameters %}, {% endif -%}
        body: {{ endpoint.bodyType }}? = nil
        {%- endif -%}
    ) {
        {% for param in endpoint.allParameters %}
        self.{{ param.name }} = {{ param.name }}
        {% endfor %}
        {% if endpoint.bodyType %}
        self.body = body
        {% endif %}
    }
}

{% if endpoint.errorCases %}
// MARK: - {{ endpoint.name }}Error

/// Errors specific to the {{ endpoint.name }} operation
public enum {{ endpoint.name }}Error: Error, Sendable {
    {% for error in endpoint.errorCases %}
    /// {{ error.description | default: "HTTP " + error.statusCode }}
    case {{ error.name }}({{ error.errorType }})
    {% endfor %}
}
{% endif %}

{% endfor %}
```

#### Error Template (error/http_error.stencil)

```stencil
// MARK: - HTTP Error Types

/// Two-level error architecture for network operations
public enum NativeNetworkLibError: Error, Sendable {
    /// HTTP-related errors with problem details
    case httpError(any HTTPError)
    
    /// Transport-level errors
    case transportError(TransportError)
}

/// RFC 9457 Problem Details for HTTP APIs
public protocol HTTPError: Codable, Sendable, Error {
    /// A URI reference that identifies the problem type
    var type: String { get }
    
    /// A short, human-readable summary of the problem type
    var title: String? { get }
    
    /// The HTTP status code
    var status: Int? { get }
    
    /// A human-readable explanation specific to this occurrence
    var detail: String? { get }
    
    /// A URI reference that identifies the specific occurrence
    var instance: String? { get }
}

/// Transport-level errors
public enum TransportError: Error, Sendable {
    case connectionFailed(Error)
    case timeout
    case invalidURL
    case noResponse
    case decodingFailed(Error)
}

{% for problemType in problemTypes %}
// MARK: - {{ problemType.name }}

/// {{ problemType.description }}
public struct {{ problemType.name }}: HTTPError {
    public let type: String = "{{ problemType.typeURI }}"
    public let title: String? = "{{ problemType.title }}"
    public let status: Int? = {{ problemType.statusCode }}
    public let detail: String?
    public let instance: String?
    
    {% for field in problemType.additionalFields %}
    public let {{ field.name }}: {{ field.type }}
    {% endfor %}
    
    public init(
        detail: String? = nil,
        instance: String? = nil
        {%- for field in problemType.additionalFields -%}
        , {{ field.name }}: {{ field.type }}
        {%- endfor -%}
    ) {
        self.detail = detail
        self.instance = instance
        {% for field in problemType.additionalFields %}
        self.{{ field.name }} = {{ field.name }}
        {% endfor %}
    }
}
{% endfor %}
```

#### Client Builder Template (client/builder.stencil)

```stencil
// MARK: - Client Builder

/// A builder for configuring and creating API clients
public final class {{ clientName }}Builder {
    private var baseURL: URL?
    private var timeout: TimeInterval = 30.0
    private var headers: [String: String] = [:]
    private var retryStrategy: RetryStrategy = .none
    private var connectionPool: ConnectionPoolStrategy = .default
    private var middlewares: [any ClientMiddleware] = []
    
    public init() {}
    
    // MARK: Configuration Methods
    
    @discardableResult
    public func withBaseURL(_ urlString: String) -> Self {
        self.baseURL = URL(string: urlString)
        return self
    }
    
    @discardableResult
    public func withBaseURL(_ url: URL) -> Self {
        self.baseURL = url
        return self
    }
    
    @discardableResult
    public func withDefaultTimeout(_ timeout: DefaultTimeout) -> Self {
        self.timeout = timeout.seconds
        return self
    }
    
    @discardableResult
    public func addDefaultHeader(_ name: String, _ value: String) -> Self {
        self.headers[name] = value
        return self
    }
    
    @discardableResult
    public func withRetryStrategy(_ strategy: RetryStrategy) -> Self {
        self.retryStrategy = strategy
        return self
    }
    
    @discardableResult
    public func withConnectionPool(_ strategy: ConnectionPoolStrategy) -> Self {
        self.connectionPool = strategy
        return self
    }
    
    @discardableResult
    public func addMiddleware(_ middleware: any ClientMiddleware) -> Self {
        self.middlewares.append(middleware)
        return self
    }
    
    // MARK: Build Method
    
    /// Builds the configured client
    /// - Throws: BuilderError if required configuration is missing
    public func build() throws -> {{ clientName }} {
        guard let baseURL = baseURL else {
            throw BuilderError.missingBaseURL
        }
        
        // Create transport with configuration
        let transportConfig = TransportConfiguration(
            timeout: timeout,
            retryStrategy: retryStrategy,
            connectionPool: connectionPool,
            defaultHeaders: headers
        )
        
        let transport = URLSessionTransport(configuration: transportConfig)
        
        return {{ clientName }}(
            serverURL: baseURL,
            transport: transport,
            middlewares: middlewares
        )
    }
}

// MARK: - Builder Types

public enum DefaultTimeout {
    case standard   // 30 seconds
    case extended   // 60 seconds
    case custom(TimeInterval)
    
    var seconds: TimeInterval {
        switch self {
        case .standard: return 30.0
        case .extended: return 60.0
        case .custom(let interval): return interval
        }
    }
}

public enum RetryStrategy {
    case none
    case linear(maxAttempts: Int)
    case exponentialBackoff(maxAttempts: Int, initialDelay: TimeInterval)
}

public enum ConnectionPoolStrategy {
    case `default`
    case low
    case high
    case custom(maxConnections: Int)
}

public enum BuilderError: Error {
    case missingBaseURL
}
```

### Configuration Examples

#### Basic Template Configuration

```yaml
# openapi-generator-config.yaml
generate:
  - types
  - client
accessModifier: public
additionalImports:
  - Foundation
  - MyCustomNetworking

# Enable templates
templates:
  enabled: true
  directory: ./templates
```

#### Advanced Template Configuration

```yaml
# openapi-generator-config.yaml
generate:
  - types
  - client

# Selective template usage
templates:
  enabled: true
  directory: ./custom-templates
  
  # Use templates for specific components
  endpoints: api/custom-endpoint.stencil
  errors: error/rfc9457-errors.stencil
  client: client/builder-pattern.stencil
  # models: null  # Use standard generation for models
  
  # Component-level control
  components:
    operations: api/operations-compat.stencil
    apiProtocol: api/protocol.stencil
```

#### Feature Flag Configuration

```yaml
# Use feature flag during development
featureFlags:
  - templateSupport

templates:
  enabled: true
  experimental: true  # Warning about experimental feature
```

### Partial Templating and Compatibility

#### Why Partial Templates Won't Break Existing Code

1. **File Independence**: Each generated file (Types, Client, Server) is independent
2. **Interface Contracts**: Templates must maintain expected type names and protocols
3. **Type Aliases**: Can bridge between new and old naming conventions

#### Compatibility Strategies

##### Strategy 1: File-Level Templating
Template entire files while keeping others standard:
```yaml
generate:
  - types    # Standard generation
  - client   # Template-based generation
```

##### Strategy 2: Component-Level Templating
Template specific components within a file:
```yaml
templates:
  components:
    operations: custom-operations.stencil  # Custom endpoint pattern
    models: null                          # Keep standard models
    apiProtocol: null                     # Keep standard protocol
```

##### Strategy 3: Compatibility Layer
Generate both patterns with type aliases:

```swift
// New HLD-compliant pattern
public struct GetUser: APIEndpoint { ... }

// Compatibility with existing code
public enum Operations {
    public enum getUser {
        public typealias Input = GetUserInput
        public typealias Output = GetUserOutput
    }
}
```

### Implementation Phases

#### Phase 1: Foundation (2-3 weeks)
1. Add Stencil dependency to Package.swift
2. Extend Config and UserConfig with template settings
3. Create basic TemplateContext types
4. Implement StencilRenderer with basic functionality
5. Add feature flag for experimental template support

#### Phase 2: Template Context Generation (3-4 weeks)
1. Create template-aware translators
2. Implement context extraction from OpenAPI
3. Design high-level context types for each component
4. Add template marker to StructuredSwiftRepresentation

#### Phase 3: Template Development (2-3 weeks)
1. Create default templates matching current output
2. Develop HLD-compliant templates
3. Add template validation and error handling
4. Implement template helper functions

#### Phase 4: Integration and Testing (2-3 weeks)
1. Integrate template renderer into pipeline
2. Add comprehensive test coverage
3. Create example projects using templates
4. Document template system usage

#### Phase 5: Polish and Release (1-2 weeks)
1. Performance optimization
2. Error message improvements
3. Documentation and tutorials
4. Migration guide for users

### Testing Strategy

#### Unit Tests
- Template context generation
- Template rendering
- Configuration parsing
- Compatibility layer

#### Integration Tests
- End-to-end generation with templates
- Partial template application
- Template error handling
- Standard/template mode switching

#### Compatibility Tests
- Generated code works with existing clients
- Type alias bridges function correctly
- No breaking changes in standard mode

### Documentation Requirements

1. **Template System Guide**
   - Overview and concepts
   - Configuration options
   - Template syntax basics
   - Common patterns

2. **Template Reference**
   - Available context objects
   - Template helpers and filters
   - Example templates

3. **Migration Guide**
   - Moving from standard to templates
   - Compatibility strategies
   - Gradual adoption path

4. **Template Development**
   - Creating custom templates
   - Testing templates
   - Best practices

### Benefits of This Approach

1. **Zero Breaking Changes**: Existing users unaffected
2. **Gradual Adoption**: Can template incrementally
3. **Flexibility**: Full control over generated code
4. **Maintainability**: Templates easier to modify than code generation logic
5. **Community**: Can share templates for common patterns

### Potential Challenges and Mitigations

| Challenge | Mitigation |
|-----------|------------|
| Template complexity | Provide comprehensive examples and documentation |
| Performance impact | Cache compiled templates, benchmark regularly |
| Type safety | Generate compatibility tests, validate output |
| Version compatibility | Version templates with generator |
| Debugging difficulty | Add template debug mode, clear error messages |

### Future Enhancements

1. **Multiple Template Engines**: Support for Mustache, Liquid
2. **Template Marketplace**: Community template sharing
3. **Live Preview**: Real-time template preview in development
4. **Template Composition**: Reusable template components
5. **Custom Filters**: User-defined Stencil filters

## Conclusion

This template system design provides a path to customize Swift OpenAPI Generator output while maintaining complete backward compatibility. The approach balances flexibility with safety, allowing gradual adoption and experimentation without disrupting existing users.

The implementation can proceed in phases, with early phases providing value even before full completion. The system is designed to grow with user needs while keeping complexity manageable.