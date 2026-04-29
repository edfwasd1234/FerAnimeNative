import Foundation

struct ResolvedPlayback: Hashable {
    let sourceId: String
    let episode: Episode
    let direct: [EpisodeStream]
    let embeds: [EpisodeStream]
}

@MainActor
final class StreamResolver: ObservableObject {
    @Published var isResolving = false
    @Published var message = "Preparing playback"

    private let sourceOrder = ["anizone", "animeheaven", "hianime", "animekai"]

    func resolve(
        client: ResolverClient,
        preferredSourceId: String,
        animeTitle: String,
        animeId: String,
        episodeId: String,
        episodeNumber: Double
    ) async -> ResolvedPlayback? {
        isResolving = true
        defer { isResolving = false }

        let ordered = ([preferredSourceId] + sourceOrder).reduce(into: [String]()) { result, source in
            if !result.contains(source) { result.append(source) }
        }

        for sourceId in ordered {
            message = "Checking \(sourceId)"
            if sourceId == preferredSourceId {
                if let playback = await playbackForKnownEpisode(client: client, sourceId: sourceId, animeId: animeId, episodeId: episodeId, episodeNumber: episodeNumber) {
                    return playback
                }
            } else if let playback = await playbackBySearch(client: client, sourceId: sourceId, animeTitle: animeTitle, episodeNumber: episodeNumber) {
                return playback
            }
        }

        message = "No playable source found"
        return nil
    }

    private func playbackForKnownEpisode(
        client: ResolverClient,
        sourceId: String,
        animeId: String,
        episodeId: String,
        episodeNumber: Double
    ) async -> ResolvedPlayback? {
        do {
            let streams = try await client.streams(sourceId: sourceId, episodeId: episodeId)
            let episode = Episode(id: episodeId, animeId: animeId, sourceId: sourceId, number: episodeNumber, title: "Episode \(Int(episodeNumber))", duration: nil, streamUrl: nil)
            return makePlayback(sourceId: sourceId, episode: episode, streams: streams)
        } catch {
            return nil
        }
    }

    private func playbackBySearch(
        client: ResolverClient,
        sourceId: String,
        animeTitle: String,
        episodeNumber: Double
    ) async -> ResolvedPlayback? {
        do {
            let results = try await client.search(animeTitle, sourceId: sourceId)
            guard let anime = bestMatch(in: results, title: animeTitle) else { return nil }
            let episodes = try await client.episodes(sourceId: sourceId, animeId: anime.id)
            guard let episode = episodes.min(by: { abs($0.number - episodeNumber) < abs($1.number - episodeNumber) }) else { return nil }
            guard abs(episode.number - episodeNumber) < 0.05 else { return nil }
            let streams = try await client.streams(sourceId: sourceId, episodeId: episode.id)
            return makePlayback(sourceId: sourceId, episode: episode, streams: streams)
        } catch {
            return nil
        }
    }

    private func makePlayback(sourceId: String, episode: Episode, streams: [EpisodeStream]) -> ResolvedPlayback? {
        let direct = sourceId == "hianime" ? [] : streams.filter(\.isDirect)
        let embeds = streams.filter(\.isEmbed)
        guard !direct.isEmpty || !embeds.isEmpty else { return nil }
        return ResolvedPlayback(sourceId: sourceId, episode: episode, direct: direct, embeds: embeds)
    }

    private func bestMatch(in results: [Anime], title: String) -> Anime? {
        let normalized = normalize(title)
        return results.first { normalize($0.title) == normalized } ?? results.first
    }

    private func normalize(_ value: String) -> String {
        value.lowercased()
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
    }
}
