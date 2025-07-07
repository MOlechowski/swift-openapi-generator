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

final class TemplateEngineTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Clean up any string extension conflicts
    }
    
    func testTemplateContextCreation() throws {
        let context = TemplateContext(data: [
            "name": "TestAPI",
            "version": "1.0.0",
            "operations": ["list", "create", "update"]
        ])
        
        XCTAssertEqual(context.rawData["name"] as? String, "TestAPI")
        XCTAssertEqual(context.rawData["version"] as? String, "1.0.0")
        XCTAssertNotNil(context.rawData["operations"])
    }
    
    func testTemplateContextBuilder() throws {
        var builder = TemplateContextBuilder()
        builder.add(key: "apiName", value: "PetStore")
        builder.add(key: "apiVersion", value: "2.0.0")
        builder.add(values: [
            "baseURL": "https://api.example.com",
            "timeout": 30
        ])
        
        let context = builder.build()
        XCTAssertEqual(context.rawData["apiName"] as? String, "PetStore")
        XCTAssertEqual(context.rawData["apiVersion"] as? String, "2.0.0")
        XCTAssertEqual(context.rawData["baseURL"] as? String, "https://api.example.com")
        XCTAssertEqual(context.rawData["timeout"] as? Int, 30)
    }
    
    func testLeafTemplateEngineBasicRendering() throws {
        let engine = LeafTemplateEngine(templatePaths: [])
        
        let template = """
        Hello #(name)!
        API Version: #(version)
        """
        
        let context = TemplateContext(data: [
            "name": "Swift OpenAPI",
            "version": "1.0.0"
        ])
        
        let result = try engine.render(template: template, context: context)
        XCTAssertEqual(result, """
        Hello Swift OpenAPI!
        API Version: 1.0.0
        """)
    }
    
    func testLeafTemplateEngineWithCustomTags() throws {
        let engine = LeafTemplateEngine(templatePaths: [])
        
        let template = """
        Original: #(name)
        Swift Identifier: #swiftIdentifier(name)
        Camel Case: #camelCase(snake_name)
        Pascal Case: #pascalCase(snake_name)
        """
        
        let context = TemplateContext(data: [
            "name": "my-api-name",
            "snake_name": "my_api_name"
        ])
        
        let result = try engine.render(template: template, context: context)
        XCTAssertEqual(result, """
        Original: my-api-name
        Swift Identifier: my_api_name
        Camel Case: myApiName
        Pascal Case: MyApiName
        """)
    }
    
    func testLeafTemplateEngineWithLoops() throws {
        let engine = LeafTemplateEngine(templatePaths: [])
        
        let template = """
        Operations:
        #for(op in operations):
        - #pascalCase(op)
        #endfor
        """
        
        let context = TemplateContext(data: [
            "operations": ["list_pets", "create_pet", "update_pet"]
        ])
        
        let result = try engine.render(template: template, context: context)
        XCTAssertEqual(result, """
        Operations:
        
        - ListPets
        
        - CreatePet
        
        - UpdatePet
        
        """)
    }
    
    func testLeafTemplateEngineWithConditionals() throws {
        let engine = LeafTemplateEngine(templatePaths: [])
        
        // Using multiline format for clearer syntax
        let template = """
        #if(isPublic):
        public struct #pascalCase(name) {
            // Implementation
        }
        #else:
        struct #pascalCase(name) {
            // Implementation
        }
        #endif
        """
        
        let context1 = TemplateContext(data: [
            "name": "my_type",
            "isPublic": true
        ])
        
        let result1 = try engine.render(template: template, context: context1)
        XCTAssertEqual(result1.trimmingCharacters(in: .whitespacesAndNewlines), """
        public struct MyType {
            // Implementation
        }
        """)
        
        let context2 = TemplateContext(data: [
            "name": "my_type",
            "isPublic": false
        ])
        
        let result2 = try engine.render(template: template, context: context2)
        XCTAssertEqual(result2.trimmingCharacters(in: .whitespacesAndNewlines), """
        struct MyType {
            // Implementation
        }
        """)
    }
    
    func testTemplateContextConvertible() throws {
        struct MyAPIInfo: TemplateContextConvertible {
            let name: String
            let version: String
            let operations: [String]
            
            var templateContextData: [String : Any] {
                [
                    "name": name,
                    "version": version,
                    "operations": operations,
                    "operationCount": operations.count
                ]
            }
        }
        
        let apiInfo = MyAPIInfo(
            name: "PetStore",
            version: "1.0.0",
            operations: ["listPets", "createPet"]
        )
        
        var builder = TemplateContextBuilder()
        builder.add(key: "api", object: apiInfo)
        
        let context = builder.build()
        let engine = LeafTemplateEngine(templatePaths: [])
        
        let template = """
        API: #(api.name) v#(api.version)
        Operations (#(api.operationCount)):
        #for(op in api.operations):
        - #(op)
        #endfor
        """
        
        let result = try engine.render(template: template, context: context)
        XCTAssertEqual(result, """
        API: PetStore v1.0.0
        Operations (2):
        
        - listPets
        
        - createPet
        
        """)
    }
    
    func testTemplateEngineErrorHandling() throws {
        let engine = LeafTemplateEngine(templatePaths: [])
        
        // Test syntax error - invalid tag
        let badTemplate = """
        #if(name
        This is invalid
        """
        
        let context = TemplateContext(data: ["name": "test"])
        
        XCTAssertThrowsError(try engine.render(template: badTemplate, context: context)) { error in
            // Leaf will throw some kind of error for invalid syntax
            XCTAssertNotNil(error)
        }
    }
}