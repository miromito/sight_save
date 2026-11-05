# SightSave

A lightweight native **macOS menu bar** app that protects your eyes and lower back. It notices when you are sitting at the computer, times your work session, and reminds you to take breaks.

**Bundle identifier:** `com.rodionlitvinoff.SightSave`  
**Requirements:** macOS 13 Ventura or later · Apple Silicon or Intel  
**License:** MIT © 2026 Rodion Litvinoff

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

| Item | Version |
|------|---------|
| macOS | 13.0+ (to run); build on macOS 13+ recommended |
| Xcode | 15 or later (includes Swift 5.9+) |
| Command Line Tools | Matching your Xcode (`xcode-select -p` should point at Xcode) |

Optional:

- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — regenerates `SightSave.xcodeproj` from `project.yml` (a project file is already committed).

Install Xcode from the Mac App Store, then:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept   # if prompted
```

---

## Build from source

### Clone

```bash
git clone https://github.com/miromito/sight_save.git
cd sight_save
```

### Option A — build script (recommended)

```bash
chmod +x scripts/build.sh scripts/test-core.sh
./scripts/build.sh
```

This produces:

- `dist/SightSave.app` (ad-hoc signed with `codesign -s -`)
- `dist/SightSave.zip` (unless you set `MAKE_ZIP=0`)

### Option B — xcodebuild directly

```bash
xcodebuild \
  -project SightSave.xcodeproj \
  -scheme SightSave \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  -destination "generic/platform=macOS" \
  CODE_SIGN_IDENTITY="-" \
  build

# Copy & ad-hoc sign
cp -R build/DerivedData/Build/Products/Release/SightSave.app dist/
codesign --force --deep --sign - dist/SightSave.app
```

### Option C — Xcode GUI

1. Open `SightSave.xcodeproj`.
2. Select the **SightSave** scheme, **My Mac**.
3. Product → Run (or Archive).

### Unit tests (state machine only)

No camera or AppKit required:

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
| Build fails | Ensure Xcode CLT point at full Xcode: `xcode-select -p` |

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
SightSave.xcodeproj/     Xcode project (also regenerable via project.yml + XcodeGen)
scripts/build.sh         Produces dist/SightSave.app (+ zip)
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
- This repository’s CI environment is Linux and **cannot compile the macOS app binary**; build on a Mac with Xcode.
