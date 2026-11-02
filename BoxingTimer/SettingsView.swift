import SwiftUI

struct SettingsView: View {
  @Binding var hapticsEnabled: Bool
  @Binding var timeAdjustmentSeconds: Int
  let previewBell: () -> Void
  @State private var previewCount = 0
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      List {
        Section {
          Toggle("Haptics", isOn: $hapticsEnabled)
            .accessibilityIdentifier("hapticsToggle")
        } header: {
          sectionHeading("Feedback")
        } footer: {
          Text("Subtle taps for adjustments and controls, with a stronger pulse at the bell.")
        }
        .listRowBackground(TimerStyle.panel)

        Section {
          Picker("Time step", selection: $timeAdjustmentSeconds) {
            ForEach([5, 10, 15, 30], id: \.self) { seconds in
              Text("\(seconds) seconds").tag(seconds)
            }
          }
          .accessibilityIdentifier("timeStepPicker")
        } header: {
          sectionHeading("Time adjustments")
        } footer: {
          Text(
            "Sets the steps for round and rest +/− buttons. Preparation changes by 5 seconds; round count by 1."
          )
        }
        .listRowBackground(TimerStyle.panel)

        Section {
          Button {
            previewBell()
            previewCount += 1
          } label: {
            Label("Test bell", systemImage: "speaker.wave.2")
              .foregroundStyle(.white)
          }
          .buttonStyle(WorkoutPressStyle())
          .sensoryFeedback(TimerStyle.bellFeedback, trigger: previewCount) { _, _ in
            hapticsEnabled
          }
        } header: {
          sectionHeading("Sound")
        } footer: {
          Text("Bells play alongside your music, using your iPhone’s media volume.")
        }
        .listRowBackground(TimerStyle.panel)
      }
      .scrollContentBackground(.hidden)
      .background(TimerStyle.background)
      .foregroundStyle(.white)
      .navigationTitle("Settings")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
    .tint(TimerStyle.red)
    .preferredColorScheme(.dark)
  }

  private func sectionHeading(_ title: String) -> some View {
    Text(title.uppercased())
      .font(TimerStyle.display(18))
      .foregroundStyle(TimerStyle.red)
  }
}
