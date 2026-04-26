import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { router, useLocalSearchParams } from "expo-router";
import React, { useEffect, useMemo, useState } from "react";
import { Image, ImageBackground, ScrollView, Text, View } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withSpring } from "react-native-reanimated";
import { useLibrary } from "../../src/hooks/useLibrary";
import { animeProvider } from "../../src/providers/animeProvider";
import { Anime, Episode, EpisodeMetadata, ShowMetadata } from "../../src/types";
import { GenreChip, Glass, GlassPlayButton, LiftPressable, ProgressLine, StarRating, posters, shows, thumbnails } from "../../src/ui/cinematic";

const cast = ["Lead Voice", "Director", "Studio", "Composer", "Localization"];
const fallbackHero = posters[0].image;

export default function AnimeDetailScreen() {
  const { id, sourceId = "mock" } = useLocalSearchParams<{ id: string; sourceId?: string }>();
  const expanded = useSharedValue(0);
  const [remoteAnime, setRemoteAnime] = useState<Anime | null>(null);
  const [remoteEpisodes, setRemoteEpisodes] = useState<Episode[]>([]);
  const [showMeta, setShowMeta] = useState<ShowMetadata | null>(null);
  const [episodeMeta, setEpisodeMeta] = useState<EpisodeMetadata[]>([]);
  const [status, setStatus] = useState(sourceId === "mock" ? "Mock catalog" : "Loading");
  const library = useLibrary();
  const mockAnime = animeProvider.getAnimeDetails(id);
  const anime = sourceId === "mock" ? mockAnime : remoteAnime;
  const episodes = sourceId === "mock" ? mockAnime?.episodes ?? [] : remoteEpisodes;
  const synopsisStyle = useAnimatedStyle(() => ({
    maxHeight: withSpring(expanded.value ? 220 : 78, { damping: 16, stiffness: 160 })
  }));

  useEffect(() => {
    if (sourceId === "mock") return;
    let mounted = true;
    Promise.all([animeProvider.getAnimeDetailsRemote(sourceId, id), animeProvider.getEpisodesRemote(sourceId, id)])
      .then(([details, nextEpisodes]) => {
        if (!mounted) return;
        setRemoteAnime(details);
        setRemoteEpisodes(nextEpisodes);
        setStatus(`${sourceId} resolver`);
      })
      .catch((error) => {
        if (mounted) setStatus(error instanceof Error ? error.message : "Resolver unavailable");
      });
    return () => {
      mounted = false;
    };
  }, [id, sourceId]);

  useEffect(() => {
    if (!anime?.title) return;
    let mounted = true;
    animeProvider
      .getShowMetadata(anime.title)
      .then((meta) => {
        if (mounted) setShowMeta(meta);
        return animeProvider.getEpisodeMetadata(anime.title, meta?.malId ?? anime.malId, anime.anidbId);
      })
      .then((data) => {
        if (mounted && data?.items) setEpisodeMeta(data.items);
      })
      .catch(() => {});
    return () => {
      mounted = false;
    };
  }, [anime?.title, anime?.malId, anime?.anidbId]);

  const enrichedEpisodes = useMemo(
    () =>
      episodes.map((episode) => {
        const meta = episodeMeta.find((item) => Number(item.number) === Number(episode.number));
        return {
          ...episode,
          title: meta?.title || episode.title,
          aired: meta?.aired || episode.aired,
          score: meta?.score ?? episode.score,
          filler: meta?.filler ?? episode.filler,
          recap: meta?.recap ?? episode.recap,
          duration: meta?.duration || episode.duration
        };
      }),
    [episodeMeta, episodes]
  );

  if (!anime) {
    return (
      <View className="flex-1 items-center justify-center bg-night px-6">
        <Text className="text-3xl font-black text-white">Anime not found</Text>
        <Text className="mt-3 text-center font-bold text-white/45">{status}</Text>
      </View>
    );
  }

  const display = {
    ...anime,
    synopsis: showMeta?.synopsis || anime.synopsis,
    score: showMeta?.score || anime.score,
    year: showMeta?.year || anime.year,
    cover: showMeta?.image || anime.cover,
    banner: anime.banner || showMeta?.image || anime.cover,
    genres: showMeta?.genres?.length ? showMeta.genres : anime.genres
  };
  const firstEpisode = enrichedEpisodes[0];
  const libraryPayload = {
    animeId: anime.id,
    sourceId,
    title: anime.title,
    image: display.cover ?? display.banner,
    progressText: anime.progress
  };

  return (
    <ScrollView className="flex-1 bg-night" showsVerticalScrollIndicator={false}>
      <ImageBackground source={{ uri: display.banner ?? display.cover ?? fallbackHero }} className="h-[560px] justify-end">
        <LinearGradient colors={["rgba(10,10,10,0.08)", "rgba(10,10,10,0.45)", "#0A0A0A"]} className="h-full justify-between px-5 pb-8 pt-14">
          <LiftPressable className="h-12 w-12 items-center justify-center rounded-2xl bg-black/45" onPress={() => router.back()}>
            <Ionicons name="chevron-back" size={24} color="#fff" />
          </LiftPressable>
          <View>
            <Text className="text-xs font-black uppercase tracking-[4px] text-accent">{status}</Text>
            <Text className="mt-3 text-5xl font-black leading-[54px] text-white">{display.title}</Text>
            <View className="mt-4 flex-row flex-wrap gap-2">
              <StarRating value={display.score ? `${display.score}` : sourceId} />
              <GenreChip label={String(display.year ?? "Anime")} active />
              {display.genres.slice(0, 3).map((genre) => <GenreChip key={genre} label={genre} />)}
            </View>
            <View className="mt-7 w-48">
              <GlassPlayButton
                label="Play"
                onPress={() =>
                  firstEpisode &&
                  router.push({
                    pathname: "/watch/[episodeId]",
                    params: {
                      episodeId: firstEpisode.id,
                      sourceId,
                      animeId: anime.id,
                      title: anime.title,
                      episodeTitle: firstEpisode.title,
                      episodeNumber: String(firstEpisode.number),
                      image: display.banner ?? display.cover ?? ""
                    }
                  })
                }
              />
            </View>
          </View>
        </LinearGradient>
      </ImageBackground>

      <View className="px-5">
        <View className="mt-2 flex-row gap-3">
          <Stat label="Episodes" value={showMeta?.episodes ? String(showMeta.episodes) : String(enrichedEpisodes.length || "?")} />
          <Stat label="Audio" value={anime.genres.includes("Dub") ? "Dub" : "Sub"} />
          <Stat label="Status" value={anime.status} />
        </View>

        <View className="mt-5 flex-row gap-3">
          {(["Watching", "Planned", "Completed"] as const).map((nextStatus) => (
            <LiftPressable key={nextStatus} className="flex-1 rounded-2xl bg-white/10 px-3 py-3" onPress={() => library.setStatus(libraryPayload, nextStatus)}>
              <Text className="text-center text-xs font-black text-white">{nextStatus}</Text>
            </LiftPressable>
          ))}
        </View>

        <Animated.View style={synopsisStyle} className="mt-7 overflow-hidden">
          <Text className="text-base font-semibold leading-7 text-white/70">{display.synopsis || "No synopsis available yet."}</Text>
        </Animated.View>
        <LiftPressable
          className="mt-3 self-start rounded-full bg-white/10 px-4 py-2"
          onPress={() => {
            expanded.value = expanded.value ? 0 : 1;
          }}
        >
          <Text className="text-sm font-black text-accent">Read more</Text>
        </LiftPressable>

        <Text className="mb-4 mt-9 text-2xl font-black text-white">Cast & Voices</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          {cast.map((name, index) => (
            <LiftPressable key={name} className="mr-4 items-center">
              <Image source={{ uri: shows[index].image }} className="h-20 w-20 rounded-full" />
              <Text className="mt-3 w-24 text-center text-sm font-black text-white">{name}</Text>
              <Text className="mt-1 text-xs font-bold text-white/42">{showMeta?.studios?.[0] ?? "Production"}</Text>
            </LiftPressable>
          ))}
        </ScrollView>

        <Text className="mb-4 mt-10 text-2xl font-black text-white">Episodes</Text>
        {enrichedEpisodes.map((episode, index) => (
          <LiftPressable
            key={episode.id}
            className="mb-4 overflow-hidden rounded-3xl bg-zinc-950"
            onPress={() =>
              router.push({
                pathname: "/watch/[episodeId]",
                params: {
                  episodeId: episode.id,
                  sourceId,
                  animeId: anime.id,
                  title: anime.title,
                  episodeTitle: episode.title,
                  episodeNumber: String(episode.number),
                  image: display.banner ?? display.cover ?? ""
                }
              })
            }
          >
            <View className="flex-row gap-4 p-3">
              <Image source={{ uri: display.banner ?? display.cover ?? thumbnails[index % thumbnails.length] }} className="h-24 w-36 rounded-2xl" />
              <View className="flex-1 justify-center">
                <Text className="text-xs font-black uppercase tracking-[2px] text-accent">Episode {episode.number}</Text>
                <Text className="mt-1 text-lg font-black text-white" numberOfLines={2}>
                  {episode.title}
                </Text>
                <Text className="mt-1 text-xs font-bold text-white/45">
                  {episode.aired ? new Date(episode.aired).toLocaleDateString() : episode.duration} {episode.filler ? "| Filler" : ""}
                </Text>
                <View className="mt-3">
                  <ProgressLine value={index < 2 ? 35 + index * 25 : 0} />
                </View>
              </View>
            </View>
          </LiftPressable>
        ))}
        {enrichedEpisodes.length === 0 && <Text className="mb-8 text-base font-bold text-white/45">{status}</Text>}
      </View>
      <View className="h-10" />
    </ScrollView>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <Glass className="flex-1 rounded-2xl p-4">
      <Text className="text-lg font-black text-white" numberOfLines={1}>{value}</Text>
      <Text className="mt-1 text-xs font-black uppercase text-white/42">{label}</Text>
    </Glass>
  );
}
