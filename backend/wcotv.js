const { execFile } = require("node:child_process");
const { promisify } = require("node:util");
const execFileAsync = promisify(execFile);

const SOURCE = {
  id: "wcotv",
  name: "WCO.tv",
  baseUrl: "https://www.wco.tv"
};

const UA = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36";

// wco.tv blocks Node.js fetch via TLS fingerprinting; curl bypasses it cleanly.
async function requestText(url, extraHeaders = {}) {
  const args = [
    "-s", "-L", "--max-time", "30",
    "-A", UA,
    "-H", "Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "-H", "Accept-Language: en-US,en;q=0.9",
    "-H", `Referer: ${SOURCE.baseUrl}/`
  ];
  for (const [k, v] of Object.entries(extraHeaders)) {
    args.push("-H", `${k}: ${v}`);
  }
  args.push(url);
  const { stdout } = await execFileAsync("curl", args, { maxBuffer: 10 * 1024 * 1024, timeout: 30000 });
  if (!stdout) throw new Error(`Empty response from ${url}`);
  return stdout;
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

  // wco.tv search/list: <ul class="items"><li> blocks
  const liRe = /<li[^>]*>([\s\S]*?)<\/li>/gi;
  let m;
  while ((m = liRe.exec(html || "")) !== null) {
    const block = m[1];
    const linkM = block.match(/<a\s+href=["']([^"']*\/anime\/([^/"'\s]+))["'][^>]*/i);
    if (!linkM) continue;
    const id = linkM[2].replace(/\/$/, "");
    if (!id || seen.has(id)) continue;
    seen.add(id);
    const imgTag = block.match(/<img[^>]+>/i)?.[0] || "";
    const cover = attr(imgTag, "data-src") || attr(imgTag, "data-lazy-src") || attr(imgTag, "src");
    const titleEl = block.match(/<span[^>]*>([^<]{3,})<\/span>/i)
      || block.match(/<div[^>]*class=["'][^"']*title[^"']*["'][^>]*>([^<]+)<\/div>/i);
    const title = titleEl
      ? cleanText(titleEl[1])
      : (attr(imgTag, "alt") || decodeHtml(id.replace(/-/g, " ")));
    items.push(makeAnime(id, title, cover));
  }

  // Fallback: bare /anime/ links anywhere in the page
  if (items.length === 0) {
    const linkRe = /<a\s+href=["']([^"']*\/anime\/([^/"'\s]+))["'][^>]*(?:\s+title=["']([^"']+)["'])?[^>]*>([^<]*)/gi;
    while ((m = linkRe.exec(html || "")) !== null) {
      const id = m[2].replace(/\/$/, "");
      if (!id || seen.has(id)) continue;
      seen.add(id);
      const title = decodeHtml((m[3] || m[4] || id.replace(/-/g, " ")).trim());
      items.push(makeAnime(id, title, null));
    }
  }

  return items;
}

// ── Public API ───────────────────────────────────────────────────────────────

async function search(query, page = 1) {
  const q = (query || "").trim();
  if (!q) {
    const html = await requestText(`${SOURCE.baseUrl}/`);
    return { sourceId: SOURCE.id, items: parseShowCards(html), hasNextPage: false };
  }

  // wco.tv search uses POST /search with form data
  const args = [
    "-s", "-L", "--max-time", "30",
    "-A", UA,
    "-H", "Accept: */*",
    "-H", "Accept-Language: en-US,en;q=0.9",
    "-H", `Referer: ${SOURCE.baseUrl}/`,
    "-H", "X-Requested-With: XMLHttpRequest",
    "--data", `catara=${encodeURIComponent(q)}&konuara=series`,
    `${SOURCE.baseUrl}/search`
  ];
  const { stdout } = await execFileAsync("curl", args, { maxBuffer: 5 * 1024 * 1024, timeout: 30000 });
  return {
    sourceId: SOURCE.id,
    items: parseShowCards(stdout || ""),
    hasNextPage: false
  };
}

