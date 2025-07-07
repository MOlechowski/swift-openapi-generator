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

/// Simple context converters for testing template functionality.
enum SimpleContextConverters {
    
    /// Creates a simple operation context for testing.
    static func simpleOperationContext(
        operationId: String,
        method: String,
        path: String
    ) -> [String: Any] {
        [
            "operationId": operationId,
            "method": method.uppercased(),
            "path": path,
            "swiftName": operationId.swiftIdentifier,
            "endpointName": "\(operationId.uppercaseFirst)Endpoint"
        ]
    }
    
    /// Creates a simple type context for testing.
    static func simpleTypeContext(
        name: String,
        properties: [(name: String, type: String)]
    ) -> [String: Any] {
        [
            "name": name,
            "properties": properties.map { prop in
                [
                    "name": prop.name,
                    "type": prop.type,
                    "swiftName": prop.name.swiftIdentifier
                ]
            }
        ]
    }
}

// String helpers are in StringHelpers.swift