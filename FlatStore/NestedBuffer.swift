//
//  NestedBuffer.swift
//  FlatStore
//
//  Created by muukii on 2018/12/11.
//  Copyright © 2018 eure. All rights reserved.
//

import Foundation

protocol NestedBufferKey {
  var firstKey: AnyHashable { get }
  var secondKey: AnyHashable { get }
}

struct NestedBuffer {

  var backingStore: [AnyHashable : [AnyHashable : Any]] = [:]

  init() {
    
  }

  func object<T : NestedBufferKey>(for key: T) -> Any? {
    return backingStore[key.firstKey]?[key.secondKey]
  }

  mutating func set<T : NestedBufferKey>(object: Any, for key: T) {
    if var nested = backingStore[key.firstKey] {
      nested[key.secondKey] = object
      backingStore[key.firstKey] = nested
    } else {
      var nested = [AnyHashable : Any]()
      nested[key.secondKey] = object
      backingStore[key.firstKey] = nested
    }
  }

  mutating func removeValue<T : NestedBufferKey>(forKey key: T) -> Any? {
    guard var nested = backingStore[key.firstKey] else { return nil }
    let removedValue = nested.removeValue(forKey: key.secondKey)
    backingStore[key.firstKey] = nested
    return removedValue
  }

  mutating func mergeWithOverwriting(_ buffer: NestedBuffer) {

    for first in buffer.backingStore {
      if var current = backingStore[first.key] {
        current.merge(first.value) { (_, new) in new }
        backingStore[first.key] = current
      } else {
        backingStore[first.key] = first.value
      }
    }
    
  }
}
