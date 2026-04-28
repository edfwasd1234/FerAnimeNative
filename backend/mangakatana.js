const SOURCE = {
  id: "mangakatana",
  name: "MangaKatana",
  baseUrl: "https://mangakatana.com"
};

const PAGE_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
  Referer: `${SOURCE.baseUrl}/`,
  Accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
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

function absoluteUrl(url) {
  if (!url) return null;
  const value = decodeHtml(String(url).trim());
  if (/^https?:\/\//i.test(value)) return value;
  if (value.startsWith("//")) return `https:${value}`;
  if (value.startsWith("/")) return `${SOURCE.baseUrl}${value}`;
  return `${SOURCE.baseUrl}/${value.replace(/^\/+/, "")}`;
}

function mangaIdFromHref(href) {
  const value = decodeHtml(href || "");
  const match = value.match(/\/manga\/([^/?#]+)/i);
  return match ? match[1] : value.split("/").filter(Boolean).pop() || value;
}

function chapterIdFromHref(href) {
  const value = decodeHtml(href || "");
  const match = value.match(/\/manga\/[^/]+\/([^/?#]+)/i);
  return match ? match[1] : value.split("/").filter(Boolean).pop() || value;
}

function metaData(totalPages = null) {
  return {
    totalPages,
    type: [
      { id: "latest", type: "Latest Updates" },
      { id: "newest", type: "New Manga" },
      { id: "topview", type: "Hot Manga" }
    ],
    state: [
      { id: "all", type: "All" },
      { id: "completed", type: "Completed" },
      { id: "ongoing", type: "Ongoing" }
    ],
    category: [
      { id: "all", type: "All" },
      { id: "action", type: "Action" },
      { id: "adventure", type: "Adventure" },
      { id: "comedy", type: "Comedy" },
      { id: "drama", type: "Drama" },
      { id: "fantasy", type: "Fantasy" },
      { id: "romance", type: "Romance" }
    ]
  };
}

function parseBookItems(html) {
  const items = [];
  const seen = new Set();
  const re = /<div[^>]+class=['"][^'"]*\bitem\b[^'"]*['"][^>]*data-id=['"][^'"]+['"][\s\S]*?(?=<div[^>]+class=['"][^'"]*\bitem\b[^'"]*['"][^>]*data-id=|<\/body>|$)/gi;
  let match;

  while ((match = re.exec(html || "")) !== null) {
    const block = match[0];
    const href = attr((block.match(/<a[^>]+href=['"][^'"]*\/manga\/[^'"]+['"][^>]*>/i) || [])[0], "href");
    const id = mangaIdFromHref(href);
    if (!id || seen.has(id)) continue;

    const imageTag = (block.match(/<img[^>]+>/i) || [])[0] || "";
    const title =
      cleanText((block.match(/<h[34][^>]+class=['"][^'"]*title[^'"]*['"][\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i) || [])[1]) ||
      cleanText(attr(imageTag, "alt")).replace(/^\[Cover\]\s*/i, "");
    if (!title) continue;

    seen.add(id);
    items.push({
      id,
      image: absoluteUrl(attr(imageTag, "data-src") || attr(imageTag, "src")),
      title,
      chapter: cleanText((block.match(/<div[^>]+class=['"][^'"]*chapter[^'"]*['"][\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i) || [])[1]),
      view: cleanText((block.match(/<div[^>]+class=['"][^'"]*status[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i) || [])[1]),
      description: cleanText((block.match(/<div[^>]+class=['"][^'"]*summary[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i) || [])[1])
    });
  }
  return items;
}

function parseTotalPages(html) {
  const pages = [...String(html || "").matchAll(/(?:\/page\/|[?&]page=)(\d+)/gi)].map((match) => Number.parseInt(match[1], 10));
  return pages.length ? Math.max(...pages.filter(Number.isFinite)) : null;
}

function listUrl({ page = 1, type = "latest", category = "all", state = "all" } = {}) {
  const safePage = Math.max(1, Number(page) || 1);
  const safeType = String(type || "latest").toLowerCase();
  const safeCategory = String(category || "all").toLowerCase();
  const safeState = String(state || "all").toLowerCase();

  if (safeCategory !== "all") return `${SOURCE.baseUrl}/genre/${encodeURIComponent(safeCategory)}${safePage > 1 ? `/page/${safePage}` : ""}`;
  if (safeState === "completed") return `${SOURCE.baseUrl}/completed${safePage > 1 ? `/page/${safePage}` : ""}`;
  if (safeType === "newest") return `${SOURCE.baseUrl}/new-manga${safePage > 1 ? `/page/${safePage}` : ""}`;
  if (safeType === "topview") return `${SOURCE.baseUrl}/`;
  return `${SOURCE.baseUrl}/latest${safePage > 1 ? `/page/${safePage}` : ""}`;
}

async function list(options = {}) {
  const html = await requestText(listUrl(options));
  return {
    mangaList: parseBookItems(html),
    metaData: metaData(parseTotalPages(html))
  };
}

async function search(query, page = 1) {
  const value = String(query || "").trim();
  if (!value) return { mangaList: [], metaData: metaData(0) };
  const params = new URLSearchParams({ search: value });
  const safePage = Math.max(1, Number(page) || 1);
  if (safePage > 1) params.set("page", String(safePage));
  const html = await requestText(`${SOURCE.baseUrl}/?${params}`);
  return {
    mangaList: parseBookItems(html),
    metaData: metaData(parseTotalPages(html))
  };
}

function parseDetail(html, id) {
  const image = attr((html.match(/<div[^>]+class=['"][^'"]*cover[^'"]*['"][\s\S]*?<img[^>]+>/i) || [])[0], "src");
  const name = cleanText((html.match(/<h1[^>]+class=['"][^'"]*heading[^'"]*['"][^>]*>([\s\S]*?)<\/h1>/i) || [])[1]);
  const author = cleanText((html.match(/<div[^>]+class=['"][^'"]*value authors[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i) || [])[1]);
  const genresBlock = (html.match(/<div[^>]+class=['"][^'"]*genres[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i) || [])[1] || "";
  const genres = [...genresBlock.matchAll(/<a[^>]*>([\s\S]*?)<\/a>/gi)].map((match) => cleanText(match[1])).filter(Boolean);
  const description = cleanText((html.match(/<div[^>]+class=['"][^'"]*summary[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i) || [])[1]);
  const text = cleanText(html);

  return {
    imageUrl: absoluteUrl(image),
    name: name || id,
    author,
    status: text.match(/\bOngoing\b/i) ? "Ongoing" : text.match(/\bCompleted\b/i) ? "Completed" : null,
    updated: null,
    view: description,
    genres,
    chapterList: parseChapterList(html)
  };
}

function parseChapterList(html) {
  const chapters = [];
  const re = /<tr[^>]*data-jump=['"][^'"]*['"][\s\S]*?<\/tr>/gi;
  let match;
  while ((match = re.exec(html || "")) !== null) {
    const block = match[0];
    const link = block.match(/<a[^>]+href=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/i);
    if (!link) continue;
    chapters.push({
      id: chapterIdFromHref(link[1]),
      path: decodeHtml(link[1]),
      name: cleanText(link[2]),
      view: null,
      createdAt: cleanText((block.match(/<div[^>]+class=['"][^'"]*update_time[^'"]*['"][^>]*>([\s\S]*?)<\/div>/i) || [])[1])
    });
  }
  return chapters;
}

async function detail(id) {
  const mangaId = String(id || "").trim();
  const html = await requestText(`${SOURCE.baseUrl}/manga/${encodeURIComponent(mangaId)}`);
  return parseDetail(html, mangaId);
}

function parseChapter(html, mangaId, chapterId) {
  const options = [...String(html || "").matchAll(/<option[^>]+value=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/option>/gi)].map((match) => ({
    id: decodeHtml(match[1]),
    name: cleanText(match[2])
  }));
  const tokenImages = [...String(html || "").matchAll(/https?:\/\/i\d+\.mangakatana\.com\/token\/[^'"]+\.(?:jpg|png|webp)/gi)]
    .map((match) => decodeHtml(match[0]));
  const unique = [...new Set(tokenImages)];
  return {
    title: cleanText((html.match(/<meta\s+property=['"]og:title['"]\s+content=['"]([^'"]+)['"]/i) || [])[1]),
    currentChapter: options.find((option) => option.id === chapterId)?.name || chapterId,
    chapterListIds: options,
    images: unique.map((image, index) => ({
      title: `Page ${index + 1}`,
      image
    }))
  };
}

async function chapter(mangaId, chapterId) {
  const safeMangaId = String(mangaId || "").trim();
  const safeChapterId = String(chapterId || "").trim();
  const html = await requestText(`${SOURCE.baseUrl}/manga/${encodeURIComponent(safeMangaId)}/${encodeURIComponent(safeChapterId)}`);
  return parseChapter(html, safeMangaId, safeChapterId);
}

module.exports = {
  SOURCE,
  list,
  search,
  detail,
  chapter
};
