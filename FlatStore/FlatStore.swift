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

import Foundation

public struct FlatStoreAnyIdentifier : Hashable {

  public let typeName: String
  public let raw: AnyHashable
  public let notificationName: Notification.Name

  public init(typeName: String, rawID: AnyHashable) {
    self.typeName = typeName
    self.raw = rawID
    self.notificationName = .init(rawValue: "\(typeName)|\(rawID)")
  }

}

public struct FlatStoreObjectIdentifier<T : FlatStoreObjectType> : Hashable, CustomStringConvertible {
  
  public var id: T.RawIDType {
    return raw
  }
  
  public static var typeName: String {
    String.init(reflecting: T.self)
  }
  
  public static func == <T>(lhs: FlatStoreObjectIdentifier<T>, rhs: FlatStoreObjectIdentifier<T>) -> Bool {
    return lhs.raw == rhs.raw
  }

  public var notificationName: Notification.Name {
    return asAny.notificationName
  }

  public let asAny: FlatStoreAnyIdentifier
  public let raw: T.RawIDType

  public init(_ raw: T.RawIDType) {
    self.raw = raw
    self.asAny = FlatStoreAnyIdentifier(typeName: Self.typeName, rawID: .init(raw))
  }

  public var description: String {
    return "\(T.self).\(raw)"
  }
}

public protocol NotificationTokenType : class {
  func invalidate()
}

public final class FlatStoreNotificationToken : NotificationTokenType {

  private var token: NSObjectProtocol
  private weak var notificationCenter: NotificationCenter?

  init(
    token: NSObjectProtocol,
    notificationCenter: NotificationCenter
    ) {
    self.token = token
    self.notificationCenter = notificationCenter
  }

  deinit {
    invalidate()
  }

  public func invalidate() {
    notificationCenter?.removeObserver(token)
  }
}

public protocol FlatStoreObjectType {
    
  associatedtype RawIDType : Hashable
  var rawID: RawIDType { get }
  var id: FlatStoreObjectIdentifier<Self> { get }
}

extension FlatStoreObjectType {

  public typealias FlatStoreID = FlatStoreObjectIdentifier<Self>
  
  public typealias Ref = FlatStoreRef<Self>
  
  public typealias CachingRef = FlatStoreCachingRef<Self>

  public var id: FlatStoreObjectIdentifier<Self> {
    return FlatStoreObjectIdentifier<Self>.init(rawID)
  }
  
}

public protocol PersistentStoreType {
  
  typealias Storage = [FlatStoreAnyIdentifier : Any]
  
  var rawStorage: Storage { get }
  var allItemCount: Int { get }
  
  func updateStorage(_ update: (inout Storage) -> ())
  
}

public final class InMemoryPersistentStore: PersistentStoreType {
  
  public var allItemCount: Int {
    return rawStorage.count
  }
  
  public var rawStorage: Storage = [:]
  
  public init() {
    
  }
  
  public func updateStorage(_ update: (inout Storage) -> ()) {
    update(&rawStorage)
  }
  
}

// MARK: FlatStore

open class FlatStore {
  
  public var itemCount: Int {
    storage.allItemCount
  }
  
  private let storage: PersistentStoreType

  private let notificationCenter: NotificationCenter = .init()
  
  private let storeIdentifier: String = UUID().uuidString

  private let notificationQueue = OperationQueue()

  private let lock = NSRecursiveLock()

  public init(persistentStore: PersistentStoreType = InMemoryPersistentStore()) {
    self.storage = persistentStore
    notificationQueue.maxConcurrentOperationCount = 1    
  }

  @inline(__always)
  private final func makeSeparatedNotificationName(_ name: Notification.Name) -> Notification.Name {
    return .init(rawValue: "\(storeIdentifier)|\(name.rawValue)")
  }
  
}

// MARK: - Accessing Data
extension FlatStore {
  
  public func get<T: FlatStoreObjectType>(by id: FlatStoreObjectIdentifier<T>) -> T? {
    lock.lock(); defer { lock.unlock() }
    return storage.rawStorage[id.asAny] as? T
  }

  public func get<S: Sequence, T: FlatStoreObjectType>(by ids: S) -> [T] where S.Element == FlatStoreObjectIdentifier<T> {
    lock.lock(); defer { lock.unlock() }
    return ids.compactMap { key in
      storage.rawStorage[key.asAny] as? T
    }
  }

  public func get(by id: FlatStoreAnyIdentifier) -> Any? {
    lock.lock(); defer { lock.unlock() }
    return storage.rawStorage[id]
  }

  @discardableResult
  public func set<T: FlatStoreObjectType>(value: T) -> T.CachingRef {
    
    let key = value.id
    
    lock.lock()
    storage.updateStorage { (store) in
      _ = store[key.asAny] = value
    }
    lock.unlock()

    let notification = makeSeparatedNotificationName(key.notificationName)
    notificationQueue.addOperation {
      self.notificationCenter.post(name: notification, object: value)
    }

    let ref = _makeCachingRef(from: value)
    return ref
  }

