import XCTest
@testable import Coordination

final class CoordinationTests: XCTestCase {
  
  func testTaskExecute() {
    let completionExpectation = expectation(description: "completion")
    let task = Task { ( finished: inout Bool) in
      Thread.sleep(forTimeInterval: 1.0)
      finished = true
      completionExpectation.fulfill()
    }
    
    XCTAssertEqual(Coordinator.shared.execute(task), .executing, "The task should successfully execute.")
    waitForExpectations(timeout: 1.1)
  }
  
  func testAsyncTasksExecute() {
    let completionExpectationA = expectation(description: "taskCmpletionA")
    let taskA = Task { ( finished: inout Bool) in
      print("A")
      Thread.sleep(forTimeInterval: 1.0)
      print("B")
      finished = true
      completionExpectationA.fulfill()
    }
    
    let completionExpectationB = expectation(description: "taskCmpletionB")
    let taskB = Task { ( finished: inout Bool) in
      print("C")
      Thread.sleep(forTimeInterval: 1.0)
      print("D")
      finished = true
      completionExpectationB.fulfill()
    }
    
    XCTAssertEqual(Coordinator.shared.execute(taskA), .executing, "The task should successfully execute.")
    XCTAssertEqual(Coordinator.shared.execute(taskB), .executing, "The task should successfully execute.")
    
    waitForExpectations(timeout: 1.1)
  }
  
  func testDeferredTask() {
    let completionExpectationA = expectation(description: "taskCmpletionA")
    let taskA = Task { ( finished: inout Bool) in
      print("A")
      Thread.sleep(forTimeInterval: 1.0)
      print("B")
      finished = true
      completionExpectationA.fulfill()
    }
    
    let completionExpectationB = expectation(description: "taskCmpletionB")
    let taskB = Task { ( finished: inout Bool) in
      print("C")
      Thread.sleep(forTimeInterval: 1.0)
      print("D")
      finished = true
      completionExpectationB.fulfill()
    }
    taskB.conditions = [Task.Condition.deferIfExecuting(task: taskA)]
    
    XCTAssertEqual(Coordinator.shared.execute(taskA), .executing, "The task should successfully execute.")
    XCTAssertEqual(Coordinator.shared.execute(taskB), .deferred, "The task should be deferred.")
    
    waitForExpectations(timeout: 2.1)
  }
  
  func testCancelledTask() {
    let completionExpectationA = expectation(description: "taskCmpletionA")
    let taskA = Task { ( finished: inout Bool) in
      print("A")
      Thread.sleep(forTimeInterval: 1.0)
      print("B")
      finished = true
      completionExpectationA.fulfill()
    }
    
    let taskB = Task { ( finished: inout Bool) in
      finished = true
    }
    taskB.conditions = [Task.Condition.cancelIfExecuting(task: taskA)]
    
    XCTAssertEqual(Coordinator.shared.execute(taskA), .executing, "The task should successfully execute.")
    XCTAssertEqual(Coordinator.shared.execute(taskB), .cancelled, "The task should be cancelled.")
    
    waitForExpectations(timeout: 1.1)
  }
  
}
