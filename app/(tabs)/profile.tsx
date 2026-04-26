import { Ionicons } from "@expo/vector-icons";
import { LinearGradient } from "expo-linear-gradient";
import React from "react";
import { ScrollView, Text, View } from "react-native";
import Animated, { useAnimatedStyle, useSharedValue, withSpring } from "react-native-reanimated";
import { Glass, LiftPressable } from "../../src/ui/cinematic";

const sections = [
  {
    title: "Account",
    items: [
      { icon: "person-circle", label: "Profile", value: "Viewer" },
      { icon: "shield-checkmark", label: "Privacy", value: "Protected" }
    ]
  },
  {
    title: "Playback",
    items: [
      { icon: "play-circle", label: "Autoplay next episode", toggle: true },
      { icon: "flash", label: "Skip intros automatically", toggle: true },
      { icon: "speedometer", label: "Streaming quality", slider: 78 }
    ]
  },
  {
    title: "Appearance",
    items: [
      { icon: "moon", label: "OLED black theme", toggle: true },
      { icon: "text", label: "Subtitle size", slider: 54 }
    ]
  },
  {
    title: "Downloads",
    items: [
      { icon: "cloud-download", label: "Download over Wi-Fi", toggle: true },
      { icon: "folder-open", label: "Storage", value: "18.4 GB free" }
    ]
  },
  {
    title: "About",
    items: [
      { icon: "sparkles", label: "Experience", value: "Cinematic UI" },
      { icon: "information-circle", label: "Build", value: "Expo" }
    ]
  }
] as const;

export default function SettingsScreen() {
  return (
    <ScrollView className="flex-1 bg-night px-5 pt-16" showsVerticalScrollIndicator={false}>
      <Text className="text-xs font-black uppercase tracking-[4px] text-accent">Settings</Text>
      <Text className="mt-3 text-5xl font-black text-white">A calmer control room.</Text>
      <Glass className="mt-8 rounded-3xl p-5">
        <View className="flex-row items-center gap-4">
          <LinearGradient colors={["#FF6B35", "#9B5DE5"]} className="h-16 w-16 items-center justify-center rounded-3xl">
            <Ionicons name="person" size={28} color="#0A0A0A" />
          </LinearGradient>
          <View className="flex-1">
            <Text className="text-xl font-black text-white">Premium viewing profile</Text>
            <Text className="mt-1 text-sm font-semibold text-white/48">Personal playback and display preferences</Text>
          </View>
        </View>
      </Glass>

      {sections.map((section) => (
        <View key={section.title} className="mt-8">
          <Text className="mb-3 text-xl font-black text-white">{section.title}</Text>
          <Glass className="overflow-hidden rounded-3xl">
            {section.items.map((item, index) => (
              <LiftPressable key={item.label} className={`px-4 py-4 ${index !== section.items.length - 1 ? "border-b border-white/10" : ""}`}>
                <View className="flex-row items-center gap-4">
                  <View className="h-11 w-11 items-center justify-center rounded-2xl bg-white/10">
                    <Ionicons name={item.icon} size={20} color="#FF6B35" />
                  </View>
                  <View className="flex-1">
                    <Text className="text-base font-black text-white">{item.label}</Text>
                    {"slider" in item && <MockSlider value={item.slider} />}
                  </View>
                  {"toggle" in item ? (
                    <AnimatedToggle enabled={item.toggle} />
                  ) : "value" in item ? (
                    <Text className="text-sm font-bold text-white/45">{item.value}</Text>
                  ) : null}
                </View>
              </LiftPressable>
            ))}
          </Glass>
        </View>
      ))}
      <View className="h-10" />
    </ScrollView>
  );
}

function AnimatedToggle({ enabled }: { enabled: boolean }) {
  const value = useSharedValue(enabled ? 1 : 0);
  const knob = useAnimatedStyle(() => ({
    transform: [{ translateX: withSpring(value.value ? 26 : 2, { damping: 14, stiffness: 220 }) }]
  }));
  const track = useAnimatedStyle(() => ({
    backgroundColor: value.value ? "#FF6B35" : "rgba(255,255,255,0.14)"
  }));
  return (
    <Animated.View style={track} className="h-8 w-16 justify-center rounded-full">
      <Animated.View style={knob} className="h-7 w-7 rounded-full bg-white shadow-xl" />
    </Animated.View>
  );
}

function MockSlider({ value }: { value: number }) {
  return (
    <View className="mt-3 h-2 overflow-hidden rounded-full bg-white/10">
      <LinearGradient colors={["#19D3FF", "#9B5DE5", "#FF6B35"]} className="h-full rounded-full" style={{ width: `${value}%` }} />
    </View>
  );
}
