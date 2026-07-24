# headscan — Development Roadmap

See [PLAN.md](PLAN.md) for architecture and confirmed decisions.

Each phase has a **Done when** gate — don't start the next phase until it holds.

### Phase 0 — Access & feasibility spike
- No gated preview — DAT is self-service via the Wearables Developer Center
  (wearables.developer.meta.com): create a developer account, accept the
  Wearables Developer Terms, register a project. Prereqs: iOS 15.2+,
  Xcode 14.0+, supported glasses (Ray-Ban Meta Gen 1/2, Ray-Ban Meta Optics,
  or Meta Ray-Ban Display).
- Update glasses firmware to the minimum version (Meta AI app → Devices →
  Device settings → General → About; cross-check the Version Dependencies
  docs page), then enable developer mode: phone Settings → App Info → tap the
  Meta AI app version number five times → toggle developer mode.
- Add the iOS SDK via SPM (File > Add Package Dependencies →
  github.com/facebook/meta-wearables-dat-ios) and build the sample app from
  its `samples/` directory onto your iPhone, against your glasses.
  The Mock Device Kit can simulate glasses for early development, but Phase 0
  answers must come from real hardware.
- Install Meta's Claude Code plugin for this SDK — gives Claude built-in docs
  on camera streaming, display, permissions, and debugging for the rest of
  this project:
  `claude plugin marketplace add facebook/meta-wearables-dat-ios` then
  `claude plugin install mwdat-ios@mwdat-ios-marketplace`.
- Verify and write down: achievable frame rate/resolution, whether audio can be
  played to the glasses (and via which path — DAT speaker API vs. plain
  Bluetooth audio route), whether any glasses button/gesture events are exposed
  to third-party apps, and foreground/background constraints.
- **Done when:** the sample app streams live camera frames from your glasses to
  your phone, and a `FINDINGS.md` records the answers above.

### Phase 1 — App skeleton + live feed
- New Xcode project in this repo (SwiftUI). Integrate the DAT SDK.
- Connect to glasses, sample the stream at ~1 fps, display frames in-app.
- **Done when:** you can wear the glasses and watch your point of view live in
  the app.

### Phase 2 — Face detection + position logic

#### Phase 2a — `PositionLogic` (pure function, no hardware/UI needed)
- New `Headscan/Logic/PositionLogic.swift`: `enum FacePosition { case left,
  ahead, right }` + `func position(for boundingBox: CGRect) -> FacePosition`
  using bbox center X (<0.4 left / >0.6 right / else ahead), per PLAN.md.
- New `HeadscanTests/PositionLogicTests.swift`: table-test the three buckets
  plus the 0.4/0.6 boundary edge cases.
- **Done when:** `PositionLogicTests` passes.

#### Phase 2b — `FaceDetector` (Vision wrapper)
- New `Headscan/Logic/FaceDetector.swift`: takes a `CGImage`/`UIImage`, runs
  `VNDetectFaceRectanglesRequest` via `VNImageRequestHandler`, returns
  `[CGRect]` (normalized Vision coords — origin is bottom-left, y-flipped
  from UIKit).
- Keep it synchronous/async-simple; measure speed before adding any
  per-frame throttling.
- **Done when:** detector returns correct bounding boxes for a known test
  image (e.g. a photo with a face dropped in `TestResources/`).

#### Phase 2c — Wire detection into `StreamSessionViewModel`
- On each `handleVideoFrame`, after `frame.makeUIImage()`, run
  `FaceDetector` on the frame.
- Add `var detectedFaces: [(rect: CGRect, position: FacePosition)]`
  published state, computed via `PositionLogic.position(for:)` on each
  detected rect.
- **Done when:** `detectedFaces` populates correctly while streaming from
  real glasses (verify via debug print/logging — no UI yet).

#### Phase 2d — Render boxes in `StreamView`
- **This must be visible live in the running app**, not just internal state,
  so the detection can be visually confirmed working while wearing the
  glasses.
- Overlay a `ForEach` of `Rectangle().stroke()` + `Text(position)` on top of
  the existing `Image`, converting Vision's normalized/flipped coords into
  the image's displayed on-screen frame (accounting for the aspect-fit
  letterboxing already in `StreamView`).
- **Done when:** faces in the live feed get boxes labeled with position,
  visible on-screen while streaming from real glasses.

### Phase 3 — Enrollment + recognition
- Pick and convert an embedding model to Core ML (MobileFaceNet or similar
  permissively licensed model); record the choice + license in the README.
- Enrollment flow: freeze the last detected face from the live feed → assign
  name, optional cue line, notes → store embedding(s) in SwiftData. Capture
  2–3 samples per person for robustness.
- Matching: cosine similarity with a tuned threshold; below threshold = unknown
  = silent.
- **Done when:** an enrolled person is correctly named in the live feed, and a
  non-enrolled face is not.

### Phase 4 — Audio cues (end-to-end v1)
- CueEngine: per-person cooldown, sequential queue for multiple matches.
- AVSpeechSynthesizer output routed to the glasses; quiet, short utterances.
- **Done when:** wearing the glasses, walking up to an enrolled person produces
  "«Name», on your left" in your ears within a couple of seconds, once, and not
  again during cooldown.

### Phase 5 — "Tell me more" + release polish
- Notes-on-demand trigger: glasses gesture if Phase 0 confirmed events are
  exposed; otherwise a large in-app button (build the button regardless, as
  fallback). Speaks the full notes of the most recently announced person.
- Settings: cooldown duration, speech rate/volume, scan on/off toggle.
- README: setup guide (DAT enrollment, sideloading), model license, and a
  clear responsible-use / legal notice (biometric privacy laws — e.g. BIPA,
  GDPR — vary by region; users are responsible for compliance and consent).
- **Done when:** a stranger with an iPhone, glasses, and the README can build,
  sideload, enroll a friend, and get working cues.

### Backlog (post-v1, in rough order)
- Distance estimation (coarse near/far buckets from face size).
- Voice-command trigger ("tell me more" via glasses mic).
- On-the-spot voice dictation of notes after meeting someone.
- Android/Kotlin port.
