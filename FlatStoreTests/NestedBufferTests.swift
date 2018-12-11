//
//  NestedBufferTests.swift
//  FlatStoreTests
//
//  Created by muukii on 2018/12/11.
//  Copyright © 2018 eure. All rights reserved.
//

import Foundation

import XCTest

@testable import FlatStore

final class NestedBufferTests: XCTestCase {

  struct Key : NestedBufferKey {
    var firstKey: AnyHashable
    var secondKey: AnyHashable

    init(_ first: String, second: String) {
      self.firstKey = .init(first)
      self.secondKey = .init(second)
    }
  }

  func testMarge() {

    var buffer1 = NestedBuffer()
    var buffer2 = NestedBuffer()

    buffer1.set(object: "A", for: Key.init("1", second: "1"))
    buffer1.set(object: "A", for: Key.init("1", second: "2"))
    buffer1.set(object: "A", for: Key.init("2", second: "1"))
    buffer1.set(object: "A", for: Key.init("2", second: "2"))

    buffer2.set(object: "_A", for: Key.init("1", second: "1"))
    buffer2.set(object: "_A", for: Key.init("1", second: "2"))

    do {
      var base = buffer1
      base.mergeWithOverwriting(buffer2)
      print(base)
      XCTAssert(base.object(for: Key.init("1", second: "1")) as! String == "_A")
    }

    do {
      var base = buffer2
      base.mergeWithOverwriting(buffer1)
      print(base)
      XCTAssert(base.object(for: Key.init("2", second: "1")) as! String == "A")
    }

  }
}
