<img src="Lockman.png" alt="Lockman Logo" width="400">

[![CI](https://github.com/takeshishimada/Lockman/workflows/CI/badge.svg)](https://github.com/takeshishimada/Lockman/actions?query=workflow%3ACI)
[![Swift](https://img.shields.io/badge/Swift-5.9%20%7C%205.10%20%7C%206.0-ED523F.svg?style=flat)](https://swift.org/download/)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Mac%20Catalyst-333333.svg?style=flat)](https://developer.apple.com/)

[English](README.md) | [日本語](README_ja.md) | [简体中文](README_zh-CN.md) | [繁體中文](README_zh-TW.md) | [Español](README_es.md) | [Français](README_fr.md) | [Deutsch](README_de.md) | [한국어](README_ko.md) | [Português](README_pt-BR.md) | [Italiano](README_it.md)

Lockman é uma biblioteca Swift que resolve problemas de controle de ações concorrentes em aplicações The Composable Architecture (TCA), com responsividade, transparência e design declarativo em mente.

* [Filosofia de Design](#filosofia-de-design)
* [Visão Geral](#visão-geral)
* [Exemplo Básico](#exemplo-básico)
* [Instalação](#instalação)
* [Comunidade](#comunidade)

## Filosofia de Design

### Princípios de Designing Fluid Interfaces

O "Designing Fluid Interfaces" da WWDC18 apresentou princípios para interfaces excepcionais:

* **Resposta Imediata e Redirecionamento Contínuo** - Responsividade que não permite nem 10ms de atraso
* **Movimento de Toque e Conteúdo Um-para-Um** - O conteúdo segue o dedo durante operações de arraste
* **Feedback Contínuo** - Reação imediata a todas as interações
* **Detecção de Gestos Paralelos** - Reconhecendo múltiplos gestos simultaneamente
* **Consistência Espacial** - Mantendo consistência de posição durante animações
* **Interações Leves, Saída Amplificada** - Grandes efeitos a partir de pequenas entradas

### Desafios Tradicionais

O desenvolvimento tradicional de UI resolveu problemas simplesmente proibindo pressionamentos simultâneos de botões e execuções duplicadas. Essas abordagens se tornaram fatores que prejudicam a experiência do usuário no design moderno de interfaces fluidas.

Os usuários esperam algum tipo de feedback mesmo ao pressionar botões simultaneamente. É crucial separar claramente a resposta imediata na camada de UI do controle apropriado de exclusão mútua na camada de lógica de negócios.

## Visão Geral

Lockman fornece as seguintes estratégias de controle para abordar problemas comuns no desenvolvimento de aplicativos:

* **Execução Única**: Previne execução duplicada da mesma ação
* **Baseado em Prioridade**: Controle e cancelamento de ação baseado em prioridade
* **Coordenação de Grupo**: Controle de grupo através de papéis líder/membro
* **Condição Dinâmica**: Controle dinâmico baseado em condições de tempo de execução
* **Concorrência Limitada**: Limita o número de execuções concorrentes por grupo
* **Estratégia Composta**: Combinação de múltiplas estratégias

## Exemplos

| Estratégia de Execução Única | Estratégia Baseada em Prioridade | Estratégia de Concorrência Limitada |
|------------------------------|----------------------------------|-------------------------------------|
| ![Estratégia de Execução Única](Sources/Lockman/Documentation.docc/images/01-SingleExecutionStrategy.gif) | ![Estratégia Baseada em Prioridade](Sources/Lockman/Documentation.docc/images/02-PriorityBasedStrategy.gif) | ![Estratégia de Concorrência Limitada](Sources/Lockman/Documentation.docc/images/03-ConcurrencyLimitedStrategy.gif) |

## Exemplo de Código

Veja como implementar um recurso que previne execução duplicada de processos usando o macro `@LockmanSingleExecution`:

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

O método `withLock` garante que `startProcessButtonTapped` não será executado enquanto o processamento estiver em andamento, prevenindo operações duplicadas mesmo se o usuário tocar o botão várias vezes.

### Exemplo de Saída de Debug

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

## Documentação

A documentação para lançamentos e `main` estão disponíveis aqui:

* [`main`](https://takeshishimada.github.io/Lockman/main/documentation/lockman/)
* [0.11.0](https://takeshishimada.github.io/Lockman/0.11.0/documentation/lockman/)
* [0.10.0](https://takeshishimada.github.io/Lockman/0.10.0/documentation/lockman/)
* [0.9.0](https://takeshishimada.github.io/Lockman/0.9.0/documentation/lockman/)
* [0.8.0](https://takeshishimada.github.io/Lockman/0.8.0/documentation/lockman/)

<details>
<summary>Outras versões</summary>

* [0.7.0](https://takeshishimada.github.io/Lockman/0.7.0/documentation/lockman/)
* [0.6.0](https://takeshishimada.github.io/Lockman/0.6.0/documentation/lockman/)
* [0.5.0](https://takeshishimada.github.io/Lockman/0.5.0/documentation/lockman/)
* [0.4.0](https://takeshishimada.github.io/Lockman/0.4.0/documentation/lockman/)
* [0.3.0](https://takeshishimada.github.io/Lockman/0.3.0/documentation/lockman/)

</details>

Existem vários artigos na documentação que você pode achar úteis à medida que se familiariza com a biblioteca:

### Essenciais
* [Começando](https://takeshishimada.github.io/Lockman/main/documentation/lockman/gettingstarted) - Aprenda como integrar Lockman em sua aplicação TCA
* [Visão Geral de Limites](https://takeshishimada.github.io/Lockman/main/documentation/lockman/boundaryoverview) - Entenda o conceito de limites em Lockman
* [Bloquear](https://takeshishimada.github.io/Lockman/main/documentation/lockman/lock) - Entendendo o mecanismo de bloqueio
* [Desbloquear](https://takeshishimada.github.io/Lockman/main/documentation/lockman/unlock) - Entendendo o mecanismo de desbloqueio
* [Escolhendo uma Estratégia](https://takeshishimada.github.io/Lockman/main/documentation/lockman/choosingstrategy) - Selecione a estratégia certa para seu caso de uso
* [Configuração](https://takeshishimada.github.io/Lockman/main/documentation/lockman/configuration) - Configure Lockman para as necessidades de sua aplicação
* [Tratamento de Erros](https://takeshishimada.github.io/Lockman/main/documentation/lockman/errorhandling) - Aprenda sobre padrões comuns de tratamento de erros
* [Guia de Depuração](https://takeshishimada.github.io/Lockman/main/documentation/lockman/debuggingguide) - Depure problemas relacionados ao Lockman em sua aplicação

### Estratégias
* [Estratégia de Execução Única](https://takeshishimada.github.io/Lockman/main/documentation/lockman/singleexecutionstrategy) - Previne execução duplicada
* [Estratégia Baseada em Prioridade](https://takeshishimada.github.io/Lockman/main/documentation/lockman/prioritybasedstrategy) - Controle baseado em prioridade
* [Estratégia de Concorrência Limitada](https://takeshishimada.github.io/Lockman/main/documentation/lockman/concurrencylimitedstrategy) - Limita execuções concorrentes
* [Estratégia de Coordenação de Grupo](https://takeshishimada.github.io/Lockman/main/documentation/lockman/groupcoordinationstrategy) - Coordena ações relacionadas
* [Estratégia de Condição Dinâmica](https://takeshishimada.github.io/Lockman/main/documentation/lockman/dynamicconditionstrategy) - Controle dinâmico em tempo de execução
* [Estratégia Composta](https://takeshishimada.github.io/Lockman/main/documentation/lockman/compositestrategy) - Combina múltiplas estratégias

Nota: A documentação está disponível apenas em inglês.

## Instalação

Lockman pode ser instalado usando [Swift Package Manager](https://swift.org/package-manager/).

### Xcode

No Xcode, selecione File → Add Package Dependencies e insira a seguinte URL:

```
https://github.com/takeshishimada/Lockman
```

### Package.swift

Adicione a dependência ao seu arquivo Package.swift:

```swift
dependencies: [
  .package(url: "https://github.com/takeshishimada/Lockman", from: "0.11.0")
]
```

Adicione a dependência ao seu alvo:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "Lockman", package: "Lockman"),
  ]
)
```

### Requisitos

| Plataforma | Versão Mínima |
|------------|---------------|
| iOS        | 13.0          |
| macOS      | 10.15         |
| tvOS       | 13.0          |
| watchOS    | 6.0           |

### Compatibilidade de Versão

| Lockman | The Composable Architecture |
|---------|----------------------------|
| 0.11.0  | 1.19.1                     |
| 0.10.0  | 1.19.0                     |
| 0.9.0   | 1.18.0                     |

<details>
<summary>Outras versões</summary>

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

## Comunidade

### Discussão e Ajuda

Perguntas e discussões podem ser realizadas no [GitHub Discussions](https://github.com/takeshishimada/Lockman/discussions).

### Relatórios de Bugs

Se você encontrar um bug, por favor reporte em [Issues](https://github.com/takeshishimada/Lockman/issues).

### Contribuindo

Se você gostaria de contribuir para a biblioteca, por favor abra um PR com um link para ele!

## Licença

Esta biblioteca é lançada sob a Licença MIT. Veja o arquivo [LICENSE](./LICENSE) para detalhes.