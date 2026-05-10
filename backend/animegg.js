const SOURCE = {
  id: "animegg",
  name: "AnimeGG",
  baseUrl: "https://animegg.org"
};

const UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36";

async function requestText(url, extraHeaders = {}) {
  const headers = {
    "User-Agent": UA,
    Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
    Referer: `${SOURCE.baseUrl}/`,
    ...extraHeaders
  };
  const res = await fetch(url, { headers });
  if (!res.ok) throw new Error(`HTTP ${res.status} from ${url}`);
  return res.text();
}

function decodeHtml(s) {
  return (s || "")
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#039;|&#39;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, d) => String.fromCharCode(+d));
}

function cleanText(s) {
  return decodeHtml((s || "").replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function makeAnime(id, title, cover, extra = {}) {
  return {
    id,
    sourceId: SOURCE.id,
    title,
    subtitle: extra.subtitle || "AnimeGG",
    cover: cover || null,
    banner: cover || null,
    year: extra.year || null,
    score: null,
    genres: extra.genres || [],
    status: extra.status || null,
    progress: "0 / ?",
    synopsis: extra.synopsis || "",
    pageUrl: `${SOURCE.baseUrl}/series/${id}`
  };
}

// ── Parsers ──────────────────────────────────────────────────────────────────

function parseSearchCards(html) {
  const items = [];
  const seen = new Set();
  const re = /<a\s+href="\/series\/([^"/?]+)"\s+class="mse">([\s\S]*?)<\/a>/gi;
  let m;
  while ((m = re.exec(html)) !== null) {
    const id = m[1];
    if (!id || seen.has(id)) continue;
    seen.add(id);
    const block = m[2];
    const titleM = block.match(/<h2>([^<]+)<\/h2>/i);
    const title = titleM ? cleanText(titleM[1]) : id.replace(/-/g, " ");
    const imgM =
      block.match(/<img[^>]+src="(https?:[^"]+)"[^>]*class="media-object"/i) ||
      block.match(/<img[^>]+class="media-object"[^>]+src="(https?:[^"]+)"/i);
    const cover = imgM ? imgM[1] : null;
    items.push(makeAnime(id, title, cover));
  }
  return items;
}

function parsePopularCards(html) {
  const items = [];
  const seen = new Set();
  // Each card: <div class="img"><img src="COVER">...<div class="rightpop"><a href="/series/SLUG">TITLE</a>
  const cardRe = /<div[^>]*class="img">([\s\S]*?)<\/div>\s*<div[^>]*class="rightpop">([\s\S]*?)<\/div>/gi;
  let m;
  while ((m = cardRe.exec(html)) !== null) {
    const imgBlock = m[1];
    const infoBlock = m[2];
    const slugM = imgBlock.match(/href="\/series\/([^"/?]+)"/i) ||
                  infoBlock.match(/href="\/series\/([^"/?]+)"/i);
    if (!slugM) continue;
    const id = slugM[1];
    if (!id || seen.has(id)) continue;
    seen.add(id);
    const imgM = imgBlock.match(/<img[^>]+src="(https?:[^"]+)"/i);
    const cover = imgM ? imgM[1] : null;
    const titleM = infoBlock.match(/href="\/series\/[^"]+">([^<]+)<\/a>/i);
    const title = titleM ? cleanText(titleM[1]) : id.replace(/-/g, " ");
    items.push(makeAnime(id, title, cover));
  }
  return items;
}

// ── Public API ───────────────────────────────────────────────────────────────

async function search(query, page = 1) {
  const q = (query || "").trim();
  if (!q) return catalog("popular");
  const html = await requestText(
    `${SOURCE.baseUrl}/search/?q=${encodeURIComponent(q)}`
  );
  return { sourceId: SOURCE.id, items: parseSearchCards(html), hasNextPage: false };
}

async function catalog(section = "popular") {
  const html = await requestText(`${SOURCE.baseUrl}/popular-series`);
  return { sourceId: SOURCE.id, section, items: parsePopularCards(html), hasNextPage: false };
}

