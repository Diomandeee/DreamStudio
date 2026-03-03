import ComposableArchitecture
import Foundation

// MARK: - Canvas Feature

@Reducer
struct CanvasFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        var html: String
        var script: String
        var title: String
        var isLoading: Bool = true
        var error: String?
        var isFullScreen: Bool = false

        /// Assembled full HTML document with script injected
        var assembledHTML: String {
            guard !html.isEmpty else { return "" }

            var fullHTML = html

            // Inject script before </body> if script exists
            if !script.isEmpty {
                let scriptTag = "<script>\n\(script)\n</script>"
                if let bodyEnd = fullHTML.range(of: "</body>", options: .caseInsensitive) {
                    fullHTML.insert(contentsOf: "\n\(scriptTag)\n", at: bodyEnd.lowerBound)
                } else {
                    fullHTML.append("\n\(scriptTag)")
                }
            }

            return fullHTML
        }
    }

    enum Action: Sendable {
        case onAppear
        case webViewLoaded
        case webViewFailed(String)
        case toggleFullScreen
        case dismiss
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                return .none

            case .webViewLoaded:
                state.isLoading = false
                state.error = nil
                return .none

            case .webViewFailed(let error):
                state.isLoading = false
                state.error = error
                return .none

            case .toggleFullScreen:
                state.isFullScreen.toggle()
                return .none

            case .dismiss:
                return .none
            }
        }
    }
}
