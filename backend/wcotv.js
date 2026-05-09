const SOURCE = {
  id: "wcotv",
  name: "WCO.tv",
  baseUrl: "https://www.wco.tv"
};

const HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
  "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Language": "en-US,en;q=0.5"
};

async function requestText(url, extraHeaders = {}) {
  const resp = await fetch(url, {
    headers: { ...HEADERS, Referer: SOURCE.baseUrl + "/", ...extraHeaders }
  });
  if (!resp.ok) throw new Error(`${resp.status} ${resp.statusText} — ${url}`);
  return resp.text();
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
  return decodeHtml((s || "").replace(/<script[\s\S]*?<\/script>/gi, " ").replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function absoluteUrl(url, base = SOURCE.baseUrl) {
  if (!url) return null;
  const v = decodeHtml(String(url).trim());
  if (/^https?:\/\//i.test(v)) return v;
  if (v.startsWith("//")) return "https:" + v;
  if (v.startsWith("/")) return base + v;
  return base + "/" + v;
}

function attr(tag, name) {
  const m = (tag || "").match(new RegExp(`\\s${name}=["']([^"']+)["']`, "i"));
  return m ? decodeHtml(m[1]) : null;
}

function animeSlugFromUrl(url) {
  const m = String(url || "").match(/\/anime\/([^/?#\s]+)/i);
  return m ? m[1].replace(/\/$/, "") : "";
}

function episodeSlugFromUrl(url) {
  // strip domain, get last path segment
  const v = String(url || "").replace(/\/$/, "");
  const m = v.match(/\/([^/]+)$/);
  return m ? m[1] : "";
}

function makeAnime(id, title, cover, extra = {}) {
  return {
    id,
    sourceId: SOURCE.id,
    title,
    subtitle: extra.subtitle || "WCO.tv",
    cover: cover ? absoluteUrl(cover) : null,
    banner: cover ? absoluteUrl(cover) : null,
    year: extra.year || null,
    score: null,
    genres: extra.genres || [],
    status: extra.status || "Planned",
    progress: "0 / ?",
    synopsis: extra.synopsis || "",
    pageUrl: `${SOURCE.baseUrl}/anime/${id}/`
  };
}

// ── Card parsing ────────────────────────────────────────────────────────────

function parseShowCards(html) {
  const items = [];
  const seen = new Set();

  // Attempt 1: <article> blocks (standard WordPress theme)
  const articleRe = /<article[^>]*>([\s\S]*?)<\/article>/gi;
  let m;
  while ((m = articleRe.exec(html || "")) !== null) {
    const block = m[1];
    const linkM = block.match(/<a\s+href=["']([^"']+\/anime\/[^"']+)["'][^>]*/i);
    if (!linkM) continue;
    const id = animeSlugFromUrl(linkM[1]);
    if (!id || seen.has(id)) continue;
    seen.add(id);
    const imgTag = block.match(/<img[^>]+>/i)?.[0] || "";
    const cover = attr(imgTag, "data-src") || attr(imgTag, "data-lazy-src") || attr(imgTag, "src");
    const titleM = block.match(/<h\d[^>]*>([\s\S]*?)<\/h\d>/i);
    const title = titleM ? cleanText(titleM[1]) : (attr(imgTag, "alt") || id);
    items.push(makeAnime(id, title, cover));
  }

  // Attempt 2: direct /anime/ links with title attribute
  if (items.length === 0) {
    const linkRe = /<a\s+href=["']([^"']+\/anime\/([^/"'\s]+))["'][^>]*(?:title=["']([^"']+)["'])?[^>]*>([^<]*)/gi;
    while ((m = linkRe.exec(html || "")) !== null) {
      const id = m[2].replace(/\/$/, "");
      if (!id || seen.has(id)) continue;
      seen.add(id);
      const title = decodeHtml((m[3] || m[4] || id).trim());
      items.push(makeAnime(id, title, null));
    }
  }

  return items;
}

// ── Public API ───────────────────────────────────────────────────────────────

async function search(query, page = 1) {
  const q = (query || "").trim();
  let url;
  if (!q) {
    url = `${SOURCE.baseUrl}/anime-list`;
  } else {
    url = page > 1
      ? `${SOURCE.baseUrl}/page/${page}/?s=${encodeURIComponent(q)}`
      : `${SOURCE.baseUrl}/?s=${encodeURIComponent(q)}`;
  }
  const html = await requestText(url);
  return {
    sourceId: SOURCE.id,
    items: parseShowCards(html),
    hasNextPage: /(?:class=["'][^"']*\bnext\b[^"']*["']|rel=["']next["'])/i.test(html)
  };
}

async function catalog(section = "recommended") {
  const routes = {
    recommended: `${SOURCE.baseUrl}/anime-list`,
    trending: `${SOURCE.baseUrl}/anime-list`,
    new: `${SOURCE.baseUrl}/`,
    cartoon: `${SOURCE.baseUrl}/cartoon-list`
  };
  const html = await requestText(routes[section] || routes.recommended);
  return { sourceId: SOURCE.id, section, items: parseShowCards(html), hasNextPage: false };
}

async function details(id) {
  const url = `${SOURCE.baseUrl}/anime/${id}/`;
  const html = await requestText(url);

  const titleM =
    html.match(/<h1[^>]*class=["'][^"']*(?:entry-title|cat-genre)[^"']*["'][^>]*>([\s\S]*?)<\/h1>/i) ||
    html.match(/<h2[^>]*class=["'][^"']*cat-genre[^"']*["'][^>]*>([\s\S]*?)<\/h2>/i) ||
    html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);

  const synM =
    html.match(/<div[^>]*class=["'][^"']*entry-content[^"']*["'][^>]*>([\s\S]*?)<\/div>/i) ||
    html.match(/<meta\s+name=["']description["'][^>]*content=["']([^"']+)["']/i);

  const posterM =
    html.match(/<img[^>]+class=["'][^"']*(?:wp-post-image|attachment)[^"']*["'][^>]+>/i) ||
    html.match(/<img[^>]+src=["'][^"']+\.(?:jpg|jpeg|png|webp)[^"']*["'][^>]*>/i);
  const cover = posterM
    ? attr(posterM[0], "data-src") || attr(posterM[0], "src")
    : null;

  const genres = [];
  const genreRe = /<a[^>]+href=["'][^"']*(?:genre|category|tag)[^"']*["'][^>]*>([^<]+)<\/a>/gi;
  let gm;
  while ((gm = genreRe.exec(html)) !== null) {
    const g = cleanText(gm[1]);
    if (g && !genres.includes(g)) genres.push(g);
  }

  return makeAnime(id, titleM ? cleanText(titleM[1]) : id, cover, {
    synopsis: synM ? cleanText(synM[1]) : "",
    genres
  });
}

function detectLang(text) {
  return /dub(?:bed)?/i.test(text) ? "dub" : "sub";
}

async function episodes(itemId) {
  const url = `${SOURCE.baseUrl}/anime/${itemId}/`;
  const html = await requestText(url);

  const titleM = html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  const seriesTitle = titleM ? cleanText(titleM[1]) : itemId;

  const out = [];
  const seen = new Set();

  // Primary: episode links that contain "episode" in href or text
  const epLinkRe = /<a\s+href=["']([^"']+)["'][^>]*>([\s\S]*?)<\/a>/gi;
  let match;
  while ((match = epLinkRe.exec(html || "")) !== null) {
    const href = match[1];
    const label = cleanText(match[2]);
    const combined = `${href} ${label}`;

    if (!/(?:episode|ep[\s-]?\d)/i.test(combined)) continue;
    if (/\/anime\//i.test(href)) continue;

    const absHref = /^https?:\/\//i.test(href) ? href : absoluteUrl(href);
    const slug = episodeSlugFromUrl(absHref) || href.replace(/^\/|\/$/g, "");
    if (!slug || seen.has(slug)) continue;
    seen.add(slug);

    const epNumM =
      slug.match(/episode[- ]?(\d+(?:\.\d+)?)/i) ||
      label.match(/(?:episode|ep)[- ]?(\d+(?:\.\d+)?)/i);
    const number = epNumM ? parseFloat(epNumM[1]) : out.length + 1;
    const lang = detectLang(combined);
    const langLabel = lang === "dub" ? "Dubbed" : "Subbed";

    out.push({
      id: slug,
      animeId: itemId,
      sourceId: SOURCE.id,
      number,
      title: label && label.length > 2 ? label : `${seriesTitle} Episode ${number} (${langLabel})`,
      duration: langLabel
    });
  }

  // Fallback: list-item links with dubbed/subbed anywhere
  if (out.length === 0) {
    const liRe = /<li[^>]*>\s*<a\s+href=["']([^"']+)["'][^>]*>([^<]+)<\/a>/gi;
    while ((match = liRe.exec(html || "")) !== null) {
      const href = match[1];
      const label = cleanText(match[2]);
      if (!/(?:dubbed|subbed)/i.test(`${href} ${label}`)) continue;

      const absHref = /^https?:\/\//i.test(href) ? href : absoluteUrl(href);
      const slug = episodeSlugFromUrl(absHref) || href.replace(/^\/|\/$/g, "");
      if (!slug || seen.has(slug)) continue;
      seen.add(slug);

      const epNumM = slug.match(/episode[- ]?(\d+(?:\.\d+)?)/i) || label.match(/(\d+(?:\.\d+)?)/);
      const number = epNumM ? parseFloat(epNumM[1]) : out.length + 1;
      const lang = detectLang(`${href} ${label}`);
      const langLabel = lang === "dub" ? "Dubbed" : "Subbed";

      out.push({
        id: slug,
        animeId: itemId,
        sourceId: SOURCE.id,
        number,
        title: label || `${seriesTitle} Episode ${number} (${langLabel})`,
        duration: langLabel
      });
    }
  }

  return out.sort((a, b) => {
    if (a.number !== b.number) return a.number - b.number;
    // sub before dub for same number
    return (a.duration === "Dubbed" ? 1 : 0) - (b.duration === "Dubbed" ? 1 : 0);
  });
}

// ── Stream extraction ────────────────────────────────────────────────────────

function extractVideoSources(html, referer) {
  const out = [];
  const seen = new Set();

  // JWPlayer sources array: sources: [{file: "...", label: "..."}]
  const sourcesM = html.match(/sources\s*:\s*\[([\s\S]*?)\]/i);
  if (sourcesM) {
    const block = sourcesM[1];
    const fileRe = /file\s*:\s*["']([^"']+)["']/gi;
    const labelRe = /label\s*:\s*["']([^"']+)["']/gi;
    const files = [];
    const labels = [];
    let fm, lm;
    while ((fm = fileRe.exec(block)) !== null) files.push(decodeHtml(fm[1]));
    while ((lm = labelRe.exec(block)) !== null) labels.push(lm[1]);
    for (let i = 0; i < files.length; i++) {
      const url = files[i];
      if (!url || seen.has(url)) continue;
      seen.add(url);
      const isHls = /\.m3u8/i.test(url);
      out.push({
        id: `wcotv-jw-${i}`,
        label: labels[i] || (isHls ? "HLS" : "MP4"),
        quality: labels[i] || "auto",
        type: isHls ? "hls" : "mp4",
        url,
        headers: { Referer: referer }
      });
    }
  }

  // JWPlayer single file: jwplayer(...).setup({ file: "..." })
  if (out.length === 0) {
    const singleM = html.match(/\.setup\s*\(\s*\{[\s\S]*?file\s*:\s*["']([^"']+)["']/i);
    if (singleM) {
      const url = decodeHtml(singleM[1]);
      if (url && !seen.has(url)) {
        seen.add(url);
        const isHls = /\.m3u8/i.test(url);
        out.push({
          id: "wcotv-jw-0",
          label: isHls ? "HLS" : "MP4",
          quality: "auto",
          type: isHls ? "hls" : "mp4",
          url,
          headers: { Referer: referer }
        });
      }
    }
  }

  // Any bare .m3u8 or .mp4 URLs in assignment context
  if (out.length === 0) {
    const urlRe = /(?:file|src|url|source)\s*[=:]\s*["']([^"']+\.(?:m3u8|mp4)[^"']*)["']/gi;
    let m;
    while ((m = urlRe.exec(html || "")) !== null) {
      const url = decodeHtml(m[1]);
      if (!url || seen.has(url) || /^data:/i.test(url)) continue;
      seen.add(url);
      const isHls = /\.m3u8/i.test(url);
      out.push({
        id: `wcotv-direct-${out.length}`,
        label: isHls ? "HLS" : "MP4",
        quality: "auto",
        type: isHls ? "hls" : "mp4",
        url,
        headers: { Referer: referer }
      });
    }
  }

  return out;
}

async function tryGetvid(html, embedReferer) {
  // Look for getvid content ID in page JS
  const idM =
    html.match(/video_content_id\s*=\s*["']?([A-Za-z0-9_=-]{6,})["']?/i) ||
    html.match(/evid=["']?([A-Za-z0-9_=-]{6,})["']?/i) ||
    html.match(/getJSON\s*\(\s*["']([^"']*getvid[^"']*)["']/i);

  if (!idM) return [];

  const rawId = idM[1];
  // If the captured group already looks like a full URL, use it; otherwise build candidates
  const candidates = /^https?:\/\//i.test(rawId)
    ? [rawId]
    : [
        `https://cdn.wcofun.net/getvid?evid=${encodeURIComponent(rawId)}`,
        `https://www.wcostream.com/getvid?evid=${encodeURIComponent(rawId)}`,
        `https://www.wco.tv/getvid?evid=${encodeURIComponent(rawId)}`
      ];

  for (const apiUrl of candidates) {
    try {
      const resp = await fetch(apiUrl, { headers: { ...HEADERS, Referer: embedReferer } });
      if (!resp.ok) continue;
      const text = await resp.text();
      const sources = parseGetvidResponse(text, apiUrl);
      if (sources.length) return sources;
    } catch {
      // try next candidate
    }
  }
  return [];
}

function parseGetvidResponse(text, referer) {
  const out = [];
  try {
    const data = JSON.parse(text);
    if (Array.isArray(data)) {
      for (const item of data) {
        const url = item.file || item.url || item.src;
        if (!url) continue;
        const isHls = /\.m3u8/i.test(url);
        out.push({
          id: `wcotv-getvid-${out.length}`,
          label: item.label || (isHls ? "HLS" : "MP4"),
          quality: item.label || "auto",
          type: isHls ? "hls" : "mp4",
          url,
          headers: { Referer: referer }
        });
      }
    } else if (data && typeof data === "object") {
      for (const [key, value] of Object.entries(data)) {
        if (typeof value !== "string" || !/^https?:\/\//i.test(value)) continue;
        const isHls = /\.m3u8/i.test(value);
        out.push({
          id: `wcotv-getvid-${out.length}`,
          label: key,
          quality: key,
          type: isHls ? "hls" : "mp4",
          url: value,
          headers: { Referer: referer }
        });
      }
    }
  } catch {
    // Non-JSON: try bare URL extraction
    const urlRe = /https?:\/\/[^"'\s,]+\.(?:m3u8|mp4)[^"'\s,]*/gi;
    let m;
    while ((m = urlRe.exec(text || "")) !== null) {
      const isHls = /\.m3u8/i.test(m[0]);
      out.push({
        id: `wcotv-getvid-${out.length}`,
        label: isHls ? "HLS" : "MP4",
        quality: "auto",
        type: isHls ? "hls" : "mp4",
        url: m[0],
        headers: { Referer: referer }
      });
    }
  }
  return out;
}

async function fetchEmbed(url, referer) {
  try {
    const resp = await fetch(url, { headers: { ...HEADERS, Referer: referer } });
    if (!resp.ok) return null;
    return resp.text();
  } catch {
    return null;
  }
}

async function streams(episodeId) {
  const slug = String(episodeId || "").replace(/^\/|\/$/g, "");
  const episodeUrl = /^https?:\/\//i.test(slug) ? slug : `${SOURCE.baseUrl}/${slug}/`;

  const pageHtml = await requestText(episodeUrl).catch(() => null);
  if (!pageHtml) return [];

  // Direct video in episode page (uncommon but possible)
  const pageSources = extractVideoSources(pageHtml, episodeUrl);
  if (pageSources.length) return pageSources;

  // Find iframe embed
  const iframeM =
    pageHtml.match(/<iframe[^>]+(?:data-litespeed-src|data-src|src)=["']([^"']+)["'][^>]*>/i) ||
    pageHtml.match(/(?:data-litespeed-src|lazyframe-src)=["']([^"']+)["']/i);
  if (!iframeM) return [];

  const iframeSrc = absoluteUrl(iframeM[1], SOURCE.baseUrl);
  if (!iframeSrc) return [];

  // Fetch embed page
  const embedHtml = await fetchEmbed(iframeSrc, episodeUrl);
  if (!embedHtml) {
    return [{ id: "wcotv-embed-0", label: "WCO Embed", quality: "auto", type: "iframe", url: iframeSrc, headers: { Referer: episodeUrl } }];
  }

  // Try JWPlayer / direct sources from embed
  const embedSources = extractVideoSources(embedHtml, iframeSrc);
  if (embedSources.length) return embedSources;

  // Try getvid API
  const getvid = await tryGetvid(embedHtml, iframeSrc);
  if (getvid.length) return getvid;

  // One level of nested iframe
  const nestedM = embedHtml.match(/<iframe[^>]+(?:data-src|src)=["']([^"']+)["'][^>]*>/i);
  if (nestedM) {
    const nestedUrl = absoluteUrl(nestedM[1], iframeSrc);
    if (nestedUrl) {
      const nestedHtml = await fetchEmbed(nestedUrl, iframeSrc);
      if (nestedHtml) {
        const nestedSources = extractVideoSources(nestedHtml, nestedUrl);
        if (nestedSources.length) return nestedSources;
        const nestedGetvid = await tryGetvid(nestedHtml, nestedUrl);
        if (nestedGetvid.length) return nestedGetvid;
      }
    }
  }

  // Fallback: serve the embed as an iframe
  return [{
    id: "wcotv-embed-0",
    label: "WCO Embed",
    quality: "auto",
    type: "iframe",
    url: iframeSrc,
    headers: { Referer: episodeUrl }
  }];
}

module.exports = { SOURCE, search, catalog, details, episodes, streams };
