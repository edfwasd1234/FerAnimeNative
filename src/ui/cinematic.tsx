import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import React from "react";
import { Image, ImageBackground, Pressable, Text, View } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withSpring } from "react-native-reanimated";
import { GlassView } from "../components/GlassView";
import { COLORS, GRADIENTS } from "../constants/colors";

export const posters = [
  {
    title: "Demon Veil",
    subtitle: "A cursed city blooms under neon rain.",
    rating: "98%",
    year: "2026",
    genres: ["Action", "Dark Fantasy", "Supernatural"],
    image: "https://images.unsplash.com/photo-1578632767115-351597cf2477?auto=format&fit=crop&w=1200&q=80"
  },
  {
    title: "Moonlit Arsenal",
    subtitle: "Elite hunters chase shadows across a silent empire.",
    rating: "96%",
    year: "2025",
    genres: ["Adventure", "Mystery", "Drama"],
    image: "https://images.unsplash.com/photo-1618336753974-aae8e04506aa?auto=format&fit=crop&w=1200&q=80"
  },
  {
    title: "Starfall Academy",
    subtitle: "Rival students learn magic at the edge of collapse.",
    rating: "94%",
    year: "2026",
    genres: ["Fantasy", "School", "Sci-Fi"],
    image: "https://images.unsplash.com/photo-1607604276583-eef5d076aa5f?auto=format&fit=crop&w=1200&q=80"
  }
];

export const thumbnails = [
  "https://images.unsplash.com/photo-1528360983277-13d401cdc186?auto=format&fit=crop&w=900&q=80",
  "https://images.unsplash.com/photo-1519638399535-1b036603ac77?auto=format&fit=crop&w=900&q=80",
  "https://images.unsplash.com/photo-1601850494422-3cf14624b0b3?auto=format&fit=crop&w=900&q=80",
  "https://images.unsplash.com/photo-1612036782180-6f0b6cd846fe?auto=format&fit=crop&w=900&q=80",
  "https://images.unsplash.com/photo-1601987077677-5346c0c57d3f?auto=format&fit=crop&w=900&q=80",
  "https://images.unsplash.com/photo-1606112219348-204d7d8b94ee?auto=format&fit=crop&w=900&q=80"
];

export const shows = [
  "Crimson Reign",
  "Afterimage Protocol",
  "Silent Blade",
  "Orbit Children",
  "Velvet Phantom",
  "Neon Exorcist",
  "Glass Horizon",
  "Azure Crown"
].map((title, index) => ({
  title,
  image: thumbnails[index % thumbnails.length],
  rating: `${99 - index}%`,
  meta: index % 2 === 0 ? "Sub | Dub" : "New Episode"
}));

const AnimatedPressableBase = Animated.createAnimatedComponent(Pressable);

export function LiftPressable({ children, className, onPress }: { children: React.ReactNode; className?: string; onPress?: () => void }) {
  const scale = useSharedValue(1);
  const y = useSharedValue(0);
  const animatedStyle = useAnimatedStyle(() => ({
    transform: [{ scale: scale.value }, { translateY: y.value }]
  }));
  return (
    <AnimatedPressableBase
      className={className}
      style={animatedStyle}
      onPress={onPress}
      onPressIn={() => {
        scale.value = withSpring(0.965, { damping: 14, stiffness: 260 });
        y.value = withSpring(-4, { damping: 14, stiffness: 260 });
      }}
      onPressOut={() => {
        scale.value = withSpring(1, { damping: 14, stiffness: 260 });
        y.value = withSpring(0, { damping: 14, stiffness: 260 });
      }}
    >
      {children}
    </AnimatedPressableBase>
  );
}

