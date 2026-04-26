import { Ionicons } from "@expo/vector-icons";
import { BlurView } from "expo-blur";
import { LinearGradient } from "expo-linear-gradient";
import { router } from "expo-router";
import React, { useEffect, useMemo, useState } from "react";
import { Image, ScrollView, Text, TextInput, View } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withSpring, withTiming } from "react-native-reanimated";
import { animeProvider } from "../../src/providers/animeProvider";
import { Anime } from "../../src/types";
import { Glass, LiftPressable, shows } from "../../src/ui/cinematic";

const chips = ["Naruto", "One Piece", "Action", "New dubs", "Dark fantasy", "Movies", "Romance"];
const sources = [
  { id: "animeheaven", label: "AnimeHeaven" },
  { id: "hianime", label: "HiAnime" },
  { id: "anizone", label: "AniZone" }
] as const;

export default function SearchScreen() {
  const focus = useSharedValue(0);
  const [query, setQuery] = useState("naruto");
  const [sourceId, setSourceId] = useState<(typeof sources)[number]["id"]>("animeheaven");
  const [remoteResults, setRemoteResults] = useState<Anime[]>([]);
  const mockResults = useMemo(() => animeProvider.searchAnime(query, "All"), [query]);
  const results = remoteResults.length ? remoteResults : mockResults;
  const searchStyle = useAnimatedStyle(() => ({
    transform: [{ scale: withSpring(focus.value ? 1.025 : 1) }],
    borderColor: focus.value ? "rgba(255,107,53,0.72)" : "rgba(255,255,255,0.10)"
  }));
  const gridStyle = useAnimatedStyle(() => ({
    opacity: withTiming(focus.value ? 1 : 0.92, { duration: 220 }),
    transform: [{ translateY: withTiming(focus.value ? -4 : 0, { duration: 220 }) }]
  }));

  useEffect(() => {
    let mounted = true;
    const timer = setTimeout(() => {
      animeProvider
        .searchAnimeRemote(query, sourceId)
        .then((items) => {
          if (mounted) setRemoteResults(items);
        })
        .catch(() => {
          if (mounted) setRemoteResults([]);
        });
    }, 300);
    return () => {
      mounted = false;
      clearTimeout(timer);
    };
  }, [query, sourceId]);

  return (
    <ScrollView className="flex-1 bg-night px-5 pt-16" showsVerticalScrollIndicator={false}>
      <Text className="text-xs font-black uppercase tracking-[4px] text-accent">Search</Text>
      <Text className="mt-3 text-5xl font-black leading-[54px] text-white">Find your next obsession.</Text>

      <View className="mt-6 flex-row gap-2">
        {sources.map((source) => (
          <LiftPressable key={source.id} className={`rounded-full px-4 py-2 ${sourceId === source.id ? "bg-accent" : "bg-white/10"}`} onPress={() => setSourceId(source.id)}>
            <Text className={`text-sm font-black ${sourceId === source.id ? "text-night" : "text-white"}`}>{source.label}</Text>
          </LiftPressable>
        ))}
      </View>

      <Animated.View style={searchStyle} className="mt-5 overflow-hidden rounded-3xl border bg-white/10">
        <BlurView intensity={34} tint="dark" className="h-16 flex-row items-center gap-3 px-5">
          <Ionicons name="search" size={22} color="#FF6B35" />
          <TextInput
            placeholder="Search anime, genres, studios"
            placeholderTextColor="rgba(255,255,255,0.42)"
            className="flex-1 text-lg font-bold text-white"
            value={query}
            onChangeText={setQuery}
            onFocus={() => {
              focus.value = 1;
            }}
            onBlur={() => {
              focus.value = 0;
            }}
          />
          <LiftPressable className="h-9 w-9 items-center justify-center rounded-full bg-white/10" onPress={() => setQuery("")}>
            <Ionicons name="close" size={18} color="rgba(255,255,255,0.74)" />
          </LiftPressable>
        </BlurView>
      </Animated.View>

      <View className="mt-6 flex-row flex-wrap gap-2">
        {chips.map((chip, index) => (
          <LiftPressable key={chip} className="overflow-hidden rounded-full" onPress={() => setQuery(chip)}>
            <LinearGradient colors={index % 3 === 0 ? ["#FF6B35", "#FF3D8B"] : ["rgba(255,255,255,0.12)", "rgba(255,255,255,0.06)"]} className="px-4 py-2">
              <Text className="text-sm font-black text-white">{chip}</Text>
            </LinearGradient>
          </LiftPressable>
        ))}
      </View>

      <View className="mb-4 mt-9 flex-row items-center justify-between">
        <View>
          <Text className="text-2xl font-black text-white">Results</Text>
          <Text className="mt-1 text-sm font-semibold text-white/45">{remoteResults.length ? `${sourceId} resolver` : "Mock fallback"}</Text>
        </View>
        <Glass className="rounded-full px-3 py-2">
          <Text className="text-xs font-black text-accent">Live</Text>
        </Glass>
      </View>

      <Animated.View style={gridStyle} className="flex-row flex-wrap justify-between pb-10">
        {results.map((item, index) => (
          <LiftPressable
            key={`${item.sourceId ?? "mock"}-${item.id}`}
            className="mb-5 w-[48%] overflow-hidden rounded-3xl bg-zinc-950"
            onPress={() => router.push({ pathname: "/anime/[id]", params: { id: item.id, sourceId: item.sourceId ?? "mock" } })}
          >
            <Image source={{ uri: item.cover ?? item.banner ?? shows[index % shows.length].image }} className="h-56 w-full" />
            <LinearGradient colors={["transparent", "rgba(0,0,0,0.95)"]} className="absolute bottom-0 w-full p-4">
              <Text numberOfLines={2} className="text-base font-black text-white">
                {item.title}
              </Text>
              <Text className="mt-1 text-xs font-black text-accent">{item.subtitle || item.sourceId || "Anime"}</Text>
            </LinearGradient>
          </LiftPressable>
        ))}
      </Animated.View>
    </ScrollView>
  );
}
