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

final class TemplateDiscoveryTests: XCTestCase {
    
    func testTemplateValidationResult() {
        let result1 = TemplateValidationResult(
            isValid: true,
            missingTemplates: [],
            foundTemplates: ["protocol", "method"]
        )
        XCTAssertTrue(result1.isValid)
        XCTAssertTrue(result1.missingTemplates.isEmpty)
        XCTAssertEqual(result1.foundTemplates.count, 2)
        
        let result2 = TemplateValidationResult(
            isValid: false,
            missingTemplates: ["protocol"],
            foundTemplates: ["method"]
        )
        XCTAssertFalse(result2.isValid)
        XCTAssertEqual(result2.missingTemplates, ["protocol"])
        XCTAssertEqual(result2.foundTemplates, ["method"])
    }
    
    func testDefaultTemplateNames() {
        // Test API Protocol templates
        let apiTemplates = DefaultTemplateNames.requiredTemplates(for: .apiProtocol)
        XCTAssertEqual(apiTemplates, ["protocol", "protocol_extension", "operation_method"])
        
        // Test Client templates
        let clientTemplates = DefaultTemplateNames.requiredTemplates(for: .client)
        XCTAssertEqual(clientTemplates, ["client_struct", "client_init", "client_method", "request_builder"])
        
        // Test Server templates
        let serverTemplates = DefaultTemplateNames.requiredTemplates(for: .server)
        XCTAssertEqual(serverTemplates, ["server_protocol", "server_handler", "response_builder"])
        
        // Test Type templates
        let typeTemplates = DefaultTemplateNames.requiredTemplates(for: .types)
        XCTAssertEqual(typeTemplates, ["struct", "enum", "typealias", "extension"])
        
        // Test Error templates
        let errorTemplates = DefaultTemplateNames.requiredTemplates(for: .errors)
        XCTAssertEqual(errorTemplates, ["base_error", "domain_error", "error_mapping"])
    }
    
    func testTemplateComponentEnumeration() {
        // Ensure all template components are handled
        let allComponents = TemplateComponent.allCases
        XCTAssertEqual(allComponents.count, 5)
        XCTAssertTrue(allComponents.contains(.apiProtocol))
        XCTAssertTrue(allComponents.contains(.client))
        XCTAssertTrue(allComponents.contains(.server))
        XCTAssertTrue(allComponents.contains(.types))
        XCTAssertTrue(allComponents.contains(.errors))
    }
    
    func testTemplateDiscoveryWithMockFileSystem() throws {
        // Create a temporary directory for testing
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        // Create mock template structure
        let clientDir = tempDir.appendingPathComponent("client")
        try FileManager.default.createDirectory(
            at: clientDir,
            withIntermediateDirectories: true
        )
        
        // Create mock template files
        let template1 = clientDir.appendingPathComponent("client_struct.leaf")
        try "// Client struct template".write(to: template1, atomically: true, encoding: .utf8)
        
        let template2 = clientDir.appendingPathComponent("client_method.leaf")
        try "// Client method template".write(to: template2, atomically: true, encoding: .utf8)
        
        // Test discovery
        let discovery = TemplateDiscovery(searchPaths: [tempDir.path])
        let discovered = discovery.discoverTemplates(for: .client)
        
        XCTAssertEqual(discovered.count, 2)
        XCTAssertNotNil(discovered["client_struct"])
        XCTAssertNotNil(discovered["client_method"])
        XCTAssertEqual(discovered["client_struct"], "client/client_struct.leaf")
        XCTAssertEqual(discovered["client_method"], "client/client_method.leaf")
        
        // Test validation
        let validationResult = discovery.validateTemplates(
            for: .client,
            requiredTemplates: ["client_struct", "client_method", "client_init"]
        )
        
        XCTAssertFalse(validationResult.isValid)
        XCTAssertEqual(validationResult.missingTemplates, ["client_init"])
        XCTAssertEqual(Set(validationResult.foundTemplates), Set(["client_struct", "client_method"]))
    }
    
    func testTemplateDiscoveryWithMultiplePaths() throws {
        // Create two temporary directories
        let tempDir1 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let tempDir2 = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        
        try FileManager.default.createDirectory(
            at: tempDir1,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: tempDir2,
            withIntermediateDirectories: true
        )
        
        defer {
            try? FileManager.default.removeItem(at: tempDir1)
            try? FileManager.default.removeItem(at: tempDir2)
        }
        
        // Create types directory in first path
        let typesDir1 = tempDir1.appendingPathComponent("types")
        try FileManager.default.createDirectory(
            at: typesDir1,
            withIntermediateDirectories: true
        )
        
        // Create types directory in second path
        let typesDir2 = tempDir2.appendingPathComponent("types")
        try FileManager.default.createDirectory(
            at: typesDir2,
            withIntermediateDirectories: true
        )
        
        // Add templates to first directory
        let structTemplate = typesDir1.appendingPathComponent("struct.leaf")
        try "// Struct template".write(to: structTemplate, atomically: true, encoding: .utf8)
        
        // Add templates to second directory (this should override/add to first)
        let enumTemplate = typesDir2.appendingPathComponent("enum.leaf")
        try "// Enum template".write(to: enumTemplate, atomically: true, encoding: .utf8)
        
        // Test discovery with multiple paths
        let discovery = TemplateDiscovery(searchPaths: [tempDir1.path, tempDir2.path])
        let discovered = discovery.discoverTemplates(for: .types)
        
        XCTAssertEqual(discovered.count, 2)
        XCTAssertNotNil(discovered["struct"])
        XCTAssertNotNil(discovered["enum"])
    }
}