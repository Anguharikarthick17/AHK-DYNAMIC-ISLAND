// AHK Dynamic Island — Universal Chrome Activity Intelligence (V0.6.1)
// Universal All-Chrome-Tabs & All-Websites + Active Tab Absolute Priority.
// ZERO polling. Strict privacy: ZERO prompt/response/cookie/history capture.

const NATIVE_HOST_NAME = "com.ahk.dynamicisland.chrome";
let nativePort = null;
let activeTabId = null;
let activeWindowId = null;

// In-memory tab registry
const tabRegistry = new Map();

// Centralized Known Services Map (Section 9)
const KNOWN_SERVICES = [
  { match: /(^|\.)youtube\.com$/i, name: "YouTube", glyph: "●" },
  { match: /(^|\.)chatgpt\.com$|(^|\.)chat\.openai\.com$/i, name: "ChatGPT", glyph: "✦" },
  { match: /^docs\.google\.com$/i, name: "Google Docs", glyph: "✎" },
  { match: /^mail\.google\.com$/i, name: "Gmail", glyph: "✉" },
  { match: /(^|\.)google\.[a-z.]+$/i, name: "Google", glyph: "●" },
  { match: /(^|\.)github\.com$/i, name: "GitHub", glyph: "◉" },
  { match: /(^|\.)figma\.com$/i, name: "Figma", glyph: "◇" },
  { match: /(^|\.)spotify\.com$/i, name: "Spotify", glyph: "♫" },
  { match: /(^|\.)instagram\.com$/i, name: "Instagram", glyph: "●" },
  { match: /(^|\.)whatsapp\.com$/i, name: "WhatsApp", glyph: "●" },
  { match: /(^|\.)x\.com$|(^|\.)twitter\.com$/i, name: "X", glyph: "●" },
  { match: /(^|\.)amazon\.[a-z.]+$/i, name: "Amazon", glyph: "●" },
  { match: /(^|\.)netflix\.com$/i, name: "Netflix", glyph: "●" },
  { match: /(^|\.)wikipedia\.org$/i, name: "Wikipedia", glyph: "●" },
  { match: /(^|\.)stackoverflow\.com$/i, name: "Stack Overflow", glyph: "●" },
  { match: /(^|\.)linkedin\.com$/i, name: "LinkedIn", glyph: "●" },
  { match: /(^|\.)reddit\.com$/i, name: "Reddit", glyph: "●" }
];

function cleanHostname(urlStr) {
  if (!urlStr) return "";
  try {
    const url = new URL(urlStr);
    return (url.hostname || "").toLowerCase().replace(/^www\./, "");
  } catch (e) {
    return "";
  }
}

// Centralized website identity resolver (Section 9)
function resolveSiteInfo(urlStr, title) {
  const hostname = cleanHostname(urlStr);

  // 1. Localhost & IP addresses
  if (hostname === "localhost" || hostname === "127.0.0.1" || hostname.startsWith("192.168.") || hostname.startsWith("10.")) {
    return { site: "localhost", glyph: "●", hostname: hostname || "localhost" };
  }

  // 2. Recognized Hostname / Service Names
  for (const s of KNOWN_SERVICES) {
    if (s.match.test(hostname)) {
      return { site: s.name, glyph: s.glyph, hostname: hostname };
    }
  }

  // 3. Clean Domain-Derived Name (Universal fallback for ANY website)
  if (hostname && hostname.includes(".")) {
    const parts = hostname.split(".");
    const commonTlds = new Set(["com", "org", "net", "edu", "gov", "mil", "io", "app", "dev", "ai", "co", "uk", "ca", "de", "jp", "fr", "au", "in", "us"]);
    let mainIndex = parts.length - 2;
    if (mainIndex > 0 && commonTlds.has(parts[parts.length - 1]) && commonTlds.has(parts[parts.length - 2])) {
      mainIndex = parts.length - 3;
    }
    if (mainIndex >= 0 && mainIndex < parts.length) {
      let label = parts[mainIndex];
      // Format kebab-case / snake-case into Title Words: "abc-random-site" -> "Abc Random Site"
      let words = label.split(/[-_]+/).filter(w => w.length > 0);
      if (words.length > 0) {
        let siteName = words.map(w => w.charAt(0).toUpperCase() + w.slice(1)).join(" ");
        return { site: siteName, glyph: "●", hostname: hostname };
      }
    }
  }

  // 4. Fallback to Title or "Chrome"
  if (title && title.trim().length > 0) {
    let clean = title.replace(/^\([0-9]+\)\s*/, "").split(/[\-–—·|•]/)[0].trim();
    if (clean.length > 0 && clean.length <= 25) {
      return { site: clean, glyph: "●", hostname: hostname || "chrome" };
    }
  }

  return { site: "Chrome", glyph: "●", hostname: hostname || "chrome" };
}

