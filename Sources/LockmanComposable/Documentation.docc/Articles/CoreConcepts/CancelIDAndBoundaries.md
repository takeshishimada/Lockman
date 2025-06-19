# CancelID and Boundaries

Lockmanにおける境界の考え方と設計原則

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

LockmanはTCAの`CancelID`を境界（boundary）として活用し、アクションの排他制御範囲を定義します。この設計により、画面ごとに独立した制御領域を作り、予期しない競合を防ぎます。

## 基本的な考え方

### なぜCancelIDを境界として使うのか

TCAでは、CancelIDは本来Effectのキャンセレーション管理に使われます。Lockmanはこの既存の仕組みを活用することで：

1. **新しい概念の学習が不要** - TCAユーザーが既に理解している概念を再利用
2. **自然な統合** - キャンセレーションとロック管理が一体化
3. **型安全** - Swiftのコンパイラが境界の一貫性を保証

### 一画面一境界の原則

**最も重要な原則：各画面（Feature）は1つのCancelIDを持つべきです。**

```swift
// ✅ 正しい設計
@Reducer
struct ProfileFeature {
    enum CancelID {
        case userAction  // この画面のすべてのユーザーアクション
    }
}

// ❌ 誤った設計
@Reducer
struct ProfileFeature {
    enum CancelID {
        case loadProfile
        case saveProfile
        case uploadImage
        // 複数の境界を作ると制御が複雑に
    }
}
```

### なぜ一画面一境界なのか

ユーザーの視点で考えてみましょう：

1. **ユーザーは一度に一つの操作をする**
   - 保存ボタンを連打しても、一度だけ実行されるべき
   - 読み込み中に他のボタンを押しても、適切に制御されるべき

2. **画面内の操作は相互に影響する**
   - データ読み込み中は保存できない
   - 保存中は削除できない
   - これらは同じ境界内で管理されるべき

3. **異なる画面の操作は独立している**
   - プロフィール画面の操作と設定画面の操作は無関係
   - それぞれ独立した境界を持つべき

## アンチパターン

### 操作ごとにCancelIDを作る

```swift
// ❌ 避けるべき
enum CancelID {
    case fetchUser
    case updateProfile  
    case uploadAvatar
    // 管理が複雑になり、意図しない並行実行が発生
}
```

### アプリ全体で1つのCancelID

```swift
// ❌ 避けるべき
enum GlobalCancelID {
    case all  // すべての画面で共有
}
// 異なる画面の操作まで相互に影響してしまう
```

## 次のステップ

- <doc:SingleExecution> - mode設定の詳細
- <doc:EffectWithLock> - withLock APIの使い方
- <doc:UnlockOptions> - ロック解放タイミングの制御
