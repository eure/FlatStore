//
//  InMemoryEntityStorage.swift
//  FlatStore
//
//  Created by muukii on 2019/11/05.
//  Copyright © 2019 eure. All rights reserved.
//

import Foundation

public struct InMemoryEntityStorage: EntityStorageType {
  
  public var allItemCount: Int {
    backingStore.reduce(0) { (count, arg1) -> Int in
      let (_, value) = arg1
      return count + value.byID.count
    }
  }
  
  private var backingStore: Storage = [:]
  private let _lock = NSRecursiveLock()
  
  public init() {
    
  }
  
  public mutating func update(inTable name: String, update: (inout EntityTable) -> Void) {
    if backingStore[name] != nil {
      update(&backingStore[name]!)
    } else {
      var table = EntityTable()
      update(&table)
      backingStore[name] = table
    }
  }
  
  public func table(name: String) -> EntityTable? {
    backingStore[name]
  }
  
  public mutating func removeAll() {
    backingStore = [:]
  }
  
  public func allItems() -> [Any] {
    backingStore.reduce(into: [Any]()) { (r, arg1) in
      let (_, value) = arg1
      let items = value.byID.map { $0.value }
      r.append(contentsOf: items)
    }
  }
  
  public mutating func merge(inMemoryStorage: InMemoryEntityStorage) {
    
    inMemoryStorage.backingStore.forEach { key, value in
      if var table = backingStore[key] {
        table.byID.merge(value.byID, uniquingKeysWith: { _, new in new })
      } else {
        backingStore[key] = value
      }
    }
  }
  
}

extension InMemoryEntityStorage {
  
  public struct Getter<Entity: FlatStoreObjectType> {
    
    let storage: InMemoryEntityStorage
    
    public init(storage: InMemoryEntityStorage) {
      self.storage = storage
    }
    
    public func find(by id: Entity.FlatStoreID) -> Entity? {
      storage.table(name: Entity.FlatStoreID.tableName)?.byID[id.id] as? Entity
    }
    
  }
  
}
