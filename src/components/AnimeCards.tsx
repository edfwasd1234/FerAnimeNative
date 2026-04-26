import { Ionicons } from "@expo/vector-icons";
import { router } from "expo-router";
import { Image, Pressable, StyleSheet, Text, View } from "react-native";
import { Anime } from "../types";

const fallbackPoster = "https://placehold.co/300x450/111111/f47521?text=FerAnime";

export function PosterCard({ anime }: { anime: Anime }) {
  return (
    <Pressable
      style={styles.posterCard}
      onPress={() =>
        router.push({
          pathname: "/anime/[id]",
          params: { id: anime.id, sourceId: anime.sourceId ?? "mock" }
        })
      }
    >
      <Image source={{ uri: anime.cover ?? fallbackPoster }} style={styles.posterImage} />
      <Text style={styles.posterTitle} numberOfLines={2}>{anime.title}</Text>
      <Text style={styles.posterMeta}>{anime.score ? `${anime.score}% match` : anime.sourceId ?? "mock"}</Text>
    </Pressable>
  );
}

export function AnimeRow({ anime }: { anime: Anime }) {
  return (
    <Pressable
      style={styles.row}
      onPress={() =>
        router.push({
          pathname: "/anime/[id]",
          params: { id: anime.id, sourceId: anime.sourceId ?? "mock" }
        })
      }
    >
      <Image source={{ uri: anime.cover ?? fallbackPoster }} style={styles.rowCover} />
      <View style={styles.rowBody}>
        <Text style={styles.rowTitle}>{anime.title}</Text>
        <Text style={styles.rowMeta}>{anime.year ?? "Anime"}  •  {anime.score ? `${anime.score}%` : anime.sourceId ?? "mock"}  •  {anime.status}</Text>
        <Text style={styles.rowSubtitle} numberOfLines={2}>{anime.subtitle}</Text>
      </View>
      <Ionicons name="chevron-forward" size={20} color="#6f7a89" />
    </Pressable>
  );
}

export function ProgressBar({ value }: { value: number }) {
  return (
    <View style={styles.track}>
      <View style={[styles.fill, { width: `${Math.max(0, Math.min(100, value))}%` }]} />
    </View>
  );
}

const styles = StyleSheet.create({
  posterCard: {
    width: "30.8%",
    minWidth: 96
  },
  posterImage: {
    width: "100%",
    aspectRatio: 0.68,
    borderRadius: 4,
    backgroundColor: "#1a1a1a"
  },
  posterTitle: {
    color: "#f8fafc",
    fontSize: 13,
    fontWeight: "800",
    marginTop: 8
  },
  posterMeta: {
    color: "#a3a3a3",
    fontSize: 12,
    marginTop: 2
  },
  row: {
    flexDirection: "row",
    alignItems: "center",
    gap: 12,
    paddingVertical: 14,
    borderBottomWidth: 1,
    borderBottomColor: "#242424"
  },
  rowCover: {
    width: 72,
    height: 104,
    borderRadius: 4
  },
  rowBody: {
    flex: 1
  },
  rowTitle: {
    color: "#f8fafc",
    fontSize: 17,
    fontWeight: "900"
  },
  rowMeta: {
    color: "#f47521",
    marginTop: 5,
    fontSize: 13,
    fontWeight: "700"
  },
  rowSubtitle: {
    color: "#b7b7b7",
    marginTop: 8,
    lineHeight: 19
  },
  track: {
    height: 5,
    borderRadius: 4,
    backgroundColor: "#303030",
    overflow: "hidden"
  },
  fill: {
    height: "100%",
    backgroundColor: "#f47521"
  }
});
