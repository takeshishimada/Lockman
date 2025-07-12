import Lockman
import SwiftUI

/// A reusable debug button component for displaying current lock state
struct DebugButton: View {
  let strategyName: String

  var body: some View {
    Button(action: {
      print("\n📊 Current Lock State (\(strategyName)):")
      LockmanManager.debug.printCurrentLocks(options: .compact)
      print("")
    }) {
      HStack {
        Image(systemName: "lock.doc")
        Text("Show Current Locks in Console")
      }
      .font(.footnote)
      .foregroundColor(.blue)
    }
    .padding(.top, 20)
  }
}

#Preview {
  DebugButton(strategyName: "ExampleStrategy")
}
