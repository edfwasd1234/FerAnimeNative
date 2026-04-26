import { WebViewNavigation } from "react-native-webview";

const blockedHostPatterns = [
  /(^|\.)doubleclick\.net$/i,
  /(^|\.)googlesyndication\.com$/i,
  /(^|\.)google-analytics\.com$/i,
  /(^|\.)adservice\.google\.com$/i,
  /(^|\.)highperformanceformat\.com$/i,
  /(^|\.)cloudfront\.net$/i,
  /(^|\.)propellerads\.com$/i,
  /(^|\.)popads\.net$/i,
  /(^|\.)popcash\.net$/i,
  /(^|\.)onclickads\.net$/i,
  /(^|\.)adsterra\.com$/i,
  /(^|\.)exoclick\.com$/i,
  /(^|\.)trafficjunky\.net$/i
];

const blockedPathPatterns = [
  /\/ads?\//i,
  /\/popunder/i,
  /\/banner/i,
  /\/prebid/i,
  /\/vast/i,
  /\/invoke\.js/i,
  /[?&](ad|ads|pop|banner)=/i
];

export function shouldAllowWebViewRequest(request: WebViewNavigation) {
  try {
    const url = new URL(request.url);
    const hostBlocked = blockedHostPatterns.some((pattern) => pattern.test(url.hostname));
    const pathBlocked = blockedPathPatterns.some((pattern) => pattern.test(`${url.pathname}${url.search}`));
    return !hostBlocked && !pathBlocked;
  } catch {
    return true;
  }
}

export const adBlockerInjectedJavaScript = `
(() => {
  const blocked = [
    'iframe[src*="doubleclick"]',
    'iframe[src*="googlesyndication"]',
    'iframe[src*="highperformanceformat"]',
    'script[src*="highperformanceformat"]',
    '[id*="ad-"]',
    '[class*=" ad-"]',
    '[class*="ads"]',
    '[class*="banner"]',
    '[class*="popunder"]'
  ];
  const clean = () => {
    blocked.forEach((selector) => {
      document.querySelectorAll(selector).forEach((node) => node.remove());
    });
  };
  clean();
  new MutationObserver(clean).observe(document.documentElement, { childList: true, subtree: true });
  window.open = () => null;
})();
true;
`;

export const mediaSnifferInjectedJavaScript = `
(() => {
  if (window.__feranimeMediaSnifferInstalled) return true;
  window.__feranimeMediaSnifferInstalled = true;

  const seen = new Set();
  const isMediaUrl = (value) => typeof value === "string" && /\\\\.(m3u8|mp4)(?:[?#]|$)/i.test(value);
  const report = (url, via) => {
    if (!isMediaUrl(url) || seen.has(url)) return;
    seen.add(url);
    window.ReactNativeWebView?.postMessage(JSON.stringify({ type: "feranime:media-url", url, via }));
  };

  const scanText = (text, via) => {
    if (typeof text !== "string") return;
    const matches = text.match(/https?:\\\\/\\\\/[^"'<>\\\\\\\\\\s]+\\\\.(?:m3u8|mp4)[^"'<>\\\\\\\\\\s]*/gi) || [];
    matches.forEach((url) => report(url, via));
  };

  const originalFetch = window.fetch;
  if (originalFetch) {
    window.fetch = function(input, init) {
      const url = typeof input === "string" ? input : input?.url;
      report(url, "fetch-request");
      return originalFetch.apply(this, arguments).then((response) => {
        report(response?.url, "fetch-response");
        try {
          const clone = response.clone();
          clone.text().then((text) => scanText(text, "fetch-body")).catch(() => {});
        } catch {}
        return response;
      });
    };
  }

  const originalOpen = XMLHttpRequest.prototype.open;
  const originalSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.open = function(method, url) {
    this.__feranimeUrl = url;
    report(url, "xhr-open");
    return originalOpen.apply(this, arguments);
  };
  XMLHttpRequest.prototype.send = function() {
    this.addEventListener("load", function() {
      report(this.responseURL || this.__feranimeUrl, "xhr-load");
      try {
        if (typeof this.responseText === "string") scanText(this.responseText, "xhr-body");
      } catch {}
    });
    return originalSend.apply(this, arguments);
  };

  const mediaSrc = Object.getOwnPropertyDescriptor(HTMLMediaElement.prototype, "src");
  if (mediaSrc?.set) {
    Object.defineProperty(HTMLMediaElement.prototype, "src", {
      configurable: true,
      get: mediaSrc.get,
      set(value) {
        report(value, "media-src");
        return mediaSrc.set.call(this, value);
      }
    });
  }

  const originalSetAttribute = Element.prototype.setAttribute;
  Element.prototype.setAttribute = function(name, value) {
    if (String(name).toLowerCase() === "src") report(value, "set-attribute");
    return originalSetAttribute.apply(this, arguments);
  };

  try {
    new PerformanceObserver((list) => {
      list.getEntries().forEach((entry) => report(entry.name, "performance"));
    }).observe({ entryTypes: ["resource"] });
    performance.getEntriesByType("resource").forEach((entry) => report(entry.name, "performance-existing"));
  } catch {}

  document.querySelectorAll("video, source").forEach((node) => report(node.currentSrc || node.src, "initial-dom"));
})();
true;
`;
