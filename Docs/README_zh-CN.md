<img src="../Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%205.10%20%7C%206.0-ED523F.svg?style=flat)](https://swift.org/download/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Mac%20Catalyst-333333.svg?style=flat)](https://developer.apple.com/)

[English](../README.md) | [日本語](README_ja.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [Español](README_es.md) | [Français](README_fr.md) | [Deutsch](README_de.md) | [한국어](README_ko.md) | [Português](README_pt-BR.md) | [Italiano](README_it.md)

Lockman 是一个 Swift 库，旨在解决 The Composable Architecture (TCA) 应用程序中的并发动作控制问题，注重响应性、透明性和声明式设计。

* [设计理念](#设计理念)
* [概述](#概述)
* [基本示例](#基本示例)
* [安装](#安装)
* [社区](#社区)

## 设计理念

### Designing Fluid Interfaces 原则

WWDC18 的"Designing Fluid Interfaces"提出了卓越界面的原则：

* **即时响应和持续重定向** - 不允许有 10 毫秒延迟的响应性
* **一对一的触摸和内容移动** - 拖动操作时内容跟随手指
* **持续反馈** - 对所有交互的即时反应
* **并行手势检测** - 同时识别多个手势
* **空间一致性** - 动画期间保持位置一致性
* **轻量级交互，放大输出** - 小输入产生大效果

### 传统挑战

传统 UI 开发通过简单地禁止同时按下按钮和重复执行来解决问题。这些方法已成为现代流畅界面设计中阻碍用户体验的因素。

用户期望即使同时按下按钮也能获得某种形式的反馈。在 UI 层的即时响应与业务逻辑层的适当互斥控制之间进行清晰分离至关重要。

## 概述

Lockman 提供以下控制策略来解决应用开发中的常见问题：

* **Single Execution**：防止相同动作的重复执行
* **Priority Based**：基于优先级的动作控制和取消
* **Group Coordination**：通过领导者/成员角色进行组控制
* **Dynamic Condition**：基于运行时条件的动态控制
* **Concurrency Limited**：限制每组的并发执行数量
* **Composite Strategy**：多种策略的组合

## 示例

| Single Execution Strategy | Priority Based Strategy | Concurrency Limited Strategy |
|--------------------------|------------------------|------------------------------|
| ![Single Execution Strategy](../Sources/Lockman/Documentation.docc/images/01-SingleExecutionStrategy.gif) | ![Priority Based Strategy](../Sources/Lockman/Documentation.docc/images/02-PriorityBasedStrategy.gif) | ![Concurrency Limited Strategy](../Sources/Lockman/Documentation.docc/images/03-ConcurrencyLimitedStrategy.gif) |

## 代码示例

以下是如何使用 `@LockmanSingleExecution` 宏实现防止进程重复执行的功能：

```swift
import CasePaths
import ComposableArchitecture
import Lockman

@Reducer
struct ProcessFeature {
    @ObservableState
    struct State: Equatable {
        var isProcessing = false
        var message = ""
    }
    
    @CasePathable
    enum Action: ViewAction {
        case view(ViewAction)
        case `internal`(InternalAction)
        
        @LockmanSingleExecution
        enum ViewAction {
            case startProcessButtonTapped
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                .init(actionId: actionName, mode: .boundary)
            }
        }
        
        enum InternalAction {
            case processStart
            case processCompleted
            case updateMessage(String)
        }
    }
    
    enum CancelID {
        case userAction
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .startProcessButtonTapped:
                    return .run { send in
                        await send(.internal(.processStart))
                        // 模拟重处理
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        await send(.internal(.processCompleted))
                    }
                }
                
            case let .internal(internalAction):
                switch internalAction {
                case .processStart:
                    state.isProcessing = true
                    state.message = "处理已开始..."
                    return .none
                    
                case .processCompleted:
                    state.isProcessing = false
                    state.message = "处理已完成"
                    return .none
                    
                case .updateMessage(let message):
                    state.message = message
                    return .none
                }
            }
        }
        .lock(
            boundaryId: CancelID.userAction,
            lockFailure: { error, send in
                // 当处理已经在进行中时
                if error is LockmanSingleExecutionError {
                    // 通过动作更新消息而不是直接修改状态
                    await send(.internal(.updateMessage("处理已经在进行中")))
                }
            },
            for: \.view
        )
    }
}
```

`Reducer.lock` 修饰符自动对符合 `LockmanAction` 的动作应用锁管理。由于 `ViewAction` 枚举被标记为 `@LockmanSingleExecution`，`startProcessButtonTapped` 动作在处理进行中时不会被执行。`for: \.view` 参数告诉 Lockman 检查嵌套在 `view` 情况中的动作的 `LockmanAction` 一致性。

### 调试输出示例

```
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 7BFC785A-3D25-4722-B9BC-A3A63A7F49FC, mode: boundary)
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 1EBA9632-DE39-43B6-BE75-7C754476CD4E, mode: boundary), Reason: Boundary 'process' already has an active lock
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 6C5C569F-4534-40D7-98F6-B4F4B0EE1293, mode: boundary), Reason: Boundary 'process' already has an active lock
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: C6779CD1-F8FE-46EB-8605-109F7C8DCEA8, mode: boundary)
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: A54E7748-A3DE-451A-BF06-56224A5C94DA, mode: boundary), Reason: Boundary 'process' already has an active lock
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 7D4D67A7-1A8C-4521-BB16-92E0D551451A, mode: boundary), Reason: Boundary 'process' already has an active lock
✅ [Lockman] canLock succeeded - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: 08CC1862-136F-4643-A796-F63156D8BF56, mode: boundary)
❌ [Lockman] canLock failed - Strategy: SingleExecution, BoundaryId: process, Info: LockmanSingleExecutionInfo(actionId: 'startProcessButtonTapped', uniqueId: DED418D1-4A10-4EF8-A5BC-9E93D04188CA, mode: boundary), Reason: Boundary 'process' already has an active lock

📊 Current Lock State (SingleExecutionStrategy):
┌─────────────────┬──────────────────┬──────────────────────────────────────┬─────────────────┐
│ Strategy        │ BoundaryId       │ ActionId/UniqueId                    │ Additional Info │
├─────────────────┼──────────────────┼──────────────────────────────────────┼─────────────────┤
│ SingleExecution │ CancelID.process │ startProcessButtonTapped             │ mode: boundary  │
│                 │                  │ 08CC1862-136F-4643-A796-F63156D8BF56 │                 │
└─────────────────┴──────────────────┴──────────────────────────────────────┴─────────────────┘
```

## 文档

发布版本和 `main` 分支的文档可在此处获取：

* [`main`](https://takeshishimada.github.io/Lockman/main/documentation/lockman/)
* [1.0.0](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/) ([迁移指南](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/migrationguides/migratingto1.0))

<details>
<summary>其他版本</summary>

* [0.13.0](https://takeshishimada.github.io/Lockman/0.13.0/documentation/lockman/)
* [0.12.0](https://takeshishimada.github.io/Lockman/0.12.0/documentation/lockman/)
* [0.11.0](https://takeshishimada.github.io/Lockman/0.11.0/documentation/lockman/)
* [0.10.0](https://takeshishimada.github.io/Lockman/0.10.0/documentation/lockman/)
* [0.9.0](https://takeshishimada.github.io/Lockman/0.9.0/documentation/lockman/)
* [0.8.0](https://takeshishimada.github.io/Lockman/0.8.0/documentation/lockman/)
* [0.7.0](https://takeshishimada.github.io/Lockman/0.7.0/documentation/lockman/)
* [0.6.0](https://takeshishimada.github.io/Lockman/0.6.0/documentation/lockman/)
* [0.5.0](https://takeshishimada.github.io/Lockman/0.5.0/documentation/lockman/)
* [0.4.0](https://takeshishimada.github.io/Lockman/0.4.0/documentation/lockman/)
* [0.3.0](https://takeshishimada.github.io/Lockman/0.3.0/documentation/lockman/)

</details>

文档中有许多文章可以帮助您更好地使用该库：

### 基础知识
* [入门指南](https://takeshishimada.github.io/Lockman/main/documentation/lockman/gettingstarted) - 了解如何将 Lockman 集成到您的 TCA 应用程序中
* [边界概述](https://takeshishimada.github.io/Lockman/main/documentation/lockman/boundaryoverview) - 理解 Lockman 中的边界概念
* [锁定](https://takeshishimada.github.io/Lockman/main/documentation/lockman/lock) - 理解锁定机制
* [解锁](https://takeshishimada.github.io/Lockman/main/documentation/lockman/unlock) - 理解解锁机制
* [选择策略](https://takeshishimada.github.io/Lockman/main/documentation/lockman/choosingstrategy) - 为您的用例选择合适的策略
* [配置](https://takeshishimada.github.io/Lockman/main/documentation/lockman/configuration) - 根据应用程序需求配置 Lockman
* [错误处理](https://takeshishimada.github.io/Lockman/main/documentation/lockman/errorhandling) - 了解常见的错误处理模式
* [调试指南](https://takeshishimada.github.io/Lockman/main/documentation/lockman/debuggingguide) - 调试应用程序中与 Lockman 相关的问题

### 策略
* [Single Execution Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/singleexecutionstrategy) - 防止重复执行
* [Priority Based Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/prioritybasedstrategy) - 基于优先级的控制
* [Concurrency Limited Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/concurrencylimitedstrategy) - 限制并发执行
* [Group Coordination Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/groupcoordinationstrategy) - 协调相关动作
* [Dynamic Condition Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/dynamicconditionstrategy) - 动态运行时控制
* [Composite Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/compositestrategy) - 组合多种策略

注：文档仅提供英文版本。

## 安装

Lockman 可以使用 [Swift Package Manager](https://swift.org/package-manager/) 进行安装。

### Xcode

在 Xcode 中，选择 File → Add Package Dependencies 并输入以下 URL：

```
https://github.com/takeshishimada/Lockman
```

### Package.swift

将依赖项添加到您的 Package.swift 文件中：

```swift
dependencies: [
  .package(url: "https://github.com/takeshishimada/Lockman", from: "1.0.0")
]
```

将依赖项添加到您的目标中：

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "Lockman", package: "Lockman"),
  ]
)
```

### 系统要求

| 平台      | 最低版本 |
|----------|---------|
| iOS      | 13.0    |
| macOS    | 10.15   |
| tvOS     | 13.0    |
| watchOS  | 6.0     |

### 版本兼容性

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 1.0.0   | 1.20.2                     |
| 0.13.4  | 1.20.2                     |
| 0.13.3  | 1.20.2                     |
| 0.13.2  | 1.20.2                     |
| 0.13.1  | 1.20.2                     |
| 0.13.0  | 1.20.2                     |
| 0.12.0  | 1.20.1                     |
| 0.11.0  | 1.19.1                     |
| 0.10.0  | 1.19.0                     |
| 0.9.0   | 1.18.0                     |
| 0.8.0   | 1.17.1                     |

<details>
<summary>其他版本</summary>

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 0.7.0   | 1.17.1                     |
| 0.6.0   | 1.17.1                     |
| 0.5.0   | 1.17.1                     |
| 0.4.0   | 1.17.1                     |
| 0.3.0   | 1.17.1                     |
| 0.2.1   | 1.17.1                     |
| 0.2.0   | 1.17.1                     |
| 0.1.0   | 1.17.1                     |

</details>

## 社区

### 讨论和帮助

可以在 [GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions) 上进行问题讨论。

### 错误报告

如果发现错误，请在 [Issues](https://github.com/takeshishimada/Lockman/issues) 上报告。

### 贡献

如果您想为该库做出贡献，请创建一个 PR 并附上相关链接！

## 许可证

本库基于 MIT 许可证发布。详情请参阅 [LICENSE](./LICENSE) 文件。