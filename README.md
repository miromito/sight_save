# SightSave

A lightweight native **macOS menu bar** app that protects your eyes and lower back. It notices when you are sitting at the computer, times your work session, and reminds you to take breaks.

**Bundle identifier:** `com.rodionlitvinoff.SightSave`  
**Requirements:** macOS 13 Ventura or later · Apple Silicon or Intel  
**License:** MIT © 2026 Rodion Litvinoff

---

## Quick start (no experience needed)

You do **not** need the big Xcode app from the App Store. Follow these steps once.

### 1. Open Terminal

1. Press **Command (⌘) + Space** to open Spotlight.
2. Type **Terminal**.
3. Press **Enter**.

A window with a text prompt appears. That is Terminal.

### 2. Install Apple’s Command Line Tools (one time)

Copy this line, paste it into Terminal (**⌘V**), then press **Enter**:

```bash
xcode-select --install
```

A system popup appears → click **Install** → agree to the license → wait until it finishes (it can take several minutes).  
If Terminal says the tools are already installed, that is fine — continue.

### 3. Download, build, and install SightSave (one copy-paste)

Copy **this whole block**, paste into Terminal, press **Enter**, and wait (first build may take a few minutes):

```bash
git clone https://github.com/miromito/sight_save.git ~/sight_save && cd ~/sight_save && chmod +x scripts/install.sh scripts/build.sh && ./scripts/install.sh
```

That command:

1. Downloads the project into a folder called `sight_save` in your home folder  
2. Builds the app  
3. Copies **SightSave** into **Applications**  
4. Opens it  

### 4. What you should see next

- An **eye** icon appears in the **menu bar** at the **top-right** of the screen (near Wi‑Fi / clock). There is **no** Dock icon — that is normal.
- macOS may ask for **Camera** and **Notifications** → click **Allow** (you can change this later; keyboard-only mode works without the camera).
- If macOS says the app **can’t be opened** / was blocked:
  1. Open **System Settings**
  2. Go to **Privacy & Security**
  3. Scroll down and click **Open Anyway** for SightSave  
  (Or in Finder: right-click the app → **Open** → **Open**.)

### 5. Open settings

Click the **eye** menu bar icon → **Settings…**

### What each setting means

| Setting | Default | Plain meaning |
|---------|---------|----------------|
| **Presence / away threshold (X)** | 2 min | How long you must sit before work timing starts; also how long you must leave before a real “rest” starts |
| **Work limit (Y)** | 50 min | How long you may sit before SightSave asks for a break |
| **Rest duration (Z)** | 5 min | How long you should stay away for the break to “count” and reset |
| **Check interval** | 5 sec | How often SightSave checks if you are there |
| **Detection mode** | Hybrid | **Hybrid** = keyboard/mouse first, camera if idle · **Camera** = face only · **Keyboard & mouse** = no camera |
| **Warning style** | Overlay | Big on-screen reminder, or a normal macOS notification |
| **Snooze length** | 5 min | “Remind me again in this many minutes” |
| **Rest-done sound** | Glass | Sound when your rest is finished (there is a Preview button) |
| **During calls** | Silent only | What to do on Zoom/Meet/etc.: stay quiet, soft ping, or normal reminders |
| **Long-call nudge** | 60 min | Optional gentle “stand up” tip during long calls |
| **Launch at login** | Off | Start SightSave automatically when you log in |

### Update later

Open Terminal and paste:

```bash
cd ~/sight_save && git pull && ./scripts/install.sh
```

### Uninstall

Quit SightSave (menu bar icon → **Quit SightSave**), then in Terminal:

```bash
rm -rf /Applications/SightSave.app
```

(Optional) also delete the download folder: `rm -rf ~/sight_save`

---

## What it does

1. Detects whether you are present (camera face detection, keyboard/mouse activity, or both).
2. After you have been continuously present for **X** minutes (default 2), starts a work timer.
3. After **Y** minutes of work (default 50), shows a break warning and keeps counting **overtime**.
4. When you leave for longer than **X** minutes, a **rest** timer starts.
5. After **Z** minutes of rest (default 5), plays a sound and notifies you that you can come back.
6. If you return before rest finishes, your work session resumes where it left off (rest does not count).

SightSave lives only in the menu bar (no Dock icon). Click the eye icon for status, Pause/Resume, Reset, Settings, and Quit.

---

## Privacy

- **On-device only.** No accounts, analytics, telemetry, or network access.
- Camera frames are captured briefly at low resolution, run through Apple Vision face detection **on your Mac**, then discarded.
- Frames are **never saved, logged, or transmitted**.
- You can use **keyboard & mouse only** mode and never enable the camera.
- During video calls, SightSave does **not** open the camera; it treats you as present via system “device in use” signals.

