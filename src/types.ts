export type LibraryStatus = "Watching" | "Planned" | "Completed";

export type Episode = {
  id: string;
  animeId: string;
  sourceId?: string;
  number: number;
  title: string;
  duration: string;
  streamUrl?: string;
  aired?: string | null;
  score?: number | null;
  filler?: boolean;
  recap?: boolean;
};

export type Anime = {
  id: string;
  sourceId?: string;
  malId?: number | null;
  anidbId?: number | string | null;
  title: string;
  subtitle: string;
  cover: string | null;
  banner: string | null;
  year: number | null;
  score: number | null;
  genres: string[];
  status: LibraryStatus;
  progress: string;
  synopsis: string;
  episodes?: Episode[];
};

export type ShowMetadata = {
  malId: number;
  title: string;
  titleJapanese: string | null;
  synopsis: string;
  score: number | null;
  rank: number | null;
  popularity: number | null;
  year: number | null;
  status: string | null;
  rating: string | null;
  episodes: number | null;
  duration: string | null;
  image: string | null;
  trailerUrl: string | null;
  genres: string[];
  studios: string[];
};

export type EpisodeMetadata = {
  provider: "anidb" | "jikan" | "none" | string;
  id: string;
  number: number | string | null;
  title: string;
  titleJapanese?: string | null;
  titleRomanji?: string | null;
  aired?: string | null;
  duration?: string | null;
  score?: number | null;
  filler?: boolean;
  recap?: boolean;
  forumUrl?: string | null;
};

export type EpisodeStream = {
  id: string;
  label: string;
  quality: string;
  type: "hls" | "mp4" | string;
  url: string;
  headers?: Record<string, string>;
};

export type EpisodeProgress = {
  currentTime: number;
  duration: number;
  updatedAt: string;
  episodeId?: string;
  animeId?: string;
  sourceId?: string;
  animeTitle?: string;
  episodeTitle?: string;
  episodeNumber?: number;
  image?: string | null;
};

export type LibraryEntry = {
  animeId: string;
  sourceId: string;
  title: string;
  image?: string | null;
  status: LibraryStatus;
  progressText?: string;
  updatedAt: string;
};

export type SourceCatalogEntry = {
  id: string;
  name: string;
  scriptUrl: string;
  version: string;
  language?: string;
};
