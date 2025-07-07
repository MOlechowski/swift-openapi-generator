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

/// Loads and discovers template files.
public struct TemplateDiscovery {
    /// The paths to search for templates.
    private let searchPaths: [String]
    
    /// Creates a new template discovery instance.
    /// - Parameters:
    ///   - searchPaths: Paths to search for templates.
    public init(searchPaths: [String]) {
        self.searchPaths = searchPaths
    }
    
    /// Discovers template files for a specific component.
    /// - Parameter component: The template component to find templates for.
    /// - Returns: Dictionary mapping template names to file paths.
    public func discoverTemplates(for component: TemplateComponent) -> [String: String] {
        var templates: [String: String] = [:]
        let fileManager = FileManager.default
        
        for searchPath in searchPaths {
            let componentPath = URL(fileURLWithPath: searchPath)
                .appendingPathComponent(component.rawValue)
            
            guard fileManager.fileExists(atPath: componentPath.path) else {
                continue
            }
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: componentPath,
                    includingPropertiesForKeys: nil
                )
                
                for fileURL in contents where fileURL.pathExtension == "leaf" {
                    let templateName = fileURL.deletingPathExtension().lastPathComponent
                    let relativePath = "\(component.rawValue)/\(fileURL.lastPathComponent)"
                    templates[templateName] = relativePath
                }
            } catch {
                // Ignore errors and continue with other paths
                continue
            }
        }
        
        return templates
    }
    
    /// Validates that required templates exist for a component.
    /// - Parameters:
    ///   - component: The component to validate.
    ///   - requiredTemplates: Names of required templates.
    /// - Returns: Validation result with missing templates.
    public func validateTemplates(
        for component: TemplateComponent,
        requiredTemplates: [String]
    ) -> TemplateValidationResult {
        let discovered = discoverTemplates(for: component)
        let missing = requiredTemplates.filter { discovered[$0] == nil }
        
        return TemplateValidationResult(
            isValid: missing.isEmpty,
            missingTemplates: missing,
            foundTemplates: Array(discovered.keys)
        )
    }
}

/// Result of template validation.
public struct TemplateValidationResult {
    /// Whether all required templates were found.
    public let isValid: Bool
    
    /// Names of missing templates.
    public let missingTemplates: [String]
    
    /// Names of found templates.
    public let foundTemplates: [String]
}

/// Default template names for different components.
public enum DefaultTemplateNames {
    /// Default templates for API protocol generation.
    public static let apiProtocol = [
        "protocol",
        "protocol_extension",
        "operation_method"
    ]
    
    /// Default templates for client generation.
    public static let client = [
        "client_struct",
        "client_init",
        "client_method",
        "request_builder"
    ]
    
    /// Default templates for server generation.
    public static let server = [
        "server_protocol",
        "server_handler",
        "response_builder"
    ]
    
    /// Default templates for type generation.
    public static let types = [
        "struct",
        "enum",
        "typealias",
        "extension"
    ]
    
    /// Default templates for error generation.
    public static let errors = [
        "base_error",
        "domain_error",
        "error_mapping"
    ]
    
    /// Returns required templates for a component.
    /// - Parameter component: The template component.
    /// - Returns: Array of required template names.
    public static func requiredTemplates(for component: TemplateComponent) -> [String] {
        switch component {
        case .apiProtocol:
            return apiProtocol
        case .client:
            return client
        case .server:
            return server
        case .types:
            return types
        case .errors:
            return errors
        }
    }
}

/// Loads template files from disk.
public class TemplateLoader {
    private let basePath: String
    
    /// Creates a new template loader.
    /// - Parameter basePath: The base path for templates. Defaults to "Templates".
    public init(basePath: String = "Templates") {
        self.basePath = basePath
    }
    
    /// Loads a template with the specified name.
    /// - Parameter name: The name of the template (without .leaf extension).
    /// - Returns: The template content.
    /// - Throws: An error if the template cannot be loaded.
    public func loadTemplate(named name: String) throws -> String {
        let templatePath = "\(basePath)/\(name).leaf"
        return try String(contentsOfFile: templatePath, encoding: .utf8)
    }
}