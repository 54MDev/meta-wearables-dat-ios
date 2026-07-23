# Phase 0 — Findings

## Access & setup
- Wearables Developer Center account, terms acceptance, project registration: confirmed working.
- Glasses firmware updated to minimum version, developer mode enabled: confirmed.
- CameraAccess sample builds via Xcode and installs on-device.
- Connects to Ray-Ban Meta glasses and streams camera frames successfully.

## Frame rate / resolution
- Sample app had no on-screen readout — couldn't read fps/resolution off the stream by eye.
- Added a debug overlay (`StreamSessionViewModel.streamStats`, rendered in `StreamView`)
  that shows actual pixel resolution and a smoothed fps counter live in the top-left
  corner while streaming.
- **Confirmed on real glasses: 360x640, ~25–30 fps** (jumps between 25 and 30, doesn't
  hold steady). Requested config was `StreamingResolution.low` @ 24 fps
  (`StreamSessionViewModel.startSession`) — actual delivered rate runs a bit above the
  requested 24, so treat the config value as a floor/hint, not a guarantee.
- Plenty for Phase 2 face detection at conversational distance; no need to request a
  higher `StreamingResolution` tier for v1.

## Audio to glasses
- The DAT SDK (v0.8.0) ships exactly four modules: `MWDATCore`, `MWDATCamera`,
  `MWDATDisplay`, `MWDATMockDevice`. There is no speaker/audio-output capability.
- **Answer: no DAT speaker API exists.** Audio to the glasses must go through the plain
  Bluetooth audio route (glasses as a standard Bluetooth output device), not through DAT.

## Glasses button/gesture events
- No touch/gesture/button input capability is exposed anywhere in the SDK's four modules.
  `MWDATDisplay`'s `Button`/`onTap` are for UI *rendered by the app onto the glasses
  display*, not physical gesture input from the wearer.
- **Answer: no glasses button/gesture events are exposed to third-party apps.** The
  in-app phone button (already planned as the guaranteed fallback in PLAN.md) is
  required, not optional.

## Foreground/background constraints
- **Confirmed: backgrounding kills the stream.** On backgrounding and returning, the app
  shows "Critical error, stream should end" (this is `StreamError.localizedDescription`
  surfaced by `StreamSessionViewModel.handleError`, not app-written text).
- Root cause, found by `strings`-ing `MWDATCamera.framework`: the SDK logs
  `[SGSX][Session] Media stream service stopped due to critical error, not retrying
  after stopping.` — the SDK itself tears the stream down on backgrounding and
  deliberately does **not** auto-resume. `UIBackgroundModes` in Info.plist doesn't
  override this; it's enforced inside the SDK's session service, not iOS.
- The missing "session end" chime on the glasses is a separate, known SDK gap — the
  plugin's debugging skill already documents a sibling bug ("no audio feedback on
  pause/resume, will be fixed in future release"). Not an app bug; nothing to build
  around.
- **Practical implication:** continuous background scanning (PLAN.md's "continuous
  scanning while active") is not achievable as designed — the app must stay
  foregrounded and the phone unlocked while worn. PLAN.md's noted worst case ("phone
  stays unlocked in a pocket with the app open") is the only viable mode, not a
  fallback.

## Battery / thermal usage ceiling
- **Measured:** 6% drain (100% → 94%) over 5 min 30 s of continuous DAT camera
  streaming. Linear extrapolation: ~1.1%/min → **~90 minutes of continuous streaming
  on a full charge**, if drain stayed linear (it likely doesn't — see below).
- Meta's official Gen 2 rating is 8 hours, but that's mixed/idle use. The closest
  official analog to continuous-camera-on use is Live AI mode, which multiple reviews
  report caps out around **30 minutes continuous** on a full charge — tighter than our
  linear extrapolation, likely because Live AI also runs on-glasses AI inference on top
  of the camera draw. Our workload (camera out, no on-glasses AI) should sit somewhere
  between the ~30 min Live AI figure and the ~90 min linear extrapolation.
- Real-world reviewer testing (mixed 3K video clips + AI queries + music) measured
  ~20%/hour — a much lighter duty cycle than continuous streaming, not directly
  comparable, but consistent with continuous streaming draining faster than that.
- **Thermal ceiling matters independently of battery %:** community forum reports
  describe glasses becoming uncomfortably hot and shutting down during sustained
  camera-heavy use (livestreaming, Live AI), sometimes before the battery is depleted.
  Battery percentage alone is not a reliable predictor of remaining safe runtime.
- **Recommendation for the app:** don't design v1 around long unattended continuous-scan
  sessions. Budget for a real-world safe ceiling well under the ~90 min linear estimate
  — treat ~30 min as the conservative planning number (matching Live AI's observed
  cap) until we've measured our own thermal/battery curve over a full session on
  hardware.

## Done when (Phase 0 gate)
- [x] Sample app streams live camera frames from glasses to phone.
- [x] All findings above recorded.
