import CoreText
import SwiftUI
import UIKit

// Colors and display type follow the approved Corner mockups.
enum TimerStyle {
  static let background = Color(red: 0.008, green: 0.047, blue: 0.078)
  static let red = Color(red: 1, green: 0.02, blue: 0.24)
  static let muted = Color(red: 0.65, green: 0.71, blue: 0.86)
  static let panel = Color(red: 0.045, green: 0.095, blue: 0.15)
  static let secondaryButton = Color(red: 0.09, green: 0.16, blue: 0.25)

  static func display(_ size: CGFloat) -> Font { .custom("Anton-Regular", size: size) }

  static func registerFont() {
    guard let url = Bundle.main.url(forResource: "Anton-Regular", withExtension: "ttf") else {
      return
    }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }
}

struct WorkoutCountdown: View {
  let seconds: Int
  let availableWidth: CGFloat
  let maximumFontSize: CGFloat

  var body: some View {
    let text = durationText(seconds)
    let referenceFont = UIFont(name: "Anton-Regular", size: 1)!
    let referenceWidth = ("00:00" as NSString).size(withAttributes: [.font: referenceFont]).width
    let fontSize = min(maximumFontSize, availableWidth / referenceWidth)

    HStack(spacing: 0) {
      ForEach(Array(text.enumerated()), id: \.offset) { _, character in
        // Anton has proportional digits. Reserve a zero's width even for a narrow one.
        Text(character == ":" ? ":" : "0")
          .hidden()
          .overlay {
            Text(String(character))
              .contentTransition(.identity)
          }
      }
    }
    .font(TimerStyle.display(fontSize))
    .frame(width: fontSize * referenceWidth)
    .contentShape(Rectangle())
    .accessibilityElement(children: .ignore)
    .accessibilityAddTraits(.isStaticText)
    .accessibilityLabel("Time remaining")
    .accessibilityValue(text)
  }
}

struct WorkoutButton: View {
  let title: String
  var symbol: String? = nil
  var primary = true
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        if let symbol {
          Image(systemName: symbol)
            .font(.system(size: 22, weight: .bold))
          Rectangle()
            .fill(.white.opacity(0.45))
            .frame(width: 1, height: 25)
            .accessibilityHidden(true)
        }
        Text(title.uppercased())
          .font(TimerStyle.display(22))
          .lineLimit(1)
          .minimumScaleFactor(0.65)
      }
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity, minHeight: 64)
      .background(primary ? TimerStyle.red : TimerStyle.secondaryButton)
      .clipShape(RoundedRectangle(cornerRadius: 5))
      .contentShape(Rectangle())
    }
    .buttonStyle(WorkoutPressStyle())
    .accessibilityLabel(title)
  }
}

struct WorkoutPressStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .opacity(configuration.isPressed ? 0.72 : 1)
  }
}
