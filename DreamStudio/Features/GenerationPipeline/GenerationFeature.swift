import ComposableArchitecture
import Foundation

// MARK: - Prompt Engine

/// Prompt generation functions ported from the TypeScript prompts.ts
enum DreamPromptEngine {
    /// Stage 1: Generate the tasks/spec prompt
    static func tasksPrompt(query: String, trajectoryContext: String? = nil) -> String {
        let contextSection = trajectoryContext.map {
            "\nContext from your personal trajectory:\n\($0)\n"
        } ?? ""

        return """
        You are a senior creative engineer who designs interactive web experiences, visualizations, and creative artifacts.
        You are not going to code it yourself, instead you will write a valid spec of the creation, in the form of JSON instructions.

        \(contextSection)
        Here are some examples, but don't copy them verbatim! Adapt to the creative brief!

        Brief: A back office application to help hot-dog stand business owners to manage stock
        Spec: {
          "summary": "Back-office application to manage stocks for a hot-dog stand",
          "layout": "An application layout with a top navigation bar, a left menu to access app areas, and a central content section",
          "art direction": "The design has nods to hot-dogs (eg. use of orange, grey for the color), large text, use of funny emojis",
          "text content": "Text should be straight to the point, it contains labels, buttons and links to execute various of the application",
          "content": "There is a table with editable cells, one line per type of ingredient: bread, sausage, mustard, etc.",
          "interactivity": "There is an input text where we can enter the number of expected customers, and JS code to automatically adjust items to order",
          "js modules": "vanilla JS only",
          "images": "no image needed"
        }

        Brief: A creative visualization of a thought in motion
        Spec: {
          "summary": "Abstract visualization of thought emergence and connection",
          "layout": "Full-screen canvas with floating elements and particle systems",
          "art direction": "Deep space aesthetic with gradients from deep purple to cyan, glowing nodes",
          "text content": "Minimal text - perhaps a single word or phrase that emerges with the thought",
          "interactivity": "Mouse movement influences particle flow, clicks spawn new thought nodes",
          "js modules": "vanilla JS with canvas API",
          "images": "no images, all generated via canvas",
          "animations": "Continuous gentle motion, nodes pulse softly"
        }

        Real work is starting now. Remember, you MUST respect the creative brief carefully!

        Brief: \(query)
        Spec: {
        """
    }

    /// Stage 2: Generate the layout/HTML prompt from a spec
    static func layoutPrompt(instructions: [String: String]) -> String {
        let summary = instructions["summary"] ?? ""
        let layout = instructions["layout"] ?? ""
        let style = instructions["art direction"] ?? ""
        let textContent = instructions["text content"] ?? ""
        let content = instructions["content"] ?? ""
        let images = instructions["images"] ?? ""

        return """
        You are a frontend engineer creating HTML with Tailwind CSS.
        Generate a complete, self-contained HTML document based on the following specification.

        RULES:
        - Use Tailwind CSS classes for all styling (loaded via CDN in the template)
        - Create realistic, rich content - never use "lorem ipsum" or placeholder text
        - For images, use descriptive alt text but leave src empty (src="")
        - Make the design beautiful and polished
        - Use semantic HTML5 elements
        - Include the Tailwind CDN: <script src="https://cdn.tailwindcss.com"></script>

        SPECIFICATION:
        Summary: \(summary)
        Layout: \(layout)
        Art Direction: \(style)
        Text Content Guidelines: \(textContent)
        Main Content: \(content)
        Image Notes: \(images)

        Generate a complete HTML document starting with <!DOCTYPE html>. Make it production-ready and visually stunning.

        HTML:
        """
    }

