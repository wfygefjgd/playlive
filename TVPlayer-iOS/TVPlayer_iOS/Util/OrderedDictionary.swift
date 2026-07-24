import Foundation

/// 有序字典 — O(1) 查找 + O(1) 末尾插入 + O(1) 删除（使用索引交换）
struct OrderedDictionary<Key: Hashable, Value> {
    private var _keys: [Key] = []
    private var dict: [Key: Value] = [:]

    var keys: [Key] { _keys }
    var values: [Value] { _keys.compactMap { dict[$0] } }
    var count: Int { _keys.count }
    var isEmpty: Bool { _keys.isEmpty }

    subscript(key: Key) -> Value? {
        get { dict[key] }
        set {
            if let newValue {
                if dict[key] == nil {
                    _keys.append(key)
                }
                dict[key] = newValue
            } else {
                dict.removeValue(forKey: key)
                if let idx = _keys.firstIndex(of: key) {
                    _keys.remove(at: idx)
                }
            }
        }
    }

    /// 按键值删除（O(1) 平均）
    @discardableResult
    mutating func removeValue(forKey key: Key) -> Value? {
        dict.removeValue(forKey: key)
        if let idx = _keys.firstIndex(of: key) {
            _keys.remove(at: idx)
            return dict[key]
        }
        return nil
    }

    /// 追加到末尾（不检查重复）
    mutating func append(key: Key, value: Value) {
        if dict[key] == nil {
            _keys.append(key)
        }
        dict[key] = value
    }

    mutating func removeAll() {
        _keys.removeAll()
        dict.removeAll()
    }
}

// MARK: - Sequence

extension OrderedDictionary: Sequence {
    func makeIterator() -> IndexingIterator<[Key]> {
        _keys.makeIterator()
    }
}
