<img src="../Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%205.10%20%7C%206.0-ED523F.svg?style=flat)](https://swift.org/download/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Mac%20Catalyst-333333.svg?style=flat)](https://developer.apple.com/)


Lockman è una libreria Swift che risolve i problemi di controllo esclusivo delle azioni nelle applicazioni The Composable Architecture (TCA), con reattività, trasparenza e design dichiarativo in mente.

* [Filosofia di Design](#filosofia-di-design)
* [Panoramica](#panoramica)
* [Esempio Base](#esempio-base)
* [Installazione](#installazione)
* [Comunità](#comunità)

## Filosofia di Design

### Principi di Designing Fluid Interfaces

"Designing Fluid Interfaces" della WWDC18 ha presentato principi per interfacce eccezionali:

* **Risposta Immediata e Reindirizzamento Continuo** - Reattività che non permette nemmeno 10ms di ritardo
* **Movimento di Tocco e Contenuto Uno-a-Uno** - Il contenuto segue il dito durante le operazioni di trascinamento
* **Feedback Continuo** - Reazione immediata a tutte le interazioni
* **Rilevamento di Gesti Paralleli** - Riconoscimento di più gesti simultaneamente
* **Coerenza Spaziale** - Mantenimento della coerenza di posizione durante le animazioni
* **Interazioni Leggere, Output Amplificato** - Grandi effetti da piccoli input

### Sfide Tradizionali

Lo sviluppo tradizionale dell'UI ha risolto i problemi semplicemente proibendo pressioni simultanee di pulsanti ed esecuzioni duplicate. Questi approcci sono diventati fattori che ostacolano l'esperienza utente nel moderno design di interfacce fluide.

Gli utenti si aspettano qualche forma di feedback anche quando premono i pulsanti simultaneamente. È cruciale separare chiaramente la risposta immediata al livello UI dal controllo appropriato di esclusione reciproca al livello della logica di business.

## Panoramica

Lockman fornisce le seguenti strategie di controllo per affrontare problemi comuni nello sviluppo di app:

* **Esecuzione Singola**: Previene l'esecuzione duplicata della stessa azione
* **Basata su Priorità**: Controllo e cancellazione delle azioni basata su priorità
* **Coordinamento di Gruppo**: Controllo di gruppo attraverso ruoli leader/membro
* **Condizione Dinamica**: Controllo dinamico basato su condizioni runtime
* **Concorrenza Limitata**: Limita il numero di esecuzioni concorrenti per gruppo
* **Strategia Composita**: Combinazione di più strategie

## Esempi

| Strategia di Esecuzione Singola | Strategia Basata su Priorità | Strategia di Concorrenza Limitata |
|----------------------------------|------------------------------|-----------------------------------|
| ![Strategia di Esecuzione Singola](../Sources/Lockman/Documentation.docc/images/01-SingleExecutionStrategy.gif) | ![Strategia Basata su Priorità](../Sources/Lockman/Documentation.docc/images/02-PriorityBasedStrategy.gif) | ![Strategia di Concorrenza Limitata](../Sources/Lockman/Documentation.docc/images/03-ConcurrencyLimitedStrategy.gif) |

## Esempio di Codice

Ecco come implementare una funzionalità che previene l'esecuzione duplicata di processi usando il macro `@LockmanSingleExecution`:

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
                        // Simula elaborazione pesante
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        await send(.internal(.processCompleted))
                    }
                }
                
            case let .internal(internalAction):
                switch internalAction {
                case .processStart:
                    state.isProcessing = true
                    state.message = "Elaborazione avviata..."
                    return .none
                    
                case .processCompleted:
                    state.isProcessing = false
                    state.message = "Elaborazione completata"
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
                // Quando l'elaborazione è già in corso
                if error is LockmanSingleExecutionError {
                    // Aggiorna il messaggio tramite un'azione invece di mutazione diretta dello stato
                    await send(.internal(.updateMessage("L'elaborazione è già in corso")))
                }
            },
            for: \.view
        )
    }
}
```

Il modificatore `Reducer.lock` applica automaticamente la gestione dei lock alle azioni che si conformano a `LockmanAction`. Poiché l'enumerazione `ViewAction` è contrassegnata con `@LockmanSingleExecution`, l'azione `startProcessButtonTapped` non verrà eseguita mentre l'elaborazione è in corso. Il parametro `for: \.view` indica a Lockman di controllare la conformità a `LockmanAction` per le azioni annidate nel caso `view`.

### Esempio di Output di Debug

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

## Documentazione

La documentazione per le release e `main` è disponibile qui:

* [`main`](https://takeshishimada.github.io/Lockman/main/documentation/lockman/)
* [1.3.0](https://takeshishimada.github.io/Lockman/1.3.0/documentation/lockman/) ([guida alla migrazione](https://takeshishimada.github.io/Lockman/1.3.0/documentation/lockman/migratingto1.3))
* [1.2.0](https://takeshishimada.github.io/Lockman/1.2.0/documentation/lockman/) ([guida alla migrazione](https://takeshishimada.github.io/Lockman/1.2.0/documentation/lockman/migratingto1.2))
* [1.1.0](https://takeshishimada.github.io/Lockman/1.1.0/documentation/lockman/) ([guida alla migrazione](https://takeshishimada.github.io/Lockman/1.1.0/documentation/lockman/migratingto1.1))

<details>
<summary>Altre versioni</summary>

* [1.0.0](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/) ([guida alla migrazione](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/migratingto1.0))
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

Ci sono numerosi articoli nella documentazione che potresti trovare utili mentre prendi confidenza con la libreria:

### Essenziali
* [Iniziare](https://takeshishimada.github.io/Lockman/main/documentation/lockman/gettingstarted) - Impara come integrare Lockman nella tua applicazione TCA
* [Panoramica dei Confini](https://takeshishimada.github.io/Lockman/main/documentation/lockman/boundaryoverview) - Comprendi il concetto di confini in Lockman
* [Lock](https://takeshishimada.github.io/Lockman/main/documentation/lockman/lock) - Comprendere il meccanismo di blocco
* [Unlock](https://takeshishimada.github.io/Lockman/main/documentation/lockman/unlock) - Comprendere il meccanismo di sblocco
* [Scegliere una Strategia](https://takeshishimada.github.io/Lockman/main/documentation/lockman/choosingstrategy) - Seleziona la strategia giusta per il tuo caso d'uso
* [Configurazione](https://takeshishimada.github.io/Lockman/main/documentation/lockman/configuration) - Configura Lockman per le esigenze della tua applicazione
* [Gestione degli Errori](https://takeshishimada.github.io/Lockman/main/documentation/lockman/errorhandling) - Impara i pattern comuni di gestione degli errori
* [Guida al Debug](https://takeshishimada.github.io/Lockman/main/documentation/lockman/debuggingguide) - Esegui il debug dei problemi relativi a Lockman nella tua applicazione

### Strategie
* [Strategia di Esecuzione Singola](https://takeshishimada.github.io/Lockman/main/documentation/lockman/singleexecutionstrategy) - Previene l'esecuzione duplicata
* [Strategia Basata su Priorità](https://takeshishimada.github.io/Lockman/main/documentation/lockman/prioritybasedstrategy) - Controllo basato su priorità
* [Strategia di Concorrenza Limitata](https://takeshishimada.github.io/Lockman/main/documentation/lockman/concurrencylimitedstrategy) - Limita le esecuzioni concorrenti
* [Strategia di Coordinamento di Gruppo](https://takeshishimada.github.io/Lockman/main/documentation/lockman/groupcoordinationstrategy) - Coordina le azioni correlate
* [Strategia di Condizione Dinamica](https://takeshishimada.github.io/Lockman/main/documentation/lockman/dynamicconditionstrategy) - Controllo dinamico runtime
* [Strategia Composita](https://takeshishimada.github.io/Lockman/main/documentation/lockman/compositestrategy) - Combina più strategie

Nota: La documentazione è disponibile solo in inglese.

## Installazione

Lockman può essere installato usando [Swift Package Manager](https://swift.org/package-manager/).

### Xcode

In Xcode, seleziona File → Add Package Dependencies e inserisci il seguente URL:

```
https://github.com/takeshishimada/Lockman
```

### Package.swift

Aggiungi la dipendenza al tuo file Package.swift:

```swift
dependencies: [
  .package(url: "https://github.com/takeshishimada/Lockman", from: "1.3.1")
]
```

Aggiungi la dipendenza al tuo target:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "Lockman", package: "Lockman"),
  ]
)
```