    /// Stage 4: Generate the script prompt for interactivity
    static func scriptPrompt(instructions: [String: String], html: String) -> String {
        let interactivity = instructions["interactivity"] ?? ""
        let mouseEvents = instructions["mouse events"] ?? ""
        let keyboardEvents = instructions["keyboard events"] ?? ""
        let appLogic = instructions["application logic"] ?? ""
        let animations = instructions["animations"] ?? ""

        let bodyContent = String(html.prefix(2000))

        return """
        You are a JavaScript engineer adding interactivity to an HTML page.
        Write vanilla JavaScript code (no modules, no imports) that will be inserted into a <script> tag.

        RULES:
        - Use vanilla JavaScript only
        - Store any application state in window.dreamData = {}
        - Use document.querySelector and addEventListener for DOM manipulation
        - Code should be self-contained and run immediately
        - Make the interactions smooth and delightful

        EXISTING HTML (partial):
        \(bodyContent)

        INTERACTIVITY REQUIREMENTS:
        \(interactivity)

        \(mouseEvents.isEmpty ? "" : "MOUSE EVENTS:\n\(mouseEvents)\n")
        \(keyboardEvents.isEmpty ? "" : "KEYBOARD EVENTS:\n\(keyboardEvents)\n")
        \(appLogic.isEmpty ? "" : "APPLICATION LOGIC:\n\(appLogic)\n")
        \(animations.isEmpty ? "" : "ANIMATIONS:\n\(animations)\n")

        Generate JavaScript code. Do not include <script> tags, just the code:

        """
    }

    // MARK: - Response Cleaning

    /// Clean JSON response from LLM
    static func cleanJSON(_ raw: String) -> String {
        var cleaned = raw
            .replacingOccurrences(of: "```json\n", with: "")
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```\n", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove trailing commas before ] or }
        if let regex = try? NSRegularExpression(pattern: #",(\s*[}\]])"#) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "$1")
        }

        return cleaned
    }

    /// Clean HTML response from LLM
    static func cleanHTML(_ raw: String) -> String {
        var cleaned = raw
            .replacingOccurrences(of: "```html\n", with: "")
            .replacingOccurrences(of: "```html", with: "")
            .replacingOccurrences(of: "```\n", with: "")

        // Split on ``` and take first part
        if let backtickRange = cleaned.range(of: "```") {
            cleaned = String(cleaned[cleaned.startIndex..<backtickRange.lowerBound])
        }

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Clean script response from LLM
    static func cleanScript(_ raw: String) -> String {
        var cleaned = raw
            .replacingOccurrences(of: "```javascript\n", with: "")
            .replacingOccurrences(of: "```js\n", with: "")
            .replacingOccurrences(of: "```\n", with: "")
            .replacingOccurrences(of: "```", with: "")

        // Remove script tags if present
        if let regex = try? NSRegularExpression(pattern: #"<script[^>]*>"#) {
            let range = NSRange(cleaned.startIndex..., in: cleaned)
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: range, withTemplate: "")
        }

        // Take only up to </script>
        if let endScript = cleaned.range(of: "</script>") {
            cleaned = String(cleaned[cleaned.startIndex..<endScript.lowerBound])
        }

        // Fix smart quotes
        cleaned = cleaned
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{201C}", with: "\"")
            .replacingOccurrences(of: "\u{201D}", with: "\"")

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Parse tasks/spec from LLM response
    static func parseTasks(_ response: String) -> [String: String] {
        let cleaned = cleanJSON(response)
        let jsonString = "{\(cleaned)"

        if let data = jsonString.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            var result: [String: String] = [:]
            for (key, value) in dict {
                result[key] = "\(value)"
            }
            return result
        }

        // Regex fallback
        var tasks: [String: String] = [:]
        let pattern = #""([^"]+)":\s*"([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let range = NSRange(response.startIndex..., in: response)
            let matches = regex.matches(in: response, range: range)
            for match in matches {
                if let keyRange = Range(match.range(at: 1), in: response),
                   let valueRange = Range(match.range(at: 2), in: response) {
                    tasks[String(response[keyRange])] = String(response[valueRange])
                }
            }
        }

        return tasks
    }
}

// MARK: - Generation Feature

@Reducer
struct GenerationFeature: Sendable {
    @ObservableState
    struct State: Equatable {
        var session: DreamSession?
        var stage: DreamStage = .idle
        var isGenerating: Bool = false
        var error: String?
        var accumulatedCost: DreamGenerationCost = .zero
        var providerSettings: DreamProviderSettings = .empty

