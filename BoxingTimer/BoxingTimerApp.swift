import SwiftUI

@main
struct BoxingTimerApp: App {
  init() {
    TimerStyle.registerFont()
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
