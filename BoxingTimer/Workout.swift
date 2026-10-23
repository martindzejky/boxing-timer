import Foundation

struct WorkoutConfiguration: Equatable, Codable {
  var rounds = 6
  var roundSeconds = 180
  var restSeconds = 60
  var preparationSeconds = 10

  var workSeconds: Int { rounds * roundSeconds }
  var totalRestSeconds: Int { max(0, rounds - 1) * restSeconds }
  var totalSeconds: Int { preparationSeconds + workSeconds + totalRestSeconds }

  static func load(from defaults: UserDefaults = .standard) -> Self {
    guard let data = defaults.data(forKey: "workoutConfiguration"),
      let saved = try? JSONDecoder().decode(Self.self, from: data)
    else { return Self() }
    return saved.validated
  }

  var validated: Self {
    Self(
      rounds: min(30, max(1, rounds)),
      roundSeconds: min(900, max(5, roundSeconds)),
      restSeconds: min(600, max(0, restSeconds)),
      preparationSeconds: min(60, max(0, preparationSeconds))
    )
  }

  func save(to defaults: UserDefaults = .standard) {
    if let data = try? JSONEncoder().encode(validated) {
      defaults.set(data, forKey: "workoutConfiguration")
    }
  }
}

enum WorkoutPhase: Equatable {
  case preparation
  case round
  case rest
}

struct WorkoutInterval: Equatable {
  let phase: WorkoutPhase
  let round: Int
  let start: TimeInterval
  let duration: Int

  var end: TimeInterval { start + Double(duration) }
}

struct WorkoutCue: Equatable {
  enum Sound { case bell, countdown }
  let time: TimeInterval
  let sound: Sound
}

struct WorkoutTimeline {
  let configuration: WorkoutConfiguration
  let intervals: [WorkoutInterval]

  init(configuration: WorkoutConfiguration) {
    self.configuration = configuration
    var intervals: [WorkoutInterval] = []
    var start: TimeInterval = 0
    if configuration.preparationSeconds > 0 {
      intervals.append(
        WorkoutInterval(
          phase: .preparation, round: 1, start: start,
          duration: configuration.preparationSeconds))
      start += Double(configuration.preparationSeconds)
    }
    for round in 1...configuration.rounds {
      intervals.append(
        WorkoutInterval(
          phase: .round, round: round, start: start, duration: configuration.roundSeconds))
      start += Double(configuration.roundSeconds)
      if round < configuration.rounds && configuration.restSeconds > 0 {
        intervals.append(
          WorkoutInterval(
            phase: .rest, round: round, start: start, duration: configuration.restSeconds))
        start += Double(configuration.restSeconds)
      }
    }
    self.intervals = intervals
  }

  var cues: [WorkoutCue] {
    var result: [WorkoutCue] = []
    for interval in intervals {
      if interval.phase != .preparation {
        result.append(WorkoutCue(time: interval.start, sound: .bell))
      }
      if interval.phase == .preparation || interval.phase == .rest {
        for remaining in 1...3 where remaining <= interval.duration {
          result.append(WorkoutCue(time: interval.end - Double(remaining), sound: .countdown))
        }
      }
    }
    result.append(WorkoutCue(time: Double(configuration.totalSeconds), sound: .bell))
    return result.sorted { $0.time < $1.time }
  }

  func interval(at elapsed: TimeInterval) -> WorkoutInterval? {
    intervals.first { elapsed >= $0.start && elapsed < $0.end }
  }

  func secondsRemaining(at elapsed: TimeInterval) -> Int {
    guard let interval = interval(at: elapsed) else { return 0 }
    return max(0, Int(ceil(interval.end - elapsed)))
  }
}

func durationText(_ seconds: Int) -> String {
  String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

func shortDurationText(_ seconds: Int) -> String {
  String(format: "%d:%02d", seconds / 60, seconds % 60)
}
