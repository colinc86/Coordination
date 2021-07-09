//
//  Coordinator.swift
//  Coordination
//
//  Created by Colin Campbell on 6/29/21.
//

import Foundation

/// Coordinates the execution of tasks.
public class Coordinator {
  
  // MARK: Types
  
  #if (os(iOS) || os(tvOS))
  /// The state of a coordinator.
  public enum State {
    
    /// The coordinator is in the background.
    case background
    
    /// The coordinator is in the foreground.
    case foreground
  }
  #endif
  
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
  
  #if (os(iOS) || os(tvOS))
  /// The current background state of the coordinator.
  private(set) var state: State = .foreground
  
  /// Keeps track of background state.
  private var backgroundNotifier = BackgroundNotifier()
  #endif
  
  // MARK: Initializers
  
  /// Initializes a coordinator.
  ///
  /// - Parameter queue: An optional queue to execute tasks on.
  public init(queue: DispatchQueue? = nil) {
    self.queue = queue
    
    #if (os(iOS) || os(tvOS))
    backgroundNotifier.delegate = self
    #endif
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
    let taskState = determineState(of: task)
    
    if taskState == .executing {
      delegate?.coordinator(self, willExecute: task)
      
      let execution = { [weak self] in
        guard let self = self else { return }
        self.delegate?.coordinator(self, finishedExecuting: task)
        self.finished(task)
      }
      
      #if (os(iOS) || os(tvOS))
      if task is BackgroundTask && state == .background {
        (task as? BackgroundTask)?.executeInBackground(on: queue, execution)
      }
      else {
        task.execute(on: queue, execution)
      }
      #else
      task.execute(on: queue, execution)
      #endif
    }
    
    return taskState
  }
  
}

// MARK: - Private methods

extension Coordinator {
  
  /// Determines the desired state of a task.
  ///
  /// - Parameter task: The task.
  /// - Returns: The tasks desired state.
  private func determineState(of task: Task) -> Task.State {
    semaphore.wait()
    
    // Can we execute the task?
    guard canExecute(task) else {
      // We can't execute the task right now, but can we defer its execution?
      if shouldDeferExecution(of: task) {
        // We should defer the tasks execution...
        task.safeState = .deferred
        pendingTasks.append(task)
        
        // Clean up and inform our delegate that we deferred execution.
        semaphore.signal()
        delegate?.coordinator(self, didDeferExecutionOf: task)
        return .deferred
      }
      
      // We can't defer execution, so cancel the task.
      task.safeState = .cancelled
      semaphore.signal()
      delegate?.coordinator(self, didCancel: task)
      return .cancelled
    }
    
    // We are going to execute this task.
    task.safeState = .executing
    executingTasks.append(task)
    semaphore.signal()
    
    return .executing
  }
  
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
    
    // Update the task.
    task.safeState = .none
    
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

#if (os(iOS) || os(tvOS))
// MARK: - BackgroundNotifierDelegate methods

extension Coordinator: BackgroundNotifierDelegate {
  
  func didEnterBackground() {
    state = .background
  }
  
  func willEnterForeground() {
    state = .foreground
  }
  
}
#endif
