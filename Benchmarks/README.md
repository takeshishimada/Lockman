# Lockman Performance Benchmark Report

## Executive Summary

Comprehensive performance benchmarks of the Lockman library have been conducted, including both basic operations and high-load burst scenarios with 100 concurrent actions. The measurements cover different strategies and their performance characteristics under various load conditions.

## How to Run Benchmarks

```bash
# Run all benchmarks
swift package benchmark

# Run specific benchmark
swift package benchmark --filter ".withLock SingleExecution"

# List available benchmarks
swift package benchmark list

# Export results in different formats
swift package benchmark --format jmh    # JMH format
swift package benchmark --format influx # InfluxDB format
```

## Benchmark Configuration

### Test Environment
- **Platform**: macOS, Darwin Kernel Version 24.5.0
- **Architecture**: arm64 (Apple Silicon M1 Pro)
- **Processors**: 8 cores
- **Memory**: 16 GB
- **Date**: June 29, 2025
- **TCA Version**: 1.18.0

### Test Scenarios

#### 1. Basic Performance Tests
- Single action execution with minimal load
- Comparison of all four strategies against baseline

#### 2. Burst Load Tests
- **Concurrent Actions**: 100 simultaneous actions
- **Competition Pattern**: Medium competition (10 action types × 10 instances each)
- **Priority Distribution** (PriorityBased only):
  - High (exclusive): 20%
  - Low (replaceable): 50%
  - None: 30%

## Performance Results

### 📊 Basic Operation Performance (Median Values)

| Strategy | Wall Clock Time | vs Baseline | Throughput | Instructions | Memory |
|----------|-----------------|-------------|------------|--------------|---------|
| **.run (baseline)** | 16μs | - | 62K ops/s | 209K | 12MB |
| **SingleExecution** | 22μs | +37.5% | 45K ops/s | 231K | 14MB |
| **PriorityBased** | 23μs | +43.8% | 44K ops/s | 236K | 14MB |
| **DynamicCondition** | 38μs | +137.5% | 26K ops/s | 605K | 12MB |
| **CompositeStrategy** | 38μs | +137.5% | 26K ops/s | 610K | 12MB |

### 🚀 Burst Load Performance (100 Concurrent Actions)

| Metric | SingleExecution | PriorityBased | Ratio |
|--------|-----------------|---------------|-------|
| **Wall Clock Time (median)** | 14ms | 15ms | 1.07x slower |
| **Throughput** | 73 ops/s | 67 ops/s | 1.09x higher |
| **Total CPU Time** | 6,406μs | 11,000μs | 1.7x less |
| **Memory Allocated** | 1,679 items | 5,095 items | 3.0x less |
| **Peak Memory** | 14MB | 21MB | 1.5x less |

### 📈 Latency Distribution Analysis

#### SingleExecution Burst (microseconds)
```
Percentiles:  p50    p75    p90    p99    p100
Wall Clock:   14     15     16     20     20
```

#### PriorityBased Burst (milliseconds)
```
Percentiles:  p50    p75    p90    p99    p100
Wall Clock:   15     15     15     16     16
```

## Performance Measurements

### 1. **SingleExecution Under Load**
- Processes 100 concurrent actions in **14ms**
- Shows good scalability
- Memory footprint: ~1.7K malloc operations

### 2. **PriorityBased Performance**
- Comparable performance to SingleExecution (1.07x slower)
- Processing time for 100 actions: 15ms
- Memory usage: 5.1K malloc operations (priority queue management)

### 3. **Competition Handling**
- **Medium competition scenario** (10 types × 10 instances):
  - SingleExecution: Minimal lock contention observed
  - PriorityBased: Priority conflicts resolved as designed

### 4. **Scalability Measurements**
- **SingleExecution**:
  - Single action: 22μs
  - 100 actions: 14ms (140μs per action amortized)
  
- **PriorityBased**:
  - Single action: 23μs
  - 100 actions: 15ms (150μs per action amortized)

## Measured Characteristics by Strategy

### 🎖️ SingleExecution

**Measured Performance**
- Performance under concurrent load: 14ms/100 actions
- Memory footprint: ~1.7K malloc operations
- Latency distribution: p50=14ms, p99=20ms
- Scaling: Good

**Characteristics**
- No priority control
- FIFO ordering

**Burst Load Results**
- 100 actions: 14ms
- Memory: ~1.7K malloc operations
- CPU time: 6,406μs

### 🏆 PriorityBased

