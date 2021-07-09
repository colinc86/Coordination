//
//  Task.swift
//  Coordination
//
//  Created by Colin Campbell on 7/5/21.
//

import Foundation

/// Tasks represent an executable block with conditions.
public class Task: Equatable {
  
  // MARK: Types

  /// A task's block.
  public typealias Block = (_ finished: inout Bool, _ cancelled: inout Bool) -> Void

  /// A task's execution condition.
  public enum Condition {
    
    /// Cancel the receiver if the given task is currently executing.
    case cancelIfExecuting(task: Task)
    
    /// Defer the receiver's execution if the given task is currently executing.
    case deferIfExecuting(task: Task)
  }

  /// A task's execution state.
  public enum State {
    
    /// The task is not executing.
    case none
    
    /// The task is executing.
    case executing
    
    /// The task was cancelled.
    case cancelled
    
    /// The task's execution was deferred.
    case deferred
  }
  
  // MARK: Public properties
  
  /// The task's identifier.
  public let identifier: UUID
  
  /// The task's conditions.
  public var conditions: [Condition]
  
  /// The task's queue.
  public var queue: DispatchQueue?
  
  // MARK: Read-only properties
  
  /// The current state of the task.
  public var state: State {
    return safeState
  }
  
  // MARK: Internal properties
  
  /// The current state of the task.
  ///
  /// Internal methods should use this property to update the task's state.
  internal var safeState: State {
    get {
      _stateSemaphore.wait()
      defer { _stateSemaphore.signal() }
      return _state
    }
    
    set {
      _stateSemaphore.wait()
      _state = newValue
      _stateSemaphore.signal()
    }
  }
  
  /// The task's block to execute.
  internal var block: Block
  
  /// Indicates whether or not the task has finished executing.
  internal var finished: Bool = true {
    didSet {
      if finished && !oldValue {
        finishedExecuting()
      }
    }
  }
  
  /// Indicatese that the task has been cancelled by a background task.
  internal var cancelled: Bool = false
  
  // MARK: Private properties
  
  /// The current state of the task.
  ///
  /// Do not access this property directly. Use the `state` or `safeState`
  /// properties.
  private var _state: State = .none
  
  /// A semaphore to access the `_state` property.
  private var _stateSemaphore = DispatchSemaphore(value: 1)
  
  /// The callback called when the task has finished executing.
  private var finishedCallback: (() -> Void)?
  
  // MARK: Initializers
  
  /// Initializes a task with a set of conditions.
  ///
  /// - Parameters:
  ///   - conditions: The task's conditions.
  ///   - block: The task's block to execute.
  ///   - queue: The queue to execute the block on.
  public init(conditions: [Condition], block: @escaping Block, queue: DispatchQueue? = nil) {
    identifier = UUID()
    self.conditions = conditions
    self.block = block
    self.queue = queue
  }
  
  /// Initializes a task.
  ///
  /// - Parameters:
  ///   - block: The task's block to execute.
  ///   - queue: The queue to execute the block on.
  ///   - isBackgroundCapable: If the task can be backgrounded.
  public convenience init(block: @escaping Block, queue: DispatchQueue? = nil) {
    self.init(conditions: [], block: block, queue: queue)
  }
  
  // MARK: Overridable methods
  
  /// Signifies that the task has finished executing.s
  internal func finishedExecuting() {
    finishedCallback?()
    finishedCallback = nil
  }
  
}

// MARK: - Public methods

extension Task {
  
  /// Executes the task and calls its completion handler.
  ///
  /// - Parameters:
  ///   - queue: The queue to execute the task on. If the task has a non-`nil`
  ///     `queue` instance property, then that queue takes precedence.
  ///   - completion: Called after the task finishes executing.
  public final func execute(on queue: DispatchQueue? = nil, _ completion: (() -> Void)? = nil) {
    let execution = { [weak self] in
      guard let self = self else {
        completion?()
        return
      }
      
      self.finished = false
      self.finishedCallback = completion
      self.cancelled = false
      self.block(&self.finished, &self.cancelled)
    }
    
    if let queue = self.queue {
      queue.async(execute: execution)
    }
    else if let queue = queue {
      queue.async(execute: execution)
    }
    else {
      execution()
    }
  }
  
  /// Cancels execution of the task.
  public final func cancel() {
    safeState = .cancelled
    finished = true
    cancelled = true
  }
  
}

// MARK: - Equatable methods

extension Task {
  
  public static func == (lhs: Task, rhs: Task) -> Bool {
    return lhs.identifier == rhs.identifier
  }
  
}
