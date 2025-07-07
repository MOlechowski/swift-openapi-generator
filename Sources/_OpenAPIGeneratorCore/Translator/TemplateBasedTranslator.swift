//===----------------------------------------------------------------------===//
//
// This source file is part of the SwiftOpenAPIGenerator open source project
//
// Copyright (c) 2023 Apple Inc. and the SwiftOpenAPIGenerator project authors
// Licensed under Apache License v2.0
//
// See LICENSE.txt for license information
// See CONTRIBUTORS.txt for the list of SwiftOpenAPIGenerator project authors
//
// SPDX-License-Identifier: Apache-2.0
//
//===----------------------------------------------------------------------===//

import Foundation
import OpenAPIKit

/// A translator that generates code using templates instead of building AST.
struct TemplateBasedTranslator: TranslatorProtocol {
    
    /// The template engine to use for rendering.
    private let templateEngine: any TemplateEngine
    
    /// The template loader.
    private let templateLoader: TemplateLoader
    
    /// Creates a new template-based translator.
    init() {
        // Use absolute path for templates during development/testing
        let templatesPath = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Templates")
            .path
        
        self.templateEngine = LeafTemplateEngine(templatePaths: [templatesPath])
        self.templateLoader = TemplateLoader(basePath: templatesPath)
    }
    
    func translate(
        parsedOpenAPI: ParsedOpenAPIRepresentation,
        config: Config,
        diagnostics: any DiagnosticCollector
    ) throws -> StructuredSwiftRepresentation {
        
        // For now, we'll create a simple placeholder that demonstrates
        // the template system is working
        let context = createContext(from: parsedOpenAPI, config: config)
        
        // Determine which templates to use based on the mode
        let templateName: String
        switch config.mode {
        case .types:
            templateName = "Types"
        case .client:
            templateName = "Client"
        case .server:
            templateName = "Server"
        }
        
        // Load and render the template
        let template = try templateLoader.loadTemplate(named: templateName)
        let rendered = try templateEngine.render(template: template, context: context)
        
        // Parse the rendered template back into a FileDescription
        // This is a temporary approach - ideally we would generate the AST directly
        let file = try parseRenderedSwift(rendered, config: config)
        
        return StructuredSwiftRepresentation(
            file: NamedFileDescription(
                name: config.mode.outputFileName,
                contents: file
            )
        )
    }
    
    // MARK: - Private
    
    private func createContext(from document: OpenAPI.Document, config: Config) -> TemplateContext {
        // Extract basic information from the document
        var contextData: [String: Any] = [:]
        
        // Add document info
        contextData["title"] = document.info.title
        contextData["version"] = document.info.version
        contextData["description"] = document.info.description ?? ""
        
        // Add configuration
        contextData["accessModifier"] = config.access.rawValue
        contextData["mode"] = config.mode.rawValue
        
        // Extract operations with more detail
        var operations: [[String: Any]] = []
        for (path, pathItemRef) in document.paths {
            // Handle path item reference
            let pathItem: OpenAPI.PathItem
            switch pathItemRef {
            case .a(let reference):
                // Skip references for now
                continue
            case .b(let item):
                pathItem = item
            }
            
            for endpoint in pathItem.endpoints {
                if let operationId = endpoint.operation.operationId {
                    var operationData: [String: Any] = [
                        "operationId": operationId,
                        "path": path.rawValue,
                        "method": endpoint.method.rawValue.uppercased(),
                        "summary": endpoint.operation.summary ?? "",
                        "description": endpoint.operation.description ?? ""
                    ]
                    
                    // Extract parameters
                    var hasQuery = false
                    var hasHeaders = false
                    var hasPath = false
                    
                    // Check for path parameters
                    if path.rawValue.contains("{") {
                        hasPath = true
                    }
                    
                    // Check operation parameters
                    for parameter in endpoint.operation.parameters {
                        switch parameter {
                        case .a(_):
                            continue // Skip references for now
                        case .b(let param):
                            switch param.location {
                            case .query:
                                hasQuery = true
                            case .header:
                                hasHeaders = true
                            case .path:
                                hasPath = true
                            case .cookie:
                                break
                            }
                        }
                    }
                    
                    operationData["hasQuery"] = hasQuery
                    operationData["hasHeaders"] = hasHeaders
                    operationData["hasPath"] = hasPath
                    operationData["hasBody"] = endpoint.operation.requestBody != nil
                    
                    // Extract response codes
                    var responseCodes: [String] = []
                    for outcome in endpoint.operation.responseOutcomes {
                        let responseKind = outcome.status.value.asKind
                        if case .code(let code) = responseKind {
                            responseCodes.append(String(code))
                        }
                    }
                    operationData["responseCodes"] = responseCodes
                    
                    operations.append(operationData)
                }
            }
        }
        contextData["operations"] = operations
        
        // Extract schemas with more detail
        var schemas: [[String: Any]] = []
        for (name, schema) in document.components.schemas {
            var schemaData: [String: Any] = [
                "name": name.rawValue,
                "type": describeSchemaType(schema),
                "swiftType": mapSchemaToSwiftType(schema)
            ]
            
            // Extract properties for object schemas
            if case .object(_, let context) = schema.value {
                var properties: [[String: Any]] = []
                for (propName, propSchema) in context.properties {
                    var propData: [String: Any] = [
                        "name": propName,
                        "type": mapSchemaToSwiftType(propSchema),
                        "required": context.requiredProperties.contains(propName),
                        "description": propSchema.description ?? ""
                    ]
                    
                    properties.append(propData)
                }
                schemaData["properties"] = properties
            }
            
            schemas.append(schemaData)
        }
        contextData["schemas"] = schemas
        
        return TemplateContext(data: contextData)
    }
    
