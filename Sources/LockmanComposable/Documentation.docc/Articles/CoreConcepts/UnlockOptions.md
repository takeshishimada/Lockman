# Unlock Options

ロック解放タイミングを制御するUnlockOptionの詳細ガイド

@Metadata {
    @PageImage(purpose: card, source: "Lockman", alt: "Lockman Logo")
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
    case transition(seconds: Double)
    
    /// 指定秒数後に解放（リソースクリーンアップ用）
    case delayed(seconds: Double)
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

適している場面：
- データ取得や計算などの非UI処理
- 次の操作を即座に許可したい場合
- パフォーマンスを重視する場合
- 高速な処理
- 連続的な操作を許可したい場合

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

適している場面：
- UI更新を伴う処理
- SwiftUIのビュー更新と同期したい場合
- 即座の再実行を避けたい軽量な処理
- アニメーションとの同期
- 描画サイクルとの調整が必要な場合

### .transition(seconds:)

指定した秒数後にロックを解放します。主にアニメーション完了を待つ場合に使用。

```swift
return .withLock(
    unlockOption: .transition(seconds: 0.3),  // 標準的なアニメーション時間
    operation: { send in
        await send(.navigateToDetail(item))
        // 0.3秒後（アニメーション完了後）に解放
    },
    action: NavigationAction.push,
    cancelID: CancelID.navigation
)
```

プラットフォーム固有のデフォルト値：
- iOS: 0.35秒（標準的な画面遷移時間）
- macOS: 0.25秒
- その他: 0.3秒

適している場面：
- 画面遷移アニメーション
- カスタムアニメーション
- UIの視覚的な完了を待つ必要がある場合
- モーダル表示/非表示
- タブ切り替え

### .delayed(seconds:)

指定した秒数の遅延後にロックを解放します。リソースのクリーンアップに使用。

```swift
return .withLock(
    unlockOption: .delayed(seconds: 2.0),
    operation: { send in
        // 大量のリソースを使用する処理
        let result = try await heavyProcessing()
        await send(.processingCompleted(result))
        // 2秒後に解放（リソースクリーンアップ時間を確保）
    },
    action: HeavyAction.process,
    cancelID: CancelID.heavy
)
```

適している場面：
- メモリ集約的な処理
- 外部リソースのクリーンアップが必要な場合
- 連続実行を意図的に制限したい場合
- カスタムアニメーション
- トースト/スナックバー表示

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
                    unlockOption: .transition(seconds: 0.35),  // iOS標準のpush animation
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

### モーダル表示での使用

```swift
@Reducer
struct ModalFeature {
    @ObservableState
    struct State {
        @Presents var alert: AlertState<Action.Alert>?
        var isProcessing = false
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .deleteButtonTapped:
                state.alert = AlertState {
                    TextState("確認")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmDelete) {
                        TextState("削除")
                    }
                    ButtonState(role: .cancel) {
                        TextState("キャンセル")
                    }
                } message: {
                    TextState("本当に削除しますか？")
                }
                return .none
                
            case .alert(.presented(.confirmDelete)):
                state.isProcessing = true
                
                return .withLock(
                    unlockOption: .transition(seconds: 0.25),  // アラート消去アニメーション
                    operation: { send in
                        try await api.deleteItem()
                        await send(.deleteCompleted)
                    },
                    action: DeleteAction.delete,
                    cancelID: CancelID.delete
                )
                
            case .deleteCompleted:
                state.isProcessing = false
                return .none
                
            case .alert:
                return .none
            }
        }
    }
}
```

### プログレス表示での使用

```swift
@Reducer
struct DownloadFeature {
    @ObservableState
    struct State {
        var downloadProgress: Double = 0
        var isDownloading = false
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .startDownload:
                state.isDownloading = true
                state.downloadProgress = 0
                
                return .withLock(
                    unlockOption: .delayed(seconds: 1.0),  // 完了後も少し表示
                    operation: { send in
                        await downloadService.download { progress in
                            await send(.updateProgress(progress))
                        }
                        
                        // 完了を表示
                        await send(.updateProgress(1.0))
                        try await Task.sleep(for: .seconds(0.5))
                        
                        await send(.downloadCompleted)
                    },
                    action: DownloadAction.download,
                    cancelID: CancelID.download
                )
                
            case let .updateProgress(progress):
                state.downloadProgress = progress
                return .none
                
            case .downloadCompleted:
                state.isDownloading = false
                state.downloadProgress = 0
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
                    unlockOption: .delayed(seconds: 3.0), // 3秒間表示
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

### 連続的な更新処理

```swift
@Reducer
struct CounterFeature {
    enum Action: ViewAction {
        case view(ViewAction)
        case countUpdated
        
        @LockmanSingleExecution
        enum ViewAction {
            case incrementTapped
            case decrementTapped
            
            var lockmanInfo: LockmanSingleExecutionInfo {
                .init(
                    actionId: actionName,
                    mode: .action // 各ボタンは独立
                )
            }
        }
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .view(.incrementTapped):
                return .withLock(
                    unlockOption: .immediate, // 即座に次の操作を許可
                    operation: { send in
                        state.count += 1
                        await send(.countUpdated)
                    },
                    action: ViewAction.incrementTapped,
                    cancelID: CancelID.counter
                )
            }
        }
    }
}
```

## 動的なUnlockOption

条件に応じてUnlockOptionを変更：

```swift
func unlockOptionForAction(_ action: Action) -> UnlockOption {
    switch action {
    case .quickAction:
        return .immediate
        
    case .uiUpdate:
        return .mainRunLoop
        
    case .navigation:
        return .transition(seconds: 0.3)
        
    case .heavyProcessing:
        return .delayed(seconds: 2.0)
    }
}

