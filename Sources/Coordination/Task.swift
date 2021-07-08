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
  public typealias Block = (_ finished: inout Bool) -> Void

  /// A task's execution condition.
  public enum Condition {
    
    /// Cancel the receiver if the given task is currently executing.
    case cancelIfExecuting(task: Task)
    
    /// Defer the receiver's execution if the given task is currently executing.
    case deferIfExecuting(task: Task)
  }

  /// A task's execution state.
  public enum State {
    
    /// The task is executing.
    case executing
    
    /// The task was cancelled.
    case cancelled
    
    /// The task's execution was deferred.
    case deferred
  }
  
  // MARK: Public properties
  
  /// The task's identifier.
  public let identifier = UUID()
  
  /// The task's conditions.
  public var conditions: [Condition]
  
  /// The task's queue.
  public var queue: DispatchQueue?
  
  // MARK: Internal properties
  
  /// The task's block to execute.
  public var block: Block
  
  // MARK: Private properties
  
  /// Indicates whether or not the task has finished executing.
  private var finished: Bool = true {
    didSet {
      if finished && !oldValue {
        finishedCallback?()
        finishedCallback = nil
      }
    }
  }
  
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
    self.conditions = conditions
    self.block = block
    self.queue = queue
  }
  
  /// Initializes a task.
  ///
  /// - Parameters:
  ///   - block: The task's block to execute.
  ///   - queue: The queue to execute the block on.
  public convenience init(block: @escaping Block, queue: DispatchQueue? = nil) {
    self.init(conditions: [], block: block, queue: queue)
  }
  
  // MARK: Overridable methods
  
  /// Executes the task and calls its completion handler.
  ///
  /// - Parameter completion: Called after the task finishes executing.
  internal func execute(_ completion: (() -> Void)? = nil) {
    finished = false
    finishedCallback = completion
    block(&self.finished)
  }
  
}

// MARK: - Equatable methods

extension Task {
  
  public static func == (lhs: Task, rhs: Task) -> Bool {
    return lhs.identifier == rhs.identifier
  }
  
}
