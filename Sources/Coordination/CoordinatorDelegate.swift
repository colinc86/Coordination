//
//  CoordinatorDelegate.swift
//  Coordination
//
//  Created by Colin Campbell on 7/7/21.
//

import Foundation

public protocol CoordinatorDelegate: AnyObject {
  
  /// Asks the coordinator's delegate if the task should be executed.
  ///
  /// This method is called at the end of the coordinator's decision to execute
  /// a task after any conditions have been evaluated.
  ///
  /// - Parameters:
  ///   - coordinator: The coordinator.
  ///   - task: The task that can be executed.
  ///   - decision: The coordinator's decision.
  func coordinator(_ coordinator: Coordinator, shouldExecute task: Task, decision: Bool) -> Bool
  
  /// Asks the coordinator's delegate if the task should be deferred.
  ///
  /// This method is called at the end of the coordinator's decision to defer
  /// a task after any conditions have been evaluated.
  ///
  /// - Parameters:
  ///   - coordinator: The coordinator.
  ///   - task: The task that should be deferred.
  ///   - decision: The coordinator's decision.
  func coordinator(_ coordinator: Coordinator, shouldDeferExecutionOf task: Task, decision: Bool) -> Bool
  
  /// Informs the coordinator's delegate that the execution of a task was
  /// deferred.
  ///
  /// - Parameters:
  ///   - coordinator: The coordinator.
  ///   - task: The task that was deferred.
  func coordinator(_ coordinator: Coordinator, didDeferExecutionOf task: Task)
  
  /// Informs the coordinator's delegate that the execution of a task was
  /// cancelled.
  ///
  /// - Parameters:
  ///   - coordinator: The coordinator.
  ///   - task: The task that was cancelled.
  func coordinator(_ coordinator: Coordinator, didCancel task: Task)
  
  /// Informs the coordinator's delegate that a task is about to be executed.
  ///
  /// - Parameters:
  ///   - coordinator: The coordinator.
  ///   - task: The task to be executed
  func coordinator(_ coordinator: Coordinator, willExecute task: Task)
  
  /// Informs the coordinator's delegate that a task has finished executing.
  ///
  /// - Parameters:
  ///   - coordinator: The coordinator.
  ///   - task: The task that finished executing.
  func coordinator(_ coordinator: Coordinator, finishedExecuting task: Task)
  
}