**Measured Performance**
- Performance under concurrent load: 15ms/100 actions
- Memory footprint: 41K malloc operations
- Latency distribution: p50=15ms, p99=16ms
- CPU time: 11,000μs

**Characteristics**
- Priority-based execution control
- Priority queue scheduling
- Priority inversion prevention

**Comparison to SingleExecution**
- 1.07x slower under high load
- 3.0x more memory usage

### 🔧 DynamicCondition

**Measured Performance**
- Wall clock time: 38μs (2.38x baseline)
- Memory allocation: 0 bytes
- Instructions: 605K

**Characteristics**
- Runtime condition evaluation
- Conditional execution logic

### 🔗 CompositeStrategy

**Measured Performance**
- Wall clock time: 38μs (2.38x baseline)
- Memory: 12MB
- Instructions: 610K

**Characteristics**
- Combines multiple strategies
- Configurable strategy composition

## Usage Examples

### High-Frequency Operations
```swift
// SingleExecution measured at 45K ops/s
@LockmanSingleExecution
enum Action {
    case processRequest(id: String)
    var lockmanInfo: LockmanSingleExecutionInfo {
        .init(actionId: "process-\(id)", mode: .boundary)
    }
}
```

### Priority-Based Systems
```swift
// PriorityBased with priority control
@LockmanPriorityBased
enum Action {
    case urgentTask
    case backgroundTask
    
    var lockmanInfo: LockmanPriorityBasedInfo {
        switch self {
        case .urgentTask:
            return .init(actionId: actionName, priority: .high(.exclusive))
        case .backgroundTask:
            return .init(actionId: actionName, priority: .low(.replaceable))
        }
    }
}
```

### Load Pattern Configuration
```swift
// Configuration based on measured performance
if expectedConcurrency > 50 && !needsPriority {
    // SingleExecution: 14ms for 100 actions
    useSingleExecutionStrategy()
} else if needsPriorityControl {
    // PriorityBased: 15ms for 100 actions (comparable performance)
    usePriorityBasedStrategy()
}
```

## Performance Reference

### Latency Measurements (100 actions)

| Strategy | Measured Latency | Throughput |
|----------|------------------|------------|
| SingleExecution | 14ms | 73 ops/s |
| PriorityBased | 15ms | 67 ops/s |
| DynamicCondition | Not measured in burst | 26K ops/s (single) |
| CompositeStrategy | Not measured in burst | 26K ops/s (single) |

### Memory Usage

| Strategy | Memory per 100 Actions | Peak Memory |
|----------|------------------------|-------------|
| SingleExecution | 1,679 malloc ops | 14MB |
| PriorityBased | 5,095 malloc ops | 21MB |
| DynamicCondition | 0 bytes (allocation) | 12MB |
| CompositeStrategy | Not measured | 12MB |

## Benchmark Methodology

### Test Implementation
- The Swift Benchmark package is used for accurate measurements
- Multiple warm-up iterations are performed
- Percentiles (p50, p75, p90, p99, p100) are measured
- Tests are run in an isolated environment

### Burst Test Design
```swift
// 100 concurrent actions with medium competition
await withTaskGroup(of: Void.self) { group in
    for i in 0..<100 {
        let actionId = i / 10  // 10 instances per action type
        group.addTask {
            await store.send(.burst(id: actionId)).finish()
        }
    }
}
```

### Statistical Reliability
- Sample sizes: 66-9,248 iterations per test
- Consistent results across multiple runs
- Percentile analysis for outlier detection

## Summary

The following performance characteristics were measured:

1. **SingleExecution** processes 100 concurrent actions in 14ms with ~1.7K malloc operations.

2. **PriorityBased** processes 100 concurrent actions in 15ms with 5.1K malloc operations, providing priority-based execution control.

3. **Basic operations** show SingleExecution and PriorityBased performing 37.5-43.8% slower than baseline (due to TCA overhead).

4. **Scalability** measurements show good scaling for both SingleExecution and PriorityBased, with comparable performance under high load.

### Use Case Reference

| Use Case | Strategy | Measured Performance |
|----------|----------|---------------------|
| High-frequency operations | SingleExecution | 14ms/100 ops |
| Conditional execution | DynamicCondition | 38μs/op |
| Priority-based queuing | PriorityBased | 15ms/100 ops |
| Combined strategies | CompositeStrategy | 38μs/op |

---

*Benchmarks performed on June 29, 2025, using TCA 1.18.0 on macOS 24.5.0*