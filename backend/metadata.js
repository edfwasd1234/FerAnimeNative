const JIKAN_BASE = "https://api.jikan.moe/v4";
const anidbCache = new Map();
const jikanCache = new Map();

function cacheKey(parts) {
  return parts.filter(Boolean).join(":").toLowerCase();
}

async function fetchJson(url) {
  const response = await fetch(url, {
    headers: {
      "User-Agent": "FerAnime/0.1.0"
    }
  });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return response.json();
}

async function fetchText(url) {
  const response = await fetch(url, {
    headers: {
      "User-Agent": "FerAnime/0.1.0",
      Accept: "application/xml,text/xml,*/*"
    }
  });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText}`);
  return response.text();
}

function pickImage(item) {
  return item?.images?.jpg?.large_image_url || item?.images?.webp?.large_image_url || item?.images?.jpg?.image_url || null;
}

function mapJikanAnime(item) {
  if (!item) return null;
  return {
    malId: item.mal_id,
    title: item.title_english || item.title,
    titleJapanese: item.title_japanese || null,
    synopsis: item.synopsis || "",
    score: item.score ? Math.round(item.score * 10) : null,
    rank: item.rank || null,
    popularity: item.popularity || null,
    year: item.year || (item.aired?.from ? new Date(item.aired.from).getFullYear() : null),
    status: item.status || null,
    rating: item.rating || null,
    episodes: item.episodes || null,
    duration: item.duration || null,
    image: pickImage(item),
    trailerUrl: item.trailer?.url || null,
    genres: Array.isArray(item.genres) ? item.genres.map((genre) => genre.name).filter(Boolean) : [],
    studios: Array.isArray(item.studios) ? item.studios.map((studio) => studio.name).filter(Boolean) : []
  };
}

async function searchJikanAnime(title) {
  const key = cacheKey(["jikan", title]);
  if (jikanCache.has(key)) return jikanCache.get(key);
  const data = await fetchJson(`${JIKAN_BASE}/anime?q=${encodeURIComponent(title)}&limit=1`);
  const meta = mapJikanAnime(data.data?.[0]);
  jikanCache.set(key, meta);
  return meta;
}

async function fetchJikanEpisodes(malId, page = 1) {
  const key = cacheKey(["jikan-episodes", String(malId), String(page)]);
  if (jikanCache.has(key)) return jikanCache.get(key);
  const data = await fetchJson(`${JIKAN_BASE}/anime/${encodeURIComponent(malId)}/episodes?page=${page}`);
  const items = (data.data || []).map((episode) => ({
    provider: "jikan",
    id: String(episode.mal_id || episode.episode_id || episode.title),
    number: episode.mal_id || episode.episode_id || null,
    title: episode.title || `Episode ${episode.mal_id || "?"}`,
    titleJapanese: episode.title_japanese || null,
    titleRomanji: episode.title_romanji || null,
    aired: episode.aired || null,
    score: episode.score || null,
    filler: !!episode.filler,
    recap: !!episode.recap,
    forumUrl: episode.forum_url || null
  }));
  const result = { items, hasNextPage: !!data.pagination?.has_next_page };
  jikanCache.set(key, result);
  return result;
}

function decodeXml(text) {
  return (text || "")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&#(\d+);/g, (_, dec) => String.fromCharCode(Number(dec)));
}

function getTag(block, tag) {
  const match = block.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)<\\/${tag}>`, "i"));
  return match ? decodeXml(match[1].replace(/<[^>]+>/g, "").trim()) : null;
}

function parseAniDbEpisodes(xml) {
  const out = [];
  const re = /<episode\b[^>]*>([\s\S]*?)<\/episode>/gi;
  let match;
  while ((match = re.exec(xml || "")) !== null) {
    const block = match[1];
    const number = getTag(block, "epno");
    const englishTitle = block.match(/<title[^>]+xml:lang="en"[^>]*>([\s\S]*?)<\/title>/i);
    const romanizedTitle = block.match(/<title[^>]+xml:lang="x-jat"[^>]*>([\s\S]*?)<\/title>/i);
    out.push({
      provider: "anidb",
      id: match[0].match(/id="([^"]+)"/i)?.[1] || number || String(out.length + 1),
      number,
      title: englishTitle ? decodeXml(englishTitle[1]) : romanizedTitle ? decodeXml(romanizedTitle[1]) : `Episode ${number}`,
      titleRomanji: romanizedTitle ? decodeXml(romanizedTitle[1]) : null,
      aired: getTag(block, "airdate"),
      duration: getTag(block, "length") ? `${getTag(block, "length")} min` : null,
      score: getTag(block, "rating") ? Number(getTag(block, "rating")) : null
    });
  }
  return out;
}

async function fetchAniDbEpisodes(anidbId) {
  const client = process.env.ANIDB_CLIENT;
  const clientver = process.env.ANIDB_CLIENTVER;
  if (!client || !clientver || !anidbId) return null;

  const key = cacheKey(["anidb", String(anidbId)]);
  if (anidbCache.has(key)) return anidbCache.get(key);
  const url = `http://api.anidb.net:9001/httpapi?client=${encodeURIComponent(client.toLowerCase())}&clientver=${encodeURIComponent(clientver)}&protover=1&request=anime&aid=${encodeURIComponent(anidbId)}`;
  const xml = await fetchText(url);
  const result = { items: parseAniDbEpisodes(xml), hasNextPage: false };
  anidbCache.set(key, result);
  return result;
}

async function showMetadata(title) {
  return searchJikanAnime(title);
}

async function episodeMetadata({ title, malId, anidbId }) {
  const anidb = await fetchAniDbEpisodes(anidbId).catch(() => null);
  if (anidb?.items?.length) return { provider: "anidb", ...anidb };

  const resolvedMalId = malId || (title ? (await searchJikanAnime(title))?.malId : null);
  if (!resolvedMalId) return { provider: "none", items: [], hasNextPage: false };
  const jikan = await fetchJikanEpisodes(resolvedMalId);
  return { provider: "jikan", ...jikan };
}

module.exports = {
  showMetadata,
  episodeMetadata
};
