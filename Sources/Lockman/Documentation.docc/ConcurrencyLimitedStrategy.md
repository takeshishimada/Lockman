# ConcurrencyLimitedStrategy

Limit the number of concurrent executions.

## Overview

ConcurrencyLimitedStrategy is a strategy that limits the number of concurrent executions. It allows concurrent execution up to a specified number and rejects execution when the limit is exceeded, enabling resource usage control and performance optimization.

This strategy is used for controlling the concurrency of resource-intensive operations such as network requests and file processing.

## Concurrency Limitation System

### Limit Types

**unlimited** - No limit

```swift
LockmanConcurrencyLimitedInfo(
    actionId: "backgroundTask",
    concurrencyId: "background",
    limit: .unlimited
)
```

- No limit on the number of concurrent executions
- Used when you want to temporarily disable limits
- Applied for behavior verification during debugging and testing

**limited** - Numeric limit

```swift
LockmanConcurrencyLimitedInfo(
    actionId: "download",
    concurrencyId: "downloads", 
    limit: .limited(3)
)
```

- Allows concurrent execution up to the specified number
- Operations exceeding the limit are rejected
- Resource protection and performance optimization

### Concurrency Groups

Operations with the same `concurrencyId` are managed as a single group, and the number of concurrent executions is limited on a per-group basis.

```swift
// Managed as the same group "downloads"
LockmanConcurrencyLimitedInfo(
    actionId: "downloadImage",
    concurrencyId: "downloads",
    limit: .limited(3)
)

LockmanConcurrencyLimitedInfo(
    actionId: "downloadVideo", 
    concurrencyId: "downloads",
    limit: .limited(3)
)
```

## Usage

### Basic Usage Example

```swift
@LockmanConcurrencyLimited
enum ViewAction {
    case downloadFile(URL)
    case uploadFile(URL)
    case processImage(UIImage)
    
    var lockmanInfo: LockmanConcurrencyLimitedInfo {
        switch self {
        case .downloadFile:
            return LockmanConcurrencyLimitedInfo(
                actionId: actionName,
                concurrencyId: "network",
                limit: .limited(3)
            )
        case .uploadFile:
            return LockmanConcurrencyLimitedInfo(
                actionId: actionName,
                concurrencyId: "network", 
                limit: .limited(3)
            )
        case .processImage:
            return LockmanConcurrencyLimitedInfo(
                actionId: actionName,
                concurrencyId: "imageProcessing",
                limit: .limited(2)
            )
        }
    }
}
```

### Group-specific Limit Configuration

```swift
// Network-related: Maximum 3
LockmanConcurrencyLimitedInfo(
    actionId: "apiCall",
    concurrencyId: "network",
    limit: .limited(3)
)

// Image processing: Maximum 2  
LockmanConcurrencyLimitedInfo(
    actionId: "imageResize",
    concurrencyId: "imageProcessing", 
    limit: .limited(2)
)

// Background tasks: No limit
LockmanConcurrencyLimitedInfo(
    actionId: "logging",
    concurrencyId: "background",
    limit: .unlimited
)
```

## Behavior Examples

### Execution Control by Limits

```
Limit: 3
Concurrency Group: "downloads"

Time: 0s  - download1 request → ✅ Execute (1/3)
Time: 1s  - download2 request → ✅ Execute (2/3)  
Time: 2s  - download3 request → ✅ Execute (3/3)
Time: 3s  - download4 request → ❌ Reject (limit reached)
Time: 4s  - download1 complete → ✅ Complete (2/3)
Time: 5s  - download5 request → ✅ Execute (3/3)
```

### Independent Control in Different Groups

```
Network Group (Limit: 3)
Time: 0s  - api1 execute, api2 execute, api3 execute → ✅ (3/3)
Time: 1s  - api4 request → ❌ Reject

Image Processing Group (Limit: 2)  
Time: 0s  - resize1 execute, resize2 execute → ✅ (2/2)
Time: 1s  - resize3 request → ❌ Reject

※ Different groups are controlled independently
```

## Error Handling

For errors that may occur in ConcurrencyLimitedStrategy and how to handle them, also refer to the common patterns on the [Error Handling](<doc:ErrorHandling>) page.

### LockmanConcurrencyLimitedCancellationError

This error conforms to `LockmanCancellationError` protocol and provides:
- `cancelledInfo`: Information about the cancelled action
- `boundaryId`: Where the cancellation occurred
- `existingInfos`: Array of currently active infos
- `currentCount`: Current number of active executions

```swift
lockFailure: { error, send in
    if let concurrencyError = error as? LockmanConcurrencyLimitedCancellationError {
        let limit = concurrencyError.cancelledInfo.limit
        let current = concurrencyError.currentCount
        await send(.concurrencyLimitReached(
            "Concurrency limit reached (\(current)/\(limit))"
        ))
    }
}
```

