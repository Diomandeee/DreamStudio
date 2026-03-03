import ComposableArchitecture
import Foundation

// MARK: - Provider Feature

@Reducer
struct ProviderFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        var settings: DreamProviderSettings
        var selectedVendor: DreamLLMVendor

        init(settings: DreamProviderSettings = .empty) {
            self.settings = settings
            self.selectedVendor = settings.vendor
        }
    }

    enum Action: Sendable, Equatable {
        case vendorSelected(DreamLLMVendor)
        case anthropicKeyChanged(String)
        case anthropicModelChanged(String)
        case openaiKeyChanged(String)
        case openaiModelChanged(String)
        case groqKeyChanged(String)
        case groqModelChanged(String)
        case geminiKeyChanged(String)
        case geminiModelChanged(String)
        case saveSettings(DreamProviderSettings)
        case save
        case dismiss
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .vendorSelected(let vendor):
                state.selectedVendor = vendor
                state.settings.vendor = vendor
                return .none

            case .anthropicKeyChanged(let key):
                state.settings.anthropicKey = key.isEmpty ? nil : key
                return .none

            case .anthropicModelChanged(let model):
                state.settings.anthropicModel = model.isEmpty ? nil : model
                return .none

            case .openaiKeyChanged(let key):
                state.settings.openaiKey = key.isEmpty ? nil : key
                return .none

            case .openaiModelChanged(let model):
                state.settings.openaiModel = model.isEmpty ? nil : model
                return .none

            case .groqKeyChanged(let key):
                state.settings.groqKey = key.isEmpty ? nil : key
                return .none

            case .groqModelChanged(let model):
                state.settings.groqModel = model.isEmpty ? nil : model
                return .none

            case .geminiKeyChanged(let key):
                state.settings.geminiKey = key.isEmpty ? nil : key
                return .none

            case .geminiModelChanged(let model):
                state.settings.geminiModel = model.isEmpty ? nil : model
                return .none

            case .save:
                return .send(.saveSettings(state.settings))

            case .saveSettings:
                return .none

            case .dismiss:
                return .none
            }
        }
    }
}
