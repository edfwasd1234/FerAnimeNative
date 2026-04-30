const http = require("node:http");
const { URL } = require("node:url");
const animekai = require("./animekai");
const anizone = require("./anizone");
const animeheaven = require("./animeheaven");
const hianime = require("./hianime");
const anigo = require("./anigo");
const metadata = require("./metadata");
const mangakatana = require("./mangakatana");

const PORT = Number(process.env.PORT || process.env.FERANIME_RESOLVER_PORT || 4517);
const resolvers = {
  animeheaven,
  hianime,
  anigo,
  animekai,
  anizone
};
const defaultSourceId = "animeheaven";
const sources = [animeheaven.SOURCE, anigo.SOURCE, animekai.SOURCE, anizone.SOURCE];

function sendJson(res, status, body) {
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  });
  res.end(JSON.stringify(body));
}

function notFound(res) {
  sendJson(res, 404, { error: "Not found" });
}

function sendText(res, status, body, contentType = "text/plain; charset=utf-8") {
  res.writeHead(status, {
    "Content-Type": contentType,
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type"
  });
  res.end(body);
}

async function handle(req, res) {
  if (req.method === "OPTIONS") {
    sendJson(res, 200, { ok: true });
    return;
  }

  const url = new URL(req.url || "/", `http://${req.headers.host}`);
  const parts = url.pathname.split("/").filter(Boolean);

  try {
    if (url.pathname === "/health") {
      sendJson(res, 200, { ok: true, service: "feranime-resolver", sources: sources.map((source) => source.id) });
      return;
    }

    if (url.pathname === "/api/sources") {
      sendJson(res, 200, { sources });
      return;
    }

    if (url.pathname === "/api/mangaList") {
      sendJson(
        res,
        200,
          await mangakatana.list({
          page: Number(url.searchParams.get("page") || 1),
          type: url.searchParams.get("type") || "latest",
          category: url.searchParams.get("category") || "all",
          state: url.searchParams.get("state") || "all"
        })
      );
      return;
    }

    if (parts[0] === "api" && parts[1] === "search" && parts[2]) {
      sendJson(res, 200, await mangakatana.search(decodeURIComponent(parts[2]), Number(url.searchParams.get("page") || 1)));
      return;
    }

    if (parts[0] === "api" && parts[1] === "manga" && parts[2]) {
      if (parts[3]) {
        sendJson(res, 200, await mangakatana.chapter(decodeURIComponent(parts[2]), decodeURIComponent(parts[3])));
        return;
      }
      sendJson(res, 200, await mangakatana.detail(decodeURIComponent(parts[2])));
      return;
    }

    if (url.pathname === "/extensions/hianime.js") {
      const fs = require("node:fs");
      const path = require("node:path");
      const file = path.join(__dirname, "..", "extensions", "hianime.js");
      sendText(res, 200, fs.readFileSync(file, "utf8"), "application/javascript; charset=utf-8");
      return;
    }

    if (url.pathname === "/api/anime/search") {
      const sourceId = url.searchParams.get("sourceId") || defaultSourceId;
      const resolver = resolvers[sourceId];
      if (!resolver) return notFound(res);
      const q = url.searchParams.get("q") || "";
      const page = Number(url.searchParams.get("page") || 1);
      sendJson(res, 200, await resolver.search(q, page));
      return;
    }

    if (url.pathname === "/api/anime/catalog") {
      const sourceId = url.searchParams.get("sourceId") || defaultSourceId;
      const section = url.searchParams.get("section") || "recommended";
      const resolver = resolvers[sourceId];
      if (!resolver || !resolver.catalog) return notFound(res);
      sendJson(res, 200, await resolver.catalog(section));
      return;
    }

    if (url.pathname === "/api/meta/show") {
      const title = url.searchParams.get("title") || "";
      if (!title.trim()) return sendJson(res, 400, { error: "Missing title" });
      sendJson(res, 200, { item: await metadata.showMetadata(title) });
      return;
    }

    if (url.pathname === "/api/meta/episodes") {
      const title = url.searchParams.get("title") || "";
      const malId = url.searchParams.get("malId") || "";
      const anidbId = url.searchParams.get("anidbId") || "";
      sendJson(res, 200, await metadata.episodeMetadata({ title, malId, anidbId }));
      return;
    }

    if (parts[0] === "api" && parts[1] === "anime" && parts[2] && parts[3]) {
      const resolver = resolvers[parts[2]];
      if (!resolver) return notFound(res);
      const id = decodeURIComponent(parts[3]);
      if (parts[4] === "episodes") {
        sendJson(res, 200, { items: await resolver.episodes(id) });
        return;
      }
      sendJson(res, 200, await resolver.details(id));
      return;
    }

    if (parts[0] === "api" && parts[1] === "episodes" && parts[2] && parts[3] && parts[4] === "streams") {
      const resolver = resolvers[parts[2]];
      if (!resolver) return notFound(res);
      const items = await resolver.streams(decodeURIComponent(parts[3]));
      sendJson(res, 200, {
        items,
        warning: items.length ? null : `${parts[2]} did not return a direct playable stream for this episode.`
      });
      return;
    }

    notFound(res);
  } catch (error) {
    sendJson(res, 500, { error: error instanceof Error ? error.message : String(error) });
  }
}

function startServer() {
  return http.createServer(handle).listen(PORT, "0.0.0.0", () => {
    console.log(`FerAnime resolver listening on http://localhost:${PORT}`);
  });
}

if (require.main === module) {
  startServer();
}

module.exports = {
  handle,
  startServer
};
