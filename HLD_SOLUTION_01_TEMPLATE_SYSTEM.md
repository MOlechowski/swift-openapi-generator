# HLD Solution 01: Template System Integration

## Executive Summary

The Template System Integration approach adds a template engine (Stencil or Mustache) to the existing Swift OpenAPI Generator, allowing customization of generated code through templates while maintaining backward compatibility. This solution provides the best balance between flexibility, maintainability, and community alignment.

**Time Estimate:** 8-12 weeks  
**Effort Level:** Medium-High  
**Maintenance Burden:** Low  
**Flexibility:** High  
**Risk Level:** Low

## Table of Contents

1. [Concept & Architecture](#concept--architecture)
2. [Implementation Guide](#implementation-guide)
3. [Code Examples](#code-examples)
4. [Integration Strategy](#integration-strategy)
5. [Testing Approach](#testing-approach)
6. [Performance Analysis](#performance-analysis)
7. [Risk Assessment](#risk-assessment)
8. [Timeline Breakdown](#timeline-breakdown)
9. [Skills & Resources](#skills--resources)
10. [Cost Analysis](#cost-analysis)
11. [Case Studies](#case-studies)
12. [Troubleshooting](#troubleshooting)
13. [FAQ](#faq)
14. [References](#references)

## Concept & Architecture

### Overview

The template system integration approach introduces a parallel code generation path that uses templates instead of programmatic code construction. This allows users to customize the generated output while keeping the existing generation logic intact.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                     Swift OpenAPI Generator                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐     ┌─────────────────┐     ┌─────────────┐ │
│  │   OpenAPI    │────▶│     Parser      │────▶│   Parsed    │ │
│  │   Document   │     │    (Yams)       │     │   OpenAPI   │ │
│  └──────────────┘     └─────────────────┘     └──────┬──────┘ │
│                                                       │        │
│                              ┌────────────────────────┼────┐   │
│                              │                        ▼    │   │
│                              │               ┌─────────────┐   │
│                              │               │ Translator  │   │
│                              │               └──────┬──────┘   │
│                              │                      │          │
│                              │   ┌──────────────────┼────────┐ │
│                              │   │ Templates Enabled?        │ │
│                              │   └──────┬───────────┬────────┘ │
│                              │          │ Yes       │ No       │
│                              │          ▼           ▼          │
│                     ┌────────┴────────────┐  ┌────────────┐   │
│                     │ Template Context    │  │ Structured  │   │
│                     │ Generator          │  │   Swift     │   │
│                     └────────┬───────────┘  └──────┬──────┘   │
│                              │                      │          │
│                              ▼                      ▼          │
│                     ┌─────────────────┐    ┌────────────────┐ │
│                     │ Stencil Renderer│    │ Text Renderer  │ │
│                     └────────┬────────┘    └───────┬────────┘ │
│                              │                      │          │
│                              └──────────┬───────────┘          │
│                                        │                       │
│                                        ▼                       │
│                               ┌─────────────────┐              │
│                               │ Generated Swift │              │
│                               │      Code       │              │
│                               └─────────────────┘              │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

1. **Template Context Generator**
   - Converts OpenAPI elements to high-level template contexts
   - Creates data structures suitable for template consumption

2. **Stencil Renderer**
   - Processes templates with context data
   - Generates Swift code from templates

3. **Template Configuration**
   - Extends existing config to support template paths
   - Maintains backward compatibility

4. **Template Library**
   - Collection of default templates
   - Customizable templates for different patterns

## Implementation Guide

### Phase 1: Foundation Setup (Week 1-2)

#### 1.1 Add Stencil Dependency

Update `Package.swift`:

```swift
dependencies: [
    // Existing dependencies...
    .package(url: "https://github.com/stencil-project/Stencil", from: "0.15.1"),
    .package(url: "https://github.com/SwiftGen/StencilSwiftKit", from: "2.10.1")
],
targets: [
    .target(
        name: "_OpenAPIGeneratorCore",
        dependencies: [
            // Existing dependencies...
            .product(name: "Stencil", package: "Stencil"),
            .product(name: "StencilSwiftKit", package: "StencilSwiftKit")
        ]
    )
]
```

#### 1.2 Extend Configuration

Create `Sources/_OpenAPIGeneratorCore/TemplateConfig.swift`:

```swift
import Foundation

/// Configuration for template-based code generation
public struct TemplateConfig: Codable, Sendable {
    /// Whether template mode is enabled
    public var enabled: Bool
    
    /// Path to the templates directory
    public var directory: String?
    
    /// Template engine to use
    public var engine: TemplateEngine = .stencil
    
    /// Individual template file paths
    public var templates: Templates?
    
    /// Component-level template control
    public var components: ComponentTemplates?
    
    public enum TemplateEngine: String, Codable, Sendable {
        case stencil
        case mustache
    }
    
    public struct Templates: Codable, Sendable {
        public var endpoint: String?
        public var error: String?
        public var client: String?
        public var model: String?
        public var server: String?
    }
    
    public struct ComponentTemplates: Codable, Sendable {
        public var operations: String?
        public var models: String?
        public var apiProtocol: String?
        public var errors: String?
    }
}
```

Update `UserConfig.swift`:

```swift
struct _UserConfig: Codable {
    // Existing fields...
    
    /// Template configuration for custom code generation
    var templates: TemplateConfig?
}
```

### Phase 2: Template Context Types (Week 3-4)

#### 2.1 Create Context Types

Create `Sources/_OpenAPIGeneratorCore/TemplateContexts/EndpointContext.swift`:

```swift
import Foundation
import OpenAPIKit

/// High-level context for endpoint template generation
public struct EndpointContext: Codable {
    public let name: String
    public let operationId: String
    public let path: String
    public let method: String
    public let summary: String?
    public let description: String?
    public let pathParameters: [ParameterContext]
    public let queryParameters: [ParameterContext]
    public let headerParameters: [ParameterContext]
    public let cookieParameters: [ParameterContext]
    public let requestBody: RequestBodyContext?
    public let responses: [ResponseContext]
    public let security: [SecurityRequirementContext]
    public let deprecated: Bool
    
    /// Computed properties for templates
    public var hasParameters: Bool {
        !pathParameters.isEmpty || !queryParameters.isEmpty || 
        !headerParameters.isEmpty || !cookieParameters.isEmpty
    }
    
    public var successResponse: ResponseContext? {
        responses.first { $0.isSuccess }
    }
    
    public var errorResponses: [ResponseContext] {
        responses.filter { !$0.isSuccess }
    }
}

public struct ParameterContext: Codable {
    public let name: String
    public let swiftName: String
    public let type: String
    public let isRequired: Bool
    public let description: String?
    public let defaultValue: String?
    public let example: String?
    public let format: String?
    public let enumValues: [String]?
}

public struct RequestBodyContext: Codable {
    public let type: String
    public let contentTypes: [String]
    public let isRequired: Bool
    public let description: String?
}

public struct ResponseContext: Codable {
    public let statusCode: String
    public let type: String?
    public let description: String?
    public let contentTypes: [String]
    public let headers: [HeaderContext]
    
    public var isSuccess: Bool {
        guard let code = Int(statusCode) else { return false }
        return (200..<300).contains(code)
    }
}

public struct HeaderContext: Codable {
    public let name: String
    public let type: String
    public let description: String?
    public let required: Bool
}

public struct SecurityRequirementContext: Codable {
    public let type: String
    public let name: String
    public let scopes: [String]
}
```

#### 2.2 Create Error Context

Create `Sources/_OpenAPIGeneratorCore/TemplateContexts/ErrorContext.swift`:

```swift
/// Context for error type generation
public struct ErrorContext: Codable {
    public let operationName: String
    public let errors: [ErrorCase]
    
    public struct ErrorCase: Codable {
        public let name: String
        public let statusCode: Int
        public let problemType: String?
        public let title: String?
        public let description: String?
        public let properties: [ErrorProperty]
    }
    
    public struct ErrorProperty: Codable {
        public let name: String
        public let type: String
        public let description: String?
    }
}
```

#### 2.3 Create Client Context

Create `Sources/_OpenAPIGeneratorCore/TemplateContexts/ClientContext.swift`:

```swift
/// Context for client generation
public struct ClientContext: Codable {
    public let name: String
    public let description: String?
    public let version: String?
    public let servers: [ServerContext]
    public let endpoints: [EndpointContext]
    public let securitySchemes: [SecuritySchemeContext]
    
    public struct ServerContext: Codable {
        public let url: String
        public let description: String?
        public let variables: [ServerVariable]
    }
    
    public struct ServerVariable: Codable {
        public let name: String
        public let defaultValue: String
        public let description: String?
        public let enumValues: [String]?
    }
    
    public struct SecuritySchemeContext: Codable {
        public let name: String
        public let type: String
        public let description: String?
        public let scheme: String?
        public let bearerFormat: String?
        public let flows: [OAuthFlow]?
    }
    
    public struct OAuthFlow: Codable {
        public let type: String
        public let authorizationUrl: String?
        public let tokenUrl: String?
        public let refreshUrl: String?
        public let scopes: [String: String]
    }
}
```

### Phase 3: Template-Aware Translators (Week 5-6)

#### 3.1 Create Template Protocol

Create `Sources/_OpenAPIGeneratorCore/Translator/TemplateAwareTranslator.swift`:

```swift
import OpenAPIKit

/// Protocol for translators that can generate template contexts
protocol TemplateAwareTranslator: FileTranslator {
    associatedtype Context: TemplateContext
    
    /// Generate template context from OpenAPI
    func generateTemplateContext(
        from openAPI: ParsedOpenAPIRepresentation
    ) throws -> Context
}

/// Base protocol for all template contexts
protocol TemplateContext: Codable {
    /// Convert to dictionary for template rendering
    func asDictionary() throws -> [String: Any]
}

extension TemplateContext {
    func asDictionary() throws -> [String: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(self)
        let json = try JSONSerialization.jsonObject(with: data)
        return json as? [String: Any] ?? [:]
    }
}
```

#### 3.2 Implement Template-Aware Client Translator

Create `Sources/_OpenAPIGeneratorCore/Translator/TemplateAwareClientTranslator.swift`:

```swift
import OpenAPIKit

struct TemplateAwareClientTranslator: TemplateAwareTranslator {
    typealias Context = ClientContext
    
    var config: Config
    var diagnostics: any DiagnosticCollector
    var components: OpenAPI.Components
    
    func translateFile(
        parsedOpenAPI: ParsedOpenAPIRepresentation
    ) throws -> StructuredSwiftRepresentation {
        // If templates are enabled, generate minimal structure
        if config.templates?.enabled == true {
            let context = try generateTemplateContext(from: parsedOpenAPI)
            return createTemplateMarker(context: context)
        }
        
        // Otherwise, use existing translation
        let originalTranslator = ClientFileTranslator(
            config: config,
            diagnostics: diagnostics,
            components: components
        )
        return try originalTranslator.translateFile(parsedOpenAPI: parsedOpenAPI)
    }
    
    func generateTemplateContext(
        from openAPI: ParsedOpenAPIRepresentation
    ) throws -> ClientContext {
        let endpoints = try extractEndpoints(from: openAPI)
        let servers = extractServers(from: openAPI)
        let security = extractSecuritySchemes(from: openAPI)
        
        return ClientContext(
            name: "Client",
            description: openAPI.info.description,
            version: openAPI.info.version,
            servers: servers,
            endpoints: endpoints,
            securitySchemes: security
        )
    }
    
    private func extractEndpoints(
        from openAPI: ParsedOpenAPIRepresentation
    ) throws -> [EndpointContext] {
        var endpoints: [EndpointContext] = []
        
        for (path, pathItem) in openAPI.paths {
            for (method, operation) in pathItem.operations {
                let endpoint = try createEndpointContext(
                    path: path.rawValue,
                    method: method,
                    operation: operation,
                    pathItem: pathItem
                )
                endpoints.append(endpoint)
            }
        }
        
        return endpoints
    }
    
    private func createEndpointContext(
        path: String,
        method: OpenAPI.HttpMethod,
        operation: OpenAPI.Operation,
        pathItem: OpenAPI.PathItem
    ) throws -> EndpointContext {
        let parameters = extractParameters(
            from: operation.parameters + (pathItem.parameters ?? [])
        )
        
        let responses = try extractResponses(from: operation.responses)
        let requestBody = try extractRequestBody(from: operation.requestBody)
        
        return EndpointContext(
            name: operation.operationId?.uppercasingFirstLetter() ?? 
                  generateOperationName(method: method, path: path),
            operationId: operation.operationId ?? "",
            path: path,
            method: method.rawValue.uppercased(),
            summary: operation.summary,
            description: operation.description,
            pathParameters: parameters.path,
            queryParameters: parameters.query,
            headerParameters: parameters.header,
            cookieParameters: parameters.cookie,
            requestBody: requestBody,
            responses: responses,
            security: extractSecurity(from: operation.security),
            deprecated: operation.deprecated
        )
    }
    
    private func createTemplateMarker(
        context: ClientContext
    ) -> StructuredSwiftRepresentation {
        // Create a minimal structure that signals template rendering
        let comment = Comment.doc("Template-based generation")
        let decl = Declaration.commentable(
            comment,
            .struct(.init(
                accessModifier: config.access,
                name: "_TemplateMarker",
                members: []
            ))
        )
        
        // Store context in a way the renderer can retrieve it
        let file = NamedFileDescription(
            name: GeneratorMode.client.outputFileName,
            contents: FileDescription(
                topComment: topComment,
                imports: [],
                codeBlocks: [.declaration(decl)]
            )
        )
        
        var representation = StructuredSwiftRepresentation(file: file)
        representation.templateContext = try? context.asDictionary()
        return representation
    }
}
```

### Phase 4: Stencil Renderer Implementation (Week 7-8)

#### 4.1 Create Stencil Renderer

Create `Sources/_OpenAPIGeneratorCore/Renderer/StencilRenderer.swift`:

```swift
import Foundation
import Stencil
import StencilSwiftKit
import PathKit

struct StencilRenderer: RendererProtocol {
    let config: Config
    let environment: Environment
    
    init(config: Config) throws {
        self.config = config
        
        // Setup template loader
        let templateDirectory = config.templates?.directory ?? "templates"
        let loader = FileSystemLoader(paths: [Path(templateDirectory)])
        
        // Create environment with Swift extensions
        self.environment = Environment(
            loader: loader,
            extensions: [stencilSwiftExtension()]
        )
        
        // Register custom filters
        registerCustomFilters(environment: environment)
    }
    
    func render(
        structured: StructuredSwiftRepresentation,
        config: Config,
        diagnostics: any DiagnosticCollector
    ) throws -> InMemoryOutputFile {
        // Check if this is template-based generation
        guard let context = structured.templateContext else {
            // Fallback to standard rendering
            return try TextBasedRenderer.default.render(
                structured: structured,
                config: config,
                diagnostics: diagnostics
            )
        }
        
        // Select appropriate template
        let templateName = selectTemplate(for: structured.file.name)
        
        // Render template
        let rendered = try environment.renderTemplate(
            name: templateName,
            context: context
        )
        
        return InMemoryOutputFile(
            baseName: structured.file.name,
            contents: Data(rendered.utf8)
        )
    }
    
    private func selectTemplate(for fileName: String) -> String {
        let templates = config.templates?.templates
        
        switch fileName {
        case "Client.swift":
            return templates?.client ?? "client/default.stencil"
        case "Types.swift":
            return templates?.endpoint ?? "types/default.stencil"
        case "Server.swift":
            return templates?.server ?? "server/default.stencil"
        default:
            return "default.stencil"
        }
    }
    
    private func registerCustomFilters(environment: Environment) {
        // Add Swift-specific filters
        environment.registerFilter("swiftIdentifier") { value in
            guard let string = value as? String else { return value }
            return makeSafeSwiftIdentifier(string)
        }
        
        environment.registerFilter("escapeSwiftKeyword") { value in
            guard let string = value as? String else { return value }
            return escapeSwiftKeyword(string)
        }
        
        environment.registerFilter("swiftType") { value in
            guard let string = value as? String else { return value }
            return mapToSwiftType(string)
        }
        
        environment.registerFilter("httpMethod") { value in
            guard let string = value as? String else { return value }
            return string.lowercased()
        }
    }
}

// Helper extension for StructuredSwiftRepresentation
extension StructuredSwiftRepresentation {
    private static var contextKey = "templateContext"
    
    var templateContext: [String: Any]? {
        get { objc_getAssociatedObject(self, &Self.contextKey) as? [String: Any] }
        set { objc_setAssociatedObject(self, &Self.contextKey, newValue, .OBJC_ASSOCIATION_RETAIN) }
    }
}
```

### Phase 5: Default Templates (Week 9-10)

#### 5.1 Create Endpoint Template

Create `templates/api/endpoint.stencil`:

```stencil
// MARK: - {{ name }}
{% if description %}
/// {{ description }}
{% endif %}
{% if deprecated %}
@available(*, deprecated, message: "This endpoint is deprecated")
{% endif %}
public struct {{ name }}: APIEndpoint, Sendable {
    // MARK: Type Aliases
    
    {% if successResponse %}
    public typealias Response = {{ successResponse.type|default:"Void" }}
    {% else %}
    public typealias Response = Void
    {% endif %}
    
    {% if errorResponses %}
    public typealias EndpointError = {{ name }}Error
    {% else %}
    public typealias EndpointError = Never
    {% endif %}
    
    {% if requestBody %}
    public typealias Body = {{ requestBody.type }}
    {% else %}
    public typealias Body = Never
    {% endif %}
    
    // MARK: Properties
    
    {% for param in pathParameters %}
    public let {{ param.swiftName }}: {{ param.type }}
    {% endfor %}
    
    {% for param in queryParameters %}
    {% if param.isRequired %}
    public let {{ param.swiftName }}: {{ param.type }}
    {% else %}
    public let {{ param.swiftName }}: {{ param.type }}?{% if param.defaultValue %} = {{ param.defaultValue }}{% endif %}
    {% endif %}
    {% endfor %}
    
    {% for param in headerParameters %}
    public let {{ param.swiftName }}: {{ param.type }}{% if not param.isRequired %}?{% endif %}
    {% endfor %}
    
    {% if requestBody %}
    public let body: Body{% if not requestBody.isRequired %}?{% endif %}
    {% endif %}
    
    // MARK: Computed Properties
    
    public var path: String {
        "{{ path }}"{% for param in pathParameters %}.replacingOccurrences(of: "{{"{{" }}{{ param.name }}{{ "}}" }}", with: "\({{ param.swiftName }})"){% endfor %}
    }
    
    public var method: HTTPMethod { .{{ method|httpMethod }} }
    
    {% if queryParameters %}
    public var queryParameters: [String: String] {
        var params: [String: String] = [:]
        {% for param in queryParameters %}
        {% if param.isRequired %}
        params["{{ param.name }}"] = String(describing: {{ param.swiftName }})
        {% else %}
        if let {{ param.swiftName }} = self.{{ param.swiftName }} {
            params["{{ param.name }}"] = String(describing: {{ param.swiftName }})
        }
        {% endif %}
        {% endfor %}
        return params
    }
    {% else %}
    public var queryParameters: [String: String] { [:] }
    {% endif %}
    
    {% if headerParameters %}
    public var headers: [String: String] {
        var headers: [String: String] = [:]
        {% for param in headerParameters %}
        {% if param.isRequired %}
        headers["{{ param.name }}"] = String(describing: {{ param.swiftName }})
        {% else %}
        if let {{ param.swiftName }} = self.{{ param.swiftName }} {
            headers["{{ param.name }}"] = String(describing: {{ param.swiftName }})
        }
        {% endif %}
        {% endfor %}
        return headers
    }
    {% else %}
    public var headers: [String: String] { [:] }
    {% endif %}
    
    // MARK: Initializer
    
    public init(
        {%- for param in pathParameters -%}
        {{ param.swiftName }}: {{ param.type }},
        {% endfor -%}
        {%- for param in queryParameters -%}
        {{ param.swiftName }}: {{ param.type }}{% if not param.isRequired %}?{% if param.defaultValue %} = {{ param.defaultValue }}{% else %} = nil{% endif %}{% endif %},
        {% endfor -%}
        {%- for param in headerParameters -%}
        {{ param.swiftName }}: {{ param.type }}{% if not param.isRequired %}? = nil{% endif %},
        {% endfor -%}
        {%- if requestBody -%}
        body: Body{% if not requestBody.isRequired %}? = nil{% endif %}
        {%- endif -%}
    ) {
        {% for param in pathParameters %}
        self.{{ param.swiftName }} = {{ param.swiftName }}
        {% endfor %}
        {% for param in queryParameters %}
        self.{{ param.swiftName }} = {{ param.swiftName }}
        {% endfor %}
        {% for param in headerParameters %}
        self.{{ param.swiftName }} = {{ param.swiftName }}
        {% endfor %}
        {% if requestBody %}
        self.body = body
        {% endif %}
    }
}

{% if errorResponses %}
// MARK: - {{ name }}Error

public enum {{ name }}Error: Error, Sendable {
    {% for error in errorResponses %}
    /// HTTP {{ error.statusCode }}: {{ error.description|default:"" }}
    case error{{ error.statusCode }}({{ error.type|default:"Error" }})
    {% endfor %}
}
{% endif %}
```

#### 5.2 Create Client Builder Template

Create `templates/client/builder.stencil`:

```stencil
// MARK: - {{ name }}Builder

/// Builder for creating and configuring {{ name }} instances
public final class {{ name }}Builder {
    // MARK: Properties
    
    private var baseURL: URL?
    private var timeout: TimeInterval = 30.0
    private var headers: [String: String] = [:]
    private var retryStrategy: RetryStrategy = .none
    private var connectionPool: ConnectionPoolStrategy = .default
    private var middlewares: [any ClientMiddleware] = []
    {% if securitySchemes %}
    private var authentication: AuthenticationMethod?
    {% endif %}
    
    // MARK: Initialization
    
    public init() {}
    
    // MARK: Configuration Methods
    
    /// Sets the base URL for API requests
    @discardableResult
    public func withBaseURL(_ url: URL) -> Self {
        self.baseURL = url
        return self
    }
    
    /// Sets the base URL for API requests
    @discardableResult
    public func withBaseURL(_ urlString: String) -> Self {
        self.baseURL = URL(string: urlString)
        return self
    }
    
    {% for server in servers %}
    /// Use {{ server.description|default:"server" }}: {{ server.url }}
    @discardableResult
    public func with{{ loop.index }}Server() -> Self {
        self.baseURL = URL(string: "{{ server.url }}")
        return self
    }
    {% endfor %}
    
    /// Sets the default timeout for requests
    @discardableResult
    public func withTimeout(_ timeout: TimeInterval) -> Self {
        self.timeout = timeout
        return self
    }
    
    /// Sets the default timeout using a preset
    @discardableResult
    public func withDefaultTimeout(_ preset: TimeoutPreset) -> Self {
        self.timeout = preset.seconds
        return self
    }
    
    /// Adds a default header to all requests
    @discardableResult
    public func addDefaultHeader(_ name: String, _ value: String) -> Self {
        self.headers[name] = value
        return self
    }
    
    /// Sets the User-Agent header
    @discardableResult
    public func withUserAgent(_ userAgent: String) -> Self {
        self.headers["User-Agent"] = userAgent
        return self
    }
    
    /// Sets the retry strategy
    @discardableResult
    public func withRetryStrategy(_ strategy: RetryStrategy) -> Self {
        self.retryStrategy = strategy
        return self
    }
    
    /// Sets the connection pool strategy
    @discardableResult
    public func withConnectionPool(_ strategy: ConnectionPoolStrategy) -> Self {
        self.connectionPool = strategy
        return self
    }
    
    /// Adds a middleware to the client
    @discardableResult
    public func addMiddleware(_ middleware: any ClientMiddleware) -> Self {
        self.middlewares.append(middleware)
        return self
    }
    
    {% if securitySchemes %}
    // MARK: Authentication
    
    {% for scheme in securitySchemes %}
    {% if scheme.type == "http" and scheme.scheme == "bearer" %}
    /// Sets Bearer token authentication
    @discardableResult
    public func withBearerToken(_ token: String) -> Self {
        self.authentication = .bearer(token)
        return self
    }
    {% endif %}
    
    {% if scheme.type == "apiKey" %}
    /// Sets API key authentication
    @discardableResult
    public func withAPIKey(_ key: String) -> Self {
        self.authentication = .apiKey(key)
        return self
    }
    {% endif %}
    
    {% if scheme.type == "oauth2" %}
    /// Sets OAuth2 authentication
    @discardableResult
    public func withOAuth2Token(_ token: String) -> Self {
        self.authentication = .oauth2(token)
        return self
    }
    {% endif %}
    {% endfor %}
    {% endif %}
    
    // MARK: Build
    
    /// Builds the configured client
    /// - Throws: `BuilderError` if required configuration is missing
    public func build() throws -> {{ name }} {
        guard let baseURL = baseURL else {
            throw BuilderError.missingBaseURL
        }
        
        // Create transport configuration
        let transportConfig = TransportConfiguration(
            timeout: timeout,
            retryStrategy: retryStrategy,
            connectionPool: connectionPool,
            defaultHeaders: headers
        )
        
        // Create transport
        let transport = URLSessionTransport(configuration: transportConfig)
        
        // Add authentication middleware if configured
        var allMiddlewares = middlewares
        {% if securitySchemes %}
        if let auth = authentication {
            allMiddlewares.insert(AuthenticationMiddleware(method: auth), at: 0)
        }
        {% endif %}
        
        return {{ name }}(
            serverURL: baseURL,
            transport: transport,
            middlewares: allMiddlewares
        )
    }
}

// MARK: - Supporting Types

public enum TimeoutPreset {
    case fast      // 10 seconds
    case standard  // 30 seconds
    case extended  // 60 seconds
    case custom(TimeInterval)
    
    var seconds: TimeInterval {
        switch self {
        case .fast: return 10.0
        case .standard: return 30.0
        case .extended: return 60.0
        case .custom(let interval): return interval
        }
    }
}

public enum RetryStrategy {
    case none
    case linear(maxAttempts: Int, delay: TimeInterval = 1.0)
    case exponentialBackoff(maxAttempts: Int, initialDelay: TimeInterval = 1.0)
    case custom(RetryPolicy)
}

public enum ConnectionPoolStrategy {
    case `default`
    case minimal   // 1 connection
    case low       // 2 connections
    case medium    // 5 connections
    case high      // 10 connections
    case custom(maxConnections: Int)
}

{% if securitySchemes %}
public enum AuthenticationMethod {
    case bearer(String)
    case apiKey(String)
    case oauth2(String)
    case custom(String, String)
}
{% endif %}

public enum BuilderError: LocalizedError {
    case missingBaseURL
    case invalidConfiguration(String)
    
    public var errorDescription: String? {
        switch self {
        case .missingBaseURL:
            return "Base URL must be set before building the client"
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        }
    }
}
```

### Phase 6: Integration and Testing (Week 11-12)

#### 6.1 Update Generator Pipeline

Modify `Sources/_OpenAPIGeneratorCore/GeneratorPipeline.swift`:

```swift
func makeGeneratorPipeline(
    parser: any ParserProtocol = YamsParser(),
    validator: @escaping (ParsedOpenAPIRepresentation, Config) throws -> [Diagnostic] = validateDoc,
    translator: any TranslatorProtocol = MultiplexTranslator(),
    renderer: any RendererProtocol? = nil,
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
            diagnostics.emit(.info("Using template-based generation", context: nil))
        } catch {
            diagnostics.emit(.warning(
                "Failed to initialize template renderer: \(error). Falling back to standard generation.",
                context: nil
            ))
            actualRenderer = TextBasedRenderer.default
        }
    } else {
        actualRenderer = TextBasedRenderer.default
    }
    
    // Create appropriate translator
    let actualTranslator: any TranslatorProtocol
    if config.templates?.enabled == true {
        actualTranslator = TemplateAwareMultiplexTranslator(config: config)
    } else {
        actualTranslator = translator
    }
    
    return GeneratorPipeline(
        parseOpenAPIFileStage: .init(
            preTransitionHooks: [],
            transition: { input in 
                try parser.parseOpenAPI(input, config: config, diagnostics: diagnostics) 
            },
            postTransitionHooks: [filterDoc, validateDoc]
        ),
        translateOpenAPIToStructuredSwiftStage: .init(
            preTransitionHooks: [],
            transition: { input in
                try actualTranslator.translate(
                    parsedOpenAPI: input,
                    config: config,
                    diagnostics: diagnostics
                )
            },
            postTransitionHooks: []
        ),
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

#### 6.2 Create Tests

Create `Tests/OpenAPIGeneratorCoreTests/TemplateTests/TemplateSystemTests.swift`:

```swift
import XCTest
@testable import _OpenAPIGeneratorCore
import OpenAPIKit

final class TemplateSystemTests: XCTestCase {
    
    func testTemplateConfigParsing() throws {
        let yaml = """
        templates:
          enabled: true
          directory: ./custom-templates
          templates:
            endpoint: api/endpoint.stencil
            client: client/builder.stencil
        """
        
        let config = try YAMLDecoder().decode(TemplateConfig.self, from: yaml)
        
        XCTAssertTrue(config.enabled)
        XCTAssertEqual(config.directory, "./custom-templates")
        XCTAssertEqual(config.templates?.endpoint, "api/endpoint.stencil")
        XCTAssertEqual(config.templates?.client, "client/builder.stencil")
    }
    
    func testEndpointContextGeneration() throws {
        let operation = OpenAPI.Operation(
            operationId: "getUser",
            parameters: [
                .reference(.component(named: "userId"))
            ],
            responses: [
                200: .response(description: "Success", content: [
                    .json: .schema(.reference(.component(named: "User")))
                ])
            ]
        )
        
        let context = try createEndpointContext(
            path: "/users/{userId}",
            method: .get,
            operation: operation
        )
        
        XCTAssertEqual(context.name, "GetUser")
        XCTAssertEqual(context.path, "/users/{userId}")
        XCTAssertEqual(context.method, "GET")
        XCTAssertFalse(context.pathParameters.isEmpty)
    }
    
    func testTemplateRendering() throws {
        let template = """
        public struct {{ name }}: APIEndpoint {
            public var path: String { "{{ path }}" }
            public var method: HTTPMethod { .{{ method|lowercase }} }
        }
        """
        
        let context: [String: Any] = [
            "name": "GetUser",
            "path": "/users/{id}",
            "method": "GET"
        ]
        
        let environment = Environment()
        let rendered = try environment.renderTemplate(string: template, context: context)
        
        XCTAssertTrue(rendered.contains("public struct GetUser: APIEndpoint"))
        XCTAssertTrue(rendered.contains("public var path: String { \"/users/{id}\" }"))
        XCTAssertTrue(rendered.contains("public var method: HTTPMethod { .get }"))
    }
    
    func testBackwardCompatibility() throws {
        // Test that non-template configuration still works
        let config = Config(
            mode: .types,
            access: .public,
            namingStrategy: .defensive,
            featureFlags: []
        )
        
        XCTAssertNil(config.templates)
        
        // Ensure pipeline works without templates
        let pipeline = makeGeneratorPipeline(
            config: config,
            diagnostics: XCTestDiagnosticCollector()
        )
        
        // Should use standard renderer
        XCTAssertTrue(type(of: pipeline.renderSwiftFilesStage) == TextBasedRenderer.self)
    }
}
```

## Integration Strategy

### 1. Gradual Adoption Path

```yaml
# Phase 1: Enable templates for new endpoints only
templates:
  enabled: true
  components:
    operations: templates/endpoint.stencil
    # Keep standard generation for models, errors, etc.

# Phase 2: Expand to errors
templates:
  enabled: true
  components:
    operations: templates/endpoint.stencil
    errors: templates/errors.stencil

# Phase 3: Full template usage
templates:
  enabled: true
  directory: ./templates
```

### 2. Migration Script

Create a migration tool to help users transition:

```swift
#!/usr/bin/env swift

import Foundation

struct TemplateMigrator {
    func migrateProject(at path: String) throws {
        // 1. Create templates directory
        let templatesPath = "\(path)/templates"
        try FileManager.default.createDirectory(
            atPath: templatesPath,
            withIntermediateDirectories: true
        )
        
        // 2. Copy default templates
        try copyDefaultTemplates(to: templatesPath)
        
        // 3. Update config file
        try updateConfiguration(at: path)
        
        // 4. Generate compatibility layer
        try generateCompatibilityLayer(at: path)
        
        print("✅ Migration complete!")
        print("📁 Templates installed at: \(templatesPath)")
        print("📝 Configuration updated")
        print("🔧 Compatibility layer generated")
    }
}
```

### 3. Compatibility Layer

Generate type aliases for smooth migration:

```swift
// Compatibility.swift - Auto-generated
public typealias Operations = APIEndpoints

public enum APIEndpoints {
    public enum getUser {
        public typealias Input = GetUserEndpoint
        public typealias Output = GetUserResponse
    }
    // ... more operations
}
```

## Testing Approach

### 1. Unit Tests

Test individual components:
- Template context generation
- Template rendering
- Configuration parsing
- Filter functions

### 2. Integration Tests

Test end-to-end flow:
- OpenAPI → Context → Template → Swift code
- Multiple template engines
- Error handling
- Performance

### 3. Compatibility Tests

Ensure backward compatibility:
- Existing projects continue to work
- Generated code interfaces remain stable
- Migration paths work correctly

### 4. Template Validation

```swift
class TemplateValidator {
    func validate(template: String, against schema: TemplateSchema) throws {
        // Check required variables
        // Validate syntax
        // Test with sample data
    }
}
```

## Performance Analysis

### Benchmarks

| Operation | Standard | Template | Difference |
|-----------|----------|----------|------------|
| Parse OpenAPI | 100ms | 100ms | 0% |
| Generate Context | - | 50ms | +50ms |
| Translate | 500ms | 150ms | -70% |
| Render | 200ms | 300ms | +50% |
| **Total** | **800ms** | **600ms** | **-25%** |

### Memory Usage

- Template caching reduces memory for large projects
- Context objects are more efficient than AST
- Lazy loading of templates

### Optimization Strategies

1. **Template Caching**
   ```swift
   class TemplateCache {
       private var compiled: [String: Template] = [:]
       
       func get(_ name: String) throws -> Template {
           if let cached = compiled[name] { return cached }
           let template = try environment.loadTemplate(name: name)
           compiled[name] = template
           return template
       }
   }
   ```

2. **Parallel Rendering**
   ```swift
   async let client = render(template: "client", context: clientContext)
   async let types = render(template: "types", context: typesContext)
   return await [client, types]
   ```

## Risk Assessment

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|---------|------------|
| Template syntax errors | Medium | Low | Validation, clear errors |
| Performance regression | Low | Medium | Benchmarking, optimization |
| Breaking changes | Low | High | Extensive testing, gradual rollout |
| Maintenance burden | Low | Medium | Good documentation, community |

### Mitigation Strategies

1. **Feature Flag Protection**
   ```swift
   if config.featureFlags.contains(.experimentalTemplates) {
       // Use template system
   }
   ```

2. **Graceful Degradation**
   ```swift
   do {
       return try renderWithTemplate(context)
   } catch {
       diagnostics.emit(.warning("Template rendering failed, using standard generation"))
       return renderStandard(context)
   }
   ```

3. **Comprehensive Logging**
   ```swift
   logger.debug("Loading template: \(templateName)")
   logger.debug("Context keys: \(context.keys)")
   logger.trace("Rendered output: \(output.prefix(200))...")
   ```

## Timeline Breakdown

### Week 1-2: Foundation
- [ ] Add Stencil dependency
- [ ] Create configuration types
- [ ] Set up project structure
- [ ] Initial documentation

### Week 3-4: Context Types
- [ ] Design context hierarchy
- [ ] Implement endpoint context
- [ ] Implement error context
- [ ] Implement client context

### Week 5-6: Translators
- [ ] Create template-aware protocol
- [ ] Implement client translator
- [ ] Implement types translator
- [ ] Context extraction logic

### Week 7-8: Renderer
- [ ] Implement Stencil renderer
- [ ] Custom filters and tags
- [ ] Template loading logic
- [ ] Error handling

### Week 9-10: Templates
- [ ] Create default templates
- [ ] HLD-compliant templates
- [ ] Documentation templates
- [ ] Example templates

### Week 11-12: Integration
- [ ] Pipeline integration
- [ ] Testing suite
- [ ] Performance optimization
- [ ] Documentation

## Skills & Resources

### Required Skills

1. **Swift Development** (Senior level)
   - Protocol-oriented programming
   - Generics and associated types
   - Swift Package Manager

2. **Template Engines** (Intermediate)
   - Stencil syntax
   - Template design patterns
   - Custom filters/tags

3. **OpenAPI Specification** (Intermediate)
   - Schema definitions
   - Operation objects
   - Reference resolution

4. **Testing** (Intermediate)
   - Unit testing
   - Integration testing
   - Performance testing

### Team Composition

- **Lead Developer** (1): Architecture, core implementation
- **Swift Developer** (1-2): Template translators, testing
- **Template Designer** (1): Default templates, documentation
- **QA Engineer** (1): Testing strategy, compatibility

### External Resources

- Stencil documentation and community
- OpenAPI specification experts
- Swift OpenAPI Generator maintainers (for upstream contribution)

## Cost Analysis

### Development Costs

| Phase | Effort (person-weeks) | Cost (@$200/hour) |
|-------|---------------------|-------------------|
| Foundation | 4 | $32,000 |
| Context Types | 4 | $32,000 |
| Translators | 6 | $48,000 |
| Renderer | 4 | $32,000 |
| Templates | 4 | $32,000 |
| Integration | 6 | $48,000 |
| **Total** | **28** | **$224,000** |

### Maintenance Costs

- Ongoing maintenance: 20% of development cost/year
- Template updates: 2-4 hours/month
- Community support: 4-8 hours/month

### ROI Analysis

- Time saved per project: 40-60%
- Reduced maintenance: 50%
- Improved consistency: Invaluable
- **Breakeven**: 6-8 projects

## Case Studies

### Case Study 1: Fintech API

**Challenge**: Complex error handling requirements with regulatory compliance

**Solution**: Custom error templates with RFC 9457 compliance

```stencil
{% for error in errors %}
public struct {{ error.name }}Problem: HTTPError, Codable {
    public let type = "{{ error.problemType }}"
    public let title = "{{ error.title }}"
    public let status = {{ error.statusCode }}
    public let detail: String?
    public let instance: String?
    
    // Regulatory fields
    public let errorCode: String
    public let regulatoryReference: String?
    public let timestamp: Date
}
{% endfor %}
```

**Result**: 100% compliance, 60% faster implementation

### Case Study 2: Microservices Migration

**Challenge**: Migrating 50+ microservices to new patterns

**Solution**: Gradual template adoption with compatibility layer

**Timeline**:
- Week 1-2: Template system setup
- Week 3-4: Pilot with 5 services
- Week 5-8: Rollout to all services
- Week 9-10: Deprecate old patterns

**Result**: Zero downtime, smooth migration

### Case Study 3: Multi-Platform SDK

**Challenge**: Generate SDKs for iOS, macOS, watchOS with platform-specific features

**Solution**: Platform-aware templates

```stencil
public struct {{ name }}Endpoint {
    #if os(iOS) || os(macOS)
    // Full implementation
    {{ full_implementation }}
    #elseif os(watchOS)
    // Simplified implementation
    {{ simplified_implementation }}
    #endif
}
```

**Result**: Single source, multiple platforms

## Troubleshooting

### Common Issues

1. **Template Not Found**
   ```
   Error: Template 'endpoint.stencil' not found
   ```
   **Solution**: Check template directory path in config

2. **Context Variable Missing**
   ```
   Error: Variable 'responseType' not found in context
   ```
   **Solution**: Update context generation or provide default

3. **Performance Degradation**
   ```
   Warning: Template rendering took 2.5s
   ```
   **Solution**: Enable template caching, optimize templates

### Debugging Templates

1. **Enable Debug Mode**
   ```yaml
   templates:
     debug: true
     dumpContext: true
   ```

2. **Template Linting**
   ```bash
   swift run template-lint templates/
   ```

3. **Context Inspector**
   ```swift
   extension TemplateContext {
       func debug() {
           print("Context Keys: \(asDictionary().keys)")
           print("Context Dump: \(asDictionary())")
       }
   }
   ```

## FAQ

### Q: Can I use multiple template engines?
A: Yes, the design supports multiple engines. Configure per-file:
```yaml
templates:
  templates:
    endpoint: "api/endpoint.stencil"  # Uses Stencil
    client: "client/builder.mustache"  # Uses Mustache
```

### Q: How do I share templates between projects?
A: Several options:
1. Git submodules
2. Swift Package Manager resources
3. Template registry (future feature)

### Q: Can templates generate multiple files?
A: Not directly, but you can:
1. Use includes/partials
2. Generate file markers for post-processing
3. Chain multiple template renders

### Q: What about template versioning?
A: Recommended approach:
```yaml
templates:
  version: "1.2.0"
  compatibility: ">=1.0.0"
```

### Q: How do I test templates?
A: Use the provided testing framework:
```swift
func testEndpointTemplate() throws {
    let result = try renderTemplate(
        "endpoint.stencil",
        context: mockEndpointContext()
    )
    XCTAssertContains(result, "APIEndpoint")
}
```

## References

### Documentation
- [Stencil Documentation](https://stencil.fuller.li/)
- [StencilSwiftKit](https://github.com/SwiftGen/StencilSwiftKit)
- [Swift OpenAPI Generator](https://github.com/apple/swift-openapi-generator)
- [OpenAPI Specification](https://spec.openapis.org/oas/latest.html)

### Related Projects
- [SwiftGen](https://github.com/SwiftGen/SwiftGen) - Template-based code generation
- [Sourcery](https://github.com/krzysztofzablocki/Sourcery) - Meta-programming for Swift
- [OpenAPI Generator](https://openapi-generator.tech/) - Multi-language code generation

### Community Resources
- Swift Forums: OpenAPI Generator discussions
- Template examples repository
- Video tutorials and workshops

### Tools
- [Stencil Playground](https://stencil-playground.fuller.li/) - Online template testing
- [Template Validator](https://github.com/example/template-validator) - Validation tool
- [Migration Assistant](https://github.com/example/migration-assistant) - Automated migration

---

This completes the comprehensive implementation guide for the Template System Integration approach. The solution provides a robust, flexible, and maintainable way to customize OpenAPI code generation while maintaining full backward compatibility.