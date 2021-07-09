import XCTest
@testable import Coordination

final class CoordinationTests: XCTestCase {
  
  /// Creates a task that waits on the given thread for the desired sleep
  /// interval.
  ///
  /// - Parameters:
  ///   - needsExpectation: If an expectation should be created.
  ///   - queue: The queue to use for the task.
  ///   - sleepInterval: The interval, in seconds, to sleep for.
  ///   - conditions: The task's conditions.
  /// - Returns: A task.
  func createTask(needsExpectation: Bool = true, withQueue queue: DispatchQueue? = nil, sleepInterval: Int = 1, conditions: [Task.Condition] = []) -> Task {
    var completionExpectation: XCTestExpectation?
    if needsExpectation {
      completionExpectation = expectation(description: "taskCompletion")
    }

    let task = Task { (finished: inout Bool, cancelled: inout Bool) in
      for _ in 0 ..< Int(sleepInterval) {
        Thread.sleep(forTimeInterval: 1.0)
        
        if cancelled {
          break
        }
      }
      
      finished = true
      completionExpectation?.fulfill()
    }
    
    task.queue = queue
    task.conditions = conditions
    return task
  }
  
  override class func setUp() {
    super.setUp()
    Coordinator.shared.queue = nil
  }
  
  // MARK: - Tests
  
  /// Test that we can execute a task on the calling queue.
  func testTaskExecutionNoQueues() {
    XCTAssertEqual(
      Coordinator.shared.execute(createTask()),
      .executing,
      "The task should successfully execute."
    )
    
    waitForExpectations(timeout: 1.1)
  }
  
  /// Test that we can execute a task using a background queue on the task.
  func testTaskExecutionTaskQueueNoCoordinatorQueue() {
    XCTAssertEqual(
      Coordinator.shared.execute(createTask(withQueue: DispatchQueue(label: "taskQueue"))),
      .executing,
      "The task should successfully execute."
    )
    
    waitForExpectations(timeout: 1.1)
  }
  
  /// Test that we can execute a task using a background queue on the
  /// coordinator.
  func testTaskExecutionNoTaskQueuesCoordinatorQueue() {
    Coordinator.shared.queue = DispatchQueue(label: "coordinatorQueue")
    
    XCTAssertEqual(
      Coordinator.shared.execute(createTask()),
      .executing,
      "The task should successfully execute."
    )
    
    waitForExpectations(timeout: 1.1)
  }
  
  /// Test that we can execute a task using a background queue on the
  /// coordinator and the task, preferring the task.
  func testTaskExecutionTaskQueuesCoordinatorQueue() {
    Coordinator.shared.queue = DispatchQueue(label: "coordinatorQueue")
    
    XCTAssertEqual(
      Coordinator.shared.execute(createTask(withQueue: DispatchQueue(label: "taskQueue"))),
      .executing,
      "The task should successfully execute."
    )
    
    waitForExpectations(timeout: 1.1)
  }
  
  func testSerialTasksNoQueues() {
    XCTAssertEqual(
      Coordinator.shared.execute(createTask()),
      .executing,
      "The task should successfully execute."
    )
    
    XCTAssertEqual(
      Coordinator.shared.execute(createTask()),
      .executing,
      "The task should successfully execute."
    )
    
    waitForExpectations(timeout: 2.1)
  }
  
  func testAsyncTasksTaskQueuesNoCoordinatorQueue() {
    XCTAssertEqual(
      Coordinator.shared.execute(createTask(withQueue: DispatchQueue(label: "taskAQueue"))),
      .executing,
      "The task should successfully execute."
    )

    XCTAssertEqual(
      Coordinator.shared.execute(createTask(withQueue: DispatchQueue(label: "taskBQueue"))),
      .executing,
      "The task should successfully execute."
    )

    waitForExpectations(timeout: 1.1)
  }
  
  func testSyncTasksNoTaskQueuesCoordinatorQueue() {
    Coordinator.shared.queue = DispatchQueue(label: "coordinatorQueue")
    
    XCTAssertEqual(
      Coordinator.shared.execute(createTask()),
      .executing,
      "The task should successfully execute."
    )

    XCTAssertEqual(
      Coordinator.shared.execute(createTask()),
      .executing,
      "The task should successfully execute."
    )

    waitForExpectations(timeout: 2.1)
  }
  
  func testAsyncTasksTaskQueuesCoordinatorQueue() {
    Coordinator.shared.queue = DispatchQueue(label: "coordinatorQueue")
    
    XCTAssertEqual(
      Coordinator.shared.execute(createTask(withQueue: DispatchQueue(label: "taskAQueue"))),
      .executing,
      "The task should successfully execute."
    )

    XCTAssertEqual(
      Coordinator.shared.execute(createTask(withQueue: DispatchQueue(label: "taskBQueue"))),
      .executing,
      "The task should successfully execute."
    )

    waitForExpectations(timeout: 1.1)
  }
  
  func testDeferredTask() {
    let taskA = createTask(withQueue: DispatchQueue(label: "taskAQueue"))
    XCTAssertEqual(
      Coordinator.shared.execute(taskA),
      .executing,
      "The task should successfully execute."
    )

    XCTAssertEqual(
      Coordinator.shared.execute(createTask(withQueue: DispatchQueue(label: "taskBQueue"), conditions: [Task.Condition.deferIfExecuting(task: taskA)])),
      .deferred,
      "The task should be deferred."
    )

    waitForExpectations(timeout: 2.1)
  }
  
  func testCancelledTask() {
    Coordinator.shared.queue = DispatchQueue(label: "coordinatorQueue")
    
    let taskA = createTask(withQueue: DispatchQueue(label: "taskAQueue"))
    XCTAssertEqual(
      Coordinator.shared.execute(taskA),
      .executing,
      "The task should successfully execute."
    )

    XCTAssertEqual(
      Coordinator.shared.execute(createTask(needsExpectation: false, withQueue: DispatchQueue(label: "taskBQueue"), conditions: [Task.Condition.cancelIfExecuting(task: taskA)])),
      .cancelled,
      "The task should be cancelled."
    )

    waitForExpectations(timeout: 1.1)
  }
  
}
