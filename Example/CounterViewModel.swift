import Combine
import Foundation

final class CounterViewModel: FeedbackLoop<CounterViewModel.State, CounterViewModel.Event, CounterViewModel.Action>, CounterViewModelProtocol {
    struct State {
        fileprivate(set) var currentCount: Int
        var increment: Int = 1
        var format: String = "%d"

        var lastLoaded: Date?
        var isLoading: Bool = false

        var displayText: String {
            return String(format: format, currentCount)
        }
    }

    init() {
        super.init(
            initial: State(currentCount: 10, increment: 1),
            reduce: { state, input in
                switch input {
                case let .event(.restoreCount(count)):
                    state.currentCount = count
                case .event(.loaded):
                    state.lastLoaded = Date()
                    state.isLoading = false
                case .updated:
                    break
                case .action(.pressedStart):
                    state.isLoading = true
                case .action(.plus):
                    state.currentCount += state.increment
                case .action(.minus):
                    state.currentCount -= state.increment
                }
            },
            feedbacks: [
                .systemBootstrapped { Just(.restoreCount(100)) },
                .positiveEdgeTrigger({ $0.state.isLoading }) { _ in
                    return Just(.loaded)
                }
            ]
        )
    }

    public enum Event {
        case restoreCount(Int)
        case loaded
    }

    public enum Action {
        case plus
        case minus
        case pressedStart
    }
}
