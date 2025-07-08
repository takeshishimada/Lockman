<img src="../Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%205.10%20%7C%206.0-ED523F.svg?style=flat)](https://swift.org/download/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Mac%20Catalyst-333333.svg?style=flat)](https://developer.apple.com/)

[English](../README.md) | [日本語](README_ja.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [Español](README_es.md) | [Français](README_fr.md) | [Deutsch](README_de.md) | [한국어](README_ko.md) | [Português](README_pt-BR.md) | [Italiano](README_it.md)

Lockman es una biblioteca Swift que resuelve problemas de control exclusivo de acciones en aplicaciones The Composable Architecture (TCA), con énfasis en la capacidad de respuesta, transparencia y diseño declarativo.

* [Filosofía de Diseño](#filosofía-de-diseño)
* [Descripción General](#descripción-general)
* [Ejemplo Básico](#ejemplo-básico)
* [Instalación](#instalación)
* [Comunidad](#comunidad)

## Filosofía de Diseño

### Principios de Designing Fluid Interfaces

La charla "Designing Fluid Interfaces" de WWDC18 presentó principios para interfaces excepcionales:

* **Respuesta Inmediata y Redirección Continua** - Capacidad de respuesta que no permite ni 10ms de retraso
* **Movimiento Uno a Uno de Toque y Contenido** - El contenido sigue al dedo durante las operaciones de arrastre
* **Retroalimentación Continua** - Reacción inmediata a todas las interacciones
* **Detección de Gestos en Paralelo** - Reconocimiento de múltiples gestos simultáneamente
* **Consistencia Espacial** - Mantenimiento de la consistencia de posición durante las animaciones
* **Interacciones Ligeras, Salida Amplificada** - Grandes efectos a partir de pequeñas entradas

### Desafíos Tradicionales

El desarrollo tradicional de UI ha resuelto problemas simplemente prohibiendo presionar botones simultáneamente y ejecuciones duplicadas. Estos enfoques se han convertido en factores que obstaculizan la experiencia del usuario en el diseño moderno de interfaces fluidas.

Los usuarios esperan alguna forma de retroalimentación incluso al presionar botones simultáneamente. Es crucial separar claramente la respuesta inmediata en la capa de UI del control de exclusión mutua apropiado en la capa de lógica de negocio.

## Descripción General

Lockman proporciona las siguientes estrategias de control para abordar problemas comunes en el desarrollo de aplicaciones:

* **Single Execution**: Previene la ejecución duplicada de la misma acción
* **Priority Based**: Control y cancelación de acciones basado en prioridad
* **Group Coordination**: Control de grupo mediante roles de líder/miembro
* **Dynamic Condition**: Control dinámico basado en condiciones de tiempo de ejecución
* **Concurrency Limited**: Limita el número de ejecuciones concurrentes por grupo
* **Composite Strategy**: Combinación de múltiples estrategias

## Ejemplos

| Single Execution Strategy | Priority Based Strategy | Concurrency Limited Strategy |
|--------------------------|------------------------|------------------------------|
| ![Single Execution Strategy](../Sources/Lockman/Documentation.docc/images/01-SingleExecutionStrategy.gif) | ![Priority Based Strategy](../Sources/Lockman/Documentation.docc/images/02-PriorityBasedStrategy.gif) | ![Concurrency Limited Strategy](../Sources/Lockman/Documentation.docc/images/03-ConcurrencyLimitedStrategy.gif) |

## Ejemplo de Código

Aquí se muestra cómo implementar una función que previene la ejecución duplicada de procesos usando el macro `@LockmanSingleExecution`:

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
                        // Simular procesamiento pesado
                        try await Task.sleep(nanoseconds: 3_000_000_000)
                        await send(.internal(.processCompleted))
                    }
                }
                
            case let .internal(internalAction):
                switch internalAction {
                case .processStart:
                    state.isProcessing = true
                    state.message = "Procesamiento iniciado..."
                    return .none
                    
                case .processCompleted:
                    state.isProcessing = false
                    state.message = "Procesamiento completado"
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
                // Cuando el procesamiento ya está en progreso
                if error is LockmanSingleExecutionError {
                    // Actualizar mensaje a través de una acción en lugar de mutación directa del estado
                    await send(.internal(.updateMessage("El procesamiento ya está en progreso")))
                }
            },
            for: \.view
        )
    }
}
```

El modificador `Reducer.lock` aplica automáticamente la gestión de bloqueos a las acciones que se conforman a `LockmanAction`. Dado que la enumeración `ViewAction` está marcada con `@LockmanSingleExecution`, la acción `startProcessButtonTapped` no se ejecutará mientras el procesamiento esté en progreso. El parámetro `for: \.view` le dice a Lockman que verifique las acciones anidadas en el caso `view` para la conformidad con `LockmanAction`.

### Ejemplo de Salida de Depuración

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

## Documentación

La documentación para las versiones publicadas y `main` está disponible aquí:

* [`main`](https://takeshishimada.github.io/Lockman/main/documentation/lockman/)
* [1.0.0](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/) ([guía de migración](https://takeshishimada.github.io/Lockman/1.0.0/documentation/lockman/migrationguides/migratingto1.0))

<details>
<summary>Otras versiones</summary>

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

Hay varios artículos en la documentación que pueden resultarte útiles a medida que te familiarizas con la biblioteca:

### Esenciales
* [Primeros Pasos](https://takeshishimada.github.io/Lockman/main/documentation/lockman/gettingstarted) - Aprende cómo integrar Lockman en tu aplicación TCA
* [Descripción General de Límites](https://takeshishimada.github.io/Lockman/main/documentation/lockman/boundaryoverview) - Comprende el concepto de límites en Lockman
* [Bloqueo](https://takeshishimada.github.io/Lockman/main/documentation/lockman/lock) - Comprensión del mecanismo de bloqueo
* [Desbloqueo](https://takeshishimada.github.io/Lockman/main/documentation/lockman/unlock) - Comprensión del mecanismo de desbloqueo
* [Elegir una Estrategia](https://takeshishimada.github.io/Lockman/main/documentation/lockman/choosingstrategy) - Selecciona la estrategia correcta para tu caso de uso
* [Configuración](https://takeshishimada.github.io/Lockman/main/documentation/lockman/configuration) - Configura Lockman para las necesidades de tu aplicación
* [Manejo de Errores](https://takeshishimada.github.io/Lockman/main/documentation/lockman/errorhandling) - Aprende sobre patrones comunes de manejo de errores
* [Guía de Depuración](https://takeshishimada.github.io/Lockman/main/documentation/lockman/debuggingguide) - Depura problemas relacionados con Lockman en tu aplicación

### Estrategias
* [Single Execution Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/singleexecutionstrategy) - Prevenir ejecución duplicada
* [Priority Based Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/prioritybasedstrategy) - Control basado en prioridad
* [Concurrency Limited Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/concurrencylimitedstrategy) - Limitar ejecuciones concurrentes
* [Group Coordination Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/groupcoordinationstrategy) - Coordinar acciones relacionadas
* [Dynamic Condition Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/dynamicconditionstrategy) - Control dinámico en tiempo de ejecución
* [Composite Strategy](https://takeshishimada.github.io/Lockman/main/documentation/lockman/compositestrategy) - Combinar múltiples estrategias

Nota: La documentación está disponible solo en inglés.

## Instalación

Lockman se puede instalar usando [Swift Package Manager](https://swift.org/package-manager/).

### Xcode

En Xcode, selecciona File → Add Package Dependencies e ingresa la siguiente URL:

```
https://github.com/takeshishimada/Lockman
```

### Package.swift

Agrega la dependencia a tu archivo Package.swift:

```swift
dependencies: [
  .package(url: "https://github.com/takeshishimada/Lockman", from: "1.0.0")
]
```

Agrega la dependencia a tu objetivo:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "Lockman", package: "Lockman"),
  ]
)
```

### Requisitos

| Plataforma | Versión Mínima |
|------------|----------------|
| iOS        | 13.0           |
| macOS      | 10.15          |
| tvOS       | 13.0           |
| watchOS    | 6.0            |

### Compatibilidad de Versiones

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
<summary>Otras versiones</summary>

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

## Comunidad

### Discusión y Ayuda

Las preguntas y discusiones se pueden realizar en [GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions).

### Reporte de Errores

Si encuentras un error, por favor repórtalo en [Issues](https://github.com/takeshishimada/Lockman/issues).

### Contribuir

¡Si deseas contribuir a la biblioteca, abre un PR con un enlace a él!

## Licencia

Esta biblioteca se publica bajo la licencia MIT. Consulta el archivo [LICENSE](./LICENSE) para más detalles.