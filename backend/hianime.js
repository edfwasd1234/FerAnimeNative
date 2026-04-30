const SOURCE = {
  id: "hianime",
  name: "HiAnime",
  baseUrl: "https://hianime.city"
};

const PAGE_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
  Referer: `${SOURCE.baseUrl}/`
};

async function requestText(url) {
  const response = await fetch(url, { headers: PAGE_HEADERS });
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText} for ${url}`);
  }
  return response.text();
}

async function requestTextWithHeaders(url, referer = SOURCE.baseUrl) {
  const response = await fetch(url, {
    headers: {
      ...PAGE_HEADERS,
      Referer: referer,
      "X-Requested-With": "XMLHttpRequest"
    }
  });
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

function absoluteUrl(url) {
  if (!url) return null;
  const value = decodeHtml(String(url).trim());
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith("//")) return `https:${value}`;
  if (value.startsWith("/")) return `${SOURCE.baseUrl}${value}`;
  return `${SOURCE.baseUrl}/${value.replace(/^\/+/, "")}`;
}

function absoluteUrlFor(base, url) {
  if (!url) return null;
  const value = decodeHtml(String(url).trim());
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith("//")) return `https:${value}`;
  try {
    return new URL(value, base).toString();
  } catch {
    return absoluteUrl(value);
  }
}

function attr(tag, name) {
  if (!tag) return null;
  const match = tag.match(new RegExp(`\\s${name}=["']([^"']+)["']`, "i"));
  return match ? decodeHtml(match[1]) : null;
}

function imageFromTag(tag) {
  const raw = attr(tag, "data-src") || attr(tag, "data-lazy-src") || attr(tag, "src");
  if (!raw || /^data:/i.test(raw)) return null;
  return absoluteUrl(raw);
}

function pushDirectUrl(out, seen, url, referer, label = "HiAnime Direct") {
  const clean = absoluteUrlFor(referer, url);
  if (!clean || seen.has(clean) || !/\.(?:m3u8|mp4)(?:[?#]|$)/i.test(clean)) return;
  seen.add(clean);
  out.push({
    id: `hianime-direct-${out.length}`,
    label: clean.includes(".m3u8") ? `${label} HLS` : `${label} MP4`,
    quality: clean.includes("/dub") ? "dub" : clean.includes("/sub") ? "sub" : "auto",
    type: clean.includes(".m3u8") ? "hls" : "mp4",
    url: clean,
    headers: { Referer: referer }
  });
}

function extractDirectStreamsFromText(text, referer, out, seen, label) {
  const directRe = /https?:\/\/[^"'<>\\\s]+\.(?:m3u8|mp4)[^"'<>\\\s]*/gi;
  let match;
  while ((match = directRe.exec(text || "")) !== null) {
    pushDirectUrl(out, seen, match[0], referer, label);
  }

  const jsonishRe = /(?:file|url|src)\s*[:=]\s*["']([^"']+\.(?:m3u8|mp4)[^"']*)["']/gi;
  while ((match = jsonishRe.exec(text || "")) !== null) {
    pushDirectUrl(out, seen, match[1], referer, label);
  }
}

function extractIframeUrls(html, pageUrl) {
  const embeds = [];
  const iframeRe = /<iframe[^>]+(?:data-litespeed-src|src)=["']([^"']+)["'][^>]*>/gi;
  let match;
  while ((match = iframeRe.exec(html || "")) !== null) {
    const url = absoluteUrlFor(pageUrl, match[1]);
    if (url) embeds.push(url);
  }
  return embeds;
}

async function tryProbeSourceEndpoints(pageUrl, html, out, seen) {
  const ids = new Set();
  for (const pattern of [/data-id=["']([^"']+)["']/gi, /data-realid=["']([^"']+)["']/gi, /data-mediaid=["']([^"']+)["']/gi, /cid:\s*["']?([^"',\s]+)["']?/gi]) {
    let match;
    while ((match = pattern.exec(html || "")) !== null) ids.add(match[1]);
  }

  const base = new URL(pageUrl);
  const domain2 = html.match(/domain2_url:\s*['"]([^'"]+)['"]/i)?.[1];
  const origins = [base.origin, domain2].filter(Boolean).map((value) => value.replace(/\/$/, ""));
  const paths = [
    (id) => `/ajax/sources/${id}`,
    (id) => `/ajax/episode/sources/${id}`,
    (id) => `/ajax/episode/sources?id=${id}`,
    (id) => `/ajax/embed/getSources?id=${id}`,
    (id) => `/ajax/getSources?id=${id}`,
    (id) => `/api/source/${id}`
  ];

  for (const id of ids) {
    for (const origin of origins) {
      for (const toPath of paths) {
        try {
          const endpoint = `${origin}${toPath(id)}`;
          const body = await requestTextWithHeaders(endpoint, pageUrl);
          if (/^\s*</.test(body)) continue;
          extractDirectStreamsFromText(body, endpoint, out, seen, "HiAnime API");
        } catch {
          // These hosts change endpoint names often; failed probes should not block embed playback.
        }
      }
    }
  }
}

async function collectDirectStreamsFromEmbed(embedUrl, out, seen, depth = 0, referer = SOURCE.baseUrl) {
  if (depth > 2 || !embedUrl) return;
  try {
    const html = await requestTextWithHeaders(embedUrl, referer);
    extractDirectStreamsFromText(html, embedUrl, out, seen, "HiAnime Player");
    await tryProbeSourceEndpoints(embedUrl, html, out, seen);
    if (out.length) return;
    for (const nested of extractIframeUrls(html, embedUrl)) {
      await collectDirectStreamsFromEmbed(nested, out, seen, depth + 1, embedUrl);
      if (out.length) return;
    }
  } catch {
    // Keep the original iframe fallback when direct extraction is blocked.
  }
}

async function collectNestedEmbeds(embedUrl, out, seen, depth = 0, referer = SOURCE.baseUrl) {
  if (depth > 2 || !embedUrl) return;
  try {
    const html = await requestTextWithHeaders(embedUrl, referer);
    for (const nested of extractIframeUrls(html, embedUrl)) {
      if (!seen.has(nested)) {
        seen.add(nested);
        out.push(nested);
      }
      await collectNestedEmbeds(nested, out, seen, depth + 1, embedUrl);
    }
  } catch {
    // Nested embeds are optional; the first embed remains the fallback.
  }
}

async function isLiveIframeUrl(url, referer = SOURCE.baseUrl) {
  if (!url) return false;
  try {
    const response = await fetch(url, {
      headers: {
        ...PAGE_HEADERS,
        Referer: referer
      },
      redirect: "manual"
    });
    return response.status >= 200 && response.status < 400;
  } catch {
    return false;
  }
}

function slugFromSeriesUrl(url) {
  const match = absoluteUrl(url)?.match(/\/series\/([^/]+)\//i);
  return match ? match[1] : "";
}

function parseCards(html) {
  const items = [];
  const seen = new Set();
  const re = /<article\s+class="bs"[\s\S]*?<\/article>/gi;
  let match;

  while ((match = re.exec(html || "")) !== null) {
    const block = match[0];
    const hrefM = block.match(/<a\s+href="([^"]+\/series\/[^"]+)"[^>]*title="([^"]+)"/i);
    if (!hrefM) continue;

    const id = slugFromSeriesUrl(hrefM[1]);
    if (!id || seen.has(id)) continue;
    seen.add(id);

    const imgTag = block.match(/<img[^>]+>/i)?.[0] || "";
    const statusM = block.match(/<div\s+class="status[^"]*">([^<]+)<\/div>/i);
    const typeM = block.match(/<div\s+class="typez[^"]*">([^<]+)<\/div>/i);
    const langM = block.match(/<span\s+class="sb\s+([^"]+)">([^<]+)<\/span>/i);
    const title = cleanText(hrefM[2]);
    const language = langM ? cleanText(langM[2]) : title.toLowerCase().includes("(dub)") ? "Dub" : "Sub";

    items.push({
      id,
      sourceId: SOURCE.id,
      title,
      subtitle: `${language} | ${typeM ? cleanText(typeM[1]) : "Anime"}`,
      cover: imageFromTag(imgTag),
      banner: imageFromTag(imgTag),
      year: null,
      score: null,
      genres: [language],
      status: statusM ? cleanText(statusM[1]) : "Planned",
      progress: "0 / ?",
      synopsis: "",
      pageUrl: absoluteUrl(hrefM[1])
    });
  }

  return items;
}

async function search(query) {
  const q = (query || "").trim();
  if (!q) {
    const html = await requestText(`${SOURCE.baseUrl}/`);
    return { sourceId: SOURCE.id, items: parseCards(html), hasNextPage: false };
  }

  const pages = [];
  for (let page = 1; page <= 4; page += 1) {
    try {
      const html = await requestText(searchPageUrl(q, page));
      pages.push(html);
      if (!hasNextPage(html)) break;
    } catch {
      break;
    }
  }

  const seen = new Set();
  const items = pages
    .flatMap(parseCards)
    .filter((item) => {
      if (seen.has(item.id)) return false;
      seen.add(item.id);
      return true;
    });

  return { sourceId: SOURCE.id, items: sortSearchResults(items, q), hasNextPage: pages.some(hasNextPage) };
}

function searchPageUrl(query, page = 1) {
  const encoded = encodeURIComponent(query);
  if (page > 1) return `${SOURCE.baseUrl}/page/${page}/?s=${encoded}`;
  return `${SOURCE.baseUrl}/?s=${encoded}`;
}

function hasNextPage(html) {
  return /class=["'][^"']*next\s+page-numbers/i.test(html || "") || /\/page\/\d+\/\?s=/i.test(html || "");
}

function normalizeTitleForSearch(value) {
  return cleanText(value)
    .toLowerCase()
    .replace(/\((sub|dub)\)/g, "")
    .replace(/shippuuden/g, "shippuden")
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function sortSearchResults(items, query) {
  const normalizedQuery = normalizeTitleForSearch(query);
  return [...items].sort((a, b) => {
    const aTitle = normalizeTitleForSearch(a.title);
    const bTitle = normalizeTitleForSearch(b.title);
    const aExact = aTitle === normalizedQuery ? 0 : 1;
    const bExact = bTitle === normalizedQuery ? 0 : 1;
    if (aExact !== bExact) return aExact - bExact;
    const aStarts = aTitle.startsWith(normalizedQuery) ? 0 : 1;
    const bStarts = bTitle.startsWith(normalizedQuery) ? 0 : 1;
    if (aStarts !== bStarts) return aStarts - bStarts;
    const aDub = /\bdub\b/i.test(a.title) ? 1 : 0;
    const bDub = /\bdub\b/i.test(b.title) ? 1 : 0;
    if (aDub !== bDub) return aDub - bDub;
    return a.title.localeCompare(b.title);
  });
}

async function catalog(section = "recommended") {
  const routes = {
    recommended: `${SOURCE.baseUrl}/series/?status=&type=&order=popular`,
    trending: `${SOURCE.baseUrl}/series/?status=&type=&order=popular`,
    new: `${SOURCE.baseUrl}/`,
    action: `${SOURCE.baseUrl}/genres/action/`
  };
  const html = await requestText(routes[section] || routes.recommended);
  return { sourceId: SOURCE.id, section, items: parseCards(html), hasNextPage: false };
}

async function details(id) {
  const url = `${SOURCE.baseUrl}/series/${encodeURIComponent(id)}/`;
  const html = await requestText(url);
  const titleM = html.match(/<h1\s+class="entry-title"[^>]*>([\s\S]*?)<\/h1>/i);
  const descM = html.match(/<div\s+class="mindesc">([\s\S]*?)<\/div>/i);
  const coverTag = html.match(/<img[^>]+class="[^"]*wp-post-image[^"]*"[^>]*>/i)?.[0] || "";
  const bannerTag = html.match(/<div\s+class="bigcover"[\s\S]*?<img[^>]+>/i)?.[0] || "";
  const statusM = html.match(/<b>Status:<\/b>\s*([^<]+)<\/span>/i);
  const releasedM = html.match(/<b>Released:<\/b>\s*([^<]+)<\/span>/i);
  const scoreM = html.match(/<strong>Rating\s+([0-9.]+)<\/strong>/i);
  const typeM = html.match(/<b>Type:<\/b>\s*([^<]+)<\/span>/i);
  const isDub = /(\(Dub\)|-dub\b|\/dub\b)/i.test(`${id} ${titleM ? titleM[1] : ""}`);
  const language = isDub ? "Dub" : "Sub";
  const genres = [language];
  const genreRe = /<div\s+class="genxed">([\s\S]*?)<\/div>/i;
  const genreBlock = html.match(genreRe)?.[1] || "";
  let genreM;
  const linkRe = /<a[^>]+>([^<]+)<\/a>/g;
  while ((genreM = linkRe.exec(genreBlock)) !== null) {
    const genre = cleanText(genreM[1]);
    if (genre && !genres.includes(genre)) genres.push(genre);
  }

  return {
    id,
    sourceId: SOURCE.id,
    title: titleM ? cleanText(titleM[1]) : id,
    subtitle: `${language} | ${typeM ? cleanText(typeM[1]) : "Anime"}`,
    cover: imageFromTag(coverTag),
    banner: imageFromTag(bannerTag) || imageFromTag(coverTag),
    year: releasedM ? Number.parseInt(cleanText(releasedM[1]), 10) || null : null,
    score: scoreM ? Math.round(Number.parseFloat(scoreM[1]) * 10) : null,
    genres,
    status: statusM ? cleanText(statusM[1]) : "Planned",
    progress: "0 / ?",
    synopsis: descM ? cleanText(descM[1]) : "",
    pageUrl: url
  };
}

async function episodes(itemId) {
  const html = await requestText(`${SOURCE.baseUrl}/series/${encodeURIComponent(itemId)}/`);
  const titleM = html.match(/<h1\s+class="entry-title"[^>]*>([\s\S]*?)<\/h1>/i);
  const seriesTitle = titleM ? cleanText(titleM[1]) : itemId;
  const language = /(\(Dub\)|-dub\b)/i.test(`${itemId} ${seriesTitle}`) ? "Dub" : "Sub";
  const out = parseEpisodesFromHtml(html, itemId, language);
  if (out.length) return out;

  return findEpisodeFallback(itemId, seriesTitle, language);
}

function parseEpisodesFromHtml(html, itemId, language) {
  const out = [];
  const re = /<li\s+data-index="[^"]*">\s*<a\s+href="([^"]+)"[^>]*>\s*<div\s+class="epl-num">([\s\S]*?)<\/div>\s*<div\s+class="epl-title">([\s\S]*?)<\/div>/gi;
  let match;

  while ((match = re.exec(html || "")) !== null) {
    const href = absoluteUrl(match[1]);
    const label = cleanText(match[2]);
    const title = cleanText(match[3]) || `Episode ${label}`;
    const numeric = Number.parseFloat(label.replace(/[^0-9.]/g, ""));
    out.push({
      id: encodeURIComponent(href),
      animeId: itemId,
      sourceId: SOURCE.id,
      number: Number.isNaN(numeric) ? out.length + 1 : numeric,
      title: `${title} (${language})`,
      duration: language
    });
  }

  return out.sort((a, b) => a.number - b.number);
}

async function findEpisodeFallback(itemId, seriesTitle, language) {
  const queries = [...new Set([
    seriesTitle,
    seriesTitle.replace(/shippuden/gi, "shippuuden"),
    seriesTitle.replace(/shippuuden/gi, "shippuden")
  ].map((value) => cleanText(value).replace(/\((sub|dub)\)/gi, "").trim()).filter(Boolean))];

  const originalTitle = normalizeTitleForSearch(seriesTitle);
  const candidates = [];
  for (const query of queries) {
    try {
      const result = await search(query);
      candidates.push(...result.items);
    } catch {
      // Empty primary pages are common during source churn; just keep trying nearby IDs.
    }
  }

  const seen = new Set();
  const ranked = candidates
    .filter((item) => {
      if (!item.id || item.id === itemId || seen.has(item.id)) return false;
      seen.add(item.id);
      if (!/movie/i.test(seriesTitle) && /movie/i.test(item.title)) return false;
      return normalizeTitleForSearch(item.title) === originalTitle;
    })
    .sort((a, b) => {
      const aLanguage = /\bdub\b/i.test(a.title) ? "Dub" : "Sub";
      const bLanguage = /\bdub\b/i.test(b.title) ? "Dub" : "Sub";
      if (aLanguage === language && bLanguage !== language) return -1;
      if (bLanguage === language && aLanguage !== language) return 1;
      return a.title.localeCompare(b.title);
    });

  for (const candidate of ranked) {
    try {
      const html = await requestText(`${SOURCE.baseUrl}/series/${encodeURIComponent(candidate.id)}/`);
      const fallbackLanguage = /(\(Dub\)|-dub\b)/i.test(`${candidate.id} ${candidate.title}`) ? "Dub" : "Sub";
      const out = parseEpisodesFromHtml(html, itemId, fallbackLanguage);
      if (out.length) return out;
    } catch {
      // Try the next nearby candidate.
    }
  }

  return [];
}

async function streams(episodeId) {
  const episodeUrl = decodeURIComponent(episodeId);
  const html = await requestText(episodeUrl);
  const embeds = [];
  const directM = html.match(/<iframe[^>]+data-litespeed-src="([^"]+)"/i) || html.match(/<iframe[^>]+src="([^"]+)"/i);
  if (directM) embeds.push(absoluteUrlFor(episodeUrl, directM[1]));

  const optionRe = /<option[^>]+value="([^"]+)"[^>]*>([\s\S]*?)<\/option>/gi;
  let optionM;
  while ((optionM = optionRe.exec(html)) !== null) {
    try {
      const decoded = Buffer.from(decodeHtml(optionM[1]), "base64").toString("utf8");
      const srcM = decoded.match(/src="([^"]+)"/i);
      if (srcM) embeds.push(absoluteUrlFor(episodeUrl, srcM[1]));
    } catch {
      // Ignore malformed mirror values.
    }
  }

  const seenDirect = new Set();
  const directStreams = [];
  extractDirectStreamsFromText(html, episodeUrl, directStreams, seenDirect, "HiAnime Page");
  for (const embed of [...new Set(embeds)]) {
    await collectDirectStreamsFromEmbed(embed, directStreams, seenDirect, 0, episodeUrl);
    if (directStreams.length) break;
  }
  const seenEmbeds = new Set(embeds);
  for (const embed of [...new Set(embeds)]) {
    await collectNestedEmbeds(embed, embeds, seenEmbeds, 0, episodeUrl);
  }

  const liveEmbeds = [];
  for (const embed of [...new Set(embeds)]) {
    if (await isLiveIframeUrl(embed, episodeUrl)) liveEmbeds.push(embed);
  }

  const embedStreams = liveEmbeds.map((url, index) => ({
    id: `hianime-embed-${index}`,
    label: index === 0 ? "HiAnime Embed" : `HiAnime Mirror ${index + 1}`,
    quality: url.includes("/dub") ? "dub" : url.includes("/sub") ? "sub" : "auto",
    type: "iframe",
    url,
    headers: { Referer: SOURCE.baseUrl }
  }));

  return [...directStreams, ...embedStreams];
}

module.exports = {
  SOURCE,
  search,
  catalog,
  details,
  episodes,
  streams
};
