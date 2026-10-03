// AHK Dynamic Island — Google Docs Activity Observer
// Privacy-first: ZERO document content inspection.

(function () {
  'use strict';

  function cleanDocTitle() {
    let title = document.title || "Google Docs";
    title = title.replace(/\s*-\s*Google Docs$/, "").replace(/\s*-\s*Google Drive$/, "").trim();
    return title.length > 0 ? title : "Untitled Document";
  }

  function emitDocsState(isEditing) {
    try {
      chrome.runtime.sendMessage({
        version: 1,
        source: "googledocs",
        site: "Google Docs",
        hostname: window.location.hostname,
        event: "stateChange",
        activity: isEditing ? "editing" : "browserActive",
        state: isEditing ? "editing" : "active",
        title: cleanDocTitle(),
        timestamp: Date.now() / 1000
      });
    } catch (e) {}
  }

  function init() {
    emitDocsState(true);

    // Debounced editing notification on user interaction
    let editTimeout = null;
    document.addEventListener('keydown', () => {
      if (!editTimeout) {
        emitDocsState(true);
      }
      clearTimeout(editTimeout);
      editTimeout = setTimeout(() => {
        editTimeout = null;
      }, 5000);
    }, { capture: true, passive: true });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
