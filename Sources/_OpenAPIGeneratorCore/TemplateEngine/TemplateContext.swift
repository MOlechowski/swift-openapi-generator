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

/// Context data passed to templates during rendering.
public struct TemplateContext {
    /// The raw context data.
    private let data: [String: Any]
    
    /// Creates a new template context.
    /// - Parameter data: The context data dictionary.
    public init(data: [String: Any]) {
        self.data = data
    }
    
    /// Creates an empty template context.
    public init() {
        self.data = [:]
    }
    
    /// Get the raw context data.
    internal var rawData: [String: Any] {
        return data
    }
}

/// Protocol for types that can be converted to template context data.
public protocol TemplateContextConvertible {
    /// The data representation for template context.
    var templateContextData: [String: Any] { get }
}

/// Builder for creating template contexts.
public struct TemplateContextBuilder {
    private var data: [String: Any] = [:]
    
    /// Creates a new context builder.
    public init() {}
    
    /// Adds a value to the context.
    /// - Parameters:
    ///   - key: The key for the value.
    ///   - value: The value to add.
    /// - Returns: The builder for chaining.
    @discardableResult
    public mutating func add(key: String, value: Any) -> TemplateContextBuilder {
        data[key] = value
        return self
    }
    
    /// Adds multiple values to the context.
    /// - Parameter values: Dictionary of values to add.
    /// - Returns: The builder for chaining.
    @discardableResult
    public mutating func add(values: [String: Any]) -> TemplateContextBuilder {
        data.merge(values) { _, new in new }
        return self
    }
    
    /// Adds a convertible object to the context.
    /// - Parameters:
    ///   - key: The key for the object.
    ///   - object: The convertible object.
    /// - Returns: The builder for chaining.
    @discardableResult
    public mutating func add(key: String, object: any TemplateContextConvertible) -> TemplateContextBuilder {
        data[key] = object.templateContextData
        return self
    }
    
    /// Builds the template context.
    /// - Returns: The constructed template context.
    public func build() -> TemplateContext {
        TemplateContext(data: data)
    }
}