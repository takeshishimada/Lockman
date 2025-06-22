import ComposableArchitecture
import SwiftUI

struct ContentView: View {
  var body: some View {
    AppView(
      store: Store(
        initialState: AppFeature.State()
      ) {
        AppFeature()
      }
    )
  }
}

#Preview {
  ContentView()
}
