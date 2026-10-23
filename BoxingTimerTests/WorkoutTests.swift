import Foundation
import Testing

@testable import BoxingTimer

struct WorkoutTests {
  @Test func fullTimelineHasPreparationAndNoFinalRest() {
    let timeline = WorkoutTimeline(configuration: WorkoutConfiguration())
    #expect(timeline.intervals.count == 12)
    #expect(timeline.configuration.totalSeconds == 1390)
    #expect(timeline.intervals.last?.phase == .round)
    #expect(timeline.intervals.last?.round == 6)
    #expect(timeline.interval(at: 9.99)?.phase == .preparation)
    #expect(timeline.interval(at: 10)?.phase == .round)
    #expect(timeline.interval(at: 190)?.phase == .rest)
    #expect(timeline.interval(at: 250)?.round == 2)
    #expect(timeline.interval(at: 1390) == nil)
  }

  @Test func clockCatchesUpAcrossMultipleIntervals() {
    let timeline = WorkoutTimeline(configuration: WorkoutConfiguration())
    #expect(timeline.interval(at: 732)?.round == 4)
    #expect(timeline.interval(at: 732)?.phase == .round)
    #expect(timeline.secondsRemaining(at: 732) == 178)
    #expect(timeline.secondsRemaining(at: 10.01) == 180)
    #expect(timeline.secondsRemaining(at: 11) == 179)
    #expect(timeline.secondsRemaining(at: 1390) == 0)
  }

  @Test func oneRoundWithoutPreparationOrRest() {
    let configuration = WorkoutConfiguration(
      rounds: 1, roundSeconds: 5, restSeconds: 0, preparationSeconds: 0)
    let timeline = WorkoutTimeline(configuration: configuration)
    #expect(timeline.intervals.count == 1)
    #expect(timeline.interval(at: 0)?.phase == .round)
    #expect(timeline.secondsRemaining(at: 0) == 5)
    #expect(timeline.interval(at: 5) == nil)
    #expect(configuration.totalRestSeconds == 0)
  }

  @Test func zeroRestMovesStraightToNextRound() {
    let timeline = WorkoutTimeline(
      configuration: WorkoutConfiguration(
        rounds: 3, roundSeconds: 5, restSeconds: 0, preparationSeconds: 0))
    #expect(timeline.intervals.count == 3)
    #expect(timeline.interval(at: 5)?.round == 2)
    #expect(timeline.interval(at: 10)?.round == 3)
    #expect(timeline.interval(at: 15) == nil)
  }

  @Test func savedConfigurationIsValidated() throws {
    let name = "WorkoutTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let configuration = WorkoutConfiguration(
      rounds: 8, roundSeconds: 120, restSeconds: 30, preparationSeconds: 5)
    configuration.save(to: defaults)
    #expect(WorkoutConfiguration.load(from: defaults) == configuration)
    let invalid = WorkoutConfiguration(
      rounds: 0, roundSeconds: -5, restSeconds: -1, preparationSeconds: 100)
    defaults.set(try JSONEncoder().encode(invalid), forKey: "workoutConfiguration")
    #expect(
      WorkoutConfiguration.load(from: defaults)
        == WorkoutConfiguration(rounds: 1, roundSeconds: 5, restSeconds: 0, preparationSeconds: 60))
    defaults.set(Data("broken".utf8), forKey: "workoutConfiguration")
    #expect(WorkoutConfiguration.load(from: defaults) == WorkoutConfiguration())
  }

  @Test func cuesAreOrderedAndSkipElapsedEventsOnResume() {
    let timeline = WorkoutTimeline(configuration: WorkoutConfiguration())
    #expect(
      Array(timeline.cues.prefix(4)) == [
        WorkoutCue(time: 7, sound: .countdown),
        WorkoutCue(time: 8, sound: .countdown),
        WorkoutCue(time: 9, sound: .countdown),
        WorkoutCue(time: 10, sound: .bell),
      ])
    #expect(timeline.cues.last == WorkoutCue(time: 1390, sound: .bell))
    let future = timeline.cues.filter { $0.time >= 248.5 }
    #expect(future.first == WorkoutCue(time: 249, sound: .countdown))
    #expect(future.dropFirst().first == WorkoutCue(time: 250, sound: .bell))
  }

  @Test func durationFormatting() {
    #expect(durationText(5) == "00:05")
    #expect(durationText(180) == "03:00")
    #expect(shortDurationText(1080) == "18:00")
  }
}
