import SwiftUI

struct SetupView: View {
  @Binding var configuration: WorkoutConfiguration
  let compact: Bool

  var body: some View {
    ScrollView {
      VStack(spacing: compact ? 10 : 16) {
        VStack(spacing: -4) {
          Text("BOXING")
            .font(TimerStyle.display(compact ? 32 : 38))
            .foregroundStyle(TimerStyle.red)
          Text("TIMER")
            .font(TimerStyle.display(compact ? 60 : 76))
            .foregroundStyle(.white)
          Text("SETUP")
            .font(TimerStyle.display(24))
            .foregroundStyle(TimerStyle.muted)
            .padding(.top, 2)
        }
        .padding(.bottom, compact ? 8 : 16)
        configurationRow("Rounds", value: $configuration.rounds, range: 1...30, step: 1)
        configurationRow(
          "Round length", value: $configuration.roundSeconds, range: 5...900, step: 15, time: true)
        configurationRow(
          "Rest length", value: $configuration.restSeconds, range: 0...600, step: 15, time: true)
        configurationRow(
          "Preparation", value: $configuration.preparationSeconds, range: 0...60, step: 5,
          time: true)
      }
      .padding(.top, compact ? 0 : 6)
      .padding(.bottom, 20)
    }
    .scrollIndicators(.hidden)
  }

  private func configurationRow(
    _ title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, time: Bool = false
  ) -> some View {
    HStack(spacing: 8) {
      Text(title.uppercased())
        .font(TimerStyle.display(18))
        .foregroundStyle(TimerStyle.red)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .frame(maxWidth: .infinity, alignment: .leading)
      adjustmentButton(
        "Decrease \(title.lowercased())", symbol: "minus",
        disabled: value.wrappedValue <= range.lowerBound
      ) {
        value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
      }
      Text(time ? shortDurationText(value.wrappedValue) : String(value.wrappedValue))
        .font(TimerStyle.display(24))
        .foregroundStyle(.white)
        .monospacedDigit()
        .frame(width: 52)
        .accessibilityLabel(title)
        .accessibilityValue(
          time ? shortDurationText(value.wrappedValue) : String(value.wrappedValue)
        )
        .accessibilityIdentifier(title)
      adjustmentButton(
        "Increase \(title.lowercased())", symbol: "plus",
        disabled: value.wrappedValue >= range.upperBound
      ) {
        value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
      }
    }
    .padding(.horizontal, 12)
    .frame(minHeight: compact ? 66 : 76)
    .background(TimerStyle.panel, in: RoundedRectangle(cornerRadius: 8))
    .overlay {
      RoundedRectangle(cornerRadius: 8)
        .strokeBorder(TimerStyle.secondaryButton.opacity(0.7), lineWidth: 1)
    }
  }

  private func adjustmentButton(
    _ label: String, symbol: String, disabled: Bool, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Image(systemName: symbol)
        .font(.system(size: 17, weight: .bold))
        .foregroundStyle(TimerStyle.muted)
        .frame(width: 36, height: 36)
        .background(TimerStyle.secondaryButton, in: Circle())
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(WorkoutPressStyle())
    .disabled(disabled)
    .opacity(disabled ? 0.35 : 1)
    .accessibilityLabel(label)
  }
}
