#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$HOME/Library/Application Support/Google/Chrome/NativeMessagingHosts/com.ahk.dynamicisland.chrome.json"
HOST_PATH="$HOME/Library/Application Support/AHKDynamicIsland/AHKChromeMediaHost"

python3 - "$PROJECT_DIR" "$MANIFEST_PATH" "$HOST_PATH" << 'EOF'
import sys, os, json, hashlib, subprocess

project_dir = sys.argv[1]
manifest_path = sys.argv[2]
host_path = sys.argv[3]
ext_dir = os.path.join(project_dir, "ChromeExtension")

def chrome_id_from_path(p):
    digest = hashlib.sha256(p.encode("utf-8")).hexdigest()[:32]
    mapping = {c: chr(ord("a") + int(c, 16)) for c in "0123456789abcdef"}
    return "".join(mapping[c] for c in digest)

# Determine Extension ID
actual_id = ""
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

if not actual_id:
    actual_id = chrome_id_from_path(ext_dir)

manifest_exists = os.path.exists(manifest_path)
manifest_json_valid = False
host_name_correct = False
host_path_correct = False
allowed_origins_valid = False
origins_match = False
manifest_content = ""

if manifest_exists:
    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest_content = f.read()
            data = json.loads(manifest_content)
            manifest_json_valid = True
            host_name_correct = (data.get("name") == "com.ahk.dynamicisland.chrome")
            host_path_correct = (data.get("path") == host_path)
            origins = data.get("allowed_origins", [])
            allowed_origins_valid = len(origins) > 0 and all(isinstance(o, str) for o in origins)
            target_origin = f"chrome-extension://{actual_id}/"
            origins_match = any(target_origin in o or f"chrome-extension://{actual_id}/*" in o for o in origins)
    except Exception:
        manifest_json_valid = False

host_exists = os.path.exists(host_path)
host_executable = os.access(host_path, os.X_OK) if host_exists else False

# Architecture check
arch_valid = False
arch_info = ""
if host_exists:
    try:
        p = subprocess.run(["file", host_path], capture_output=True, text=True)
        arch_info = p.stdout.strip()
        arch_valid = "arm64" in arch_info or "Mach-O" in arch_info
    except Exception:
        pass

overall_config_pass = (
    len(actual_id) == 32 and
    manifest_exists and
    manifest_json_valid and
    host_name_correct and
    host_path_correct and
    host_exists and
    host_executable and
    arch_valid and
    allowed_origins_valid and
    origins_match
)

def status(b):
    return "PASS" if b else "FAIL"

print("------------------------------------------------")
print("AHK DYNAMIC ISLAND NATIVE MESSAGING DIAGNOSTICS")
print("------------------------------------------------\n")
print(f"Extension ID:\n{actual_id}\n")
print(f"Manifest:\n{manifest_path}\n")
print(f"Host:\n{host_path}\n")
print("Checks:\n")
print(f"[{status(len(actual_id) == 32)}] Extension identity")
print(f"[{status(manifest_exists)}] Manifest exists")
print(f"[{status(manifest_json_valid)}] Manifest JSON valid")
print(f"[{status(host_name_correct)}] Host name correct")
print(f"[{status(host_path_correct)}] Host path correct")
print(f"[{status(host_exists)}] Host exists")
print(f"[{status(host_executable)}] Host executable")
print(f"[{status(arch_valid)}] Host architecture ({arch_info.split(': ')[-1] if arch_info else 'unknown'})")
print(f"[{status(allowed_origins_valid)}] allowed_origins")
print(f"[{status(origins_match)}] allowed_origins matches extension ID")
print(f"[{status(overall_config_pass)}] Native Messaging configuration\n")

print("------------------------------------------------")
print("Final Manifest:")
print(manifest_content if manifest_content else "(manifest not found)")
print("------------------------------------------------")

if not overall_config_pass:
    sys.exit(1)
EOF
