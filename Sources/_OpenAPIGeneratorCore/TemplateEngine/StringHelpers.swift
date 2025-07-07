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

/// String manipulation helpers for template engine.
extension String {
    /// Returns string with first letter uppercased.
    var uppercaseFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).uppercased() + dropFirst()
    }
    
    /// Returns string with first letter lowercased.
    var lowercaseFirst: String {
        guard !isEmpty else { return self }
        return prefix(1).lowercased() + dropFirst()
    }
    
    /// Converts to a Swift-safe identifier.
    var swiftIdentifier: String {
        self.replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }
    
    /// Converts camelCase to kebab-case.
    func camelCaseToKebabCase() -> String {
        return self.reduce("") { result, char in
            if char.isUppercase {
                return result + (result.isEmpty ? "" : "-") + char.lowercased()
            } else {
                return result + String(char)
            }
        }
    }
    
    /// Converts camelCase to Title Case.
    func camelCaseToTitle() -> String {
        return self.reduce("") { result, char in
            if char.isUppercase && !result.isEmpty {
                return result + " " + String(char)
            } else {
                return result + String(char)
            }
        }
    }
}