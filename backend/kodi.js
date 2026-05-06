function kodiUrl() {
  return (process.env.KODI_URL || "").replace(/\/+$/, "");
}

function credentials() {
  const username = process.env.KODI_USERNAME || "";
  const password = process.env.KODI_PASSWORD || "";
  if (!username && !password) return null;
  return Buffer.from(`${username}:${password}`).toString("base64");
}

function requireKodiUrl() {
  if (!kodiUrl()) {
    throw new Error("Missing KODI_URL. Add your Kodi JSON-RPC URL to .env, for example KODI_URL=http://192.168.1.50:8080/jsonrpc.");
  }
}

async function rpc(method, params = {}) {
  requireKodiUrl();
  const headers = {
    "Content-Type": "application/json",
    Accept: "application/json"
  };
  const auth = credentials();
  if (auth) headers.Authorization = `Basic ${auth}`;

  const response = await fetch(kodiUrl(), {
    method: "POST",
    headers,
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: Date.now(),
      method,
      params
    })
  });

  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(`Kodi returned HTTP ${response.status}`);
  }
  if (body.error) {
    throw new Error(body.error.message || "Kodi JSON-RPC error");
  }
  return body.result || {};
}

function imageUrl(value) {
  if (!value) return null;
  if (/^https?:\/\//i.test(value)) return value;
  const base = kodiUrl().replace(/\/jsonrpc$/i, "");
  return `${base}/image/${encodeURIComponent(value)}`;
}

function movieItem(movie) {
  return {
    id: String(movie.movieid),
    kodiId: movie.movieid,
    sourceId: "kodi",
    kind: "movie",
    title: movie.title || "Untitled",
    subtitle: "Kodi Library",
    artwork: imageUrl(movie.thumbnail || movie.art?.poster),
    banner: imageUrl(movie.fanart || movie.art?.fanart || movie.thumbnail),
    year: movie.year || null,
    score: movie.rating || null,
    genres: movie.genre || [],
    synopsis: movie.plot || "",
    status: "Local library",
    runtime: movie.runtime || null
  };
}

function showItem(show) {
  return {
    id: String(show.tvshowid),
    kodiId: show.tvshowid,
    sourceId: "kodi",
    kind: "show",
    title: show.title || "Untitled",
    subtitle: "Kodi Library",
    artwork: imageUrl(show.thumbnail || show.art?.poster),
    banner: imageUrl(show.fanart || show.art?.fanart || show.thumbnail),
    year: show.year || null,
    score: show.rating || null,
    genres: show.genre || [],
    synopsis: show.plot || "",
    status: "Local library",
    seasons: show.season ? [{ id: `${show.tvshowid}-seasons`, title: "Seasons", episodes: show.episode || null }] : []
  };
}

async function movies() {
  const result = await rpc("VideoLibrary.GetMovies", {
    properties: ["title", "year", "rating", "genre", "plot", "runtime", "thumbnail", "fanart", "art"],
    sort: { method: "lastplayed", order: "descending" }
  });
  return { sourceId: "kodi", kind: "movie", items: (result.movies || []).map(movieItem) };
}

async function shows() {
  const result = await rpc("VideoLibrary.GetTVShows", {
    properties: ["title", "year", "rating", "genre", "plot", "episode", "season", "thumbnail", "fanart", "art"],
    sort: { method: "lastplayed", order: "descending" }
  });
  return { sourceId: "kodi", kind: "show", items: (result.tvshows || []).map(showItem) };
}

module.exports = {
  movies,
  shows
};