    private func describeSchemaType(_ schema: JSONSchema) -> String {
        switch schema.value {
        case .string:
            return "string"
        case .integer:
            return "integer"
        case .number:
            return "number"
        case .boolean:
            return "boolean"
        case .array:
            return "array"
        case .object:
            return "object"
        case .reference:
            return "reference"
        case .all:
            return "allOf"
        case .one:
            return "oneOf"
        case .any:
            return "anyOf"
        case .not:
            return "not"
        case .fragment:
            return "fragment"
        case .null:
            return "null"
        }
    }
    
    private func mapSchemaToSwiftType(_ schema: JSONSchema) -> String {
        switch schema.value {
        case .string(_, let context):
            if context.contentEncoding == .base64 {
                return "OpenAPIRuntime.Base64EncodedData"
            }
            // For now, just use String for all string types
            // TODO: Add proper format handling for dates, etc.
            return "Swift.String"
            
        case .integer:
            // Default to Int64 for integers
            return "Swift.Int64"
            
        case .number:
            // Default to Double for numbers
            return "Swift.Double"
            
        case .boolean:
            return "Swift.Bool"
            
        case .array(_, let context):
            if let items = context.items {
                let itemType = mapSchemaToSwiftType(items)
                return "[\(itemType)]"
            } else {
                return "[Any]"
            }
            
        case .object:
            return "OpenAPIRuntime.OpenAPIObjectContainer"
            
        case .reference(let ref, _):
            // Extract the component name from the reference URI
            let uri = ref.absoluteString
            let components = uri.split(separator: "/")
            if let name = components.last {
                return "Components.Schemas.\(name)"
            }
            return "Any"
            
        default:
            return "Any"
        }
    }
    
    /// Parses rendered Swift code back into a FileDescription.
    /// This is a temporary solution until we can generate AST directly from templates.
    private func parseRenderedSwift(_ rendered: String, config: Config) throws -> FileDescription {
        // Extract the top comment if present
        let lines = rendered.split(separator: "\n", omittingEmptySubsequences: false)
        var topComment: Comment? = nil
        var contentStartIndex = 0
        
        if let firstLine = lines.first, firstLine.starts(with: "//") {
            // Find the end of the comment block
            for (index, line) in lines.enumerated() {
                if !line.starts(with: "//") && !line.isEmpty {
                    contentStartIndex = index
                    break
                }
            }
            
            // Extract comment text
            let commentLines = lines[0..<contentStartIndex]
                .map { line in
                    let str = String(line)
                    if str.starts(with: "// ") {
                        return String(str.dropFirst(3))
                    } else if str == "//" {
                        return ""
                    }
                    return str
                }
                .joined(separator: "\n")
            topComment = .doc(commentLines.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        // Extract imports
        var imports: [ImportDescription] = []
        var codeStartIndex = contentStartIndex
        
        for (index, line) in lines[contentStartIndex...].enumerated() {
            let actualIndex = contentStartIndex + index
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.starts(with: "import ") {
                let moduleName = String(trimmedLine.dropFirst("import ".count))
                imports.append(ImportDescription(moduleName: moduleName))
                codeStartIndex = actualIndex + 1
            } else if !trimmedLine.isEmpty {
                break
            }
        }
        
        // For now, we'll create a simple declaration that contains the rest of the code
        // In a real implementation, we would parse the Swift code properly
        let remainingCode = lines[codeStartIndex...].joined(separator: "\n")
        
        // Create a raw declaration that will be rendered as-is
        let codeBlock = CodeBlock(
            comment: nil,
            item: .expression(.literal(.string(remainingCode)))
        )
        
        return FileDescription(
            topComment: topComment,
            imports: imports,
            codeBlocks: [codeBlock]
        )
    }
}