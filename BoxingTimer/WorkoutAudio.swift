import AVFAudio
import Foundation

/// The audio player owns the workout clock. Cues are scheduled before playback starts,
/// so their timing does not depend on foreground UI refreshes or background timers.
@MainActor
final class WorkoutAudio {
  private let engine = AVAudioEngine()
  private let player = AVAudioPlayerNode()
  private let roundEndPlayer = AVAudioPlayerNode()
  private let countdownPlayer = AVAudioPlayerNode()
  private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
  private var buffers: [AVAudioPCMBuffer] = []
  private var offset: TimeInterval = 0
  private var playbackID = UUID()
  private(set) var isPrepared = false

  private var players: [AVAudioPlayerNode] { [player, roundEndPlayer, countdownPlayer] }

  init() {
    for node in players {
      engine.attach(node)
      engine.connect(node, to: engine.mainMixerNode, format: format)
    }
  }

  var isRunning: Bool { engine.isRunning && player.isPlaying }

  var elapsed: TimeInterval? {
    guard let renderTime = player.lastRenderTime,
      let time = player.playerTime(forNodeTime: renderTime), time.isSampleTimeValid
    else { return nil }
    return offset + max(0, Double(time.sampleTime) / time.sampleRate)
  }

  func start(timeline: WorkoutTimeline, from elapsed: TimeInterval = 0) throws {
    stop()
    offset = elapsed
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
    try session.setActive(true)

    let bell = try loadBell()
    let roundEndBell = makeDoubleBell(bell, spacing: 0.25)
    let workoutEndBell = makeDoubleBell(bell, spacing: 0.8)
    let beep = makeCountdownBeep()
    buffers = [bell, roundEndBell, workoutEndBell, beep]
    for cue in timeline.cues where cue.time >= elapsed {
      let time = cue.time - elapsed
      switch cue.sound {
      case .roundStart:
        schedule(bell, at: time, on: player)
      case .roundEnd:
        schedule(roundEndBell, at: time, on: roundEndPlayer)
      case .workoutEnd:
        scheduleFinalBell(workoutEndBell, at: time, on: roundEndPlayer)
      case .countdown:
        schedule(beep, at: time, on: countdownPlayer)
      }
    }
    engine.prepare()
    try engine.start()
    // Use the same render start for each voice so overlapping cues stay on the workout clock.
    let startTime = AVAudioTime(
      hostTime: mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.02))
    for node in players {
      node.play(at: startTime)
    }
    isPrepared = true
  }

  func previewBell() throws {
    stop()
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.playback, mode: .default, options: .mixWithOthers)
    try session.setActive(true)
    let bell = try loadBell()
    buffers = [bell]
    scheduleFinalBell(bell, at: 0, on: player)
    engine.prepare()
    try engine.start()
    player.play()
  }

  func pause() {
    for node in players { node.pause() }
    engine.pause()
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  func stop() {
    playbackID = UUID()
    for node in players { node.stop() }
    engine.stop()
    buffers.removeAll()
    isPrepared = false
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
  }

  private func schedule(
    _ buffer: AVAudioPCMBuffer, at seconds: TimeInterval, on node: AVAudioPlayerNode
  ) {
    node.scheduleBuffer(
      buffer,
      at: AVAudioTime(
        sampleTime: AVAudioFramePosition(seconds * format.sampleRate), atRate: format.sampleRate)
    )
  }

  private func scheduleFinalBell(
    _ buffer: AVAudioPCMBuffer, at seconds: TimeInterval, on node: AVAudioPlayerNode
  ) {
    let id = playbackID
    node.scheduleBuffer(
      buffer,
      at: AVAudioTime(
        sampleTime: AVAudioFramePosition(seconds * format.sampleRate), atRate: format.sampleRate),
      options: [], completionCallbackType: .dataPlayedBack
    ) { [weak self] _ in
      Task { @MainActor in
        guard let self, self.playbackID == id else { return }
        // Release background audio even if the UI is asleep when the session ends.
        self.stop()
      }
    }
  }

  private func loadBell() throws -> AVAudioPCMBuffer {
    guard let url = Bundle.main.url(forResource: "boxing-bell", withExtension: "wav") else {
      throw CocoaError(.fileNoSuchFile)
    }
    let file = try AVAudioFile(forReading: url)
    let buffer = AVAudioPCMBuffer(
      pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))!
    try file.read(into: buffer)
    return buffer
  }

  private func makeDoubleBell(
    _ bell: AVAudioPCMBuffer, spacing: TimeInterval
  ) -> AVAudioPCMBuffer {
    let delay = Int(spacing * format.sampleRate)
    let count = Int(bell.frameLength) + delay
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count))!
    buffer.frameLength = AVAudioFrameCount(count)
    let output = buffer.floatChannelData![0]
    let input = bell.floatChannelData![0]
    output.initialize(repeating: 0, count: count)
    for index in 0..<Int(bell.frameLength) {
      output[index] += input[index]
      output[index + delay] += input[index]
    }
    // Preserve both decays without clipping where the strikes overlap.
    var peak: Float = 1
    for index in 0..<count { peak = max(peak, abs(output[index])) }
    if peak > 1 {
      for index in 0..<count { output[index] /= peak }
    }
    return buffer
  }

  private func makeCountdownBeep() -> AVAudioPCMBuffer {
    let duration = 0.12
    let count = AVAudioFrameCount(duration * format.sampleRate)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
    buffer.frameLength = count
    let samples = buffer.floatChannelData![0]
    for index in 0..<Int(count) {
      let time = Double(index) / format.sampleRate
      let attack = min(1, time / 0.003)
      let value = sin(2 * .pi * 880 * time) * 0.25 * min(1, (duration - time) / 0.02)
      samples[index] = Float(value * attack)
    }
    return buffer
  }
}
