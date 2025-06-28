# ``Lockman``

A library to implement exclusive control of user actions in application development using TCA.

@Metadata {
  @PageImage(purpose: icon, source: "Lockman.png", alt: "Lockman logo")
}

## Overview

Lockman provides a comprehensive solution for managing exclusive control over user actions in applications built with The Composable Architecture (TCA). It offers various strategies to handle concurrent operations, prevent duplicate executions, and maintain consistent application state.

## Topics

### Getting started
- <doc:GettingStarted>
- <doc:AddingLockmanDependency>
- <doc:WritingYourFirstFeature>

### Boundary
- <doc:BoundaryOverview>

### Lock & Unlock
- <doc:LockUnlockOverview>
- <doc:TCAIntegration>
- <doc:EffectExtension>
- <doc:ReducerIntegration>

### Strategies
- <doc:StrategiesOverview>
- <doc:ChoosingStrategy>
- <doc:SingleExecutionStrategy>
- <doc:PriorityBasedStrategy>
- <doc:ConcurrencyLimitedStrategy>
- <doc:GroupCoordinationStrategy>
- <doc:DynamicConditionStrategy>
- <doc:CompositeStrategy>

### Advance
- <doc:CustomStrategy>
- <doc:Configuration>

### Debugging
- <doc:Debugging>

### Performance
- <doc:Performance>

### Troubleshooting
- <doc:CommonIssues>
- <doc:FAQ>