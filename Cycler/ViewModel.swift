import SwiftUI
import Combine

public protocol ViewModel: BindableObject {
    associatedtype State
    associatedtype Action

    var state: State { get }

    func perform(_ action: Action)
    func update<U>(_ value: U, for keyPath: WritableKeyPath<State, U>)
}
