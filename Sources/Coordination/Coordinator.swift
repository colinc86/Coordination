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
  
  // MARK: Private properties
  
  /// Semaphore for safe access to the task arrays.
  private let semaphore = DispatchSemaphore(value: 1)
  
  /// An array of tasks that are currently executing.
  private var executingTasks = [Task]()
  
  /// An array of tasks that are awaiting execution.
  private var pendingTasks = [Task]()
  
  // MARK: Initializers
  
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
    self.semaphore.wait()
    
    guard self.canExecute(task) else {
      if self.shouldDeferExecution(of: task) {
        self.pendingTasks.append(task)
        self.semaphore.signal()
        return .deferred
      }
      self.semaphore.signal()
      return .cancelled
    }
    
    self.executingTasks.append(task)
    self.semaphore.signal()
    
    let executionClosure = {
      task.execute { [weak task] in
        self.finished(task)
      }
    }
    
    if queue == nil || task.queue != nil {
      executionClosure()
    }
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
          return false
        }
      }
    }
    
    return true
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
          return true
        }
      default:
        continue
      }
    }
    
    return false
  }
  
  /// Should be called when a task has finished executing.
  ///
  /// - Parameter task: The task that finished executing.
  private func finished(_ task: Task?) {
    guard let task = task else {
      return
    }
    
    self.semaphore.wait()
    if let index = executingTasks.firstIndex(where: { $0 == task }) {
      executingTasks.remove(at: index)
    }
    
    guard pendingTasks.count > 0 else {
      semaphore.signal()
      return
    }
    
    var queuedTasks = [Task]()
    for i in stride(from: pendingTasks.count - 1, through: 0, by: -1) where canExecute(pendingTasks[i]) {
      queuedTasks.append(pendingTasks.remove(at: i))
    }
    semaphore.signal()
    
    for queuedTask in queuedTasks {
      execute(queuedTask)
    }
  }
  
}