---

## Requirements to build

**You do not need the full Xcode app.** Command Line Tools are enough.

| Item | Version |
|------|---------|
| macOS | 13.0+ (to run); build on a Mac with a recent SDK |
| **Apple Command Line Tools** (default) | Provides `swift` + macOS SDK (`xcode-select --install`) |
| Full Xcode (optional) | 15+ — only if you prefer the `.xcodeproj` / GUI workflow |

Install Command Line Tools:

```bash
xcode-select --install
swift --version   # should print Apple Swift …
```

Optional:

- Full [Xcode](https://developer.apple.com/xcode/) from the Mac App Store (multi‑GB) if you want `xcodebuild` or the GUI
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — regenerates `SightSave.xcodeproj` from `project.yml`

---

## Build from source

### Clone

```bash
git clone https://github.com/miromito/sight_save.git
cd sight_save
```

### Option A — build script (recommended, Command Line Tools)

Uses **Swift Package Manager** by default (`swift build`). No `xcodebuild` required.

```bash
chmod +x scripts/build.sh scripts/install.sh scripts/test-core.sh
./scripts/build.sh
# or build + copy to /Applications + open:
./scripts/install.sh
```

This produces:

- `dist/SightSave.app` — proper bundle (`Contents/MacOS`, `Info.plist` with `LSUIElement`, bundle id `com.rodionlitvinoff.SightSave`, camera usage string), ad-hoc signed (`codesign -s -` + entitlements)
- `dist/SightSave.zip` (unless you set `MAKE_ZIP=0`)

Equivalent manual SwiftPM steps:

```bash
swift build -c release --product SightSaveApp
./scripts/build.sh   # assembles Contents/, codesigns, zips (SwiftPM is the default)
```

Useful env flags for the script:

| Variable | Effect |
|----------|--------|
| `FORCE_SWIFTPM=1` | Always use SwiftPM (default path) |
| `PREFER_XCODEBUILD=1` / `FORCE_XCODEBUILD=1` | Use full Xcode’s `xcodebuild` instead |
| `HARDENED_RUNTIME=1` | Pass `--options runtime` to `codesign` |
| `MAKE_ZIP=0` | Skip zip |

### Option B — xcodebuild (full Xcode)

```bash
PREFER_XCODEBUILD=1 ./scripts/build.sh
```

Or manually:

```bash
xcodebuild \
  -project SightSave.xcodeproj \
  -scheme SightSave \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="-" \
  build

cp -R build/DerivedData/Build/Products/Release/SightSave.app dist/
codesign --force --deep --sign - --entitlements App/SightSave/Resources/SightSave.entitlements dist/SightSave.app
```

### Option C — Xcode GUI

1. Open `SightSave.xcodeproj`.
2. Select the **SightSave** scheme, **My Mac**.
3. Product → Run (or Archive).

### Unit tests (state machine only)

No camera or AppKit required (works with Command Line Tools):

```bash
./scripts/test-core.sh
# or
swift test
```

---

## Install

```bash
cp -R dist/SightSave.app /Applications/
open /Applications/SightSave.app
```

Launch at login can be enabled in **Settings** (uses `SMAppService`). The app should live in `/Applications` for that to work reliably.

---

## First launch & Gatekeeper

The build is **ad-hoc signed** (not notarized). macOS may block it once:

1. **Finder:** right-click `SightSave.app` → **Open** → **Open**.
2. Or **System Settings → Privacy & Security** → scroll to the blocked-app message → **Open Anyway**.
3. Or clear quarantine after download:

```bash
xattr -dr com.apple.quarantine /Applications/SightSave.app
```

---

## Permissions

### Camera

Needed only for **Camera** or **Hybrid** detection modes.

- SightSave prompts on first camera use.
- Usage description is in `Info.plist` (`NSCameraUsageDescription`).
- If denied, the app **falls back to keyboard/mouse mode** and notifies you.

Reset camera permission:

```bash
tccutil reset Camera com.rodionlitvinoff.SightSave
```

### Notifications

Used for break warnings, rest-complete, and call nudges.

- Grant when prompted, or enable under **System Settings → Notifications → SightSave**.

Reset notification permission (macOS may require resetting the whole notifications TCC category depending on version):

```bash
tccutil reset Notifications com.rodionlitvinoff.SightSave
```

If that fails on your macOS version, toggle SightSave off/on under Notifications, or remove the app and reinstall.

---

## Configuration

Open **Settings…** from the menu bar icon.

| Setting | Default | Meaning |
|---------|---------|---------|
| **X — Presence / away threshold** | 2 min | Continuous presence required before work starts; also how long you must be away before rest starts |
| **Y — Work limit** | 50 min | Work time until break warning |
| **Z — Rest duration** | 5 min | Away time needed to complete rest and reset the session |
| **Check interval** | 5 s | How often presence is sampled |
| **Detection mode** | Hybrid | Camera / Keyboard & mouse / Hybrid (input first, camera when idle) |
| **Warning style** | Overlay | macOS notification, or large semi-transparent overlay with Snooze & Dismiss |
| **Snooze length** | 5 min | How long to wait after Snooze before warning again |
| **Rest-done sound** | Glass | System sound + preview button |
| **During calls** | Silent only | Don't disturb / Silent notification only / Normal |
| **Long-call nudge** | 60 min | Optional gentle reminder to stand during long calls |
| **Launch at login** | Off | Register with `SMAppService` |

Settings are stored in **UserDefaults** (no cloud sync).

### Menu bar status examples

- `Work 32:10` — working
- `Over +07:40` — past the limit (overtime)
- `Rest 3:45` — resting
- `Away` — not present
- `Paused` — manually paused
- `Call …` / `Settling` — on a call or still warming up to X

---

## Video call handling

SightSave checks whether the **camera or microphone is already in use** by another app (CoreMediaIO / CoreAudio “device is running somewhere”).

While that is true:

- It **does not** grab camera frames itself.
- It treats you as **present**.
- Break behavior follows **During calls**:
  - **Don't disturb** — no break UI/alerts
  - **Silent notification only** (default) — quiet banner when Y is hit
  - **Normal** — same as when not on a call
- When the call ends and overtime already exists, the **full warning** is shown immediately.
- Optional **long-call nudge** after N minutes suggests standing up.

---

## Sleep & lock

While the Mac is asleep or the screen is locked, timers **pause** and you are treated as **away**.

---

## Troubleshooting

| Problem | What to try |
|---------|-------------|
| App won’t open | Right-click → Open; or `xattr -dr com.apple.quarantine …`; check Privacy & Security |
| No camera detection | Grant Camera permission; or switch to Keyboard & mouse / Hybrid |
| Camera always “busy” | Another app may be holding the camera; SightSave releases the camera after each check |
| No notifications | Enable Notifications for SightSave; re-request via reinstall or `tccutil` |
| Launch at login does nothing | Keep the app in `/Applications`; toggle the setting off/on |
| Menu bar icon missing | Look in the menu bar overflow (`<<`); restart the app |
| Build fails (`swift` missing) | Run `xcode-select --install`, then `swift --version` |
| Build fails (`xcodebuild` missing) | Normal without full Xcode — use `./scripts/build.sh` (SwiftPM). Or install Xcode and set `PREFER_XCODEBUILD=1` |

---

## Uninstall

1. Quit SightSave (menu → Quit).
2. Delete the app: `rm -rf /Applications/SightSave.app`
3. Optional — remove settings: `defaults delete com.rodionlitvinoff.SightSave`
4. Optional — reset TCC entries with `tccutil` as above.
5. Disable launch at login in Settings before quitting, or remove the login item under **System Settings → General → Login Items**.

---

## Project layout

```
Sources/SightSaveCore/   Pure Swift session engine + settings models (unit-tested)
Tests/SightSaveCoreTests/
App/SightSave/           macOS menu bar app (AppKit/SwiftUI, AVFoundation, Vision)
Package.swift            SightSaveCore + SightSave executable (SwiftPM / CLT)
SightSave.xcodeproj/     Optional Xcode project (regenerable via project.yml + XcodeGen)
scripts/build.sh         SwiftPM by default → dist/SightSave.app (+ zip); xcodebuild optional
scripts/install.sh       build.sh + copy to /Applications + open (beginner-friendly)
scripts/test-core.sh     swift test for the core package
```

---

## Contributing

Issues and pull requests are welcome. Prefer small, focused changes. Keep the session engine free of AppKit/AVFoundation so `swift test` stays fast and hermetic. Please do not add network clients, analytics, or third-party SDKs.

---

## Known limitations

- Built and signed **ad-hoc** — not notarized; Gatekeeper requires a one-time bypass.
- Face detection needs decent lighting and a visible face; Hybrid/keyboard modes help when the camera is unreliable.
- Call detection is best-effort via system “device running somewhere” flags; unusual audio routing may false-positive.
- Launch at login via `SMAppService` is most reliable when the app is in `/Applications`.
- The menu bar icon uses an **SF Symbol** (no compiled asset catalog), so the app builds with Command Line Tools alone.
- Linux CI can run `swift test` for `SightSaveCore` but **cannot** link the macOS app; build the `.app` on a Mac.
