import Foundation

struct OrderedDictionary<Key: Hashable, Value> {
    private var _keys: [Key] = []
    private var dict: [Key: Value] = [:]

    var keys: [Key] { _keys }
    var values: [Value] { _keys.compactMap { dict[$0] } }

    subscript(key: Key) -> Value? {
        get { dict[key] }
        set {
            if newValue == nil {
                dict.removeValue(forKey: key)
                _keys.removeAll { $0 == key }
            } else if dict[key] == nil {
                _keys.append(key)
                dict[key] = newValue
            } else {
                dict[key] = newValue
            }
        }
    }
}
