import { BlurView } from "expo-blur";
import React from "react";
import { StyleProp, View, ViewStyle } from "react-native";
import { COLORS } from "../constants/colors";

export function GlassView({
  children,
  intensity = 34,
  className = "",
  style
}: {
  children: React.ReactNode;
  intensity?: number;
  className?: string;
  style?: StyleProp<ViewStyle>;
}) {
  return (
    <BlurView
      intensity={intensity}
      tint="dark"
      className={`overflow-hidden border ${className}`}
      style={[{ borderColor: COLORS.glassBorder, backgroundColor: COLORS.glass }, style]}
    >
      <View className="absolute inset-0 bg-white/5" pointerEvents="none" />
      {children}
    </BlurView>
  );
}