        // Dream list
        var dreams: [DreamSummary] = []
        var isLoadingList: Bool = false
        var isOnline: Bool = false

        // Template
        var selectedTemplate: DreamTemplate?

        // Input
        var promptText: String = ""
        var selectedOutputType: DreamOutputType = .webpage
        var thinkingLevel: DreamThinkingLevel = .medium

        // Navigation
        @Presents var canvas: CanvasFeature.State?
        @Presents var providerConfig: ProviderFeature.State?
        @Presents var templatePicker: TemplateFeature.State?
        @Presents var costTracker: CostFeature.State?
    }

    enum Action: Sendable {
        // User actions
        case onAppear
        case promptTextChanged(String)
        case outputTypeChanged(DreamOutputType)
        case thinkingLevelChanged(DreamThinkingLevel)
        case createAndGenerate
        case stopGeneration
        case selectDream(String)
        case deleteDream(String)
        case toggleFavorite(String)
        case refreshList

        // Generation pipeline
        case startGeneration(DreamSession)
        case stageCompleted(DreamStage, DreamSession)
        case generationCompleted(DreamSession)
        case generationFailed(String)

        // Internal
        case dreamsLoaded([DreamSummary], Bool)
        case dreamCreated(DreamSession)
        case dreamSelected(DreamSession?)
        case dreamDeleted(String)
        case favoriteToggled(String, Bool)

        // Navigation
        case canvas(PresentationAction<CanvasFeature.Action>)
        case providerConfig(PresentationAction<ProviderFeature.Action>)
        case templatePicker(PresentationAction<TemplateFeature.Action>)
        case costTracker(PresentationAction<CostFeature.Action>)
        case showCanvas
        case showProviderConfig
        case showTemplatePicker
        case showCostTracker

        // Example prompt
        case useExamplePrompt
    }

    @Dependency(\.dreamProvider) var provider
    @Dependency(\.dreamImage) var imageClient
    @Dependency(\.dreamStorage) var storage

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            // MARK: - Lifecycle

            case .onAppear:
                state.isLoadingList = true
                return .run { send in
                    let dreams = try await storage.listDreams(50, 0, nil, nil)
                    let stats = try await storage.getStats()
                    await send(.dreamsLoaded(dreams, stats.isOnline))
                }

            case .dreamsLoaded(let dreams, let isOnline):
                state.dreams = dreams
                state.isOnline = isOnline
                state.isLoadingList = false
                return .none

            // MARK: - Input

            case .promptTextChanged(let text):
                state.promptText = text
                return .none

            case .outputTypeChanged(let type):
                state.selectedOutputType = type
                return .none

            case .thinkingLevelChanged(let level):
                state.thinkingLevel = level
                return .none

            case .useExamplePrompt:
                let (_, prompt) = DreamTemplates.randomPrompt()
                state.promptText = prompt
                return .none

            // MARK: - CRUD

            case .createAndGenerate:
                let prompt = state.promptText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !prompt.isEmpty else { return .none }
                guard !state.isGenerating else { return .none }

                let outputType = state.selectedOutputType
                let templateID = state.selectedTemplate?.id
                let thinkingLevel = state.thinkingLevel
                let vendor = state.providerSettings.vendor
                let libraries = state.selectedTemplate?.suggestedLibraries ?? []

                var dream = DreamSession.create(
                    prompt: prompt,
                    outputType: outputType,
                    provider: vendor,
                    templateID: templateID,
                    thinkingLevel: thinkingLevel,
                    libraries: libraries
                )

                state.promptText = ""

                return .run { send in
                    let created = try await storage.createDream(dream)
                    await send(.dreamCreated(created))
                    await send(.startGeneration(created))
                }

            case .dreamCreated(let dream):
                state.session = dream
                let summary = DreamSummary(
                    id: dream.id,
                    title: dream.title,
                    prompt: dream.prompt,
                    outputType: dream.outputType,
                    isFavorite: dream.isFavorite,
                    tags: dream.tags,
                    createdAt: dream.createdAt,
                    updatedAt: dream.updatedAt
                )
                state.dreams.insert(summary, at: 0)
                return .none

