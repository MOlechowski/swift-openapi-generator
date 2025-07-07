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
import Leaf
import LeafKit
import NIOCore
import NIOPosix

/// Leaf-based template engine implementation.
public final class LeafTemplateEngine: TemplateEngine {
    /// The Leaf renderer.
    private let renderer: LeafRenderer
    
    /// The event loop group for async operations.
    private let eventLoopGroup: any EventLoopGroup
    
    /// Temporary directory for inline templates.
    private let tempDirectory: URL
    
    /// Creates a new Leaf template engine.
    /// - Parameters:
    ///   - templatePaths: Paths to search for templates.
    public init(templatePaths: [String]) {
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        
        // Create a temporary directory for inline templates
        self.tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift-openapi-generator-templates")
            .appendingPathComponent(UUID().uuidString)
        
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Configure Leaf sources
        let sources = LeafSources()
        
        // Add temporary directory as a source (make it searchable)
        let tempSource = NIOLeafFiles(
            fileio: NonBlockingFileIO(threadPool: .init(numberOfThreads: 1)),
            limits: .default,
            sandboxDirectory: tempDirectory.path,
            viewDirectory: tempDirectory.path,
            defaultExtension: "leaf"
        )
        try? sources.register(source: "temp", using: tempSource, searchable: true)
        
        for path in templatePaths {
            let source = NIOLeafFiles(
                fileio: NonBlockingFileIO(threadPool: .init(numberOfThreads: 1)),
                limits: .default,
                sandboxDirectory: path,
                viewDirectory: path,
                defaultExtension: "leaf"
            )
            try? sources.register(source: path, using: source, searchable: true)
        }
        
        // Create renderer configuration
        let config = LeafConfiguration(rootDirectory: templatePaths.first ?? ".")
        
        // Register custom tags in default tags before creating renderer
        defaultTags["swiftIdentifier"] = SwiftIdentifierTag()
        defaultTags["camelCase"] = CamelCaseTag()
        defaultTags["pascalCase"] = PascalCaseTag()
        defaultTags["uppercaseFirst"] = UppercaseFirstTag()
        defaultTags["lowercased"] = LowercasedTag()
        
        // Create renderer with custom tags
        self.renderer = LeafRenderer(
            configuration: config,
            sources: sources,
            eventLoop: eventLoopGroup.next()
        )
    }
    
    deinit {
        try? eventLoopGroup.syncShutdownGracefully()
        try? FileManager.default.removeItem(at: tempDirectory)
    }
    
    public func render(template: String, context: TemplateContext) throws -> String {
        // Create a temporary file for the inline template
        let tempFileName = "inline-\(UUID().uuidString).leaf"
        let tempFilePath = tempDirectory.appendingPathComponent(tempFileName)
        
        // Write template to temporary file
        try template.write(to: tempFilePath, atomically: true, encoding: .utf8)
        
        
        defer {
            // Clean up temporary file
            try? FileManager.default.removeItem(at: tempFilePath)
        }
        
        // Get the context data
        let contextData = try context.toLeafData()
        
        // Render using just the filename (without extension)
        let templateName = tempFileName.replacingOccurrences(of: ".leaf", with: "")
        let rendered = try renderer.render(path: templateName, context: contextData).wait()
        return String(buffer: rendered)
    }
    
    public func renderFile(templatePath: String, context: TemplateContext) throws -> String {
        let contextData = try context.toLeafData()
        
        let rendered = try renderer.render(path: templatePath, context: contextData).wait()
        return String(buffer: rendered)
    }
}

// MARK: - Custom Leaf Tags

/// Tag that converts strings to Swift identifiers.
struct SwiftIdentifierTag: LeafTag {
    func render(_ context: LeafContext) throws -> LeafData {
        try context.requireParameterCount(1)
        
        guard let string = context.parameters[0].string else {
            throw LeafError(.unknownError("unable to convert parameter to string for swiftIdentifier"))
        }
        
        let result = string
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        
        return .string(result)
    }
}

