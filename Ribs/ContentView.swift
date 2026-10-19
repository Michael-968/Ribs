//
//  ContentView.swift
//  Ribs
//
//  Created by Mikhail Kemenov on 19.10.2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "ipod")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("buenas dias pedrilas")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
