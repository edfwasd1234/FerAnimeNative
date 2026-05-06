const SOURCE = {
  id: "vsembed",
  name: "Vidsrc/VSEmbed",
  baseUrl: process.env.VSEMBED_BASE_URL || "https://vidsrc-embed.ru"
};

function cleanId(value) {
  const raw = String(value || "").trim();
  if (!raw) return "";
  const parts = raw.split(":");
  return parts.length > 1 ? parts[1] : raw;
}

function movieEmbed(id, options = {}) {
  const tmdb = cleanId(id);
  if (!tmdb) throw new Error("Missing movie TMDB id");
  const url = new URL(`${SOURCE.baseUrl}/embed/movie`);
  url.searchParams.set("tmdb", tmdb);
  url.searchParams.set("autoplay", options.autoplay ?? "1");
  if (options.subtitleLanguage) url.searchParams.set("ds_lang", options.subtitleLanguage);
  if (options.subtitleUrl) url.searchParams.set("sub_url", options.subtitleUrl);
  return url.toString();
}

function tvEmbed(id, season = 1, episode = 1, options = {}) {
  const tmdb = cleanId(id);
  if (!tmdb) throw new Error("Missing TV TMDB id");
  const url = new URL(`${SOURCE.baseUrl}/embed/tv`);
  url.searchParams.set("tmdb", tmdb);
  url.searchParams.set("season", String(season || 1));
  url.searchParams.set("episode", String(episode || 1));
  url.searchParams.set("autoplay", options.autoplay ?? "1");
  url.searchParams.set("autonext", options.autonext ?? "1");
  if (options.subtitleLanguage) url.searchParams.set("ds_lang", options.subtitleLanguage);
  if (options.subtitleUrl) url.searchParams.set("sub_url", options.subtitleUrl);
  return url.toString();
}

function streams({ kind, id, season, episode, subtitleLanguage, subtitleUrl }) {
  const isShow = ["show", "tv"].includes(String(kind || "").toLowerCase());
  const url = isShow
    ? tvEmbed(id, season, episode, { subtitleLanguage, subtitleUrl })
    : movieEmbed(id, { subtitleLanguage, subtitleUrl });
  return [{
    id: `${SOURCE.id}-${isShow ? "tv" : "movie"}-${cleanId(id)}-${season || 0}-${episode || 0}`,
    label: isShow ? `Episode ${season || 1}x${episode || 1}` : "Movie",
    quality: "embed",
    type: "embed",
    url,
    headers: {
      Referer: SOURCE.baseUrl
    }
  }];
}

module.exports = {
  SOURCE,
  streams,
  movieEmbed,
  tvEmbed
};
