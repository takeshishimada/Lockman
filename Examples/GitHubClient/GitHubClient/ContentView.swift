//
//  ContentView.swift
//  GitHubClient
//
//  Created by 嶋田 武士 on 2025/06/20.
//

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
