import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import { router } from "expo-router";
import React, { useEffect, useMemo, useState } from "react";
import { Dimensions, ImageBackground, ScrollView, Text, View } from "react-native";
import Animated, { interpolate, SharedValue, useAnimatedScrollHandler, useAnimatedStyle, useSharedValue } from "react-native-reanimated";
import { useAllEpisodeProgress } from "../../src/hooks/useProgress";
import { animeProvider } from "../../src/providers/animeProvider";
import { Anime } from "../../src/types";
import { GenreChip, Glass, GlassPlayButton, HeroBackdrop, LiftPressable, PosterTile, ProgressLine, SectionHeader, StarRating, shows } from "../../src/ui/cinematic";

const { width } = Dimensions.get("window");
const AnimatedScrollView = Animated.createAnimatedComponent(ScrollView);
const fallbackHero = "https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=1200&q=80";

export default function HomeScreen() {
  const scrollX = useSharedValue(0);
  const mockAnime = animeProvider.listTrending();
  const savedProgress = useAllEpisodeProgress();
  const [sections, setSections] = useState<Record<string, Anime[]>>({
    recommended: mockAnime,
    trending: mockAnime,
    popular: mockAnime,
    top: mockAnime
  });
  const [mode, setMode] = useState("Live catalog");
  const heroes = useMemo(() => sections.recommended.slice(0, 3), [sections.recommended]);
  const onScroll = useAnimatedScrollHandler((event) => {
    scrollX.value = event.contentOffset.x;
  });

  useEffect(() => {
    let mounted = true;
    Promise.all([
      animeProvider.getCatalogRemote("recommended"),
      animeProvider.getCatalogRemote("trending"),
      animeProvider.getCatalogRemote("new"),
      animeProvider.getCatalogRemote("action")
    ])
      .then(([recommended, trending, popular, top]) => {
        if (!mounted) return;
        setSections({
          recommended: recommended.length ? recommended : mockAnime,
          trending: trending.length ? trending : mockAnime,
          popular: popular.length ? popular : mockAnime,
          top: top.length ? top : mockAnime
        });
        setMode("AnimeHeaven live");
      })
      .catch(() => {
        if (mounted) setMode("Mock fallback");
      });
    return () => {
      mounted = false;
    };
  }, []);

  return (
    <ScrollView className="flex-1 bg-night" showsVerticalScrollIndicator={false}>
      <AnimatedScrollView horizontal pagingEnabled showsHorizontalScrollIndicator={false} onScroll={onScroll} scrollEventThrottle={16} className="bg-night">
        {heroes.map((item, index) => (
          <HeroSlide key={`${item.sourceId}-${item.id}`} item={item} index={index} scrollX={scrollX} />
        ))}
      </AnimatedScrollView>
      <View className="absolute right-4 top-24 gap-1.5">
        {heroes.map((item, index) => (
          <View key={`dot-${item.id}`} className={`w-1 rounded-full ${index === 0 ? "h-6 bg-accent" : "h-2 bg-white/30"}`} />
        ))}
      </View>

      <View className="-mt-16 px-5">
        <Glass className="rounded-3xl p-4">
          <View className="flex-row items-center justify-between">
            <View>
              <Text className="text-xs font-black uppercase tracking-[3px] text-accent">Tonight's spotlight</Text>
              <Text className="mt-1 text-xl font-black text-white">{mode}</Text>
            </View>
            <View className="h-12 w-12 items-center justify-center rounded-2xl bg-white/10">
              <Ionicons name="sparkles" size={20} color="#FF6B35" />
            </View>
          </View>
        </Glass>
      </View>

      <SectionHeader title="Continue Watching" />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="px-5">
        {(savedProgress.items.length ? savedProgress.items : mockAnime.slice(0, 4).map((item, index) => ({
          episodeId: item.episodes?.[index]?.id ?? item.episodes?.[0]?.id,
          animeId: item.id,
          sourceId: "mock",
          animeTitle: item.title,
          episodeTitle: item.episodes?.[index]?.title ?? item.episodes?.[0]?.title,
          episodeNumber: item.episodes?.[index]?.number ?? item.episodes?.[0]?.number,
          image: item.banner ?? item.cover,
          currentTime: 38 + index * 14,
          duration: 100,
          updatedAt: new Date().toISOString()
        }))).slice(0, 6).map((progress, index) => {
          const item = mockAnime.find((anime) => anime.id === progress.animeId) ?? mockAnime[index % mockAnime.length];
          const episode = item.episodes?.[index] ?? item.episodes?.[0];
          return (
            <LiftPressable
              key={progress.episodeId ?? `${item.id}-${index}`}
              className="mr-4 w-72 overflow-hidden rounded-3xl bg-zinc-950 shadow-2xl"
              onPress={() =>
                progress.episodeId &&
                router.push({
                  pathname: "/watch/[episodeId]",
                  params: {
                    episodeId: progress.episodeId,
                    sourceId: progress.sourceId ?? "mock",
                    animeId: progress.animeId ?? item.id,
                    title: progress.animeTitle ?? item.title,
                    episodeTitle: progress.episodeTitle ?? episode?.title,
                    episodeNumber: String(progress.episodeNumber ?? episode?.number ?? 1),
                    image: progress.image ?? item.banner ?? item.cover ?? ""
                  }
                })
              }
            >
              <ImageBackground source={{ uri: progress.image ?? item.banner ?? item.cover ?? fallbackHero }} className="h-40 justify-end overflow-hidden">
                <LinearGradient colors={["transparent", "rgba(0,0,0,0.94)"]} className="p-4">
                  <Text className="text-lg font-black text-white">{progress.animeTitle ?? item.title}</Text>
                  <Text className="mt-1 text-xs font-bold text-white/60">Episode {progress.episodeNumber ?? episode?.number ?? 1} | resume</Text>
                  <View className="mt-4">
                    <ProgressLine value={progress.duration ? (progress.currentTime / progress.duration) * 100 : 0} />
                  </View>
                </LinearGradient>
              </ImageBackground>
            </LiftPressable>
          );
        })}
      </ScrollView>

      <Rail title="Trending" items={sections.trending} />
      <Rail title="Popular This Season" items={sections.popular} />
      <Rail title="Top Rated" items={sections.top} large />
      <View className="h-10" />
    </ScrollView>
  );
}

