# Headscan

An iOS companion app that streams the camera feed from Ray-Ban Meta glasses,
recognizes known faces on-device, and whispers an audio cue into the glasses'
open-ear speakers: who the person is, where they are, and what you should
remember about them.

See [docs/PLAN.md](docs/PLAN.md) for architecture and confirmed decisions,
[docs/ROADMAP.md](docs/ROADMAP.md) for development phases, and
[docs/FINDINGS.md](docs/FINDINGS.md) for Phase 0 hardware findings.

## Status

Phase 1 (app skeleton + live feed): connects to glasses, streams the camera,
displays ~1 fps sampled frames live in the app. Face recognition and audio
cues land in later phases.

## Prerequisites

- iOS 17.0+
- Xcode 16.0+
- Swift 5.0+
- Meta Wearables Device Access Toolkit (included as an SPM dependency)
- A Meta AI glasses device (Ray-Ban Meta Gen 1/2, Ray-Ban Meta Optics, or
  Meta Ray-Ban Display) — the DAT stream doesn't work over MockDeviceKit alone
  for the "watch it live" gate, real hardware is required

## Building the app

1. Open `Headscan.xcodeproj` in Xcode.
2. Register a **new** project for `com.cherry.headscan` in the
   [Wearables Developer Center](https://wearables.developer.meta.com/) — this
   is a separate registration from the CameraAccess sample's, since DAT ties
   registration to the app's bundle ID / URL scheme.
3. Select your target device, build (`Cmd+B`), run (`Cmd+R`).

## Running the app

1. Turn on Developer Mode in the Meta AI app.
2. Launch Headscan, tap "Connect my glasses" to complete registration.
3. Once a device is active, tap "Start streaming" to watch your glasses'
   point of view live in the app.

## Troubleshooting

For DAT SDK issues, see the [developer documentation](https://wearables.developer.meta.com/docs/develop/)
or the [discussions forum](https://github.com/facebook/meta-wearables-dat-ios/discussions).
