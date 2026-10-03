// AHK Dynamic Island — ChatGPT Activity Observer
// Event-driven, privacy-first detection of ChatGPT UI generation states.
// STRICT PRIVACY: ZERO prompt scraping, ZERO response scraping, ZERO conversation history.

(function () {
  'use strict';

  let currentState = 'active';
  let completionTimer = null;

  function emitChatGPTState(state) {
    if (state === currentState && state !== 'completed') return;
    currentState = state;

    // Sanitize title: only extract conversation topic if present in document title,
    // otherwise default to "ChatGPT"
    let pageTitle = "ChatGPT";
    if (document.title && !document.title.includes("http")) {
      const clean = document.title.replace(/^\([0-9]+\)\s*/, "").replace(/\s*-\s*ChatGPT$/, "").trim();
      if (clean.length > 0 && clean.toLowerCase() !== "chatgpt") {
        pageTitle = clean;
      }
    }

    try {
      chrome.runtime.sendMessage({
        version: 1,
        source: "chatgpt",
        site: "ChatGPT",
        hostname: window.location.hostname,
        event: "stateChange",
        activity: state === 'processing' ? 'processing' : (state === 'completed' ? 'completed' : 'browserActive'),
        state: state,
        title: pageTitle,
        timestamp: Date.now() / 1000
      });
    } catch (e) {
      // Extension context invalidated or reloaded
    }
  }

  function isGenerating() {
    // Check for explicit stop button indicating active generation/streaming
    const stopBtn = document.querySelector('button[data-testid="stop-button"], button[aria-label*="Stop"], button[aria-label*="stop"]');
    if (stopBtn && !stopBtn.disabled) {
      return true;
    }
    // Check for streaming indicator / thinking badge
    const streamingIndicator = document.querySelector('.result-streaming, [data-is-streaming="true"]');
    if (streamingIndicator) {
      return true;
    }
    return false;
  }

  function checkUIState() {
    const generating = isGenerating();
    if (generating) {
      if (completionTimer) {
        clearTimeout(completionTimer);
        completionTimer = null;
      }
      emitChatGPTState('processing');
    } else {
      if (currentState === 'processing') {
        // Generation just completed!
        emitChatGPTState('completed');
        // Transient completion state for 2.5 seconds, then return to active
        if (completionTimer) clearTimeout(completionTimer);
        completionTimer = setTimeout(() => {
          emitChatGPTState('active');
          completionTimer = null;
        }, 2500);
      }
    }
  }

  function observeChatGPT() {
    // Initial emit
    emitChatGPTState('active');

    // Scoped MutationObserver on the main interactive container
    const observer = new MutationObserver((mutations) => {
      checkUIState();
    });

    const targetNode = document.querySelector('main') || document.body || document.documentElement;
    observer.observe(targetNode, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['data-testid', 'aria-label', 'disabled', 'class']
    });

    // Event listener on prompt form submission
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        const textarea = e.target.closest('#prompt-textarea, textarea');
        if (textarea) {
          // User sent prompt; queue immediate check
          setTimeout(checkUIState, 50);
        }
      }
    }, { capture: true, passive: true });

    document.addEventListener('click', (e) => {
      const btn = e.target.closest('button[data-testid="send-button"], button[aria-label*="Send"]');
      if (btn) {
        setTimeout(checkUIState, 50);
      }
    }, { capture: true, passive: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', observeChatGPT);
  } else {
    observeChatGPT();
  }
})();
