const SOURCE = {
  id: "animekai",
  name: "AnimeKai",
  baseUrl: "https://anikai.to"
};

const AJAX_HEADERS = {
  Referer: "https://anikai.to/",
  "X-Requested-With": "XMLHttpRequest"
};

const PAGE_HEADERS = {
  Referer: "https://anikai.to/"
};

const STREAM_UA =
  "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36";

async function requestText(url, options = {}) {
  const response = await fetch(url, options);
  if (!response.ok) {
    throw new Error(`${response.status} ${response.statusText} for ${url}`);
  }
  return response.text();
}

function decodeHtml(s) {
  if (!s) return "";
  return s
    .replace(/&amp;/g, "&")
    .replace(/&quot;/g, '"')
    .replace(/&#039;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&#(\d+);/g, (_, d) => String.fromCharCode(parseInt(d, 10)));
}

function extractAjaxHtml(resp) {
  if (!resp) return "";
  try {
    const json = JSON.parse(resp);
    const result = json && json.result;
    if (typeof result === "string") return result;
    if (result && typeof result.html === "string") return result.html;
    return "";
  } catch {
    return resp;
  }
}

async function encodeToken(text) {
  const resp = await requestText(
    `https://enc-dec.app/api/enc-kai?text=${encodeURIComponent(text)}`,
    { headers: PAGE_HEADERS }
  );
  const json = JSON.parse(resp);
  return json && json.result ? json.result : "";
}

async function decodeKai(text) {
  const resp = await requestText("https://enc-dec.app/api/dec-kai", {
    method: "POST",
    body: JSON.stringify({ text }),
    headers: { "Content-Type": "application/json" }
  });
  const json = JSON.parse(resp);
  return json && json.status === 200 ? json.result : null;
}

async function getMegaupStream(embedUrl) {
  const mediaUrl = embedUrl.replace("/e/", "/media/");
  const mediaResp = await requestText(mediaUrl, {
    headers: {
      Referer: SOURCE.baseUrl,
      "User-Agent": STREAM_UA
    }
  });
  const mediaJson = JSON.parse(mediaResp);
  const encrypted = mediaJson && mediaJson.result ? mediaJson.result : "";
  if (!encrypted) return null;

  const decResp = await requestText("https://enc-dec.app/api/dec-mega", {
    method: "POST",
    body: JSON.stringify({ text: encrypted, agent: STREAM_UA }),
    headers: { "Content-Type": "application/json" }
  });
  const decJson = JSON.parse(decResp);
  const sources = decJson && decJson.result && decJson.result.sources;
  return sources && sources[0] && sources[0].file ? sources[0].file : null;
}

function parseBrowserItems(html) {
  const items = [];
  const re = /<div\s+class="aitem">([\s\S]*?<a\s+class="title"[^>]*>[^<]+<\/a>[\s\S]*?<\/div>\s*<\/div>)/g;
  let match;

  while ((match = re.exec(html)) !== null) {
    const block = match[1];
    const hrefM = block.match(/<a\s+href="(\/watch\/[^"]+)"\s+class="poster"/);
    if (!hrefM) continue;

    const slug = hrefM[1].replace(/^\/watch\//, "");
    let titleM = block.match(/<a\s+class="title"[^>]*title="([^"]+)"[^>]*>/);
    if (!titleM) titleM = block.match(/<a\s+class="title"[^>]*>([^<]+)<\/a>/);

    const imgM = block.match(/<img[^>]+(?:data-src|src)="([^"]+)"/);
    const typeM = block.match(/<span><b>(TV|MOVIE|OVA|ONA|SPECIAL|MUSIC)<\/b><\/span>/i);

    items.push({
      id: slug,
      sourceId: SOURCE.id,
      title: titleM ? decodeHtml(titleM[1].trim()) : slug,
      subtitle: typeM ? typeM[1].trim() : "AnimeKai",
      cover: imgM ? imgM[1].replace(/@\d+\.jpg$/, ".jpg") : null,
      banner: imgM ? imgM[1].replace(/@\d+\.jpg$/, ".jpg") : null,
      year: null,
      score: null,
      genres: [],
      status: "Planned",
      progress: "0 / ?",
      pageUrl: `${SOURCE.baseUrl}/watch/${slug}`
    });
  }

  return items;
}

function hasNextPage(html, page) {
  return html.includes(`page=${page + 1}`) || html.includes(`page=${page + 1}&`);
}

async function search(query, page = 1) {
  const params = new URLSearchParams({ page: String(page) });
  if (query && query.trim()) params.set("keyword", query.trim());
  if (!query || !query.trim()) params.set("sort", "trending");

  const url = `${SOURCE.baseUrl}/browser?${params.toString()}`;
  const html = await requestText(url, { headers: PAGE_HEADERS });
  return {
    sourceId: SOURCE.id,
    items: parseBrowserItems(html),
    hasNextPage: hasNextPage(html, page)
  };
}

