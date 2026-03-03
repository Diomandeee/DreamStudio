import SwiftUI
import ComposableArchitecture

// MARK: - Provider Settings View

struct ProviderSettingsView: View {
    @Bindable var store: StoreOf<ProviderFeature>

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Default Provider
                Section("Default Provider") {
                    Picker("Primary Provider", selection: $store.selectedVendor.sending(\.vendorSelected)) {
                        ForEach(DreamLLMVendor.allCases) { vendor in
                            HStack {
                                Image(systemName: iconForVendor(vendor))
                                Text(vendor.displayName)
                            }
                            .tag(vendor)
                        }
                    }
                }

                // MARK: - Gemini
                Section {
                    SecureField("API Key", text: Binding(
                        get: { store.settings.geminiKey ?? "" },
                        set: { store.send(.geminiKeyChanged($0)) }
                    ))
                    .textContentType(.password)
                    .autocorrectionDisabled()

                    TextField("Model (default: \(DreamLLMVendor.gemini.defaultModel))", text: Binding(
                        get: { store.settings.geminiModel ?? "" },
                        set: { store.send(.geminiModelChanged($0)) }
                    ))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    configuredBadge(store.settings.isConfigured(.gemini))
                } header: {
                    Label("Gemini (Google)", systemImage: "sparkle")
                } footer: {
                    Text("Primary provider. Also used for Imagen 4.0 image generation.")
                }

                // MARK: - Anthropic
                Section {
                    SecureField("API Key", text: Binding(
                        get: { store.settings.anthropicKey ?? "" },
                        set: { store.send(.anthropicKeyChanged($0)) }
                    ))
                    .textContentType(.password)
                    .autocorrectionDisabled()

                    TextField("Model (default: \(DreamLLMVendor.anthropic.defaultModel))", text: Binding(
                        get: { store.settings.anthropicModel ?? "" },
                        set: { store.send(.anthropicModelChanged($0)) }
                    ))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    configuredBadge(store.settings.isConfigured(.anthropic))
                } header: {
                    Label("Claude (Anthropic)", systemImage: "brain.head.profile")
                }

                // MARK: - OpenAI
                Section {
                    SecureField("API Key", text: Binding(
                        get: { store.settings.openaiKey ?? "" },
                        set: { store.send(.openaiKeyChanged($0)) }
                    ))
                    .textContentType(.password)
                    .autocorrectionDisabled()

                    TextField("Model (default: \(DreamLLMVendor.openai.defaultModel))", text: Binding(
                        get: { store.settings.openaiModel ?? "" },
                        set: { store.send(.openaiModelChanged($0)) }
                    ))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    configuredBadge(store.settings.isConfigured(.openai))
                } header: {
                    Label("GPT (OpenAI)", systemImage: "bubble.left.and.bubble.right")
                }

                // MARK: - Groq
                Section {
                    SecureField("API Key", text: Binding(
                        get: { store.settings.groqKey ?? "" },
                        set: { store.send(.groqKeyChanged($0)) }
                    ))
                    .textContentType(.password)
                    .autocorrectionDisabled()

                    TextField("Model (default: \(DreamLLMVendor.groq.defaultModel))", text: Binding(
                        get: { store.settings.groqModel ?? "" },
                        set: { store.send(.groqModelChanged($0)) }
                    ))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                    configuredBadge(store.settings.isConfigured(.groq))
                } header: {
                    Label("Llama (Groq)", systemImage: "bolt")
                } footer: {
                    Text("OpenAI-compatible API for fast inference.")
                }

                // MARK: - Fallback Info
                Section {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        VStack(alignment: .leading) {
                            Text("Automatic Fallback")
                                .font(.subheadline.bold())
                            Text("If the primary provider fails, Dream Studio will automatically try the next configured provider.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    let available = store.settings.availableProviders
                    if available.isEmpty {
                        Label("No providers configured", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else {
                        ForEach(Array(available.enumerated()), id: \.element) { index, vendor in
                            HStack {
                                Text("\(index + 1).")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                Image(systemName: iconForVendor(vendor))
                                Text(vendor.displayName)
                                Spacer()
                                if vendor == store.settings.vendor {
                                    Text("Primary")
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.2))
                                        .foregroundStyle(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                } header: {
                    Text("Provider Priority")
                }
            }
            .navigationTitle("AI Providers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        store.send(.dismiss)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.send(.save)
                    }
                    .bold()
                }
            }
        }
    }

    private func configuredBadge(_ isConfigured: Bool) -> some View {
        HStack {
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isConfigured ? .green : .secondary)
            Text(isConfigured ? "Configured" : "Not configured")
                .foregroundStyle(isConfigured ? .primary : .secondary)
        }
        .font(.caption)
    }

    private func iconForVendor(_ vendor: DreamLLMVendor) -> String {
        switch vendor {
        case .gemini:    return "sparkle"
        case .anthropic: return "brain.head.profile"
        case .openai:    return "bubble.left.and.bubble.right"
        case .groq:      return "bolt"
        }
    }
}
