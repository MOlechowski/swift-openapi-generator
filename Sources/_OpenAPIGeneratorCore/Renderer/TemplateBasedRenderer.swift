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

/// A renderer that uses templates instead of AST-based rendering.
struct TemplateBasedRenderer: RendererProtocol {
    
    private let templateEngine: any TemplateEngine
    private let templateLoader: TemplateLoader
    private let templateConfig: TemplateConfig
    
    public struct TemplateConfig {
        public let apiProtocolName: String
        
        public init(
            apiProtocolName: String = "APIProtocol"
        ) {
            self.apiProtocolName = apiProtocolName
        }
    }
    
    init(templateConfig: TemplateConfig = TemplateConfig()) {
        self.templateConfig = templateConfig
        self.templateEngine = LeafTemplateEngine(templatePaths: ["Templates"])
        self.templateLoader = TemplateLoader()
    }
    
    // MARK: - RendererProtocol
    
    func render(structured code: StructuredSwiftRepresentation, config: Config, diagnostics: any DiagnosticCollector) throws -> InMemoryOutputFile {
        // Check if we should use template-based rendering
        guard config.featureFlags.contains(.templateBasedGeneration) else {
            // Fall back to the default AST-based renderer
            throw RendererError.notImplemented("Template-based rendering requires the templateBasedGeneration feature flag")
        }
        
        // Extract information from the structured representation
        let fileDescription = code.file.contents
        let fileName = code.file.name
        
        // Determine which template to use based on the generator mode
        let generatedContent: String
        switch config.mode {
        case .types:
            generatedContent = try renderTypes(from: fileDescription, config: config)
        case .client:
            generatedContent = try renderClient(from: fileDescription, config: config)
        case .server:
            generatedContent = try renderServer(from: fileDescription, config: config)
        }
        
        return InMemoryOutputFile(
            baseName: fileName,
            contents: Data(generatedContent.utf8)
        )
    }
    
    // MARK: - Template-based rendering methods
    
    private func renderTypes(from fileDescription: FileDescription, config: Config) throws -> String {
        // For template-based rendering, we need to use the TemplateBasedTranslator
        // which generates code directly from templates instead of building AST
        // The translator should have already handled this, so this shouldn't be called
        throw RendererError.notImplemented("Template-based rendering should use TemplateBasedTranslator, not TemplateBasedRenderer")
    }
    
    private func renderClient(from fileDescription: FileDescription, config: Config) throws -> String {
        // For template-based rendering, we need to use the TemplateBasedTranslator
        throw RendererError.notImplemented("Template-based rendering should use TemplateBasedTranslator, not TemplateBasedRenderer")
    }
    
    private func renderServer(from fileDescription: FileDescription, config: Config) throws -> String {
        // For template-based rendering, we need to use the TemplateBasedTranslator
        throw RendererError.notImplemented("Template-based rendering should use TemplateBasedTranslator, not TemplateBasedRenderer")
    }
}

// MARK: - Errors

private enum RendererError: LocalizedError {
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .notImplemented(let feature):
            return "Feature not implemented: \(feature)"
        }
    }
}