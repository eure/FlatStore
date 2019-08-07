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

public final class FlatStoreRef<Element : FlatStoreObjectType> : Hashable {

  public static func == (lhs: FlatStoreRef<Element>, rhs: FlatStoreRef<Element>) -> Bool {
    return lhs.identifier == rhs.identifier
  }

  // MARK: - Properties

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }

  private var lock = os_unfair_lock_s()

  public weak var store: FlatStore?

  public let identifier: FlatStoreObjectIdentifier<Element>

  public var value: Element? {
    os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
    return cached ?? store?.get(by: identifier)
  }

  public var isLiving: Bool {
    return store != nil
  }

  private var cached: Element?

  private var token: NotificationTokenType?

  // MARK: - Initializers

  init(key: FlatStoreObjectIdentifier<Element>, in store: FlatStore, cached: Element?) {
    self.store = store
    self.identifier = key
    self.cached = cached
    token = observe { [weak self] (update) in
      guard let self = self else { return }
      os_unfair_lock_lock(&self.lock)
      self.cached = update.value
      os_unfair_lock_unlock(&self.lock)
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

public final class FlatStoreCachingRef<Element : FlatStoreObjectType>: Hashable {

  public static func == (lhs: FlatStoreCachingRef<Element>, rhs: FlatStoreCachingRef<Element>) -> Bool {
    return lhs.identifier == rhs.identifier
  }

  // MARK: - Properties

  public func hash(into hasher: inout Hasher) {
    hasher.combine(identifier)
  }

  private var lock = os_unfair_lock_s()

  public weak var store: FlatStore?

  public let identifier: FlatStoreObjectIdentifier<Element>

  public var cached: Element {
    os_unfair_lock_lock(&lock); defer { os_unfair_lock_unlock(&lock) }
    return _cached
  }

  public var isDeleted: Bool = false

  public var isLiving: Bool {
    return store != nil
  }

  private var _cached: Element

  private var token: NotificationTokenType?

  // MARK: - Initializers

  init(key: FlatStoreObjectIdentifier<Element>, in store: FlatStore, cached: Element) {
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
      os_unfair_lock_lock(&self.lock)
      self._cached = value
      os_unfair_lock_unlock(&self.lock)
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

  public func asFlatRef() -> FlatStoreRef<Element>? {

    guard let store = store else { return nil }

    return FlatStoreRef.init(key: identifier, in: store, cached: nil)

  }

}
