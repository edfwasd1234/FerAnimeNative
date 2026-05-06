import Foundation
import SwiftUI

enum MediaKind: String, Codable, CaseIterable, Identifiable {
    case anime
    case movie
    case show

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anime: "Anime"
        case .movie: "Movie"
        case .show: "Show"
        }
    }

    var symbol: String {
        switch self {
        case .anime: "sparkles.tv.fill"
        case .movie: "film.fill"
        case .show: "play.tv.fill"
        }
    }
}

struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let kind: MediaKind
    let sourceId: String?
    let title: String
    let subtitle: String?
    let artwork: String?
    let banner: String?
    let year: Int?
    let score: Double?
    let genres: [String]
    let synopsis: String?
    let status: String?
    let seasons: [MediaSeason]?
    let cast: [MediaCastMember]?
    let similar: [MediaItem]?

    init(
        id: String,
        kind: MediaKind,
        sourceId: String? = nil,
        title: String,
        subtitle: String? = nil,
        artwork: String? = nil,
        banner: String? = nil,
        year: Int? = nil,
        score: Double? = nil,
        genres: [String] = [],
        synopsis: String? = nil,
        status: String? = nil,
        seasons: [MediaSeason]? = nil,
        cast: [MediaCastMember]? = nil,
        similar: [MediaItem]? = nil
    ) {
        self.id = id
        self.kind = kind
        self.sourceId = sourceId
        self.title = title
        self.subtitle = subtitle
        self.artwork = artwork
        self.banner = banner
        self.year = year
        self.score = score
        self.genres = genres
        self.synopsis = synopsis
        self.status = status
        self.seasons = seasons
        self.cast = cast
        self.similar = similar
    }
}

enum TasteAxis: String, Codable, CaseIterable, Identifiable {
    case emotionalIntensity
    case narrativeComplexity
    case tone
    case pacing
    case visualStyle
    case comfortChallenge
    case chaosCalm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .emotionalIntensity: "Intensity"
        case .narrativeComplexity: "Complexity"
        case .tone: "Tone"
        case .pacing: "Pacing"
        case .visualStyle: "Style"
        case .comfortChallenge: "Comfort"
        case .chaosCalm: "Chaos"
        }
    }
}

struct TasteFingerprint: Codable, Hashable {
    var axes: [TasteAxis: Double]
    var animeAxes: [TasteAxis: Double]
    var updatedAt: Date

    static let neutral = TasteFingerprint(
        axes: Dictionary(uniqueKeysWithValues: TasteAxis.allCases.map { ($0, 0.5) }),
        animeAxes: Dictionary(uniqueKeysWithValues: TasteAxis.allCases.map { ($0, 0.5) }),
        updatedAt: Date()
    )

    mutating func blend(axis: TasteAxis, value: Double, animeOnly: Bool = false, weight: Double = 0.18) {
        let clamped = min(max(value, 0), 1)
        let current = axes[axis] ?? 0.5
        axes[axis] = current + (clamped - current) * weight
        if animeOnly {
            let animeCurrent = animeAxes[axis] ?? 0.5
            animeAxes[axis] = animeCurrent + (clamped - animeCurrent) * weight
        }
        updatedAt = Date()
    }
}

struct TasteQuestion: Identifiable, Hashable {
    let id: String
    let prompt: String
    let left: String
    let right: String
    let axis: TasteAxis
    let leftValue: Double
    let rightValue: Double

    static let onboarding: [TasteQuestion] = [
        TasteQuestion(id: "ending", prompt: "Pick the ending you crave", left: "Hopeful", right: "Devastating", axis: .emotionalIntensity, leftValue: 0.35, rightValue: 0.92),
        TasteQuestion(id: "pace", prompt: "Pick the pace", left: "Slow burn", right: "Fast and chaotic", axis: .pacing, leftValue: 0.25, rightValue: 0.86),
        TasteQuestion(id: "feeling", prompt: "Pick the feeling", left: "Comforting", right: "Challenging", axis: .comfortChallenge, leftValue: 0.18, rightValue: 0.84),
        TasteQuestion(id: "plot", prompt: "Pick the story shape", left: "Simple and clean", right: "Puzzle box", axis: .narrativeComplexity, leftValue: 0.25, rightValue: 0.9),
        TasteQuestion(id: "look", prompt: "Pick the visual pull", left: "Natural", right: "Stylized", axis: .visualStyle, leftValue: 0.3, rightValue: 0.88),
        TasteQuestion(id: "tone", prompt: "Pick the tone", left: "Warm", right: "Bleak", axis: .tone, leftValue: 0.25, rightValue: 0.82),
        TasteQuestion(id: "energy", prompt: "Pick the room energy", left: "Quiet", right: "Unhinged", axis: .chaosCalm, leftValue: 0.2, rightValue: 0.9),
        TasteQuestion(id: "rewatch", prompt: "Pick the rewatch", left: "Safe favorite", right: "New scar", axis: .emotionalIntensity, leftValue: 0.28, rightValue: 0.86),
        TasteQuestion(id: "world", prompt: "Pick the world", left: "Grounded", right: "Mythic", axis: .visualStyle, leftValue: 0.34, rightValue: 0.82),
        TasteQuestion(id: "night", prompt: "Pick the night", left: "Cozy", right: "No sleep", axis: .chaosCalm, leftValue: 0.24, rightValue: 0.88)
    ]
}

enum ReactionTag: String, Codable, CaseIterable, Identifiable {
    case wreckedMe
    case comfortWatch
    case slowStartWorthIt
    case overhyped
    case hiddenGem
    case backgroundNoise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wreckedMe: "Wrecked me"
        case .comfortWatch: "Comfort watch"
        case .slowStartWorthIt: "Slow start worth it"
        case .overhyped: "Overhyped"
        case .hiddenGem: "Hidden gem"
        case .backgroundNoise: "Background noise"
        }
    }
}

struct WatchLog: Codable, Identifiable, Hashable {
    let id: UUID
    let media: MediaItem
    let rating: Double
    let reactions: [ReactionTag]
    let watchedWith: String
    let watchStyle: String
    let mood: String
    let note: String
    let finished: Bool
    let watchedAt: Date
    let hours: Double
}

struct LensPickRequest: Codable, Hashable {
    var mood: String
    var availableTime: String
    var company: String
    var services: [String]
    var kind: MediaKind
}

struct LensPickResult: Identifiable, Hashable {
    let id = UUID()
    let media: MediaItem
    let reason: String
    let confidence: Double
}

struct ViewingStats: Hashable {
    let totalHours: Double
    let logsCount: Int
    let averageRating: Double
    let bingeRatio: Double
    let aloneRatio: Double
    let topReaction: String

    static let empty = ViewingStats(totalHours: 0, logsCount: 0, averageRating: 0, bingeRatio: 0, aloneRatio: 0, topReaction: "None yet")
}

extension MediaItem {
    init(anime: Anime) {
        self.init(
            id: anime.id,
            kind: .anime,
            sourceId: anime.sourceId,
            title: anime.title,
            subtitle: anime.subtitle,
            artwork: anime.cover ?? anime.banner,
            banner: anime.banner ?? anime.cover,
            year: anime.year,
            score: anime.score,
            genres: anime.genres,
            synopsis: anime.synopsis,
            status: anime.status
        )
    }
}
