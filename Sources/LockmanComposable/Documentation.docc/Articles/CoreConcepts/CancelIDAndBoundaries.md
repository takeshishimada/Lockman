# CancelID and Boundaries

Lockmanにおける境界の考え方と設計原則

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
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

## 実践的な設計

### 基本的な実装

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State {
        var profile: Profile?
        var isLoading = false
    }
    
    enum Action {
        case loadButtonTapped
        case saveButtonTapped
        case deleteButtonTapped
        // ... その他のアクション
    }
    
    // 一画面一境界
    enum CancelID {
        case userAction
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .loadButtonTapped:
                return .withLock(
                    operation: { /* 読み込み処理 */ },
                    action: LoadAction(),
                    cancelID: CancelID.userAction  // 同じ境界
                )
                
            case .saveButtonTapped:
                return .withLock(
                    operation: { /* 保存処理 */ },
                    action: SaveAction(),
                    cancelID: CancelID.userAction  // 同じ境界
                )
                
            case .deleteButtonTapped:
                return .withLock(
                    operation: { /* 削除処理 */ },
                    action: DeleteAction(),
                    cancelID: CancelID.userAction  // 同じ境界
                )
            }
        }
    }
}
```

### modeとの関係

SingleExecutionStrategyの`mode`設定は、境界内でのさらに細かい制御を提供します：

```swift
@LockmanSingleExecution
enum ProfileAction {
    case load
    case save
    case delete
    
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(
            actionId: actionName,
            mode: .boundary  // または .action
        )
    }
}
```

**mode: .boundary**（推奨）
- 境界内で一度に1つのアクションのみ実行
- 画面全体で排他制御

**mode: .action**
- 同じactionIdのみ排他制御
- loadとsaveは並行実行可能

### 考え方の違い

```swift
// mode: .boundary の考え方
// 「ユーザーは一度に一つの操作をする」
// → 読み込み中は保存も削除もできない

// mode: .action の考え方
// 「同じ種類の操作は重複させない」
// → 読み込みながら保存は可能、ただし保存の重複は防ぐ
```

## よくある設計パターン

### 1. 標準的な画面

```swift
// プロフィール、設定、詳細画面など
enum CancelID {
    case userAction
}
```

### 2. タブ付き画面

```swift
// タブごとに独立した制御が必要な場合
enum CancelID {
    case userAction  // 基本はこれ1つ
    // タブが完全に独立している場合のみ：
    // case tab1
    // case tab2
}
```

### 3. モーダル/シート

```swift
// 親画面とは独立した境界を持つ
struct ModalFeature {
    enum CancelID {
        case userAction  // モーダル内の操作
    }
}
```

## 設計時の判断基準

新しい機能を追加する際の判断フロー：

1. **同じ画面内か？**
   - Yes → 既存のCancelID.userActionを使用
   - No → 新しいFeatureとCancelIDを作成

2. **ユーザーから見て独立した操作か？**
   - Yes → 別のCancelIDを検討
   - No → 同じCancelID.userActionを使用

3. **並行実行が必要か？**
   - Yes → mode: .actionを検討
   - No → mode: .boundary（デフォルト）

## アンチパターン

### 1. 操作ごとにCancelIDを作る

```swift
// ❌ 避けるべき
enum CancelID {
    case fetchUser
    case updateProfile  
    case uploadAvatar
    // 管理が複雑になり、意図しない並行実行が発生
}
```

### 2. アプリ全体で1つのCancelID

```swift
// ❌ 避けるべき
enum GlobalCancelID {
    case all  // すべての画面で共有
}
// 異なる画面の操作まで相互に影響してしまう
```

### 3. 動的すぎるCancelID

```swift
// ❌ 避けるべき
enum CancelID {
    case operation(UUID())  // 毎回新しい境界
}
// 排他制御が機能しない
```

## まとめ

- **一画面一境界** - 各Featureは1つのCancelID.userActionを持つ
- **ユーザー視点で考える** - ユーザーの操作フローに合わせて境界を設計
- **シンプルに保つ** - 複雑な境界設計は避け、必要最小限に
- **modeで微調整** - 境界内での制御はmodeで調整

この原則に従うことで、予測可能で保守しやすい排他制御を実現できます。

## 次のステップ

- <doc:SingleExecution> - mode設定の詳細
- <doc:EffectWithLock> - withLock APIの使い方
- <doc:UnlockOptions> - ロック解放タイミングの制御