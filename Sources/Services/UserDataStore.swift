import Combine
import Foundation

@MainActor
final class UserDataStore: UserDataSync, ObservableObject {
    let objectWillChange = ObservableObjectPublisher()
    override func didChange() { objectWillChange.send() }
}