async function details(id) {
  const url = `${SOURCE.baseUrl}/series/${id}`;
  const html = await requestText(url);

  const titleM = html.match(/<h1>([^<]+)<\/h1>/i);
  const title = titleM ? cleanText(titleM[1]) : id.replace(/-/g, " ");

  const imgM =
    html.match(/<img[^>]+class="media-object"[^>]+src="(https?:[^"]+)"/i) ||
    html.match(/<img[^>]+src="(https?:[^"]+)"[^>]+class="media-object"/i);
  const cover = imgM ? imgM[1] : null;

  const synM = html.match(/<p\s+class="ptext">([\s\S]*?)<\/p>/i);
  const synopsis = synM ? cleanText(synM[1]) : "";

  const genres = [];
  const genreRe = /<a\s+href="\/genre\/[^"]*"[^>]*>([^<]+)<\/a>/gi;
  let gm;
  while ((gm = genreRe.exec(html)) !== null) {
    const g = cleanText(gm[1]);
    if (g && !genres.includes(g)) genres.push(g);
  }

  const statusM = html.match(
    /<p[^>]+class="infoami"[^>]*>[\s\S]*?<span>Status:\s*([^<]+)<\/span>/i
  );
  const status = statusM ? cleanText(statusM[1]) : null;

  return makeAnime(id, title, cover, { synopsis, genres, status });
}

async function episodes(id) {
  const url = `${SOURCE.baseUrl}/series/${id}`;
  const html = await requestText(url);

  const items = [];
  const seen = new Set();

  // Each episode row: <li><div><a href="/SERIES-episode-N" class="anm_det_pop">...</a><i class="anititle">TITLE</i>...</div></li>
  const liRe = /<li>([\s\S]*?)<\/li>/gi;
  let m;
  while ((m = liRe.exec(html)) !== null) {
    const block = m[1];
    const linkM = block.match(/<a\s+href="\/(([^/"]+)-episode-(\d+(?:\.\d+)?))"[^>]*class="anm_det_pop"/i);
    if (!linkM) continue;
    const slug = linkM[1];
    if (seen.has(slug)) continue;
    seen.add(slug);
    const number = parseFloat(linkM[3]);
    const titleM = block.match(/<i\s+class="anititle">([^<]*)<\/i>/i);
    const epTitle = titleM ? cleanText(titleM[1]) : `Episode ${number}`;
    items.push({
      id: slug,
      animeId: id,
      sourceId: SOURCE.id,
      number,
      title: epTitle || `Episode ${number}`,
      duration: null,
      streamUrl: null
    });
  }

  return items.sort((a, b) => a.number - b.number);
}

async function streams(episodeId) {
  const slug = String(episodeId || "").replace(/^\//, "");
  const episodeUrl = `${SOURCE.baseUrl}/${slug}`;
  const html = await requestText(episodeUrl);

  // Extract embed IDs with their sub/dub version
  // Pattern: data-id='EMBED_ID' data-mirror="Animegg" data-version="subbed|dubbed"
  const embedRe = /data-id='(\d+)'[^>]*data-version="(subbed|dubbed)"/gi;
  const embeds = [];
  const seenEmbed = new Set();
  let m;
  while ((m = embedRe.exec(html)) !== null) {
    const embedId = m[1];
    if (seenEmbed.has(embedId)) continue;
    seenEmbed.add(embedId);
    embeds.push({ embedId, version: m[2] });
  }

  if (embeds.length === 0) return [];

  // Subbed first so the iOS player defaults to subbed
  embeds.sort((a, b) => (a.version === "subbed" ? -1 : 1));

  const result = [];
  for (const { embedId, version } of embeds) {
    try {
      const embedHtml = await requestText(`${SOURCE.baseUrl}/embed/${embedId}`, {
        Referer: episodeUrl
      });
      // var videoSources = [{file: "/play/ID/video.mp4?for=TOKEN", label: "360p", ...}, ...];
      const srcM = embedHtml.match(/var videoSources\s*=\s*(\[[\s\S]*?\]);/);
      if (!srcM) continue;
      let sources;
      try {
        // videoSources uses unquoted JS keys — convert to valid JSON first
        const jsonStr = srcM[1]
          .replace(/([{,])\s*([a-zA-Z_$][a-zA-Z0-9_$]*)\s*:/g, '$1"$2":')
          .replace(/'/g, '"');
        sources = JSON.parse(jsonStr);
      } catch { continue; }
      for (const src of sources) {
        if (!src.file) continue;
        const playUrl = src.file.startsWith("http")
          ? src.file
          : `${SOURCE.baseUrl}${src.file}`;
        const qualityLabel = src.label || "SD";
        result.push({
          id: `animegg-${embedId}-${qualityLabel}-${version}`,
          label: `${qualityLabel} (${version})`,
          quality: qualityLabel,
          type: "mp4",
          url: playUrl,
          headers: { Referer: `${SOURCE.baseUrl}/embed/${embedId}` }
        });
      }
    } catch {
      // skip unavailable embeds
    }
  }

  return result;
}

module.exports = { SOURCE, search, catalog, details, episodes, streams };
