# DynamicConditionStrategy

Control actions based on runtime conditions.

## Overview

DynamicConditionStrategyは、実行時の状態や条件に基づいて動的にロック制御を行う戦略です。カスタムロジックによる条件判定により、ビジネスルールに応じた柔軟な排他制御を実現できます。

この戦略は、標準戦略では表現できない複雑なビジネス条件や、アプリケーション状態に応じた動的な制御が必要な場面で使用されます。

## 条件評価システム

### 基本的な条件指定

```swift
LockmanDynamicConditionInfo(
    actionId: "payment",
    condition: {
        // カスタム条件ロジック
        guard userIsAuthenticated else {
            return .failure(AuthenticationError.notLoggedIn)
        }
        guard accountBalance >= requiredAmount else {
            return .failure(PaymentError.insufficientFunds)
        }
        return .success
    }
)
```

### ReduceWithLockによる高度な制御

ReduceWithLockを使用することで、現在の状態とアクションに基づいたより高度な条件評価が可能です：

```swift
ReduceWithLock { state, action in
    switch action {
    case .makePayment(let amount):
        return self.withLock(
            state: state,
            action: action,
            operation: { send in
                try await processPayment(amount)
                send(.paymentCompleted)
            },
            lockAction: PaymentAction.makePayment,
            cancelID: CancelID.payment,
            lockCondition: { state, action in
                // アクションレベルの条件
                guard state.balance >= amount else {
                    return .failure(PaymentError.insufficientFunds(
                        required: amount, 
                        available: state.balance
                    ))
                }
                return .success
            }
        )
    }
} lockCondition: { state, _ in
    // リデューサーレベルの条件
    guard state.isAuthenticated else {
        return .failure(AuthenticationError.notLoggedIn)
    }
    return .success
}
```

## 使用方法

### 基本的な使用例

```swift
@LockmanDynamicCondition
enum Action {
    case transfer(amount: Double)
    case withdraw(amount: Double)
    
    var lockmanInfo: LockmanDynamicConditionInfo {
        switch self {
        case .transfer(let amount):
            return LockmanDynamicConditionInfo(
                actionId: actionName,
                condition: {
                    // 営業時間チェック
                    guard BusinessHours.isOpen else {
                        return .failure(BankError.outsideBusinessHours)
                    }
                    // 金額制限チェック
                    guard amount <= transferLimit else {
                        return .failure(BankError.transferLimitExceeded)
                    }
                    return .success
                }
            )
        case .withdraw(let amount):
            return LockmanDynamicConditionInfo(
                actionId: actionName,
                condition: {
                    // ATM利用可能性チェック
                    guard ATMService.isAvailable else {
                        return .failure(BankError.atmUnavailable)
                    }
                    return .success
                }
            )
        }
    }
}
```

### 多段階条件評価

ReduceWithLockは3段階の条件評価を提供します：

1. **アクションレベル条件**: 特定の操作に対する条件
2. **リデューサーレベル条件**: 全体的な前提条件
3. **従来のロック戦略**: 標準的な排他制御

```swift
ReduceWithLock { state, action in
    switch action {
    case .criticalOperation:
        return self.withLock(
            state: state,
            action: action,
            operation: { send in
                try await performCriticalOperation()
                send(.operationCompleted)
            },
            lockAction: CriticalAction.execute, // 3. 従来戦略（SingleExecution等）
            cancelID: CancelID.critical,
            lockCondition: { state, _ in
                // 1. アクションレベル条件
                guard state.systemStatus == .ready else {
                    return .failure(SystemError.notReady)
                }
                return .success
            }
        )
    }
} lockCondition: { state, _ in
    // 2. リデューサーレベル条件
    guard state.maintenanceMode == false else {
        return .failure(SystemError.maintenanceMode)
    }
    return .success
}
```

## 動作例

### 基本的な条件判定

```
時刻: 9:00  - transfer($1000)要求
  条件1: 営業時間チェック → ✅ 営業中
  条件2: 金額制限チェック → ✅ 制限内
  結果: ✅ 実行

時刻: 18:00 - transfer($1000)要求  
  条件1: 営業時間チェック → ❌ 営業時間外
  結果: ❌ 拒否（BankError.outsideBusinessHours）

時刻: 10:00 - transfer($50000)要求
  条件1: 営業時間チェック → ✅ 営業中
  条件2: 金額制限チェック → ❌ 制限超過
  結果: ❌ 拒否（BankError.transferLimitExceeded）
```

### 多段階評価の動作

```
criticalOperation要求:

Step 1: リデューサーレベル条件
  maintenanceMode == false → ✅ 通過

Step 2: アクションレベル条件  
  systemStatus == .ready → ✅ 通過

Step 3: 従来戦略（例：SingleExecution）
  重複実行チェック → ✅ 通過

結果: ✅ 全段階通過で実行開始
```

## エラーハンドリング

### カスタムエラーの活用

```swift
enum BusinessError: Error {
    case insufficientFunds(required: Double, available: Double)
    case dailyLimitExceeded(limit: Double)
    case accountSuspended(reason: String)
    case outsideBusinessHours
}

lockFailure: { error, send in
    switch error as? BusinessError {
    case .insufficientFunds(let required, let available):
        send(.showError("残高不足: 必要額¥\(required)、残高¥\(available)"))
        
    case .dailyLimitExceeded(let limit):
        send(.showError("1日の利用限度額¥\(limit)を超過しています"))
        
    case .accountSuspended(let reason):
        send(.showError("アカウントが停止されています: \(reason)"))
        
    case .outsideBusinessHours:
        send(.showError("営業時間外です（平日9:00-17:00）"))
        
    default:
        send(.showError("操作を実行できません"))
    }
}
```

## ガイド

次のステップ <doc:CompositeStrategy>

前のステップ <doc:GroupCoordinationStrategy>
