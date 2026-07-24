import MWDATCamera
import MWDATCore
import Observation
import QuartzCore
import SwiftUI

enum StreamingStatus {
  case streaming
  case waiting
  case stopped
}

/// Stream request settings. 7fps keeps facial recognition workable while
/// leaving BLE headroom for .high resolution instead of .low.
private let streamResolution = StreamingResolution.high
private let streamFrameRate: UInt = 7

/// Window over which the two debug FPS counters are averaged.
private let fpsWindowInterval: CFTimeInterval = 1.0

/// ViewModel for video streaming UI. Delegates device management to DeviceSessionManager.
@Observable
@MainActor
final class StreamSessionViewModel {
  // MARK: - State

  var currentVideoFrame: UIImage?
  var hasReceivedFirstFrame: Bool = false
  var streamingStatus: StreamingStatus = .stopped
  var showError: Bool = false
  var errorMessage: String = ""
  var requiresDATAppUpdate: Bool = false

  var hasActiveDevice: Bool { sessionManager.hasActiveDevice }
  var isDeviceSessionReady: Bool { sessionManager.isReady }

  var isStreaming: Bool { streamingStatus != .stopped }

  /// e.g. "720x1280" — the resolution requested in `StreamConfiguration`.
  var qualityLabel: String {
    let size = streamResolution.videoFrameSize
    return "\(size.width)x\(size.height)"
  }

  /// Frames/sec arriving from the glasses over BLE (pre-display-throttle).
  var glassesFPS: Int = 0
  /// Frames/sec actually rendered to the screen.
  var displayFPS: Int = 0

  // MARK: - Private

  private let sessionManager: DeviceSessionManager
  private let wearables: WearablesInterface
  private var stream: MWDATCamera.Stream?

  private var glassesFrameCount = 0
  private var displayFrameCount = 0
  private var fpsWindowStart: CFTimeInterval?

  private var stateListenerToken: AnyListenerToken?
  private var videoFrameListenerToken: AnyListenerToken?
  private var errorListenerToken: AnyListenerToken?

  // MARK: - Init

  init(wearables: WearablesInterface) {
    self.wearables = wearables
    self.sessionManager = DeviceSessionManager(wearables: wearables)
  }

  // MARK: - Public API

  func handleStartStreaming() async {
    let permission = Permission.camera
    do {
      var status = try await wearables.checkPermissionStatus(permission)
      if status != .granted {
        status = try await wearables.requestPermission(permission)
      }
      guard status == .granted else {
        showError("Permission denied")
        return
      }
      await startSession()
    } catch {
      // Use `localizedDescription` for user-facing text — `description` is
      // always English and intended for logs.
      showError("Permission error: \(error.localizedDescription)")
    }
  }

  func stopSession() {
    stream?.stop()
  }

  /// Stops both the stream and the underlying device session. Call in test tearDown.
  func endSession() {
    stream = nil
    clearListeners()
    streamingStatus = .stopped
    currentVideoFrame = nil
    hasReceivedFirstFrame = false
    resetFPSCounters()
    sessionManager.cleanup()
  }

  func dismissError() {
    showError = false
    errorMessage = ""
  }

  // MARK: - Private

  private func startSession() async {
    let deviceSession: DeviceSession
    do {
      deviceSession = try await sessionManager.getSession()
      requiresDATAppUpdate = false
    } catch DeviceSessionError.datAppOnTheGlassesUpdateRequired {
      requiresDATAppUpdate = true
      showError(DeviceSessionError.datAppOnTheGlassesUpdateRequired.localizedDescription)
      return
    } catch {
      showError("Failed to start session: \(error.localizedDescription)")
      return
    }

    guard deviceSession.state == .started else {
      showError("Device session is not ready. Please try again.")
      return
    }

    let config = StreamConfiguration(
      videoCodec: VideoCodec.raw,
      resolution: streamResolution,
      frameRate: streamFrameRate
    )

    do {
      guard let newStream = try deviceSession.addStream(config: config) else {
        showError("Unable to create stream. Please try again.")
        return
      }
      stream = newStream
      streamingStatus = .waiting
      setupListeners(for: newStream)
      newStream.start()
    } catch {
      showError("Failed to start stream: \(error.localizedDescription)")
    }
  }

  private func setupListeners(for stream: MWDATCamera.Stream) {
    stateListenerToken = stream.statePublisher.listen { [weak self] state in
      Task { @MainActor in self?.handleStateChange(state) }
    }

    videoFrameListenerToken = stream.videoFramePublisher.listen { [weak self] frame in
      Task { @MainActor in self?.handleVideoFrame(frame) }
    }

    errorListenerToken = stream.errorPublisher.listen { [weak self] error in
      Task { @MainActor in self?.handleError(error) }
    }
  }

  private func clearListeners() {
    stateListenerToken = nil
    videoFrameListenerToken = nil
    errorListenerToken = nil
  }

  private func handleStateChange(_ state: StreamState) {
    switch state {
    case .stopped:
      currentVideoFrame = nil
      streamingStatus = .stopped
      stream = nil
      clearListeners()
      hasReceivedFirstFrame = false
      resetFPSCounters()
      sessionManager.stopCurrentSession()
    case .waitingForDevice, .starting, .stopping, .paused:
      streamingStatus = .waiting
    case .streaming:
      streamingStatus = .streaming
    }
  }

  private func handleVideoFrame(_ frame: VideoFrame) {
    let now = CACurrentMediaTime()
    glassesFrameCount += 1

    guard let image = frame.makeUIImage() else {
      updateFPSCounters(now: now)
      return
    }
    displayFrameCount += 1
    currentVideoFrame = image
    hasReceivedFirstFrame = true
    updateFPSCounters(now: now)
  }

  private func updateFPSCounters(now: CFTimeInterval) {
    guard let windowStart = fpsWindowStart else {
      fpsWindowStart = now
      return
    }
    let elapsed = now - windowStart
    guard elapsed >= fpsWindowInterval else { return }
    glassesFPS = Int((Double(glassesFrameCount) / elapsed).rounded())
    displayFPS = Int((Double(displayFrameCount) / elapsed).rounded())
    glassesFrameCount = 0
    displayFrameCount = 0
    fpsWindowStart = now
  }

  private func resetFPSCounters() {
    glassesFrameCount = 0
    displayFrameCount = 0
    fpsWindowStart = nil
    glassesFPS = 0
    displayFPS = 0
  }

  private func handleError(_ error: StreamError) {
    let message = error.localizedDescription
    if message != errorMessage {
      showError(message)
    }
  }

  private func showError(_ message: String) {
    errorMessage = message
    showError = true
  }
}
