# Boundary

Understand the concept of boundaries in Lockman.

## Overview

Boundaryとは、Lockmanにおける**排他制御の境界線**です。LockmanはTCAのCancelIDをこの境界線として利用し、アクションの実行制御を行います。

## CancelIDとの関係

LockmanにおけるBoundaryは、実はTCAのCancelIDと同じものです：

- **Boundary** = 排他制御の境界線を表す概念
- **CancelID** = TCAでタスクをキャンセルするための識別子
- **Lockman** = CancelIDを境界線として活用し、排他制御を実現

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
    cancelId: CancelID.userAction  // このCancelIDがBoundaryとして機能
)
```

## CancelIDを利用する理由

CancelIDを境界線として使用することで、以下の利点があります：

1. **TCAとの自然な統合** - 既存のTCAの仕組みを活用
2. **明確な境界の定義** - CancelIDによって排他制御の範囲が明確になる
3. **柔軟な制御** - 同じCancelIDを持つアクション間で排他制御が可能

## 制限事項

Lockmanの境界による排他制御には、以下の重要な制限があります：

### 1. 境界を超えた排他制御は不可能

異なるCancelID間での排他制御はできません：

```swift
// ❌ できないこと：saveとloadを同時に制御
case .saveButtonTapped:
    // CancelID.saveの境界内でのみ制御
    return .withLock(..., cancelId: CancelID.save)
    
case .loadButtonTapped:
    // CancelID.loadの境界内でのみ制御（saveとは独立）
    return .withLock(..., cancelId: CancelID.load)
```

これらは別々の境界として扱われるため、saveの実行中でもloadは実行可能です。

### 2. 一つのアクションに指定できる境界は一つのみ

単一のアクションに複数のCancelIDを指定することはできません：

```swift
// ❌ できないこと：複数の境界を同時に指定
return .withLock(
    operation: { send in /* ... */ },
    lockFailure: { error, send in /* ... */ },
    action: action,
    cancelId: [CancelID.save, CancelID.validate]  // 複数指定は不可
)
```

複数の処理を同時に制御したい場合は、共通の境界を定義する必要があります：

```swift
// ✅ 正しい方法：共通の境界を使用
enum CancelID {
    case fileOperation  // save, load, validateを含む共通境界
}

case .saveButtonTapped, .loadButtonTapped, .validateButtonTapped:
    return .withLock(..., cancelId: CancelID.fileOperation)
```

## まとめ

Boundaryは排他制御の境界線であり、LockmanはTCAのCancelIDをこの境界として活用します。適切な境界を設定することで、アプリケーションの安定性と応答性を両立できます。

## 次のステップ

- <doc:Lock> - 境界内でのロック取得の詳細
- <doc:Unlock> - ロックの解放とCancelIDの関係
- <doc:ChoosingStrategy> - より高度な境界制御戦略
