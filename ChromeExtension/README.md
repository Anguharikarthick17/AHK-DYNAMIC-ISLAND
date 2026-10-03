# AHK Dynamic Island — Chrome Media Bridge Extension (V0.5.1)

This extension connects Google Chrome's YouTube media playback to the native **AHK Dynamic Island** using Chrome Native Messaging.

## Privacy & Security Principles
- **Zero Scraping**: Only listens to HTML5 `<video>` events (`play`, `pause`, `ended`, `timeupdate`, `seeked`) and standard `navigator.mediaSession` metadata.
- **Zero Surveillance**: Never inspects cookies, passwords, search history, browsing history, comments, account data, or arbitrary tabs.
- **Strictly Local**: Transmits metadata directly to the local native messaging host on your Mac. No remote servers, no cloud APIs, no external telemetry.
- **Battery Friendly**: Zero polling (`no setInterval`), coalesced progress updates (maximum once every 1.8 seconds), completely quiescent when idle.

---

## Installation Guide (Developer Mode)

### Step 1: Install Native Messaging Host
Run the automated installation script from the project root:
```bash
./NativeMessaging/install_host.sh
```
This registers the Native Messaging manifest at:
`~/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.ahk.dynamicisland.chrome.json`

### Step 2: Load Unpacked Extension in Chrome
1. Open Google Chrome.
2. Navigate to `chrome://extensions/`.
3. Enable **Developer mode** (toggle in the top-right corner).
4. Click **Load unpacked** (top-left).
5. Select the `ChromeExtension/` directory from this repository:
   `/Users/angu/Documents/AHK Dynamic Island/ChromeExtension`

### Step 3: Test Live Activity
1. Open any video on [YouTube](https://www.youtube.com).
2. Click **Play**:
   - The Dynamic Island will smoothly display:
     `▶ YouTube / <Video Title>  <Position / Duration>`
3. Click **Pause**:
   - The Dynamic Island updates to:
     `⏸ YouTube / <Video Title>`
4. Switch to another app (e.g. Finder, Xcode, Terminal):
   - The YouTube playback activity remains visible on your Dynamic Island!
5. Close the tab or video finishes:
   - Dynamic Island displays `✓ YouTube Playback Complete` and restores your Mac's idle computer name.
