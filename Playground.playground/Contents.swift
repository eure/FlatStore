import FlatStore

struct Buffer : Identifiable {
  var rawID: String
  var a: String?
  var b: String?
  var c: String?
}

let store = FlatStore()

let b = Buffer(rawID: "a", a: nil, b: nil, c: nil)
store.set(value: b)

store.performBatchUpdates { (store, context) -> Void in
  var b = context.get(by: Identifier<Buffer>.init("a"))!
  b.a = "a"
  context.set(value: b)
}

let __b = store.get(by: Identifier<Buffer>.init("a"))

print(__b)
