//
//  BackgroundNotifier.swift
//  Coordinator
//
//  Created by Colin Campbell on 7/8/21.
//

#if (os(iOS) || os(tvOS))
import UIKit

/// Responds to messages about the application entering or leaving the
/// background.
internal protocol BackgroundNotifierDelegate: AnyObject {
  
  /// `UIApplication.didEnterBackgroundNotification` was called.
  func didEnterBackground()
  
  /// `UIApplication.willEnterForegroundNotification` was called.
  func willEnterForeground()
}

/// Notifies background notifier delegates when the app leaves or enters the
/// background.
internal class BackgroundNotifier {
  
  // MARK: Public properties
  
  weak var delegate: BackgroundNotifierDelegate?
  
  // MARK: Private properties
  
  /// Receives `UIApplication.didEnterBackgroundNotification` notifications.
  private var didEnterBackgroundNotificationObserver: NSObjectProtocol?
  
  /// Receives `UIApplication.willEnterForegroundNotification` notifications.
  private var willEnterForegroundNotificationObserver: NSObjectProtocol?
  
  /// An operation queue to keep things serial.
  private lazy var backgroundNotificationQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.maxConcurrentOperationCount = 1
    return queue
  }()
  
  /// Initializes a background notifier.
  ///
  /// - Parameter delegate: The notifier's delegate.
  init(delegate: BackgroundNotifierDelegate? = nil) {
    self.delegate = delegate
    
    didEnterBackgroundNotificationObserver = NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: backgroundNotificationQueue, using: receivedDidEnterBackgroundNotification)
    willEnterForegroundNotificationObserver = NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: backgroundNotificationQueue, using: receivedWillEnterForegroundNotification)
  }
  
  deinit {
    if let observer = didEnterBackgroundNotificationObserver {
      NotificationCenter.default.removeObserver(observer)
      didEnterBackgroundNotificationObserver = nil
    }
    
    if let observer = willEnterForegroundNotificationObserver {
      NotificationCenter.default.removeObserver(observer)
      willEnterForegroundNotificationObserver = nil
    }
  }
  
}

// MARK: Private methods

extension BackgroundNotifier {
  
  /// Called when a did enter background notification is received.
  ///
  /// - Parameter notification: The notification.
  private func receivedDidEnterBackgroundNotification(_ notification: Notification) {
    delegate?.didEnterBackground()
  }
  
  /// Called when a will enter foreground notification is received.
  ///
  /// - Parameter notification: The notification.
  private func receivedWillEnterForegroundNotification(_ notification: Notification) {
    delegate?.willEnterForeground()
  }
  
}

#endif
