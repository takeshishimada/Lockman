# ``Lockman``

A library to implement exclusive control of user actions in application development using TCA.

@Metadata {
  @PageImage(purpose: icon, source: "Lockman.png", alt: "Lockman logo")
}

## Design Philosophy

### Principles from Designing Fluid Interfaces

WWDC18's "Designing Fluid Interfaces" presented principles for exceptional interfaces:

- **Immediate Response and Continuous Redirection** - Responsiveness that doesn't allow even 10ms of delay
- **One-to-One Touch and Content Movement** - Content follows the finger during drag operations
- **Continuous Feedback** - Immediate reaction to all interactions
- **Parallel Gesture Detection** - Recognizing multiple gestures simultaneously
- **Spatial Consistency** - Maintaining position consistency during animations
- **Lightweight Interactions, Amplified Output** - Large effects from small inputs

### Traditional Challenges

Traditional UI development has solved problems by simply prohibiting simultaneous button presses and duplicate executions. These approaches have become factors that hinder user experience in modern fluid interface design.

Users expect some form of feedback even when pressing buttons simultaneously. It's crucial to clearly separate immediate response at the UI layer from appropriate mutual exclusion control at the business logic layer.

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
- <doc:DebuggingGuide>

### Strategies
- <doc:SingleExecutionStrategy>
- <doc:PriorityBasedStrategy>
- <doc:ConcurrencyLimitedStrategy>
- <doc:GroupCoordinationStrategy>
- <doc:DynamicConditionStrategy>
- <doc:CompositeStrategy>