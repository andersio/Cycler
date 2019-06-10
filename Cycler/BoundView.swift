import SwiftUI
import Combine

public struct BoundView<Entity: ViewModel, Content: View>: View {
    public let content: (StateSnapshot<Entity>) -> Content
    @ObjectBinding private var viewModel: Entity

    public init(
        _ viewModel: Entity,
        @ViewBuilder content: @escaping (StateSnapshot<Entity>) -> Content
    ) {
        self.viewModel = viewModel
        self.content = content
    }

    public var body: some View {
        return content(
            StateSnapshot(state: viewModel.state, entity: viewModel)
        )
    }
}

/// A snapshot of the state of the view model bound with a `BoundView`.
///
/// `StateSnapshot` forwards read accesses via the dot syntax to all properties of `state`. Bindings
/// with writable properties of `state` can be constructed using `subscript(_:)` or `binding(for:)`.
/// UI callbacks can flow back to the view model via `perform(_:)`.
///
/// - important: The state contained in the snapshot never changes regardless of use of bindings or
///              `perform(_:)`. These actions and mutations are delivered to the view model, which
///              may change the state, leading to a new view update pass.
@dynamicMemberLookup
public struct StateSnapshot<Entity: ViewModel> {
    public let state: Entity.State
    public weak var entity: Entity?

    public init(state: Entity.State, entity: Entity) {
        self.state = state
        self.entity = entity
    }

    public func perform(_ action: Entity.Action) {
        entity?.perform(action)
    }

    public subscript<U>(dynamicMember keyPath: KeyPath<Entity.State, U>) -> U {
        get { return state[keyPath: keyPath] }
    }

    public subscript<U>(keyPath: WritableKeyPath<Entity.State, U>) -> Binding<U> {
        return binding(for: keyPath)
    }

    public func binding<U>(for keyPath: WritableKeyPath<Entity.State, U>) -> Binding<U> {
        return Binding(
            getValue: { self.state[keyPath: keyPath] },
            setValue: { self.entity?.update($0, for: keyPath) }
        )
    }
}
