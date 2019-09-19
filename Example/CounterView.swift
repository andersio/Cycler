import SwiftUI
import Combine

protocol CounterViewModelProtocol: ViewModel
    where State == CounterViewModel.State,
          Action == CounterViewModel.Action {}

enum ViewLibrary {
    static func counter<ViewModel: CounterViewModelProtocol>(_ vm: ViewModel) -> some View {
        return BoundView(vm) { (state: StateSnapshot<ViewModel>) in
            VStack {
                VStack {
                    Text(state.displayText)
                        .font(.largeTitle)
                        .padding()
                    HStack {
                        Spacer()
                        Button(
                            action: { state.perform(.minus) },
                            label: { Image(systemName: "minus.circle") }
                        )
                        Spacer()
                        Button(
                            action: { state.perform(.plus) },
                            label: { Image(systemName: "plus.circle") }
                        )
                        Spacer()
                    }.padding()
                }

                List {
                    Section(header: Text("Settings")) {
                        Stepper(
                            value: state.binding(for: \.increment),
                            in: 1 ... 10,
                            label: {
                                Text("Increment: \(state.increment)")
                            }
                        )
                        HStack {
                            Text("Format")
                            TextField(
                                "%d",
                                text: state.binding(for: \.format),
                                onEditingChanged: { _ in },
                                onCommit: {}
                            )
                            .multilineTextAlignment(.trailing)
                        }

                        HStack {
                            Text("Last loaded")
                            Spacer()
                            Text((state.lastLoaded.map { "\($0)" } ?? "Never") as String)
                                .multilineTextAlignment(.trailing)
                        }

                        Button(
                            action: { state.perform(.pressedStart) },
                            label: { Text("Refresh") }
                        )
                    }
                }
            }
        }
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ViewLibrary.counter(MockCounterCycle(
            CounterViewModel.State(currentCount: 10, increment: 1)
        ))
    }
}

final class MockCounterCycle: CounterViewModelProtocol {
    var state: CounterViewModel.State
    let didChange: PassthroughSubject<Void, Never>

    init(_ value: CounterViewModel.State) {
        state = value
        didChange = PassthroughSubject()
    }

    func perform(_ action: CounterViewModel.Action) {}
    func update<U>(_ value: U, for keyPath: WritableKeyPath<CounterViewModel.State, U>) {}
}
#endif
