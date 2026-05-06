const TMDB_BASE = "https://api.themoviedb.org/3";
const IMAGE_BASE = "https://image.tmdb.org/t/p/w780";
const BACKDROP_BASE = "https://image.tmdb.org/t/p/w1280";

const kindMap = {
  movie: "movie",
  show: "tv",
  tv: "tv"
};

const catalogMap = {
  movie: {
    trending: "/trending/movie/week",
    popular: "/movie/popular",
    top_rated: "/movie/top_rated",
    new: "/movie/now_playing",
    upcoming: "/movie/upcoming"
  },
  tv: {
    trending: "/trending/tv/week",
    popular: "/tv/popular",
    top_rated: "/tv/top_rated",
    new: "/tv/on_the_air",
    airing_today: "/tv/airing_today"
  }
};

function token() {
  return process.env.TMDB_READ_ACCESS_TOKEN || "";
}

function apiKey() {
  return process.env.TMDB_API_KEY || "";
}

function mediaType(kind) {
  return kindMap[String(kind || "").toLowerCase()] || "movie";
}

function appKind(type) {
  return type === "tv" ? "show" : "movie";
}

function requireCredentials() {
  if (!token() && !apiKey()) {
    throw new Error("Missing TMDB credentials. Add TMDB_READ_ACCESS_TOKEN or TMDB_API_KEY to .env.");
  }
}

async function request(path, params = {}) {
  requireCredentials();
  const url = new URL(`${TMDB_BASE}${path}`);
  url.searchParams.set("language", params.language || "en-US");
  url.searchParams.set("include_adult", "false");
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null && key !== "language") {
      url.searchParams.set(key, String(value));
    }
  }
  if (!token()) {
    url.searchParams.set("api_key", apiKey());
  }

  const headers = { Accept: "application/json" };
  if (token()) {
    headers.Authorization = `Bearer ${token()}`;
  }

  const response = await fetch(url, { headers });
  const text = await response.text();
  let body;
  try {
    body = text ? JSON.parse(text) : {};
  } catch {
    body = { raw: text };
  }
  if (!response.ok) {
    throw new Error(body.status_message || body.error || `TMDB returned HTTP ${response.status}`);
  }
  return body;
}

function image(pathname, base = IMAGE_BASE) {
  return pathname ? `${base}${pathname}` : null;
}

function yearFor(item, type) {
  const date = type === "tv" ? item.first_air_date : item.release_date;
  return date ? Number(String(date).slice(0, 4)) || null : null;
}

function normalize(item, type, genres = []) {
  const title = type === "tv" ? item.name : item.title;
  const original = type === "tv" ? item.original_name : item.original_title;
  return {
    id: String(item.id),
    tmdbId: item.id,
    sourceId: "tmdb",
    kind: appKind(type),
    title: title || original || "Untitled",
    subtitle: "TMDB",
    artwork: image(item.poster_path),
    banner: image(item.backdrop_path, BACKDROP_BASE) || image(item.poster_path),
    year: yearFor(item, type),
    score: item.vote_average || null,
    genres,
    synopsis: item.overview || "",
    status: item.status || null
  };
}

function genreNames(details) {
  return Array.isArray(details.genres) ? details.genres.map((genre) => genre.name).filter(Boolean) : [];
}

async function catalog({ kind = "movie", section = "trending", page = 1 }) {
  const type = mediaType(kind);
  const endpoint = catalogMap[type][section] || catalogMap[type].trending;
  const body = await request(endpoint, { page });
  return {
    kind: appKind(type),
    section,
    items: (body.results || []).map((item) => normalize(item, type)),
    page: body.page || page,
    totalPages: body.total_pages || null
  };
}

async function search({ kind = "movie", q = "", page = 1 }) {
  const type = mediaType(kind);
  const query = String(q || "").trim();
  if (!query) {
    return { kind: appKind(type), items: [], page, totalPages: 0 };
  }
  const body = await request(`/search/${type}`, { query, page });
  return {
    kind: appKind(type),
    items: (body.results || []).map((item) => normalize(item, type)),
    page: body.page || page,
    totalPages: body.total_pages || null
  };
}

async function details({ kind = "movie", id }) {
  const type = mediaType(kind);
  const body = await request(`/${type}/${encodeURIComponent(id)}`, {
    append_to_response: type === "tv" ? "credits,similar,content_ratings" : "credits,similar,release_dates"
  });
  const item = normalize(body, type, genreNames(body));
  item.runtime = type === "tv" ? body.episode_run_time?.[0] || null : body.runtime || null;
  item.seasons = type === "tv" ? (body.seasons || []).map((season) => ({
    id: String(season.id),
    number: season.season_number,
    title: season.name,
    episodes: season.episode_count,
    artwork: image(season.poster_path),
    year: season.air_date ? Number(String(season.air_date).slice(0, 4)) || null : null
  })) : [];
  item.cast = (body.credits?.cast || []).slice(0, 12).map((person) => ({
    id: String(person.id),
    name: person.name,
    role: person.character || "",
    image: image(person.profile_path)
  }));
  item.similar = (body.similar?.results || []).slice(0, 12).map((similar) => normalize(similar, type));
  return item;
}

module.exports = {
  catalog,
  search,
  details
};
