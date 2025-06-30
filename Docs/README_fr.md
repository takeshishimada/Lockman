<img src="../Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%205.10%20%7C%206.0-ED523F.svg?style=flat)](https://swift.org/download/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Mac%20Catalyst-333333.svg?style=flat)](https://developer.apple.com/)

[English](../README.md) | [日本語](README_ja.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [Español](README_es.md) | [Français](README_fr.md) | [Deutsch](README_de.md) | [한국어](README_ko.md) | [Português](README_pt-BR.md) | [Italiano](README_it.md)

Lockman est une bibliothèque Swift qui résout les problèmes de contrôle des actions concurrentes dans les applications The Composable Architecture (TCA), en mettant l'accent sur la réactivité, la transparence et la conception déclarative.

* [Philosophie de Conception](#philosophie-de-conception)
* [Vue d'Ensemble](#vue-densemble)
* [Exemple de Base](#exemple-de-base)
* [Installation](#installation)
* [Communauté](#communauté)

## Philosophie de Conception

### Principes de Designing Fluid Interfaces

La présentation "Designing Fluid Interfaces" de WWDC18 a présenté des principes pour des interfaces exceptionnelles :

* **Réponse Immédiate et Redirection Continue** - Une réactivité qui ne tolère pas même 10ms de délai
* **Mouvement Un-à-Un entre le Toucher et le Contenu** - Le contenu suit le doigt pendant les opérations de glissement
* **Retour d'Information Continu** - Réaction immédiate à toutes les interactions
* **Détection de Gestes en Parallèle** - Reconnaissance de plusieurs gestes simultanément
* **Cohérence Spatiale** - Maintien de la cohérence de position pendant les animations
* **Interactions Légères, Sortie Amplifiée** - Grands effets à partir de petites entrées

### Défis Traditionnels

Le développement d'interface utilisateur traditionnel a résolu les problèmes en interdisant simplement les pressions simultanées de boutons et les exécutions en double. Ces approches sont devenues des facteurs qui entravent l'expérience utilisateur dans la conception moderne d'interfaces fluides.

Les utilisateurs attendent une forme de retour d'information même lorsqu'ils appuient simultanément sur des boutons. Il est crucial de séparer clairement la réponse immédiate au niveau de la couche UI du contrôle d'exclusion mutuelle approprié au niveau de la couche de logique métier.

## Vue d'Ensemble

Lockman fournit les stratégies de contrôle suivantes pour résoudre les problèmes courants dans le développement d'applications :

* **Single Execution** : Empêche l'exécution en double de la même action
* **Priority Based** : Contrôle et annulation d'actions basés sur la priorité
* **Group Coordination** : Contrôle de groupe via les rôles leader/membre
* **Dynamic Condition** : Contrôle dynamique basé sur les conditions d'exécution
* **Concurrency Limited** : Limite le nombre d'exécutions concurrentes par groupe
* **Composite Strategy** : Combinaison de plusieurs stratégies

## Exemples

| Single Execution Strategy | Priority Based Strategy | Concurrency Limited Strategy |
|--------------------------|------------------------|------------------------------|
| ![Single Execution Strategy](../Sources/Lockman/Documentation.docc/images/01-SingleExecutionStrategy.gif) | ![Priority Based Strategy](../Sources/Lockman/Documentation.docc/images/02-PriorityBasedStrategy.gif) | ![Concurrency Limited Strategy](../Sources/Lockman/Documentation.docc/images/03-ConcurrencyLimitedStrategy.gif) |

## Exemple de Code

Voici comment implémenter une fonctionnalité qui empêche l'exécution en double de processus en utilisant la macro `@LockmanSingleExecution` :

```swift
import ComposableArchitecture
import Lockman

@Reducer
struct ProcessFeature {
    @ObservableState
    struct State: Equatable {
        var isProcessing = false
        var message = ""
    }
    
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
                    return .withLock(
                        operation: { send in
                            await send(.internal(.processStart))
                            // Simulate heavy processing
                            try await Task.sleep(nanoseconds: 3_000_000_000)
                            await send(.internal(.processCompleted))
                        },
                        lockFailure: { error, send in
                            // When processing is already in progress
                            state.message = "Processing is already in progress"
                        },
                        action: viewAction,
                        cancelID: CancelID.userAction
                    )
                }
                
            case let .internal(internalAction):
                switch internalAction {
                case .processStart:
                    state.isProcessing = true
                    state.message = "Processing started..."
                    return .none
                    
                case .processCompleted:
                    state.isProcessing = false
                    state.message = "Processing completed"
                    return .none
                }
            }
        }
    }
}
```

La méthode `withLock` garantit que `startProcessButtonTapped` ne s'exécutera pas pendant que le traitement est en cours, empêchant les opérations en double même si l'utilisateur appuie plusieurs fois sur le bouton.

### Exemple de Sortie de Débogage

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

## Documentation

La documentation pour les versions publiées et `main` est disponible ici :

* [`main`](https://takeshishimada.github.io/Lockman/main/documentation/lockman/)
* [0.12.0](https://takeshishimada.github.io/Lockman/0.12.0/documentation/lockman/)
* [0.10.0](https://takeshishimada.github.io/Lockman/0.10.0/documentation/lockman/)
* [0.9.0](https://takeshishimada.github.io/Lockman/0.9.0/documentation/lockman/)
* [0.8.0](https://takeshishimada.github.io/Lockman/0.8.0/documentation/lockman/)

<details>
<summary>Autres versions</summary>

* [0.7.0](https://takeshishimada.github.io/Lockman/0.7.0/documentation/lockman/)
* [0.6.0](https://takeshishimada.github.io/Lockman/0.6.0/documentation/lockman/)
* [0.5.0](https://takeshishimada.github.io/Lockman/0.5.0/documentation/lockman/)
* [0.4.0](https://takeshishimada.github.io/Lockman/0.4.0/documentation/lockman/)
* [0.3.0](https://takeshishimada.github.io/Lockman/0.3.0/documentation/lockman/)

</details>

Il existe plusieurs articles dans la documentation qui peuvent vous être utiles pour vous familiariser avec la bibliothèque :

### Essentiels
* [Démarrage](https://takeshishimada.github.io/Lockman/main/documentation/lockman/gettingstarted) - Apprenez à intégrer Lockman dans votre application TCA
* [Vue d'Ensemble des Limites](https://takeshishimada.github.io/Lockman/main/documentation/lockman/boundaryoverview) - Comprendre le concept de limites dans Lockman
* [Verrouillage](https://takeshishimada.github.io/Lockman/main/documentation/lockman/lock) - Comprendre le mécanisme de verrouillage
* [Déverrouillage](https://takeshishimada.github.io/Lockman/main/documentation/lockman/unlock) - Comprendre le mécanisme de déverrouillage
* [Choisir une Stratégie](https://takeshishimada.github.io/Lockman/main/documentation/lockman/choosingstrategy) - Sélectionnez la bonne stratégie pour votre cas d'utilisation
* [Configuration](https://takeshishimada.github.io/Lockman/main/documentation/lockman/configuration) - Configurez Lockman pour les besoins de votre application
* [Gestion des Erreurs](https://takeshishimada.github.io/Lockman/main/documentation/lockman/errorhandling) - Apprenez les modèles courants de gestion des erreurs
* [Guide de Débogage](https://takeshishimada.github.io/Lockman/main/documentation/lockman/debuggingguide) - Déboguez les problèmes liés à Lockman dans votre application

### Stratégies
* [Single Execution Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/singleexecutionstrategy) - Empêcher l'exécution en double
* [Priority Based Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/prioritybasedstrategy) - Contrôle basé sur la priorité
* [Concurrency Limited Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/concurrencylimitedstrategy) - Limiter les exécutions concurrentes
* [Group Coordination Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/groupcoordinationstrategy) - Coordonner les actions liées
* [Dynamic Condition Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/dynamicconditionstrategy) - Contrôle dynamique à l'exécution
* [Composite Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/compositestrategy) - Combiner plusieurs stratégies

Note : La documentation est disponible uniquement en anglais.

## Installation

Lockman peut être installé en utilisant [Swift Package Manager](https://swift.org/package-manager/).

### Xcode

Dans Xcode, sélectionnez File → Add Package Dependencies et entrez l'URL suivante :

```
https://github.com/takeshishimada/Lockman
```

### Package.swift

Ajoutez la dépendance à votre fichier Package.swift :

```swift
dependencies: [
  .package(url: "https://github.com/takeshishimada/Lockman", from: "0.12.0")
]
```

Ajoutez la dépendance à votre cible :

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "Lockman", package: "Lockman"),
  ]
)
```

### Configuration Requise

| Plateforme | Version Minimale |
|------------|------------------|
| iOS        | 13.0             |
| macOS      | 10.15            |
| tvOS       | 13.0             |
| watchOS    | 6.0              |

### Compatibilité des Versions

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 0.12.0  | 1.19.1                     |
| 0.10.0  | 1.19.0                     |
| 0.9.0   | 1.18.0                     |

<details>
<summary>Autres versions</summary>

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 0.8.0   | 1.17.1                     |
| 0.7.0   | 1.17.1                     |
| 0.6.0   | 1.17.1                     |
| 0.5.0   | 1.17.1                     |
| 0.4.0   | 1.17.1                     |
| 0.3.0   | 1.17.1                     |
| 0.2.1   | 1.17.1                     |
| 0.2.0   | 1.17.1                     |
| 0.1.0   | 1.17.1                     |

</details>

## Communauté

### Discussion et Aide

Les questions et discussions peuvent être tenues sur [GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions).

### Rapports de Bogues

Si vous trouvez un bogue, veuillez le signaler sur [Issues](https://github.com/takeshishimada/Lockman/issues).

### Contribution

Si vous souhaitez contribuer à la bibliothèque, veuillez ouvrir une PR avec un lien vers celle-ci !

## Licence

Cette bibliothèque est publiée sous la licence MIT. Consultez le fichier [LICENSE](./LICENSE) pour plus de détails.