async function catalog(section = "recommended") {
  // Anime list pages are JS-rendered; use the homepage for static content
  const html = await requestText(`${SOURCE.baseUrl}/`);
  return { sourceId: SOURCE.id, section, items: parseShowCards(html), hasNextPage: false };
}

async function details(id) {
  const url = `${SOURCE.baseUrl}/anime/${id}/`;
  const html = await requestText(url);

  const titleM =
    html.match(/<h2[^>]*class=["'][^"']*cat-genre[^"']*["'][^>]*>([\s\S]*?)<\/h2>/i) ||
    html.match(/<h1[^>]*class=["'][^"']*(?:entry-title|cat-genre)[^"']*["'][^>]*>([\s\S]*?)<\/h1>/i) ||
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

  const titleM =
    html.match(/<h2[^>]*class=["'][^"']*cat-genre[^"']*["'][^>]*>([\s\S]*?)<\/h2>/i) ||
    html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i);
  const seriesTitle = titleM ? cleanText(titleM[1]) : itemId;

  const out = [];
  const seen = new Set();

  // wco.tv episode list: <div class="cat-eps"><a href="..." title="Watch ...">
  const catEpsRe = /<div[^>]*class=["'][^"']*cat-eps[^"']*["'][^>]*>([\s\S]*?)<\/div>/gi;
  let m;
  while ((m = catEpsRe.exec(html || "")) !== null) {
    const block = m[1];
    const linkM = block.match(/<a\s+href=["']([^"']+)["'][^>]*(?:\s+title=["']([^"']+)["'])?[^>]*>([^<]*)/i);
    if (!linkM) continue;
    const href = linkM[1];
    const titleAttr = cleanText(linkM[2] || "");
    const linkText = cleanText(linkM[3] || "");
    const label = titleAttr || linkText;
    if (!label && !href) continue;

    const absHref = /^https?:\/\//i.test(href) ? href : absoluteUrl(href);
    const slug = episodeSlugFromUrl(absHref) || href.replace(/^\/|\/$/g, "");
    if (!slug || seen.has(slug)) continue;
    seen.add(slug);

    const combined = `${slug} ${label}`;
    const epNumM = combined.match(/episode[- ]?(\d+(?:\.\d+)?)/i);
    const number = epNumM ? parseFloat(epNumM[1]) : out.length + 1;
    const lang = detectLang(combined);
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

  // Fallback: episode-keyed links anywhere in page
  if (out.length === 0) {
    const epLinkRe = /<a\s+href=["']([^"']+)["'][^>]*(?:\s+title=["']([^"']+)["'])?[^>]*>([^<]*)/gi;
    while ((m = epLinkRe.exec(html || "")) !== null) {
      const href = m[1];
      const label = cleanText(m[2] || m[3] || "");
      if (!/episode/i.test(`${href} ${label}`)) continue;
      if (/\/anime\//i.test(href)) continue;

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

  // Filter out sidebar-injected episodes from unrelated shows.
  // wco.tv dynamically adds trending content to the sidebar which contaminates the list.
  const idWords = itemId.split("-").filter(w => w.length >= 4);
  if (idWords.length > 0) {
    const relevant = out.filter(e => idWords.some(w => e.id.toLowerCase().includes(w)));
    if (relevant.length > 0) {
      return relevant.sort((a, b) => {
        if (a.number !== b.number) return a.number - b.number;
        return (a.duration === "Dubbed" ? 1 : 0) - (b.duration === "Dubbed" ? 1 : 0);
      });
    }
  }

  return out.sort((a, b) => {
    if (a.number !== b.number) return a.number - b.number;
    return (a.duration === "Dubbed" ? 1 : 0) - (b.duration === "Dubbed" ? 1 : 0);
  });
}

// ── Stream extraction ────────────────────────────────────────────────────────
//
// Pipeline:
//   1. Fetch episode page
//   2. Decode oRE obfuscated JS array → PMx (iframe HTML)
//   3. Extract iframe src (embed.wcostream.com) with file path + time-signed params
//   4. Convert file path: .flv → .mp4, prepend "neptun/"
//   5. POST-like GET to getvidlink.php (needs XHR header + embed URL as Referer)
//   6. Response: { enc, hd, fhd, server } — JWT tokens per quality level
//   7. GET server/getvid?evid=TOKEN — 302s to actual CDN MP4 URL

async function streams(episodeId) {
  const slug = String(episodeId || "").replace(/^\/|\/$/g, "");
  const episodeUrl = /^https?:\/\//i.test(slug) ? slug : `${SOURCE.baseUrl}/${slug}/`;

  const pageHtml = await requestText(episodeUrl).catch(() => null);
  if (!pageHtml) return [];

  // Step 1: Locate and decode obfuscated token array (variable name varies: oRE, YTd, etc.)
  // Match the array variable that feeds the .forEach(atob decode) loop
  const oreMatch = pageHtml.match(/var ([A-Za-z][A-Za-z]*)\s*=\s*\[([\s\S]*?)\];\s*\1\.forEach/);
  if (!oreMatch) return [];

  const constMatch = pageHtml.match(/\)\s*-\s*(\d{6,})\s*\)/);
  const constant = constMatch ? parseInt(constMatch[1]) : 51973287;

  const tokens = [...oreMatch[2].matchAll(/"([A-Za-z0-9+/=]+)"/g)].map(m => m[1]);
  let PMx = "";
  for (const tok of tokens) {
    try {
      const decoded = Buffer.from(tok, "base64").toString("latin1");
      const digits = decoded.replace(/\D/g, "");
      if (digits) {
        const code = parseInt(digits) - constant;
        if (code > 0 && code < 0x110000) PMx += String.fromCodePoint(code);
      }
    } catch {}
  }
  if (!PMx) return [];

  // Step 2: Extract iframe src from PMx HTML
  const iframeM =
    PMx.match(/src=["']([^"']+embed\.wcostream\.com[^"']+)["']/i) ||
    PMx.match(/<iframe[^>]+src=["']([^"']+)["']/i);
  if (!iframeM) return [];
  const iframeSrc = decodeHtml(iframeM[1]);

  // Step 3: Get file path param, convert .flv → .mp4
  const fileParamM = iframeSrc.match(/[?&]file=([^&]+)/);
  if (!fileParamM) return [];
  const filePath = decodeURIComponent(fileParamM[1]).replace(/\.flv$/i, ".mp4");

  // Step 4: Build getvidlink URL — encode each path segment but keep slashes
  const encodedPath = filePath.split("/").map(s => encodeURIComponent(s)).join("/");
  const getvidlinkUrl = `https://embed.wcostream.com/inc/embed/getvidlink.php?v=neptun/${encodedPath}&embed=neptun&fullhd=1`;

  let vidJson;
  try {
    const { stdout } = await execFileAsync("curl", [
      "-s", "-L", "--max-time", "20", "-A", UA,
      "-H", `Referer: ${iframeSrc}`,
      "-H", "X-Requested-With: XMLHttpRequest",
      getvidlinkUrl
    ], { maxBuffer: 1 * 1024 * 1024, timeout: 25000 });
    vidJson = JSON.parse(stdout);
  } catch {
    return [];
  }

  const server = vidJson.server || vidJson.cdn;
  if (!server) return [];

  // Step 5: Build stream entries — getvid endpoint 302s to actual CDN URL
  const result = [];
  for (const [key, token, label] of [
    ["fhd", vidJson.fhd, "1080p"],
    ["hd", vidJson.hd, "720p"],
    ["enc", vidJson.enc, "480p"],
  ]) {
    if (!token) continue;
    result.push({
      id: `wcotv-${key}`,
      label,
      quality: label,
      type: "mp4",
      url: `${server}/getvid?evid=${encodeURIComponent(token)}`,
      headers: { Referer: iframeSrc }
    });
  }

  return result;
}

module.exports = { SOURCE, search, catalog, details, episodes, streams };
