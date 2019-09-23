import SwiftUI
import Combine

public struct BoundView<Entity: ViewModel, Content: View>: View {
    public let content: (StateSnapshot<Entity>) -> Content
    @ObservedObject private var viewModel: Entity

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
/// You can access any readable property of `state` by using the dot syntax directly on a
/// `StateSnapshot`. To create bindings with writable properties of the state, use `subscript(_:)` or
/// `binding(for:)`. For other kinds of UI callbacks, define them as an action of your view model, and
/// send them through with `perform(_:)`.
///
/// - important: The state contained in the snapshot **never changes** regardless of the use of bindings
///              or `perform(_:)` with the snapshot. The snapshot funnels actions and mutations back to
///              the view model.
@dynamicMemberLookup
public struct StateSnapshot<Entity: ViewModel> {
    public let state: Entity.ObjectWillChangePublisher
    public weak var entity: Entity?

    public init(state: Entity.S, entity: Entity) {
        self.state = state
        self.entity = entity
    }

    public func perform(_ action: Entity.A) {
        entity?.perform(action)
    }

    public subscript<U>(dynamicMember keyPath: KeyPath<Entity.S, U>) -> U {
        get { return state[keyPath: keyPath] }
    }

    public subscript<U>(keyPath: WritableKeyPath<Entity.S, U>) -> Binding<U> {
        return binding(for: keyPath)
    }

    public func binding<U>(for keyPath: WritableKeyPath<Entity.S, U>) -> Binding<U> {
        return Binding(
            get: { self.state[keyPath: keyPath] },
            set: { self.entity?.update($0, for: keyPath) }
        )
    }
}
