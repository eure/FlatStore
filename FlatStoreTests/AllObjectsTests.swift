//
//  AllObjectsTests.swift
//  FlatStoreTests
//
//  Created by muukii on 2019/09/10.
//  Copyright © 2019 eure. All rights reserved.
//

import XCTest
@testable import FlatStore

final class AllObjectsTests: XCTestCase {

  let storeA = FlatStore()

  override func setUp() {
    
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
  
  func testAllObjects() {
        
    let count = storeA.allObjects(type: Post.self).count
    XCTAssertEqual(count, 30000)
  }
  
  func testPerformanceAllObjects() {
    
    print(storeA.itemCount)
    measure {
      storeA.allObjects(type: Post.self)
    }
  }
}
