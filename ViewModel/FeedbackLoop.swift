import Combine
import Dispatch
import Foundation

open class FeedbackLoop<State, Event, Action>: ViewModel {
    public enum Input {
        /// A feedback has emitted an event.
        case event(Event)

        /// An API consumer has triggered an action.
        case action(Action)

        /// A publicly writable property of the state has been updated by a value
        /// supplied by an API consumer.
        case updated(PartialKeyPath<State>)
    }

    public struct Output {
        /// The last processed input. `nil` means the system has just been spun up.
        public let input: Input?

        /// The state after having processed `input`.
        public let state: State

        public init(state: State, input: Input?) {
            self.input = input
            self.state = state
        }
    }

    public private(set) var state: State

    public let didChange: PassthroughSubject<Void, Never>
    private let outputSubject: PassthroughSubject<Output, Never>
    private let reduce: (inout State, Input) -> Void

    public init(
        initial: State,
        reduce: @escaping (inout State, Input) -> Void,
        feedbacks: [Feedback] = []
    ) {
        self.state = initial
        self.reduce = reduce
        self.didChange = PassthroughSubject()
        self.outputSubject = PassthroughSubject()

        _ = Publishers.MergeMany(
            feedbacks.map { $0.effects(AnyPublisher(outputSubject)) }
        )
        .sink { [weak self] event in
            guard let self = self else { return }
            self.process(.event(event))
        }

        outputSubject.send(Output(state: initial, input: nil))
    }

    deinit {
        outputSubject.send(completion: .finished)
        didChange.send(completion: .finished)
    }

    public func perform(_ action: Action) {
        mainThreadAssertion()
        process(.action(action))
    }

    public func update<U>(_ value: U, for keyPath: WritableKeyPath<State, U>) {
        mainThreadAssertion()
        self.state[keyPath: keyPath] = value
        process(.updated(keyPath))
    }

    private func process(_ input: Input) {
        reduce(&self.state, input)
        outputSubject.send(Output(state: state, input: input))
        didChange.send(())
    }
}

private func mainThreadAssertion() {
    dispatchPrecondition(condition: .onQueue(.main))
}
