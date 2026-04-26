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

    const imgM = block.match(/<img[^>]+(?:data-src|src)="([^"]+)"[^>]*>/i);
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
      cover: absoluteUrl(imgM ? imgM[1] : null),
      banner: absoluteUrl(imgM ? imgM[1] : null),
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
  const url = q ? `${SOURCE.baseUrl}/?s=${encodeURIComponent(q)}` : `${SOURCE.baseUrl}/`;
  const html = await requestText(url);
  return { sourceId: SOURCE.id, items: parseCards(html), hasNextPage: false };
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
  const coverM = html.match(/<img[^>]+class="[^"]*wp-post-image[^"]*"[^>]+(?:data-src|src)="([^"]+)"/i);
  const bannerM = html.match(/<div\s+class="bigcover"[\s\S]*?<img[^>]+(?:data-src|src)="([^"]+)"/i);
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
    cover: absoluteUrl(coverM ? coverM[1] : null),
    banner: absoluteUrl(bannerM ? bannerM[1] : coverM ? coverM[1] : null),
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

  const embedStreams = [...new Set(embeds)].map((url, index) => ({
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
