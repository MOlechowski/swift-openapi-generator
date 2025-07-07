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
import OpenAPIKit
@testable import _OpenAPIGeneratorCore

final class Test_TemplateBasedTranslator: XCTestCase {
    
    func testTranslateSimpleDocument() throws {
        let translator = TemplateBasedTranslator()
        let diagnostics = TestDiagnosticsCollector()
        
        // Create a simple OpenAPI document
        let document = OpenAPI.Document(
            info: .init(title: "Test API", version: "1.0.0"),
            servers: [],
            paths: [
                "/pets": .b(.init(
                    get: .init(
                        summary: "List all pets",
                        operationId: "listPets",
                        responses: [
                            200: .b(.init(description: "Success"))
                        ]
                    ),
                    post: .init(
                        summary: "Create a pet",
                        operationId: "createPet",
                        responses: [
                            201: .b(.init(description: "Created"))
                        ]
                    )
                ))
            ],
            components: .init(
                schemas: [
                    "Pet": .object(
                        properties: [
                            "id": .integer,
                            "name": .string
                        ]
                    )
                ]
            )
        )
        
        let config = Config(
            mode: .types,
            access: .public,
            namingStrategy: .defensive,
            featureFlags: [.templateBasedGeneration]
        )
        
        let result = try translator.translate(
            parsedOpenAPI: document,
            config: config,
            diagnostics: diagnostics
        )
        
        // Verify the result
        XCTAssertEqual(result.file.name, "Types.swift")
        
        // The file should contain the rendered template
        let codeBlocks = result.file.contents.codeBlocks
        XCTAssertFalse(codeBlocks.isEmpty)
        
        // Since we're rendering a template as a string literal for now,
        // check that it contains expected content
        if case .expression(.literal(.string(let rendered))) = codeBlocks.first?.item {
            // The title isn't used in the generated code, so we don't check for it
            // Instead, check that the operations and schemas are present
            XCTAssertTrue(rendered.contains("listPets"), "Should contain listPets operation")
            XCTAssertTrue(rendered.contains("createPet"), "Should contain createPet operation") 
            XCTAssertTrue(rendered.contains("struct Pet"), "Should contain Pet schema")
        } else {
            XCTFail("Expected string literal with rendered template")
        }
    }
    
    func testTranslateForClient() throws {
        let translator = TemplateBasedTranslator()
        let diagnostics = TestDiagnosticsCollector()
        
        let document = OpenAPI.Document(
            info: .init(title: "Pet Store", version: "2.0.0"),
            servers: [],
            paths: [:],
            components: .init()
        )
        
        let config = Config(
            mode: .client,
            access: .internal,
            namingStrategy: .defensive,
            featureFlags: [.templateBasedGeneration]
        )
        
        let result = try translator.translate(
            parsedOpenAPI: document,
            config: config,
            diagnostics: diagnostics
        )
        
        XCTAssertEqual(result.file.name, "Client.swift")
    }
    
    func testTranslateForServer() throws {
        let translator = TemplateBasedTranslator()
        let diagnostics = TestDiagnosticsCollector()
        
        let document = OpenAPI.Document(
            info: .init(title: "Pet Store", version: "2.0.0"),
            servers: [],
            paths: [:],
            components: .init()
        )
        
        let config = Config(
            mode: .server,
            access: .public,
            namingStrategy: .defensive,
            featureFlags: [.templateBasedGeneration]
        )
        
        let result = try translator.translate(
            parsedOpenAPI: document,
            config: config,
            diagnostics: diagnostics
        )
        
        XCTAssertEqual(result.file.name, "Server.swift")
    }
}

// MARK: - Test Helpers

private final class TestDiagnosticsCollector: DiagnosticCollector {
    var diagnostics: [Diagnostic] = []
    
    func emit(_ diagnostic: Diagnostic) throws {
        diagnostics.append(diagnostic)
    }
}