//
//  BackgroundTask.swift
//  Coordination
//
//  Created by Colin Campbell on 7/8/21.
//

#if (os(iOS) || os(tvOS))
import UIKit

/// A task that is background capable.
public class BackgroundTask: Task {
  
  /// The current background task identifier, if any.
  private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier? = nil
  
  /// Keeps track of background state.
  private var backgroundNotifier = BackgroundNotifier()
  
  // MARK: Initializers
  
  public override init(queue: DispatchQueue? = nil, conditions: [Task.Condition], block: @escaping Task.Block) {
    super.init(queue: queue, conditions: conditions, block: block)
    backgroundNotifier.delegate = self
  }
  
  // MARK: Override methods
  
  override func finishedExecuting() {
    super.finishedExecuting()
    endBackgroundTask()
  }
  
}

// MARK: - Public methods

extension BackgroundTask {
  
  /// Executes the task by first beginning a background task.
  ///
  /// - Parameters:
  ///   - queue: The queue to execute the task on.
  ///   - completion: Called after the task finishes executing.
  public final func executeInBackground(on queue: DispatchQueue? = nil, _ completion: (() -> Void)? = nil) {
    beginBackgroundTask()
    execute(on: queue, completion)
  }
  
}

// MARK: - Private methods

extension BackgroundTask {
  
  /// Begins a background task.
  private func beginBackgroundTask() {
    // Get a copy of the current task
    let pendingBackgroundTaskIdentifier = backgroundTaskIdentifier
    
    // Create a new background task
    backgroundTaskIdentifier = createBackgroundTaskIdentifier()
    
    // End the old background task
    if let uPendingBackgroundTaskIdentifier = pendingBackgroundTaskIdentifier, uPendingBackgroundTaskIdentifier != .invalid {
      UIApplication.shared.endBackgroundTask(uPendingBackgroundTaskIdentifier)
    }
  }
  
  /// Ends a current background task.
  private func endBackgroundTask() {
    defer {
      backgroundTaskIdentifier = nil
    }
    
    guard let uBackgroundTaskIdentifier = backgroundTaskIdentifier else {
      return
    }
    
    guard uBackgroundTaskIdentifier != .invalid else {
      return
    }
    
    UIApplication.shared.endBackgroundTask(uBackgroundTaskIdentifier)
  }
  
  /// Creates a new background task identifier.
  ///
  /// - Returns: A background task identifier.
  private func createBackgroundTaskIdentifier() -> UIBackgroundTaskIdentifier? {
    // Create the background task and set the expiration handler.
    var taskIdentifier: UIBackgroundTaskIdentifier = .invalid
    taskIdentifier = UIApplication.shared.beginBackgroundTask(withName: identifier.uuidString, expirationHandler: { [weak self] in
      // Halt execution
      self?.cancel()
    })
    
    // Ensure that the background task identifier isn't invalid.
    guard taskIdentifier != UIBackgroundTaskIdentifier.invalid else {
      return nil
    }
    
    return taskIdentifier
  }
  
}

// MARK: - BackgroundNotifierDelegate methods

extension BackgroundTask: BackgroundNotifierDelegate {
  
  func didEnterBackground() {
    beginBackgroundTask()
  }
  
  func willEnterForeground() {
    endBackgroundTask()
  }
  
}

#endif
