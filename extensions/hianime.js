// HiAnime — Kazemi JS extension
// Source: https://hianime.city
// This extension follows the Kakuga/Kazemi shape: SOURCE plus
// fetchSearch, fetchPopular, fetchLatest, fetchItemDetails,
// fetchChildren, and fetchVideoList.

const SOURCE = {
  id: "hianime",
  name: "HiAnime",
  baseUrl: "https://hianime.city",
  language: "en",
  version: "1.0.0",
  iconUrl: "https://hianime.city/favicon.ico",
  contentKind: "anime",
  supportsPopular: true,
  supportedTypes: ["tv", "movie", "ova", "ona", "special"],
  filters: [
    {
      name: "genre",
      options: [
        { id: "action", label: "Action" },
        { id: "adventure", label: "Adventure" },
        { id: "comedy", label: "Comedy" },
        { id: "drama", label: "Drama" },
        { id: "fantasy", label: "Fantasy" },
        { id: "romance", label: "Romance" },
        { id: "school", label: "School" },
        { id: "sci-fi", label: "Sci-Fi" },
        { id: "shounen", label: "Shounen" },
        { id: "slice-of-life", label: "Slice of Life" },
        { id: "sports", label: "Sports" },
        { id: "supernatural", label: "Supernatural" }
      ]
    },
    {
      name: "language",
      options: [
        { id: "sub", label: "Sub" },
        { id: "dub", label: "Dub" }
      ]
    }
  ]
};

var PAGE_HEADERS = {
  "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Safari/537.36",
  "Referer": SOURCE.baseUrl + "/"
};

function getHtml(url) {
  return http.get(url, PAGE_HEADERS);
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
    .replace(/&#(\d+);/g, function (_, dec) { return String.fromCharCode(parseInt(dec, 10)); });
}

function cleanText(text) {
  return decodeHtml((text || "").replace(/<script[\s\S]*?<\/script>/gi, " ").replace(/<[^>]+>/g, " "))
    .replace(/\s+/g, " ")
    .trim();
}

function absoluteUrl(url) {
  if (!url) return null;
  var value = decodeHtml(String(url).trim());
  if (/^https?:\/\//i.test(value)) return value;
  if (/^\/\//.test(value)) return "https:" + value;
  if (value.charAt(0) === "/") return SOURCE.baseUrl + value;
  return SOURCE.baseUrl + "/" + value.replace(/^\/+/, "");
}

function slugFromSeriesUrl(url) {
  var absolute = absoluteUrl(url) || "";
  var match = absolute.match(/\/series\/([^/]+)\//i);
  return match ? match[1] : "";
}

function parseCards(html) {
  var items = [];
  var seen = {};
  var re = /<article\s+class="bs"[\s\S]*?<\/article>/gi;
  var match;

  while ((match = re.exec(html || "")) !== null) {
    var block = match[0];
    var hrefM = block.match(/<a\s+href="([^"]+\/series\/[^"]+)"[^>]*title="([^"]+)"/i);
    if (!hrefM) continue;

    var id = slugFromSeriesUrl(hrefM[1]);
    if (!id || seen[id]) continue;
    seen[id] = true;

    var imgM = block.match(/<img[^>]+(?:data-src|src)="([^"]+)"[^>]*>/i);
    var statusM = block.match(/<div\s+class="status[^"]*">([^<]+)<\/div>/i);
    var typeM = block.match(/<div\s+class="typez[^"]*">([^<]+)<\/div>/i);
    var langM = block.match(/<span\s+class="sb\s+([^"]+)">([^<]+)<\/span>/i);
    var title = cleanText(hrefM[2]);
    var language = langM ? cleanText(langM[2]) : title.toLowerCase().indexOf("(dub)") !== -1 ? "Dub" : "Sub";

    items.push({
      id: id,
      slug: id,
      title: title,
      thumbnail: absoluteUrl(imgM ? imgM[1] : null),
      banner: absoluteUrl(imgM ? imgM[1] : null),
      type: typeM ? cleanText(typeM[1]) : "Anime",
      status: statusM ? cleanText(statusM[1]) : null,
      genres: [language],
      language: language,
      pageUrl: absoluteUrl(hrefM[1])
    });
  }

  return items;
}

function catalogUrl(section, filters) {
  if (filters && filters.genre) return SOURCE.baseUrl + "/genres/" + encodeURIComponent(filters.genre) + "/";
  if (section === "latest") return SOURCE.baseUrl + "/";
  return SOURCE.baseUrl + "/series/?status=&type=&order=popular";
}

function fetchSearch(query, page, filters) {
  var q = (query || "").trim();
  var url = q ? SOURCE.baseUrl + "/?s=" + encodeURIComponent(q) : catalogUrl("popular", filters);
  var items = parseCards(getHtml(url));

  if (filters && filters.language) {
    var lang = String(filters.language).toLowerCase();
    items = items.filter(function (item) {
      return String(item.language || "").toLowerCase() === lang;
    });
  }

  return { items: items, hasNextPage: false };
}

function fetchPopular(page) {
  return { items: parseCards(getHtml(catalogUrl("popular"))), hasNextPage: false };
}

function fetchLatest(page) {
  return { items: parseCards(getHtml(catalogUrl("latest"))), hasNextPage: false };
}

function fetchItemDetails(id) {
  var url = SOURCE.baseUrl + "/series/" + encodeURIComponent(id) + "/";
  var html = getHtml(url);
  var titleM = html.match(/<h1\s+class="entry-title"[^>]*>([\s\S]*?)<\/h1>/i);
  var descM = html.match(/<div\s+class="mindesc">([\s\S]*?)<\/div>/i);
  var coverM = html.match(/<img[^>]+class="[^"]*wp-post-image[^"]*"[^>]+(?:data-src|src)="([^"]+)"/i);
  var bannerM = html.match(/<div\s+class="bigcover"[\s\S]*?<img[^>]+(?:data-src|src)="([^"]+)"/i);
  var statusM = html.match(/<b>Status:<\/b>\s*([^<]+)<\/span>/i);
  var releasedM = html.match(/<b>Released:<\/b>\s*([^<]+)<\/span>/i);
  var scoreM = html.match(/<strong>Rating\s+([0-9.]+)<\/strong>/i);
  var typeM = html.match(/<b>Type:<\/b>\s*([^<]+)<\/span>/i);
  var isDub = /(\(Dub\)|-dub\b|\/dub\b)/i.test(id + " " + (titleM ? titleM[1] : ""));
  var language = isDub ? "Dub" : "Sub";
  var genres = [language];
  var genreBlock = (html.match(/<div\s+class="genxed">([\s\S]*?)<\/div>/i) || [])[1] || "";
  var linkRe = /<a[^>]+>([^<]+)<\/a>/g;
  var genreM;
  while ((genreM = linkRe.exec(genreBlock)) !== null) {
    var genre = cleanText(genreM[1]);
    if (genre && genres.indexOf(genre) === -1) genres.push(genre);
  }

  return {
    id: id,
    slug: id,
    title: titleM ? cleanText(titleM[1]) : id,
    synopsis: descM ? cleanText(descM[1]) : "",
    thumbnail: absoluteUrl(coverM ? coverM[1] : null),
    banner: absoluteUrl(bannerM ? bannerM[1] : coverM ? coverM[1] : null),
    type: typeM ? cleanText(typeM[1]) : "Anime",
    status: statusM ? cleanText(statusM[1]) : null,
    genres: genres,
    language: language,
    year: releasedM ? cleanText(releasedM[1]) : null,
    rating: scoreM ? scoreM[1] + "/10" : null,
    pageUrl: url,
    related: []
  };
}

