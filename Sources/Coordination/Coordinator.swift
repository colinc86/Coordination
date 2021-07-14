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
    semaphore.wait()
    let taskState = determineState(of: task)
    switch taskState {
    case .deferred:
      // We should defer the tasks execution...
      pendingTasks.append(task)
      semaphore.signal()
      
      task.safeState = .deferred
      delegate?.coordinator(self, didDeferExecutionOf: task)
    case .cancelled:
      // We can't defer execution, so cancel the task.
      semaphore.signal()
      
      task.safeState = .cancelled
      delegate?.coordinator(self, didCancel: task)
    case .executing:
      // We are going to execute this task.
      // May way...
      for cancelledTask in makeWay(for: task) {
        delegate?.coordinator(self, didCancel: cancelledTask)
      }
      executingTasks.append(task)
      semaphore.signal()
      
      task.safeState = .executing
      execute(task: task)
    default:
      break
    }
    
    // Return the state of the task
    return taskState
  }
  
  /// Executes the given tasks.
  /// 
  /// - Parameter tasks: The tasks to execute.
  /// - Returns: An array of task states for each of the tasks in the array.
  @discardableResult
  public func execute(tasks: [Task]) -> [Task.State] {
    var states = [Task.State]()
    for task in tasks {
      states.append(execute(task))
    }
    return states
  }
  
}

// MARK: - Private methods

extension Coordinator {
  
  /// Determines the desired state of a task.
  ///
  /// - Parameter task: The task.
  /// - Returns: The tasks desired state.
  private func determineState(of task: Task) -> Task.State {
    if canExecute(task) {
      // We can execute the task now.
      return .executing
    }
    else if shouldDeferExecution(of: task) {
      // We can't execute the task, but we should defer its execution.
      return .deferred
    }
    
    // We should cancel the task
    return .cancelled
  }
  
  /// Determines if a task can be immediately executed.
  ///
  /// - Parameter task: The task to execute.
  /// - Returns: A boolean indicating if the task can be executed.
  private func canExecute(_ task: Task) -> Bool {
    for condition in task.conditions {
      switch condition {
      case .cancelIfExecuting(let tasks), .deferIfExecuting(let tasks):
        // We can't execute this task if any executing task is included in the
        // cancel or defer task arrays.
        if executingTasks.contains(where: { tasks.contains($0) }) {
          return delegate?.coordinator(self, shouldExecute: task, decision: false) ?? false
        }
      default:
        continue
      }
    }
    
    return delegate?.coordinator(self, shouldExecute: task, decision: true) ?? true
  }
  
  /// Determines if a task's execution should be deferred until a later date.
  ///
  /// - Parameter task: The task to defer.
  /// - Returns: A boolean indicating if the task can be deferred.
  private func shouldDeferExecution(of task: Task) -> Bool {
    for condition in task.conditions {
      switch condition {
      case .deferIfExecuting(let tasks):
        // We should defer this task if any executing task is included in the
        // defer task array.
        if executingTasks.contains(where: { tasks.contains($0) }) {
          return delegate?.coordinator(self, shouldDeferExecutionOf: task, decision: true) ?? true
        }
      default:
        continue
      }
    }
    
    return delegate?.coordinator(self, shouldDeferExecutionOf: task, decision: false) ?? false
  }
  
  /// Cancels any executing tasks that are included in any of the given tasks
  /// `makeWayByCancelling` conditions.
  ///
  /// - Parameter task: The task to make way for.
  /// - Returns: The tasks that were cancelled.
  private func makeWay(for task: Task) -> [Task] {
    var cancelledTasks = [Task]()
    for condition in task.conditions {
      switch condition {
      case .makeWayByCancelling(let tasks):
        // We should cancel any executing task that is included in the makeWay
        // task array.
        for task in executingTasks where tasks.contains(task) {
          task.cancel()
          cancelledTasks.append(task)
        }
      default:
        continue
      }
    }
    return cancelledTasks
  }
  
  /// Executes the task.
  ///
  /// - Parameter task: The task to execute.
  private func execute(task: Task) {
    // Block to execute when a task completes.
    let execution = { [weak self] in
      guard let self = self else { return }
      self.finished(task)
    }
    
    // Tell the delegate we're about to execute the task
    delegate?.coordinator(self, willExecute: task)
    
    // Execute the task
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
  
  /// Should be called when a task has finished executing.
  ///
  /// - Parameter task: The task that finished executing.
  private func finished(_ task: Task) {
    semaphore.wait()
    
    // Update the task.
    task.safeState = .none
    
    // Notify the delegate
    delegate?.coordinator(self, finishedExecuting: task)
    
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
