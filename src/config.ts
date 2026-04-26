import Constants from "expo-constants";
import { Platform } from "react-native";

const resolverPort = 4517;

function getResolverHost() {
  if (Platform.OS === "web") return "127.0.0.1";

  const hostUri =
    Constants.expoConfig?.hostUri ||
    Constants.manifest2?.extra?.expoClient?.hostUri ||
    Constants.manifest?.debuggerHost;

  const host = typeof hostUri === "string" ? hostUri.split(":")[0] : "";
  return host || "127.0.0.1";
}

export const FERANIME_RESOLVER_URL = `http://${getResolverHost()}:${resolverPort}`;
