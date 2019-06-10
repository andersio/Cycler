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

    @StatePublished public var state: State

    public let didChange: PassthroughSubject<Void, Never>
    private let outputSubject: CurrentValueSubject<Output, Never>
    private let reduce: (inout State, Input) -> Void

    public init(
        initial: State,
        reduce: @escaping (inout State, Input) -> Void,
        feedbacks: [Feedback] = []
    ) {
        self.reduce = reduce
        self.didChange = PassthroughSubject()
        self.outputSubject = CurrentValueSubject(Output(state: initial, input: nil))
        self.$state = .init(subject: outputSubject)

        _ = Publishers.MergeMany(
            feedbacks.map { $0.effects(AnyPublisher(outputSubject)) }
        )
        .sink { [weak self] event in
            guard let self = self else { return }
            self.process(.event(event)) { _ in }
        }
    }

    deinit {
        outputSubject.send(completion: .finished)
        didChange.send(completion: .finished)
    }

    public func perform(_ action: Action) {
        process(.action(action)) { _ in }
    }

    public func update<U>(_ value: U, for keyPath: WritableKeyPath<State, U>) {
        process(.updated(keyPath)) {
            $0[keyPath: keyPath] = value
        }
    }

    private func process(_ input: Input, willReduce: (inout State) -> Void) {
        mainThreadAssertion()

        var state = outputSubject.value.state
        willReduce(&state)
        reduce(&state, input)
        outputSubject.value = Output(state: state, input: input)
        didChange.send(())
    }

    @propertyDelegate
    public struct StatePublished {
        public var value: State {
            _read { yield subject.value.state }
        }

        public var publisher: AnyPublisher<State, Never> {
            return subject.map { $0.state }.eraseToAnyPublisher()
        }

        private let subject: CurrentValueSubject<Output, Never>

        fileprivate init(subject: CurrentValueSubject<Output, Never>) {
            self.subject = subject
        }
    }
}

private func mainThreadAssertion() {
    dispatchPrecondition(condition: .onQueue(.main))
}
