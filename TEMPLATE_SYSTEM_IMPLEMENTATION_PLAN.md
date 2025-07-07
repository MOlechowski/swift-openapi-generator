# Template System Implementation Plan

## Overview
This document tracks the implementation of the Stencil template system for Swift OpenAPI Generator, enabling HLD-compliant code generation while maintaining backward compatibility.

## Implementation Phases

### Phase 1: Foundation Setup ⏳
**Goal**: Establish the template infrastructure without affecting existing functionality

#### 1.1 Project Configuration
- [ ] Create feature branch: `feature/template-system`
- [ ] Add Stencil dependency to Package.swift
  - Package: `https://github.com/stencilproject/Stencil.git`
  - Version: `0.15.1` or latest stable
  - Target: `_OpenAPIGeneratorCore`
- [ ] Update CI/CD configuration for new dependency
- [ ] Document dependency addition in CHANGELOG

#### 1.2 Configuration Schema
- [ ] Extend `Config.swift` with template configuration:
  ```swift
  public struct TemplateConfig: Sendable {
      public var enabled: Bool
      public var paths: [String]
      public var components: Set<TemplateComponent>
      public var customVariables: [String: String]
  }
  ```
- [ ] Add `templateConfig: TemplateConfig?` to main Config struct
- [ ] Update `_UserConfig` in `UserConfig.swift` to parse template settings
- [ ] Add validation for template paths existence
- [ ] Write unit tests for configuration parsing

#### 1.3 Template Infrastructure
- [ ] Create `Sources/_OpenAPIGeneratorCore/TemplateEngine/` directory
- [ ] Implement `TemplateEngine.swift`:
  - Protocol definition
  - Stencil implementation
  - Error handling
- [ ] Create `TemplateContext.swift` for context objects
- [ ] Implement `TemplateLoader.swift` for template discovery
- [ ] Add template caching mechanism
- [ ] Write unit tests for template engine

### Phase 2: Template Context System 📝
**Goal**: Build high-level context objects from OpenAPI specifications

#### 2.1 Context Object Design
- [ ] Create context protocols in `TemplateContextProtocols.swift`:
  - `OperationContext`
  - `TypeContext`
  - `ErrorContext`
  - `ClientContext`
- [ ] Implement concrete context types:
  - [ ] `APIEndpointContext` for endpoint generation
  - [ ] `ErrorTypeContext` for RFC 9457 errors
  - [ ] `ClientBuilderContext` for builder pattern
  - [ ] `SchemaTypeContext` for type definitions
- [ ] Add context factory methods
- [ ] Write comprehensive unit tests

#### 2.2 Context Translation
- [ ] Create `ContextTranslator.swift` to convert OpenAPI → Context
- [ ] Implement operation grouping logic for APIEndpoint
- [ ] Add error type categorization for two-level architecture
- [ ] Implement client configuration extraction
- [ ] Add context validation and sanitization
- [ ] Write integration tests with sample OpenAPI specs

#### 2.3 Template Variables
- [ ] Define standard variable sets for each component
- [ ] Implement variable resolution system
- [ ] Add custom variable injection support
- [ ] Document all available template variables
- [ ] Create variable debugging/inspection tools

### Phase 3: Template Development 🎨
**Goal**: Create Stencil templates for HLD requirements

#### 3.1 APIEndpoint Templates
- [ ] Create `Templates/APIEndpoint/protocol.stencil`:
  - Protocol definition with async methods
  - Proper error handling
  - Documentation comments
- [ ] Create `Templates/APIEndpoint/implementation.stencil`:
  - Default implementation
  - Transport abstraction
  - Request/response handling
- [ ] Add operation grouping templates
- [ ] Write template tests with expected outputs

#### 3.2 Error Type Templates
- [ ] Create `Templates/Errors/base_error.stencil`:
  - RFC 9457 Problem Details structure
  - Standard error properties
- [ ] Create `Templates/Errors/domain_error.stencil`:
  - Domain-specific error types
  - Error categorization
- [ ] Create `Templates/Errors/error_mapping.stencil`:
  - HTTP status to error type mapping
  - Error factory methods
- [ ] Test error generation with various OpenAPI specs

#### 3.3 Client Builder Templates
- [ ] Create `Templates/Client/builder.stencil`:
  - Builder pattern implementation
  - Configuration methods
  - Validation logic
- [ ] Create `Templates/Client/configuration.stencil`:
  - Client configuration structure
  - Default values
- [ ] Add transport abstraction templates
- [ ] Test builder generation and usage

#### 3.4 Supporting Templates
- [ ] Create utility templates for common patterns
- [ ] Add import management templates
- [ ] Create documentation generation templates
- [ ] Implement file header templates

### Phase 4: Renderer Integration 🔧
**Goal**: Integrate template rendering into the generation pipeline

#### 4.1 Template Renderer Implementation
- [ ] Create `TemplateRenderer.swift` implementing `RendererProtocol`
- [ ] Add template component selection logic
- [ ] Implement fallback to `TextBasedRenderer`
- [ ] Add rendering performance monitoring
- [ ] Write unit tests for renderer

#### 4.2 Pipeline Integration
- [ ] Modify `GeneratorPipeline.swift`:
  - Add template renderer option
  - Implement renderer selection logic
  - Maintain backward compatibility
