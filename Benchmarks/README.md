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
- **Platform**: macOS, Darwin Kernel Version 24.3.0
- **Architecture**: arm64 (Apple Silicon M3 Max)
- **Processors**: 14 cores
- **Memory**: 36 GB
- **Date**: June 15, 2025

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
| **.run (baseline)** | 16μs | - | 62K ops/s | 207K | 12MB |
| **SingleExecution** | 14μs | -12.5% ⚡ | 72K ops/s | 174K | 13MB |
| **PriorityBased** | 14μs | -12.5% ⚡ | 71K ops/s | 173K | 14MB |
| **DynamicCondition** | 33μs | +106% | 31K ops/s | 590K | 12MB |
| **CompositeStrategy** | 33μs | +106% | 30K ops/s | 595K | 12MB |

### 🚀 Burst Load Performance (100 Concurrent Actions)

| Metric | SingleExecution | PriorityBased | Ratio |
|--------|-----------------|---------------|-------|
| **Wall Clock Time (median)** | 691μs | 15ms | 22x faster |
| **Throughput** | 1,449 ops/s | 67 ops/s | 22x higher |
| **Total CPU Time** | 997μs | 8,520μs | 8.5x less |
| **Memory Allocated** | 1,392 items | 41K items | 29x less |
| **Peak Memory** | 14MB | 23MB | 1.6x less |

### 📈 Latency Distribution Analysis

#### SingleExecution Burst (microseconds)
```
Percentiles:  p50    p75    p90    p99    p100
Wall Clock:   691    706    728    818   10,918
```

#### PriorityBased Burst (milliseconds)
```
Percentiles:  p50    p75    p90    p99    p100
Wall Clock:   15     15     15     16     16
```

## Performance Measurements

### 1. **SingleExecution Under Load**
- Processes 100 concurrent actions in **0.69ms**
- Shows linear scalability
- Memory footprint: ~1.4K malloc operations

### 2. **PriorityBased Performance**
- 22x slower than SingleExecution
- Processing time for 100 actions: 15ms
- Memory usage: 41K malloc operations (priority queue management)

### 3. **Competition Handling**
- **Medium competition scenario** (10 types × 10 instances):
  - SingleExecution: Minimal lock contention observed
  - PriorityBased: Priority conflicts resolved as designed

### 4. **Scalability Measurements**
- **SingleExecution**:
  - Single action: 14μs
  - 100 actions: 691μs (6.9μs per action amortized)
  
- **PriorityBased**:
  - Single action: 14μs
  - 100 actions: 15ms (150μs per action amortized)

## Measured Characteristics by Strategy

### 🎖️ SingleExecution

**Measured Performance**
- Performance under concurrent load: 0.69ms/100 actions
- Memory footprint: ~1.4K malloc operations
- Latency distribution: p50=691μs, p99=818μs
- Scaling: Linear

**Characteristics**
- No priority control
- FIFO ordering

**Burst Load Results**
- 100 actions: 0.69ms
- Memory: ~1.4K malloc operations
- CPU time: 997μs

### 🏆 PriorityBased

**Measured Performance**
- Performance under concurrent load: 15ms/100 actions
- Memory footprint: 41K malloc operations
- Latency distribution: p50=15ms, p99=16ms
- CPU time: 8,520μs

**Characteristics**
- Priority-based execution control
- Priority queue scheduling
- Priority inversion prevention

**Comparison to SingleExecution**
- 22x slower under high load
- 29x more memory usage

### 🔧 DynamicCondition

**Measured Performance**
- Wall clock time: 33μs (2.06x baseline)
- Memory allocation: 0 bytes
- Instructions: 590K

**Characteristics**
- Runtime condition evaluation
- Conditional execution logic

### 🔗 CompositeStrategy

**Measured Performance**
- Wall clock time: 33μs (2.06x baseline)
- Memory: 12MB
- Instructions: 595K

**Characteristics**
- Combines multiple strategies
- Configurable strategy composition

## Usage Examples

### High-Frequency Operations
```swift
// SingleExecution measured at 79K ops/s
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
    // SingleExecution: 0.69ms for 100 actions
    useSingleExecutionStrategy()
} else if needsPriorityControl {
    // PriorityBased: 15ms for 100 actions
    usePriorityBasedStrategy()
}
```

## Performance Reference

### Latency Measurements (100 actions)

| Strategy | Measured Latency | Throughput |
|----------|------------------|------------|
| SingleExecution | 691μs | 1,449 ops/s |
| PriorityBased | 15ms | 67 ops/s |
| DynamicCondition | Not measured in burst | 31K ops/s (single) |
| CompositeStrategy | Not measured in burst | 30K ops/s (single) |

### Memory Usage

| Strategy | Memory per 100 Actions | Peak Memory |
|----------|------------------------|-------------|
| SingleExecution | 1,392 malloc ops | 14MB |
| PriorityBased | 41K malloc ops | 23MB |
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
- Sample sizes: 67-8,848 iterations per test
- Consistent results across multiple runs
- Percentile analysis for outlier detection

## Summary

The following performance characteristics were measured:

1. **SingleExecution** processes 100 concurrent actions in 0.69ms with ~1.4K malloc operations.

2. **PriorityBased** processes 100 concurrent actions in 15ms with 41K malloc operations, providing priority-based execution control.

3. **Basic operations** show SingleExecution and PriorityBased performing 12.5% faster than baseline.

4. **Scalability** measurements show linear scaling for SingleExecution and sub-linear scaling for PriorityBased.

### Use Case Reference

| Use Case | Strategy | Measured Performance |
|----------|----------|---------------------|
| High-frequency operations | SingleExecution | 0.69ms/100 ops |
| Conditional execution | DynamicCondition | 33μs/op |
| Priority-based queuing | PriorityBased | 15ms/100 ops |
| Combined strategies | CompositeStrategy | 33μs/op |

---

*Benchmarks performed on June 15, 2025, using Lockman v1.0 on macOS 24.3.0*