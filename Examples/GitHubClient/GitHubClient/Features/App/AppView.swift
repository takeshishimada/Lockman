import ComposableArchitecture
import SwiftUI

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    AppStackView(store: store.scope(state: \.appStack, action: \.appStack))
      .alert($store.scope(state: \.alert, action: \.alert))
  }
}