- [ ] Update `makeGeneratorPipeline` function
- [ ] Add feature flag checks
- [ ] Test pipeline with both renderers

#### 4.3 Hybrid Rendering
- [ ] Implement component-level template control
- [ ] Add seamless renderer switching
- [ ] Ensure consistent output formatting
- [ ] Test mixed rendering scenarios
- [ ] Document renderer behavior

### Phase 5: Testing & Validation ✅
**Goal**: Comprehensive testing of template functionality

#### 5.1 Unit Testing
- [ ] Template engine tests
- [ ] Context object tests
- [ ] Template rendering tests
- [ ] Configuration tests
- [ ] Error handling tests

#### 5.2 Integration Testing
- [ ] End-to-end generation tests
- [ ] Backward compatibility tests
- [ ] Performance comparison tests
- [ ] Feature flag behavior tests
- [ ] Multi-mode generation tests

#### 5.3 Template Testing
- [ ] Create template test framework
- [ ] Add snapshot tests for generated code
- [ ] Test edge cases and error conditions
- [ ] Validate against HLD requirements
- [ ] Test with real-world OpenAPI specs

#### 5.4 Performance Testing
- [ ] Benchmark template rendering performance
- [ ] Memory usage profiling
- [ ] Large spec handling tests
- [ ] Cache effectiveness tests
- [ ] Optimization opportunities identification

### Phase 6: Documentation & Migration 📚
**Goal**: Comprehensive documentation and migration support

#### 6.1 User Documentation
- [ ] Write template system user guide
- [ ] Create template customization tutorial
- [ ] Document configuration options
- [ ] Add troubleshooting guide
- [ ] Create FAQ section

#### 6.2 Template Documentation
- [ ] Document all template variables
- [ ] Create template examples
- [ ] Add template best practices
- [ ] Write template debugging guide
- [ ] Create template reference

#### 6.3 Migration Guide
- [ ] Write migration guide from default generation
- [ ] Create template migration examples
- [ ] Document breaking changes (if any)
- [ ] Add compatibility matrix
- [ ] Create migration scripts/tools

#### 6.4 Developer Documentation
- [ ] Document template engine architecture
- [ ] Add contribution guidelines for templates
- [ ] Create template testing guide
- [ ] Document internal APIs
- [ ] Add architecture diagrams

### Phase 7: Rollout & Monitoring 🚀
**Goal**: Safe production rollout with monitoring

#### 7.1 Feature Flag Implementation
- [ ] Implement gradual rollout mechanism
- [ ] Add telemetry for template usage
- [ ] Create rollback procedures
- [ ] Document feature flag usage
- [ ] Test flag behavior

#### 7.2 Beta Testing
- [ ] Internal testing with team
- [ ] Select beta users for testing
- [ ] Collect feedback and metrics
- [ ] Address reported issues
- [ ] Performance optimization based on usage

#### 7.3 Production Release
- [ ] Final performance validation
- [ ] Update all documentation
- [ ] Create release notes
- [ ] Update changelog
- [ ] Plan deprecation timeline (if needed)

## Risk Mitigation Strategies

### Performance Risks
- [ ] Implement template caching
- [ ] Add performance benchmarks to CI
- [ ] Create performance regression tests
- [ ] Document performance characteristics
- [ ] Add performance tuning options

### Compatibility Risks
- [ ] Extensive backward compatibility testing
- [ ] Feature flag for gradual adoption
- [ ] Clear migration documentation
- [ ] Support period for old behavior
- [ ] Automated compatibility checks

### Quality Risks
- [ ] Comprehensive test coverage (>90%)
- [ ] Code review requirements
- [ ] Static analysis integration
- [ ] Documentation reviews
- [ ] Beta testing period

## Success Metrics

### Technical Metrics
- [ ] All tests passing
- [ ] No performance regression (±5%)
- [ ] Zero breaking changes
- [ ] >90% test coverage
- [ ] <100ms template rendering time

### Adoption Metrics
- [ ] Beta user satisfaction
- [ ] Documentation completeness
- [ ] Issue resolution time
- [ ] Feature adoption rate
- [ ] Community feedback

## Timeline Estimates

- **Phase 1**: 1 week (Foundation)
- **Phase 2**: 1-2 weeks (Context System)
- **Phase 3**: 2 weeks (Template Development)
- **Phase 4**: 1 week (Integration)
- **Phase 5**: 1-2 weeks (Testing)
- **Phase 6**: 1 week (Documentation)
- **Phase 7**: 2 weeks (Rollout)

**Total**: 9-12 weeks

## Notes

### Implementation Order
1. Start with Phase 1 (Foundation) - required for all subsequent work
2. Phase 2 and 3 can be partially parallelized
3. Phase 4 requires completion of Phase 2 and 3
4. Phase 5 should run continuously alongside development
5. Phase 6 can start early and continue throughout
6. Phase 7 only after all other phases complete

### Key Decision Points
1. After Phase 1: Validate Stencil integration approach
2. After Phase 3: Review template quality and completeness
3. After Phase 5: Go/No-go decision for beta
4. After Phase 7.2: Production release decision

### Dependencies
- Stencil library stability
- No major changes to OpenAPIKit during implementation
- Availability of beta testers
- No conflicting changes to main codebase

---

*Last Updated: [To be updated as implementation progresses]*
*Status: Planning Complete - Ready for Implementation*