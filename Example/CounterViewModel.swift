import Combine

final class CounterViewModel: FeedbackViewModel<CounterViewModel.State, Never, CounterViewModel.Action>, CounterViewModelProtocol {
    struct State {
        fileprivate(set) var currentCount: Int
        var increment: Int = 1
        var format: String = "%d"

        var displayText: String {
            return String(format: format, currentCount)
        }
    }

    init() {
        super.init(
            initial: State(currentCount: 10, increment: 1),
            reduce: { state, input in
                switch input {
                case .updated:
                    break
                case .action(.plus):
                    state.currentCount += state.increment
                case .action(.minus):
                    state.currentCount -= state.increment
                }
            },
            feedbacks: []
        )
    }

    public enum Action {
        case plus
        case minus
    }
}
