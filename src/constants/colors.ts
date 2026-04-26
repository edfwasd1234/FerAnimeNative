export const COLORS = {
  bg: "#0A0A0A",
  surface: "#111111",
  surface2: "#1A1A1A",
  surface3: "#222222",
  accent: "#FF6B35",
  accentPink: "#FF3D8B",
  accentPurple: "#9B5DE5",
  accentGold: "#FFD700",
  text: "#FFFFFF",
  textMuted: "#888888",
  textDim: "#444444",
  glass: "rgba(255,255,255,0.07)",
  glassBorder: "rgba(255,255,255,0.12)",
  glassStrong: "rgba(255,255,255,0.12)"
} as const;

export const GRADIENTS = {
  accent: ["#FF6B35", "#FF3D8B"],
  accentFull: ["#FF6B35", "#FF3D8B", "#9B5DE5"],
  heroBottom: ["transparent", "rgba(10,10,10,0.7)", "#0A0A0A"],
  heroLeft: ["rgba(10,10,10,0.6)", "transparent"],
  cardBottom: ["transparent", "rgba(0,0,0,0.85)"],
  playerTop: ["rgba(0,0,0,0.9)", "transparent"],
  playerBottom: ["transparent", "rgba(0,0,0,0.95)"]
} as const;
