import SwiftUI

public protocol ViewModel: ObservableObject {
    associatedtype S
    associatedtype A

    var state: S { get }

    func perform(_ action: A)
    func update<U>(_ value: U, for keyPath: WritableKeyPath<S, U>)
}
