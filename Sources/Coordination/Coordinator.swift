//
//  Coordinator.swift
//  Coordination
//
//  Created by Colin Campbell on 6/29/21.
//

import ApplicationKey
import Foundation

/// Executes tasks.
public class Coordinator {
  
  // MARK: Static properties
  
  /// The shared coordinator.
  public static let shared = Coordinator()
  
  // MARK: Public properties
  
  /// The queue to execute tasks on.
  public var queue: DispatchQueue?
  
  /// The coordinator's delegate.
  public weak var delegate: CoordinatorDelegate?
  
  // MARK: Private properties
  
  /// Semaphore for safe access to the task arrays.
  private let semaphore = DispatchSemaphore(value: 1)
  
  /// An array of tasks that are currently executing.
  private var executingTasks = [Task]()
  
  /// An array of tasks that are awaiting execution.
  private var pendingTasks = [Task]()
  
  // MARK: Initializers
  
  /// Initializes a coordinator.
  ///
  /// - Parameter queue: An optional queue to execute tasks on.
  public init(queue: DispatchQueue? = nil) {
    self.queue = queue
  }
  
}

// MARK: - Public methods

extension Coordinator {
  
  /// Executes the given task.
  ///
  /// - Parameter task: The task to execute.
  /// - Returns: The state of the task.
  @discardableResult
  public func execute(_ task: Task) -> Task.State {
    // Wrap the next portion of code in our semaphore so everything is set
    // before we potentially begin executing the task.
    semaphore.wait()
    
    // Can we execute the task?
    guard canExecute(task) else {
      // We can't execute the task right now, but can we defer its execution?
      if shouldDeferExecution(of: task) {
        // We should defer the tasks execution...
        pendingTasks.append(task)
        
        // Clean up and inform our delegate that we deferred execution.
        semaphore.signal()
        delegate?.coordinator(self, didDeferExecutionOf: task)
        return .deferred
      }
      
      // We can't defer execution, so cancel the task.
      semaphore.signal()
      delegate?.coordinator(self, didCancel: task)
      return .cancelled
    }
    
    // We are going to execute this task.
    executingTasks.append(task)
    semaphore.signal()
    
    // Create a block that will execute the task from various queues.
    let executionClosure = { [weak self] in
      guard let self = self else { return }
      
      // Tell the delegate we're executing the task, and begin.
      self.delegate?.coordinator(self, willExecute: task)
      task.execute { [weak task] in
        guard let task = task else { return }
        
        // Tell the delegate we've finished, and clean up.
        self.delegate?.coordinator(self, finishedExecuting: task)
        self.finished(task)
      }
    }
    
    // If we don't have a queue, or the task has a queue, then just execute the
    // task.
    if queue == nil || task.queue != nil {
      executionClosure()
    }
    // If we have a queue, then use it.
    else if let queue = queue {
      queue.async {
        executionClosure()
      }
    }
    
    return .executing
  }
  
}

// MARK: - Private methods

extension Coordinator {
  
  /// Determines if a task can be immediately executed.
  ///
  /// - Parameter task: The task to execute.
  /// - Returns: A boolean indicating if the task can be executed.
  private func canExecute(_ task: Task) -> Bool {
    for condition in task.conditions {
      switch condition {
      case .cancelIfExecuting(let task), .deferIfExecuting(let task):
        if executingTasks.contains(task) {
          return delegate?.coordinator(self, canExecute: task, decision: false) ?? false
        }
      }
    }
    
    return delegate?.coordinator(self, canExecute: task, decision: true) ?? true
  }
  
  /// Determines if a task's execution should be deferred until a later date.
  ///
  /// - Parameter task: The task to defer.
  /// - Returns: A boolean indicating if the task can be deferred.
  private func shouldDeferExecution(of task: Task) -> Bool {
    for condition in task.conditions {
      switch condition {
      case .deferIfExecuting(let task):
        if executingTasks.contains(task) {
          return delegate?.coordinator(self, shouldDeferExecutionOf: task, decision: true) ?? true
        }
      default:
        continue
      }
    }
    
    return delegate?.coordinator(self, shouldDeferExecutionOf: task, decision: false) ?? false
  }
  
  /// Should be called when a task has finished executing.
  ///
  /// - Parameter task: The task that finished executing.
  private func finished(_ task: Task) {
    semaphore.wait()
    
    // Get ride of the task in the executing tasks array.
    if let index = executingTasks.firstIndex(where: { $0 == task }) {
      executingTasks.remove(at: index)
    }
    
    // Bail if there are no more pending tasks to check.
    guard pendingTasks.count > 0 else {
      semaphore.signal()
      return
    }
    
    // Get an array of tasks that can be executed.
    var queuedTasks = [Task]()
    for i in stride(from: pendingTasks.count - 1, through: 0, by: -1) where canExecute(pendingTasks[i]) {
      queuedTasks.append(pendingTasks.remove(at: i))
    }
    semaphore.signal()
    
    // Execute the queued tasks.
    for queuedTask in queuedTasks {
      execute(queuedTask)
    }
  }
  
}
