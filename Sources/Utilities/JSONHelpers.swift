import Foundation

enum JSONHelpers {
    static func string(_ dict: [String: Any], keys: [String]) -> String {
        for key in keys {
            if let value = dict[key] as? String, !value.isEmpty {
                return value
            }
        }
        return ""
    }

    static func int(_ dict: [String: Any], keys: [String]) -> Int {
        for key in keys {
            if let value = dict[key] as? Int {
                return value
            }
            if let value = dict[key] as? Double {
                return Int(value)
            }
            if let value = dict[key] as? String, let parsed = Int(value) {
                return parsed
            }
        }
        return 0
    }

    static func double(_ dict: [String: Any], keys: [String]) -> Double {
        for key in keys {
            if let value = dict[key] as? Double {
                return value
            }
            if let value = dict[key] as? Int {
                return Double(value)
            }
            if let value = dict[key] as? String, let parsed = Double(value) {
                return parsed
            }
        }
        return 0
    }

    static func bool(_ dict: [String: Any], keys: [String]) -> Bool {
        for key in keys {
            if let value = dict[key] as? Bool {
                return value
            }
        }
        return false
    }

    static func optionalInt(_ dict: [String: Any], keys: [String]) -> Int? {
        for key in keys {
            if dict[key] == nil { continue }
            if let value = dict[key] as? Int { return value }
            if let value = dict[key] as? Double { return Int(value) }
            if let value = dict[key] as? String, let parsed = Int(value) { return parsed }
        }
        return nil
    }

    static func genres(_ dict: [String: Any]) -> [String] {
        guard let raw = dict["genres"] as? [Any] else { return [] }
        return raw.compactMap { item in
            if let string = item as? String { return string }
            if let object = item as? [String: Any] {
                return string(object, keys: ["name", "title"])
            }
            return nil
        }
    }

    static func dictArray(_ value: Any?) -> [[String: Any]] {
        guard let array = value as? [Any] else { return [] }
        return array.compactMap { $0 as? [String: Any] }
    }

    static func asDict(_ value: Any?) -> [String: Any] {
        value as? [String: Any] ?? [:]
    }
}
