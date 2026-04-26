import AsyncStorage from "@react-native-async-storage/async-storage";
import { useCallback, useEffect, useState } from "react";
import { LibraryEntry, LibraryStatus } from "../types";

const libraryKey = "feranime:library";

async function readLibrary() {
  const raw = await AsyncStorage.getItem(libraryKey);
  return raw ? (JSON.parse(raw) as LibraryEntry[]) : [];
}

async function writeLibrary(items: LibraryEntry[]) {
  await AsyncStorage.setItem(libraryKey, JSON.stringify(items));
}

export function useLibrary() {
  const [items, setItems] = useState<LibraryEntry[]>([]);

  const refresh = useCallback(async () => {
    setItems(await readLibrary());
  }, []);

  const upsert = useCallback(async (entry: Omit<LibraryEntry, "updatedAt"> & { updatedAt?: string }) => {
    const current = await readLibrary();
    const nextEntry: LibraryEntry = { ...entry, updatedAt: entry.updatedAt || new Date().toISOString() };
    const next = [nextEntry, ...current.filter((item) => !(item.animeId === entry.animeId && item.sourceId === entry.sourceId))];
    await writeLibrary(next);
    setItems(next);
  }, []);

  const setStatus = useCallback(
    async (entry: Omit<LibraryEntry, "updatedAt" | "status">, status: LibraryStatus) => {
      await upsert({ ...entry, status });
    },
    [upsert]
  );

  useEffect(() => {
    refresh();
  }, [refresh]);

  return { items, refresh, upsert, setStatus };
}
