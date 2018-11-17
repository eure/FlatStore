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

public struct AnyIdentifier : Hashable {

  public let typeName: String
  public let raw: AnyHashable
  public let notificationName: Notification.Name

  public init(typeName: String, rawID: AnyHashable) {
    self.typeName = typeName
    self.raw = rawID
    self.notificationName = .init(rawValue: "\(typeName)|\(rawID)")
  }

}

public struct Identifier<T : Identifiable> : Hashable {

  public static func == <T>(lhs: Identifier<T>, rhs: Identifier<T>) -> Bool {
    return lhs.raw == rhs.raw
  }

  public var notificationName: Notification.Name {
    return asAny.notificationName
  }

  public let asAny: AnyIdentifier
  public let raw: T.RawIDType

  public init(_ raw: T.RawIDType) {
    self.raw = raw
    self.asAny = AnyIdentifier(typeName: String.init(reflecting: T.self), rawID: .init(raw))
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

public protocol Identifiable {

  associatedtype RawIDType : Hashable
  var rawID: RawIDType { get }
}

extension Identifiable {

  public typealias ID = Identifier<Self>

  public var id: Identifier<Self> {
    return Identifier<Self>.init(rawID)
  }
}

open class FlatStore {

  final var storage: [AnyIdentifier : Any] = [:]

  private let notificationCenter: NotificationCenter = .init()

  private let storeIdentifier: String = UUID().uuidString

  private let notificationQueue = OperationQueue()

  private let lock = NSRecursiveLock()

  public init() {
    notificationQueue.maxConcurrentOperationCount = 1    
  }

  @inline(__always)
  private final func makeSeparatedNotificationName(_ name: Notification.Name) -> Notification.Name {
    return .init(rawValue: "\(storeIdentifier)|\(name.rawValue)")
  }
  
}

/// Accessing Data
extension FlatStore {

  public func get<T: Identifiable>(by id: Identifier<T>) -> T? {
    lock.lock(); defer { lock.unlock() }
    return storage[id.asAny] as? T
  }

  public func get<S: Sequence, T: Identifiable>(by ids: S) -> [T] where S.Element == Identifier<T> {
    lock.lock(); defer { lock.unlock() }
    return ids.compactMap { key in
      storage[key.asAny] as? T
    }
  }

  public func get(by id: AnyIdentifier) -> Any? {
    lock.lock(); defer { lock.unlock() }
    return storage[id]
  }

  @discardableResult
  public func set<T: Identifiable>(value: T) -> CachingFlatRef<T> {
    
    let key = value.id

    lock.lock()
    storage[key.asAny] = value
    lock.unlock()

    let notification = makeSeparatedNotificationName(key.notificationName)
    notificationQueue.addOperation {
      self.notificationCenter.post(name: notification, object: value)
    }

    let ref = _makeCachingRef(from: value)
    return ref
  }

  @discardableResult
  public func set<T : Sequence>(values: T) -> [CachingFlatRef<T.Element>] where T.Element : Identifiable {

    return
      values.map {
        set(value: $0)
    }

  }

  public func delete<T: Identifiable>(value: T) {
    let key = value.id

    lock.lock()
    _ = storage.removeValue(forKey: key.asAny)
    lock.unlock()

    let notification = makeSeparatedNotificationName(key.notificationName)
    notificationQueue.addOperation {
      self.notificationCenter.post(name: notification, object: value)
    }
  }

  public func deleteAll() {
    lock.lock(); defer { lock.unlock() }
    storage = [:]
  }

}

extension FlatStore {

  private func _makeCachingRef<T : Identifiable>(from value: T) -> CachingFlatRef<T> {
    return CachingFlatRef<T>.init(key: value.id, in: self, cached: value)
  }

  private func _makeRef<T : Identifiable>(from value: T) -> FlatRef<T> {
    return FlatRef<T>.init(key: value.id, in: self, cached: value)
  }

  public func makeRef<T : Identifiable>(from value: T) -> FlatRef<T>? {
    guard get(by: value.id) != nil else { return nil }
    return _makeRef(from: value)
  }

  public func makeCachingRef<T : Identifiable>(from value: T) -> CachingFlatRef<T>? {
    guard get(by: value.id) != nil else { return nil }
    return _makeCachingRef(from: value)
  }

  public func makeCachingRef<T : Identifiable>(from identifier: Identifier<T>) -> CachingFlatRef<T>? {
    guard let value = get(by: identifier) else { return nil }
    let ref = CachingFlatRef.init(key: identifier, in: self, cached: value)
    return ref
  }

  public func makeCachingRefs<S : Sequence, T : Identifiable>(from identifiers: S) -> [CachingFlatRef<T>] where S.Element == Identifier<T> {
    let values = get(by: identifiers)
    let refs = values.map {
      CachingFlatRef.init(key: $0.id, in: self, cached: $0)
    }
    return refs
  }

  public func makeCachingRefs<S : Sequence, T : Identifiable>(from values: S) -> [CachingFlatRef<T>] where S.Element == T {
    let values = get(by: values.map { $0.id })
    let refs = values.map {
      CachingFlatRef.init(key: $0.id, in: self, cached: $0)
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
    _ key: AnyIdentifier,
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

  public func observe<T>(
    _ key: Identifier<T>,
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

  public func observe<T: Identifiable>(
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

    for item in context.buffer {
      storage[item.key] = item.value
    }
    return u
    
  }

}
