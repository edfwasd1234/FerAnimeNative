const SOURCE = {
  id: "anizone",
  name: "AniZone",
  baseUrl: "https://anizone.to"
};

const PAGE_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
  Referer: `${SOURCE.baseUrl}/`
};

async function requestText(url, headers = {}) {
  const response = await fetch(url, { headers: { ...PAGE_HEADERS, ...headers } });
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText} for ${url}`);
  }
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

function attr(html, name) {
  const re = new RegExp(`\\b${name}=['"]([^'"]+)['"]`, "i");
  const match = (html || "").match(re);
  return match ? decodeHtml(match[1]) : "";
}

function absoluteUrl(url, base = SOURCE.baseUrl) {
  if (!url) return null;
  const value = decodeHtml(String(url).trim());
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith("//")) return `https:${value}`;
  try {
    return new URL(value, base).toString();
  } catch {
    return `${SOURCE.baseUrl}/${value.replace(/^\/+/, "")}`;
  }
}

function idFromUrl(url) {
  if (url && !String(url).includes("/") && !String(url).startsWith("http")) return String(url).trim();
  const value = absoluteUrl(url);
  if (!value) return "";
  const match = value.match(/\/anime\/([^/?#]+)(?:\/|$)/i);
  return match ? match[1] : value.replace(SOURCE.baseUrl, "").replace(/^\/+/, "");
}

function mediaKindFromText(text) {
  const haystack = cleanText(text).toLowerCase();
  if (/\bdub\b|english dub|\(dub\)/i.test(haystack)) return "Dub";
  if (/\bsub\b|english sub|\(sub\)/i.test(haystack)) return "Sub";
  return "Sub";
}

function makeAnime({ id, title, image, subtitle, synopsis = "", genres = [], year = null, status = "Planned", pageUrl }) {
  const uniqueGenres = [...new Set(genres.filter(Boolean))];
  const audio = mediaKindFromText(`${title} ${subtitle} ${uniqueGenres.join(" ")}`);
  if (!uniqueGenres.includes(audio)) uniqueGenres.unshift(audio);
  return {
    id,
    sourceId: SOURCE.id,
    title,
    subtitle: subtitle || `${audio} | AniZone`,
    cover: absoluteUrl(image),
    banner: absoluteUrl(image),
    year,
    score: null,
    genres: uniqueGenres,
    status,
    progress: "0 / ?",
    synopsis,
    pageUrl: pageUrl || `${SOURCE.baseUrl}/anime/${encodeURIComponent(id)}`
  };
}

function parseAnimeCards(html) {
  const out = [];
  const seen = new Set();
  const cardRe = /<div\b[^>]*wire:key=['"]a-[^'"]+['"][\s\S]*?(?=<div\b[^>]*wire:key=['"]a-|<\/div>\s*<!--[if ENDBLOCK]|$)/gi;
  let cardM;

  while ((cardM = cardRe.exec(html || "")) !== null) {
    const block = cardM[0];
    const href = attr(block.match(/<a\b[\s\S]*?>/i)?.[0] || "", "href");
    const id = idFromUrl(href);
    if (!id || seen.has(id)) continue;
    const title = attr(block.match(/<a\b[\s\S]*?>/i)?.[0] || "", "title") || cleanText(block.match(/<a\b[^>]*>([\s\S]*?)<\/a>/i)?.[1] || "");
    if (!title || title.length < 2) continue;
    const image = attr(block.match(/<img\b[\s\S]*?>/i)?.[0] || "", "src") || attr(block.match(/<img\b[\s\S]*?>/i)?.[0] || "", "data-src");
    const meta = cleanText(block.match(/<div\b[^>]*class=['"][^'"]*text-xs[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i)?.[1] || "");
    const year = Number.parseInt(meta.match(/\b(19|20)\d{2}\b/)?.[0] || "", 10) || null;
    const status = /completed/i.test(meta) ? "Completed" : /ongoing|airing/i.test(meta) ? "Watching" : "Planned";
    const audio = mediaKindFromText(`${title} ${block}`);
    seen.add(id);
    out.push(makeAnime({
      id,
      title,
      image,
      subtitle: `${audio} | ${meta || "AniZone"}`,
      genres: [audio],
      year,
      status,
      pageUrl: absoluteUrl(href)
    }));
  }

  if (out.length) return out;

  const anchorRe = /<a\b[^>]*href=['"]([^'"]*\/anime\/[^'"]+)['"][^>]*>[\s\S]*?<\/a>/gi;
  let match;

  while ((match = anchorRe.exec(html || "")) !== null) {
    const block = match[0];
    const href = absoluteUrl(match[1]);
    const id = idFromUrl(href);
    if (!id || seen.has(id)) continue;

    const title = attr(block, "title") || cleanText(block.match(/<h[1-6][^>]*>([\s\S]*?)<\/h[1-6]>/i)?.[1] || "");
    if (!title || title.length < 2) continue;

    const image = attr(block.match(/<img\b[\s\S]*?>/i)?.[0] || "", "src") || attr(block.match(/<img\b[\s\S]*?>/i)?.[0] || "", "data-src");
    const audio = mediaKindFromText(`${title} ${block}`);
    seen.add(id);
    out.push(makeAnime({
      id,
      title,
      image,
      subtitle: `${audio} | AniZone`,
      genres: [audio],
      pageUrl: href
    }));
  }

  return out;
}

async function search(query, page = 1) {
  const q = (query || "").trim();
  const url = `${SOURCE.baseUrl}/anime?search=${encodeURIComponent(q)}&page=${Number(page) || 1}`;
  const html = await requestText(url);
  return { sourceId: SOURCE.id, items: parseAnimeCards(html), hasNextPage: html.includes(`page=${Number(page) + 1}`) };
}

async function catalog(section = "recommended") {
  const routes = {
    recommended: `${SOURCE.baseUrl}/anime?page=1`,
    trending: `${SOURCE.baseUrl}/anime?page=1`,
    new: `${SOURCE.baseUrl}/anime?page=1`,
    action: `${SOURCE.baseUrl}/anime?genres=Action&page=1`
  };
  const html = await requestText(routes[section] || routes.recommended);
  return { sourceId: SOURCE.id, section, items: parseAnimeCards(html), hasNextPage: html.includes("page=2") };
}

async function details(id) {
  const showId = idFromUrl(id);
  const pageUrl = id.startsWith("http") ? id : `${SOURCE.baseUrl}/anime/${showId}`;
  const html = await requestText(pageUrl);
  const title =
    cleanText(html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i)?.[1] || "") ||
    cleanText(html.match(/<title[^>]*>([\s\S]*?)<\/title>/i)?.[1] || "").replace(/\s*-\s*AniZone.*$/i, "") ||
    id;
  const image =
    attr(html.match(/<meta[^>]+property=['"]og:image['"][^>]*>/i)?.[0] || "", "content") ||
    attr(html.match(/<img\b[\s\S]*?>/i)?.[0] || "", "src");
  const synopsis =
    cleanText(html.match(/<meta[^>]+name=['"]description['"][^>]+content=['"]([^'"]+)['"]/i)?.[1] || "") ||
    cleanText(html.match(/<p[^>]*>([\s\S]*?)<\/p>/i)?.[1] || "");
  const genres = [];
  const tagRe = /href=['"][^'"]*(?:genre|genres|anime\?genres=)[^'"]*['"][^>]*>([\s\S]*?)<\/a>/gi;
  let tagM;
  while ((tagM = tagRe.exec(html || "")) !== null) {
    const genre = cleanText(tagM[1]);
    if (genre && !genres.includes(genre)) genres.push(genre);
  }
  const audio = mediaKindFromText(html);

  return makeAnime({
    id: showId || idFromUrl(pageUrl) || id,
    title,
    image,
    subtitle: `${audio} | ${genres.slice(0, 2).join(" | ") || "AniZone"}`,
    genres: [audio, ...genres],
    synopsis,
    pageUrl
  });
}

async function episodes(itemId) {
  const showId = idFromUrl(itemId) || itemId.split("/").filter(Boolean).pop() || itemId;
  const url = `${SOURCE.baseUrl}/anime/${showId}/1`;
  const html = await requestText(url);
  const out = [];
  const seen = new Set();
  const linkRe = /<a\b[^>]*href=['"]([^'"]*\/anime\/[^'"]+\/\d+[^'"]*)['"][^>]*class=['"][^'"]*\bblock\b[^'"]*['"][^>]*>[\s\S]*?<\/a>/gi;
  let match;

  while ((match = linkRe.exec(html || "")) !== null) {
    const block = match[0];
    const href = absoluteUrl(match[1], url);
    if (!href || seen.has(href)) continue;
    seen.add(href);

    const epMatch = href.match(/\/(\d+)(?:[/?#]|$)/);
    const number = epMatch ? Number(epMatch[1]) : out.length + 1;
    const title = cleanText(block.match(/<div[^>]*>([\s\S]*?)<\/div>\s*<\/a>$/i)?.[1] || "") || `Episode ${number}`;
    const audio = mediaKindFromText(`${title} ${block}`);

    out.push({
      id: href,
      animeId: showId,
      sourceId: SOURCE.id,
      number,
      title: `${title} (${audio})`,
      duration: audio
    });
  }

  if (!out.length && /<media-player\b/i.test(html)) {
    out.push({
      id: url,
      animeId: showId,
      sourceId: SOURCE.id,
      number: 1,
      title: `Episode 1 (${mediaKindFromText(html)})`,
      duration: mediaKindFromText(html)
    });
  }

  return out.sort((a, b) => a.number - b.number);
}

function pushStream(out, seen, url, pageUrl, label, audio) {
  const clean = absoluteUrl(url, pageUrl);
  if (!clean || seen.has(clean)) return;
  seen.add(clean);
  const isHls = /\.m3u8(?:[?#]|$)/i.test(clean);
  const isMp4 = /\.mp4(?:[?#]|$)/i.test(clean);
  out.push({
    id: `anizone-${out.length}`,
    label,
    quality: `${audio} | auto`,
    type: isHls ? "hls" : isMp4 ? "mp4" : "iframe",
    url: clean,
    headers: { Referer: pageUrl, ...PAGE_HEADERS }
  });
}

async function streams(episodeId) {
  const pageUrl = episodeId.startsWith("http") ? episodeId : absoluteUrl(episodeId);
  const html = await requestText(pageUrl);
  const out = [];
  const seen = new Set();
  const audio = mediaKindFromText(html);
  const serverLabel =
    cleanText(html.match(/class=['"][^'"]*bg-teal-600[^'"]*['"][^>]*>([\s\S]*?)<\/[^>]+>/i)?.[1] || "") ||
    `${audio} - AniZone`;

  const mediaRe = /<media-player\b[^>]*>/gi;
  let mediaM;
  while ((mediaM = mediaRe.exec(html || "")) !== null) {
    const src = attr(mediaM[0], "src");
    if (src) pushStream(out, seen, src, pageUrl, `${serverLabel} - Multi`, audio);
  }

  const directRe = /https?:\/\/[^"'<>\\\s]+\.(?:m3u8|mp4)[^"'<>\\\s]*/gi;
  let directM;
  while ((directM = directRe.exec(html || "")) !== null) {
    pushStream(out, seen, directM[0], pageUrl, `${serverLabel} - Direct`, audio);
  }

  const tracks = [];
  const trackRe = /<track\b[^>]*>/gi;
  let trackM;
  while ((trackM = trackRe.exec(html || "")) !== null) {
    if (attr(trackM[0], "kind") !== "subtitles") continue;
    const src = absoluteUrl(attr(trackM[0], "src"), pageUrl);
    if (!src) continue;
    tracks.push({ url: src, lang: attr(trackM[0], "srclang") || attr(trackM[0], "label") || "en" });
  }

  return out.map((stream) => (tracks.length ? { ...stream, subtitles: tracks } : stream));
}

module.exports = {
  SOURCE,
  search,
  catalog,
  details,
  episodes,
  streams
};
