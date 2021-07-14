# Coordination

[![Unit Tests](https://github.com/colinc86/Coordination/actions/workflows/swift.yml/badge.svg)](https://github.com/colinc86/Coordination/actions/workflows/swift.yml)

Coordinates the execution of tasks.

## Usage

### Tasks

Tasks execute a block and contain an array of conditions. A coordinator coordinates the execution of tasks given their conditions.

#### Creating a Task

Create a task by giving it a block of type `Task.Block`.

```swift
let task = Task { (finished: inout Bool, cancelled: inout Bool) in
  // Do some work...
  
  // Check to see if the task has been cancelled
  if cancelled {
    // Clean up and bail.
    return
  }
  
  // Do some more work...
  
  // Tell the task we're finished
  finished = true
}
```

#### Executing a Task

Execute a task by calling `execute()` on it.

```swift
task.execute()
```

Execute the task and a closure when the task's block sets its `finished` property to `true`.

```swift
task.execute {
  // Finished executing the task
}
```

Finally, execute the task on the specified queue.

```swift
task.execute(on: DispatchQueue(label: "taskQueue")) {
  // Finished executing the task
}
```

- Note: Tasks also have a `queue` property that can be set to a given `DispatchQueue`.

```swift
task.queue = DispatchQueue(label: "taskQueue")
task.execute()
```

#### Cancelling a Task

If you need to cancel a task, and the task honors its block's `cancelled` parameter, then call `cancel()` on the task.

```swift
task.cancel()
```

### Coordinators

The package provides a shared coordinator which should be sufficient for most cases. You may also create your own coordinator to separate tasks in to their own pools.

#### Executing a Task

Give the coordinator a task to execute.

```swift
Coordinator.shared.execute(task)
```

The coordinator can also be given a dispatch queue to run tasks on. If the coordinator is provided a queue, then it takes precidence over a task's queue when executing a task with a coordinator.

```swift
Coordinator.shared.queue = DispatchQueue(label: "coordinatorQueue")
Coordinator.shared.execute(task)
```

#### Coordinating the Execution of Multiple Tasks

The coordinator can coordinate the execution of multiple tasks using tasks' conditions.

```swift
let taskA = Task(queue: DispatchQueue(label: "taskAQueue")) { (finished: inout Bool , cancelled: inout Bool) in
  // Do some work...
  finished = true
}

let taskB = Task(queue: DispatchQueue(label: "taskBQueue"), conditions: ) { (finished: inout Bool, cancelled: inout Bool) in
  // Do some work...
  finished = true
}

let testB = Task(
  queue: DispatchQueue(label: "taskBQueue"),
  conditions: [
    Task.Condition.deferIfExecuting(task: test)
  ]
) { (finished: inout Bool, cancelled: inout Bool) in
  // Do some work...
  finished = true
}

// Execute taskA and taskB, but defer the execution of taskB.
Coordinator.shared.execute(taskA)
Coordinator.shared.execute(taskB)
```
