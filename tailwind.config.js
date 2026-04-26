/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{js,jsx,ts,tsx}", "./src/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      colors: {
        bg: "#0A0A0A",
        surface: "#111111",
        surface2: "#1A1A1A",
        surface3: "#222222",
        accent: "#FF6B35",
        "accent-pink": "#FF3D8B",
        "accent-purple": "#9B5DE5",
        "accent-gold": "#FFD700",
        muted: "#888888",
        dim: "#444444",
        night: "#0A0A0A",
        glass: "rgba(255,255,255,0.08)",
        ember: "#FF6B35",
        aura: "#9B5DE5",
        cyan: "#19D3FF",
        rose: "#FF3D8B"
      },
      boxShadow: {
        glow: "0 0 34px rgba(255,106,26,0.38)"
      }
    }
  },
  plugins: []
};
