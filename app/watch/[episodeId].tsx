import { Ionicons } from "@expo/vector-icons";
import { BlurView } from "expo-blur";
import { LinearGradient } from "expo-linear-gradient";
import { router, useLocalSearchParams } from "expo-router";
import { VideoView, useVideoPlayer } from "expo-video";
import React, { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { Text, View } from "react-native";
import { WebViewMessageEvent } from "react-native-webview";
import Animated, { useAnimatedStyle, useSharedValue, withDelay, withSpring, withTiming } from "react-native-reanimated";
import { sampleStreams } from "../../src/data/anime";
import { useLibrary } from "../../src/hooks/useLibrary";
import { useEpisodeProgress } from "../../src/hooks/useProgress";
import { animeProvider } from "../../src/providers/animeProvider";
import { EpisodeStream } from "../../src/types";
import { Glass, LiftPressable } from "../../src/ui/cinematic";
import { AdBlockedWebView } from "../../src/webview/AdBlockedWebView";

export default function VideoPlayerScreen() {
  const { episodeId, sourceId = "mock", animeId, title = "Episode", episodeTitle, episodeNumber, image } = useLocalSearchParams<{
    episodeId: string;
    sourceId?: string;
    animeId?: string;
    title?: string;
    episodeTitle?: string;
    episodeNumber?: string;
    image?: string;
  }>();
  const controls = useSharedValue(1);
  const loadedSourceRef = useRef("");
  const resumedSourceRef = useRef("");
  const [remoteStreams, setRemoteStreams] = useState<EpisodeStream[]>([]);
  const [streamIndex, setStreamIndex] = useState(0);
  const [status, setStatus] = useState(sourceId === "mock" ? "Mock stream" : "Resolving stream");
  const [isPlaying, setIsPlaying] = useState(false);
  const [subtitleEnabled, setSubtitleEnabled] = useState(true);
  const [lastTick, setLastTick] = useState({ currentTime: 0, duration: 0 });
  const { progress, saveProgress } = useEpisodeProgress(episodeId);
  const library = useLibrary();
  const mockStream = sourceId === "mock" ? animeProvider.getEpisodeStreams(episodeId)[0] : null;
  const streams = useMemo(() => (sourceId === "mock" && mockStream ? [mockStream] : remoteStreams), [mockStream, remoteStreams, sourceId]);
  const playableStreams = useMemo(() => streams.filter((item) => item.type === "hls" || item.type === "mp4"), [streams]);
  const embedStream = useMemo(() => streams.find((item) => item.type === "iframe"), [streams]);
  const fallbackStream: EpisodeStream = { id: "fallback-demo", label: "Demo fallback", quality: "auto", type: "hls", url: sampleStreams[0] };
  const activeStream = playableStreams[streamIndex] ?? playableStreams[0] ?? fallbackStream;
  const activeSource = useMemo(
    () =>
      activeStream.headers
        ? { uri: activeStream.url, headers: activeStream.headers, contentType: activeStream.type === "hls" ? ("hls" as const) : ("auto" as const) }
        : activeStream.url,
    [activeStream]
  );
  const shouldUseEmbed = playableStreams.length === 0 && !!embedStream;
  const player = useVideoPlayer(activeSource, (instance) => {
    instance.loop = false;
    instance.timeUpdateEventInterval = 2;
  });
  const controlsStyle = useAnimatedStyle(() => ({
    opacity: withTiming(controls.value, { duration: 260 }),
    transform: [{ translateY: withSpring(controls.value ? 0 : 20) }]
  }));
  const centerStyle = useAnimatedStyle(() => ({
    transform: [{ scale: withDelay(80, withSpring(controls.value ? 1 : 0.88, { damping: 18, stiffness: 180 })) }]
  }));

  const saveCurrentProgress = useCallback(
    async (currentTime = player.currentTime, duration = player.duration) => {
      const safeDuration = Number.isFinite(duration) && duration > 0 ? duration : lastTick.duration;
      const payload = {
        currentTime: Number.isFinite(currentTime) ? currentTime : 0,
        duration: safeDuration || 0,
        updatedAt: new Date().toISOString(),
        animeId,
        sourceId,
        animeTitle: title,
        episodeTitle,
        episodeNumber: episodeNumber ? Number(episodeNumber) : undefined,
        image: image || null
      };
      await saveProgress(payload);
      if (animeId) {
        await library.upsert({
          animeId,
          sourceId,
          title,
          image: image || null,
          status: "Watching",
          progressText: payload.duration ? `${Math.round((payload.currentTime / payload.duration) * 100)}%` : "Watching"
        });
      }
    },
    [animeId, episodeNumber, episodeTitle, image, lastTick.duration, library, player, saveProgress, sourceId, title]
  );

  const resolveAnimeHeavenFallback = useCallback(async () => {
    if (sourceId === "animeheaven" || !title) return false;
    try {
      setStatus("Trying AnimeHeaven fallback");
      const matches = await animeProvider.searchAnimeRemote(title, "animeheaven");
      const candidate = matches[0];
      if (!candidate) return false;
      const nextEpisodes = await animeProvider.getEpisodesRemote("animeheaven", candidate.id);
      const targetNumber = episodeNumber ? Number(episodeNumber) : undefined;
      const nextEpisode = nextEpisodes.find((episode) => Number(episode.number) === targetNumber) ?? nextEpisodes[0];
      if (!nextEpisode) return false;
      const nextStreams = await animeProvider.getEpisodeStreamsRemote("animeheaven", nextEpisode.id);
      if (!nextStreams.length) return false;
      setRemoteStreams(nextStreams);
      setStreamIndex(0);
      setStatus("AnimeHeaven fallback stream");
      return true;
    } catch {
      setStatus("Fallback unavailable");
      return false;
    }
  }, [episodeNumber, sourceId, title]);

  useEffect(() => {
    if (!shouldUseEmbed) {
      const sourceKey = `${activeStream.id}:${activeStream.url}`;
      if (loadedSourceRef.current !== sourceKey) {
        player.replace(activeSource);
        loadedSourceRef.current = sourceKey;
        resumedSourceRef.current = "";
      }
      if (progress?.currentTime && resumedSourceRef.current !== sourceKey) {
        const timer = setTimeout(() => {
          player.currentTime = progress.currentTime;
          setLastTick({ currentTime: progress.currentTime, duration: progress.duration });
          resumedSourceRef.current = sourceKey;
        }, 900);
        return () => clearTimeout(timer);
      }
    }
  }, [activeSource, activeStream.id, activeStream.url, player, progress?.currentTime, progress?.duration, shouldUseEmbed]);

  useEffect(() => {
    if (sourceId === "mock") return;
    let mounted = true;
    setStatus("Resolving stream");
    animeProvider
      .getEpisodeStreamsRemote(sourceId, episodeId)
      .then((items) => {
        if (!mounted) return;
        setRemoteStreams(items);
        setStreamIndex(0);
        const hasPlayable = items.some((item) => item.type === "hls" || item.type === "mp4");
        const hasEmbed = items.some((item) => item.type === "iframe");
        setStatus(hasPlayable ? `${sourceId} direct stream` : hasEmbed ? `${sourceId} protected embed` : "Demo fallback");
        if (!hasPlayable && !hasEmbed) resolveAnimeHeavenFallback();
      })
      .catch((error) => {
        if (mounted) {
          setStatus(error instanceof Error ? error.message : "Resolver unavailable");
          resolveAnimeHeavenFallback();
        }
      });
    return () => {
      mounted = false;
    };
  }, [episodeId, sourceId]);

  useEffect(() => {
    if (shouldUseEmbed) return;
    const timer = setInterval(() => {
      const currentTime = player.currentTime || 0;
      const duration = player.duration || 0;
      setLastTick({ currentTime, duration });
      if (currentTime > 0) saveCurrentProgress(currentTime, duration);
    }, 5000);
    return () => clearInterval(timer);
  }, [player, saveCurrentProgress, shouldUseEmbed]);

  const togglePlayback = () => {
    controls.value = controls.value ? 0 : 1;
    if (shouldUseEmbed) return;
    if (isPlaying) {
      player.pause();
      saveCurrentProgress();
      setIsPlaying(false);
    } else {
      player.play();
      setIsPlaying(true);
    }
  };

  const addDetectedStream = useCallback((url: string, via: string) => {
    if (!/\.(m3u8|mp4)(?:[?#]|$)/i.test(url)) return;
    const directStream: EpisodeStream = {
      id: `detected-${Date.now()}`,
      label: `Detected ${via}`,
      quality: url.includes("/dub") ? "dub" : url.includes("/sub") ? "sub" : "auto",
      type: url.includes(".m3u8") ? "hls" : "mp4",
      url,
      headers: embedStream?.url ? { Referer: embedStream.url } : undefined
    };
    setRemoteStreams((items) => (items.some((item) => item.url === url) ? items : [directStream, ...items]));
    setStreamIndex(0);
    setStatus("Detected direct stream");
  }, [embedStream?.url]);

  const handleWebViewMessage = useCallback((event: WebViewMessageEvent) => {
    try {
      const payload = JSON.parse(event.nativeEvent.data);
      const url = typeof payload?.url === "string" ? payload.url : "";
      if (payload?.type !== "feranime:media-url" || !/\.(m3u8|mp4)(?:[?#]|$)/i.test(url)) return;
      addDetectedStream(url, payload.via || "WebView");
    } catch {
      // Ignore unrelated WebView messages.
    }
  }, [addDetectedStream]);

  const progressPercent = lastTick.duration ? Math.min(100, Math.max(0, (lastTick.currentTime / lastTick.duration) * 100)) : 0;

  return (
    <View className="flex-1 items-center justify-center bg-black px-3">
      <View className="aspect-video w-full overflow-hidden rounded-3xl border border-white/10 bg-black shadow-2xl">
        {shouldUseEmbed && embedStream ? (
          <View className="absolute inset-0 bg-black">
            <AdBlockedWebView
              source={{ uri: embedStream.url, headers: embedStream.headers }}
              allowsFullscreenVideo
              allowsInlineMediaPlayback
              mediaPlaybackRequiresUserAction={false}
              onError={resolveAnimeHeavenFallback}
              onMessage={handleWebViewMessage}
              onShouldStartLoadWithRequest={(request) => {
                if (/\.(m3u8|mp4)(?:[?#]|$)/i.test(request.url)) {
                  addDetectedStream(request.url, "navigation");
                  return false;
                }
                return true;
              }}
              className="bg-black"
            />
          </View>
        ) : (
          <VideoView style={{ width: "100%", height: "100%", backgroundColor: "#000" }} player={player} allowsFullscreen allowsPictureInPicture />
        )}

        <LinearGradient colors={["rgba(0,0,0,0.82)", "transparent", "rgba(0,0,0,0.9)"]} className="absolute inset-0 justify-between p-4">
          <Animated.View style={controlsStyle} className="flex-row items-center justify-between">
            <LiftPressable className="h-11 w-11 items-center justify-center rounded-2xl bg-black/55" onPress={() => router.back()}>
              <Ionicons name="chevron-back" size={24} color="#fff" />
            </LiftPressable>
            <View className="flex-1 px-3">
              <Text numberOfLines={1} className="text-center text-sm font-black text-white">{title || animeId || "Now Playing"}</Text>
              <Text className="mt-1 text-center text-xs font-bold text-white/48">{status}</Text>
            </View>
            <LiftPressable className="h-11 w-11 items-center justify-center rounded-2xl bg-black/55">
              <Ionicons name="settings" size={21} color="#fff" />
            </LiftPressable>
          </Animated.View>

          <Animated.View style={centerStyle} className="items-center">
            <LiftPressable className="h-20 w-20 items-center justify-center overflow-hidden rounded-full border border-white/20 bg-white/10" onPress={togglePlayback}>
              <BlurView intensity={28} tint="dark" className="h-full w-full items-center justify-center">
                <Ionicons name={shouldUseEmbed ? "browsers" : isPlaying ? "pause" : "play"} size={32} color="#fff" />
              </BlurView>
            </LiftPressable>
          </Animated.View>

          <Animated.View style={controlsStyle}>
            <View className="mb-3 flex-row items-center justify-between">
              <Text className="text-xs font-black text-white/70">{shouldUseEmbed ? "Embed" : formatTime(lastTick.currentTime)}</Text>
              <Text className="text-xs font-black text-white/70">{activeStream.quality}</Text>
            </View>
            <View className="mb-4 h-2 overflow-hidden rounded-full bg-white/20">
              <LinearGradient colors={["#FF6B35", "#FF3D8B", "#9B5DE5"]} className="h-full rounded-full" style={{ width: `${shouldUseEmbed ? 0 : progressPercent}%` }} />
              {!shouldUseEmbed && <View className="absolute top-[-5px] h-5 w-5 rounded-full border-2 border-black bg-white" style={{ left: `${Math.min(96, progressPercent)}%` }} />}
            </View>

            <Glass className="rounded-3xl p-3">
              <View className="flex-row items-center justify-between">
                <PlayerAction icon="play-skip-back" label="10s" onPress={() => !shouldUseEmbed && player.seekBy(-10)} />
                <PlayerAction icon="play-back" label="OP" onPress={() => !shouldUseEmbed && player.seekBy(85)} />
                <PlayerAction icon="chatbox-ellipses" label={subtitleEnabled ? "Sub On" : "Sub Off"} active={subtitleEnabled} onPress={() => setSubtitleEnabled((value) => !value)} />
                <PlayerAction
                  icon="speedometer"
                  label={playableStreams[streamIndex]?.quality ?? (shouldUseEmbed ? "Embed" : "Auto")}
                  active
                  onPress={() => playableStreams.length > 1 && setStreamIndex((index) => (index + 1) % playableStreams.length)}
                />
                <PlayerAction icon="play-skip-forward" label="10s" onPress={() => !shouldUseEmbed && player.seekBy(10)} />
              </View>
            </Glass>
          </Animated.View>
        </LinearGradient>
      </View>
    </View>
  );
}

function PlayerAction({ icon, label, active = false, onPress }: { icon: keyof typeof Ionicons.glyphMap; label: string; active?: boolean; onPress?: () => void }) {
  return (
    <LiftPressable className="items-center gap-2" onPress={onPress}>
      <View className={`h-10 w-10 items-center justify-center rounded-2xl ${active ? "bg-accent" : "bg-white/10"}`}>
        <Ionicons name={icon} size={18} color={active ? "#0A0A0A" : "#fff"} />
      </View>
      <Text className="text-[10px] font-black text-white/70">{label}</Text>
    </LiftPressable>
  );
}

function formatTime(seconds: number) {
  const safe = Number.isFinite(seconds) ? Math.max(0, seconds) : 0;
  const minutes = Math.floor(safe / 60);
  const rest = Math.floor(safe % 60);
  return `${minutes}:${String(rest).padStart(2, "0")}`;
}
