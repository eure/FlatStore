//
//  InMemoryEntityStorage.swift
//  FlatStore
//
//  Created by muukii on 2019/11/05.
//  Copyright © 2019 eure. All rights reserved.
//

import Foundation

public struct EntityTable {
  
  public var byID: [AnyHashable : Any] = [:]
    
}

public struct InMemoryEntityState: EntityStorageType {
  
  public var allItemCount: Int {
    backingStore.reduce(0) { (count, arg1) -> Int in
      let (_, value) = arg1
      return count + value.byID.count
    }
  }
  
  private var backingStore: Storage = [:]
  
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
    
  public func allItems() -> [Any] {
    backingStore.reduce(into: [Any]()) { (r, arg1) in
      let (_, value) = arg1
      let items = value.byID.map { $0.value }
      r.append(contentsOf: items)
    }
  }
  
  public mutating func merge(inMemoryStorage: InMemoryEntityState) {
    
    inMemoryStorage.backingStore.forEach { key, value in
      if var table = backingStore[key] {
        var merged = table.byID
        
        value.byID.forEach { key, value in
          merged[key] = value
        }
        
        table.byID = merged
        backingStore[key] = table
      } else {
        backingStore[key] = value
      }
    }
  }
  
}

// MARK: Query
extension InMemoryEntityState {
  
  public func get<T: FlatStoreObjectType>(by id: FlatStoreObjectIdentifier<T>) -> T? {
    table(name: T.FlatStoreID.tableName)?.byID[id.raw] as? T
  }
  
  public func get<S: Sequence, T: FlatStoreObjectType>(by ids: S) -> [T] where S.Element == FlatStoreObjectIdentifier<T> {
    return ids.compactMap { key in
      table(name: T.FlatStoreID.tableName)?.byID[key.raw] as? T
    }
  }
  
}

// MARK: Mutation
extension InMemoryEntityState {
  
  public mutating func set<T: FlatStoreObjectType>(value: T) {
    set(values: [value])
  }
  
  public mutating func set<T : Sequence>(values: T) where T.Element : FlatStoreObjectType {
    update(inTable: T.Element.FlatStoreID.tableName) { (table) in
      values.forEach { value in
        table.byID[value.id.raw] = value
      }
    }
  }
  
  public mutating func delete<T: FlatStoreObjectType>(value: T) {
    delete(values: [value])
  }
  
  public mutating func delete<T : Sequence>(values: T) where T.Element : FlatStoreObjectType {
    update(inTable: T.Element.FlatStoreID.tableName) { (table) in
      values.forEach { value in
        table.byID.removeValue(forKey: value.id.raw)
      }
    }
  }
      
  public mutating func deleteAll() {
    
    backingStore = [:]
  }
}

// MARK: Batch Updates
extension InMemoryEntityState {
  
  @discardableResult
  public mutating func performBatchUpdates<U>(updates: (NormalizedStateBatchUpdatesContext) throws -> U) rethrows -> U {
        
    let context = NormalizedStateBatchUpdatesContext(state: self)
    let u = try updates(context)
    merge(inMemoryStorage: context.buffer)
    return u
    
  }
  
}

public final class NormalizedStateBatchUpdatesContext {
  
  //  private let store: FlatStore
  
  var buffer = InMemoryEntityState()
  
  private let state: InMemoryEntityState
  
  public init(state: InMemoryEntityState) {
    self.state = state
  }
  
  public func set<T: FlatStoreObjectType>(value: T) -> T.FlatStoreID {
    let key = value.id
    _ = set(values: [value])
    return key
  }
  
  public func set<T : Sequence>(values: T) -> [FlatStoreObjectIdentifier<T.Element>] where T.Element : FlatStoreObjectType {
    let ids = values.map { $0.id }
    buffer.set(values: values)
    return ids
  }
  
  public func get<T: FlatStoreObjectType>(by key: FlatStoreObjectIdentifier<T>) -> T? {
    
    if let transientObject = (buffer.get(by: key)) {
      return transientObject
    }
    if let object = state.get(by: key) {
      return object
    }
    return nil
  }
  
}

extension InMemoryEntityState {
  
  public struct Getter<Entity: FlatStoreObjectType> {
    
    let storage: InMemoryEntityState
    
    public init(storage: InMemoryEntityState) {
      self.storage = storage
    }
    
    public func find(by id: Entity.FlatStoreID) -> Entity? {
      storage.table(name: Entity.FlatStoreID.tableName)?.byID[id.raw] as? Entity
    }
    
  }
  
}
