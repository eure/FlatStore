//
//  NestedBuffer.swift
//  FlatStore
//
//  Created by muukii on 2018/12/11.
//  Copyright © 2018 eure. All rights reserved.
//

import Foundation

final class __Ref<T> : CustomStringConvertible {
  var source: T
  init(_ source: T) {
    self.source = source
  }

  var description: String {
    return "__Ref<\(Unmanaged.passUnretained(self).toOpaque())> \(source)"
  }
}

protocol NestedBufferKey {
  var firstKey: AnyHashable { get }
  var secondKey: AnyHashable { get }
}

struct NestedBuffer {

  var backingStore: [AnyHashable : __Ref<[AnyHashable : Any]>] = [:]

  init() {
    
  }

  func object<T : NestedBufferKey>(for key: T) -> Any? {
    return backingStore[key.firstKey]?.source[key.secondKey]
  }

  mutating func set<T : NestedBufferKey>(object: Any, for key: T) {
    if let _ = backingStore[key.firstKey] {
      backingStore[key.firstKey]!.source[key.secondKey] = object
    } else {
      var nested = [AnyHashable : Any]()
      nested[key.secondKey] = object
      backingStore[key.firstKey] = .init(nested)
    }
  }

  mutating func removeValue<T : NestedBufferKey>(forKey key: T) -> Any? {
    guard let nested = backingStore[key.firstKey] else { return nil }
    let removedValue = nested.source.removeValue(forKey: key.secondKey)
    return removedValue
  }

  mutating func mergeWithOverwriting(_ buffer: NestedBuffer) {

    for first in buffer.backingStore {
      if let current = backingStore[first.key] {
        current.source.merge(first.value.source) { (_, new) in new }
      } else {
        backingStore[first.key] = .init(first.value.source)
      }
    }
    
  }
}
