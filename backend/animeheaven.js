const SOURCE = {
  id: "animeheaven",
  name: "AnimeHeaven",
  baseUrl: "https://animeheaven.me"
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
    .replace(/&quot;/g, '"')
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
  const value = String(url).trim();
  if (/^https?:\/\//i.test(value)) return value;
  if (/^\/\//.test(value)) return `https:${value}`;
  if (value.startsWith("/")) return `${SOURCE.baseUrl}${value}`;
  return `${SOURCE.baseUrl}/${value.replace(/^\/+/, "")}`;
}

function attr(html, name) {
  const re = new RegExp(`\\b${name}=['"]([^'"]+)['"]`, "i");
  const match = (html || "").match(re);
  return match ? decodeHtml(match[1]) : "";
}

function makeAnime(id, title, image, extra = {}) {
  return {
    id,
    sourceId: SOURCE.id,
    title,
    subtitle: extra.subtitle || "AnimeHeaven",
    cover: absoluteUrl(image),
    banner: absoluteUrl(image),
    year: extra.year ? Number.parseInt(String(extra.year), 10) || null : null,
    score: extra.score || null,
    genres: extra.genres || [],
    status: extra.status || "Planned",
    progress: "0 / ?",
    synopsis: extra.synopsis || "",
    pageUrl: `${SOURCE.baseUrl}/anime.php?${id}`
  };
}

function parseCardItems(html) {
  const out = [];
  const seen = new Set();
  const re = /<div\s+class=['"]chart\s+bc1['"][\s\S]*?<\/div>\s*<\/div>/gi;
  let match;

  while ((match = re.exec(html || "")) !== null) {
    const block = match[0];
    const idM = block.match(/href=['"]anime\.php\?([^'"]+)['"]/i);
    if (!idM || seen.has(idM[1])) continue;
    seen.add(idM[1]);

    const titleM = block.match(/class=['"]charttitle\s+c['"][\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i);
    const imageM = block.match(/<img[^>]+src=['"]([^'"]+)['"][^>]*>/i);
    const title = titleM ? cleanText(titleM[1]) : cleanText(attr(imageM ? imageM[0] : "", "alt"));
    if (title) out.push(makeAnime(idM[1], title, imageM ? imageM[1] : null));
  }

  return out;
}

function parseSearchItems(html) {
  const out = [];
  const seen = new Set();
  const re = /<div\s+class=['"]similarimg['"][\s\S]*?<\/div>\s*<\/div>/gi;
  let match;

  while ((match = re.exec(html || "")) !== null) {
    const block = match[0];
    const idM = block.match(/href=['"]anime\.php\?([^'"]+)['"]/i);
    if (!idM || seen.has(idM[1])) continue;
    seen.add(idM[1]);

    const titleM = block.match(/class=['"]similarname\s+c['"][\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i);
    const imageM = block.match(/<img[^>]+src=['"]([^'"]+)['"][^>]*>/i);
    const title = titleM ? cleanText(titleM[1]) : cleanText(attr(imageM ? imageM[0] : "", "alt"));
    if (title) out.push(makeAnime(idM[1], title, imageM ? imageM[1] : null));
  }

  return out;
}

async function search(query) {
  const q = (query || "").trim();
  const url = q ? `${SOURCE.baseUrl}/search.php?s=${encodeURIComponent(q)}` : `${SOURCE.baseUrl}/new.php`;
  const html = await requestText(url);
  let items = parseSearchItems(html);
  if (items.length === 0) items = parseCardItems(html);
  return { sourceId: SOURCE.id, items, hasNextPage: false };
}

async function catalog(section = "recommended") {
  const routes = {
    recommended: `${SOURCE.baseUrl}/popular.php`,
    trending: `${SOURCE.baseUrl}/popular.php`,
    new: `${SOURCE.baseUrl}/new.php`,
    action: `${SOURCE.baseUrl}/tags.php?tag=Action`
  };
  const html = await requestText(routes[section] || routes.recommended);
  let items = parseCardItems(html);
  if (items.length === 0) items = parseSearchItems(html);
  return { sourceId: SOURCE.id, section, items, hasNextPage: false };
}

async function details(id) {
  const html = await requestText(`${SOURCE.baseUrl}/anime.php?${encodeURIComponent(id)}`);
  const titleM = html.match(/<div\s+class=['"]infotitle\s+c['"]>([\s\S]*?)<\/div>/i);
  const descM = html.match(/<div\s+class=['"]infodes\s+c['"]>([\s\S]*?)<\/div>/i);
  let imgM = html.match(/<img[^>]+class=['"]posterimg['"][^>]+src=['"]([^'"]+)['"]/i);
  if (!imgM) imgM = html.match(/<img[^>]+src=['"]([^'"]+)['"][^>]*class=['"]posterimg['"]/i);

  const genres = [];
  const tagRe = /<div\s+class=['"]boxitem\s+bc2\s+c1['"]>([\s\S]*?)<\/div>/gi;
  let tagM;
  while ((tagM = tagRe.exec(html)) !== null) {
    const tag = cleanText(tagM[1]);
    if (tag && !genres.includes(tag)) genres.push(tag);
  }

  const infoM = html.match(/<div\s+class=['"]infoyear\s+c['"]>([\s\S]*?)<\/div>\s*<\/div>/i);
  const info = infoM ? cleanText(infoM[1]) : "";
  const yearM = info.match(/Year:\s*([0-9? -]+)/i);
  const scoreM = info.match(/Score:\s*([0-9.]+)\/10/i);
  const epM = info.match(/Episodes:\s*([0-9.+]+)/i);

  return makeAnime(id, titleM ? cleanText(titleM[1]) : id, imgM ? imgM[1] : null, {
    subtitle: genres.slice(0, 3).join("  •  ") || "AnimeHeaven",
    genres,
    synopsis: descM ? cleanText(descM[1]) : "",
    year: yearM ? yearM[1].trim() : null,
    score: scoreM ? Math.round(Number.parseFloat(scoreM[1]) * 10) : null,
    status: yearM && yearM[1].includes("?") ? "Watching" : "Planned",
    episodeCount: epM ? epM[1] : null
  });
}

async function episodes(itemId) {
  const html = await requestText(`${SOURCE.baseUrl}/anime.php?${encodeURIComponent(itemId)}`);
  const titleM = html.match(/<div\s+class=['"]infotitle\s+c['"]>([\s\S]*?)<\/div>/i);
  const seriesTitle = titleM ? cleanText(titleM[1]) : "";
  const out = [];
  const seen = new Set();
  const re = /<a[^>]+(?:onmouseover|onclick)=['"]gate[ha]\(['"]([a-f0-9]{16,})['"]\)['"][\s\S]*?<\/a>/gi;
  let match;

  while ((match = re.exec(html)) !== null) {
    const block = match[0];
    const key = match[1];
    if (seen.has(key)) continue;
    seen.add(key);

    const epM = block.match(/<div\s+class=['"][^'"]*watch2[^'"]*['"]>([\s\S]*?)<\/div>/i);
    const label = epM ? cleanText(epM[1]) : String(out.length + 1);
    let number = Number.parseFloat(label.replace(/[^0-9.]/g, ""));
    if (Number.isNaN(number)) number = out.length + 1;

    out.push({
      id: `${itemId}|${key}|${label}`,
      animeId: itemId,
      sourceId: SOURCE.id,
      number,
      title: `${seriesTitle ? `${seriesTitle} - ` : ""}Episode ${label}`,
      duration: "24m"
    });
  }

  return out.sort((a, b) => a.number - b.number);
}

async function streams(episodeId) {
  const [showId, key, label] = String(episodeId || "").split("|");
  const referer = showId ? `${SOURCE.baseUrl}/anime.php?${showId}` : `${SOURCE.baseUrl}/`;
  const html = await requestText(`${SOURCE.baseUrl}/gate.php`, {
    Referer: referer,
    Cookie: `key=${key || episodeId}`
  });

  const out = [];
  const seen = new Set();
  const sourceRe = /<source[^>]+src=['"]([^'"]+)['"][^>]*type=['"]video\/mp4['"][^>]*>/gi;
  let match;
  while ((match = sourceRe.exec(html)) !== null) {
    const url = decodeHtml(match[1]);
    if (!url || seen.has(url)) continue;
    seen.add(url);
    out.push({
      id: `animeheaven-${out.length}`,
      label: label ? `MP4 - Ep. ${label}` : "MP4",
      quality: "auto",
      type: "mp4",
      url,
      headers: { Referer: `${SOURCE.baseUrl}/gate.php` }
    });
  }

  const hlsRe = /https?:\/\/[^"'<>\\\s]+\.m3u8[^"'<>\\\s]*/gi;
  while ((match = hlsRe.exec(html)) !== null) {
    const url = decodeHtml(match[0]);
    if (!url || seen.has(url)) continue;
    seen.add(url);
    out.push({
      id: `animeheaven-hls-${out.length}`,
      label: label ? `HLS - Ep. ${label}` : "HLS",
      quality: "auto",
      type: "hls",
      url,
      headers: { Referer: `${SOURCE.baseUrl}/gate.php` }
    });
  }

  const downloadM = html.match(/href=['"]([^'"]*video\.mp4\?[^'"]+&d)['"]/i);
  if (downloadM) {
    const url = decodeHtml(downloadM[1]);
    if (url && !seen.has(url)) {
      out.push({
        id: "animeheaven-download",
        label: "MP4 - Download",
        quality: "auto",
        type: "mp4",
        url,
        headers: { Referer: `${SOURCE.baseUrl}/gate.php` }
      });
    }
  }

  return out;
}

module.exports = {
  SOURCE,
  search,
  catalog,
  details,
  episodes,
  streams
};
