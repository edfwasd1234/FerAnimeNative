const SOURCE = {
  id: "mangahook",
  name: "MangaHook",
  baseUrl: "https://ww6.mangakakalot.tv"
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

function idFromHref(href) {
  const value = decodeHtml(href || "");
  const match = value.match(/\/(?:manga|chapter)\/([^/?#]+)/i);
  return match ? match[1] : value.split("/").filter(Boolean).pop() || value;
}

function chapterIdFromHref(href) {
  const value = decodeHtml(href || "");
  const match = value.match(/\/chapter\/[^/]+\/([^/?#]+)/i);
  return match ? match[1] : value.split("/").filter(Boolean).pop() || value;
}

function normalizeType(type) {
  const value = String(type || "latest").trim().toLowerCase();
  if (value === "popular" || value === "top read" || value === "topread") return "topview";
  if (["newest", "latest", "topview"].includes(value)) return value;
  return "latest";
}

function normalizeFilter(value) {
  const normalized = String(value || "all").trim();
  if (!normalized || /^all$/i.test(normalized)) return "None";
  return normalized;
}

function metaData(totalPages = null) {
  return {
    totalPages,
    type: [
      { id: "latest", type: "Latest" },
      { id: "newest", type: "Newest" },
      { id: "topview", type: "Top Read" }
    ],
    state: [
      { id: "all", type: "All" },
      { id: "Completed", type: "Completed" },
      { id: "Ongoing", type: "Ongoing" }
    ],
    category: [
      { id: "all", type: "All" },
      { id: "Action", type: "Action" },
      { id: "Adventure", type: "Adventure" },
      { id: "Comedy", type: "Comedy" },
      { id: "Drama", type: "Drama" },
      { id: "Fantasy", type: "Fantasy" },
      { id: "Romance", type: "Romance" }
    ]
  };
}

function parseMangaList(html) {
  const items = [];
  const re = /<div[^>]+class=['"][^'"]*list-truyen-item-wrap[^'"]*['"][\s\S]*?(?=<div[^>]+class=['"][^'"]*list-truyen-item-wrap|<\/body>|$)/gi;
  let match;
  while ((match = re.exec(html || "")) !== null) {
    const block = match[0];
    const link = block.match(/<a[^>]+href=['"]([^'"]+)['"][\s\S]*?<img[^>]+(?:data-src|src)=['"]([^'"]+)['"]/i);
    const title = cleanText((block.match(/<h3[\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i) || [])[1]);
    if (!link || !title) continue;
    items.push({
      id: idFromHref(link[1]),
      image: absoluteUrl(link[2]),
      title,
      chapter: cleanText((block.match(/class=['"][^'"]*list-story-item-wrap-chapter[^'"]*['"][^>]*>([\s\S]*?)<\/[^>]+>/i) || [])[1]),
      view: cleanText((block.match(/class=['"][^'"]*aye_icon[^'"]*['"][^>]*>([\s\S]*?)<\/[^>]+>/i) || [])[1]),
      description: cleanText((block.match(/<p[^>]*>([\s\S]*?)<\/p>/i) || [])[1]).replace(/More\./i, "...").trim()
    });
  }
  return items;
}

function parseSearchList(html) {
  const items = [];
  const re = /<div[^>]+class=['"][^'"]*story_item[^'"]*['"][\s\S]*?(?=<div[^>]+class=['"][^'"]*story_item|<\/body>|$)/gi;
  let match;
  while ((match = re.exec(html || "")) !== null) {
    const block = match[0];
    const link = block.match(/<a[^>]+href=['"]([^'"]+)['"][\s\S]*?<img[^>]+src=['"]([^'"]+)['"]/i);
    const title = cleanText((block.match(/<h3[\s\S]*?<a[^>]*>([\s\S]*?)<\/a>/i) || [])[1]);
    if (!link || !title) continue;
    items.push({
      id: idFromHref(link[1]),
      image: absoluteUrl(link[2]),
      title,
      chapter: null,
      view: null,
      description: null
    });
  }
  return items;
}

function parseTotalPages(html) {
  const pages = [...String(html || "").matchAll(/[?&]page=(\d+)/gi)].map((match) => Number.parseInt(match[1], 10));
  return pages.length ? Math.max(...pages.filter(Number.isFinite)) : null;
}

async function list({ page = 1, type = "latest", category = "all", state = "all" } = {}) {
  const params = new URLSearchParams({
    type: normalizeType(type),
    category: normalizeFilter(category),
    state: normalizeFilter(state),
    page: String(page || 1)
  });
  const html = await requestText(`${SOURCE.baseUrl}/manga_list?${params}`);
  return {
    mangaList: parseMangaList(html),
    metaData: metaData(parseTotalPages(html))
  };
}

async function search(query, page = 1) {
  const value = encodeURIComponent(String(query || "").trim());
  if (!value) return { mangaList: [], metaData: metaData(0) };
  const html = await requestText(`${SOURCE.baseUrl}/search/${value}?page=${Number(page) || 1}`);
  return {
    mangaList: parseSearchList(html),
    metaData: metaData(parseTotalPages(html))
  };
}

function parseDetail(html, id) {
  const top = (html.match(/<div[^>]+class=['"][^'"]*manga-info-top[^'"]*['"][\s\S]*?(?=<div[^>]+class=['"][^'"]*chapter-list|$)/i) || [])[0] || html;
  const image = attr((top.match(/class=['"][^'"]*manga-info-pic[^'"]*['"][\s\S]*?<img[^>]+>/i) || [])[0], "src");
  const name = cleanText((top.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i) || [])[1]);
  const text = cleanText(top);
  const lineValue = (label) => {
    const match = text.match(new RegExp(`${label}:\\s*([^:]+?)(?:\\s{2,}|$)`, "i"));
    return match ? match[1].trim() : null;
  };
  const genresText = lineValue("Genres") || "";
  return {
    imageUrl: absoluteUrl(image),
    name: name || id,
    author: lineValue("Author"),
    status: lineValue("Status"),
    updated: lineValue("Last updated"),
    view: lineValue("View"),
    genres: genresText ? genresText.split(",").map((item) => item.trim()).filter(Boolean) : [],
    chapterList: parseChapterList(html)
  };
}

function parseChapterList(html) {
  const chapters = [];
  const re = /<div[^>]+class=['"][^'"]*\brow\b[^'"]*['"][\s\S]*?<\/div>/gi;
  let match;
  while ((match = re.exec(html || "")) !== null) {
    const block = match[0];
    const link = block.match(/<a[^>]+href=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/a>/i);
    if (!link) continue;
    const spans = [...block.matchAll(/<span[^>]*>([\s\S]*?)<\/span>/gi)].map((span) => cleanText(span[1]));
    chapters.push({
      id: chapterIdFromHref(link[1]),
      path: decodeHtml(link[1]),
      name: cleanText(link[2]),
      view: spans[1] || null,
      createdAt: spans[2] || null
    });
  }
  return chapters;
}

async function detail(id) {
  const mangaId = String(id || "").trim();
  const html = await requestText(`${SOURCE.baseUrl}/manga/${encodeURIComponent(mangaId)}`);
  return parseDetail(html, mangaId);
}

function parseChapter(html) {
  const breadcrumb = cleanText((html.match(/<div[^>]+class=['"][^'"]*breadcrumb[^'"]*['"][\s\S]*?<\/div>/i) || [])[0])
    .split("»")
    .map((item) => item.trim())
    .filter(Boolean);
  const options = [...String(html || "").matchAll(/<option[^>]+value=['"]([^'"]+)['"][^>]*>([\s\S]*?)<\/option>/gi)].map((match) => ({
    id: decodeHtml(match[1]),
    name: cleanText(match[2])
  }));
  const images = [...String(html || "").matchAll(/<img[^>]+(?:data-src|src)=['"]([^'"]+)['"][^>]*>/gi)]
    .map((match) => ({
      title: attr(match[0], "title"),
      image: absoluteUrl(match[1])
    }))
    .filter((item) => item.image && !/logo|avatar|banner/i.test(item.image));
  return {
    title: breadcrumb[3] || breadcrumb[breadcrumb.length - 2] || "",
    currentChapter: breadcrumb[4] || breadcrumb[breadcrumb.length - 1] || "",
    chapterListIds: options,
    images
  };
}

async function chapter(mangaId, chapterId) {
  const html = await requestText(`${SOURCE.baseUrl}/chapter/${encodeURIComponent(mangaId)}/${encodeURIComponent(chapterId)}`);
  return parseChapter(html);
}

module.exports = {
  SOURCE,
  list,
  search,
  detail,
  chapter
};
