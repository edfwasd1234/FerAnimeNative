import { animeList } from "../data/anime";
import { extractorCatalog, sourceCatalog } from "../data/sourceCatalog";
import { FERANIME_RESOLVER_URL } from "../config";
import { Anime, Episode, EpisodeMetadata, EpisodeStream, ShowMetadata } from "../types";

async function fetchJson<T>(path: string): Promise<T> {
  const response = await fetch(`${FERANIME_RESOLVER_URL}${path}`);
  if (!response.ok) {
    throw new Error(`Resolver ${response.status}: ${await response.text()}`);
  }
  return response.json() as Promise<T>;
}

export const animeProvider = {
  listTrending() {
    return animeList;
  },
  searchAnime(query: string, genre: string) {
    return animeList.filter((anime) => {
      const matchesQuery = anime.title.toLowerCase().includes(query.toLowerCase());
      const matchesGenre = genre === "All" || anime.genres.includes(genre);
      return matchesQuery && matchesGenre;
    });
  },
  getAnimeDetails(id: string) {
    return animeList.find((anime) => anime.id === id);
  },
  getEpisode(episodeId: string) {
    return animeList.flatMap((anime) => anime.episodes ?? []).find((episode) => episode.id === episodeId);
  },
  getSourceCatalog() {
    return sourceCatalog;
  },
  getExtractorCatalog() {
    return extractorCatalog;
  },
  getEpisodeStreams(episodeId: string): EpisodeStream[] {
    const episode = this.getEpisode(episodeId);
    if (!episode || !episode.streamUrl) return [];
    return [
      {
        id: "mock-auto",
        label: "Mock Auto",
        quality: "auto",
        type: episode.streamUrl.includes(".m3u8") ? "hls" : "mp4",
        url: episode.streamUrl
      }
    ];
  },
  async searchAnimeRemote(query: string, sourceId = "animeheaven") {
    const data = await fetchJson<{ items: Anime[] }>(
      `/api/anime/search?sourceId=${encodeURIComponent(sourceId)}&q=${encodeURIComponent(query)}`
    );
    return data.items;
  },
  async getCatalogRemote(section: string, sourceId = "animeheaven") {
    const data = await fetchJson<{ items: Anime[] }>(
      `/api/anime/catalog?sourceId=${encodeURIComponent(sourceId)}&section=${encodeURIComponent(section)}`
    );
    return data.items;
  },
  async getAnimeDetailsRemote(sourceId: string, id: string) {
    return fetchJson<Anime>(`/api/anime/${encodeURIComponent(sourceId)}/${encodeURIComponent(id)}`);
  },
  async getEpisodesRemote(sourceId: string, id: string) {
    const data = await fetchJson<{ items: Episode[] }>(
      `/api/anime/${encodeURIComponent(sourceId)}/${encodeURIComponent(id)}/episodes`
    );
    return data.items;
  },
  async getEpisodeStreamsRemote(sourceId: string, episodeId: string) {
    const data = await fetchJson<{ items: EpisodeStream[] }>(
      `/api/episodes/${encodeURIComponent(sourceId)}/${encodeURIComponent(episodeId)}/streams`
    );
    return data.items;
  },
  async getShowMetadata(title: string) {
    const data = await fetchJson<{ item: ShowMetadata | null }>(`/api/meta/show?title=${encodeURIComponent(title)}`);
    return data.item;
  },
  async getEpisodeMetadata(title: string, malId?: number | null, anidbId?: string | number | null) {
    const params = new URLSearchParams({ title });
    if (malId) params.set("malId", String(malId));
    if (anidbId) params.set("anidbId", String(anidbId));
    const data = await fetchJson<{ provider: string; items: EpisodeMetadata[]; hasNextPage: boolean }>(`/api/meta/episodes?${params.toString()}`);
    return data;
  }
};
