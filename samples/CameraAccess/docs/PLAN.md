# headscan — AI Audio Memory Aid for Ray-Ban Meta Glasses

An iOS companion app that streams the camera feed from Ray-Ban Meta (Gen 2)
glasses, recognizes known faces on-device, and whispers an audio cue into the
glasses' open-ear speakers: who the person is, where they are, and what you
should remember about them.

## Confirmed decisions

| Decision | Choice |
|---|---|
| Platform | iOS / Swift (native) |
| Distribution | Open source on GitHub; users build & sideload via Xcode. No App Store, no Meta publishing (avoids facial-recognition policy conflicts) |
| Recognition | Fully on-device. No face data ever leaves the phone |
| Face detection | Apple Vision framework (native — no MediaPipe needed on iOS) |
| Identity matching | Small face-embedding model (MobileFaceNet-class) converted to Core ML; cosine similarity against local profiles |
| TTS | AVSpeechSynthesizer (native) |
| Enrollment | Live capture from the glasses feed; unknown faces ignored otherwise (silent) |
| Announce behavior | Continuous scanning while active; each person announced once, then per-person cooldown (~10–15 min, configurable) |
| Multiple people | All announced, queued sequentially ("John, on your left. Sarah, straight ahead.") |
| Cue content | Name + position only. Full notes spoken on demand ("tell me more") |
| Notes trigger | Glasses gesture if the DAT SDK exposes button/touch events; phone button as guaranteed fallback |
| Distance estimation | **Deferred** — not in v1 (unreliable at 1 fps ultra-wide; backlog item) |
| Profile data | Name, short spoken cue line optional, free-text notes. Stored locally (SwiftData) |

## Architecture

```
Ray-Ban Meta Gen 2
   │  camera stream (~1 fps sampling)          ▲ audio (Bluetooth route /
   ▼                                           │ DAT speaker access)
iPhone app (foreground)                        │
   ├─ StreamManager      — DAT SDK session, frame sampling
   ├─ FaceDetector       — Vision: face rects + landmarks
   ├─ FaceMatcher        — crop/align → Core ML embedding → cosine match
   ├─ PositionLogic      — bbox center X: <0.4 left / >0.6 right / else ahead
   ├─ ProfileStore       — SwiftData: name, cue line, notes, embeddings
   ├─ CueEngine          — cooldown tracking, multi-person queue, cue text
   └─ SpeechOutput       — AVSpeechSynthesizer → glasses speakers
```

Position note: the outward-facing camera is not mirrored — image-left is the
wearer's left, so bbox X maps directly.

Development phases and their completion gates live in [ROADMAP.md](ROADMAP.md).

## Risks & open questions

- **DAT is a developer preview** — APIs may change or break between releases;
  pin the SDK version.
- **Background execution:** iOS will likely require the app foregrounded (or at
  least a live audio session) to keep streaming. Phase 0 must confirm real
  behavior; worst case the phone stays unlocked in a pocket with the app open.
- **Glasses gesture events** may not be exposed at all — phone button fallback
  is planned, not optional.
- **Recognition accuracy:** faces are small in a 12 MP ultra-wide frame at
  conversational distance; may need to crop-and-upscale before embedding. Tune
  with real-world testing, not stock photos.
- **Battery/thermals** on both glasses and phone under continuous streaming —
  measure in Phase 1.

## Tooling recommendations (Claude Code)

- **MCP: XcodeBuildMCP** (`npx xcodebuildmcp`) — the one genuinely useful
  addition: lets Claude build, run on simulator/device, and read build errors
  directly instead of round-tripping through you. Add it when Phase 1 starts.
- **Skills:** the built-in `/verify` and `/code-review` cover this project;
  once the app runs, let `/verify` bootstrap a project-specific verify skill
  (xcodebuild + unit tests). No custom skills needed up front.
- **Subagents:** none needed. The built-in Explore/Plan/general-purpose agents
  cover research (e.g., digging through DAT sample code); a custom Swift agent
  would be premature.
- **Not recommended:** GitHub MCP (you have `gh` CLI), simulator-only MCPs
  (this project needs a physical device + glasses for anything interesting).
