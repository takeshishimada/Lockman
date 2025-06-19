# Unlock Options

ロック解放タイミングを制御するUnlockOptionの詳細ガイド

@Metadata {
    @PageImage(purpose: icon, source: "Lockman", alt: "Lockman Logo")
}

## 概要

`UnlockOption`は、Lockmanがロックを解放するタイミングを制御する重要な機能です。UI遷移、アニメーション、リソースのクリーンアップなど、様々なシナリオに対応できます。UIの応答性とデータの一貫性のバランスを取るために、適切なオプションを選択することが重要です。

## UnlockOptionの種類

```swift
public enum UnlockOption: Sendable, Equatable {
    /// 即座にロックを解放
    case immediate
    
    /// メインランループで次のサイクルに解放
    case mainRunLoop
    
    /// アニメーションなどの遷移時間を考慮して解放
    case transition  // プラットフォームごとのデフォルト遅延を使用
    
    /// 指定秒数後に解放
    case delayed(TimeInterval)  // 秒単位で指定
}
```

## 各オプションの詳細

### .immediate

処理完了と同時に即座にロックを解放します。

```swift
return .withLock(
    unlockOption: .immediate,
    operation: { send in
        let data = try await api.fetchData()
        await send(.dataReceived(data))
        // ここで即座にロック解放
    },
    action: DataAction.fetch,
    cancelID: CancelID.userAction
)
```

### .mainRunLoop

メインランループの次のサイクルでロックを解放します。

```swift
return .withLock(
    unlockOption: .mainRunLoop,
    operation: { send in
        // UI更新を含む処理
        await send(.updateUI(newData))
        // メインランループの次のサイクルで解放
    },
    action: UIAction.update,
    cancelID: CancelID.ui
)
```

### .transition

遷移アニメーションに必要な時間を待機後にロックを解放します。

```swift
return .withLock(
    unlockOption: .transition,
    operation: { send in
        await send(.navigateToDetail(item))
    },
    action: NavigationAction.push,
    cancelID: CancelID.navigation
)
```

プラットフォーム固有のデフォルト値：
- iOS: 0.35秒（標準的な画面遷移時間）
- macOS: 0.25秒
- その他: 0.3秒

### .delayed(_:)

指定した秒数（TimeInterval）の遅延後にロックを解放します。

```swift
return .withLock(
    unlockOption: .delayed(0.5),  // 0.5秒後に解放
    operation: { send in
        await send(.customAnimation)
    },
    action: CustomAction.animate,
    cancelID: CancelID.animation
)
```

## 実装例

### 画面遷移での使用

```swift
@Reducer
struct NavigationFeature {
    @ObservableState
    struct State {
        @Presents var destination: Destination.State?
    }
    
    enum Action {
        case rowTapped(Item)
        case destination(PresentationAction<Destination.Action>)
    }
    
    enum CancelID {
        case userAction
    }
    
    @LockmanSingleExecution
    enum NavAction {
        case navigate(to: String)
        
        var lockmanInfo: LockmanSingleExecutionInfo {
            .init(actionId: actionName, mode: .boundary)
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case let .rowTapped(item):
                return .withLock(
                    unlockOption: .transition,  // プラットフォーム固有の遷移時間を使用
                    operation: { send in
                        // データ準備
                        let details = try await loadDetails(item.id)
                        
                        // 画面遷移
                        state.destination = .detail(
                            DetailFeature.State(item: details)
                        )
                    },
                    action: NavAction.navigate(to: item.id),
                    cancelID: CancelID.userAction
                )
                
            case .destination:
                return .none
            }
        }
    }
}
```

### トースト表示パターン

```swift
@Reducer
struct ToastFeature {
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .showSuccessToast:
                return .withLock(
                    unlockOption: .delayed(3.0), // 3秒間表示
                    operation: { send in
                        state.toast = .success("保存しました")
                        
                        // 3秒後に自動的に非表示
                        try await Task.sleep(for: .seconds(3))
                        await send(.hideToast)
                    },
                    action: ToastAction.show,
                    cancelID: CancelID.toast
                )
            }
        }
    }
}
```

## 次のステップ

- <doc:EffectWithLock> - Effect.withLockの詳細
- <doc:Debugging> - UnlockOptionのデバッグ方法
