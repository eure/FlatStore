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

/// A transaction batch updating
public final class FlatBatchUpdatesContext {

//  private let store: FlatStore

  var buffer = InMemoryEntityStorage()
  
  private let store: FlatStore

  public init(store: FlatStore) {
    self.store = store
  }

  public func set<T: FlatStoreObjectType>(value: T) -> FlatStoreObjectIdentifier<T> {
    let key = value.id
    buffer.update(inTable: T.FlatStoreID.tableName) { (table) in
      table.byID[key.id] = value
    }
    return key
  }

  public func set<T : Sequence>(values: T) -> [FlatStoreObjectIdentifier<T.Element>] where T.Element : FlatStoreObjectType {
    
    var ids: [FlatStoreObjectIdentifier<T.Element>] = []
    
    buffer.update(inTable: T.Element.FlatStoreID.tableName) { (table) in
      values.forEach { value in
        table.byID[value.id] = value
        ids.append(value.id)
      }
    }
    
    return ids
  }

  public func get<T: FlatStoreObjectType>(by key: FlatStoreObjectIdentifier<T>) -> T? {
            
    if let transientObject = (buffer.table(name: T.FlatStoreID.tableName)?.byID[key.id] as? T) {
      return transientObject
    }
    if let object = store.get(by: key) {
      return object
    }
    return nil
  }

}
