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

public protocol FlatRefType {
  associatedtype Element : Identifiable
  var value: Element? { get }
}

open class FlatRef<Element : Identifiable> : Hashable {

  public static func == (lhs: FlatRef<Element>, rhs: FlatRef<Element>) -> Bool {
    return lhs.identifier == rhs.identifier
  }

  // MARK: - Properties

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }

  private let lock = UnfairLock()

  public weak var store: FlatStore?

  public let identifier: Identifier<Element>

  public var value: Element? {
    lock.lock(); defer { lock.unlock() }
    return cached ?? store?.get(by: identifier)
  }

  public var isLiving: Bool {
    return store != nil
  }

  private var cached: Element?

  private var token: NotificationTokenType?

  // MARK: - Initializers

  init(key: Identifier<Element>, in store: FlatStore, cached: Element?) {
    self.store = store
    self.identifier = key
    self.cached = cached
    token = observe { [weak self] (update) in
      guard let self = self else { return }
      self.lock.lock()
      self.cached = update.value
      self.lock.unlock()
    }
  }

  deinit {
    token?.invalidate()
  }

  // MARK: - Functions

  public func observe(callback: @escaping (FlatStore.Update<Element?>) -> Void) -> NotificationTokenType? {

    return store?.observe(identifier, callback: callback)

  }
}

public protocol CachingFlatRefType {
  associatedtype Element : Identifiable
  var cached: Element { get }
}

open class CachingFlatRef<Element : Identifiable> : CachingFlatRefType, Hashable {

  public static func == (lhs: CachingFlatRef<Element>, rhs: CachingFlatRef<Element>) -> Bool {
    return lhs.identifier == rhs.identifier
  }

  // MARK: - Properties

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }

  private let lock = UnfairLock()

  public weak var store: FlatStore?

  public let identifier: Identifier<Element>

  public var cached: Element {
    lock.lock(); defer { lock.unlock() }
    return _cached
  }

  public var isDeleted: Bool = false

  public var isLiving: Bool {
    return store != nil
  }

  private var _cached: Element

  private var token: NotificationTokenType?

  // MARK: - Initializers

  init(key: Identifier<Element>, in store: FlatStore, cached: Element) {
    self.store = store
    self.identifier = key
    self._cached = cached
    token = store.observe(key) { [weak self] (update) in
      guard let self = self else { return }
      guard let value = update.value else {
        self.isDeleted = true
        return
      }
      self.isDeleted = false
      self.lock.lock()
      self._cached = value
      self.lock.unlock()
    }
  }

  deinit {
    token?.invalidate()
  }

  // MARK: - Functions

  public func observe(callback: @escaping (FlatStore.Update<Element>) -> Void) -> NotificationTokenType? {

    return store?.observe(identifier, callback: { o in
      guard let value = o.value else { return }
      callback(FlatStore.Update<Element>.init(value: value, from: o.store))
    })

  }

  public func asFlatRef() -> FlatRef<Element>? {

    guard let store = store else { return nil }

    return FlatRef.init(key: identifier, in: store, cached: nil)

  }

}
