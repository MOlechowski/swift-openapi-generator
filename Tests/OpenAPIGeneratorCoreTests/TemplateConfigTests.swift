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

import XCTest
@testable import _OpenAPIGeneratorCore

final class TemplateConfigTests: XCTestCase {
    
    func testTemplateConfigCreation() {
        // Test default initialization
        let config1 = TemplateConfig()
        XCTAssertFalse(config1.enabled)
        XCTAssertTrue(config1.paths.isEmpty)
        XCTAssertTrue(config1.components.isEmpty)
        XCTAssertTrue(config1.customVariables.isEmpty)
        
        // Test full initialization
        let config2 = TemplateConfig(
            enabled: true,
            paths: ["./templates", "/usr/share/templates"],
            components: [.apiProtocol, .client],
            customVariables: ["author": "Test", "version": "1.0"]
        )
        XCTAssertTrue(config2.enabled)
        XCTAssertEqual(config2.paths, ["./templates", "/usr/share/templates"])
        XCTAssertEqual(config2.components, [.apiProtocol, .client])
        XCTAssertEqual(config2.customVariables, ["author": "Test", "version": "1.0"])
    }
    
    func testTemplateConfigEquatable() {
        let config1 = TemplateConfig(
            enabled: true,
            paths: ["./templates"],
            components: [.client],
            customVariables: ["key": "value"]
        )
        
        let config2 = TemplateConfig(
            enabled: true,
            paths: ["./templates"],
            components: [.client],
            customVariables: ["key": "value"]
        )
        
        let config3 = TemplateConfig(
            enabled: false,
            paths: ["./templates"],
            components: [.client],
            customVariables: ["key": "value"]
        )
        
        XCTAssertEqual(config1, config2)
        XCTAssertNotEqual(config1, config3)
    }
    
    func testTemplateConfigCodable() throws {
        let original = TemplateConfig(
            enabled: true,
            paths: ["./templates", "../shared-templates"],
            components: [.apiProtocol, .types, .errors],
            customVariables: ["company": "Acme Corp", "year": "2024"]
        )
        
        // Encode
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(original)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(TemplateConfig.self, from: data)
        
        // Verify
        XCTAssertEqual(original, decoded)
        XCTAssertEqual(decoded.enabled, true)
        XCTAssertEqual(decoded.paths, ["./templates", "../shared-templates"])
        XCTAssertEqual(decoded.components.sorted { $0.rawValue < $1.rawValue }, 
                      [.apiProtocol, .errors, .types])
        XCTAssertEqual(decoded.customVariables, ["company": "Acme Corp", "year": "2024"])
    }
    
    func testConfigWithTemplateConfig() {
        let templateConfig = TemplateConfig(
            enabled: true,
            paths: ["./templates"],
            components: [.client],
            customVariables: ["test": "value"]
        )
        
        let config = Config(
            mode: .types,
            access: .public,
            additionalImports: ["Foundation"],
            namingStrategy: .idiomatic,
            templateConfig: templateConfig
        )
        
        XCTAssertNotNil(config.templateConfig)
        XCTAssertEqual(config.templateConfig?.enabled, true)
        XCTAssertEqual(config.templateConfig?.paths, ["./templates"])
        XCTAssertEqual(config.templateConfig?.components, [.client])
    }
    
    func testTemplateComponentRawValues() {
        // Ensure raw values are as expected for file paths
        XCTAssertEqual(TemplateComponent.apiProtocol.rawValue, "apiProtocol")
        XCTAssertEqual(TemplateComponent.client.rawValue, "client")
        XCTAssertEqual(TemplateComponent.server.rawValue, "server")
        XCTAssertEqual(TemplateComponent.types.rawValue, "types")
        XCTAssertEqual(TemplateComponent.errors.rawValue, "errors")
    }
    
    func testTemplateComponentCodable() throws {
        let components: Set<TemplateComponent> = [.apiProtocol, .client, .errors]
        
        // Encode
        let encoder = JSONEncoder()
        let data = try encoder.encode(components)
        
        // Decode
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(Set<TemplateComponent>.self, from: data)
        
        XCTAssertEqual(components, decoded)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertTrue(decoded.contains(.apiProtocol))
        XCTAssertTrue(decoded.contains(.client))
        XCTAssertTrue(decoded.contains(.errors))
    }
}