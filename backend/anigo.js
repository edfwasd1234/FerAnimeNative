const { execFile } = require("node:child_process");
const { promisify } = require("node:util");

const execFileAsync = promisify(execFile);

const SOURCE = {
  id: "anigo",
  name: "AniGo",
  baseUrl: "https://anigo.to"
};

const PAGE_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
  Referer: `${SOURCE.baseUrl}/`
};

async function requestText(url) {
  const response = await fetch(url, { headers: PAGE_HEADERS });
  if (!response.ok) throw new Error(`${response.status} ${response.statusText} for ${url}`);
  return response.text();
}

function decodeHtml(text) {
  return (text || "")
    .replace(/&amp;/g, "&")
    .replace(/&#038;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#8211;/g, "-")
    .replace(/&#039;|&#39;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, dec) => String.fromCharCode(parseInt(dec, 10)));
}

function cleanText(text) {
  return decodeHtml((text || "").replace(/<script[\s\S]*?<\/script>/gi, " ").replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function absoluteUrl(url) {
  if (!url) return null;
  const value = decodeHtml(String(url).trim());
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith("//")) return `https:${value}`;
  if (value.startsWith("/")) return `${SOURCE.baseUrl}${value}`;
  return `${SOURCE.baseUrl}/${value.replace(/^\/+/, "")}`;
}

function attr(tag, name) {
  const match = (tag || "").match(new RegExp(`\\s${name}=["']([^"']+)["']`, "i"));
  return match ? decodeHtml(match[1]) : null;
}

function slugFromWatchUrl(url) {
  const match = absoluteUrl(url)?.match(/\/watch\/([^/#?]+)/i);
  return match ? match[1] : "";
}

function makeAnime(id, title, cover, extra = {}) {
  return {
    id,
    sourceId: SOURCE.id,
    title,
    subtitle: extra.subtitle || "AniGo",
    cover: absoluteUrl(cover),
    banner: absoluteUrl(extra.banner || cover),
    year: extra.year ? Number.parseInt(String(extra.year), 10) || null : null,
    score: extra.score || null,
    genres: extra.genres || [],
    status: extra.status || "Planned",
    progress: "0 / ?",
    synopsis: extra.synopsis || "",
    pageUrl: `${SOURCE.baseUrl}/watch/${id}`
  };
}

function parseCards(html) {
  const items = [];
  const seen = new Set();
  const re = /<div\s+class=["']unit["'][\s\S]*?<\/div>\s*<\/div>\s*<\/div>/gi;
  let match;

  while ((match = re.exec(html || "")) !== null) {
    const block = match[0];
    const href = attr(block.match(/<a[^>]+href=["'][^"']*\/watch\/[^"']+["'][^>]*>/i)?.[0] || "", "href");
    const id = slugFromWatchUrl(href);
    if (!id || seen.has(id)) continue;
    seen.add(id);

    const imgTag = block.match(/<img[^>]+>/i)?.[0] || "";
    const titleTag = block.match(/<h6[^>]*class=["'][^"']*title[^"']*["'][^>]*>[\s\S]*?<\/h6>/i)?.[0] || "";
    const title = cleanText(titleTag) || cleanText(attr(imgTag, "alt"));
    if (!title) continue;

    const type = cleanText(block.match(/<span\s+class=["']type["'][^>]*>([\s\S]*?)<\/span>/i)?.[1] || "");
    const rating = cleanText(block.match(/<span\s+class=["']rating["'][^>]*>([\s\S]*?)<\/span>/i)?.[1] || "");
    const sub = cleanText(block.match(/<span\s+class=["']sub["'][^>]*>[\s\S]*?<\/svg>\s*([^<]+)<\/span>/i)?.[1] || "");
    const dub = cleanText(block.match(/<span\s+class=["']dub["'][^>]*>[\s\S]*?<\/svg>\s*([^<]+)<\/span>/i)?.[1] || "");
    const languages = [sub ? `Sub ${sub}` : "", dub ? `Dub ${dub}` : ""].filter(Boolean).join(" | ");

    items.push(makeAnime(id, title, attr(imgTag, "src"), {
      subtitle: [languages, type, rating].filter(Boolean).join(" | ") || "AniGo",
      genres: [sub ? "Sub" : "", dub ? "Dub" : ""].filter(Boolean),
      status: "Planned"
    }));
  }

  return items;
}

async function search(query) {
  const q = (query || "").trim();
  const url = q ? `${SOURCE.baseUrl}/browser?keyword=${encodeURIComponent(q)}` : `${SOURCE.baseUrl}/recent`;
  const html = await requestText(url);
  return { sourceId: SOURCE.id, items: parseCards(html), hasNextPage: /rel=["']next["']|page=\d+/i.test(html) };
}

async function catalog(section = "recommended") {
  const routes = {
    recommended: `${SOURCE.baseUrl}/home`,
    trending: `${SOURCE.baseUrl}/home`,
    new: `${SOURCE.baseUrl}/new-releases`,
    action: `${SOURCE.baseUrl}/genres/action`
  };
  const html = await requestText(routes[section] || routes.recommended);
  return { sourceId: SOURCE.id, section, items: parseCards(html), hasNextPage: false };
}

async function details(id) {
  const html = await requestText(`${SOURCE.baseUrl}/watch/${encodeURIComponent(id)}`);
  const title = cleanText(html.match(/<div\s+class=["']title["'][^>]*>([\s\S]*?)<\/div>/i)?.[1] || "") || id;
  const poster = attr(html.match(/<div\s+class=["']poster["'][\s\S]*?<img[^>]+>/i)?.[0] || "", "src");
  const banner = (html.match(/background-image:\s*url\(['"]?([^'")]+)['"]?\)/i) || [])[1];
  const synopsis = cleanText(html.match(/<div\s+class=["']desc["'][^>]*>([\s\S]*?)<\/div>/i)?.[1] || "");
  const genres = [];
  const genreBlock = html.match(/<div\s+class=["']genre["'][^>]*>([\s\S]*?)<\/div>/i)?.[1] || "";
  let genreMatch;
  const genreRe = /<a[^>]+>([\s\S]*?)<\/a>/gi;
  while ((genreMatch = genreRe.exec(genreBlock)) !== null) {
    const genre = cleanText(genreMatch[1]);
    if (genre && !genres.includes(genre)) genres.push(genre);
  }

  const meta = cleanText(html.match(/<div\s+class=["']aniMeta["'][^>]*>([\s\S]*?)<\/div>/i)?.[1] || "");
  const year = cleanText(html.match(/Premiered:[\s\S]*?year=([0-9]{4})/i)?.[1] || "");
  const status = cleanText(html.match(/Status:\s*<span>([^<]+)/i)?.[1] || "");

  return makeAnime(id, title, poster, {
    banner,
    synopsis,
    genres,
    year,
    status: status || "Planned",
    subtitle: meta || "AniGo"
  });
}

async function episodes(itemId) {
  const watchUrl = `${SOURCE.baseUrl}/watch/${encodeURIComponent(itemId)}`;
  const html = await renderDom(watchUrl).catch(() => "");
  const out = parseRenderedEpisodes(html, itemId);
  if (out.length) return out;

  const detail = await details(itemId);
  const count = Number.parseInt((detail.subtitle || detail.progress || "").match(/Episodes:\s*([0-9]+)/i)?.[1] || "", 10);
  if (!Number.isFinite(count) || count <= 0) return [];
  return Array.from({ length: count }, (_, index) => makeEpisode(itemId, index + 1, String(index + 1), `Episode ${index + 1}`));
}

function parseRenderedEpisodes(html, itemId) {
  const out = [];
  const seen = new Set();
  const re = /<a[^>]+href=["'][^"']*#ep=([^"']+)["'][^>]*>[\s\S]*?<span\s+class=["']number["'][^>]*>([\s\S]*?)<\/span>[\s\S]*?<span\s+class=["']name["'][^>]*>([\s\S]*?)<\/span>/gi;
  let match;

  while ((match = re.exec(html || "")) !== null) {
    const slug = cleanText(match[1]);
    const label = cleanText(match[2]);
    const title = cleanText(match[3]) || `Episode ${label || slug}`;
    const number = Number.parseFloat(label || slug);
    const key = `${slug}:${label}`;
    if (!slug || seen.has(key) || Number.isNaN(number)) continue;
    seen.add(key);
    out.push(makeEpisode(itemId, number, slug, title));
  }

  return out.sort((a, b) => a.number - b.number);
}

function makeEpisode(itemId, number, slug, title) {
  return {
    id: `${itemId}|${slug}`,
    animeId: itemId,
    sourceId: SOURCE.id,
    number,
    title,
    duration: "AniGo"
  };
}

async function streams(episodeId) {
  const [itemId, slug = "1"] = String(episodeId || "").split("|");
  const watchUrl = `${SOURCE.baseUrl}/watch/${encodeURIComponent(itemId)}#ep=${encodeURIComponent(slug)}`;
  const html = await renderDom(watchUrl).catch(() => "");
  const iframe = attr(html.match(/<iframe[^>]+src=["'][^"']+["'][^>]*>/i)?.[0] || "", "src");
  const url = absoluteUrl(iframe) || watchUrl;
  return [{
    id: "anigo-embed-0",
    label: "AniGo Embed",
    quality: "auto",
    type: "iframe",
    url,
    headers: { Referer: `${SOURCE.baseUrl}/watch/${itemId}` }
  }];
}

async function renderDom(url) {
  const edge = findEdgeBinary();
  if (!edge) throw new Error("AniGo rendered data requires Microsoft Edge or Chrome on this machine.");
  const profile = `${process.cwd()}\\.edge-anigo-render-${Date.now()}-${Math.round(Math.random() * 100000)}`;
  const { stdout } = await execFileAsync(edge, [
    "--headless=new",
    "--disable-gpu",
    "--dump-dom",
    "--virtual-time-budget=10000",
    `--user-data-dir=${profile}`,
    url
  ], { maxBuffer: 20 * 1024 * 1024, timeout: 30000 });
  return stdout;
}

function findEdgeBinary() {
  const candidates = [
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe"
  ];
  const fs = require("node:fs");
  return candidates.find((path) => fs.existsSync(path));
}

module.exports = {
  SOURCE,
  search,
  catalog,
  details,
  episodes,
  streams
};
