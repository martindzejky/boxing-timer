import AVFAudio
import SwiftUI

struct ContentView: View {
  @State private var workout = WorkoutController()
  @State private var showingSettings = false
  @State private var confirmingEnd = false
  @Environment(\.scenePhase) private var scenePhase

  private var isActiveRound: Bool {
    workout.screen == .running && workout.interval?.phase == .round
  }

  private var background: Color { isActiveRound ? TimerStyle.red : TimerStyle.background }
  private var foreground: Color { isActiveRound ? TimerStyle.background : .white }
  private var accent: Color { isActiveRound ? TimerStyle.background : TimerStyle.red }
  private var muted: Color { isActiveRound ? TimerStyle.background : TimerStyle.muted }

  var body: some View {
    GeometryReader { geometry in
      let compact = geometry.size.height < 600
      VStack(spacing: 0) {
        HStack {
          Spacer()
          if workout.screen != .finished {
            Button {
              workout.pause()
              showingSettings = true
            } label: {
              Image(systemName: "gearshape")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(muted)
                .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Settings")
          }
        }
        .frame(height: compact ? 36 : 44)
        switch workout.screen {
        case .setup:
          SetupView(configuration: $workout.configuration, compact: compact)
        case .running, .paused:
          timerScreen(width: geometry.size.width - 48, compact: compact)
        case .finished:
          finishedScreen(compact: compact)
        }
      }
      .padding(.horizontal, 24)
      .safeAreaInset(edge: .bottom, spacing: 0) {
        controls
          .padding(.horizontal, 24)
          .padding(.top, 16)
          .padding(.bottom, 14)
          .background(background)
      }
    }
    .background(background.ignoresSafeArea())
    .preferredColorScheme(isActiveRound ? .light : .dark)
    .sheet(isPresented: $showingSettings) {
      settingsSheet
    }
    .alert("End this session?", isPresented: $confirmingEnd) {
      Button("End session", role: .destructive) { workout.end() }
      Button("Keep session", role: .cancel) {}
    } message: {
      Text("Your workout is paused. You can resume it or return to setup.")
    }
    .alert(
      "Couldn’t start audio",
      isPresented: Binding(
        get: { workout.errorMessage != nil },
        set: { if !$0 { workout.errorMessage = nil } }
      )
    ) {
      Button("OK") { workout.errorMessage = nil }
    } message: {
      Text(workout.errorMessage ?? "")
    }
    .onChange(of: workout.configuration) { _, configuration in configuration.save() }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { workout.refresh() }
    }
    .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) {
      workout.handleInterruption($0)
    }
    .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) {
      workout.handleRouteChange($0)
    }
    .onReceive(NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange)) { _ in
      workout.handleEngineChange()
    }
    .task {
      while !Task.isCancelled {
        workout.refresh()
        try? await Task.sleep(for: .milliseconds(100))
      }
    }
  }

  private func timerScreen(width: CGFloat, compact: Bool) -> some View {
    VStack(spacing: 0) {
      Text(heading)
        .font(TimerStyle.display(compact ? 28 : 34))
        .foregroundStyle(accent)
        .padding(.top, compact ? 8 : 16)
        .accessibilityIdentifier("workoutPhase")
      WorkoutCountdown(
        seconds: workout.remaining, availableWidth: width,
        maximumFontSize: min(width * 0.47, compact ? 115 : 180)
      )
      .foregroundStyle(foreground)
      .accessibilityIdentifier("countdown")
      .padding(.top, 4)
      Text(
        "Round \(Text(String(format: "%02d", workout.round)).foregroundStyle(accent)) / \(String(format: "%02d", workout.timeline.configuration.rounds))"
      )
      .foregroundStyle(muted)
      .font(TimerStyle.display(compact ? 23 : 28))
      .accessibilityIdentifier("roundCount")
      roundProgress
        .padding(.top, compact ? 14 : 24)
      Spacer(minLength: 16)
      Text("UPCOMING")
        .font(TimerStyle.display(18))
        .foregroundStyle(muted)
      upcoming
        .padding(.top, 2)
      if let message = workout.interruptionMessage {
        Text(message)
          .font(.callout)
          .multilineTextAlignment(.center)
          .foregroundStyle(muted)
          .padding(.top, 12)
      }
      Spacer(minLength: 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var heading: String {
    if workout.screen == .paused { return "PAUSED" }
    switch workout.interval?.phase {
    case .preparation: return "GET READY"
    case .round: return "ROUND"
    case .rest: return "REST"
    case nil: return "ROUND"
    }
  }

  private var roundProgress: some View {
    // Two rows keep larger workouts readable without making the segments disappear.
    let columns = min(workout.timeline.configuration.rounds, 10)
    return LazyVGrid(
      columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns), spacing: 4
    ) {
      ForEach(0..<workout.timeline.configuration.rounds, id: \.self) { index in
        Rectangle()
          .fill(
            index < progressCount
              ? accent
              : (isActiveRound ? TimerStyle.background.opacity(0.25) : TimerStyle.secondaryButton)
          )
          .frame(height: 9)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Round progress")
    .accessibilityValue(
      "\(workout.completedRounds) of \(workout.timeline.configuration.rounds) completed")
  }

  private var progressCount: Int {
    workout.interval?.phase == .preparation ? 0 : workout.round
  }

  @ViewBuilder
  private var upcoming: some View {
    let configuration = workout.timeline.configuration
    switch workout.interval?.phase {
    case .preparation:
      upcomingLabel("ROUND 01", seconds: configuration.roundSeconds)
    case .rest:
      VStack(spacing: 0) {
        Text(String(format: "ROUND %02d", workout.round + 1))
          .font(TimerStyle.display(32))
          .foregroundStyle(TimerStyle.muted)
        Text(shortDurationText(configuration.roundSeconds))
          .font(TimerStyle.display(38))
          .foregroundStyle(.white)
      }
    case .round:
      if workout.round == configuration.rounds {
        Text("FINISH")
          .font(TimerStyle.display(38))
          .foregroundStyle(foreground)
      } else if configuration.restSeconds == 0 {
        upcomingLabel("ROUND", seconds: configuration.roundSeconds)
      } else {
        upcomingLabel("REST", seconds: configuration.restSeconds)
      }
    case nil:
      EmptyView()
    }
  }

  private func upcomingLabel(_ title: String, seconds: Int) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 12) {
      Text(title).foregroundStyle(accent)
      Text(shortDurationText(seconds)).foregroundStyle(foreground)
    }
    .font(TimerStyle.display(38))
    .lineLimit(1)
    .minimumScaleFactor(0.65)
  }

  private func finishedScreen(compact: Bool) -> some View {
    VStack(spacing: 0) {
      Text("SESSION")
        .font(TimerStyle.display(28))
        .foregroundStyle(TimerStyle.red)
      Text("COMPLETE")
        .font(TimerStyle.display(compact ? 48 : 64))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
      Spacer(minLength: 24)
      Text("ROUNDS COMPLETED")
        .font(TimerStyle.display(20))
        .foregroundStyle(TimerStyle.muted)
      Text(
        "\(Text(String(workout.timeline.configuration.rounds)).foregroundStyle(TimerStyle.red))\(Text(" / ").foregroundStyle(TimerStyle.secondaryButton))\(Text(String(workout.timeline.configuration.rounds)).foregroundStyle(.white))"
      )
      .font(TimerStyle.display(58))
      HStack(spacing: 24) {
        summary("WORK", seconds: workout.timeline.configuration.workSeconds)
        Rectangle().fill(TimerStyle.secondaryButton).frame(width: 1, height: 70)
        summary("REST", seconds: workout.timeline.configuration.totalRestSeconds)
      }
      .padding(.top, 22)
      Spacer(minLength: 24)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .accessibilityIdentifier("finishedScreen")
  }

  private func summary(_ title: String, seconds: Int) -> some View {
    VStack(spacing: 0) {
      Text(title).font(TimerStyle.display(18)).foregroundStyle(TimerStyle.muted)
      Text(shortDurationText(seconds)).font(TimerStyle.display(40)).foregroundStyle(.white)
    }
  }

  @ViewBuilder
  private var controls: some View {
    switch workout.screen {
    case .setup:
      WorkoutButton(title: "Start session", symbol: "play.fill") { workout.start() }
    case .running, .paused:
      HStack(spacing: 10) {
        WorkoutButton(
          title: workout.screen == .paused ? "Resume" : "Pause",
          symbol: workout.screen == .paused ? "play.fill" : "pause.fill",
          background: isActiveRound ? TimerStyle.background : nil
        ) {
          if workout.screen == .paused { workout.resume() } else { workout.pause() }
        }
        WorkoutButton(
          title: "End", primary: false, background: isActiveRound ? TimerStyle.background : nil
        ) {
          workout.pause()
          confirmingEnd = true
        }
        .frame(width: 100)
      }
    case .finished:
      HStack(spacing: 10) {
        WorkoutButton(title: "Repeat", symbol: "arrow.clockwise") { workout.start() }
        WorkoutButton(title: "Setup", primary: false) { workout.end() }
          .frame(width: 100)
      }
    }
  }

  private var settingsSheet: some View {
    NavigationStack {
      List {
        Section("Sound") {
          Text("Bells play alongside your music, using your iPhone’s media volume.")
          Button("Test bell", systemImage: "speaker.wave.2") { workout.previewBell() }
        }
        Section("During your workout") {
          Text("The screen stays awake while the timer runs. You can also lock your phone.")
          Text("Calls and disconnected headphones pause the session. Resume when you’re ready.")
        }
        Section {
          Text("Boxing Timer").font(.headline)
        }
      }
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { showingSettings = false }
        }
      }
    }
    .tint(TimerStyle.red)
  }
}

#Preview {
  ContentView()
}