function HeroSlide({ item, index, scrollX }: { item: Anime; index: number; scrollX: SharedValue<number> }) {
  const style = useAnimatedStyle(() => {
    const input = [(index - 1) * width, index * width, (index + 1) * width];
    return {
      transform: [
        { scale: interpolate(scrollX.value, input, [0.94, 1, 0.94]) },
        { translateY: interpolate(scrollX.value, input, [20, 0, 20]) }
      ]
    };
  });

  return (
    <Animated.View style={[{ width }, style]}>
      <HeroBackdrop image={item.banner ?? item.cover ?? fallbackHero}>
        <View className="mb-20">
          <View className="flex-row flex-wrap gap-2">
            {item.genres.slice(0, 3).map((genre, genreIndex) => (
              <GenreChip key={genre} label={genre} active={genreIndex === 0} />
            ))}
          </View>
          <Text className="mt-4 text-6xl font-black leading-[62px] text-white" numberOfLines={2}>
            {item.title}
          </Text>
          <Text className="mt-4 max-w-[330px] text-base font-semibold leading-6 text-white/76" numberOfLines={3}>
            {item.synopsis || item.subtitle}
          </Text>
          <View className="mt-5 flex-row flex-wrap gap-2">
            <StarRating value={item.score ? `${item.score}` : item.sourceId ?? "Live"} />
            <Text className="text-xs font-black text-white/60">{item.year ?? "Anime"}</Text>
            <Text className="text-xs font-black text-white/60">Sub | Dub</Text>
          </View>
          <View className="mt-7 w-44">
            <GlassPlayButton label="Play" onPress={() => router.push({ pathname: "/anime/[id]", params: { id: item.id, sourceId: item.sourceId ?? "mock" } })} />
          </View>
        </View>
      </HeroBackdrop>
    </Animated.View>
  );
}

function Rail({ title, items, large = false }: { title: string; items: Anime[]; large?: boolean }) {
  return (
    <View>
      <SectionHeader title={title} />
      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerClassName="px-5">
        {items.map((item) => (
          <PosterTile
            key={`${title}-${item.sourceId ?? "mock"}-${item.id}`}
            item={{ title: item.title, image: item.cover ?? item.banner ?? shows[0].image, rating: item.score ? `${item.score}%` : item.subtitle || item.sourceId }}
            size={large ? "lg" : "md"}
            onPress={() => router.push({ pathname: "/anime/[id]", params: { id: item.id, sourceId: item.sourceId ?? "mock" } })}
          />
        ))}
      </ScrollView>
    </View>
  );
}
