//
//  UnfairLock.swift
//  FlatStore
//
//  Created by muukii on 2018/11/15.
//  Copyright © 2018 eure. All rights reserved.
//

import Foundation

import os

final class UnfairLock {
  private var _lock = os_unfair_lock()
  @inline(__always)
  func lock() {
    os_unfair_lock_lock(&_lock)
  }

  @inline(__always)
  func unlock() {
    os_unfair_lock_unlock(&_lock)
  }
}
