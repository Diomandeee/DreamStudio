import Foundation

// MARK: - Template Category

enum TemplateCategory: String, Codable, CaseIterable, Sendable, Identifiable {
    case app
    case game
    case dashboard
    case story
    case canvas

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .app:       return "Interactive App"
        case .game:      return "Game"
        case .dashboard: return "Dashboard"
        case .story:     return "Story"
        case .canvas:    return "Canvas"
        }
    }

    var systemImage: String {
        switch self {
        case .app:       return "iphone"
        case .game:      return "gamecontroller"
        case .dashboard: return "chart.bar"
        case .story:     return "book"
        case .canvas:    return "paintpalette"
        }
    }
}

// MARK: - Dream Template

struct DreamTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let description: String
    let category: TemplateCategory
    let systemImage: String
    let baseHTML: String
    let suggestedLibraries: [String]
    let examplePrompts: [String]
    let defaults: TemplateDefaults

    struct TemplateDefaults: Equatable, Sendable {
        let thinkingLevel: DreamThinkingLevel
        let maxTokens: Int
    }
}

// MARK: - Template Registry

enum DreamTemplates {
    static let all: [DreamTemplate] = [app, game, dashboard, story, canvas]

    static func template(for id: String) -> DreamTemplate? {
        all.first { $0.id == id }
    }

    static func templates(for category: TemplateCategory) -> [DreamTemplate] {
        all.filter { $0.category == category }
    }

    static func randomPrompt() -> (templateID: String, prompt: String) {
        let template = all.randomElement() ?? app
        let prompt = template.examplePrompts.randomElement() ?? ""
        return (template.id, prompt)
    }

    // MARK: - App Template

    static let app = DreamTemplate(
        id: "app",
        name: "Interactive App",
        description: "Build interactive tools, utilities, and productivity apps with forms and user input.",
        category: .app,
        systemImage: "iphone",
        baseHTML: """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>{{title}}</title>
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="min-h-screen bg-gradient-to-br from-slate-900 via-purple-900 to-slate-900">
          <div class="container mx-auto px-4 py-8">
            <header class="text-center mb-12">
              <h1 class="text-4xl font-bold text-white mb-2">{{title}}</h1>
              <p class="text-gray-400">{{description}}</p>
            </header>
            <main class="max-w-2xl mx-auto">{{semantic_blocks}}</main>
            <footer class="text-center mt-16 text-gray-500 text-sm"><p>Generated with Dream</p></footer>
          </div>
        </body>
        </html>
        """,
        suggestedLibraries: ["jQuery", "Lodash", "Chart.js"],
        examplePrompts: [
            "Create a pomodoro timer with customizable work and break intervals",
            "Build a unit converter for length, weight, and temperature",
            "Make a markdown editor with live preview",
            "Create a color palette generator with export options",
            "Build a password strength checker with suggestions",
        ],
        defaults: .init(thinkingLevel: .medium, maxTokens: 8192)
    )

    // MARK: - Game Template

    static let game = DreamTemplate(
        id: "game",
        name: "Interactive Game",
        description: "Create browser games with canvas graphics, animations, and sound effects.",
        category: .game,
        systemImage: "gamecontroller",
        baseHTML: """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>{{title}}</title>
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="min-h-screen bg-gray-900 text-white overflow-hidden">
          <div class="flex flex-col items-center justify-center min-h-screen p-4">
            <header class="text-center mb-6">
              <h1 class="text-2xl text-purple-400 mb-2">{{title}}</h1>
              <div id="score" class="text-lg text-gray-400">Score: <span id="scoreValue">0</span></div>
            </header>
            <div class="relative">
              <canvas id="gameCanvas" width="800" height="600"></canvas>
            </div>
            <footer class="mt-8 text-center text-gray-500 text-sm">{{semantic_blocks}}</footer>
          </div>
        </body>
        </html>
        """,
        suggestedLibraries: ["Three.js", "Tone.js", "GSAP"],
        examplePrompts: [
            "Create a snake game with smooth animations and power-ups",
            "Build a memory matching card game with flip animations",
            "Make a simple platformer with a jumping character",
            "Create a breakout/brick breaker game with physics",
            "Build a rhythm game that reacts to button presses",
        ],
        defaults: .init(thinkingLevel: .high, maxTokens: 12000)
    )

    // MARK: - Dashboard Template