/// Tag that converts strings to camelCase.
struct CamelCaseTag: LeafTag {
    func render(_ context: LeafContext) throws -> LeafData {
        try context.requireParameterCount(1)
        
        guard let string = context.parameters[0].string else {
            throw LeafError(.unknownError("unable to convert parameter to string for camelCase"))
        }
        
        let parts = string.split(separator: "_")
        let result = parts.enumerated().map { index, part in
            index == 0 ? part.lowercased() : part.capitalized
        }.joined()
        
        return .string(result)
    }
}

/// Tag that converts strings to PascalCase.
struct PascalCaseTag: LeafTag {
    func render(_ context: LeafContext) throws -> LeafData {
        try context.requireParameterCount(1)
        
        guard let string = context.parameters[0].string else {
            throw LeafError(.unknownError("unable to convert parameter to string for pascalCase"))
        }
        
        let result = string.split(separator: "_")
            .map { $0.capitalized }
            .joined()
        
        return .string(result)
    }
}

/// Tag that uppercases the first letter of a string.
struct UppercaseFirstTag: LeafTag {
    func render(_ context: LeafContext) throws -> LeafData {
        try context.requireParameterCount(1)
        
        guard let string = context.parameters[0].string else {
            throw LeafError(.unknownError("unable to convert parameter to string for uppercaseFirst"))
        }
        
        guard !string.isEmpty else {
            return .string(string)
        }
        
        let result = string.prefix(1).uppercased() + string.dropFirst()
        return .string(result)
    }
}

/// Tag that converts a string to lowercase.
struct LowercasedTag: LeafTag {
    func render(_ context: LeafContext) throws -> LeafData {
        try context.requireParameterCount(1)
        
        guard let string = context.parameters[0].string else {
            throw LeafError(.unknownError("unable to convert parameter to string for lowercased"))
        }
        
        return .string(string.lowercased())
    }
}

// MARK: - Context Extensions

extension TemplateContext {
    /// Converts this context to Leaf data.
    /// - Returns: LeafData suitable for rendering.
    /// - Throws: An error if conversion fails.
    func toLeafData() throws -> [String: LeafData] {
        let convertedData = try convertToLeafCompatible(rawData)
        
        // Handle case where convertedData is LeafData.dictionary
        if let leafData = convertedData as? LeafData {
            guard let dict = leafData.dictionary else {
                throw TemplateEngineError.invalidContext(message: "Expected dictionary LeafData but got \(leafData)")
            }
            return dict
        }
        
        // Otherwise, it should be a regular dictionary
        guard let dict = convertedData as? [String: LeafData] else {
            throw TemplateEngineError.invalidContext(message: "Failed to convert context to LeafData")
        }
        return dict
    }
    
    /// Converts data to Leaf-compatible format.
    private func convertToLeafCompatible(_ value: Any) throws -> Any {
        switch value {
        case let dict as [String: Any]:
            var result: [String: LeafData] = [:]
            for (key, val) in dict {
                if let leafData = try convertToLeafCompatible(val) as? LeafData {
                    result[key] = leafData
                }
            }
            return LeafData.dictionary(result)
            
        case let array as [Any]:
            let leafArray = try array.compactMap { element -> LeafData? in
                try convertToLeafCompatible(element) as? LeafData
            }
            return LeafData.array(leafArray)
            
        case let string as String:
            return LeafData.string(string)
            
        case let bool as Bool:
            return LeafData.bool(bool)
            
        case let int as Int:
            return LeafData.int(int)
            
        case let double as Double:
            return LeafData.double(double)
            
        case is NSNull, is Void:
            return LeafData.nil
            
        case let context as any TemplateContextConvertible:
            return try convertToLeafCompatible(context.templateContextData)
            
        default:
            // For other types, convert to string representation
            return LeafData.string(String(describing: value))
        }
    }
}

// MARK: - Helper Extensions

extension LeafContext {
    /// Requires a specific number of parameters.
    func requireParameterCount(_ count: Int) throws {
        guard parameters.count == count else {
            throw LeafError(.unknownError("Invalid parameter count. Expected \(count), got \(parameters.count)"))
        }
    }
}