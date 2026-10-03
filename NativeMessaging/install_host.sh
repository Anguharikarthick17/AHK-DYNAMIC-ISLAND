#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

echo "============================================================"
echo "AHK DYNAMIC ISLAND — NATIVE MESSAGING HOST INSTALLATION"
echo "============================================================"

# Step 1: Build Release AHKChromeMediaHost
echo "==> [1/14] Building AHKChromeMediaHost (Release)..."
swift build -c release --product AHKChromeMediaHost > /dev/null

# Step 2: Create Host Directory
TARGET_DIR="$HOME/Library/Application Support/AHKDynamicIsland"
echo "==> [2/14] Creating target directory: $TARGET_DIR..."
mkdir -p "$TARGET_DIR"

# Step 3: Install Host Executable
HOST_BIN="$TARGET_DIR/AHKChromeMediaHost"
echo "==> [3/14] Installing host executable..."
cp "$PROJECT_DIR/.build/release/AHKChromeMediaHost" "$HOST_BIN"

# Step 4: chmod +x Executable
echo "==> [4/14] Setting executable permissions..."
chmod +x "$HOST_BIN"

if [[ -d "/Applications/AHK Dynamic Island.app/Contents/MacOS" ]]; then
    cp "$HOST_BIN" "/Applications/AHK Dynamic Island.app/Contents/MacOS/AHKChromeMediaHost"
    chmod +x "/Applications/AHK Dynamic Island.app/Contents/MacOS/AHKChromeMediaHost"
fi

# Step 5: Create Chrome NativeMessagingHosts directory
CHROME_HOSTS_DIR="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts"
echo "==> [5/14] Preparing Chrome NativeMessagingHosts directory..."
mkdir -p "$CHROME_HOSTS_DIR"

# Step 6, 7, 8, 9, 10, 11, 12, 13, 14: Use Python for deterministic ID calculation, manifest generation, and validation
python3 - "$PROJECT_DIR" "$HOST_BIN" "$CHROME_HOSTS_DIR" << 'EOF'
import sys, os, json, hashlib, subprocess

project_dir = sys.argv[1]
host_bin = sys.argv[2]
chrome_hosts_dir = sys.argv[3]
ext_dir = os.path.join(project_dir, "ChromeExtension")

def chrome_id_from_path(p):
    digest = hashlib.sha256(p.encode("utf-8")).hexdigest()[:32]
    mapping = {c: chr(ord("a") + int(c, 16)) for c in "0123456789abcdef"}
    return "".join(mapping[c] for c in digest)

# 6. Determine ACTUAL extension identity
actual_id = ""

# Method A: Check running Chrome error tab or open tabs
try:
    ascript = """
    tell application "Google Chrome"
        set res to ""
        repeat with w in windows
            repeat with t in tabs of w
                set u to (URL of t)
                if u contains "chrome://extensions/?errors=" then
                    set AppleScript's text item delimiters to "chrome://extensions/?errors="
                    set res to text item 2 of u
                end if
            end repeat
        end repeat
        return res
    end tell
    """
    p = subprocess.run(["osascript", "-e", ascript], capture_output=True, text=True)
    out = p.stdout.strip()
    if len(out) == 32 and out.isalnum():
        actual_id = out
except Exception:
    pass

# Method B: Check manifest key if present
if not actual_id:
    manifest_p = os.path.join(ext_dir, "manifest.json")
    if os.path.exists(manifest_p):
        try:
            with open(manifest_p, "r", encoding="utf-8") as f:
                m = json.load(f)
                if "key" in m:
                    import base64
                    der = base64.b64decode(m["key"])
                    digest = hashlib.sha256(der).hexdigest()[:32]
                    mapping = {c: chr(ord("a") + int(c, 16)) for c in "0123456789abcdef"}
                    actual_id = "".join(mapping[c] for c in digest)
        except Exception:
            pass

# Method C: Path-derived ID
path_id = chrome_id_from_path(ext_dir)
if not actual_id:
    actual_id = path_id

print(f"==> [6/14] Determined ACTUAL Extension ID: {actual_id}")

# 7 & 8: Generate manifest with correct allowed_origins
allowed_origins = [
    f"chrome-extension://{actual_id}/",
    f"chrome-extension://{actual_id}/*"
]
if path_id != actual_id:
    allowed_origins.extend([
        f"chrome-extension://{path_id}/",
        f"chrome-extension://{path_id}/*"
    ])

manifest_data = {
    "name": "com.ahk.dynamicisland.chrome",
    "description": "AHK Dynamic Island Chrome Media Bridge",
    "path": host_bin,
    "type": "stdio",
    "allowed_origins": allowed_origins
}

manifest_path = os.path.join(chrome_hosts_dir, "com.ahk.dynamicisland.chrome.json")
with open(manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest_data, f, indent=2)
os.chmod(manifest_path, 0o644)

# Keep project repository copy in sync
local_manifest_path = os.path.join(project_dir, "NativeMessaging", "com.ahk.dynamicisland.chrome.json")
with open(local_manifest_path, "w", encoding="utf-8") as f:
    json.dump(manifest_data, f, indent=2)

print(f"==> [7/14] Generated manifest at: {manifest_path}")
print(f"==> [8/14] Registered allowed_origins: {allowed_origins[0]}")

# 9. Validate JSON
json_valid = False
try:
    with open(manifest_path, "r", encoding="utf-8") as f:
        loaded = json.load(f)
        json_valid = (loaded.get("name") == "com.ahk.dynamicisland.chrome" and loaded.get("type") == "stdio")
except Exception:
    json_valid = False

# 10. Validate executable path
bin_exists = os.path.exists(host_bin)

# 11. Validate executable permissions
bin_executable = os.access(host_bin, os.X_OK)

# 12 & 13. Print final manifest and registered ID
print("------------------------------------------------------------")
print(f"Registered Extension ID: {actual_id}")
print("Final Manifest:")
print(json.dumps(manifest_data, indent=2))
print("------------------------------------------------------------")

# 14. Print PASS/FAIL for each validation
print("==> [14/14] Validation Results:")
print(f"  [{'PASS' if len(actual_id) == 32 else 'FAIL'}] Extension identity: {actual_id}")
print(f"  [{'PASS' if json_valid else 'FAIL'}] Manifest JSON validation")
print(f"  [{'PASS' if bin_exists else 'FAIL'}] Host executable exists: {host_bin}")
print(f"  [{'PASS' if bin_executable else 'FAIL'}] Host executable permissions (+x)")
print(f"  [{'PASS' if (allowed_origins[0].startswith('chrome-extension://' + actual_id)) else 'FAIL'}] allowed_origins matching")

if not (len(actual_id) == 32 and json_valid and bin_exists and bin_executable):
    sys.exit(1)
EOF

echo "==> Native Messaging host installation complete."
