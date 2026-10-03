// AHK Dynamic Island — YouTube Media Detection Content Script
// Purely event-driven media observation. Zero DOM scraping. Zero polling.

(function () {
  'use strict';

  let lastEmittedTime = 0;
  let lastReportedPosition = -1;
  let observedVideo = null;
  const sessionId = "yt_" + Math.random().toString(36).substring(2, 10);

  function getMediaMetadata() {
    let title = "YouTube";
    let artist = "";
    let artworkUrl = null;

    // Priority 1: Standard Media Session API
    if (navigator.mediaSession && navigator.mediaSession.metadata) {
      const meta = navigator.mediaSession.metadata;
      if (meta.title && meta.title.trim().length > 0) {
        title = meta.title.trim();
      }
      if (meta.artist && meta.artist.trim().length > 0) {
        artist = meta.artist.trim();
      }
      if (meta.artwork && meta.artwork.length > 0) {
        artworkUrl = meta.artwork[0].src;
      }
    }

    // Fallback: If mediaSession title is generic or empty, inspect page document title
    if (title === "YouTube" && document.title) {
      const cleanTitle = document.title.replace(/^\([0-9]+\)\s*/, "").replace(/\s*-\s*YouTube$/, "").trim();
      if (cleanTitle.length > 0) {
        title = cleanTitle;
      }
    }

    return { title, artist, artworkUrl };
  }

  function sendMediaMessage(event, video) {
    if (!video) return;

    const meta = getMediaMetadata();
    const position = Math.round(video.currentTime || 0);
    const duration = Math.round(video.duration || 0);

    const isSpotify = window.location.hostname.includes("spotify.com");
    const isSoundCloud = window.location.hostname.includes("soundcloud.com");
    const mediaProvider = isSpotify ? "spotify" : (isSoundCloud ? "soundcloud" : "youtube");

    const message = {
      version: 1,
      source: "chrome",
      provider: mediaProvider,
      site: isSpotify ? "Spotify" : (isSoundCloud ? "SoundCloud" : "YouTube"),
      event: event,
      sessionId: sessionId,
      title: meta.title,
      artist: meta.artist,
      position: position,
      duration: duration,
      timestamp: Date.now() / 1000,
      artworkUrl: meta.artworkUrl
    };

    lastReportedPosition = position;
    lastEmittedTime = Date.now();

    try {
      chrome.runtime.sendMessage(message, () => {
        // Handled by background service worker
      });
    } catch (e) {
      // Extension context invalidated or reloaded
    }
  }

  function isPreviewOrThumbnail(video) {
    if (!video) return true;
    if (video.closest && video.closest('.ytd-video-preview, ytd-thumbnail, #inline-preview-player, .video-preview')) {
      return true;
    }
    if (window.location.hostname.includes("youtube.com")) {
      if (!video.classList.contains('html5-main-video') && (video.duration || 0) < 15) {
        return true;
      }
    }
    return false;
  }

  function attachVideoListeners(video) {
    if (!video || video === observedVideo) return;
    if (isPreviewOrThumbnail(video)) return;
    observedVideo = video;

    video.addEventListener('play', () => {
      if (!isPreviewOrThumbnail(video)) {
        sendMediaMessage('play', video);
      }
    });

    video.addEventListener('pause', () => {
      if (!isPreviewOrThumbnail(video)) {
        sendMediaMessage('pause', video);
      }
    });

    video.addEventListener('ended', () => {
      sendMediaMessage('ended', video);
    });

    video.addEventListener('seeked', () => {
      if (!isPreviewOrThumbnail(video)) {
        sendMediaMessage('timeupdate', video);
      }
    });

    video.addEventListener('timeupdate', () => {
      if (isPreviewOrThumbnail(video)) return;
      // Strict progress coalescing: update at most once every 1.8 seconds (Section 6 & 19)
      const now = Date.now();
      const currentPos = Math.round(video.currentTime || 0);
      const isLargeSeek = Math.abs(currentPos - lastReportedPosition) >= 3;

      if (isLargeSeek || (now - lastEmittedTime >= 1800)) {
        if (!video.paused && !video.ended) {
          sendMediaMessage('timeupdate', video);
        }
      }
    });

    // If already playing when attached
    if (!video.paused && !video.ended) {
      sendMediaMessage('play', video);
    }
  }

  // Detect HTML5 video tag dynamically via MutationObserver without polling
  function findAndObserveVideo() {
    const video = document.querySelector('.html5-main-video') || document.querySelector('video');
    if (video && !isPreviewOrThumbnail(video)) {
      attachVideoListeners(video);
    }

    const observer = new MutationObserver((mutations) => {
      if (observedVideo && document.contains(observedVideo) && !observedVideo.paused) return;
      const v = document.querySelector('.html5-main-video') || document.querySelector('video');
      if (v && !isPreviewOrThumbnail(v)) {
        attachVideoListeners(v);
      }
    });

    observer.observe(document.body || document.documentElement, {
      childList: true,
      subtree: true
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', findAndObserveVideo);
  } else {
    findAndObserveVideo();
  }
})();
