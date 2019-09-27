import Combine
import Dispatch
import Foundation

open class FeedbackLoop<S, E, A>: ViewModel {
    public enum Input {
        /// A feedback has emitted an event.
        case event(E)

        /// An API consumer has triggered an action.
        case action(A)

        /// A publicly writable property of the state has been updated by a value
        /// supplied by an API consumer.
        case updated(PartialKeyPath<S>)
    }

    public struct Output {
        /// The last processed input. `nil` means the system has just been spun up.
        public let input: Input?

        /// The state after having processed `input`.
        public let state: S

        public init(state: S, input: Input?) {
            self.input = input
            self.state = state
        }
    }

    @StatePublished public var state: S

    public let objectWillChange: PassthroughSubject<Void, Never>

    private let outputSubject: CurrentValueSubject<Output, Never>
    private let reduce: (inout S, Input) -> Void

    // NOTE: Beyond initialization, all inputs must be processed on `queue`.
    private let queue: DispatchQueue
    private let specificKey = DispatchSpecificKey<Void>()
    private var disposables = Set<AnyCancellable>()

    public init(
        initial: S,
        reduce: @escaping (inout S, Input) -> Void,
        feedbacks: [Feedback] = [],
        usesMainQueue: Bool = true,
        qos: DispatchQoS = .default
    ) {
        self.reduce = reduce
        self.objectWillChange = PassthroughSubject()
        self.outputSubject = CurrentValueSubject(Output(state: initial, input: nil))
        self._state = .init(subject: outputSubject)
        
        self.queue = usesMainQueue
            ? .main
            : DispatchQueue(
                label: "FeedbackLoop",
                qos: qos,
                attributes: [],
                autoreleaseFrequency: .inherit,
                target: nil
            )

        queue.setSpecific(key: specificKey, value: ())

        Publishers.MergeMany(
            feedbacks.map { $0.effects(AnyPublisher(outputSubject)) }
        )
        .sink { [weak self] event in
            guard let self = self else { return }
            self.process(.event(event)) { _ in }
        }
        .store(in: &disposables)
    }

    deinit {
        outputSubject.send(completion: .finished)
        objectWillChange.send(completion: .finished)
        queue.setSpecific(key: specificKey, value: nil)
    }

    public func perform(_ action: A) {
        process(.action(action)) { _ in }
    }

    public func update<U>(_ value: U, for keyPath: WritableKeyPath<S, U>) {
        process(.updated(keyPath)) {
            $0[keyPath: keyPath] = value
        }
    }

    private func process(_ input: Input, willReduce: @escaping (inout S) -> Void) {
        func execute() {
            var state = outputSubject.value.state
            willReduce(&state)
            reduce(&state, input)
            outputSubject.value = Output(state: state, input: input)
            objectWillChange.send()
        }

        if DispatchQueue.getSpecific(key: specificKey) != nil {
            execute()
        } else {
            queue.async(execute: execute)
        }
    }

    @propertyWrapper
    public struct StatePublished {
        public var wrappedValue: S {
            _read { yield subject.value.state }
        }

        public var publisher: AnyPublisher<S, Never> {
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