    static let dashboard = DreamTemplate(
        id: "dashboard",
        name: "Data Dashboard",
        description: "Build data visualization dashboards with charts, metrics, and real-time displays.",
        category: .dashboard,
        systemImage: "chart.bar",
        baseHTML: """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>{{title}}</title>
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 text-white">
          <div class="container mx-auto px-4 py-8">
            <header class="mb-8">
              <h1 class="text-3xl font-bold mb-2">{{title}}</h1>
              <p class="text-gray-400">{{description}}</p>
            </header>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8"></div>
            <main>{{semantic_blocks}}</main>
            <footer class="text-center mt-12 text-gray-500 text-sm"><p>Generated with Dream</p></footer>
          </div>
        </body>
        </html>
        """,
        suggestedLibraries: ["Chart.js", "D3.js", "Lodash"],
        examplePrompts: [
            "Create a stock portfolio tracker with live price charts",
            "Build a weather dashboard showing forecasts and historical data",
            "Make a fitness tracker dashboard with workout statistics",
            "Create a social media analytics dashboard with engagement metrics",
            "Build a sales dashboard with revenue trends and KPIs",
        ],
        defaults: .init(thinkingLevel: .medium, maxTokens: 10000)
    )

    // MARK: - Story Template

    static let story = DreamTemplate(
        id: "story",
        name: "Illustrated Story",
        description: "Create illustrated narratives with consistent characters and visual storytelling.",
        category: .story,
        systemImage: "book",
        baseHTML: """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>{{title}}</title>
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="min-h-screen bg-gradient-to-b from-amber-50 to-orange-50 text-gray-800">
          <div class="max-w-4xl mx-auto px-4 py-12">
            <header class="text-center mb-16">
              <h1 class="text-5xl font-bold text-gray-900 mb-4">{{title}}</h1>
              <p class="text-lg text-gray-600 italic">{{description}}</p>
            </header>
            <main class="space-y-16">{{semantic_blocks}}</main>
            <footer class="text-center mt-16 text-gray-400 text-sm"><p>Generated with Dream</p></footer>
          </div>
        </body>
        </html>
        """,
        suggestedLibraries: ["GSAP", "Lodash"],
        examplePrompts: [
            "Create an illustrated fairy tale about a brave little fox",
            "Build an interactive choose-your-own-adventure story",
            "Make a visual poem with animated text and images",
            "Create a children's bedtime story with colorful illustrations",
            "Build a graphic novel style story with panel layouts",
        ],
        defaults: .init(thinkingLevel: .high, maxTokens: 12000)
    )

    // MARK: - Canvas Template

    static let canvas = DreamTemplate(
        id: "canvas",
        name: "Creative Canvas",
        description: "Build drawing tools, generative art, and creative applications with canvas.",
        category: .canvas,
        systemImage: "paintpalette",
        baseHTML: """
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>{{title}}</title>
          <script src="https://cdn.tailwindcss.com"></script>
        </head>
        <body class="min-h-screen bg-gray-900 text-white overflow-hidden">
          <div class="flex h-screen">
            <main class="flex-1 flex flex-col">
              <header class="h-14 bg-gray-800 flex items-center justify-between px-4 border-b border-gray-700">
                <h1 class="font-semibold">{{title}}</h1>
              </header>
              <div class="flex-1 flex items-center justify-center p-4 bg-gray-950">
                <canvas id="canvas" width="800" height="600" class="bg-white"></canvas>
              </div>
              <div class="h-12 bg-gray-800 flex items-center px-4 gap-4 border-t border-gray-700">
                {{semantic_blocks}}
              </div>
            </main>
          </div>
        </body>
        </html>
        """,
        suggestedLibraries: ["Three.js", "Tone.js", "GSAP"],
        examplePrompts: [
            "Create a pixel art drawing tool with layers",
            "Build a generative art canvas that creates patterns from mouse movement",
            "Make a collaborative whiteboard with shape tools",
            "Create a music visualizer that responds to audio input",
            "Build a particle system playground with physics controls",
        ],
        defaults: .init(thinkingLevel: .medium, maxTokens: 10000)
    )
}

// MARK: - Template Processing

extension DreamTemplate {
    /// Process template by replacing placeholders with generated content
    func process(semanticBlocks: String, title: String? = nil, description: String? = nil) -> String {
        var html = baseHTML
        html = html.replacingOccurrences(of: "{{semantic_blocks}}", with: semanticBlocks)
        if let title = title {
            html = html.replacingOccurrences(of: "{{title}}", with: title)
        }
        if let description = description {
            html = html.replacingOccurrences(of: "{{description}}", with: description)
        }
        return html
    }

    /// Build context string for injection into LLM prompts
    func buildContext() -> String {
        """
        Template: \(name)
        Category: \(category.rawValue)
        Description: \(description)
        Suggested Libraries: \(suggestedLibraries.joined(separator: ", "))

        You should generate content that fits this template's structure and purpose.
        Focus on creating \(category.rawValue)-appropriate content with interactivity.
        """
    }
}
