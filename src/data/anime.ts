import { Anime } from "../types";

export const sampleStreams = [
  "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
  "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
  "https://storage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
];

export const animeList: Anime[] = [
  {
    id: "afterglow",
    title: "Afterglow Circuit",
    subtitle: "A midnight racing club discovers spirits inside the city grid.",
    cover: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx170942-CATD0dGzjFqD.jpg",
    banner: "https://s4.anilist.co/file/anilistcdn/media/anime/banner/170942-FGkkP8y5jtMU.jpg",
    year: 2026,
    score: 92,
    genres: ["Action", "Supernatural", "Sci-Fi"],
    status: "Watching",
    progress: "6 / 12",
    synopsis:
      "Neon districts, illegal races, and a signal from another world collide when a courier finds a haunted engine core.",
    episodes: [
      { id: "afterglow-1", animeId: "afterglow", number: 1, title: "Ignition Ghost", duration: "24m", streamUrl: sampleStreams[0] },
      { id: "afterglow-2", animeId: "afterglow", number: 2, title: "Blue Shift", duration: "24m", streamUrl: sampleStreams[1] },
      { id: "afterglow-3", animeId: "afterglow", number: 3, title: "No Signal", duration: "24m", streamUrl: sampleStreams[2] }
    ]
  },
  {
    id: "garden",
    title: "Garden of Comets",
    subtitle: "A quiet academy drama where astronomy turns magical.",
    cover: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx16498-C6FPmWm59CyP.jpg",
    banner: "https://s4.anilist.co/file/anilistcdn/media/anime/banner/16498.jpg",
    year: 2025,
    score: 88,
    genres: ["Drama", "Fantasy", "Slice of Life"],
    status: "Planned",
    progress: "0 / 13",
    synopsis:
      "Every spring, comet dust falls over Hoshimi Academy. This year, it starts answering wishes.",
    episodes: [
      { id: "garden-1", animeId: "garden", number: 1, title: "First Light", duration: "23m", streamUrl: sampleStreams[1] },
      { id: "garden-2", animeId: "garden", number: 2, title: "Wish Bloom", duration: "23m", streamUrl: sampleStreams[0] }
    ]
  },
  {
    id: "ronin",
    title: "Ronin Signal",
    subtitle: "A wandering swordsman hunts corrupted broadcast towers.",
    cover: "https://s4.anilist.co/file/anilistcdn/media/anime/cover/large/bx21-YCDoj1EkAxFn.jpg",
    banner: "https://s4.anilist.co/file/anilistcdn/media/anime/banner/21-O8soP3qK4VZl.jpg",
    year: 2024,
    score: 95,
    genres: ["Adventure", "Action", "Mystery"],
    status: "Completed",
    progress: "26 / 26",
    synopsis:
      "In a frontier stitched together by radio towers, one ronin follows a song only the lost can hear.",
    episodes: [
      { id: "ronin-24", animeId: "ronin", number: 24, title: "Static Road", duration: "25m", streamUrl: sampleStreams[2] },
      { id: "ronin-25", animeId: "ronin", number: 25, title: "Last Relay", duration: "25m", streamUrl: sampleStreams[0] },
      { id: "ronin-26", animeId: "ronin", number: 26, title: "Goodnight Frequency", duration: "25m", streamUrl: sampleStreams[1] }
    ]
  }
];