  @discardableResult
  public func set<T : Sequence>(values: T) -> [T.Element.CachingRef] where T.Element : FlatStoreObjectType {

    return
      values.map {
        set(value: $0)
    }

  }

  public func delete<T: FlatStoreObjectType>(value: T) {
    let key = value.id

    lock.lock()
    storage.updateStorage { (store) in
      _ = store.removeValue(forKey: key.asAny)
    }
    lock.unlock()

    let notification = makeSeparatedNotificationName(key.notificationName)
    notificationQueue.addOperation {
      self.notificationCenter.post(name: notification, object: value)
    }
  }

  public func deleteAll() {
    lock.lock(); defer { lock.unlock() }
    storage.updateStorage { (store) in
      _ = store.removeAll()
    }
  }

}

// MARK: - Querying
extension FlatStore {
  
  public func allObjects<T: FlatStoreObjectType>(type: T.Type) -> [T] {
    lock.lock(); defer { lock.unlock() }
    let typeName = T.FlatStoreID.typeName
    return storage.rawStorage.filter { $0.key.typeName == typeName }.map { $0.value } as! [T]
  }

}

extension FlatStore {

  private func _makeCachingRef<T : FlatStoreObjectType>(from value: T) -> T.CachingRef {
    return FlatStoreCachingRef<T>.init(id: value.id, in: self, cached: value)
  }

  private func _makeRef<T : FlatStoreObjectType>(from value: T) -> T.Ref {
    return FlatStoreRef<T>.init(id: value.id, in: self, cached: value)
  }

  public func makeRef<T : FlatStoreObjectType>(from value: T) -> T.Ref? {
    guard get(by: value.id) != nil else { return nil }
    return _makeRef(from: value)
  }

  public func makeCachingRef<T : FlatStoreObjectType>(from value: T) -> T.CachingRef? {
    guard get(by: value.id) != nil else { return nil }
    return _makeCachingRef(from: value)
  }

  public func makeCachingRef<T : FlatStoreObjectType>(from identifier: T.FlatStoreID) -> T.CachingRef? {
    guard let value = get(by: identifier) else { return nil }
    let ref = FlatStoreCachingRef.init(id: identifier, in: self, cached: value)
    return ref
  }

  public func makeCachingRefs<S : Sequence, T : FlatStoreObjectType>(from identifiers: S) -> [T.CachingRef] where S.Element == FlatStoreObjectIdentifier<T> {
    let values = get(by: identifiers)
    let refs = values.map {
      FlatStoreCachingRef.init(id: $0.id, in: self, cached: $0)
    }
    return refs
  }

  public func makeCachingRefs<S : Sequence, T : FlatStoreObjectType>(from values: S) -> [T.CachingRef] where S.Element == T {
    let values = get(by: values.map { $0.id })
    let refs = values.map {
      FlatStoreCachingRef.init(id: $0.id, in: self, cached: $0)
    }
    return refs
  }

}

/// Observing
extension FlatStore {

  public struct Update<T> {
    public let value: T
    public let store: FlatStore

    init(value: T, from store: FlatStore) {
      self.value = value
      self.store = store
    }
  }

  public func observe(
    _ key: FlatStoreAnyIdentifier,
    receiveInitial: Bool = true,
    callback: @escaping (Update<Any?>) -> Void
    ) -> NotificationTokenType {

    let name = makeSeparatedNotificationName(key.notificationName)
    let _token = notificationCenter.addObserver(
      forName: name,
      object: nil,
      queue: nil,
      using: { [weak self] notification in
        guard let self = self else { return }
        guard let object = notification.object else {
          callback(Update<Any?>(value: nil, from: self))
          return
        }
        callback(Update<Any?>(value: object, from: self))
    })

    let token = FlatStoreNotificationToken(
      token: _token,
      notificationCenter: notificationCenter
    )

    if receiveInitial {
      notificationQueue.addOperation { [weak self] in
        guard let self = self else { return }
        let value = self.get(by: key)
        callback(Update.init(value: value, from: self))
      }
    }

    return token
  }

  public func observe<T: FlatStoreObjectType>(
    _ key: T.FlatStoreID,
    receiveInitial: Bool = true,
    callback: @escaping (Update<T?>) -> Void
    ) -> NotificationTokenType {

    return
      observe(
        key.asAny,
        receiveInitial: receiveInitial
      ) { (notification) in
        callback(Update.init(value: (notification.value as! T), from: notification.store))
    }

  }

  public func observe<T: FlatStoreObjectType>(
    _ value: T,
    receiveInitial: Bool = true,
    callback: @escaping (Update<T?>) -> Void
    ) -> NotificationTokenType {

    return observe(
      value.id,
      receiveInitial: receiveInitial,
      callback: callback
    )
  }
}

extension FlatStore {

  @discardableResult
  public func performBatchUpdates<U>(updates: (FlatStore, FlatBatchUpdatesContext) throws -> U) rethrows -> U {

    lock.lock(); defer { lock.unlock() }

    let context = FlatBatchUpdatesContext(store: self)
    let u = try updates(self, context)

    storage.updateStorage { (store) in
      for item in context.buffer {
        store[item.key] = item.value
      }
    }
    return u
    
  }

}
