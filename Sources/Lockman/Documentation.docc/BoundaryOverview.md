# Boundary

Understand the concept of boundaries in Lockman.

## Overview

Boundaryとは、Lockmanにおける**排他制御の境界**です。LockmanはTCAのCancelIDをこの境界として利用し、アクションの実行制御を行います。

```swift
// withLockでCancelIDを境界として指定
return .withLock(
    operation: { send in
        // 処理
    },
    lockFailure: { error, send in
        // 同じ境界内で既に実行中の場合の処理
    },
    action: action,
    cancelID: CancelID.userAction  // このCancelIDがBoundaryとして機能
)
```

CancelIDを境界として使用することで、以下の利点があります：

1. **TCAとの自然な統合** - 既存のTCAの仕組みを活用
2. **明確な境界の定義** - CancelIDによって排他制御の範囲が明確になる

## Boundaryの仕様

### 1. 境界を超えた排他制御は不可能

異なるBoundary間での排他制御はできません：

```swift
// ❌ できないこと：saveとloadを同時に制御
case .saveButtonTapped:
    // CancelID.saveの境界内でのみ制御
    return .withLock(..., cancelID: CancelID.save)
    
case .loadButtonTapped:
    // CancelID.loadの境界内でのみ制御（saveとは独立）
    return .withLock(..., cancelID: CancelID.load)
```

これらは別々の境界として扱われるため、saveの実行中でもloadは実行可能です。

### 2. 一つのアクションに指定できるBoundaryは一つのみ

単一のアクションに複数のBoundaryを指定することはできません：

```swift
// ❌ できないこと：複数のBoundaryを同時に指定
return .withLock(
    operation: { send in /* ... */ },
    lockFailure: { error, send in /* ... */ },
    action: action,
    cancelID: [CancelID.save, CancelID.validate]  // 複数指定は不可
)
```

複数の処理を同時に制御したい場合は、共通のBoundaryを定義する必要があります：

```swift
// ✅ 正しい方法：共通の境界を使用
enum CancelID {
    case fileOperation  // save, load, validateを含む共通境界
}

case .saveButtonTapped, .loadButtonTapped, .validateButtonTapped:
    return .withLock(..., cancelID: CancelID.fileOperation)
```

## まとめ

適切な境界を設定することで、アプリケーションの安定性と応答性を両立できます。

