import Combine
import Dispatch
import Foundation

open class FeedbackViewModel<State, Event, Action>: ViewModel {
    public private(set) var state: State {
        willSet {
            mainThreadAssertion()
        }

        didSet {
            feedbackDriver.send(state)
            didChange.send(())
        }
    }

    public let didChange: PassthroughSubject<Void, Never>
    private let feedbackDriver: PassthroughSubject<State, Never>
    private let reduce: (inout State, ReducerInput) -> Void

    public init(
        initial: State,
        reduce: @escaping (inout State, ReducerInput) -> Void,
        feedbacks: [Feedback] = []
    ) {
        self.state = initial
        self.reduce = reduce
        self.didChange = PassthroughSubject()
        self.feedbackDriver = PassthroughSubject()

        _ = Publishers.MergeMany(
            feedbacks.map { $0.effects(feedbackDriver) }
        )
        .sink { [weak self] input in
            guard let self = self else { return }
            reduce(&self.state, input)
        }
    }

    deinit {
        feedbackDriver.send(completion: .finished)
        didChange.send(completion: .finished)
    }

    public enum ReducerInput {
        case event(Event)
        case action(Action)
        case updated
    }

    public func perform(_ action: Action) {
        mainThreadAssertion()
        reduce(&self.state, .action(action))
    }

    public func update<U>(_ value: U, for keyPath: WritableKeyPath<State, U>) {
        mainThreadAssertion()
        self.state[keyPath: keyPath] = value
        reduce(&self.state, .updated)
    }

    public struct Feedback {
        internal let effects: (PassthroughSubject<State, Never>) -> AnyPublisher<ReducerInput, Never>

        public init<Events: Publisher>(
            effects: @escaping (PassthroughSubject<State, Never>) -> Events
        ) where Events.Output == Event, Events.Failure == Never {
            self.effects = { AnyPublisher(effects($0).map(ReducerInput.event)) }
        }
    }
}

private func mainThreadAssertion() {
    guard Thread.isMainThread else {
        fatalError("Main thread only")
    }
}