            case .selectDream(let id):
                return .run { send in
                    let dream = try await storage.getDream(id)
                    await send(.dreamSelected(dream))
                }

            case .dreamSelected(let dream):
                state.session = dream
                if let dream = dream, dream.stage == .complete {
                    state.canvas = CanvasFeature.State(
                        html: dream.html,
                        script: dream.script,
                        title: dream.title
                    )
                }
                return .none

            case .deleteDream(let id):
                return .run { send in
                    _ = try await storage.deleteDream(id)
                    await send(.dreamDeleted(id))
                }

            case .dreamDeleted(let id):
                state.dreams.removeAll { $0.id == id }
                if state.session?.id == id {
                    state.session = nil
                    state.canvas = nil
                }
                return .none

            case .toggleFavorite(let id):
                guard let index = state.dreams.firstIndex(where: { $0.id == id }) else { return .none }
                let newValue = !state.dreams[index].isFavorite
                state.dreams[index].isFavorite = newValue

                return .run { [newValue] send in
                    _ = try await storage.updateDream(id, DreamPatch(is_favorite: newValue))
                    await send(.favoriteToggled(id, newValue))
                }

            case .favoriteToggled:
                return .none

            case .refreshList:
                state.isLoadingList = true
                return .run { send in
                    let dreams = try await storage.listDreams(50, 0, nil, nil)
                    let stats = try await storage.getStats()
                    await send(.dreamsLoaded(dreams, stats.isOnline))
                }

            // MARK: - Generation Pipeline

            case .startGeneration(let dream):
                guard !state.isGenerating else { return .none }

                let settings = state.providerSettings
                guard !settings.availableProviders.isEmpty else {
                    state.error = "No AI providers configured. Please add an API key in Settings."
                    return .none
                }

                state.isGenerating = true
                state.error = nil
                state.stage = .tasks
                state.accumulatedCost = .zero

                return .run { send in
                    var currentDream = dream

                    // STAGE 1: Tasks/Spec
                    let tasksResult = try await provider.completeWithFallback(
                        CompletionParams(
                            systemPrompt: "You are a creative engineer designing web experiences.",
                            userPrompt: DreamPromptEngine.tasksPrompt(query: dream.prompt),
                            maxTokens: 2048,
                            settings: .json
                        ),
                        settings,
                        settings.vendor
                    )

                    let tasks = DreamPromptEngine.parseTasks(tasksResult.content)
                    currentDream.tasks = tasks
                    currentDream.stage = .layout
                    _ = try await storage.updateDream(currentDream.id, DreamPatch(
                        tasks: tasks, stage: DreamStage.layout.rawValue
                    ))
                    await send(.stageCompleted(.tasks, currentDream))

                    // STAGE 2: Layout/HTML
                    let layoutResult = try await provider.completeWithFallback(
                        CompletionParams(
                            systemPrompt: "You are a frontend engineer creating beautiful HTML with Tailwind CSS.",
                            userPrompt: DreamPromptEngine.layoutPrompt(instructions: tasks),
                            maxTokens: 8192,
                            settings: .html
                        ),
                        settings,
                        settings.vendor
                    )

                    var html = DreamPromptEngine.cleanHTML(layoutResult.content)
                    currentDream.html = html
                    currentDream.stage = .images
                    _ = try await storage.updateDream(currentDream.id, DreamPatch(
                        html: html, stage: DreamStage.images.rawValue
                    ))
                    await send(.stageCompleted(.layout, currentDream))

                    // STAGE 3: Images
                    var images: [DreamGeneratedImage] = []
                    let hasPlaceholders = html.contains("alt=\"") && html.contains("src=\"\"")
                    if hasPlaceholders {
                        do {
                            let imageResult = try await imageClient.resolveImagesInHTML(html, settings, .illustration)
                            html = imageResult.html
                            images = imageResult.images
                            currentDream.html = html
                            currentDream.images = images
                        } catch {
                            // Image generation failed, continue without images
                        }
                    }
                    currentDream.stage = .script
                    _ = try await storage.updateDream(currentDream.id, DreamPatch(
                        html: html, stage: DreamStage.script.rawValue
                    ))
                    await send(.stageCompleted(.images, currentDream))

                    // STAGE 4: Script
                    let interactivity = tasks["interactivity"] ?? ""
                    let needsScript = !interactivity.isEmpty
                        && !interactivity.lowercased().contains("no javascript")
                        && !interactivity.lowercased().contains("none")

                    var script = ""
                    if needsScript {
                        let scriptResult = try await provider.completeWithFallback(
                            CompletionParams(
                                systemPrompt: "You are a JavaScript engineer adding interactivity to HTML pages.",
                                userPrompt: DreamPromptEngine.scriptPrompt(instructions: tasks, html: html),
                                maxTokens: 4096,
                                settings: .script
                            ),
                            settings,
                            settings.vendor
                        )
                        script = DreamPromptEngine.cleanScript(scriptResult.content)
                    }

                    currentDream.script = script
                    currentDream.stage = .complete
                    currentDream.model = settings.model(for: settings.vendor)

                    // Calculate accumulated cost
                    let totalCost = DreamGenerationCost(
                        inputTokens: tasksResult.inputTokens + layoutResult.inputTokens,
                        outputTokens: tasksResult.outputTokens + layoutResult.outputTokens,
                        imageCount: images.count
                    )
                    currentDream.generationCost = totalCost

                    _ = try await storage.updateDream(currentDream.id, DreamPatch(
                        script: script, stage: DreamStage.complete.rawValue, model: currentDream.model
                    ))

                    await send(.generationCompleted(currentDream))
                } catch: { error, send in
                    await send(.generationFailed(error.localizedDescription))
                }

