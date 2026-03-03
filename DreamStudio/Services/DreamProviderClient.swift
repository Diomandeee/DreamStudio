import Foundation
import ComposableArchitecture

// MARK: - Completion Types

struct CompletionParams: Equatable, Sendable {
    let systemPrompt: String
    let userPrompt: String
    var maxTokens: Int = 4096
    var settings: DreamPromptSettings = .json
}

struct CompletionResult: Equatable, Sendable {
    let content: String
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var usedVendor: DreamLLMVendor?
}

// MARK: - Dream Provider Client

@DependencyClient
struct DreamProviderClient: Sendable {
    /// Complete a prompt using a specific vendor
    var complete: @Sendable (DreamLLMVendor, CompletionParams, DreamProviderSettings) async throws -> CompletionResult

    /// Complete with automatic fallback rotation across configured providers
    var completeWithFallback: @Sendable (CompletionParams, DreamProviderSettings, DreamLLMVendor?) async throws -> CompletionResult
}

// MARK: - DependencyKey

extension DreamProviderClient: DependencyKey {
    static let liveValue: DreamProviderClient = {
        let session = URLSession.shared

        @Sendable
        func completeGemini(
            params: CompletionParams,
            settings: DreamProviderSettings
        ) async throws -> CompletionResult {
            guard let apiKey = settings.geminiKey, !apiKey.isEmpty else {
                throw DreamProviderError.noAPIKey(.gemini)
            }
            let model = settings.model(for: .gemini)
            let endpoint = "\(DreamLLMVendor.gemini.endpoint)/\(model):generateContent?key=\(apiKey)"

            guard let url = URL(string: endpoint) else {
                throw DreamProviderError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "contents": [
                    [
                        "role": "user",
                        "parts": [["text": "\(params.systemPrompt)\n\n\(params.userPrompt)"]]
                    ]
                ],
                "generationConfig": [
                    "maxOutputTokens": params.maxTokens,
                    "temperature": params.settings.temperature,
                    "stopSequences": params.settings.stop ?? []
                ]
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DreamProviderError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw DreamProviderError.apiError(.gemini, httpResponse.statusCode, errorBody)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let text = parts.first?["text"] as? String else {
                throw DreamProviderError.parseError("Failed to parse Gemini response")
            }

            var inputTokens = 0
            var outputTokens = 0
            if let usage = json["usageMetadata"] as? [String: Any] {
                inputTokens = usage["promptTokenCount"] as? Int ?? 0
                outputTokens = usage["candidatesTokenCount"] as? Int ?? 0
            }

            return CompletionResult(
                content: text,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                usedVendor: .gemini
            )
        }

        @Sendable
        func completeAnthropic(
            params: CompletionParams,
            settings: DreamProviderSettings
        ) async throws -> CompletionResult {
            guard let apiKey = settings.anthropicKey, !apiKey.isEmpty else {
                throw DreamProviderError.noAPIKey(.anthropic)
            }
            let model = settings.model(for: .anthropic)

            guard let url = URL(string: DreamLLMVendor.anthropic.endpoint) else {
                throw DreamProviderError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            let body: [String: Any] = [
                "model": model,
                "max_tokens": params.maxTokens,
                "temperature": params.settings.temperature,
                "system": params.systemPrompt,
                "messages": [
                    ["role": "user", "content": params.userPrompt]
                ]
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DreamProviderError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw DreamProviderError.apiError(.anthropic, httpResponse.statusCode, errorBody)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let contentArray = json["content"] as? [[String: Any]],
                  let firstContent = contentArray.first,
                  let text = firstContent["text"] as? String else {
                throw DreamProviderError.parseError("Failed to parse Anthropic response")
            }

            var inputTokens = 0
            var outputTokens = 0
            if let usage = json["usage"] as? [String: Any] {
                inputTokens = usage["input_tokens"] as? Int ?? 0
                outputTokens = usage["output_tokens"] as? Int ?? 0
            }

            return CompletionResult(
                content: text,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                usedVendor: .anthropic
            )
        }

        @Sendable
        func completeOpenAICompatible(
            vendor: DreamLLMVendor,
            params: CompletionParams,
            settings: DreamProviderSettings
        ) async throws -> CompletionResult {
            guard let apiKey = settings.apiKey(for: vendor), !apiKey.isEmpty else {
                throw DreamProviderError.noAPIKey(vendor)
            }
            let model = settings.model(for: vendor)

            guard let url = URL(string: vendor.endpoint) else {
                throw DreamProviderError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            var bodyDict: [String: Any] = [
                "model": model,
                "max_tokens": params.maxTokens,
                "temperature": params.settings.temperature,
                "frequency_penalty": params.settings.frequencyPenalty,
                "presence_penalty": params.settings.presencePenalty,
                "messages": [
                    ["role": "system", "content": params.systemPrompt],
                    ["role": "user", "content": params.userPrompt]
                ]
            ]

            if let stop = params.settings.stop, !stop.isEmpty {
                bodyDict["stop"] = stop
            }

            request.httpBody = try JSONSerialization.data(withJSONObject: bodyDict)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DreamProviderError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw DreamProviderError.apiError(vendor, httpResponse.statusCode, errorBody)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let text = message["content"] as? String else {
                throw DreamProviderError.parseError("Failed to parse \(vendor.displayName) response")
            }

            var inputTokens = 0
            var outputTokens = 0
            if let usage = json["usage"] as? [String: Any] {
                inputTokens = usage["prompt_tokens"] as? Int ?? 0
                outputTokens = usage["completion_tokens"] as? Int ?? 0
            }

            return CompletionResult(
                content: text,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                usedVendor: vendor
            )
        }

        @Sendable
        func completeVendor(
            vendor: DreamLLMVendor,
            params: CompletionParams,
            settings: DreamProviderSettings
        ) async throws -> CompletionResult {
            switch vendor {
            case .gemini:
                return try await completeGemini(params: params, settings: settings)
            case .anthropic:
                return try await completeAnthropic(params: params, settings: settings)
            case .openai, .groq:
                return try await completeOpenAICompatible(vendor: vendor, params: params, settings: settings)
            }
        }

        return DreamProviderClient(
            complete: { vendor, params, settings in
                try await completeVendor(vendor: vendor, params: params, settings: settings)
            },
            completeWithFallback: { params, settings, preferredVendor in
                let available = settings.availableProviders
                guard !available.isEmpty else {
                    throw DreamProviderError.noProvidersConfigured
                }

                // Build provider order: preferred first, then by priority
                var providerOrder: [DreamLLMVendor] = []
                if let preferred = preferredVendor, available.contains(preferred) {
                    providerOrder.append(preferred)
                }
                for vendor in DreamLLMVendor.priority {
                    if available.contains(vendor) && !providerOrder.contains(vendor) {
                        providerOrder.append(vendor)
                    }
                }

                var errors: [(DreamLLMVendor, String)] = []

                for vendor in providerOrder {
                    do {
                        return try await completeVendor(vendor: vendor, params: params, settings: settings)
                    } catch {
                        errors.append((vendor, error.localizedDescription))
                    }
                }

                let summary = errors.map { "\($0.0.rawValue): \($0.1)" }.joined(separator: "; ")
                throw DreamProviderError.allProvidersFailed(summary)
            }
        )
    }()

    static let testValue = DreamProviderClient(
        complete: { _, _, _ in
            CompletionResult(content: "Test response", inputTokens: 10, outputTokens: 20, usedVendor: .gemini)
        },
        completeWithFallback: { _, _, _ in
            CompletionResult(content: "Test response", inputTokens: 10, outputTokens: 20, usedVendor: .gemini)
        }
    )
}

extension DependencyValues {
    var dreamProvider: DreamProviderClient {
        get { self[DreamProviderClient.self] }
        set { self[DreamProviderClient.self] = newValue }
    }
}

// MARK: - Errors

enum DreamProviderError: LocalizedError, Equatable {
    case noAPIKey(DreamLLMVendor)
    case noProvidersConfigured
    case invalidURL
    case invalidResponse
    case apiError(DreamLLMVendor, Int, String)
    case parseError(String)
    case allProvidersFailed(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey(let vendor):
            return "\(vendor.displayName) API key not configured"
        case .noProvidersConfigured:
            return "No AI providers configured. Please add an API key in Settings."
        case .invalidURL:
            return "Invalid API endpoint URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .apiError(let vendor, let code, let message):
            return "\(vendor.displayName) API error (\(code)): \(message)"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .allProvidersFailed(let summary):
            return "All providers failed: \(summary)"
        }
    }
}
