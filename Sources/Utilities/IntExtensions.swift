import Foundation

extension Int {
    func nonzeroOr(_ fallback: Int) -> Int {
        self == 0 ? fallback : self
    }
}
