import Foundation

// MARK: - Dream Stage

/// The 4-stage generation pipeline + lifecycle states.
/// Maps directly from the TypeScript DreamStage union type.
enum DreamStage: String, Codable, CaseIterable, Sendable, Equatable {
    case idle
    case tasks      // Stage 1: Spec generation from user prompt
    case layout     // Stage 2: HTML + Tailwind CSS layout generation
    case images     // Stage 3: Image generation/resolution via Gemini Imagen
    case script     // Stage 4: JavaScript logic generation
    case rendering  // Assembling final output
    case complete
    case error

    var displayName: String {
        switch self {
        case .idle:      return "Ready"
        case .tasks:     return "Generating Spec"
        case .layout:    return "Building Layout"
        case .images:    return "Creating Images"
        case .script:    return "Writing Script"
        case .rendering: return "Rendering"
        case .complete:  return "Complete"
        case .error:     return "Error"
        }
    }

    var stageNumber: Int? {
        switch self {
        case .tasks:  return 1
        case .layout: return 2
        case .images: return 3
        case .script: return 4
        default:      return nil
        }
    }

    var isActive: Bool {
        switch self {
        case .tasks, .layout, .images, .script, .rendering:
            return true
        default:
            return false
        }
    }

    var progress: Double {
        switch self {
        case .idle:      return 0.0
        case .tasks:     return 0.2
        case .layout:    return 0.4
        case .images:    return 0.6
        case .script:    return 0.8
        case .rendering: return 0.9
        case .complete:  return 1.0
        case .error:     return 0.0
        }
    }

    var systemImage: String {
        switch self {
        case .idle:      return "play.circle"
        case .tasks:     return "list.clipboard"
        case .layout:    return "rectangle.3.group"
        case .images:    return "photo.stack"
        case .script:    return "curlybraces"
        case .rendering: return "gearshape.2"
        case .complete:  return "checkmark.circle.fill"
        case .error:     return "exclamationmark.triangle"
        }
    }
}

// MARK: - Output Type

enum DreamOutputType: String, Codable, CaseIterable, Sendable {
    case webpage
    case artifact
    case hybrid

    var displayName: String {
        switch self {
        case .webpage:  return "Web Page"
        case .artifact: return "Artifact"
        case .hybrid:   return "Hybrid"
        }
    }
}

// MARK: - LLM Vendor

enum DreamLLMVendor: String, Codable, CaseIterable, Sendable, Identifiable {
    case gemini
    case anthropic
    case openai
    case groq

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gemini:    return "Gemini (Google)"
        case .anthropic: return "Claude (Anthropic)"
        case .openai:    return "GPT (OpenAI)"
        case .groq:      return "Llama (Groq)"
        }
    }

    var defaultModel: String {
        switch self {
        case .gemini:    return "gemini-2.5-flash-preview-05-20"
        case .anthropic: return "claude-sonnet-4-20250514"
        case .openai:    return "gpt-4o-2024-11-20"
        case .groq:      return "llama-3.3-70b-versatile"
        }
    }

    var endpoint: String {
        switch self {
        case .gemini:    return "https://generativelanguage.googleapis.com/v1beta/models"
        case .anthropic: return "https://api.anthropic.com/v1/messages"
        case .openai:    return "https://api.openai.com/v1/chat/completions"
        case .groq:      return "https://api.groq.com/openai/v1/chat/completions"
        }
    }

    /// Provider priority for fallback rotation
    static let priority: [DreamLLMVendor] = [.gemini, .anthropic, .openai, .groq]
}

// MARK: - Thinking Level

enum DreamThinkingLevel: String, Codable, CaseIterable, Sendable {
    case minimal
    case low
    case medium
    case high

    var budget: Int {
        switch self {
        case .minimal: return 128
        case .low:     return 512
        case .medium:  return 2048
        case .high:    return 8192
        }
    }

    var displayName: String {
        switch self {
        case .minimal: return "Minimal"
        case .low:     return "Low"
        case .medium:  return "Medium"
        case .high:    return "High"
        }
    }
}

// MARK: - Image Style

enum DreamImageStyle: String, Codable, CaseIterable, Sendable {
    case photorealistic
    case illustration
    case cartoon
    case abstract
    case threeD = "3d-render"
    case watercolor
    case sketch
    case pixelArt = "pixel-art"

    var displayName: String {
        switch self {
        case .photorealistic: return "Photorealistic"
        case .illustration:   return "Illustration"
        case .cartoon:        return "Cartoon"
        case .abstract:       return "Abstract"
        case .threeD:         return "3D Render"
        case .watercolor:     return "Watercolor"
        case .sketch:         return "Sketch"
        case .pixelArt:       return "Pixel Art"
        }
    }

    var promptGuide: String {
        switch self {
        case .photorealistic: return "Create a photorealistic, high-quality photograph."
        case .illustration:   return "Create a clean, modern digital illustration."
        case .cartoon:        return "Create a vibrant cartoon-style illustration."
        case .abstract:       return "Create an abstract artistic interpretation."
        case .threeD:         return "Create a 3D rendered scene with realistic lighting."
        case .watercolor:     return "Create a soft watercolor painting."
        case .sketch:         return "Create a detailed pencil sketch."
        case .pixelArt:       return "Create pixel art in retro game style."
        }
    }
}

// MARK: - Aspect Ratio

enum DreamAspectRatio: String, Codable, CaseIterable, Sendable {
    case square = "1:1"
    case landscape = "16:9"
    case portrait = "9:16"
    case fourThree = "4:3"
    case threeFour = "3:4"

    var dimensions: (width: Int, height: Int) {
        switch self {
        case .square:     return (1024, 1024)
        case .landscape:  return (1280, 720)
        case .portrait:   return (720, 1280)
        case .fourThree:  return (1024, 768)
        case .threeFour:  return (768, 1024)
        }
    }
}