function cleanTitle(rawTitle, site) {
  if (!rawTitle) return site || "Chrome";
  // Remove tab notification counts like "(3) " and common site suffixes
  let cleaned = rawTitle.replace(/^\([0-9]+\)\s*/, "").trim();
  if (site === "YouTube") {
    cleaned = cleaned.replace(/\s*-\s*YouTube$/, "").trim();
  } else if (site === "GitHub") {
    cleaned = cleaned.replace(/\s*·\s*GitHub$/, "").trim();
  } else if (site === "Google Docs") {
    cleaned = cleaned.replace(/\s*-\s*Google Docs$/, "").trim();
  } else if (site === "ChatGPT") {
    cleaned = cleaned.replace(/\s*-\s*ChatGPT$/, "").trim();
  }
  return cleaned.length > 0 ? cleaned : (site || "Chrome");
}

function connectNative() {
  if (nativePort) return nativePort;
  try {
    nativePort = chrome.runtime.connectNative(NATIVE_HOST_NAME);
    nativePort.onMessage.addListener((response) => {});
    nativePort.onDisconnect.addListener(() => {
      nativePort = null;
    });
  } catch (err) {
    nativePort = null;
  }
  return nativePort;
}

function sendNativeMessage(msg) {
  const port = connectNative();
  if (port) {
    try {
      port.postMessage(msg);
    } catch (e) {
      nativePort = null;
    }
  }
}

function broadcastTabActivity(tabId, overrides = {}) {
  const tab = tabRegistry.get(tabId);
  if (!tab) return;

  const isActive = (tabId === activeTabId);
  const siteInfo = resolveSiteInfo(tab.url || "", tab.title || "");
  const pageTitle = cleanTitle(tab.title, siteInfo.site);

  const activityType = overrides.activity || (tab.status === "loading" ? "pageLoading" : "browserActive");
  const activityState = overrides.state || (activityType === "pageLoading" ? "loading" : "active");
  const defaultSubtitle = (activityType === "pageLoading") ? "Loading" : "Working";
  const subtitle = overrides.subtitle || defaultSubtitle;
  const confidence = overrides.confidence || (siteInfo.site !== "Chrome" ? "medium" : "low");

  const message = {
    version: 1,
    source: "chrome",
    event: overrides.event || "activityUpdate",
    tabId: tabId,
    windowId: tab.windowId,
    site: overrides.site || siteInfo.site,
    hostname: siteInfo.hostname,
    title: pageTitle,
    glyph: overrides.glyph || siteInfo.glyph,
    activity: activityType,
    state: activityState,
    activitySubtitle: subtitle,
    confidence: confidence,
    isActiveTab: isActive,
    timestamp: Date.now() / 1000
  };

  sendNativeMessage(message);
}

// MARK: - Chrome Tab Event Listeners (Event-Driven, Zero Polling)

// 1. Tab Activation (Switching Tabs)
chrome.tabs.onActivated.addListener((activeInfo) => {
  activeTabId = activeInfo.tabId;
  activeWindowId = activeInfo.windowId;

  chrome.tabs.get(activeTabId, (tab) => {
    if (chrome.runtime.lastError || !tab) return;
    tabRegistry.set(tab.id, {
      id: tab.id,
      windowId: tab.windowId,
      url: tab.url || "",
      title: tab.title || "",
      status: tab.status || "complete",
      audible: tab.audible || false
    });

    broadcastTabActivity(tab.id, { event: "tabActivated" });
  });
});

// 2. Tab Updated (URL navigation, title change, loading state, SPA transitions)
chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab) => {
  let existing = tabRegistry.get(tabId) || { id: tabId, windowId: tab.windowId };
  existing.url = tab.url || existing.url || "";
  existing.title = tab.title || existing.title || "";
  existing.status = tab.status || existing.status || "complete";
  existing.audible = tab.audible !== undefined ? tab.audible : existing.audible;
  tabRegistry.set(tabId, existing);

  // If loading or title updated on active or media tab, emit update
  if (changeInfo.status || changeInfo.title || changeInfo.audible !== undefined) {
    const isSpecialState = existing.audible || tabId === activeTabId;
    if (isSpecialState) {
      broadcastTabActivity(tabId, {
        activity: changeInfo.status === "loading" ? "pageLoading" : undefined
      });
    }
  }
});

