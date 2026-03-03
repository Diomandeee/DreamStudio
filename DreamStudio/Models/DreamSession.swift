import Foundation

// MARK: - Dream Session

/// Core model for a Dream generation session.
/// Mirrors the TypeScript DreamSession interface from the trajectory search codebase.
struct DreamSession: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var title: String
    var prompt: String
    var outputType: DreamOutputType
    var tasks: [String: String]
    var html: String
    var script: String
    var images: [DreamGeneratedImage]
    var templateID: String?
    var thinkingLevel: DreamThinkingLevel
    var libraries: [String]
    var stage: DreamStage
    var provider: DreamLLMVendor
    var model: String
    var generationCost: DreamGenerationCost?
    var trajectoryContext: TrajectoryContext?
    var isFavorite: Bool
    var tags: [String]
    var createdAt: Date
    var updatedAt: Date
    var deviceID: String?

    enum CodingKeys: String, CodingKey {
        case id, title, prompt, tasks, html, script, images, libraries, stage, provider, model, tags
        case outputType = "output_type"
        case templateID = "template_id"
        case thinkingLevel = "thinking_level"
        case generationCost = "generation_cost"
        case trajectoryContext = "trajectory_context"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deviceID = "device_id"
    }

    /// Create a new session with defaults
    static func create(
        prompt: String,
        outputType: DreamOutputType = .webpage,
        provider: DreamLLMVendor = .gemini,
        templateID: String? = nil,
        thinkingLevel: DreamThinkingLevel = .medium,
        libraries: [String] = []
    ) -> DreamSession {
        let now = Date()
        return DreamSession(
            id: UUID().uuidString,
            title: String(prompt.prefix(100)),
            prompt: prompt,
            outputType: outputType,
            tasks: [:],
            html: "",
            script: "",
            images: [],
            templateID: templateID,
            thinkingLevel: thinkingLevel,
            libraries: libraries,
            stage: .idle,
            provider: provider,
            model: "",
            generationCost: nil,
            trajectoryContext: nil,
            isFavorite: false,
            tags: [],
            createdAt: now,
            updatedAt: now,
            deviceID: nil
        )
    }
}

// MARK: - Dream Summary

/// Lightweight summary for list display.
struct DreamSummary: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let prompt: String
    let outputType: DreamOutputType
    var isFavorite: Bool
    var tags: [String]
    let createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, prompt, tags
        case outputType = "output_type"
        case isFavorite = "is_favorite"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Generated Image

struct DreamGeneratedImage: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let alt: String
    var dataURI: String
    let mimeType: String
    var width: Int?
    var height: Int?
    var metadata: ImageMetadata?

    enum CodingKeys: String, CodingKey {
        case id, alt, mimeType, width, height, metadata
        case dataURI = "dataUri"
    }

    struct ImageMetadata: Codable, Equatable, Sendable {
        let prompt: String
        var style: String?
        var aspectRatio: String?
        let generatedAt: String

        enum CodingKeys: String, CodingKey {
            case prompt, style, generatedAt
            case aspectRatio = "aspectRatio"
        }
    }
}

// MARK: - Generation Cost

struct DreamGenerationCost: Codable, Equatable, Sendable {
    var inputTokens: Int
    var outputTokens: Int
    var thinkingTokens: Int?
    var imageCount: Int?
    var estimatedCostUSD: Double?

    enum CodingKeys: String, CodingKey {
        case inputTokens, outputTokens, thinkingTokens, imageCount
        case estimatedCostUSD = "estimatedCostUsd"
    }

    var totalTokens: Int {
        inputTokens + outputTokens + (thinkingTokens ?? 0)
    }

    static var zero: DreamGenerationCost {
        DreamGenerationCost(inputTokens: 0, outputTokens: 0)
    }

    static func + (lhs: DreamGenerationCost, rhs: DreamGenerationCost) -> DreamGenerationCost {
        DreamGenerationCost(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens,
            thinkingTokens: (lhs.thinkingTokens ?? 0) + (rhs.thinkingTokens ?? 0),
            imageCount: (lhs.imageCount ?? 0) + (rhs.imageCount ?? 0),
            estimatedCostUSD: (lhs.estimatedCostUSD ?? 0) + (rhs.estimatedCostUSD ?? 0)
        )
    }
}

// MARK: - Trajectory Context

struct TrajectoryContext: Codable, Equatable, Sendable {
    var projectID: String?
    var ideaIDs: [String]?
    var relatedTurns: [String]?

    enum CodingKeys: String, CodingKey {
        case projectID = "project_id"
        case ideaIDs = "idea_ids"
        case relatedTurns = "related_turns"
    }
}

// MARK: - Provider Settings

struct DreamProviderSettings: Codable, Equatable, Sendable {
    var vendor: DreamLLMVendor
    var anthropicKey: String?
    var anthropicModel: String?
    var openaiKey: String?
    var openaiModel: String?
    var groqKey: String?
    var groqModel: String?
    var geminiKey: String?
    var geminiModel: String?

    static var empty: DreamProviderSettings {
        DreamProviderSettings(vendor: .gemini)
    }

    /// Check if a given vendor has an API key configured
    func isConfigured(_ vendor: DreamLLMVendor) -> Bool {
        switch vendor {
        case .anthropic: return !(anthropicKey ?? "").isEmpty
        case .openai:    return !(openaiKey ?? "").isEmpty
        case .groq:      return !(groqKey ?? "").isEmpty
        case .gemini:    return !(geminiKey ?? "").isEmpty
        }
    }

    /// Get the API key for a vendor
    func apiKey(for vendor: DreamLLMVendor) -> String? {
        switch vendor {
        case .anthropic: return anthropicKey
        case .openai:    return openaiKey
        case .groq:      return groqKey
        case .gemini:    return geminiKey
        }
    }

    /// Get the model for a vendor, falling back to default
    func model(for vendor: DreamLLMVendor) -> String {
        switch vendor {
        case .anthropic: return anthropicModel ?? vendor.defaultModel
        case .openai:    return openaiModel ?? vendor.defaultModel
        case .groq:      return groqModel ?? vendor.defaultModel
        case .gemini:    return geminiModel ?? vendor.defaultModel
        }
    }

    /// Get list of configured providers in priority order
    var availableProviders: [DreamLLMVendor] {
        DreamLLMVendor.priority.filter { isConfigured($0) }
    }
}

// MARK: - Prompt Settings

struct DreamPromptSettings: Codable, Equatable, Sendable {
    var temperature: Double
    var frequencyPenalty: Double
    var presencePenalty: Double
    var stop: [String]?

    static let json = DreamPromptSettings(temperature: 0.8, frequencyPenalty: 0, presencePenalty: 0)
    static let html = DreamPromptSettings(temperature: 0.8, frequencyPenalty: 0, presencePenalty: 0, stop: ["<script"])
    static let script = DreamPromptSettings(temperature: 0.7, frequencyPenalty: 0, presencePenalty: 0, stop: ["</script>"])
}
