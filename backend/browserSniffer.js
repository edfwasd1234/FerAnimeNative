const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawn } = require("node:child_process");

const mediaRe = /\.(?:m3u8|mp4)(?:[?#]|$)/i;

function findBrowser() {
  const candidates = [
    process.env.CHROME_PATH,
    "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
    "C:\\Program Files\\Microsoft\\Edge\\Application\\msedge.exe",
    "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe"
  ].filter(Boolean);
  return candidates.find((candidate) => fs.existsSync(candidate));
}

function wait(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function fetchJson(url, init) {
  const response = await fetch(url, init);
  if (!response.ok) throw new Error(`${response.status} ${response.statusText} for ${url}`);
  return response.json();
}

async function waitForDebugger(port, timeoutMs) {
  const started = Date.now();
  while (Date.now() - started < timeoutMs) {
    try {
      return await fetchJson(`http://127.0.0.1:${port}/json/version`);
    } catch {
      await wait(250);
    }
  }
  throw new Error("Browser debugger did not start");
}

function openCdp(wsUrl) {
  const socket = new WebSocket(wsUrl);
  let nextId = 1;
  const pending = new Map();
  const listeners = new Set();

  socket.addEventListener("message", (event) => {
    const payload = JSON.parse(event.data);
    if (payload.id && pending.has(payload.id)) {
      pending.get(payload.id)(payload);
      pending.delete(payload.id);
      return;
    }
    listeners.forEach((listener) => listener(payload));
  });

  const ready = new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  return {
    ready,
    onEvent(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    },
    send(method, params = {}) {
      const id = nextId++;
      const message = { id, method, params };
      const result = new Promise((resolve) => pending.set(id, resolve));
      socket.send(JSON.stringify(message));
      return result;
    },
    close() {
      socket.close();
    }
  };
}

async function sniffMediaUrls(url, { referer, timeoutMs = 18000 } = {}) {
  const browser = findBrowser();
  if (!browser) throw new Error("No Chrome or Edge executable found");

  const port = 9300 + Math.floor(Math.random() * 500);
  const userDataDir = fs.mkdtempSync(path.join(os.tmpdir(), "feranime-cdp-"));
  const args = [
    "--headless=new",
    "--disable-gpu",
    "--mute-audio",
    "--autoplay-policy=no-user-gesture-required",
    "--disable-popup-blocking",
    "--no-first-run",
    "--no-default-browser-check",
    `--remote-debugging-port=${port}`,
    `--user-data-dir=${userDataDir}`,
    "about:blank"
  ];

  const child = spawn(browser, args, { stdio: "ignore", windowsHide: true });
  const found = new Map();

  try {
    await waitForDebugger(port, 7000);
    const target = await fetchJson(`http://127.0.0.1:${port}/json/new?${encodeURIComponent("about:blank")}`, { method: "PUT" });
    const cdp = openCdp(target.webSocketDebuggerUrl);
    await cdp.ready;
    cdp.onEvent((message) => {
      const requestUrl = message.params?.request?.url || message.params?.response?.url;
      if (requestUrl && mediaRe.test(requestUrl) && !found.has(requestUrl)) {
        found.set(requestUrl, {
          url: requestUrl,
          via: message.method,
          type: requestUrl.includes(".m3u8") ? "hls" : "mp4"
        });
      }
      if (message.method === "Network.responseReceived" && message.params?.requestId) {
        const resourceType = message.params.type;
        if (["XHR", "Fetch", "Media", "Other"].includes(resourceType)) {
          cdp.send("Network.getResponseBody", { requestId: message.params.requestId })
            .then((bodyResponse) => {
              const body = bodyResponse.result?.body || bodyResponse.body || "";
              const text = bodyResponse.result?.base64Encoded || bodyResponse.base64Encoded ? Buffer.from(body, "base64").toString("utf8") : body;
              const matches = String(text).match(/https?:\/\/[^"'<>\\\s]+\.(?:m3u8|mp4)[^"'<>\\\s]*/gi) || [];
              matches.forEach((url) => {
                if (!found.has(url)) {
                  found.set(url, {
                    url,
                    via: `${message.method}:body`,
                    type: url.includes(".m3u8") ? "hls" : "mp4"
                  });
                }
              });
            })
            .catch(() => {});
        }
      }
    });

    await cdp.send("Network.enable");
    await cdp.send("Page.enable");
    if (referer) {
      await cdp.send("Network.setExtraHTTPHeaders", { headers: { Referer: referer } });
    }
    await cdp.send("Page.navigate", { url, referrer: referer || "" });
    await wait(Math.min(timeoutMs, 6000));
    await cdp.send("Runtime.evaluate", {
      expression: `
        (() => {
          document.querySelectorAll('video,button,.jw-icon-playback,.vjs-big-play-button,[role="button"]').forEach((node) => {
            try { node.click(); } catch {}
          });
        })();
      `,
      awaitPromise: false
    });
    await wait(Math.max(1000, timeoutMs - 6000));
    cdp.close();
    return [...found.values()];
  } finally {
    child.kill();
    fs.rm(userDataDir, { recursive: true, force: true }, () => {});
  }
}

module.exports = {
  sniffMediaUrls
};