function fetchChildren(itemId) {
  var html = getHtml(SOURCE.baseUrl + "/series/" + encodeURIComponent(itemId) + "/");
  var titleM = html.match(/<h1\s+class="entry-title"[^>]*>([\s\S]*?)<\/h1>/i);
  var seriesTitle = titleM ? cleanText(titleM[1]) : itemId;
  var language = /(\(Dub\)|-dub\b)/i.test(itemId + " " + seriesTitle) ? "Dub" : "Sub";
  var episodes = [];
  var re = /<li\s+data-index="[^"]*">\s*<a\s+href="([^"]+)"[^>]*>\s*<div\s+class="epl-num">([\s\S]*?)<\/div>\s*<div\s+class="epl-title">([\s\S]*?)<\/div>/gi;
  var match;

  while ((match = re.exec(html || "")) !== null) {
    var href = absoluteUrl(match[1]);
    var label = cleanText(match[2]);
    var title = cleanText(match[3]) || "Episode " + label;
    var number = parseFloat(label.replace(/[^0-9.]/g, ""));
    if (isNaN(number)) number = episodes.length + 1;
    episodes.push({
      id: encodeURIComponent(href),
      number: number,
      title: title + " (" + language + ")",
      pageUrl: href,
      language: language
    });
  }

  episodes.sort(function (a, b) { return a.number - b.number; });
  return episodes;
}

function fetchVideoList(episodeId) {
  var episodeUrl = decodeURIComponent(episodeId || "");
  var html = getHtml(episodeUrl);
  var out = [];
  var seen = {};
  var directRe = /https?:\/\/[^"'<>\\\s]+\.(?:m3u8|mp4)[^"'<>\\\s]*/gi;
  var dm;
  while ((dm = directRe.exec(html)) !== null) {
    var directUrl = absoluteUrl(dm[0]);
    if (!directUrl || seen[directUrl]) continue;
    seen[directUrl] = true;
    out.push({
      url: directUrl,
      server: directUrl.indexOf(".m3u8") !== -1 ? "hianime-hls" : "hianime-mp4",
      quality: directUrl.indexOf("/dub") !== -1 ? "Dub" : directUrl.indexOf("/sub") !== -1 ? "Sub" : "Auto",
      type: directUrl.indexOf(".m3u8") !== -1 ? "hls" : "mp4",
      headers: { "Referer": SOURCE.baseUrl + "/" }
    });
  }

  var embeds = [];
  var directM = html.match(/<iframe[^>]+data-litespeed-src="([^"]+)"/i) || html.match(/<iframe[^>]+src="([^"]+)"/i);
  if (directM) embeds.push(absoluteUrl(directM[1]));

  var optionRe = /<option[^>]+value="([^"]+)"[^>]*>([\s\S]*?)<\/option>/gi;
  var optionM;
  while ((optionM = optionRe.exec(html)) !== null) {
    try {
      var decoded = atob(decodeHtml(optionM[1]));
      var srcM = decoded.match(/src="([^"]+)"/i);
      if (srcM) embeds.push(absoluteUrl(srcM[1]));
    } catch (e) {}
  }

  for (var i = 0; i < embeds.length; i++) {
    if (!embeds[i] || seen[embeds[i]]) continue;
    seen[embeds[i]] = true;
    out.push({
      url: embeds[i],
      server: "hianime-embed",
      quality: embeds[i].indexOf("/dub") !== -1 ? "Dub Embed" : embeds[i].indexOf("/sub") !== -1 ? "Sub Embed" : "Embed",
      type: "iframe",
      headers: { "Referer": SOURCE.baseUrl + "/" }
    });
  }

  return out;
}
