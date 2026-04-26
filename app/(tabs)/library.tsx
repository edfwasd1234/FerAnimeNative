import { Ionicons } from "@expo/vector-icons";
import { router } from "expo-router";
import React from "react";
import { Image, ScrollView, Text, View } from "react-native";
import { useLibrary } from "../../src/hooks/useLibrary";
import { animeProvider } from "../../src/providers/animeProvider";
import { LibraryStatus } from "../../src/types";
import { Glass, LiftPressable, ProgressLine, shows } from "../../src/ui/cinematic";

const statuses: LibraryStatus[] = ["Watching", "Planned", "Completed"];

export default function LibraryScreen() {
  const library = useLibrary();
  const mockAnime = animeProvider.listTrending();
  const fallbackItems = mockAnime.map((anime) => ({
    animeId: anime.id,
    sourceId: "mock",
    title: anime.title,
    image: anime.cover,
    status: anime.status,
    progressText: anime.progress,
    updatedAt: new Date().toISOString()
  }));
  const items = library.items.length ? library.items : fallbackItems;

  return (
    <ScrollView className="flex-1 bg-night px-5 pt-16" showsVerticalScrollIndicator={false}>
      <Text className="text-xs font-black uppercase tracking-[4px] text-accent">Library</Text>
      <Text className="mt-3 text-5xl font-black text-white">Your cinematic queue.</Text>

      {statuses.map((section) => {
        const sectionItems = items.filter((item) => item.status === section);
        return (
          <View key={section} className="mt-8">
            <View className="mb-4 flex-row items-center justify-between">
              <Text className="text-2xl font-black text-white">{section}</Text>
              <Text className="text-sm font-black text-accent">{sectionItems.length} saved</Text>
            </View>
            <Glass className="rounded-3xl p-2">
              {sectionItems.length ? (
                sectionItems.map((item, index) => (
                  <LiftPressable
                    key={`${item.sourceId}-${item.animeId}`}
                    className="flex-row items-center gap-4 rounded-3xl p-3"
                    onPress={() => router.push({ pathname: "/anime/[id]", params: { id: item.animeId, sourceId: item.sourceId } })}
                  >
                    <Image source={{ uri: item.image || shows[index % shows.length].image }} className="h-24 w-16 rounded-2xl" />
                    <View className="flex-1">
                      <Text className="text-lg font-black text-white">{item.title}</Text>
                      <Text className="mt-1 text-sm font-semibold text-white/45">{item.progressText || item.status}</Text>
                      <View className="mt-3">
                        <ProgressLine value={section === "Completed" ? 100 : progressValue(item.progressText)} />
                      </View>
                    </View>
                    <Ionicons name="chevron-forward" size={20} color="rgba(255,255,255,0.45)" />
                  </LiftPressable>
                ))
              ) : (
                <Text className="px-4 py-5 text-sm font-bold text-white/40">Nothing here yet.</Text>
              )}
            </Glass>
          </View>
        );
      })}
      <View className="h-12" />
    </ScrollView>
  );
}

function progressValue(text?: string) {
  if (!text) return 0;
  const percent = text.match(/(\d+)%/);
  if (percent) return Number(percent[1]);
  const ratio = text.match(/(\d+)\s*\/\s*(\d+)/);
  if (ratio) return (Number(ratio[1]) / Number(ratio[2])) * 100;
  return 10;
}
