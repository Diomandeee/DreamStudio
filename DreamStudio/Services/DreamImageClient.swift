import Foundation
import ComposableArchitecture

// MARK: - Image Generation Types

struct ImageGenerationOptions: Equatable, Sendable {
    var style: DreamImageStyle = .illustration
    var aspectRatio: DreamAspectRatio = .square
    var numberOfImages: Int = 1
    var negativePrompt: String?
}

struct ImageResolutionResult: Equatable, Sendable {
    let html: String
    let images: [DreamGeneratedImage]
    let tokensUsed: Int
}

// MARK: - Dream Image Client

@DependencyClient
struct DreamImageClient: Sendable {
    /// Generate a single image using Gemini Imagen
    var generateImage: @Sendable (String, ImageGenerationOptions, DreamProviderSettings) async throws -> DreamGeneratedImage

    /// Resolve all image placeholders in HTML
    var resolveImagesInHTML: @Sendable (String, DreamProviderSettings, DreamImageStyle) async throws -> ImageResolutionResult
}

// MARK: - DependencyKey

extension DreamImageClient: DependencyKey {
    static let liveValue: DreamImageClient = {
        // Gemini Imagen 4.0 model
        let imagenModel = "imagen-4.0-generate-001"
        let imagenEndpoint = "https://generativelanguage.googleapis.com/v1beta/models"
        let session = URLSession.shared

        @Sendable
        func generateSingleImage(
            prompt: String,
            options: ImageGenerationOptions,
            settings: DreamProviderSettings
        ) async throws -> DreamGeneratedImage {
            guard let apiKey = settings.geminiKey, !apiKey.isEmpty else {
                throw DreamImageError.noAPIKey
            }

            // Build enhanced prompt with style guidance
            let enhancedPrompt = "\(options.style.promptGuide) \(prompt)"
            let dims = options.aspectRatio.dimensions

            let endpoint = "\(imagenEndpoint)/\(imagenModel):generateContent?key=\(apiKey)"
            guard let url = URL(string: endpoint) else {
                throw DreamImageError.invalidURL
            }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "contents": [
                    [
                        "parts": [["text": enhancedPrompt]]
                    ]
                ],
                "generationConfig": [
                    "responseModalities": ["TEXT", "IMAGE"],
                    "imageDimensions": [
                        "width": dims.width,
                        "height": dims.height
                    ]
                ]
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw DreamImageError.invalidResponse
            }

            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown"
                throw DreamImageError.apiError(httpResponse.statusCode, errorBody)
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else {
                throw DreamImageError.parseError("No candidates in response")
            }

            // Find the image part
            var imageData: String?
            var mimeType = "image/png"

            for part in parts {
                if let inlineData = part["inlineData"] as? [String: Any],
                   let partMime = inlineData["mimeType"] as? String,
                   let partData = inlineData["data"] as? String {
                    imageData = partData
                    mimeType = partMime
                    break
                }
            }

            guard let base64Data = imageData else {
                throw DreamImageError.noImageGenerated
            }

            let dataURI = "data:\(mimeType);base64,\(base64Data)"
            let imageID = "img_\(Int(Date().timeIntervalSince1970))_\(String(UUID().uuidString.prefix(7)))"

            return DreamGeneratedImage(
                id: imageID,
                alt: prompt,
                dataURI: dataURI,
                mimeType: mimeType,
                width: dims.width,
                height: dims.height,
                metadata: .init(
                    prompt: prompt,
                    style: options.style.rawValue,
                    aspectRatio: options.aspectRatio.rawValue,
                    generatedAt: ISO8601DateFormatter().string(from: Date())
                )
            )
        }

        return DreamImageClient(
            generateImage: { prompt, options, settings in
                try await generateSingleImage(prompt: prompt, options: options, settings: settings)
            },
            resolveImagesInHTML: { html, settings, defaultStyle in
                // Parse HTML to find all <img> tags with alt text
                let pattern = #"<img\s+[^>]*alt="([^"]+)"[^>]*>"#
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                    return ImageResolutionResult(html: html, images: [], tokensUsed: 0)
                }

                let range = NSRange(html.startIndex..., in: html)
                let matches = regex.matches(in: html, options: [], range: range)

                if matches.isEmpty {
                    return ImageResolutionResult(html: html, images: [], tokensUsed: 0)
                }

                var updatedHTML = html
                var images: [DreamGeneratedImage] = []

                for match in matches {
                    guard let altRange = Range(match.range(at: 1), in: html) else { continue }
                    let alt = String(html[altRange])

                    do {
                        let image = try await generateSingleImage(
                            prompt: alt,
                            options: ImageGenerationOptions(style: defaultStyle),
                            settings: settings
                        )

                        // Replace src="" with the generated data URI
                        if let fullRange = Range(match.range, in: updatedHTML) {
                            let fullMatch = String(updatedHTML[fullRange])
                            let replaced = fullMatch.replacingOccurrences(
                                of: #"src="[^"]*""#,
                                with: "src=\"\(image.dataURI)\"",
                                options: .regularExpression
                            )
                            updatedHTML = updatedHTML.replacingOccurrences(of: fullMatch, with: replaced)
                        }

                        images.append(image)
                    } catch {
                        // Use placeholder on error
                        let placeholder = "https://placehold.co/600x400?text=\(alt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? alt)"
                        if let fullRange = Range(match.range, in: updatedHTML) {
                            let fullMatch = String(updatedHTML[fullRange])
                            let replaced = fullMatch.replacingOccurrences(
                                of: #"src="[^"]*""#,
                                with: "src=\"\(placeholder)\"",
                                options: .regularExpression
                            )
                            updatedHTML = updatedHTML.replacingOccurrences(of: fullMatch, with: replaced)
                        }
                    }
                }

                return ImageResolutionResult(html: updatedHTML, images: images, tokensUsed: 0)
            }
        )
    }()

    static let testValue = DreamImageClient(
        generateImage: { _, _, _ in
            DreamGeneratedImage(
                id: "test_img",
                alt: "Test image",
                dataURI: "data:image/png;base64,iVBORw0KGgo=",
                mimeType: "image/png"
            )
        },
        resolveImagesInHTML: { html, _, _ in
            ImageResolutionResult(html: html, images: [], tokensUsed: 0)
        }
    )
}

extension DependencyValues {
    var dreamImage: DreamImageClient {
        get { self[DreamImageClient.self] }
        set { self[DreamImageClient.self] = newValue }
    }
}

// MARK: - Errors

enum DreamImageError: LocalizedError, Equatable {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case apiError(Int, String)
    case parseError(String)
    case noImageGenerated

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "Gemini API key not configured for image generation"
        case .invalidURL:
            return "Invalid image API endpoint"
        case .invalidResponse:
            return "Invalid response from image API"
        case .apiError(let code, let message):
            return "Image API error (\(code)): \(message)"
        case .parseError(let message):
            return "Image parse error: \(message)"
        case .noImageGenerated:
            return "No image was generated in the response"
        }
    }
}