            case .stageCompleted(let stage, let dream):
                state.session = dream
                state.stage = stage == .tasks ? .layout
                    : stage == .layout ? .images
                    : stage == .images ? .script
                    : .rendering
                return .none

            case .generationCompleted(let dream):
                state.session = dream
                state.stage = .complete
                state.isGenerating = false
                state.accumulatedCost = dream.generationCost ?? .zero

                // Auto-show canvas
                state.canvas = CanvasFeature.State(
                    html: dream.html,
                    script: dream.script,
                    title: dream.title
                )

                // Update list
                if let index = state.dreams.firstIndex(where: { $0.id == dream.id }) {
                    state.dreams[index].updatedAt = dream.updatedAt
                }

                return .none

            case .generationFailed(let error):
                state.error = error
                state.stage = .error
                state.isGenerating = false
                return .none

            case .stopGeneration:
                state.isGenerating = false
                state.stage = .idle
                return .none

            // MARK: - Navigation

            case .showCanvas:
                guard let dream = state.session, !dream.html.isEmpty else { return .none }
                state.canvas = CanvasFeature.State(
                    html: dream.html,
                    script: dream.script,
                    title: dream.title
                )
                return .none

            case .showProviderConfig:
                state.providerConfig = ProviderFeature.State(settings: state.providerSettings)
                return .none

            case .showTemplatePicker:
                state.templatePicker = TemplateFeature.State()
                return .none

            case .showCostTracker:
                state.costTracker = CostFeature.State(cost: state.accumulatedCost)
                return .none

            case .canvas:
                return .none

            case .providerConfig(.presented(.saveSettings(let settings))):
                state.providerSettings = settings
                state.providerConfig = nil
                return .none

            case .providerConfig:
                return .none

            case .templatePicker(.presented(.templateSelected(let template))):
                state.selectedTemplate = template
                state.templatePicker = nil
                return .none

            case .templatePicker:
                return .none

            case .costTracker:
                return .none
            }
        }
        .ifLet(\.$canvas, action: \.canvas) {
            CanvasFeature()
        }
        .ifLet(\.$providerConfig, action: \.providerConfig) {
            ProviderFeature()
        }
        .ifLet(\.$templatePicker, action: \.templatePicker) {
            TemplateFeature()
        }
        .ifLet(\.$costTracker, action: \.costTracker) {
            CostFeature()
        }
    }
}
