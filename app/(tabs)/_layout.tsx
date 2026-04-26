import { Ionicons } from "@expo/vector-icons";
import { Tabs } from "expo-router";
import React from "react";

const iconFor = {
  index: "home",
  search: "search",
  library: "albums",
  profile: "settings"
} as const;

export default function TabLayout() {
  return (
    <Tabs
      screenOptions={({ route }) => ({
        headerShown: false,
        tabBarStyle: {
          position: "absolute",
          backgroundColor: "rgba(10,10,10,0.86)",
          borderTopColor: "rgba(255,255,255,0.08)",
          height: 82,
          paddingTop: 8
        },
        tabBarActiveTintColor: "#FF6A1A",
        tabBarInactiveTintColor: "#777777",
        tabBarIcon: ({ color, size }) => (
          <Ionicons name={iconFor[route.name as keyof typeof iconFor]} size={size} color={color} />
        )
      })}
    >
      <Tabs.Screen name="index" options={{ title: "Home" }} />
      <Tabs.Screen name="search" options={{ title: "Search" }} />
      <Tabs.Screen name="library" options={{ title: "Library" }} />
      <Tabs.Screen name="profile" options={{ title: "Settings" }} />
    </Tabs>
  );
}
