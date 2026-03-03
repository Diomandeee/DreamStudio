import Foundation
import ComposableArchitecture
import Supabase
import PostgREST

// MARK: - Dream Patch (partial update)

struct DreamPatch: Encodable, Sendable {
    var tasks: [String: String]? = nil
    var html: String? = nil
    var script: String? = nil
    var stage: String? = nil
    var model: String? = nil
    var is_favorite: Bool? = nil
    var updated_at: String? = nil

    enum CodingKeys: String, CodingKey {
        case tasks, html, script, stage, model, is_favorite, updated_at
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let tasks { try container.encode(tasks, forKey: .tasks) }
        if let html { try container.encode(html, forKey: .html) }
        if let script { try container.encode(script, forKey: .script) }
        if let stage { try container.encode(stage, forKey: .stage) }
        if let model { try container.encode(model, forKey: .model) }
        if let is_favorite { try container.encode(is_favorite, forKey: .is_favorite) }
        if let updated_at { try container.encode(updated_at, forKey: .updated_at) }
    }
}

// MARK: - Dream Storage Client

@DependencyClient
struct DreamStorageClient: Sendable {
    // CRUD
    var createDream: @Sendable (DreamSession) async throws -> DreamSession
    var getDream: @Sendable (String) async throws -> DreamSession?
    var listDreams: @Sendable (Int, Int, Bool?, DreamOutputType?) async throws -> [DreamSummary]
    var updateDream: @Sendable (String, DreamPatch) async throws -> DreamSession?
    var deleteDream: @Sendable (String) async throws -> Bool

    // Search
    var searchDreams: @Sendable (String, Int) async throws -> [DreamSummary]

    // Stats
    var getStats: @Sendable () async throws -> DreamStats
}

struct DreamStats: Equatable, Sendable {
    var totalDreams: Int = 0
    var favoriteDreams: Int = 0
    var byType: [DreamOutputType: Int] = [:]
    var isOnline: Bool = false
}

// MARK: - DependencyKey

extension DreamStorageClient: DependencyKey {
    static let liveValue: DreamStorageClient = {
        // Supabase client - lazy initialized
        let supabaseURL = URL(string: "https://aaqbofotpchgpyuohmmz.supabase.co")!
        let supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFhcWJvZm90cGNoZ3B5dW9obW16Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzc2NjczMDgsImV4cCI6MjA1MzI0MzMwOH0.3gNejSYUVGNrgQKf9SN0Cc6ALTm25Lff5pBf2E5KZWQ"

        let client = SupabaseClient(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
        let tableName = "dream_sessions"

        return DreamStorageClient(
            createDream: { dream in
                do {
                    let response: DreamSession = try await client
                        .database.from(tableName)
                        .insert(dream)
                        .select()
                        .single()
                        .execute()
                        .value

                    return response
                } catch {
                    // Fallback: return the dream as-is (will be stored locally)
                    return dream
                }
            },

            getDream: { id in
                do {
                    let response: DreamSession = try await client
                        .database.from(tableName)
                        .select()
                        .eq("id", value: id)
                        .single()
                        .execute()
                        .value

                    return response
                } catch {
                    return nil
                }
            },

            listDreams: { limit, offset, favoritesOnly, outputType in
                do {
                    var query = await client
                        .database.from(tableName)
                        .select("id, title, prompt, output_type, is_favorite, tags, created_at, updated_at")

                    if let favoritesOnly = favoritesOnly, favoritesOnly {
                        query = query.eq("is_favorite", value: true)
                    }
                    if let outputType = outputType {
                        query = query.eq("output_type", value: outputType.rawValue)
                    }

                    let response: [DreamSummary] = try await query
                        .order("is_favorite", ascending: false)
                        .order("updated_at", ascending: false)
                        .range(from: offset, to: offset + limit - 1)
                        .execute()
                        .value

                    return response
                } catch {
                    return []
                }
            },

            updateDream: { id, patch in
                var patchWithTimestamp = patch
                patchWithTimestamp.updated_at = ISO8601DateFormatter().string(from: Date())

                do {
                    let response: DreamSession = try await client
                        .database.from(tableName)
                        .update(patchWithTimestamp)
                        .eq("id", value: id)
                        .select()
                        .single()
                        .execute()
                        .value

                    return response
                } catch {
                    return nil
                }
            },

            deleteDream: { id in
                do {
                    try await client
                        .database.from(tableName)
                        .delete()
                        .eq("id", value: id)
                        .execute()

                    return true
                } catch {
                    return false
                }
            },

            searchDreams: { query, limit in
                do {
                    let response: [DreamSummary] = try await client
                        .database.from(tableName)
                        .select("id, title, prompt, output_type, is_favorite, tags, created_at, updated_at")
                        .or("title.ilike.%\(query)%,prompt.ilike.%\(query)%")
                        .order("updated_at", ascending: false)
                        .limit(limit)
                        .execute()
                        .value

                    return response
                } catch {
                    return []
                }
            },

            getStats: {
                do {
                    struct MinimalDream: Decodable {
                        let id: String
                        let output_type: String
                        let is_favorite: Bool
                    }

                    let response: [MinimalDream] = try await client
                        .database.from(tableName)
                        .select("id, output_type, is_favorite")
                        .execute()
                        .value

                    var byType: [DreamOutputType: Int] = [
                        .webpage: 0, .artifact: 0, .hybrid: 0
                    ]
                    for dream in response {
                        if let type = DreamOutputType(rawValue: dream.output_type) {
                            byType[type, default: 0] += 1
                        }
                    }

                    return DreamStats(
                        totalDreams: response.count,
                        favoriteDreams: response.filter(\.is_favorite).count,
                        byType: byType,
                        isOnline: true
                    )
                } catch {
                    return DreamStats(isOnline: false)
                }
            }
        )
    }()

    static let testValue = DreamStorageClient()
}

extension DependencyValues {
    var dreamStorage: DreamStorageClient {
        get { self[DreamStorageClient.self] }
        set { self[DreamStorageClient.self] = newValue }
    }
}

// MARK: - Errors

enum DreamStorageError: LocalizedError {
    case encodingFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode dream session"
        case .notFound: return "Dream session not found"
        }
    }
}
