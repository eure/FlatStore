//
//  FlatStore+Identifiable.swift
//  FlatStore
//
//  Created by muukii on 2019/09/23.
//  Copyright © 2019 eure. All rights reserved.
//

import Foundation

@available(iOS 13, *)
extension FlatStoreCachingRef: Identifiable {
  public typealias ID = FlatStoreObjectIdentifier<Element>
}

@available(iOS 13, *)
extension FlatStoreRef: Identifiable {
  public typealias ID = FlatStoreObjectIdentifier<Element>
}

@available(iOS 13, *)
extension FlatStoreObjectIdentifier: Identifiable {
  public typealias ID = T.RawIDType
}
