import AVFAudio
import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class WorkoutController {
  enum Screen {
    case setup, running, paused, finished
  }

  var configuration: WorkoutConfiguration
  private(set) var screen: Screen = .setup
  private(set) var elapsed: TimeInterval = 0
  private(set) var timeline: WorkoutTimeline
  var errorMessage: String?
  var interruptionMessage: String?

  @ObservationIgnored private let defaults: UserDefaults
  @ObservationIgnored private let audio = WorkoutAudio()
  @ObservationIgnored private var clockStartedAt: TimeInterval = 0
  @ObservationIgnored private var clockOffset: TimeInterval = 0

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    let configuration = WorkoutConfiguration.load(from: defaults)
    self.configuration = configuration
    timeline = WorkoutTimeline(configuration: configuration)
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
        self.configuration = WorkoutConfiguration(
          rounds: 2, roundSeconds: 5, restSeconds: 5, preparationSeconds: 3)
      }
    #endif
  }

  var interval: WorkoutInterval? { timeline.interval(at: elapsed) }
  var remaining: Int { timeline.secondsRemaining(at: elapsed) }
  var isWorkoutVisible: Bool { screen == .running || screen == .paused }
  var round: Int { interval?.round ?? timeline.configuration.rounds }
  var completedRounds: Int {
    guard let interval else { return timeline.configuration.rounds }
    return interval.phase == .rest ? interval.round : max(0, interval.round - 1)
  }

  func start() {
    configuration = configuration.validated
    configuration.save(to: defaults)
    timeline = WorkoutTimeline(configuration: configuration)
    elapsed = 0
    interruptionMessage = nil
    beginPlayback()
  }

  func resume() {
    guard screen == .paused else { return }
    interruptionMessage = nil
    beginPlayback()
  }

  private func beginPlayback() {
    do {
      try audio.start(timeline: timeline, from: elapsed)
      clockOffset = elapsed
      clockStartedAt = ProcessInfo.processInfo.systemUptime
      screen = .running
      UIApplication.shared.isIdleTimerDisabled = true
    } catch {
      audio.stop()
      UIApplication.shared.isIdleTimerDisabled = false
      errorMessage = "Audio could not start. Check your audio output and try again."
    }
  }

  func refresh() {
    guard screen == .running else { return }
    let audioTime = audio.elapsed
    // The monotonic fallback covers the short delay before the first audio render.
    elapsed = min(
      Double(timeline.configuration.totalSeconds),
      max(
        elapsed, audioTime ?? (clockOffset + ProcessInfo.processInfo.systemUptime - clockStartedAt))
    )
    if elapsed >= Double(timeline.configuration.totalSeconds) {
      screen = .finished
      UIApplication.shared.isIdleTimerDisabled = false
    }
  }

  func pause(reason: String? = nil) {
    guard screen == .running else { return }
    refresh()
    guard screen == .running else { return }
    screen = .paused
    interruptionMessage = reason
    audio.pause()
    UIApplication.shared.isIdleTimerDisabled = false
  }

  func end() {
    audio.stop()
    elapsed = 0
    screen = .setup
    interruptionMessage = nil
    UIApplication.shared.isIdleTimerDisabled = false
  }

  func previewBell() {
    do {
      try audio.previewBell()
    } catch {
      audio.stop()
      errorMessage = "Audio could not start. Check your audio output and try again."
    }
  }

  func handleInterruption(_ notification: Notification) {
    guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: rawType), type == .began
    else { return }
    pause(reason: "Audio was interrupted. Resume when you’re ready.")
  }

  func handleRouteChange(_ notification: Notification) {
    guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
      let reason = AVAudioSession.RouteChangeReason(rawValue: rawReason),
      reason == .oldDeviceUnavailable
    else { return }
    pause(reason: "Audio output disconnected. Check your output before resuming.")
  }

  func handleEngineChange() {
    guard !audio.isRunning else { return }
    pause(reason: "Audio output changed. Resume when you’re ready.")
  }
}
