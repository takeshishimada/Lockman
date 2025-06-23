# ``Lockman``

Lockman is a Swift library that solves concurrent action control issues in The Composable Architecture (TCA) applications, with responsiveness, transparency, and declarative design in mind.

@Metadata {
  @PageImage(purpose: icon, source: "Lockman.png", alt: "Lockman logo")
}

## Overview

Lockman provides the following control strategies to address common problems in app development:

- **Single Execution**: Prevents duplicate execution of the same action
- **Priority Based**: Action control and cancellation based on priority
- **Group Coordination**: Group control through leader/member roles
- **Dynamic Condition**: Dynamic control based on runtime conditions
- **Composite Strategy**: Combination of multiple strategies

## Topics

### Getting Started

- ``LockmanManager``
- ``LockmanPriorityBasedInfo``
- ``LockmanGroupCoordinatedInfo``