export function Glass({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return <GlassView className={className}>{children}</GlassView>;
}

export function GlowButton({ label, icon = "play" }: { label: string; icon?: keyof typeof Ionicons.glyphMap }) {
  return (
    <LiftPressable className="shadow-glow overflow-hidden rounded-2xl">
      <LinearGradient colors={[...GRADIENTS.accentFull]} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} className="h-14 flex-row items-center justify-center gap-3 px-6">
        <Ionicons name={icon} size={20} color={COLORS.bg} />
        <Text className="text-base font-black text-night">{label}</Text>
      </LinearGradient>
    </LiftPressable>
  );
}

export function GlassPlayButton({ label = "Play", onPress }: { label?: string; onPress?: () => void }) {
  return (
    <LiftPressable className="overflow-hidden rounded-2xl shadow-2xl" onPress={onPress}>
      <GlassView intensity={40} className="h-14 flex-row items-center justify-center gap-3 px-6" style={{ backgroundColor: "rgba(255,255,255,0.12)" }}>
        <View className="h-8 w-8 items-center justify-center rounded-full bg-white/90">
          <Ionicons name="play" size={16} color={COLORS.bg} />
        </View>
        <Text className="text-base font-black text-white">{label}</Text>
      </GlassView>
    </LiftPressable>
  );
}

export function StarRating({ value }: { value?: string | number | null }) {
  if (!value) return null;
  return (
    <View className="flex-row items-center gap-1">
      <Ionicons name="star" size={13} color={COLORS.accentGold} />
      <Text className="text-xs font-black text-accent-gold">{value}</Text>
    </View>
  );
}

export function GenreChip({ label, active = false }: { label: string; active?: boolean }) {
  return (
    <Glass className={`rounded-full px-3 py-1.5 ${active ? "bg-accent/20" : ""}`}>
      <Text className={`text-[11px] font-black uppercase ${active ? "text-accent" : "text-white/70"}`}>{label}</Text>
    </Glass>
  );
}

export function PosterTile({ item, size = "md", onPress }: { item: { title: string; image: string; rating?: string; meta?: string }; size?: "sm" | "md" | "lg"; onPress?: () => void }) {
  const widthClass = size === "lg" ? "w-48" : size === "sm" ? "w-36" : "w-40";
  const heightClass = size === "lg" ? "h-72" : size === "sm" ? "h-52" : "h-60";
  return (
    <LiftPressable className={`${widthClass} mr-4`} onPress={onPress}>
      <View className="overflow-hidden rounded-2xl bg-zinc-900 shadow-2xl">
        <Image source={{ uri: item.image }} className={`${heightClass} w-full`} />
        <LinearGradient colors={[...GRADIENTS.cardBottom]} className="absolute bottom-0 h-28 w-full justify-end p-3">
          <Text numberOfLines={2} className="text-sm font-black text-white">
            {item.title}
          </Text>
          <View className="mt-1">
            <StarRating value={item.rating ?? item.meta} />
          </View>
        </LinearGradient>
      </View>
    </LiftPressable>
  );
}

export function ProgressLine({ value }: { value: number }) {
  return (
    <View className="h-1.5 overflow-hidden rounded-full bg-white/15">
      <LinearGradient colors={[...GRADIENTS.accent]} className="h-full rounded-full" style={{ width: `${value}%` }} />
    </View>
  );
}

export function SectionHeader({ title }: { title: string }) {
  return (
    <View className="mb-4 mt-8 flex-row items-center justify-between px-5">
      <Text className="text-2xl font-black tracking-tight text-white">{title}</Text>
      <Text className="text-sm font-extrabold text-accent">See All</Text>
    </View>
  );
}

export function HeroBackdrop({ image, children }: { image: string; children: React.ReactNode }) {
  return (
    <ImageBackground source={{ uri: image }} className="overflow-hidden bg-night">
      <LinearGradient colors={["rgba(10,10,10,0.12)", "rgba(10,10,10,0.56)", COLORS.bg]} className="min-h-[520px] justify-end px-5 pb-8 pt-16">
        {children}
      </LinearGradient>
    </ImageBackground>
  );
}
