import Combine

extension FeedbackLoop {
    public struct Feedback {
        public let effects: (AnyPublisher<Output, Never>) -> AnyPublisher<E, Never>

        public init(
            effects: @escaping (AnyPublisher<Output, Never>) -> AnyPublisher<E, Never>
        ) {
            self.effects = { effects($0) }
        }

        /// Creates a Feedback which re-evaluates the given effect every time the
        /// state changes, and the transform consequentially yields a new value
        /// distinct from the last yielded value.
        ///
        /// If the previous effect is still alive when a new one is about to start,
        /// the previous one would automatically be cancelled.
        ///
        /// - parameters:
        ///   - transform: The transform to apply on the state.
        ///   - effecs: The side effect accepting transformed values produced by
        ///              `transform` and yielding events that eventually affect
        ///              the state.
        public static func skippingRepeated<U: Equatable, Events: Publisher>(
            _ transform: @escaping (Output) -> U?,
            effect: @escaping (U) -> Events
        ) -> Feedback where Events.Output == E, Events.Failure == Never {
            return Feedback { output -> AnyPublisher<E, Never> in
                return output
                    .map(transform)
                    .removeDuplicates()
                    .map { $0.map(effect)?.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher() }
                    .switchToLatest()
                    .eraseToAnyPublisher()
            }
        }

        public static func positiveEdgeTrigger<Events: Publisher>(
            _ predicate: @escaping (Output) -> Bool,
            effect: @escaping (Output) -> Events
        ) -> Feedback where Events.Output == E, Events.Failure == Never {
            return Feedback { output -> AnyPublisher<E, Never> in
                var last = false

                return output
                    .compactMap { output -> AnyPublisher<E, Never>? in
                        let current = predicate(output)
                        defer { last = current }

                        switch (last, current) {
                        case (false, true):
                            return effect(output).eraseToAnyPublisher()
                        case (true, false):
                            return Empty().eraseToAnyPublisher()
                        case (false, false), (true, true):
                            return nil
                        }
                    }
                    .switchToLatest()
                    .eraseToAnyPublisher()
            }
        }

        public static func systemBootstrapped<Events: Publisher>(
            effect: @escaping () -> Events
        ) -> Feedback where Events.Output == E, Events.Failure == Never {
            return Feedback { output -> AnyPublisher<E, Never> in
                return output
                    .filter { $0.input == nil }
                    .first()
                    .flatMap { _ in effect() }
                    .eraseToAnyPublisher()
            }
        }
    }
}
