import AsyncStorage from "@react-native-async-storage/async-storage";
import { useCallback, useEffect, useState } from "react";
import { EpisodeProgress } from "../types";

const keyFor = (episodeId: string) => `feranime:progress:${episodeId}`;
const indexKey = "feranime:progress:index";

async function readIndex() {
  const raw = await AsyncStorage.getItem(indexKey);
  return raw ? (JSON.parse(raw) as string[]) : [];
}

async function writeIndex(ids: string[]) {
  await AsyncStorage.setItem(indexKey, JSON.stringify([...new Set(ids)]));
}

export function useEpisodeProgress(episodeId: string) {
  const [progress, setProgress] = useState<EpisodeProgress | null>(null);

  useEffect(() => {
    let mounted = true;
    AsyncStorage.getItem(keyFor(episodeId)).then((value) => {
      if (mounted && value) {
        setProgress(JSON.parse(value) as EpisodeProgress);
      }
    });
    return () => {
      mounted = false;
    };
  }, [episodeId]);

  const saveProgress = useCallback(
    async (nextProgress: EpisodeProgress) => {
      const payload = { ...nextProgress, episodeId };
      setProgress(payload);
      await AsyncStorage.setItem(keyFor(episodeId), JSON.stringify(payload));
      await writeIndex([episodeId, ...(await readIndex())]);
    },
    [episodeId]
  );

  return { progress, saveProgress };
}

export function useAllEpisodeProgress() {
  const [items, setItems] = useState<EpisodeProgress[]>([]);

  const refresh = useCallback(async () => {
    const ids = await readIndex();
    const values = await Promise.all(ids.map((id) => AsyncStorage.getItem(keyFor(id))));
    const parsed = values
      .filter(Boolean)
      .map((value) => JSON.parse(value as string) as EpisodeProgress)
      .sort((a, b) => new Date(b.updatedAt).getTime() - new Date(a.updatedAt).getTime());
    setItems(parsed);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { items, refresh };
}