// 3. Tab Removed (Tab closed)
chrome.tabs.onRemoved.addListener((tabId) => {
  tabRegistry.delete(tabId);
  sendNativeMessage({
    version: 1,
    source: "chrome",
    event: "tabRemoved",
    tabId: tabId,
    timestamp: Date.now() / 1000
  });

  if (tabId === activeTabId) {
    activeTabId = null;
    // Resolve newly active tab in current window
    chrome.tabs.query({ active: true, lastFocusedWindow: true }, (tabs) => {
      if (tabs && tabs.length > 0) {
        activeTabId = tabs[0].id;
        broadcastTabActivity(activeTabId, { event: "tabActivated" });
      }
    });
  }
});

// 4. Tab Attached / Detached / Replaced
chrome.tabs.onAttached.addListener((tabId, attachInfo) => {
  let existing = tabRegistry.get(tabId) || { id: tabId };
  existing.windowId = attachInfo.newWindowId;
  tabRegistry.set(tabId, existing);
});

chrome.tabs.onDetached.addListener((tabId) => {
  let existing = tabRegistry.get(tabId);
  if (existing) {
    existing.windowId = null;
  }
});

chrome.tabs.onReplaced.addListener((addedTabId, removedTabId) => {
  tabRegistry.delete(removedTabId);
  if (activeTabId === removedTabId) {
    activeTabId = addedTabId;
  }
  chrome.tabs.get(addedTabId, (tab) => {
    if (chrome.runtime.lastError || !tab) return;
    tabRegistry.set(addedTabId, {
      id: tab.id,
      windowId: tab.windowId,
      url: tab.url || "",
      title: tab.title || "",
      status: tab.status || "complete",
      audible: tab.audible || false
    });
    broadcastTabActivity(addedTabId, { event: "tabActivated" });
  });
});

// 5. Window Focus Changed & Window Removal (Multiple Chrome Windows Support)
chrome.windows.onFocusChanged.addListener((windowId) => {
  if (windowId === chrome.windows.WINDOW_ID_NONE) return;
  activeWindowId = windowId;
  chrome.tabs.query({ active: true, windowId: windowId }, (tabs) => {
    if (tabs && tabs.length > 0) {
      activeTabId = tabs[0].id;
      tabRegistry.set(activeTabId, {
        id: tabs[0].id,
        windowId: windowId,
        url: tabs[0].url || "",
        title: tabs[0].title || "",
        status: tabs[0].status || "complete",
        audible: tabs[0].audible || false
      });
      broadcastTabActivity(activeTabId, { event: "tabActivated" });
    }
  });
});

chrome.windows.onRemoved.addListener((windowId) => {
  for (const [id, tab] of tabRegistry.entries()) {
    if (tab.windowId === windowId) {
      tabRegistry.delete(id);
    }
  }
});

// 6. Specialized Content Script Message Relay (YouTube, ChatGPT, Google Docs)
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (!message) return false;

  const senderTabId = (sender && sender.tab) ? sender.tab.id : activeTabId;
  const senderWindowId = (sender && sender.tab) ? sender.tab.windowId : activeWindowId;

  // Augment message with tab context
  message.tabId = senderTabId;
  message.windowId = senderWindowId;
  message.isActiveTab = (senderTabId === activeTabId);

  // Update in-memory registry
  if (senderTabId) {
    let existing = tabRegistry.get(senderTabId) || { id: senderTabId, windowId: senderWindowId };
    if (message.title) existing.title = message.title;
    if (message.state) existing.lastSpecialState = message.state;
    tabRegistry.set(senderTabId, existing);
  }

  sendNativeMessage(message);
  sendResponse({ status: "relayed" });
  return true;
});

// 7. Initial Boot Discovery (One-time query when worker spins up)
function initActiveTab() {
  chrome.tabs.query({ active: true, lastFocusedWindow: true }, (tabs) => {
    if (tabs && tabs.length > 0) {
      const tab = tabs[0];
      activeTabId = tab.id;
      activeWindowId = tab.windowId;
      tabRegistry.set(tab.id, {
        id: tab.id,
        windowId: tab.windowId,
        url: tab.url || "",
        title: tab.title || "",
        status: tab.status || "complete",
        audible: tab.audible || false
      });
      broadcastTabActivity(tab.id, { event: "tabActivated" });
    }
  });
}

initActiveTab();
chrome.runtime.onInstalled.addListener(initActiveTab);
chrome.runtime.onStartup.addListener(initActiveTab);