// 使用
return .withLock(
    unlockOption: unlockOptionForAction(action),
    operation: { send in
        // 処理
    },
    action: dynamicAction,
    cancelID: cancelID
)
```

## カスタムUnlockOption

アプリケーション固有の定数を定義：

```swift
extension UnlockOption {
    // アプリ標準のアニメーション時間
    static let standardAnimation = UnlockOption.transition(seconds: 0.3)
    
    // 画面遷移用
    static let navigation = UnlockOption.transition(seconds: 0.35)
    
    // モーダル表示用
    static let modal = UnlockOption.transition(seconds: 0.25)
    
    // ヘビーな処理用
    static let heavyProcessing = UnlockOption.delayed(seconds: 3.0)
}

// プラットフォーム別の設定
extension UnlockOption {
    static var iOSTransition: UnlockOption {
        // iOSの標準的な画面遷移時間
        .delayed(seconds: 0.35)
    }
    
    static var iOSModalPresentation: UnlockOption {
        // モーダル表示のアニメーション時間
        .delayed(seconds: 0.4)
    }
    
    static var macOSWindowTransition: UnlockOption {
        // macOSのウィンドウアニメーション
        .delayed(seconds: 0.25)
    }
}

// 使用
return .withLock(
    unlockOption: .standardAnimation,
    operation: { send in /* ... */ },
    action: action,
    cancelID: cancelID
)
```

## グローバル設定

デフォルトのUnlockOptionを設定：

```swift
// アプリ起動時に設定
Lockman.config.defaultUnlockOption = .mainRunLoop

// 特定の処理のみオーバーライド
return .withLock(
    unlockOption: .immediate,  // デフォルトを上書き
    operation: { send in /* ... */ },
    action: action,
    cancelID: cancelID
)
```

## 手動アンロック制御

```swift
// 手動でアンロックタイミングを制御
return .withLock(
    operation: { send, unlock in
        // 処理実行
        let result = try await performLongOperation()
        
        // 結果に応じてアンロックタイミングを変更
        if result.requiresAnimation {
            unlock(.transition(seconds: 0.3))
        } else {
            unlock(.immediate)
        }
        
        await send(.operationCompleted(result))
    },
    action: myAction,
    cancelID: CancelID.operation
)

// フォールバックとの組み合わせ
return .withLock(
    unlockOption: .delayed(seconds: 1.0),  // フォールバック
    operation: { send, unlock in
        do {
            let result = try await process()
            await send(.completed(result))
            
            // 成功時は即座に解放
            await unlock()
        } catch {
            // エラー時は遅延解放（クリーンアップ時間確保）
            await send(.failed(error))
        }
    },
    action: ProcessAction.execute,
    cancelID: CancelID.process
)
```

## ベストプラクティス

### 1. 用途に応じた選択

```swift
// ✅ データ処理：immediate
return .withLock(
    unlockOption: .immediate,
    operation: { send in
        let data = try await process()
        await send(.completed(data))
    },
    action: DataAction.process,
    cancelID: CancelID.userAction
)

// ✅ UI更新：mainRunLoop
return .withLock(
    unlockOption: .mainRunLoop,
    operation: { send in
        await send(.updateView(newState))
    },
    action: UIAction.update,
    cancelID: CancelID.ui
)

// ✅ 画面遷移：transition
return .withLock(
    unlockOption: .transition(seconds: 0.3),
    operation: { send in
        await send(.navigate(to: destination))
    },
    action: NavAction.push,
    cancelID: CancelID.nav
)
```

### 2. パフォーマンスへの配慮

```swift
// ❌ 不必要な遅延
return .withLock(
    unlockOption: .delayed(seconds: 5.0),  // 過度な遅延
    operation: { send in
        let result = 1 + 1  // 軽量な処理
        await send(.calculated(result))
    },
    action: CalcAction.add,
    cancelID: CancelID.calc
)

// ✅ 適切な選択
return .withLock(
    unlockOption: .immediate,
    operation: { send in
        let result = 1 + 1
        await send(.calculated(result))
    },
    action: CalcAction.add,
    cancelID: CancelID.calc
)
```

### 3. カスタム遅延の活用

```swift
// アニメーション時間に合わせる
let animationDuration: TimeInterval = 0.6
return .withLock(
    unlockOption: .delayed(seconds: animationDuration),
    operation: { send in
        withAnimation(.easeInOut(duration: animationDuration)) {
            state.isExpanded.toggle()
        }
    },
    action: toggleAction,
    cancelID: CancelID.userAction
)
```

### 4. 条件付きアンロック

```swift
struct ConditionalUnlockAction {
    let shouldDelayUnlock: Bool
    
    var unlockOption: UnlockOption {
        shouldDelayUnlock ? .transition(seconds: 0.3) : .immediate
    }
}
```

## トラブルシューティング

### よくある問題

1. **操作がブロックされる**
   - 適切なUnlockOptionが設定されているか確認
   - デバッグログでロック状態を確認

2. **アニメーションとの不整合**
   - アニメーション時間とdelayed値を一致させる
   - mainRunLoopオプションの使用を検討

3. **連続操作が効かない**
   - immediateオプションに変更
   - ExecutionModeを.actionに設定

## 次のステップ

- <doc:EffectWithLock> - Effect.withLockの詳細
- <doc:Debugging> - UnlockOptionのデバッグ方法