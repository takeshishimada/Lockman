# ``Lockman``

A library to implement exclusive control of user actions in application development using TCA.

@Metadata {
  @PageImage(purpose: icon, source: "Lockman.png", alt: "Lockman logo")
}

## Overview

Lockman provides a comprehensive solution for managing exclusive control over user actions in applications built with The Composable Architecture (TCA). It offers various strategies to handle concurrent operations, prevent duplicate executions, and maintain consistent application state.

## Topics

### Essentials
- <doc:GettingStarted>
- <doc:BoundaryOverview>
- <doc:Lock>
- <doc:Unlock>
- <doc:ChoosingStrategy>
- <doc:Configuration>

### Strategies
- <doc:StrategiesOverview>
- <doc:SingleExecutionStrategy>
- <doc:PriorityBasedStrategy>
- <doc:ConcurrencyLimitedStrategy>
- <doc:GroupCoordinationStrategy>
- <doc:DynamicConditionStrategy>
- <doc:CompositeStrategy>

### Advanced
- <doc:CustomStrategyImplementation>
- <doc:DebuggingGuide>