### Requisiti

| Piattaforma | Versione Minima |
|-------------|-----------------|
| iOS         | 13.0            |
| macOS       | 10.15           |
| tvOS        | 13.0            |
| watchOS     | 6.0             |

### Compatibilità delle Versioni

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 1.3.1   | 1.20.2                     |

<details>
<summary>Altre versioni</summary>

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 1.3.0   | 1.20.2                     |
| 1.2.0   | 1.20.2                     |
| 1.1.0   | 1.20.2                     |
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
| 0.7.0   | 1.17.1                     |
| 0.6.0   | 1.17.1                     |
| 0.5.0   | 1.17.1                     |
| 0.4.0   | 1.17.1                     |
| 0.3.0   | 1.17.1                     |
| 0.2.1   | 1.17.1                     |
| 0.2.0   | 1.17.1                     |
| 0.1.0   | 1.17.1                     |

</details>

## Translations

This documentation is also available in other languages:

- [English](../README.md)
- [日本語 (Japanese)](README_ja.md)
- [简体中文 (Simplified Chinese)](README_zh-CN.md)
- [繁體中文 (Traditional Chinese)](README_zh-TW.md)
- [Español (Spanish)](README_es.md)
- [Français (French)](README_fr.md)
- [Deutsch (German)](README_de.md)
- [한국어 (Korean)](README_ko.md)
- [Português (Portuguese)](README_pt-BR.md)
- [Italiano (Italian)](README_it.md)

## Comunità

### Discussione e Aiuto

Domande e discussioni possono essere tenute su [GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions).

### Segnalazioni di Bug

Se trovi un bug, per favore segnalalo su [Issues](https://github.com/takeshishimada/Lockman/issues).

### Contribuire

Se desideri contribuire alla libreria, per favore apri una PR con un link ad essa!

## Licenza

Questa libreria è rilasciata sotto licenza MIT. Vedi il file [LICENSE](./LICENSE) per i dettagli.