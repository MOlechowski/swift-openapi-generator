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

/// Protocol for template engines used in code generation.
public protocol TemplateEngine {
    /// Renders a template with the given context.
    /// - Parameters:
    ///   - template: The template content.
    ///   - context: The context data to pass to the template.
    /// - Returns: The rendered output.
    /// - Throws: An error if rendering fails.
    func render(template: String, context: TemplateContext) throws -> String
    
    /// Renders a template from a file with the given context.
    /// - Parameters:
    ///   - templatePath: Path to the template file.
    ///   - context: The context data to pass to the template.
    /// - Returns: The rendered output.
    /// - Throws: An error if loading or rendering fails.
    func renderFile(templatePath: String, context: TemplateContext) throws -> String
}

/// Errors that can occur during template rendering.
public enum TemplateEngineError: Error, CustomStringConvertible {
    case templateNotFound(path: String)
    case renderingFailed(message: String)
    case invalidContext(message: String)
    case templateSyntaxError(message: String)
    
    public var description: String {
        switch self {
        case .templateNotFound(let path):
            return "Template not found at path: \(path)"
        case .renderingFailed(let message):
            return "Template rendering failed: \(message)"
        case .invalidContext(let message):
            return "Invalid template context: \(message)"
        case .templateSyntaxError(let message):
            return "Template syntax error: \(message)"
        }
    }
}