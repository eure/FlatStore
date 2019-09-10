//
// Copyright (c) 2018 eureka, Inc.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import XCTest
@testable import FlatStore

struct User : FlatStoreObjectType, Equatable {
  
  var rawID: String { return name }
  
  var name: String
  
}

struct Comment : FlatStoreObjectType, Equatable {
  var rawID: String
  
  var userID: FlatStoreObjectIdentifier<User>
  var body: String = ""
}

struct Post : FlatStoreObjectType, Equatable {
  
  var rawID: String
  
  var body: String = ""
}

class FlatStoreTests: XCTestCase {

  let storeA = FlatStore()
  let storeB = FlatStore()

 

  override func setUp() {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    let a = User(name: "a")
    let b = User(name: "b")
    let c = User(name: "c")

    storeA.set(value: a)
    storeA.set(value: b)
    storeA.set(value: c)

    for i in 0..<10000 {
      storeA.set(value: Comment(rawID: "A-\(i)", userID: a.id, body: "\(i)"))
    }

    for i in 0..<10000 {
      storeA.set(value: Comment(rawID: "B-\(i)", userID: b.id, body: "\(i)"))
    }

    for i in 0..<10000 {
      storeA.set(value: Comment(rawID: "C-\(i)", userID: c.id, body: "\(i)"))
    }

    for i in 0..<10000 {
      storeA.set(value: Post(rawID: "A-\(i)", body: "\(i)"))
    }

    for i in 0..<10000 {
      storeA.set(value: Post(rawID: "B-\(i)", body: "\(i)"))
    }

    for i in 0..<10000 {
      storeA.set(value: Post(rawID: "C-\(i)", body: "\(i)"))
    }

  }

  override func tearDown() {
    storeA.deleteAll()
  }

  func testGetRelationship() {

    let comment = storeA.get(by: FlatStoreObjectIdentifier<Comment>.init("A-5"))

    XCTAssertNotNil(comment)

    let user = storeA.get(by: comment!.userID)

    XCTAssertNotNil(user)

  }

  func testInitialNotification() {

    let comment = storeA.get(by: FlatStoreObjectIdentifier<Comment>.init("A-5"))!
    let body = comment.body

    let exp = XCTestExpectation(description: "Receive Notification")

    let token = storeA.observe(FlatStoreObjectIdentifier<Comment>.init("A-5"), receiveInitial: true) { (update) in

      guard let comment = update.value else {
        XCTFail("OH")
        exp.fulfill()
        return
      }

      XCTAssertEqual(comment.body, body)
      exp.fulfill()
    }

    wait(for: [exp], timeout: 10)
    _ = token

  }

  func testUpdateNotification() {

    var comment = storeA.get(by: FlatStoreObjectIdentifier<Comment>.init("A-5"))!

    let exp = XCTestExpectation(description: "Receive Notification")

    let token = storeA.observe(FlatStoreObjectIdentifier<Comment>.init("A-5"), receiveInitial: false) { (update) in
      guard let comment = update.value else {
        XCTFail("OH")
        exp.fulfill()
        return
      }
      XCTAssertEqual(comment.body, "Hello")
      exp.fulfill()
    }

    comment.body = "Hello"

    storeA.set(value: comment)

    wait(for: [exp], timeout: 10)
    _ = token
  }

  func testRef() {

    let comment = storeA.get(by: FlatStoreObjectIdentifier<Comment>.init("A-5"))!

    let ref = storeA.makeRef(from: comment)!

    XCTAssertNotNil(ref.value)
    XCTAssertEqual(ref.value, comment)

  }

  func testNotificationDifferentStore() {

    var comment = storeA.get(by: FlatStoreObjectIdentifier<Comment>("A-5"))!

    let exp = XCTestExpectation(description: "Receive Notification")

    let token = storeA.observe(FlatStoreObjectIdentifier<Comment>("A-5"), receiveInitial: false) { (change) in
      XCTFail("Oh")
    }

    comment.body = "Hello"

    storeB.set(value: comment)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      exp.fulfill()
    }
    wait(for: [exp], timeout: 0.5)
    _ = token
  }

  func testPerformanceExample() {
    // This is an example of a performance test case.
    self.measure {
      for i in 0..<10000 {
        _ = storeA.get(by: FlatStoreObjectIdentifier<Comment>("A-\(i)"))
      }
    }
  }

}