async function details(id) {
  const url = `${SOURCE.baseUrl}/watch/${id}`;
  const html = await requestText(url, { headers: PAGE_HEADERS });
  const titleM =
    html.match(/<h1[^>]*itemprop="name"[^>]*>([^<]+)<\/h1>/i) ||
    html.match(/<h1[^>]*class="[^"]*\btitle\b[^"]*"[^>]*>([^<]+)<\/h1>/i);
  const synM = html.match(/<div[^>]*class="[^"]*\bdesc\b[^"]*"[^>]*>([\s\S]*?)<\/div>/i);
  const coverM = html.match(/<img[^>]+itemprop="image"[^>]+src="([^"]+)"/i);
  const genres = [];
  const genreRe = /<a[^>]+href="\/genres\/[^"]*"[^>]*>([^<]+)<\/a>/g;
  let genreM;
  while ((genreM = genreRe.exec(html)) !== null) {
    const genre = decodeHtml(genreM[1].trim());
    if (genre && !genres.includes(genre)) genres.push(genre);
  }

  return {
    id,
    sourceId: SOURCE.id,
    title: titleM ? decodeHtml(titleM[1].trim()) : id,
    subtitle: genres.slice(0, 3).join("  •  ") || "AnimeKai",
    cover: coverM ? coverM[1] : null,
    banner: coverM ? coverM[1] : null,
    year: null,
    score: null,
    genres,
    status: "Planned",
    progress: "0 / ?",
    synopsis: synM ? decodeHtml(synM[1].replace(/<[^>]+>/g, "").trim()) : "",
    pageUrl: url
  };
}

async function episodes(itemId) {
  const html = await requestText(`${SOURCE.baseUrl}/watch/${itemId}`, { headers: PAGE_HEADERS });
  const aniIdM =
    html.match(/id="anime-rating"[^>]*data-id="([^"]+)"/) ||
    html.match(/data-id="([^"]+)"[^>]*id="anime-rating"/) ||
    html.match(/class="ttip-btn"\s+data-tip="([A-Za-z0-9_-]+)"/) ||
    html.match(/(?:user-bookmark|w2g-trigger)[^>]+data-id="([A-Za-z0-9_-]+)"/);

  if (!aniIdM) return [];
  const enc = await encodeToken(aniIdM[1]);
  if (!enc) return [];

  const epsResp = await requestText(
    `${SOURCE.baseUrl}/ajax/episodes/list?ani_id=${aniIdM[1]}&_=${encodeURIComponent(enc)}`,
    { headers: AJAX_HEADERS }
  );
  const epsHtml = extractAjaxHtml(epsResp);
  const results = [];
  const epRe = /<a\s([^>]+)>([\s\S]*?)<\/a>/g;
  let epM;

  while ((epM = epRe.exec(epsHtml)) !== null) {
    const attrs = epM[1];
    const content = epM[2];
    const numM = attrs.match(/\bnum="([^"]+)"/);
    const tokenM = attrs.match(/\btoken="([^"]+)"/);
    if (!numM || !tokenM) continue;

    const nameM = content.match(/<span[^>]*>([^<]+)<\/span>/);
    const number = parseInt(numM[1], 10);
    results.push({
      id: tokenM[1],
      animeId: itemId,
      sourceId: SOURCE.id,
      number,
      title: nameM ? decodeHtml(nameM[1].trim()) : `Episode ${number}`,
      duration: "24m"
    });
  }

  return results.sort((a, b) => a.number - b.number);
}

async function streams(episodeId) {
  const enc = await encodeToken(episodeId);
  if (!enc) return [];

  const serversResp = await requestText(
    `${SOURCE.baseUrl}/ajax/links/list?token=${encodeURIComponent(episodeId)}&_=${encodeURIComponent(enc)}`,
    { headers: AJAX_HEADERS }
  );
  const serversHtml = extractAjaxHtml(serversResp);
  const entries = [];
  const langMap = { sub: "Sub", softsub: "SoftSub", dub: "Dub" };
  const groupRe = /<div\s+class="server-items[^"]*"\s+data-id="([^"]+)"[^>]*>([\s\S]*?)<\/div>/g;
  let groupM;

  while ((groupM = groupRe.exec(serversHtml)) !== null) {
    const lang = langMap[groupM[1]] || groupM[1];
    const srvRe = /<span[^>]+\bdata-sid="([^"]*)"[^>]+\bdata-lid="([^"]+)"[^>]*>([^<]+)<\/span>/g;
    let srvM;
    while ((srvM = srvRe.exec(groupM[2])) !== null) {
      entries.push({ lid: srvM[2], name: srvM[3].trim(), lang });
    }
  }

  const results = [];
  for (const entry of entries.slice(0, 4)) {
    const encLid = await encodeToken(entry.lid);
    if (!encLid) continue;

    const viewResp = await requestText(
      `${SOURCE.baseUrl}/ajax/links/view?id=${encodeURIComponent(entry.lid)}&_=${encodeURIComponent(encLid)}`,
      { headers: AJAX_HEADERS }
    );
    let encrypted = "";
    try {
      const viewJson = JSON.parse(viewResp);
      encrypted = viewJson && typeof viewJson.result === "string" ? viewJson.result : "";
    } catch {
      continue;
    }

    const decoded = encrypted ? await decodeKai(encrypted) : null;
    const embedUrl = typeof decoded === "string" ? decoded : decoded && decoded.url;
    if (!embedUrl) continue;

    const url = embedUrl.includes("megaup") ? await getMegaupStream(embedUrl).catch(() => null) : null;
    if (!url) continue;

    results.push({
      id: `${SOURCE.id}-${entry.lang.toLowerCase()}-${results.length}`,
      label: `${entry.lang} - ${entry.name}`,
      quality: "auto",
      type: "hls",
      url,
      headers: {
        Referer: SOURCE.baseUrl,
        "User-Agent": STREAM_UA
      }
    });
  }

  return results;
}

module.exports = {
  SOURCE,
  search,
  details,
  episodes,
  streams
};
